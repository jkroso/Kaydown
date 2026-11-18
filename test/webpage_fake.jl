# A pretend program for webpage.jl, for webpage_test.jl and
# webpage_view_test.jl. It takes the place of the program that draws a page of
# HTML, so the tests use neither WebKit nor the web. `helper` is a function
# for `Webpages.HELPER`: it writes strips of one colour each, and the text
# file that says what it made. `opener` is a function for `Webpages.OPENER`:
# it opens nothing, and notes what it was asked to open.
#
# The HTML says what the helper makes:
#
# - The page is 400 px tall, or as tall as a comment like `<!-- tall 1500 -->` says.
# - Each `<a href="...">` is a link. The links are one under the other: `box(i)` is where link `i` is.
# - A page that's drawn with its pictures from the web is blue, and one without is grey: see `colour`.
# - Each comment like `<!-- line Hi Jake -->` is a line of the page's words. The lines are one under the
#   other, and each letter is 10 px wide: `spot(i, k)` is where letter `k` of line `i` starts.
#
# Three switches say what the helper does with every page: `slow[]` makes it
# take `SLOW` seconds, `offline[]` makes it fail, and `broken[]` makes it
# write strips that aren't pictures.

@use "./map_fake" png

"Each page that was asked for: its HTML, how wide it is in px, its zoom, and whether it gets its pictures from the web"
const calls = NamedTuple[]
"Each address that was asked to open"
const opened = String[]
"How many seconds a slow page takes"
const SLOW = 0.4
const slow, offline, broken = Ref(false), Ref(false), Ref(false)

"How tall the page of `html` is, in px"
tall(html) = (m = match(r"<!-- tall (\d+) -->", html); m === nothing ? 400 : parse(Int, m[1]))
"Where each link of `html` goes"
links(html) = String[m[1] for m in eachmatch(r"<a href=\"([^\"]+)\"", html)]
"Where link `i` of a page is, in px from the page's top left corner"
box(i) = (left=20.0, top=40.0 + 60.0 * (i - 1), wide=200.0, tall=30.0)
"The lines of words of `html`"
words(html) = String[m[1] for m in eachmatch(r"<!-- line (.+?) -->", html)]
"Where letter `k` of line `i` of the words starts, in px from the page's top left corner, and how tall the line is. Letter 0 is the first."
spot(i, k=0) = (left=20.0 + 10k, top=300.0 + 30 * (i - 1), tall=20.0)
"The red, the green and the blue of strip `n` of a page. Each strip is a little darker than the one over it."
colour(pictures, n=1) = (pictures ? (40, 120, 220) : (200, 200, 200)) .- 20 * (n - 1)

const strips = Dict{Any,Vector{UInt8}}()

helper(source, wide, zoom, pictures, stem, out, err) = begin
  html = read(source, String)
  push!(calls, (html=html, wide=wide, zoom=zoom, pictures=pictures))
  if offline[]
    write(err, "error: WebKit stopped.\n")
    return 1
  end
  high = tall(html)
  lines = ["page\t$wide\t$high"]
  top, n = 0, 0
  while top < high
    n += 1
    part = min(1024, high - top)
    name = "$(basename(stem))-$n.png"
    ink = colour(pictures, n)
    write(joinpath(dirname(stem), name), broken[] ? b"not a picture" : get!(() -> png((x, y) -> ink, wide, part), strips, (wide, part, ink)))
    push!(lines, "strip\t$part\t$name")
    top += part
  end
  for (i, url) in enumerate(links(html))
    b = box(i)
    push!(lines, "link\t$(b.left)\t$(b.top)\t$(b.wide)\t$(b.tall)\t$url")
  end
  for (i, line) in enumerate(words(html))
    s = spot(i)
    edges = join((spot(i, k).left for k in 0:length(line)), ',')
    push!(lines, "text\t$(i == 1 ? "-" : "line")\t$(s.top)\t$(s.tall)\t$edges\t$line")
  end
  write(out, join(lines, "\n") * "\n")
  slow[] ? run(`sleep $SLOW`, wait=false) : 0
end

opener(url) = (push!(opened, url); nothing)
