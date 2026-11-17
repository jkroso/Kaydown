# Tests for the `sketch` block of main.jl: a drawing, and the tools that draw
# it. Run them with `julia -O0 --project=. test/sketch_view_test.jl`. They
# draw in a window that isn't on the screen. Set `KAYDOWN_SHOTS` to a folder,
# and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "bathroom.md")
write(page, """
# The bathroom

```sketch
box 100,40 300,160
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const v = e.nodes[(:block, K.SKETCH, page, 1)]
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Press the mouse at the first place, move it through the others, and let go"
drag(places...) = (press(places[1]); foreach(at, places[2:end]); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(key) = click(middle(rect(v.parts[(:button, key)])))
block() = (s = K.block_lines(e.buf, K.SKETCH, 1); e.buf.lines[s[1]+1:s[2]-1])
"Where a place of the sketch is in the window"
spot(x, y) = (s = K.sketch_scale(v); (v.box[1] + x * s, v.box[2] + y * s))
shapes() = v.data.shapes

@testset "the block shows its drawing" begin
  @test length(shapes()) == 1 && shapes()[1].kind == :box && v.box[3] > 300
  # The sketch is 720 of its own measure wide, whatever the width of the page
  @test K.sketch_scale(v) ≈ v.box[3] / 720 && rect(v.parts[:area]).height ≈ px(K.Sketches.LEAST * K.sketch_scale(v))
  @test any(en -> en.title == "Sketch", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Sketch", K.INSERTS)
  @test !K.dirty(e.buf)
end

@testset "the tools draw shapes" begin
  # The pen draws through the places that the mouse goes through
  drag(spot(400, 50), spot(420, 60), spot(440, 90), spot(430, 120), spot(400, 130))
  @test length(shapes()) == 2 && shapes()[2].kind == :pen && length(shapes()[2].points) >= 3 && startswith(block()[2], "pen 400,50 ")
  @test endswith(block()[2], " 400,130") && K.dirty(e.buf)
  button(:arrow)
  drag(spot(500, 60), spot(520, 80), spot(350, 100))
  @test block()[3] == "arrow 500,60 350,100"
  button(:oval)
  click(middle(rect(v.parts[(:ink, :red)])))
  drag(spot(120, 60), spot(180, 90), spot(280, 140))
  @test block()[4] == "oval red 120,60 280,140"
  # A click without a drag draws nothing
  click(spot(600, 60))
  @test length(shapes()) == 4
  button(:text)
  click(spot(520, 150))
  @test v.asking !== nothing && w.focus === v.parts[:input]
  typed("The  drain")
  key(Keys.enter)
  @test block()[5] == "text red 520,150 The drain" && v.asking === nothing
  # ⌘Z takes the last shape back
  K.undo!(e.buf); frames()
  @test length(block()) == 4 && length(shapes()) == 4
  K.redo!(e.buf); frames()
  @test length(shapes()) == 5
  shot("sketch.png")
end

@testset "the arrow tool selects, moves and deletes" begin
  button(:select)
  click(spot(100, 100))   # the left edge of the box
  @test v.picked == 1 && haskey(v.parts, (:button, :delete))
  drag(spot(100, 100), spot(110, 105), spot(130, 110))
  @test block()[1] == "box 130,50 330,170" && v.picked == 1
  # A colour goes to the shape that's selected
  click(middle(rect(v.parts[(:ink, :blue)])))
  @test block()[1] == "box blue 130,50 330,170"
  key(Keys.backspace)
  @test length(shapes()) == 4 && v.picked == 0 && startswith(block()[1], "pen ")
  click(spot(650, 190))   # on nothing
  @test v.picked == 0
  # A shape that's near the bottom makes the sketch taller
  button(:line)
  before = rect(v.parts[:area]).height
  drag(spot(50, 100), spot(60, 150), spot(80, 210))
  @test block()[end] == "line blue 50,100 80,210" && rect(v.parts[:area]).height > before
  @test e.buf.lines[end-1] == "The end."
  html = K.page_html(e)
  @test occursin("<svg", html) && occursin("<ellipse", html) && occursin(">The drain</text>", html)
end
