# Turns a module of JavaScript into a plain script, since JavaScriptCore gives
# no program but Safari a way to load modules.
#
#     m = script_of(code)     # the module as a function, with what it imports
#     m.imports               # the addresses that it imports, as its code writes them: "three", "./a.js"
#     wrapped(m, ...)         # the script that gives LOADER the module's function
#
# A module becomes a function of four values: `__lm_x` adds to what it
# exports, `__lm_i(k)` gives what the module of its kth address exports,
# `__lm_meta` is `import.meta`, and `__lm_import` is `import()`. Its
# `import` and `export` lines are taken out of its code, and the code is
# otherwise the same, on the same lines, so an error names the right line.
#
#     import * as THREE from 'three'          const THREE = __lm_i(0);
#     import { a, b as c } from './x.js'      const {a, b: c} = __lm_i(1);
#     export function f() {}                  function f() {}             and f is exported
#     export { f as g }                       (taken out)                 and g is f
#     export default 4                        const __lm_default = 4
#
# What's left out: a name that's imported has the value that the module
# exported when the import ran, and not what it changes to later. Two modules
# that import each other can see each other half made. That's rare in the
# modules of the web, which import each other in one direction.
#
# LOADER is the JavaScript that keeps the modules and runs each one once,
# after the modules that it imports: see script.jl, which gets their files.

"A module as a function: its code, and the addresses that it imports, in the order of `__lm_i`"
struct Converted
  code::String
  imports::Vector{String}
end

# The names after which a / starts a pattern (a regular expression) and not a division
const BEFORE_PATTERN = Set(["return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw", "case", "do", "else", "yield", "await", "extends"])
# The names that start a statement: after a line break, the statement before has ended
const STARTS = Set(["export", "import", "const", "let", "var", "function", "class", "if", "for", "while", "do", "return", "switch", "try", "throw", "async"])

"Where the reading of a module's code has got to"
mutable struct Lexer
  s::Vector{UInt8}
  i::Int                  # the next byte to read
  last::Symbol            # what the last token was: :none, :name, :keyword (one of BEFORE_PATTERN), :value, :close (a ) or a ]) or :open
  dot::Bool               # the last token was a `.`, so a name after it is a property
  prop::Bool              # the last name that was read was a property, like `import` in `x.import`
  newline::Bool           # a line break came before the token that was read last
  depth::Int              # how many (, [ and { are open
  templates::Vector{Int}  # the depth at which each value of a template that's open was started, with \${
end
Lexer(s) = Lexer(s, 1, :none, false, false, false, 0, Int[])

"A token: what kind it is, and its first and last byte"
struct Token
  kind::Symbol            # :name, :string, :template, :pattern, :number, :punct or :end
  from::Int
  to::Int
end

isstart(c::UInt8) = UInt8('a') <= c <= UInt8('z') || UInt8('A') <= c <= UInt8('Z') || c == UInt8('_') || c == UInt8('$') || c == UInt8('\\') || c >= 0x80
ispart(c::UInt8) = isstart(c) || UInt8('0') <= c <= UInt8('9')
isdigitbyte(c::UInt8) = UInt8('0') <= c <= UInt8('9')

"The text of a token"
word(l::Lexer, t::Token) = String(l.s[t.from:t.to])
is(l::Lexer, t::Token, w::AbstractString) = t.kind == :name && t.to - t.from + 1 == ncodeunits(w) && all(k -> l.s[t.from+k-1] == codeunit(w, k), 1:ncodeunits(w))
ispunct(t::Token, l::Lexer, c::Char) = t.kind == :punct && t.from == t.to && l.s[t.from] == UInt8(c)

"Skip the spaces, the line breaks and the comments from byte `i`. Gives the next byte to read."
blank!(l::Lexer, i) = begin
  s, n = l.s, length(l.s)
  l.newline = false
  while i <= n
    c = s[i]
    if c == UInt8(' ') || c == UInt8('\t') || c == UInt8('\r') || c == 0x0b || c == 0x0c
      i += 1
    elseif c == UInt8('\n')
      l.newline = true
      i += 1
    elseif c == UInt8('/') && i < n && s[i+1] == UInt8('/')
      while i <= n && s[i] != UInt8('\n') i += 1 end
    elseif c == UInt8('/') && i < n && s[i+1] == UInt8('*')
      i += 2
      while i < n && !(s[i] == UInt8('*') && s[i+1] == UInt8('/'))
        s[i] == UInt8('\n') && (l.newline = true)
        i += 1
      end
      i += 2
    elseif c == 0xc2 && i < n && s[i+1] == 0xa0                                        # a space that doesn't break
      i += 2
    elseif c == 0xe2 && i + 1 < n && s[i+1] == 0x80 && (s[i+2] == 0xa8 || s[i+2] == 0xa9)   # a line or paragraph break
      l.newline = true
      i += 3
    elseif c == 0xef && i + 1 < n && s[i+1] == 0xbb && s[i+2] == 0xbf                  # the mark at the start of some files
      i += 3
    else
      break
    end
  end
  i
end

"Read the rest of a template from byte `i`: to its end, or to the \$ and { that start a value in it"
template!(l::Lexer, i, from) = begin
  s, n = l.s, length(l.s)
  while i <= n
    c = s[i]
    if c == UInt8('\\')
      i += 2
    elseif c == UInt8('`')
      l.i, l.last, l.dot = i + 1, :value, false
      return Token(:template, from, i)
    elseif c == UInt8('$') && i < n && s[i+1] == UInt8('{')
      l.depth += 1
      push!(l.templates, l.depth)
      l.i, l.last, l.dot = i + 2, :open, false
      return Token(:template, from, i + 1)
    else
      i += 1
    end
  end
  l.i = n + 1
  Token(:template, from, n)
end

"Read the next token"
next!(l::Lexer) = begin
  s, n = l.s, length(l.s)
  i = blank!(l, l.i)
  l.i = i
  i > n && return Token(:end, i, i - 1)
  c = s[i]
  if c == UInt8('"') || c == UInt8('\'')
    j = i + 1
    while j <= n && s[j] != c && s[j] != UInt8('\n')
      s[j] == UInt8('\\') && (j += 1)
      j += 1
    end
    l.i, l.last, l.dot = j + 1, :value, false
    return Token(:string, i, min(j, n))
  elseif c == UInt8('`')
    return template!(l, i + 1, i)
  elseif c == UInt8('}') && !isempty(l.templates) && l.templates[end] == l.depth
    # The end of a value in a template: the template goes on
    pop!(l.templates)
    l.depth -= 1
    return template!(l, i + 1, i)
  elseif isstart(c)
    j = i
    while j <= n && ispart(s[j]) j += 1 end
    t = Token(:name, i, j - 1)
    l.i = j
    after = l.dot
    l.dot = false
    l.prop = after
    l.last = !after && word(l, t) in BEFORE_PATTERN ? :keyword : :name
    return t
  elseif isdigitbyte(c) || (c == UInt8('.') && i < n && isdigitbyte(s[i+1]))
    j = i + 1
    while j <= n && (ispart(s[j]) || s[j] == UInt8('.')) j += 1 end
    l.i, l.last, l.dot = j, :value, false
    return Token(:number, i, j - 1)
  elseif c == UInt8('/') && !(l.last in (:name, :value, :close))
    # A pattern: up to the / that ends it, which isn't in a [ ] or after a \, then its flags
    j, within = i + 1, false
    while j <= n
      d = s[j]
      d == UInt8('\n') && break
      if d == UInt8('\\')
        j += 2
        continue
      end
      d == UInt8('[') ? (within = true) : d == UInt8(']') ? (within = false) : (d == UInt8('/') && !within && break)
      j += 1
    end
    if j <= n && s[j] == UInt8('/')
      j += 1
      while j <= n && ispart(s[j]) j += 1 end
      l.i, l.last, l.dot = j, :value, false
      return Token(:pattern, i, j - 1)
    end
  end
  # Any other character is a token by itself
  if c == UInt8('(') || c == UInt8('[') || c == UInt8('{')
    l.depth += 1
    l.last = :open
  elseif c == UInt8(')') || c == UInt8(']')
    l.depth -= 1
    l.last = :close
  elseif c == UInt8('}')
    l.depth -= 1
    l.last = :open    # a block ends, and a pattern can start the next statement
  else
    l.last = :open
  end
  l.dot = c == UInt8('.')
  l.i = i + 1
  Token(:punct, i, i)
end

"What `next!` would read, without reading it. `l.newline` then says whether a line break comes before it."
peek(l::Lexer) = begin
  i, last, dot, prop, depth, templates = l.i, l.last, l.dot, l.prop, l.depth, copy(l.templates)
  t = next!(l)
  l.i, l.last, l.dot, l.prop, l.depth, l.templates = i, last, dot, prop, depth, templates
  t
end

"The text of a string token, without its quotes"
unquoted(l::Lexer, t::Token) = begin
  inner = String(l.s[t.from+1:t.to-1])
  replace(inner, r"\\(.)" => s"\1")
end

"The name or the string that a token is, as JavaScript writes a key"
key(l::Lexer, t::Token) = t.kind == :string ? repr(unquoted(l, t)) : word(l, t)
"The name that a key is, as a string of JavaScript"
quoted(name::AbstractString) = repr(String(name))

"""
The module of JavaScript `code` as a function. `async` makes it an async
function, which a module with an `await` outside any function needs.
"""
script_of(code::AbstractString) = begin
  src = Vector{UInt8}(codeunits(String(code)))
  l = Lexer(src)
  imports = String[]
  slot(spec) = (k = findfirst(==(spec), imports); k === nothing ? (push!(imports, spec); length(imports) - 1) : k - 1)
  binds = String[]                       # the lines that make the names that the module imports
  exported = Pair{String,String}[]       # what it exports: the name, as a key of JavaScript, and the code of its value
  stars = Int[]                          # the modules all of whose exports it exports too
  edits = Tuple{Int,Int,String}[]        # the bytes to take out, from and to, and what goes in their place
  # A module can start with a line that says which program runs it
  length(src) >= 2 && src[1] == UInt8('#') && src[2] == UInt8('!') && push!(edits, (1, something(findfirst(==(UInt8('\n')), src), length(src) + 1) - 1, ""))
  # `import(...)` and `import.meta` can be anywhere
  dynamic!(t) = begin
    after = blank!(l, l.i)
    after <= length(src) || return false
    if src[after] == UInt8('(')
      push!(edits, (t.from, t.to, "__lm_import"))
      return true
    elseif src[after] == UInt8('.')
      m = blank!(l, after + 1)
      if m + 3 <= length(src) && String(src[m:m+3]) == "meta" && (m + 4 > length(src) || !ispart(src[m+4]))
        push!(edits, (t.from, m + 3, "__lm_meta"))
        l.i, l.last, l.dot = m + 4, :name, false
        return true
      end
    end
    false
  end
  # The end of an `import` or `export` line: what it adds after its address, like `with { type: 'json' }`, and its ;
  ending!() = begin
    t = peek(l)
    if (is(l, t, "with") || is(l, t, "assert")) && !l.newline
      next!(l)
      if ispunct(peek(l), l, '{')
        next!(l)
        base = l.depth - 1
        while (u = next!(l)).kind != :end && !(ispunct(u, l, '}') && l.depth == base) end
      end
    end
    ispunct(peek(l), l, ';') && next!(l)
    l.i - 1
  end
  # The address after `from`
  address!() = begin
    f = next!(l)
    is(l, f, "from") || return nothing
    t = next!(l)
    t.kind == :string ? unquoted(l, t) : nothing
  end
  # The names of `{ a, b as c }`, as (the name in the other module, the name here)
  list!() = begin
    names = Tuple{String,String}[]
    while (t = next!(l)).kind != :end
      ispunct(t, l, '}') && break
      ispunct(t, l, ',') && continue
      outer = key(l, t)
      inner = outer
      if is(l, peek(l), "as")
        next!(l)
        inner = key(l, next!(l))
      end
      push!(names, (outer, inner))
    end
    names
  end
  # The names that a declaration of `var`, `let` or `const` makes, for an `export` of one
  declared!() = begin
    names = String[]
    base = l.depth
    target!() = begin
      t = next!(l)
      if t.kind == :name
        push!(names, word(l, t))
      elseif ispunct(t, l, '{') || ispunct(t, l, '[')
        # A pattern: a name in it is made when it's a whole entry, or after a :, and not when a : follows it
        prev = t
        while (u = next!(l)).kind != :end
          l.depth == base && break
          if u.kind == :name && (ispunct(prev, l, '{') || ispunct(prev, l, '[') || ispunct(prev, l, ',') || ispunct(prev, l, ':') || ispunct(prev, l, '.')) &&
             !ispunct(peek(l), l, ':') && !ispunct(peek(l), l, '(')
            push!(names, word(l, u))
          end
          prev = u
        end
      end
    end
    target!()
    while true
      t = peek(l)
      t.kind == :end && break
      if l.depth == base && ispunct(t, l, ',')
        next!(l)
        target!()
        continue
      end
      l.depth == base && ispunct(t, l, ';') && break
      # Where a line break ends the statement
      l.depth == base && l.newline && l.last in (:name, :value, :close) && (t.kind in (:string, :number, :template) || (t.kind == :name && !(word(l, t) in ("in", "instanceof", "of")))) && break
      l.depth == base && l.newline && t.kind == :name && word(l, t) in STARTS && break
      l.depth < base && break
      next!(l)
      t.kind == :name && is(l, t, "import") && dynamic!(t)
    end
    names
  end
  # The name of a function or a class that's declared after `export`, or nothing for one with none
  declared_name!() = begin
    t = next!(l)
    is(l, t, "async") && (t = next!(l))
    if is(l, t, "function")
      ispunct(peek(l), l, '*') && next!(l)
      u = peek(l)
      return u.kind == :name ? word(l, u) : nothing
    elseif is(l, t, "class")
      u = peek(l)
      return u.kind == :name && !is(l, u, "extends") ? word(l, u) : nothing
    end
    nothing
  end
  while true
    t = next!(l)
    t.kind == :end && break
    t.kind == :name || continue
    l.prop && continue   # a property, like `x.import`, is no keyword
    if is(l, t, "import")
      dynamic!(t) && continue
      l.depth == 0 || continue
      u = next!(l)
      if u.kind == :string
        slot(unquoted(l, u))
        push!(edits, (t.from, ending!(), ""))
        continue
      end
      default, space, names = nothing, nothing, Tuple{String,String}[]
      if u.kind == :name && !is(l, u, "from")
        default = word(l, u)
        ispunct(peek(l), l, ',') && (next!(l); u = next!(l))
      end
      if ispunct(u, l, '*')
        next!(l)   # as
        space = word(l, next!(l))
      elseif ispunct(u, l, '{')
        names = list!()
      end
      spec = address!()
      spec === nothing && continue
      k = slot(spec)
      push!(edits, (t.from, ending!(), ""))
      from = "__lm_i($k)"
      default === nothing || push!(binds, "const $default = $from.default;")
      space === nothing || push!(binds, "const $space = $from;")
      isempty(names) || push!(binds, "const {" * join(("$o: $i" for (o, i) in names), ", ") * "} = $from;")
    elseif is(l, t, "export") && l.depth == 0
      u = peek(l)
      if ispunct(u, l, '*')
        next!(l)
        if is(l, peek(l), "as")
          next!(l)
          space = key(l, next!(l))
          spec = address!()
          spec === nothing && continue
          push!(exported, space => "__lm_i($(slot(spec)))")
        else
          spec = address!()
          spec === nothing && continue
          push!(stars, slot(spec))
        end
        push!(edits, (t.from, ending!(), ""))
      elseif ispunct(u, l, '{')
        next!(l)
        names = list!()
        if is(l, peek(l), "from")
          spec = address!()
          spec === nothing && continue
          k = slot(spec)
          foreach(((o, i),) -> push!(exported, i => "__lm_i($k)[$(o[1] == '"' ? o : quoted(o))]"), names)
        else
          foreach(((o, i),) -> push!(exported, i => o), names)
        end
        push!(edits, (t.from, ending!(), ""))
      elseif is(l, u, "default")
        next!(l)
        v = peek(l)
        if v.kind == :name && (is(l, v, "function") || is(l, v, "class") || is(l, v, "async"))
          at, last, depth = l.i, l.last, l.depth
          name = declared_name!()
          l.i, l.last, l.depth = at, last, depth
          if name !== nothing
            push!(edits, (t.from, u.to, ""))
            push!(exported, "default" => name)
            continue
          end
        end
        push!(edits, (t.from, u.to, "const __lm_default ="))
        push!(exported, "default" => "__lm_default")
      elseif is(l, u, "var") || is(l, u, "let") || is(l, u, "const")
        push!(edits, (t.from, t.to, ""))
        next!(l)
        foreach(n -> push!(exported, n => n), declared!())
      elseif is(l, u, "function") || is(l, u, "class") || is(l, u, "async")
        push!(edits, (t.from, t.to, ""))
        at, last, depth = l.i, l.last, l.depth
        name = declared_name!()
        l.i, l.last, l.depth = at, last, depth
        name === nothing || push!(exported, name => name)
      end
    end
  end
  # The code with the edits: what's taken out keeps its line breaks, so each line of the rest stays on its line
  out = IOBuffer()
  at = 1
  for (from, to, put) in sort!(edits)
    from < at && continue
    write(out, @view src[at:from-1])
    write(out, put)
    for k in from:to
      src[k] == UInt8('\n') && write(out, '\n')
    end
    at = to + 1
  end
  at <= length(src) && write(out, @view src[at:end])
  head = join(binds, " ")
  isempty(exported) || (head *= " __lm_x({" * join(("$(n[1] == '"' ? n : quoted(n)): () => $v" for (n, v) in exported), ", ") * "});")
  for k in stars
    head *= " __lm_x.star(__lm_i($k));"
  end
  Converted(head * String(take!(out)), imports)
end

"""
The script that gives LOADER the module `m`, whose address is `address`, as
a function. `url` is what `import.meta.url` is, and `imports` the addresses of
the modules that it imports, in the order of `m.imports`, made whole.
"""
wrapped(m::Converted, address, url, imports; async=false) =
  "globalThis[Symbol.for('ladder.modules')].define(" * quoted(address) * ", " * quoted(url) * ", [" * join(quoted.(imports), ", ") * "], " *
  (async ? "async " : "") * "function (__lm_x, __lm_i, __lm_meta, __lm_import) {'use strict'; " * m.code * "\n})"

const LOADER = raw"""
(function (native) {
'use strict'
// Each module by its address: what it imports, its function, the object of what it exports, and whether it has run
const modules = new Map()
const KEY = Symbol.for('ladder.modules')

function define(address, url, imports, run) {
  if (modules.has(address)) return
  const exports = Object.create(null)
  Object.defineProperty(exports, Symbol.toStringTag, {value: 'Module'})
  modules.set(address, {address, url, imports, run, exports, state: 0, promise: undefined})
}

// What a module calls to say what it exports: a getter for each name, so a value that the module changes is seen
function exporter(m) {
  const x = getters => { for (const name in getters) Object.defineProperty(m.exports, name, {get: getters[name], enumerable: true, configurable: true}) }
  x.star = other => {
    for (const name of Object.keys(other))
      if (name !== 'default' && !Object.prototype.hasOwnProperty.call(m.exports, name))
        Object.defineProperty(m.exports, name, {get: () => other[name], enumerable: true, configurable: true})
  }
  return x
}

// `import(address)` in the module at `from`: the module, once it and what it imports have come and have run
const importer = from => address => new Promise((ok, no) => {
  const attempt = () => {
    let got
    try { got = native.gather(String(address), from) } catch (e) { return no(e) }
    if (got === false) return setTimeout(attempt, 30)
    try { Promise.resolve(run(got)).then(() => ok(modules.get(got).exports), no) } catch (e) { no(e) }
  }
  attempt()
})

// Run the module at `address`, after the modules that it imports. Gives a promise when one of them waits for something.
function run(address) {
  const m = modules.get(address)
  if (!m) throw new Error('The module ' + address + ' is missing')
  if (m.state) return m.promise
  m.state = 1
  const waits = []
  for (const a of m.imports) { const p = run(a); if (p) waits.push(p) }
  const go = () => {
    const meta = {url: m.url, resolve: name => native.resolve(String(name), m.url)}
    const r = m.run.call(undefined, exporter(m), k => modules.get(m.imports[k]).exports, meta, importer(m.address))
    if (r && typeof r.then === 'function') return r.then(() => { m.state = 2 })
    m.state = 2
  }
  if (waits.length) return m.promise = Promise.all(waits).then(go)
  const r = go()
  if (r) m.promise = r
  return r
}

globalThis[KEY] = {define, run}
})
"""

export Converted, script_of, wrapped, LOADER
