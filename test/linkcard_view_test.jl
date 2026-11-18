# Tests for the `card` block of main.jl: a card for each web address in the
# block, with the page's title, its description and its picture. Run them
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
const JULIA = "https://julialang.org/"   # the address of a line that's written as a picture is
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

const page = joinpath(dir, "links.md")
cp(joinpath(@__DIR__, "..", "app", "icon.png"), joinpath(dir, "plan.png"))
write(page, """
# Links

```card
$PAINT
```

Some words with $PAINT in the line.

```card
$SLOW
Paint for the hall

$GONE
```

```card
```

$PAINT

![Julia]($JULIA)

The end.
""")

# Kaydown gets a picture from the web with `curl` itself. Here it knows that this one can't be had, so that it asks the web for nothing.
K.fetches[JULIA] = nothing

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1000px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)
line(text) = findfirst(startswith(text), e.buf.lines)
flows(i) = K.item(e, i).content isa K.Flow
"The view of the page's `n`th `card` block, and the first and last line of that block"
view(n) = e.nodes[(:block, K.CARD, page, n)]::K.CardsView
block(n) = K.block_lines(e.buf, K.CARD, n)
"True when the page's `n`th `card` block shows its cards, and not its lines"
shows(n) = (c = K.item(e, block(n)[1]).content; c isa K.Live && c.node === view(n))
"The `k`th card of the page's `n`th `card` block"
card(n, k=1) = view(n).parts[(:card, k)]::K.LinkCard
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

@testset "what a block shows" begin
  @test shows(1) && shows(2) && shows(3)
  # One address is one card. Two addresses are two cards, one under the other, and a line that isn't an address is between them.
  @test [en.text for en in view(1).entries] == [PAINT] && [en.address for en in view(2).entries] == [true, false, true]
  @test card(1).card.url == PAINT && card(2, 1).card.url == SLOW && card(2, 3).card.url == GONE && !haskey(view(2).parts, (:card, 2))
  tall = K.card_tall(K.body(e).size)
  @test 90 <= K.num(tall) <= 110 && rect(card(1)).height ≈ tall && rect(card(1)).width ≈ e.width
  @test rect(card(2, 3)).top > rect(card(2, 1)).top + tall && rect(card(2, 3)).height ≈ tall
  @test rect(view(2)).height > 2tall && rect(view(2)).height < 2.6tall
  # An empty block says what to write, in one line
  @test isempty(view(3).entries) && rect(view(3)).height < 0.6tall
  # The sidebar lists each block, the Insert menu has it, and a `find` block can list the page's link cards
  @test count(en -> en.title == "Link card", K.outline(e.buf)) == 3 && any(x -> x isa Tuple && x[1] == "Link Card", K.INSERTS)
  @test K.Searches.what("link cards") == :card && K.Searches.block_kind(K.CARD) == :card && "link-45deg" in K.SIDEBAR_ICONS
  # A window that isn't on the screen asks the web for nothing with `curl`. This test has its own function in place of it.
  mine = C.getter[]
  @test K.online(e)
  C.getter[] = C.curl
  @test !K.online(e)
  C.getter[] = mine
  # In an email, Kaydown asks the web for nothing
  was = e.buf.path
  e.buf.path = joinpath(dir, "letter.eml")
  @test !K.online(e)
  e.buf.path = was
end

@testset "only a block shows a card" begin
  # A web address alone on a line is a line of text, and so is one in a line of words
  bare = findlast(==(PAINT), e.buf.lines)
  @test flows(bare) && K.solid(e.buf, bare) === nothing && flows(line("Some words"))
  @test join(seg.text for vl in K.item(e, bare).content.lines for seg in vl.segs) == PAINT
  # A web address in a picture's form is a picture line, as it always was. Kaydown has no picture for this one, so it
  # shows as it's written. It's no card, and the cards asked no one for it.
  julia = line("![Julia]")
  @test K.pictured(e.buf, julia) && K.solid(e.buf, julia) == (julia, julia) && flows(julia) && K.picture_item(e, julia) === nothing
  @test !(JULIA in asked) && !any(n -> n isa K.LinkCard && n.card.url == JULIA, values(e.nodes))
  @test occursin("<p><img src=\"$JULIA\" alt=\"Julia\"></p>", K.page_html(e))
end

@testset "a card while its page is on its way" begin
  # Each page was asked for once, and nothing else was
  @test sort(asked) == sort([PAINT, SLOW, GONE])
  c = card(1)
  @test c.card == C.Card(PAINT) && c.picture == "" && c.icon == ""
  @test C.heading(c.card) == PAINT && C.source(c.card) == "bunnings.com.au"
  shot("cards-waiting.png")
  tops = [K.item(e, block(n)[1]).top for n in 1:3]
  arrived[] = true
  frames(4)
  # The page that can't be had was asked for twice. Here the second time comes at once.
  C.jobs[joinpath(K.cards_dir(), C.name(GONE) * ".html")] -= C.SOON
  frames(4)
  @test count(==(GONE), asked) == 2
  @test c.card.title == "White paint & primer, 4 L" && c.card.site == "Bunnings Australia" && !isempty(c.picture) && !isempty(c.icon)
  @test card(2, 1).card.title == "Getting Started · The Julia Language" && card(2, 1).picture == ""
  # A page that can't be had keeps its address, and the page doesn't move when a card fills in
  @test card(2, 3).card == C.Card(GONE) && [K.item(e, block(n)[1]).top for n in 1:3] == tops
  @test !K.dirty(e.buf)
  shot("cards.png")
  # The folder keeps each card and each picture, and nothing of the pages themselves
  kept = readdir(K.cards_dir())
  @test dirname(K.cards_dir()) == joinpath(dir, "cache") && count(endswith(".card"), kept) == 2 && !any(endswith(".html"), kept)
  @test C.name("https://www.bunnings.com.au/images/paint.png") in kept
end

@testset "the caret and the block" begin
  s, t = block(1)
  # The caret goes onto the block as a whole
  caret!((s - 1, 0))
  key(Keys.down)
  @test e.buf.caret == (s, 0) && K.picked(e.buf) == (s, t) && shows(1)
  shot("cards-picked.png")
  # Return gives the keyboard to a block that takes it. This one has nothing to type in, so it stays as it is.
  key(Keys.enter)
  @test K.picked(e.buf) == (s, t) && shows(1) && e.buf.lines[s:t] == ["```card", PAINT, "```"]
  key(Keys.down)
  @test e.buf.caret[1] == t + 1 && shows(1)
  # With the caret in the block, the block shows its lines. What's typed there changes the address, and ⌘Z takes it back.
  caret!((s + 1, length(PAINT)))
  @test !shows(1) && flows(s + 1) && K.item(e, s + 1).content.kind == K.Kind.code
  shot("cards-typing.png")
  ontype(e, Typed('s', w)); frames()
  @test e.buf.lines[s+1] == PAINT * "s"
  K.undo!(e.buf); frames()
  @test e.buf.lines[s+1] == PAINT
  caret!((1, 0))
  @test shows(1) && card(1).card.title == "White paint & primer, 4 L"
  # A click with ⌥ held shows the lines too
  click(card(1), Keys.opt)
  @test e.buf.caret == (s + 1, 0) && !shows(1) && flows(s + 1)
  caret!((1, 0))
  # ⌫ takes the block away, and ⌘Z puts it back
  caret!((s, 0))
  key(Keys.backspace)
  @test block(3) === nothing && !(PAINT in e.buf.lines[1:s+1])
  K.undo!(e.buf); frames()
  @test block(1) == (s, t) && shows(1) && !K.dirty(e.buf)
end

@testset "a new block from the Insert menu" begin
  web["https://example.org/new"] = "<title>A new page</title>"
  item = K.INSERTS[findfirst(x -> x isa Tuple && x[1] == "Link Card", K.INSERTS)]
  caret!(K.line_end(e.buf, line("The end.")))
  K.add_block!(e, item[2], item[3]); frames()
  s, t = block(4)
  # The caret is after https:// in the block, and the block shows its lines while the caret is there
  @test e.buf.lines[s:t] == ["```card", "https://", "```"] && e.buf.caret == (s + 1, 8) && flows(s + 1)
  for c in "example.org/new"
    ontype(e, Typed(c, w))
  end
  frames()
  # Kaydown asks for no page until the caret leaves the block
  @test e.buf.lines[s+1] == "https://example.org/new" && !any(startswith("https://example.org"), asked)
  caret!((1, 0)); frames(4)
  @test shows(4) && card(4).card.title == "A new page" && "https://example.org/new" in asked
  foreach(_ -> K.undo!(e.buf), 1:40); frames()
  @test block(4) === nothing && !K.dirty(e.buf)
end

@testset "a click on a card" begin
  c = card(1)
  caret!((1, 0))
  was = e.buf.caret
  @test K.cursor(c) == :arrow && !K.opening(c)
  # A click with no key held opens nothing, and leaves the block as it is
  click(c)
  @test isempty(opened) && e.buf.caret == was && shows(1)
  # With ⌘ held, the mouse shows a hand, and a click opens the address
  w.keys = Keys.cmd
  @test K.cursor(c) == :hand
  w.keys = Keys(0)
  click(c, Keys.cmd)
  @test opened == [PAINT] && e.buf.caret == was && shows(1)
  click(card(2, 3), Keys.cmd)
  @test opened == [PAINT, GONE]
  # In a page that's never changed, a click opens the address with no key held
  chmod(page, 0o444)
  frames()
  @test e.buf.fixed && K.cursor(c) == :hand
  click(c)
  @test opened == [PAINT, GONE, PAINT] && shows(1)
  chmod(page, 0o644)
  frames()
  @test !e.buf.fixed
end

@testset "the page as HTML and the page on paper" begin
  made = K.page_html(e)
  @test occursin("<a class=\"card\" href=\"$PAINT\"><span class=\"card-words\"><strong>White paint &amp; primer, 4 L</strong>", made)
  @test occursin("<img class=\"card-picture\" src=\"https://www.bunnings.com.au/images/paint.png\" alt=\"\">", made)
  # Two cards of one block, with the line between them as a paragraph
  @test occursin("<strong>Getting Started · The Julia Language</strong>", made) && occursin("</a>\n<p>Paint for the hall</p>\n<a class=\"card\" href=\"$GONE\">", made)
  @test occursin("<a class=\"card\" href=\"$GONE\"><span class=\"card-words\"><strong>$GONE</strong>", made)
  # The rules for a card's look come with each block that has a card. An empty block is nothing in the page.
  @test count("class=\"card\"", made) == 3 && count("a.card {", made) == 2 && !occursin("language-card", made)
  # A page with no `card` block has none of those rules, and an address by itself is a line of text
  @test occursin("<p>$PAINT</p>", made) && !occursin("card", K.html(["# A page", "", PAINT, "", "![Julia]($JULIA)"]))
  @test length(K.print_pdf(e)) > 1000
  frames()
end

@testset "the look of a card" begin
  caret!((1, 0))
  K.theme!(e, :night); frames()
  shot("cards-night.png")
  K.theme!(e, :sepia); frames()
  # In a narrow window the card is as wide as the text, and its words end in …
  narrow = Window(e, size=(420px, 1000px))
  foreach(_ -> frame(narrow), 1:3)
  @test rect(card(1)).width ≈ e.width && K.num(e.width) < 400
  haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], "cards-narrow.png"), narrow)
  close(narrow)
end
