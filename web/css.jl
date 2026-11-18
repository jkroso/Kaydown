# Reads CSS, and says which of its rules are for an element.
#
#     rules = sheet("p.note > b { color: red; margin: 0 !important }")
#     r = rules[1]
#     matches(r.selector, element)     # true when the rule is for the element
#     r.selector.weight                # how specific it is: (ids, classes, tags)
#     r.declarations                   # each with its name, its value and whether it's !important
#     r.media                          # what each @media round the rule asks of the page
#     media("screen and (max-width: 600px)", 500)   # true on a page 500 px wide
#     declarations("color: red; margin: 0")         # what a style attribute says
#
# A selector can have tags, classes, ids, what an attribute says, the words
# between two parts (a space, `>`, `+`, `~`), and :first-child, :last-child,
# :only-child, :nth-child, :not, :link, :root and :empty. A rule for the mouse
# or for a part of an element (:hover, ::before) is for nothing, since a page
# that's drawn has neither. A rule whose selector can't be read is left out,
# as a browser leaves it out.

@use "./dom" Element Text attr

struct Declaration
  name::String
  value::String
  important::Bool
end

"A part of a selector that's about one element, like `td.wide[align=left]`"
struct Compound
  tag::String                                  # "" for any
  id::String
  classes::Vector{String}
  attrs::Vector{Tuple{String,String,String}}   # the name, how it's compared ("" for there at all, "=", "~=", "|=", "^=", "\$=", "*="), and the value
  pseudos::Vector{Tuple{Symbol,Any}}
end

struct Selector
  parts::Vector{Compound}   # from the element that the rule is for, back to the left
  links::Vector{Char}       # what's between each part and the next: ' ', '>', '+' or '~'
  weight::NTuple{3,Int}
end

struct Rule
  selector::Selector
  declarations::Vector{Declaration}
  media::Vector{String}
  order::Int
end

# --- reading ------------------------------------------------------------------------------

"Where the bracket at `i` of `s` closes, past strings and brackets in it, or the end of `s`"
closing(s, i, open, close) = begin
  depth = 0
  n = lastindex(s)
  while i <= n
    c = s[i]
    if c == '"' || c == '\''
      i = something(findnext(c, s, nextind(s, i)), n)
    elseif c == '\\'
      i = nextind(s, i)
    elseif c == open
      depth += 1
    elseif c == close
      depth -= 1
      depth == 0 && return i
    end
    i = nextind(s, i)
  end
  n + 1
end

"`s` cut at each `at` that's in no string and no brackets"
pieces(s::AbstractString, at::Char) = begin
  out = SubString{String}[]
  s = String(s)
  from = i = firstindex(s)
  n = lastindex(s)
  while i <= n
    c = s[i]
    if c == '"' || c == '\''
      i = something(findnext(c, s, nextind(s, i)), n)
    elseif c == '\\'
      i = nextind(s, i)
    elseif c == '('
      i = min(closing(s, i, '(', ')'), n)
    elseif c == '['
      i = min(closing(s, i, '[', ']'), n)
    elseif c == at
      push!(out, SubString(s, from, prevind(s, i)))
      from = nextind(s, i)
    end
    i = nextind(s, i)
  end
  from <= n && push!(out, SubString(s, from, n))
  out
end

const IMPORTANT = r"!\s*important\s*$"i

"What a block of CSS, or a style attribute, declares"
declarations(block::AbstractString) = begin
  out = Declaration[]
  for piece in pieces(block, ';')
    colon = findfirst(':', piece)
    colon === nothing && continue
    name = lowercase(strip(SubString(piece, firstindex(piece), prevind(piece, colon))))
    value = strip(SubString(piece, nextind(piece, colon)))
    (isempty(name) || isempty(value) || occursin(r"[^a-z0-9_-]", name)) && continue
    important = occursin(IMPORTANT, value)
    important && (value = strip(replace(value, IMPORTANT => "")))
    isempty(value) || push!(out, Declaration(name, String(value), important))
  end
  out
end

"The rules of a sheet of CSS, in its order. `order` is how many rules the page had before it."
sheet(text::AbstractString; media=String[], order=0) = begin
  rules = Rule[]
  text = replace(String(text), r"/\*.*?(\*/|$)"s => " ", "<!--" => " ", "-->" => " ")
  read!(rules, text, Vector{String}(media), order)
  rules
end

read!(rules, text, media, order) = begin
  i, n = firstindex(text), lastindex(text)
  while i <= n
    isspace(text[i]) && (i = nextind(text, i); continue)
    # What's before the block: a selector, or an @ rule's name and what it asks
    j = i
    while j <= n && text[j] != '{' && text[j] != ';' && text[j] != '}'
      c = text[j]
      j = c == '"' || c == '\'' ? something(findnext(c, text, nextind(text, j)), n) : c == '(' ? min(closing(text, j, '(', ')'), n) :
          c == '[' ? min(closing(text, j, '[', ']'), n) : j
      j = nextind(text, j)
    end
    before = strip(SubString(text, i, prevind(text, j)))
    if j > n || text[j] != '{'
      i = j > n ? j : nextind(text, j)   # an @import, or a } with nothing open
      continue
    end
    stop = closing(text, j, '{', '}')
    block = SubString(text, nextind(text, j), prevind(text, min(stop, n + 1)))
    i = stop > n ? stop : nextind(text, stop)
    if startswith(before, '@')
      m = match(r"^@([a-zA-Z-]+)\s*(.*)$"s, before)
      m === nothing && continue
      name = lowercase(m[1])
      if name == "media"
        read!(rules, String(block), [media; String(m[2])], order)
      elseif name == "supports" || name == "layer"
        read!(rules, String(block), media, order)
      end
      continue
    end
    found = declarations(block)
    isempty(found) && continue
    selectors = [selector(strip(s)) for s in pieces(before, ',')]
    # One selector that can't be read spoils the rule
    (isempty(selectors) || any(isnothing, selectors)) && continue
    for s in selectors
      push!(rules, Rule(s, found, media, order + length(rules) + 1))
    end
  end
end

const NAME = r"^(?:[-_a-zA-Z0-9]|[^\x00-\x7f]|\\.)+"
unescape(s) = replace(s, r"\\(.)" => s"\1")
const ATTR = r"^\[\s*((?:[-_a-zA-Z0-9:]|\\.)+)\s*(?:([~|^$*]?=)\s*(?:\"([^\"]*)\"|'([^']*)'|([^\]\s]*))\s*(?:[iIsS]\s*)?)?\]"
# These are true of no element of a page that's drawn: there's no mouse, no keyboard, and nothing has been visited
const NEVER = Set(["hover", "active", "focus", "focus-visible", "focus-within", "visited", "target", "checked", "disabled", "indeterminate",
                   "before", "after", "first-line", "first-letter", "selection", "placeholder", "placeholder-shown", "marker", "backdrop"])

"`a` and `b` of an+b, as :nth-child writes them, or nothing"
nth(s) = begin
  s = replace(lowercase(strip(s)), " " => "")
  s == "odd" && return (2, 1)
  s == "even" && return (2, 0)
  m = match(r"^([+-]?\d*)n([+-]\d+)?$", s)
  m === nothing && return (b = tryparse(Int, s)) === nothing ? nothing : (0, b)
  a = m[1] in ("", "+") ? 1 : m[1] == "-" ? -1 : Base.parse(Int, m[1])
  (a, m[2] === nothing ? 0 : Base.parse(Int, m[2]))
end

"The part of a selector at the start of `s`, and the rest of `s`, or nothing when it can't be read"
compound(s::AbstractString) = begin
  tag, id = "", ""
  classes, attrs, pseudos = String[], Tuple{String,String,String}[], Tuple{Symbol,Any}[]
  any = false
  while !isempty(s)
    c = s[1]
    if c == '*'
      s = SubString(s, 2)
    elseif c == '#' || c == '.'
      m = match(NAME, SubString(s, 2))
      m === nothing && return nothing
      c == '#' ? (id = unescape(m.match)) : push!(classes, unescape(m.match))
      s = SubString(s, 2 + ncodeunits(m.match))
    elseif c == '['
      m = match(ATTR, s)
      m === nothing && return nothing
      push!(attrs, (lowercase(unescape(m[1])), something(m[2], ""), String(something(m[3], m[4], m[5], ""))))
      s = SubString(s, 1 + ncodeunits(m.match))
    elseif c == ':'
      m = match(r"^::?([-a-zA-Z]+)", s)
      m === nothing && return nothing
      name = lowercase(m[1])
      s = SubString(s, 1 + ncodeunits(m.match))
      inside = nothing
      if startswith(s, '(')
        stop = closing(s, 1, '(', ')')
        stop > lastindex(s) && return nothing
        inside = strip(SubString(s, 2, prevind(s, stop)))
        s = SubString(s, nextind(s, stop))
      end
      if name in NEVER || startswith(name, "-")
        push!(pseudos, (:never, nothing))
      elseif name in ("first-child", "last-child", "only-child", "root", "empty", "first-of-type", "last-of-type")
        push!(pseudos, (Symbol(replace(name, '-' => '_')), nothing))
      elseif name in ("link", "any-link")
        push!(pseudos, (:link, nothing))
      elseif name in ("nth-child", "nth-last-child") && inside !== nothing
        ab = nth(inside)
        ab === nothing && return nothing
        push!(pseudos, (name == "nth-child" ? :nth : :nth_last, ab))
      elseif name == "not" && inside !== nothing
        inner = [compound(strip(p)) for p in pieces(inside, ',')]
        Base.any(x -> x === nothing || !isempty(x[2]), inner) && return nothing
        push!(pseudos, (:not, [first(x) for x in inner]))
      else
        return nothing
      end
    elseif (m = match(NAME, s)) !== nothing && !any && isempty(id) && isempty(classes) && isempty(attrs) && isempty(pseudos) && isempty(tag)
      tag = lowercase(unescape(m.match))
      s = SubString(s, 1 + ncodeunits(m.match))
    else
      break
    end
    any = true
  end
  any ? (Compound(tag, id, classes, attrs, pseudos), s) : nothing
end

"How specific a part of a selector is: how many ids, how many classes and the like, and how many tags"
weight(c::Compound) = begin
  inner = [weight(x) for (kind, xs) in c.pseudos if kind == :not for x in xs]
  not = isempty(inner) ? (0, 0, 0) : maximum(inner)
  (Int(!isempty(c.id)), length(c.classes) + length(c.attrs) + count(p -> p[1] != :not, c.pseudos), Int(!isempty(c.tag))) .+ not
end

"The selector that `s` writes, or nothing when it can't be read"
selector(s::AbstractString) = begin
  parts, links = Compound[], Char[]
  s = strip(s)
  isempty(s) && return nothing
  while true
    found = compound(s)
    found === nothing && return nothing
    part, rest = found
    push!(parts, part)
    isempty(strip(rest)) && break
    m = match(r"^\s*([>+~])\s*|^\s+", rest)
    m === nothing && return nothing
    push!(links, m[1] === nothing ? ' ' : m[1][1])
    s = SubString(rest, 1 + ncodeunits(m.match))
  end
  Selector(reverse(parts), reverse(links), reduce((a, b) -> a .+ b, weight.(parts)))
end

# --- which elements a selector is for -----------------------------------------------------

"The elements beside `e` in its parent, and which of them `e` is"
siblings(e::Element) = begin
  e.parent === nothing && return (Element[e], 1)
  all = Element[c for c in e.parent.children if c isa Element]
  (all, something(findfirst(c -> c === e, all), 1))
end

"The element before `e` in its parent, or nothing"
before(e::Element) = begin
  all, i = siblings(e)
  i > 1 ? all[i-1] : nothing
end

compare(how, has, wants) =
  how == "" ? true : how == "=" ? has == wants : how == "~=" ? wants in split(has) : how == "|=" ? has == wants || startswith(has, wants * "-") :
  isempty(wants) ? false : how == "^=" ? startswith(has, wants) : how == "\$=" ? endswith(has, wants) : occursin(wants, has)

nth_ok((a, b), i) = a == 0 ? i == b : (i - b) % a == 0 && (i - b) ÷ a >= 0

"True when the part `c` of a selector is for the element `e`"
matches(c::Compound, e::Element) = begin
  isempty(c.tag) || c.tag == e.tag || return false
  isempty(c.id) || attr(e, "id") == c.id || return false
  if !isempty(c.classes)
    has = split(attr(e, "class"))
    all(k -> k in has, c.classes) || return false
  end
  for (name, how, wants) in c.attrs
    haskey(e.attrs, name) && compare(how, e.attrs[name], wants) || return false
  end
  for (kind, arg) in c.pseudos
    ok = if kind == :never
      false
    elseif kind == :link
      e.tag == "a" && haskey(e.attrs, "href")
    elseif kind == :root
      e.parent === nothing
    elseif kind == :empty
      !any(n -> n isa Element || !isempty(n.text), e.children)
    elseif kind == :not
      !any(x -> matches(x, e), arg)
    else
      all, i = siblings(e)
      kind == :first_child ? i == 1 : kind == :last_child ? i == length(all) : kind == :only_child ? length(all) == 1 :
      kind == :nth ? nth_ok(arg, i) : kind == :nth_last ? nth_ok(arg, length(all) - i + 1) :
      kind == :first_of_type ? findfirst(x -> x.tag == e.tag, all) == i : findlast(x -> x.tag == e.tag, all) == i
    end
    ok || return false
  end
  true
end

"True when the selector `s` is for the element `e`"
matches(s::Selector, e::Element) = matches(s.parts[1], e) && rest(s, 1, e)

"True when the parts of `s` after part `i`, which is for `e`, are for the elements round `e`"
rest(s::Selector, i, e::Element) = begin
  i > length(s.links) && return true
  link, part = s.links[i], s.parts[i+1]
  if link == '>'
    p = e.parent
    p !== nothing && matches(part, p) && rest(s, i + 1, p)
  elseif link == ' '
    p = e.parent
    while p !== nothing
      matches(part, p) && rest(s, i + 1, p) && return true
      p = p.parent
    end
    false
  elseif link == '+'
    b = before(e)
    b !== nothing && matches(part, b) && rest(s, i + 1, b)
  else
    all, at = siblings(e)
    any(b -> matches(part, b) && rest(s, i + 1, b), @view all[1:at-1])
  end
end

# --- @media -------------------------------------------------------------------------------

"How many px a length of a media query is"
media_px(v) = begin
  m = match(r"^([0-9.]+)\s*(px|em|rem|pt)?$", strip(lowercase(v)))
  m === nothing && return nothing
  x = tryparse(Float64, m[1])
  x === nothing ? nothing : x * (m[2] in ("em", "rem") ? 16 : m[2] == "pt" ? 4 / 3 : 1)
end

# How many pixels the screen has to the px. A page is drawn for a screen like a Mac's.
const DENSITY = 2.0

"How many pixels to the px a media query's `2`, `2dppx` or `192dpi` means"
density(v) = begin
  m = match(r"^([0-9.]+)\s*(dppx|x|dpi|dpcm)?$", strip(lowercase(v)))
  m === nothing && return nothing
  x = tryparse(Float64, m[1])
  x === nothing ? nothing : m[2] == "dpi" ? x / 96 : m[2] == "dpcm" ? x * 2.54 / 96 : x
end

"True when a page `wide` px wide, on a screen, is what the media query `q` asks for"
media(q::AbstractString, wide) = begin
  isempty(strip(q)) && return true
  any(split(lowercase(q), ',')) do one
    one = strip(one)
    negate = startswith(one, "not ")
    one = strip(replace(one, r"^(not|only)\s+" => ""))
    ok = all(split(one, r"\s+and\s+")) do part
      part = strip(part)
      part in ("all", "screen", "") && return true
      m = match(r"^\(\s*([a-z-]+)\s*(?::\s*([^)]+?)\s*)?\)$", part)
      m === nothing && return false
      name, v = m[1], m[2]
      v === nothing && return name == "color"
      name in ("max-width", "max-device-width") ? (x = media_px(v)) !== nothing && wide <= x :
      name in ("min-width", "min-device-width") ? (x = media_px(v)) !== nothing && wide >= x :
      name == "prefers-color-scheme" ? v == "light" : name == "orientation" ? v == "landscape" :
      name in ("-webkit-min-device-pixel-ratio", "min-device-pixel-ratio", "min-resolution") ? (x = density(v)) !== nothing && DENSITY >= x :
      name in ("-webkit-max-device-pixel-ratio", "max-device-pixel-ratio", "max-resolution") ? (x = density(v)) !== nothing && DENSITY <= x : false
    end
    negate ? !ok : ok
  end
end
