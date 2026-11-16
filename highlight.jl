# Splits a line of code into the parts a code block draws in different colours:
# comments, strings, numbers, keywords, the names of functions being called and
# the names of types. It reads one line at a time and knows a little about each
# language, so it's quick, and it's wrong about things that run over several
# lines, like a string in triple quotes.
#
# Code in a string, like the $(c.count) in "Clicked $(c.count) times", has the
# colours of code. Its $( and ) have the colour of a keyword.

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

"""
Marks the parts of the code that starts at `chars[i]`. A mark is the first and
last character of a part and its kind. It stops at the end of the line, or at a
`close` that has no partner, like the ) at the end of \$(x). It gives the place it
stopped.
"""
code!(marks, chars, lang, i, close=nothing) = begin
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
      i = string!(marks, chars, lang, i) + 1
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
that doesn't close runs to the end of the line. Code in the string, like \$(x) in
Julia, gets the marks that code gets, and the \$( and ) get the colour of a keyword.
A name like \$x has the colour of a name.
"""
string!(marks, chars, lang, i) = begin
  n = length(chars)
  q = chars[i]
  how = holds(lang, chars, i)
  from = i                          # the first character of the string that has no mark yet
  text!(j) = from < j && push!(marks, (from, j - 1, :string))
  j = i + 1
  while j <= n
    c = chars[j]
    d = j < n ? chars[j+1] : '\0'
    if c == '\\'
      j += 2
    elseif c == q
      push!(marks, (from, j, :string))
      return j
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
  n
end

"The parts of one line of code written in the language named `name`"
tokens(text::AbstractString, name::AbstractString) = begin
  lang = get(LANGUAGES, lowercase(name), nothing)
  lang === nothing && return [Token(0, String(text), :plain)]
  chars = collect(text)
  marks = Tuple{Int,Int,Symbol}[]
  code!(marks, chars, lang, 1)
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

export Token, tokens
