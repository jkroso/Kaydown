# Makes pictures of a page of HTML, as a browser draws it. Ladder shows an
# email as it was sent with them: the email's own HTML, with its colours, its
# layout and its buttons.
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
# A page can be very tall, so its picture is in strips, which a window draws
# one under the other. The page is drawn without JavaScript. The program asks
# the web for nothing, so that the sender of an email can't tell when it's
# opened. Then a picture that the page has from a web site shows as an empty
# box. `remote(html)` is true for a page with such pictures, and
# `picture!(...; pictures=true)` fetches them.
#
# The Ladder app has the program in it, beside its own program. When Ladder
# runs from its source, it compiles webpage.swift the first time it's needed,
# which takes a few seconds, and keeps the program in a folder of the Mac's
# caches. That needs Swift, which comes with Xcode and its command line tools.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use "./map" => Maps

const SOURCE = joinpath(@__DIR__, "webpage.swift")

"What to say when the pictures can't be made"
const FAILED = "Ladder can't draw this email as it was sent."
const NO_SWIFT = "Ladder needs Swift to draw an email as it was sent. It comes with Xcode's command line tools."

"The program in the Ladder app, or nothing when Ladder runs from its source"
bundled() = begin
  Sys.isapple() || return nothing
  path = with_pool() do
    jstring(msg(msg(cls("NSBundle"), "mainBundle"), "pathForAuxiliaryExecutable:", nsstring("webpage")))
  end
  isfile(path) ? path : nothing
end

"What the program is compiled for: this Mac's kind of processor, and macOS 26, as Ladder's other programs are"
target() = "$(Sys.ARCH == :aarch64 ? "arm64" : "x86_64")-apple-macos26.0"

"Compile webpage.swift into the program at `out`. The app's build runs it."
compile(out) = run(`swiftc -O -parse-as-library -target $(target()) $SOURCE -o $out`)

"The folder of the Mac's caches that keeps the program that's compiled from the source"
programs() = joinpath(homedir(), "Library", "Caches", "Ladder")

"""
The command that runs the program with `args`: the program in the app, or the
one compiled from the source, which is kept in the folder `dir`. If that isn't
compiled yet, the command compiles it first.
"""
command(args; dir=programs()) = begin
  app = bundled()
  app === nothing || return `$app $args`
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

"The pictures of a page: how wide and how tall the page is in px, each strip's file with how tall it is, and the page's links"
struct Shot
  wide::Int
  tall::Int
  strips::Vector{Pair{String,Int}}
  links::Vector{Link}
end

"""
What the text file `path` says that the program made, as webpage.swift writes
it. It's nothing when the file says nothing that can be drawn, or one of its
strips is gone.
"""
shot(path) = begin
  isfile(path) || return nothing
  size, strips, links = nothing, Pair{String,Int}[], Link[]
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
    end
  end
  (size === nothing || any(isnothing, size) || isempty(strips) || sum(last, strips) != size[2]) && return nothing
  Shot(size[1], size[2], strips, links)
end

"The link at the point `(x, y)` of the page, in px from the page's top left corner, or nothing"
link(s::Shot, x, y) = begin
  # A link that's written later is drawn over one that's written before it
  i = findlast(l -> l.left <= x <= l.left + l.wide && l.top <= y <= l.top + l.tall, s.links)
  i === nothing ? nothing : s.links[i]
end

"""
True when the HTML has a picture, a font or a style sheet from a web site, so
that it looks as its sender meant only with what the web has for it.
"""
remote(html) = occursin(r"<(img|link|input|video)\b[^>]*\b(src|href|poster)\s*=\s*[\"']?\s*https?://|\bbackground\s*=\s*[\"']?\s*https?://|url\(\s*[\"']?\s*https?://"i, html)

"The text file in `folder` that says what was made of `html` on a page `wide` px wide"
file(folder, html, wide, zoom, pictures) = joinpath(folder, string(hash((html, wide, zoom, pictures)), base=16) * ".txt")

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
