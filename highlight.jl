# Splits a line of code into the parts a code block draws in different colours:
# comments, strings, numbers, keywords, the names of functions being called and
# the names of types. It reads one line at a time and knows a little about each
# language, so it's quick. Of the things that run over several lines, it knows
# only a string in three quotes, like a docstring: `left_open` says when a line
# leaves one open, and `tokens` reads the next line from inside it.
#
# Code in a string, like the $(c.count) in "Clicked $(c.count) times", has the
# colours of code. Its $( and ) have the colour of a keyword.
#
# CSS and Less are read a line at a time too: see "CSS and Less" below. What a
# line of them leaves open, like a comment, is a character, as the quote of a
# string in three quotes is for the other languages.

"What a language's code looks like"
struct Language
  keywords::Set{String}
  literals::Set{String}      # words like true and nothing
  comment::String            # what starts a comment that runs to the end of the line
  quotes::String             # the characters that open and close a string
  chars::Bool                # true when 'x' is one character, not a string
  bang::Bool                 # true when a name can end in !
  code::Symbol               # how a string holds code: :julia, :python, :javascript, :shell or :none
end

Language(keywords, literals; comment="//", quotes="\"'", chars=false, bang=false, code=:none) =
  Language(Set(split(keywords)), Set(split(literals)), comment, quotes, chars, bang, code)

const JULIA = Language("""abstract baremodule begin break catch const continue do else elseif end export finally for
                          function global if import in isa let local macro module mutable primitive quote return
                          struct try type using where while""",
                       "true false nothing missing Inf NaN pi", comment="#", quotes="\"`", chars=true, bang=true,
                       code=:julia)

const PYTHON = Language("""and as assert async await break class continue def del elif else except finally for from
                           global if import in is lambda nonlocal not or pass raise return try while with yield""",
                        "True False None self", comment="#", code=:python)

const JAVASCRIPT = Language("""as async await break case catch class const continue default delete do else enum export
                               extends finally for from function if implements import in instanceof interface let new
                               of return static switch throw try type typeof var void while yield""",
                            "true false null undefined this super NaN Infinity", quotes="\"'`", code=:javascript)

const RUST = Language("""as async await break const continue crate dyn else enum extern fn for if impl in let loop match
                         mod move mut pub ref return static struct trait type unsafe use where while""",
                      "true false self Self None Some Ok Err", quotes="\"", chars=true, bang=true)

const C = Language("""auto break case catch class const continue default defer delete do else enum extern final for
                      func go goto if import inline interface map namespace new package private protected public
                      range return sizeof static struct switch template throw try typedef union using var virtual
                      void volatile while""",
                   "true false null nil nullptr NULL this self", chars=true)

const SHELL = Language("case do done elif else esac export fi for function if in local return then until while",
                       "true false", comment="#", code=:shell)

const SQL = Language("""select from where and or not null insert into values update set delete create table drop alter
                        add join left right inner outer on as group by order having limit distinct union index
                        primary key references default is in like between exists""",
                     "true false", comment="--", quotes="'\"")

const DATA = Language("", "true false null yes no", comment="#")

const LANGUAGES = Dict{String,Language}()
for (names, language) in ("julia jl ui" => JULIA, "python py" => PYTHON,
                          "javascript js jsx mjs cjs typescript ts tsx" => JAVASCRIPT, "rust rs" => RUST,
                          "c cpp c++ cc h hpp go java swift kotlin kt csharp cs zig" => C,
                          "bash sh zsh shell fish" => SHELL, "sql" => SQL, "json yaml yml toml" => DATA)
  for name in split(names)
    LANGUAGES[name] = language
  end
end

"One part of a line of code. `kind` is :plain, :comment, :string, :number, :keyword, :call or :type."
struct Token
  col::Int       # the column of its first character
  text::String
  kind::Symbol
end

isname(c::Char) = isletter(c) || isdigit(c) || c == '_'

"True when the characters of `s` are at `chars[i]`"
starts(chars, s, i) = !isempty(s) && i + length(s) - 1 <= length(chars) && all(chars[i+k-1] == c for (k, c) in enumerate(s))

"Where the name that starts at `chars[i]` ends"
namend(chars, lang, i) = begin
  n = length(chars)
  j = i
  while j < n && (isname(chars[j+1]) || (lang.bang && chars[j+1] == '!' && !(j + 1 < n && chars[j+2] == '=')))
    j += 1
  end
  j
end

"True when the string that opens at `chars[i]` is a Python f-string, like f\"{x}\" or rf'{x}'"
fstring(chars, i) = begin
  k = i - 1
  while k >= 1 && isletter(chars[k]); k -= 1 end
  (k < 1 || !isname(chars[k])) && lowercase(String(chars[k+1:i-1])) in ("f", "rf", "fr")
end

"""
How the string that opens at `chars[i]` holds code: :julia, :python, :javascript,
:shell or :none. A Julia string with a name in front, like raw"..." or r"...", has
no code in it. In JavaScript only a string in backticks has code, and in a shell
only a string in double quotes.
"""
holds(lang, chars, i) = begin
  q = chars[i]
  lang.code == :julia ? (i > 1 && isname(chars[i-1]) ? :none : :julia) :
  lang.code == :python ? (fstring(chars, i) ? :python : :none) :
  lang.code == :javascript ? (q == '`' ? :javascript : :none) :
  lang.code == :shell ? (q == '"' ? :shell : :none) : :none
end

const NUMBER = r"^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(\.\d+)?([eE][+-]?\d+)?)"

"True when three of the quote `q` open a string in `lang` that can run over several lines, like a docstring"
triples(lang, q) = (lang.code == :julia && q == '"') || (lang.code == :python && q in "\"'")

"True when the string that opens at `chars[i]` opens with three quotes"
triple_at(lang, chars, i) = triples(lang, chars[i]) && i + 2 <= length(chars) && chars[i+1] == chars[i] && chars[i+2] == chars[i]

"""
Marks the parts of the code that starts at `chars[i]`. A mark is the first and
last character of a part and its kind. It stops at the end of the line, or at a
`close` that has no partner, like the ) at the end of \$(x). It gives the place it
stopped. `left` gets the quote of a string in three quotes that's still open at
the end of the line.
"""
code!(marks, chars, lang, i, close=nothing, left=Ref('\0')) = begin
  n = length(chars)
  open = close == ')' ? '(' : close == '}' ? '{' : nothing
  depth = 0
  while i <= n
    c = chars[i]
    if c == close
      depth == 0 && return i
      depth -= 1
      i += 1
    elseif c == open
      depth += 1
      i += 1
    elseif starts(chars, lang.comment, i)
      push!(marks, (i, n, :comment))
      return n + 1
    elseif c in lang.quotes
      k = string!(marks, chars, lang, i)
      close === nothing && k > n && triple_at(lang, chars, i) && (left[] = c)
      i = k + 1
    elseif c == '\'' && lang.chars
      # 'x' and '\n' are characters. A lone ' is something else, like a transpose.
      j = i + 2 <= n && chars[i+1] != '\\' && chars[i+2] == '\'' ? i + 2 :
          i + 3 <= n && chars[i+1] == '\\' && chars[i+3] == '\'' ? i + 3 : 0
      j == 0 || push!(marks, (i, j, :string))
      i = max(i, j) + 1
    elseif isdigit(c) && (i == 1 || !isname(chars[i-1]))
      j = i + length(match(NUMBER, String(chars[i:end])).match) - 1
      push!(marks, (i, j, :number))
      i = j + 1
    elseif isletter(c) || c == '_' || (c == '@' && i < n && isletter(chars[i+1]))
      j = namend(chars, lang, i)
      word = String(chars[i:j])
      kind = word in lang.keywords ? :keyword :
             word in lang.literals ? :number :
             c == '@' || (j < n && chars[j+1] == '(') ? :call :
             isuppercase(c) && any(islowercase, word) ? :type : :plain
      kind == :plain || push!(marks, (i, j, kind))
      i = j + 1
    else
      i += 1
    end
  end
  n + 1
end

"""
Marks the string that opens at `chars[i]` and gives the place it closes. A string
that doesn't close runs to the end of the line, and gives the place after it.
Three quotes, like \"\"\", open a string that only three quotes close. `open` is
the quote of a string in three quotes that a line above opened: the string then
starts at `chars[i]`, which isn't a quote of its own. Code in the string, like \$(x) in
Julia, gets the marks that code gets, and the \$( and ) get the colour of a keyword.
A name like \$x has the colour of a name.
"""
string!(marks, chars, lang, i, open=nothing) = begin
  n = length(chars)
  q = open === nothing ? chars[i] : open
  triple = open !== nothing || triple_at(lang, chars, i)
  # A string that a line above opened can't be raw"..." or a Python f-string, as far as this line knows
  how = open === nothing ? holds(lang, chars, i) : lang.code == :julia ? :julia : :none
  from = i                          # the first character of the string that has no mark yet
  text!(j) = from < j && push!(marks, (from, j - 1, :string))
  j = open !== nothing ? i : triple ? i + 3 : i + 1
  while j <= n
    c = chars[j]
    d = j < n ? chars[j+1] : '\0'
    if c == '\\'
      j += 2
    elseif c == q && (!triple || (j + 2 <= n && chars[j+1] == q && chars[j+2] == q))
      k = triple ? j + 2 : j
      push!(marks, (from, k, :string))
      return k
    elseif how == :python && c == '{' && d == '{'
      j += 2                        # {{ is a {
    elseif (how in (:julia, :shell) && c == '$' && d == '(') || (how == :javascript && c == '$' && d == '{') ||
           (how == :python && c == '{')
      # Code: $(x) in Julia or a shell, ${x} in JavaScript, {x} in Python
      text!(j)
      w = how == :python ? 1 : 2
      push!(marks, (j, j + w - 1, :keyword))
      k = code!(marks, chars, lang, j + w, chars[j+w-1] == '(' ? ')' : '}')
      k <= n && push!(marks, (k, k, :keyword))
      from = j = k + 1
    elseif how == :shell && c == '$' && d == '{'
      # ${name} and ${name:-word} in a shell are a name, not code
      text!(j)
      k = something(findnext(==('}'), chars, j + 2), n)
      push!(marks, (j, j + 1, :keyword))
      k > j + 1 && chars[k] == '}' && push!(marks, (k, k, :keyword))
      from = j = k + 1
    elseif how in (:julia, :shell) && c == '$' && (isletter(d) || d == '_' || (how == :shell && (isdigit(d) || d in "@*#?\$!-")))
      # A name, like $x, or $1 and $? in a shell
      text!(j)
      push!(marks, (j, j, :keyword))
      from = j = (isletter(d) || d == '_' ? namend(chars, lang, j + 1) : j + 1) + 1
    else
      j += 1
    end
  end
  text!(n + 1)
  n + 1
end

"""
The parts of one line of code written in the language named `name`. `open` is
the quote of a string in three quotes that a line above left open, like the
middle of a docstring, or '\\0' when there's none: see `left_open`.
"""
tokens(text::AbstractString, name::AbstractString, open::Char='\0') = first(read_line(text, name, open))

"""
The quote of the string in three quotes that's still open at the end of the
line `text`, or '\\0' when there's none. `open` is the quote of the one that's
open at its start. A line with no three quotes leaves things as they were, so
for most lines this is quick. For CSS and Less it's what the line leaves open:
see "CSS and Less".
"""
left_open(text::AbstractString, name::AbstractString, open::Char='\0') =
  iscss(name) || occursin("\"\"\"", text) || occursin("'''", text) ? last(read_line(text, name, open)) : open

"The parts of the line `text`, and what `left_open` says of it"
read_line(text, name, open) = begin
  if iscss(name)
    chars = collect(text)
    marks = Tuple{Int,Int,Symbol}[]
    # Nothing open, '\0', is the same as being among the rules
    left = css!(marks, chars, 1, length(chars), open in CSS_OPENS ? open : IN_STYLE, lowercase(name) == "less")
    return (marked(chars, marks), left == IN_STYLE ? '\0' : left)
  end
  lang = get(LANGUAGES, lowercase(name), nothing)
  lang === nothing && return ([Token(0, String(text), :plain)], '\0')
  chars = collect(text)
  marks = Tuple{Int,Int,Symbol}[]
  left = Ref('\0')
  i = 1
  if open != '\0' && triples(lang, open)
    i = string!(marks, chars, lang, 1, open) + 1
    # A line that doesn't close the string is all string
    i > length(chars) + 1 && (left[] = open)
  end
  i <= length(chars) && code!(marks, chars, lang, i, nothing, left)
  (marked(chars, marks), left[])
end

"Where `s` starts in `chars`, from `i` up to `upto`, or nothing. With `anycase`, capitals are the same as small letters."
found(chars, s, i, upto=length(chars); anycase=false) = begin
  n = length(s)
  for k in i:upto-n+1
    all(j -> anycase ? lowercase(chars[k+j-1]) == s[j] : chars[k+j-1] == s[j], 1:n) && return k
  end
  nothing
end

# --- CSS and Less -----------------------------------------------------------------------------
#
# A selector, like `.note p` or `a:hover`, has the colour of a keyword, and so
# has the name of a rule like @media. A property, like the color of `color: red`,
# has the colour of a type. In its value a number, like 2px or #a6c8e8, has the
# colour of a number, and a function, like the var of var(--ink), of a call.
#
# Less has more. A comment can start with // and run to the end of the line. A
# variable that's set, like @gap in `@gap: 4px;`, has the colour of a property,
# and a mixin that's used, like `.rounded(4px);`, the colour of a call. The @{
# and } of @{name}, which puts a variable's value in a selector or a string,
# have the colour of a keyword.
#
# What a line leaves open:

const IN_STYLE = 'c'               # nothing: the line starts among the rules
const IN_STYLE_COMMENT = 'C'       # a comment among them, which */ ends
const IN_STYLE_VALUE = 'v'         # a property's value, which ; ends, as in a list of fonts on several lines
const IN_STYLE_VALUE_COMMENT = 'V' # a comment in a value
const CSS_OPENS = (IN_STYLE, IN_STYLE_COMMENT, IN_STYLE_VALUE, IN_STYLE_VALUE_COMMENT)

"The rules of CSS and Less that a ( can follow, like @media(min-width: 600px)"
const AT_RULES = Set(["media", "import", "supports", "container", "layer", "document", "plugin", "scope"])

"True when `name` is a language that's read as CSS"
iscss(name) = lowercase(name) in ("css", "less")

"The place of the first character from `chars[i]` that isn't a space, or `upto + 1`"
unspaced(chars, i, upto) = begin
  while i <= upto && isspace(chars[i]) i += 1 end
  i
end

"The place after the name of letters, digits, _ and - that goes on at `chars[i]`"
cssname(chars, i, upto) = begin
  while i <= upto && (isname(chars[i]) || chars[i] == '-') i += 1 end
  i
end

"""
Marks the comment that opens with /* at `chars[i]`, or at `from` when a line
above opened it. Gives the place after its */, or nothing when it doesn't close
by `upto`.
"""
comment!(marks, chars, i, upto, from=i + 2) = begin
  k = found(chars, "*/", from, upto)
  k === nothing && (push!(marks, (i, upto, :comment)); return nothing)
  push!(marks, (i, k + 1, :comment))
  k + 2
end

"""
Marks the CSS from `chars[i]` to `chars[upto]`, which starts in `state`: one of
the characters above. `less` is true for Less. Gives what's open at `upto`.
"""
css!(marks, chars, i, upto, state, less=false) = begin
  # A line that starts a rule or sets a property isn't more of the value above it, which lacked its ;
  state == IN_STYLE_VALUE && fresh(chars, i, upto) && (state = IN_STYLE)
  while i <= upto
    c = chars[i]
    if state in (IN_STYLE_COMMENT, IN_STYLE_VALUE_COMMENT)
      k = comment!(marks, chars, i, upto, i)
      k === nothing && return state
      i, state = k, state == IN_STYLE_COMMENT ? IN_STYLE : IN_STYLE_VALUE
    elseif state == IN_STYLE_VALUE
      i, state = part!(marks, chars, i, upto, :value, less)
    elseif isspace(c) || c in ";{}"
      i += 1
    elseif c == '/' && i < upto && chars[i+1] == '*'
      k = comment!(marks, chars, i, upto)
      k === nothing && return IN_STYLE_COMMENT
      i = k
    elseif less && c == '/' && i < upto && chars[i+1] == '/'
      push!(marks, (i, upto, :comment))
      return state
    else
      i, state = statement!(marks, chars, i, upto, less)
    end
  end
  state
end

"""
Where the rule or the property that starts at `chars[i]` ends: the place of the
;, { or } that ends it, or `upto + 1` when it goes on past the end of the line.
One in a string or between brackets doesn't end it.
"""
css_end(chars, i, upto) = begin
  depth, q = 0, '\0'
  while i <= upto
    c = chars[i]
    if q != '\0'
      c == '\\' ? (i += 1) : c == q && (q = '\0')
    elseif c == '"' || c == '\''
      q = c
    elseif c == '@' && i < upto && chars[i+1] == '{'
      i = something(findnext(==('}'), view(chars, 1:upto), i), upto)   # the @{name} of Less
    elseif c == '(' || c == '['
      depth += 1
    elseif c == ')' || c == ']'
      depth = max(depth - 1, 0)
    elseif depth == 0 && c in ";{}"
      return i
    end
    i += 1
  end
  upto + 1
end

"""
When the text from `chars[i]` sets a property, like `color: red`, the place of
the property's last character and of its colon. Else nothing. The text ends at
`k`, the place of `stop`: its ;, { or }, or '\\0' at the end of the line.
"""
declared(chars, i, k, upto, stop) = begin
  stop == '{' && return nothing                # a selector, like a:hover {
  j = i
  j < k && chars[j] in "*_" && (j += 1)        # an old trick for Internet Explorer, like *zoom: 1
  (j < k && (isletter(chars[j]) || chars[j] == '-')) || return nothing
  j = cssname(chars, j, k - 1)
  last = j - 1
  while j < k && chars[j] in " \t" j += 1 end
  (j < k && chars[j] == ':') || return nothing
  # At the end of a line, a:hover is more likely a selector that goes on below than a property set to hover
  stop == '\0' && j < upto && !isspace(chars[j+1]) && return nothing
  (last, j)
end

"""
True when the line from `chars[i]`, which starts in the value of a property,
starts a rule or sets a property of its own: the value above lacked its ;
"""
fresh(chars, i, upto) = begin
  i = unspaced(chars, i, upto)
  i > upto && return false
  k = css_end(chars, i, upto)
  stop = k <= upto ? chars[k] : '\0'
  declared(chars, i, k, upto, stop) !== nothing || (stop == '{' && !(chars[i] in "{("))
end

"""
Marks the rule or the property that starts at `chars[i]`: a selector, like
`.note p {`, a rule like `@media print {`, or a property and its value, like
`color: red;`. In Less it can be a variable that's set, like `@gap: 4px;`, or a
mixin that's used, like `.rounded(4px);`. Gives where it stopped, and what's
open there.
"""
statement!(marks, chars, i, upto, less) = begin
  k = css_end(chars, i, upto)
  stop = k <= upto ? chars[k] : '\0'
  if chars[i] == '@' && i < upto && chars[i+1] != '{'
    j = i + 1
    while j <= upto && (isname(chars[j]) || chars[j] in "-@") j += 1 end
    after = unspaced(chars, j, upto)
    next = after <= upto ? chars[after] : '\0'
    if less && next == ':'
      push!(marks, (i, j - 1, :type))          # a variable that's set
      return part!(marks, chars, after + 1, upto, :value, less)
    end
    # A rule, like @media, or in Less a set of rules that a variable holds, which is used, like @rules();
    called = less && j <= upto && chars[j] == '(' && !(String(chars[i+1:j-1]) in AT_RULES)
    push!(marks, (i, j - 1, called ? :call : :keyword))
    return part!(marks, chars, j, upto, :prelude, less)
  end
  property = declared(chars, i, k, upto, stop)
  if property !== nothing
    push!(marks, (i, property[1], :type))
    return part!(marks, chars, property[2] + 1, upto, :value, less)
  end
  part!(marks, chars, i, upto, less && stop in (';', '}') && chars[i] in ".#" ? :mixin : :selector, less)
end

"True when the ( at `chars[i]` follows a pseudo-class, like :not( or :nth-child("
pseudo_before(chars, i) = begin
  k = i - 1
  while k >= 1 && (isname(chars[k]) || chars[k] == '-') k -= 1 end
  k >= 1 && k < i - 1 && chars[k] == ':'
end

"""
Marks a part of a rule, from `chars[i]`. `how` says what it is: :selector, like
`a:hover > .note`; :mixin, a mixin of Less that's used, like `.rounded(4px)`;
:value, the value of a property, like `0 2px var(--gap)`; or :prelude, what
follows the name of a rule, like the `screen and (min-width: 600px)` of @media.
It stops at the ;, { or } that ends the part, or at `upto`. Gives where it
stopped, and what's open there.
"""
part!(marks, chars, i, upto, how, less) = begin
  start = how
  inside = Symbol[]          # for each ( or [ that's open, what the part is outside it
  while i <= upto
    c = chars[i]
    d = i < upto ? chars[i+1] : '\0'
    if c == '/' && d == '*'
      k = comment!(marks, chars, i, upto)
      k === nothing && return upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE_COMMENT : IN_STYLE_COMMENT
      i = k
    elseif less && c == '/' && d == '/'
      push!(marks, (i, upto, :comment))
      return upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE : IN_STYLE
    elseif c == '"' || c == '\'' || (less && c == '~' && (d == '"' || d == '\''))
      i = quoted!(marks, chars, i, upto, less) + 1
    elseif less && c == '@' && d == '{'
      i = interpolated!(marks, chars, i, upto) + 1
    elseif isempty(inside) && c in ";{}"
      return i, IN_STYLE
    elseif c == '(' || (c == '[' && how == :selector)
      push!(inside, how)
      how = c == '[' ? :attribute :
            how == :mixin || (how == :selector && less && !pseudo_before(chars, i)) ? :value :   # a mixin's parameters
            how
      i += 1
    elseif !isempty(inside) && (c == ']') == (how == :attribute) && c in ")]"
      how = pop!(inside)
      i += 1
    elseif c == '!' && found(chars, "important", i + 1, min(upto, i + 9); anycase=true) == i + 1
      push!(marks, (i, i + 9, :keyword))
      i += 10
    elseif c == '@' && (isletter(d) || d in "@-_")
      # A variable of Less, like @gap, which is set when a : follows it, as a mixin's parameter is
      k = cssname(chars, i + 1, upto)
      after = unspaced(chars, k, upto)
      next = after <= upto ? chars[after] : '\0'
      next in ":(" && push!(marks, (i, k - 1, next == ':' ? :type : :call))
      i = k
    elseif c == '#' && how in (:value, :prelude) && isname(d)
      k = cssname(chars, i + 1, upto)
      push!(marks, (i, k - 1, :number))        # a colour, like #a6c8e8
      i = k
    elseif c in ".#" && how in (:selector, :mixin) && (isname(d) || d == '-')
      k = cssname(chars, i + 1, upto)
      push!(marks, (i, k - 1, how == :mixin ? :call : :keyword))   # a class or an id
      i = k
    elseif c == ':' && how == :selector && (isletter(d) || d in ":-")
      k = cssname(chars, d == ':' ? i + 2 : i + 1, upto)
      push!(marks, (i, k - 1, :keyword))       # a pseudo-class, like :hover, or ::before
      i = k
    elseif c == '&' && how == :selector
      push!(marks, (i, i, :keyword))           # the selector of the rule this one is in
      i += 1
    elseif (isdigit(c) || (c in ".-+" && isdigit(d))) && (i == 1 || !isname(chars[i-1]))
      k = i + 1
      while k <= upto && (isname(chars[k]) || chars[k] in ".%") k += 1 end
      push!(marks, (i, k - 1, :number))
      i = k
    elseif isletter(c) || c == '_' || (c == '-' && (isletter(d) || d in "-_")) || (less && c == '%' && d == '(')
      k = cssname(chars, i + 1, upto)
      word = lowercase(String(chars[i:k-1]))
      next = k <= upto ? chars[k] : '\0'
      if how == :selector
        push!(marks, (i, k - 1, :keyword))     # a tag, like p
        less && word == "when" && (how = :prelude)   # a guard, like .m(@a) when (@a > 0)
      elseif how == :attribute
        j = i - 1
        while j >= 1 && chars[j] == ' ' j -= 1 end
        push!(marks, (i, k - 1, j >= 1 && chars[j] == '=' ? :string : :type))
      elseif next == '('
        push!(marks, (i, k - 1, :call))
        j = unspaced(chars, k + 1, upto)
        if word == "url" && j <= upto && !(chars[j] in "\"'@")
          # The address in url(...) is a string, though it has no quotes, unless it's a variable of Less
          close = something(findnext(==(')'), view(chars, 1:upto), j), upto + 1)
          close > j && push!(marks, (j, close - 1, :string))
          i = close + 1
          continue
        end
      elseif (j = unspaced(chars, k, upto)) <= upto && chars[j] == ':'
        push!(marks, (i, k - 1, :type))        # a feature, like the min-width of (min-width: 600px)
      elseif how == :prelude && word in ("and", "or", "not", "only", "when")
        push!(marks, (i, k - 1, :keyword))
      end
      i = k
    else
      i += 1
    end
  end
  upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE : IN_STYLE
end

"""
Marks the string that opens at `chars[i]` and gives the place of the quote that
closes it, or `upto`. In Less a ~ can come before it, and @{name} in it puts a
variable's value there.
"""
quoted!(marks, chars, i, upto, less) = begin
  from = i
  i += chars[i] == '~'
  q = chars[i]
  j = i + 1
  while j <= upto && chars[j] != q
    if chars[j] == '\\'
      j += 2
    elseif less && chars[j] == '@' && j < upto && chars[j+1] == '{'
      from < j && push!(marks, (from, j - 1, :string))
      j = interpolated!(marks, chars, j, upto) + 1
      from = j
    else
      j += 1
    end
  end
  j = min(j, upto)
  from <= j && push!(marks, (from, j, :string))
  j
end

"Marks the @{name} of Less that opens at `chars[i]`: its @{ and its } have the colour of a keyword. Gives the place of its }, or `upto`."
interpolated!(marks, chars, i, upto) = begin
  push!(marks, (i, i + 1, :keyword))
  k = i + 2
  while k <= upto && chars[k] != '}' k += 1 end
  k <= upto && push!(marks, (k, k, :keyword))
  min(k, upto)
end

"The tokens of the characters `chars`, which have the marks `marks`"
marked(chars, marks) = begin
  out = Token[]
  plain = 1                         # the first character that isn't in a token yet
  for (i, j, kind) in marks
    plain < i && push!(out, Token(plain - 1, String(chars[plain:i-1]), :plain))
    push!(out, Token(i - 1, String(chars[i:j]), kind))
    plain = j + 1
  end
  plain <= length(chars) && push!(out, Token(plain - 1, String(chars[plain:end]), :plain))
  out
end

export Token, tokens, left_open
