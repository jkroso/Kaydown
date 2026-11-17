# Tests for the link cards of main.jl: a line that's written as a picture is,
# with the address of a web page, shows the page's title, its description and
# its picture. Run them
# with `julia -O0 --project=. test/linkcard_view_test.jl`. They use a window
# that isn't on the screen, and no network: a function of the test stands in
# for `curl`, and another for the browser. Set `KAYDOWN_SHOTS` to a folder,
# and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const C, px = K.Cards, K.px

const dir = mktempdir()
K.MEDIA_CACHE[] = joinpath(dir, "cache")

# The pretend web: what it has at each address, the addresses that were asked for, and whether it has answered yet
const web = Dict{String,Any}()
const asked = String[]
const arrived = Ref(false)
C.getter[] = (url, file, most) -> begin
  push!(asked, url)
  haskey(web, url) && write(file, first(Vector{UInt8}(web[url]), most))
  () -> arrived[]
end
const opened = String[]   # the addresses that the pretend browser was sent to
K.BROWSER[] = url -> (push!(opened, url); nothing)

const PAINT = "https://www.bunnings.com.au/paint"
const SLOW = "https://docs.julialang.org/en/v1/manual/getting-started/"
const GONE = "https://gone.example.com/"
const PHOTO = "https://example.com/photo"        # an address with no ending that turns out to be a picture
const KEPT = "https://example.com/kept"          # and one whose picture Kaydown has already
const TALK = "https://www.youtube.com/watch?v=abc"
const picture = read(joinpath(@__DIR__, "..", "app", "icon.png"))
web[PAINT] = """
<html><head><title>Paint | Bunnings</title>
<meta property="og:title" content="White paint &amp; primer, 4 L">
<meta property="og:description" content="A low-sheen acrylic for walls and ceilings in every room of the house. It covers 16 square metres with each litre, dries in two hours and washes off your brushes with water. This sentence is here to make the description longer than two lines of the card.">
<meta property="og:image" content="/images/paint.png">
<meta property="og:site_name" content="Bunnings Australia">
<link rel="icon" href="/icon.png">
</head><body></body></html>
"""
web["https://www.bunnings.com.au/images/paint.png"] = picture
web["https://www.bunnings.com.au/icon.png"] = picture
web[SLOW] = "<title>Getting Started · The Julia Language</title><meta name=\"description\" content=\"Documentation for The Julia Language.\">"
web[PHOTO] = picture

const page = joinpath(dir, "links.md")
cp(joinpath(@__DIR__, "..", "app", "icon.png"), joinpath(dir, "plan.png"))
write(page, """
# Links

![Paint]($PAINT)

Some words with $PAINT in the line.

[Words that go somewhere]($PAINT)

![]($SLOW)

![A page that's gone]($GONE)

$PAINT

<$SLOW>

![A plan](plan.png)

![A photo]($PHOTO)

![A photo that's kept]($KEPT)

![A talk]($TALK)

- ![Paint]($PAINT)

The end.
""")

# Kaydown gets a picture from the web with `curl` itself. Here it has each of these already, or knows that it can't be had,
# so that it asks the web for nothing.
K.fetches[PHOTO] = nothing
K.fetches[TALK] = nothing
K.fetches[KEPT] = joinpath(dir, "plan.png")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1000px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)
line(text) = findfirst(startswith(text), e.buf.lines)
card(i) = K.item(e, i).content.node::K.LinkCard
iscard(i) = (c = K.item(e, i).content; c isa K.Live && c.node isa K.LinkCard)
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames())
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
"Click the middle of `node`, with the keys `held`"
click(node, held=Keys(0)) = begin
  r = rect(node)
  at((K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)))
  w.keys = held | Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys = held
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys = Keys(0)
  frames()
end

const paint, slow, gone = line("![Paint]"), line("![](" * SLOW), line("![A page that's gone]")
flows(i) = K.item(e, i).content isa K.Flow

@testset "the lines that show as cards" begin
  @test iscard(paint) && iscard(slow) && iscard(gone)
  @test K.carded(e.buf, paint) && K.solid(e.buf, paint) == (paint, paint) && K.part(e.buf, slow) == (slow, slow)
  # A web address alone on a line is a line of text, as it was before there were cards, and so is one between < and >
  for bare in (line(PAINT), line("<" * SLOW))
    @test flows(bare) && !K.carded(e.buf, bare) && K.solid(e.buf, bare) === nothing && !K.israw(e.buf, bare)
    @test join(seg.text for vl in K.item(e, bare).content.lines for seg in vl.segs) == e.buf.lines[bare]
  end
  # An address in a line of text, a link with words and a list item stay as they were
  for start in ("Some words", "[Words", "- ")
    @test flows(line(start)) && !K.carded(e.buf, line(start))
  end
  # A picture on the Mac is a picture, and so is one from the web that Kaydown has already. No one is asked for that one.
  @test K.item(e, line("![A plan]")).content.node isa K.Picture && K.item(e, line("![A photo that's kept]")).content.node isa K.Picture
  @test !(KEPT in asked)
  # A video on YouTube is no card. Its line does what it did: Kaydown has no picture for it, so it shows as it's written.
  @test !K.carded(e.buf, line("![A talk]")) && flows(line("![A talk]")) && !(TALK in asked)
  # A window that isn't on the screen asks the web for nothing with `curl`. This test has its own function in place of it.
  mine = C.getter[]
  @test K.online(e)
  C.getter[] = C.curl
  @test !K.online(e)
  C.getter[] = mine
  # An email shows no cards
  was = e.buf.path
  e.buf.path = joinpath(dir, "letter.eml")
  @test !K.carded(e.buf, paint) && K.card_item(e, paint) === nothing
  e.buf.path = was
end

@testset "a card while its page is on its way" begin
  # Each page was asked for once, and nothing else was
  @test sort(asked) == sort([PAINT, SLOW, GONE, PHOTO])
  c = card(paint)
  @test c.card == C.Card(PAINT) && c.words == "Paint" && c.picture == "" && c.icon == ""
  # The words of the line are the title, with the address under them. A line with no words has the address as its title.
  @test C.heading(c.card, c.words) == "Paint" && C.blurb(c.card, c.words) == PAINT && C.source(c.card) == "bunnings.com.au"
  @test card(slow).words == "" && C.heading(card(slow).card, card(slow).words) == SLOW
  @test iscard(line("![A photo]"))   # until its first bytes come, Kaydown can't tell that it's a picture
  shot("cards-waiting.png")
  tall = K.item(e, paint).tall
  @test tall == K.card_tall(K.body(e).size) + 2K.LIVE_GAP && 90 <= K.num(K.card_tall(K.body(e).size)) <= 110
  @test rect(c).width ≈ e.width
  top = K.item(e, slow).top
  arrived[] = true
  frames(4)
  # The page that can't be had was asked for twice. Here the second time comes at once.
  C.jobs[joinpath(K.cards_dir(), C.name(GONE) * ".html")] -= C.SOON
  frames(4)
  @test count(==(GONE), asked) == 2
  # The page's own title takes the place of the words
  @test c.card.title == "White paint & primer, 4 L" && c.card.site == "Bunnings Australia" && C.heading(c.card, c.words) == c.card.title
  @test !isempty(c.picture) && !isempty(c.icon)
  @test card(slow).card.title == "Getting Started · The Julia Language" && card(slow).picture == ""
  # A page that can't be had keeps the words of its line as its title, and the page doesn't move when a card fills in
  @test card(gone).card == C.Card(GONE) && C.heading(card(gone).card, card(gone).words) == "A page that's gone"
  @test K.item(e, paint).tall == tall && K.item(e, slow).top == top
  @test !K.dirty(e.buf)
  shot("cards.png")
  # The folder keeps each card and each picture, and nothing of the pages themselves
  kept = readdir(K.cards_dir())
  @test dirname(K.cards_dir()) == joinpath(dir, "cache") && count(endswith(".card"), kept) == 3 && !any(endswith(".html"), kept)
  @test C.name("https://www.bunnings.com.au/images/paint.png") in kept
end

@testset "an address that turns out to be a picture" begin
  photo = line("![A photo]")
  # It's no card. While Kaydown hasn't the picture, the line shows as it's written, as it did before there were cards.
  @test C.pictured(first(C.lookup!(PHOTO, K.cards_dir()))) && K.card_item(e, photo) === nothing && flows(photo)
  @test K.pictured(e.buf, photo) && !K.has_picture(PHOTO)
  # Once Kaydown has the picture, the line shows it
  K.fetches[PHOTO] = joinpath(dir, "plan.png")
  frames()
  @test K.has_picture(PHOTO) && K.item(e, photo).content.node isa K.Picture
end

@testset "the caret goes onto a card as a whole" begin
  caret!((paint - 1, 0))
  key(Keys.down)
  @test e.buf.caret == (paint, 0) && K.picked(e.buf) == (paint, paint) && iscard(paint)
  shot("cards-picked.png")
  key(Keys.down)
  @test e.buf.caret[1] == paint + 1 && iscard(paint)
  key(Keys.up)
  @test K.picked(e.buf) == (paint, paint)
  # Return shows the line as it's written, with the caret at its end
  key(Keys.enter)
  @test e.buf.caret == (paint, length("![Paint]($PAINT)")) && flows(paint)
  shot("cards-typing.png")
  # What's typed there changes the line, and ⌘Z takes it back
  ontype(e, Typed('s', w)); frames()
  @test e.buf.lines[paint] == "![Paint]($PAINT)s" && flows(paint)
  K.undo!(e.buf); frames()
  @test e.buf.lines[paint] == "![Paint]($PAINT)"
  caret!((1, 0))
  @test iscard(paint)
  # ⌫ takes the card away, and ⌘Z puts it back
  caret!((gone, 0))
  key(Keys.backspace)
  @test line("![A page that's gone]") === nothing
  K.undo!(e.buf); frames()
  @test line("![A page that's gone]") == gone && iscard(gone)
end

@testset "typing a card" begin
  last = line("The end.")
  caret!(K.line_end(e.buf, last))
  key(Keys.enter); key(Keys.enter)
  new = e.buf.caret[1]
  web["https://example.org/new"] = "<title>A new page</title>"
  for c in "![New](https://example.org/new)"
    ontype(e, Typed(c, w))
  end
  frames()
  # The line shows as its text while the caret is in it, and Kaydown asks for no page until the caret leaves
  @test e.buf.lines[new] == "![New](https://example.org/new)" && flows(new)
  @test !any(startswith("https://example.org"), asked)
  caret!((1, 0)); frames(4)
  @test iscard(new) && card(new).card.title == "A new page" && "https://example.org/new" in asked
  foreach(_ -> K.undo!(e.buf), 1:60); frames()
  @test line("![New]") === nothing && !K.dirty(e.buf)
  # Insert › Link Card writes the line, with the caret where the address goes on
  item = K.INSERTS[findfirst(x -> x isa Tuple && x[1] == "Link Card", K.INSERTS)]
  caret!(K.line_end(e.buf, line("The end.")))
  K.add_block!(e, item[2], item[3]); frames()
  made = e.buf.caret[1]
  @test e.buf.lines[made] == "![](https://)" && e.buf.caret == (made, 12) && flows(made)
  for c in "example.org/new"
    ontype(e, Typed(c, w))
  end
  caret!((1, 0)); frames()
  @test e.buf.lines[made] == "![](https://example.org/new)" && iscard(made) && card(made).card.title == "A new page"
  foreach(_ -> K.undo!(e.buf), 1:60); frames()
  @test line("![](https://example.org") === nothing && !K.dirty(e.buf)
end

@testset "a click on a card" begin
  c = card(paint)
  caret!((1, 0))
  @test K.cursor(c) == :ibeam && !K.opening(c)
  # A click puts the caret in the card's line, so the line shows as it's written
  click(c)
  @test e.buf.caret == (paint, length("![Paint]($PAINT)")) && flows(paint) && isempty(opened)
  caret!((1, 0))
  # With ⌘ held, the mouse shows a hand, and a click opens the address
  w.keys = Keys.cmd
  @test K.cursor(c) == :hand
  w.keys = Keys(0)
  was = e.buf.caret
  click(c, Keys.cmd)
  @test opened == [PAINT] && e.buf.caret == was && iscard(paint)
  click(card(slow), Keys.cmd)
  @test opened == [PAINT, SLOW]
  # In a page that's never changed, a click opens the address with no key held
  chmod(page, 0o444)
  frames()
  @test e.buf.fixed && K.cursor(c) == :hand
  click(c)
  @test opened == [PAINT, SLOW, PAINT] && iscard(paint)
  chmod(page, 0o644)
  frames()
  @test !e.buf.fixed
end

@testset "the page as HTML and the page on paper" begin
  made = K.page_html(e)
  @test occursin("<a class=\"card\" href=\"$PAINT\"><span class=\"card-words\"><strong>White paint &amp; primer, 4 L</strong>", made)
  @test occursin("<img class=\"card-picture\" src=\"https://www.bunnings.com.au/images/paint.png\" alt=\"\">", made)
  # A page that couldn't be had has the words of its line as its title, and its address under them
  @test occursin("<a class=\"card\" href=\"$GONE\"><span class=\"card-words\"><strong>A page that's gone</strong><span class=\"card-description\">$GONE</span>", made)
  @test occursin("a.card {", made) && count("class=\"card\"", made) == 3
  # The other lines are as they were: an address by itself is text, and a picture is a picture
  @test occursin("<p>$PAINT</p>", made) && occursin("<p>&lt;$SLOW&gt;</p>", made)
  @test occursin("<p>Some words with $PAINT in the line.</p>", made) && occursin("<a href=\"$PAINT\">Words that go somewhere</a>", made)
  @test occursin("<p><img src=\"$PHOTO\" alt=\"A photo\"></p>", made) && occursin("<p><img src=\"$KEPT\" alt=\"A photo that's kept\"></p>", made)
  @test occursin("<p><img src=\"plan.png\" alt=\"A plan\"></p>", made) && occursin("<li><img src=\"$PAINT\" alt=\"Paint\">", made)
  @test length(K.print_pdf(e)) > 1000
  frames()
end

@testset "the look of a card" begin
  caret!((1, 0))
  K.theme!(e, :night); frames()
  shot("cards-night.png")
  K.theme!(e, :sepia); frames()
  # In a narrow window the card is as wide as the text, and its words end in …
  narrow = Window(e, size=(420px, 900px))
  foreach(_ -> frame(narrow), 1:3)
  @test rect(card(paint)).width ≈ e.width && K.num(e.width) < 400
  haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], "cards-narrow.png"), narrow)
  close(narrow)
end
