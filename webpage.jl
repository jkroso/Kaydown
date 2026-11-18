# Makes pictures of a page of HTML, as a browser draws it, and finds the link
# and the words at a point of a page.
#
# Ladder shows an email as it was sent with web/, which lays the email's HTML
# out itself. The email view uses the second half of this file for that
# page: `Shot`, `link`, `place`, `words`, `marks`, `word` and `paragraph`.
#
# The pictures are how Ladder showed an email before it had web/. They stay
# as a way to check web/ against a browser: the text file that comes with
# them says how big WebKit makes a page, and where it puts each letter.
#
# webpage.swift does the drawing, as a program of its own, because macOS only
# offers WebKit, its part that draws web pages, to Swift. The pictures are
# kept in a folder, so a page shows at once the next time:
#
#     p = picture!(folder, html, 700)
#     p.state         # :there, :coming, :failed or :none. Ask again while it's :coming.
#     s = shot(p.file)
#     s.wide, s.tall  # how big the whole page is, in px
#     s.strips        # the page from the top down, as PNG files: each file, and how tall it is
#     link(s, x, y)   # the link at a point of the page, with where it goes, or nothing
#
# The page's words can be selected and copied, as in a browser, though the page
# is a picture. The program says where each letter of the words is drawn. A
# place in the words is how many of their letters come before it: 0 is before
# the first one.
#
#     a = place(s, x, y)          # the place nearest a point of the page
#     words(s, a, b)              # the words between two places, as they're copied
#     marks(s, a, b)              # where the page draws them: a rectangle for each line
#     word(s, a), paragraph(s, a) # the places round the word or the paragraph at a place
#
# A page can be very tall, so its picture is in strips, which a window draws
# one under the other. The page is drawn without JavaScript. The program asks
# the web for nothing, so that the sender of an email can't tell when it's
# opened. Then a picture that the page has from a web site shows as an empty
# box. `remote(html)` is true for a page with such pictures, and
# `picture!(...; pictures=true)` fetches them.
#
# The Ladder app doesn't have the program in it. Run from its source, Ladder
# compiles webpage.swift the first time it's needed, which takes a few
# seconds, and keeps the program in a folder of the Mac's caches. That needs
# Swift, which comes with Xcode and its command line tools.

@use "./map" => Maps

const SOURCE = joinpath(@__DIR__, "webpage.swift")

"What to say when the pictures can't be made"
const FAILED = "Ladder can't draw this email as it was sent."
const NO_SWIFT = "Ladder needs Swift to draw an email as it was sent. It comes with Xcode's command line tools."

"What the program is compiled for: this Mac's kind of processor, and macOS 26, as Ladder's other programs are"
target() = "$(Sys.ARCH == :aarch64 ? "arm64" : "x86_64")-apple-macos26.0"

"The folder of the Mac's caches that keeps the program that's compiled from the source"
programs() = joinpath(homedir(), "Library", "Caches", "Ladder")

"""
The command that runs the program with `args`. The program is compiled from
the source, and kept in the folder `dir`. If it isn't compiled yet, the
command compiles it first.
"""
command(args; dir=programs()) = begin
  # A change to the source makes a program of a new name
  program = joinpath(dir, "webpage-program-" * string(hash(read(SOURCE)), base=16))
  isfile(program) && return `$program $args`
  mkpath(dir)
  # A program compiled from older source isn't needed. One that's being compiled from this source now is left alone.
  foreach(f -> startswith(f, "webpage-program-") && !startswith(f, basename(program)) && rm(joinpath(dir, f), force=true), readdir(dir))
  # It's compiled to a name of this run's own and renamed once it's whole, so a program that's there is always whole
  script = """swiftc -O -parse-as-library -target $(target()) "\$1" -o "\$2.\$\$" && mv "\$2.\$\$" "\$2" && p="\$2" && shift 2 && exec "\$p" "\$@" """
  `sh -c $script sh $SOURCE $program $args`
end

"""
Start the program that draws the HTML in the file `source` on a page `wide`
px wide. It writes each strip of the picture to a file whose name starts with
`stem`, then what it made to the file `out`, and why it failed to the file
`err`. This gives the program as it runs.
"""
run_program(source, wide, zoom, pictures, stem, out, err) =
  run(pipeline(command([(pictures ? ["--pictures"] : String[])..., "--zoom", string(zoom), string(wide), source, stem, out]),
               stdout=devnull, stderr=err), wait=false)

"""
The function that makes the pictures. It takes what `run_program` takes. It
gives a program that runs, or the number that a program which has finished
already ended with: 0 when the pictures are made, and 1 when they aren't. A
test puts a function of its own here, so that it uses neither the program nor
the web.
"""
const HELPER = Ref{Any}(run_program)

"Open the address `url` with the app that the Mac uses for it: a web page in the browser, and mailto: in the email app"
open_app(url) = (run(pipeline(`open $url`, stdout=devnull, stderr=devnull), wait=false); nothing)

"The function that opens a link of a page, given its address. A test puts a function of its own here."
const OPENER = Ref{Any}(open_app)

"Open the link of a page that goes to `url`"
open_link(url::AbstractString) = try OPENER[](url) catch; nothing end

"A rectangle of a page that's a link, in px from the page's top left corner, and where it goes"
const Link = @NamedTuple{left::Float64, top::Float64, wide::Float64, tall::Float64, url::String}

"""
A piece of the page's words that's drawn in one line: what goes before it when
it's copied (a new line `"\\n"`, a tab `"\\t"` between two cells of a row, or
`""`), its top and how tall it is in px, where each of its letters starts and
the last one ends, its letters, and its place in the words.
"""
const Words = @NamedTuple{before::String, top::Float64, tall::Float64, edges::Vector{Float64}, letters::Vector{Char}, from::Int}

"""
The pictures of a page: how wide and how tall the page is in px, each strip's
file with how tall it is, the page's links, and its words in the order that
the HTML has them.
"""
struct Shot
  wide::Int
  tall::Int
  strips::Vector{Pair{String,Int}}
  links::Vector{Link}
  words::Vector{Words}
end

"""
What the text file `path` says that the program made, as webpage.swift writes
it. It's nothing when the file says nothing that can be drawn, or one of its
strips is gone.
"""
shot(path) = begin
  isfile(path) || return nothing
  size, strips, links, pieces = nothing, Pair{String,Int}[], Link[], Words[]
  for line in eachline(path)
    parts = split(line, '\t')
    if parts[1] == "page" && length(parts) == 3
      size = (tryparse(Int, parts[2]), tryparse(Int, parts[3]))
    elseif parts[1] == "strip" && length(parts) == 3
      tall = tryparse(Int, parts[2])
      file = joinpath(dirname(path), parts[3])
      (tall === nothing || tall < 1 || !isfile(file)) && return nothing
      push!(strips, file => tall)
    elseif parts[1] == "link" && length(parts) == 6
      box = tryparse.(Float64, parts[2:5])
      any(isnothing, box) || push!(links, (left=box[1], top=box[2], wide=box[3], tall=box[4], url=String(parts[6])))
    elseif parts[1] == "text" && length(parts) == 6
      # A line that doesn't add up is left out, and the words go on without it
      top, tall = tryparse(Float64, parts[3]), tryparse(Float64, parts[4])
      edges = tryparse.(Float64, split(parts[5], ','))
      letters = collect(parts[6])
      (top === nothing || tall === nothing || any(isnothing, edges) || isempty(letters) || length(edges) != length(letters) + 1) && continue
      before = parts[2] == "line" ? "\n" : parts[2] == "tab" ? "\t" : ""
      push!(pieces, (before=before, top=top, tall=tall, edges=Float64.(edges), letters=letters, from=letter_count(pieces)))
    end
  end
  (size === nothing || any(isnothing, size) || isempty(strips) || sum(last, strips) != size[2]) && return nothing
  Shot(size[1], size[2], strips, links, pieces)
end

"The link at the point `(x, y)` of the page, in px from the page's top left corner, or nothing"
link(s::Shot, x, y) = begin
  # A link that's written later is drawn over one that's written before it
  i = findlast(l -> l.left <= x <= l.left + l.wide && l.top <= y <= l.top + l.tall, s.links)
  i === nothing ? nothing : s.links[i]
end

"How many letters the words `ws` have"
letter_count(ws) = isempty(ws) ? 0 : ws[end].from + length(ws[end].letters)
letter_count(s::Shot) = letter_count(s.words)

"How far the point `(x, y)` is from the line of words `w`, up or down. It's 0 for a point that's level with it."
off_line(w::Words, y) = y < w.top ? w.top - y : max(0.0, y - w.top - w.tall)
"How far the point `(x, y)` is from the words `w`, to the left or the right. It's 0 for a point over them."
off_words(w::Words, x) = x < w.edges[1] ? w.edges[1] - x : max(0.0, x - w.edges[end])

"""
The place in the page's words that's nearest the point `(x, y)` of the page,
in px from its top left corner. The point is in the line of words that it's
level with, or in the nearest line up or down. In that line, the place is
before the letter that the point is over, or after it when the point is over
its right half. Over the first line of words, it's the start of the words.
Under the last line, it's their end.
"""
place(s::Shot, x, y) = begin
  isempty(s.words) && return 0
  y < minimum(w -> w.top, s.words) && return 0
  y > maximum(w -> w.top + w.tall, s.words) && return letter_count(s)
  # A line can have more than one piece of words, like a word in bold, or the cells of a row of a table
  near = argmin(w -> off_line(w, y), s.words)
  w = argmin(w -> off_words(w, x), Iterators.filter(w -> level(w, near.top, near.tall), s.words))
  w.from + count(i -> (w.edges[i] + w.edges[i+1]) / 2 < x, eachindex(w.letters))
end

"True when the words `w` are in the same line as words whose top is `top` and that are `tall`: when most of the shorter is level with the other"
level(w::Words, top, tall) = min(w.top + w.tall, top + tall) - max(w.top, top) > min(w.tall, tall) / 2

"True when the point `(x, y)` of the page is over some of its words"
over_words(s::Shot, x, y) = any(w -> off_line(w, y) == 0 && off_words(w, x) == 0, s.words)

"The letters of `w` between the places `a` and `b` of the page's words, as how many of its letters come before each"
letters_between(w::Words, a, b) = (max(a - w.from, 0), min(b - w.from, length(w.letters)))

"""
The words of the page between the places `a` and `b`, as they're copied: with
a new line between two lines of the page that aren't one paragraph, and a tab
between two cells of a row of a table. A space that can't break a line is a
space, and no line ends with a space.
"""
words(s::Shot, a, b) = begin
  a, b = minmax(a, b)
  io = IOBuffer()
  for w in s.words
    lo, hi = letters_between(w, a, b)
    lo < hi || continue
    position(io) > 0 && print(io, w.before)
    print(io, String(w.letters[lo+1:hi]))
  end
  replace(replace(String(take!(io)), '\u00a0' => ' '), r" +(?=\n|$)" => "")
end

"""
Where the page draws its words between the places `a` and `b`: a rectangle for
each line, as the left, the top, how wide and how tall it is, in px. The words
of a line that are in more than one piece, like a word in bold, are one
rectangle. Two cells of a row of a table are two.
"""
marks(s::Shot, a, b) = begin
  a, b = minmax(a, b)
  out = NTuple{4,Float64}[]
  for w in s.words
    lo, hi = letters_between(w, a, b)
    lo < hi || continue
    left, right, top, bottom = w.edges[lo+1], w.edges[hi+1], w.top, w.top + w.tall
    if !isempty(out) && isempty(w.before)
      l, t, wide, tall = out[end]
      # Words that go on in the same line, to the right, are part of the same rectangle
      if left >= l + wide - 1 && level(w, t, tall)
        top, bottom = min(top, t), max(bottom, t + tall)
        out[end] = (l, top, max(right, l + wide) - l, bottom - top)
        continue
      end
    end
    push!(out, (left, top, right - left, bottom - top))
  end
  out
end

"Which piece of the page's words holds the letter after place `a`, or the last letter when `a` is the end of the words, or nothing"
words_at(s::Shot, a) = findlast(w -> w.from <= a, s.words)

isword(c::Char) = isletter(c) || isdigit(c) || c in ('_', '\'', '’')

"""
The places round the word at place `a` of the page's words, as two clicks
select it. Where there's no word, it's the letter after `a`.
"""
word(s::Shot, a) = begin
  i = words_at(s, a)
  i === nothing && return (a, a)
  w = s.words[i]
  k = a - w.from
  n = length(w.letters)
  # A place at the end of a piece of words, after its last letter, is in its last word
  k >= n && return n > 0 && isword(w.letters[n]) ? word(s, a - 1) : (a, a)
  isword(w.letters[k+1]) || return (a, a + 1)
  lo = hi = k
  while lo > 0 && isword(w.letters[lo]); lo -= 1 end
  while hi < n && isword(w.letters[hi+1]); hi += 1 end
  (w.from + lo, w.from + hi)
end

"""
The places round the paragraph at place `a` of the page's words, as three
clicks select it: the lines of words from the last one that starts a line of
its own, to the next one that does.
"""
paragraph(s::Shot, a) = begin
  i = words_at(s, a)
  i === nothing && return (a, a)
  lo = hi = i
  while lo > 1 && isempty(s.words[lo].before); lo -= 1 end
  while hi < length(s.words) && isempty(s.words[hi+1].before); hi += 1 end
  (s.words[lo].from, s.words[hi].from + length(s.words[hi].letters))
end

"""
True when the HTML has a picture, a font or a style sheet from a web site, so
that it looks as its sender meant only with what the web has for it.
"""
remote(html) = occursin(r"<(img|link|input|video)\b[^>]*\b(src|href|poster)\s*=\s*[\"']?\s*https?://|\bbackground\s*=\s*[\"']?\s*https?://|url\(\s*[\"']?\s*https?://"i, html)

"""
How webpage.swift draws a page. Make it one more with a change to the program
that changes its pictures, so that the pictures it made before are made again.
2: a table that's wider than the page is let be as narrow as the page.
3: a short page is as tall as its content, not 600 px.
4: the program says where the page's words are.
"""
const DRAWS = 4

"The text file in `folder` that says what was made of `html` on a page `wide` px wide"
file(folder, html, wide, zoom, pictures) = joinpath(folder, string(hash((html, wide, zoom, pictures, DRAWS)), base=16) * ".txt")

"""
The pictures of `html` on a page `wide` px wide, kept in `folder`. `kept!` in
map.jl says what the `state` is, and `shot(p.file)` reads what was made once
it's `:there`. `zoom` makes everything in the page that much bigger. With
`pictures`, the page gets its pictures from the web. Without `start`, nothing
is made that isn't kept already.
"""
picture!(folder, html, wide; zoom=1.0, pictures=false, start=true) = begin
  out = file(folder, html, wide, zoom, pictures)
  p = Maps.kept!(out; start) do part, err
    stem = chopsuffix(out, ".txt")
    source = stem * ".html"
    write(source, html)
    HELPER[](source, wide, zoom, pictures, stem, part, err)
  end
  # What's wrong is said in words about an email, not about a map
  p.state == :failed ? merge(p, (problem=p.problem == Maps.NO_SWIFT ? NO_SWIFT : FAILED,)) : p
end

"""
Remove from `folder` each file that isn't part of the pictures whose text
file is `out`. A page's folder then keeps the pictures of the width that it
was last shown at, and no others.
"""
tidy!(folder, out) = begin
  stem = chopsuffix(basename(out), ".txt")
  foreach(f -> startswith(f, stem) || startswith(f, '.') || rm(joinpath(folder, f), force=true), readdir(folder))
end
