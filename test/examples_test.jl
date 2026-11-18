# Tests for pages/examples.md, the page that lists everything that Kaydown
# does: each of its links goes to a page and a heading that are there, every
# page and every kind of block has an example that it links to, and a link
# that names a heading goes to that heading. Run them with
# `julia -O0 --project=. test/examples_test.jl`. Set `KAYDOWN_SHOTS` to a
# folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const pages = K.pages_dir[]
const hub = joinpath(pages, "examples.md")
const links = [String(m[1]) for m in eachmatch(r"\]\(([^)\s]+)\)", read(hub, String))]
"The file that a link names, and the heading after its #, or \"\""
parts(link) = (String.(split(link, '#', limit=2))..., "")[1:2]
"The headings of the page at `path`, as a link names them"
headings(path) = (lines = K.text(path); [K.heading_slug(K.rest(lines[i], l.prefix)) for (i, l) in enumerate(K.classify(lines)) if l.kind == K.Kind.heading])

@testset "each link goes somewhere" begin
  @test length(links) > 30
  for link in links
    file, heading = parts(link)
    @test isfile(joinpath(pages, file))
    isempty(heading) || @test heading in headings(joinpath(pages, file))
  end
end

@testset "nothing is left out" begin
  linked = unique(first.(parts.(links)))
  # Every page that comes with Kaydown
  for name in readdir(pages)
    (K.ismarkdown(name) && name != "examples.md") || continue
    @test name in linked
  end
  # Every kind of block has an example in a page that's linked
  text = join((read(joinpath(pages, file), String) for file in linked if K.ismarkdown(file)), "\n")
  for lang in [K.LIVE, K.SHEET, K.SPREADSHEET, K.DIAGRAM, K.TAKEOFF, K.SCHEDULE, "julia", keys(K.BLOCKS)...]
    @test occursin("\n```$lang\n", text)
  end
  # Each heading of the welcome page is one that a link names
  named = [heading for (file, heading) in parts.(links) if file == "welcome.md"]
  for heading in headings(joinpath(pages, "welcome.md"))[2:end]
    @test heading in named
  end
end

@testset "a link that names a heading goes to it" begin
  e = K.build_editor(hub)
  w = Window(e, size=(1000px, 800px))
  frames() = foreach(_ -> frame(w), 1:3)
  frames()
  haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], "examples.png"), w)
  # A click on a link with ⌘ held follows it
  i = findfirst(l -> occursin("(welcome.md#sheets)", l), e.buf.lines)
  it = K.item(e, i)
  e.scroll.offset = it.top - 200px; frames()   # the line is brought into the window
  x, y = K.num(e.origin[1]) + 90, K.num(e.origin[2] + it.top + it.tall / 2)
  @test K.link_at(e, (px(x), px(y))) == "welcome.md#sheets"
  w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames()
  w.keys |= Keys.cmd | Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd | Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames()
  @test e.buf.path == joinpath(pages, "welcome.md") && e.buf.lines[e.buf.caret[1]] == "## Sheets"
  K.open!(e, hub); frames()
  K.follow!(e, "welcome.md#charts"); frames()
  @test e.buf.path == joinpath(pages, "welcome.md") && e.buf.lines[e.buf.caret[1]] == "## Charts"
  # The heading is near the top of the window
  @test K.num(K.item(e, e.buf.caret[1]).top - e.scroll.offset) < 60
  # A heading of the page that shows, by its words or as a link writes them
  K.follow!(e, "#work-with-an-agent"); frames()
  @test e.buf.lines[e.buf.caret[1]] == "## Work with an agent"
  K.follow!(e, "#Live%20blocks"); frames()
  @test e.buf.lines[e.buf.caret[1]] == "## Live blocks"
  # A page with no such heading still opens
  K.follow!(e, "schedule.md#nothing"); frames()
  @test e.buf.path == joinpath(pages, "schedule.md")
  @test K.heading_slug("Sums in a **line** of text") == "sums-in-a-line-of-text" && K.heading_slug("3D models") == "3d-models"
  # A web address with a # in it is no page
  @test !K.follow_heading!(e, "https://example.com/page#part") && e.buf.path == joinpath(pages, "schedule.md")
end

@testset "the settings page links to each page of examples" begin
  settings = K.settings_page()
  linked = [String(m[1]) for m in eachmatch(r"\]\(\.\./([^)\s]+)\)", read(settings, String))]
  # Each Markdown page in the folder of pages, so a new page needs a link there too
  for name in readdir(pages)
    K.ismarkdown(name) && @test name in linked
  end
  @test all(name -> isfile(joinpath(pages, name)), linked)
  # A link opens its page in the settings window, and ⌘⌥← comes back
  e = K.build_editor(settings)
  K.follow!(e, "../examples.md")
  @test e.buf.path == hub
  @test K.go_back!(e) && e.buf.path == settings
end
