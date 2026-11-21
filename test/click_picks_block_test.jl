# Tests for a click on a live block that nothing in the block takes: it puts
# the caret on the block as a whole, as ↑ and ↓ do. See `pick_clicked!` in
# main.jl. Run them with `julia -O0 --project=. test/click_picks_block_test.jl`.
# They click in a window that isn't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
write(joinpath(dir, "costs.csv"), "Item,Supplier,Quantity,Price\nPaint,\"Colour & Co, Hamilton\",12 L,\$42.50\nTimber,The yard,340 m,\$8.00\nNails,\"Fix It, Te Rapa\",5 boxes,\$3.20\nPlaster,The yard,6 bags,\$27.90\n")
write(joinpath(dir, "long.csv"), "Day,Rain\n" * join(("$d,$(d % 7) mm" for d in 1:60), "\n") * "\n")

const page = joinpath(dir, "home.md")
write(page, """
# Home

Ladder opens this page when you start it without a file.

```load
from: costs.csv
```

Some words between the blocks.

```load
from: long.csv
```

![Costs](costs.csv)

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"The line of the page that holds `text`"
line(text) = findfirst(l -> occursin(text, l), e.buf.lines)
"The place in the window that is `down` from the top of what line `i` shows, in the middle of the page"
spot(i, down) = (it = K.item(e, i); (e.origin[1] + e.width / 2, e.origin[2] + it.top + down))
click(place, held...) = begin
  x, y = place
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w)); frame(w)
  foreach(h -> w.keys |= h, held)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
caret!(i, col=0) = (e.buf.caret = e.buf.anchor = (i, col); K.touch!(e); frames())
"True when a line goes round the part of the page that the caret is on"
ringed() = K.picked(e.buf) !== nothing && w.focus === e

@testset "a click on a row of a load block puts the caret on the block" begin
  i = line("from: costs.csv") - 1
  it = K.item(e, i)
  @test it.content isa K.Live && K.picked(e.buf) === nothing
  caret!(3, 5)
  click(spot(i, it.tall - 20px))
  @test e.buf.caret == e.buf.anchor == (i, 0)
  @test K.picked(e.buf) == (it.first, it.last) && ringed()
  # The block still shows as what it makes
  @test K.item(e, i).content isa K.Live
  shot("click-picks-load.png")
  # From there the arrows go on as they do from a block that ↓ went onto
  onkey(w, KeyPress{Keys.down}(0, w)); frames()
  @test e.buf.caret[1] == it.last + 1 && K.picked(e.buf) === nothing
end

@testset "a click on the empty part of the block's bar picks it too" begin
  i = line("from: costs.csv") - 1
  caret!(3, 0)
  click(spot(i, 22px))
  @test K.picked(e.buf) == (i, K.item(e, i).last)
end

@testset "a click on a block takes away a selection" begin
  i = line("from: costs.csv") - 1
  e.buf.anchor, e.buf.caret = (3, 0), (3, 10); K.touch!(e); frames()
  click(spot(i, K.item(e, i).tall - 20px))
  @test e.buf.caret == e.buf.anchor == (i, 0)
end

@testset "a click with ⌘ or ⇧ held leaves the caret" begin
  i = line("from: costs.csv") - 1
  for key in (Keys.cmd, Keys.shft)
    caret!(3, 2)
    click(spot(i, K.item(e, i).tall - 20px), key)
    @test e.buf.caret == (3, 2) && K.picked(e.buf) === nothing
  end
end

@testset "the page doesn't scroll when a tall block is clicked" begin
  i = line("from: long.csv") - 1
  it = K.item(e, i)
  @test it.tall > 700px
  # The block's top is above the window, and the click is near its bottom
  e.scroll.offset = it.top + it.tall - 500px; frames(3)
  before = e.scroll.offset
  caret!(3, 0)
  e.scroll.offset = before; frames(3)
  click(spot(i, it.tall - 200px))
  @test K.picked(e.buf) == (i, it.last)
  @test e.scroll.offset == before
  e.scroll.offset = 0px; frames(3)
end

@testset "a table from a CSV file still shows its line as it's written" begin
  i = line("![Costs](costs.csv)")
  caret!(3, 0)
  e.scroll.offset = max(0px, K.item(e, i).top - 60px); frames(3)
  click(spot(i, K.item(e, i).tall / 2))
  @test e.buf.caret == (i, length(e.buf.lines[i]))
  e.scroll.offset = 0px; frames(3)
end
