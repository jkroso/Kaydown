# Tests for the code that runs where it is. See "code that runs where it is" in
# main.jl. Run them with `julia -O0 --project=. test/outcome_test.jl`. They press keys
# and click in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "sums.md")
const TEXT = """
# Sums

```julia
x = 1 + 2
y = x * 10

# doubles a number
double(n) = begin
  2n
end

m = [1 2; 3 4]
println("hi")
error("no")
nothing
```

Some words.

```python
print(1)
```
"""
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

"Put the text back as it was, with no outcomes, and the caret at `line` and `col`"
fresh!(line, col=0) = begin
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
  empty!(K.outcomes(e))
  K.focus(e)   # as a click on the page does
  caret!(line, col)
end
caret!(line, col=0) = (b.caret = b.anchor = (line, col); frames())
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
run!() = key(Keys.enter, Keys.cmd)
step!() = key(Keys.enter, Keys.shft)
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
"The outcome whose code ends on `line`, or nothing"
outcome(line) = (k = findfirst(o -> o.last == line, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])

const shots = get(ENV, "OUTCOME_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "the pieces of a block of code" begin
  @test K.statements(["x = 1 + 2", "y = x * 10", "", "# doubles a number", "double(n) = begin", "  2n", "end", "", "m = [1 2; 3 4]"]) ==
        [1:1, 2:2, 4:7, 9:9]
  @test K.statements(["a = 1; b = 2", "c = 3"]) == [1:1, 2:2]
  @test K.statements(["f(1,", "  2)", "", "# the end"]) == [1:2]
  @test K.statements(["x = (1,"]) == [1:1]   # code that isn't finished is still a piece, and running it says what's wrong
  @test K.statements(String[]) == []
  @test K.statements(["", "  "]) == []
end

@testset "⌘Return runs the line that the caret is in" begin
  fresh!(4, 3)
  run!()
  o = outcome(4)
  @test o !== nothing
  @test o.brief == "3" && !o.failed && !o.more
  @test b.caret == (4, 3)   # the caret stays
  @test b.lines[4] == "x = 1 + 2"   # and the text doesn't change
  # A name that one line makes is there for the next
  caret!(5)
  run!()
  @test outcome(5).brief == "30"
  @test length(K.outcomes(e)) == 2
  shot("two")
end

@testset "the box is after the end of the line of code" begin
  fresh!(4)
  run!()
  r = rect(outcome(4))
  @test r !== nothing
  it = K.item(e, 4)
  f = it.content
  line_end = K.num(e.origin[1]) + K.num(K.xcol(f.lines[1], f.lines[1].to))
  @test K.num(r.left) ≈ line_end + K.num(K.OUTCOME_GAP) atol=1
  top = K.num(e.origin[2]) + K.num(it.top)
  @test top <= K.num(r.top) && K.num(r.top) + K.num(r.height) <= top + K.num(it.tall) + 1
end

@testset "an expression of several lines runs whole" begin
  fresh!(9, 1)
  run!()
  o = outcome(10)
  @test o !== nothing && o.first == 7   # with the comment above it
  @test startswith(o.brief, "double")
  # The comment and the last line run it too
  for line in (7, 10)
    fresh!(line)
    run!()
    @test outcome(10) !== nothing
  end
  # A blank line runs the piece above it
  fresh!(11)
  run!()
  @test outcome(10) !== nothing && length(K.outcomes(e)) == 1
end

@testset "a value of several lines opens with a click" begin
  fresh!(12)
  run!()
  o = outcome(12)
  @test o.brief == "2×2 Matrix{Int64}:"
  @test o.more && !o.open
  click(middle(rect(o)))
  @test o.open
  @test o.rest == " 1  2\n 3  4"
  @test rect(o.body) !== nothing
  @test K.num(rect(o.body).top) > K.num(rect(o).top)
  @test b.caret == (12, 0)   # the click didn't move the caret
  shot("open")
  click(middle(rect(o)))
  @test !o.open
end

@testset "what the code printed, what went wrong, and nothing" begin
  fresh!(13)
  run!()
  @test outcome(13).brief == "hi" && !outcome(13).failed
  caret!(14)
  run!()
  @test outcome(14).failed && outcome(14).brief == "no"
  caret!(15)
  run!()
  @test outcome(15).full == "" && !outcome(15).failed && !outcome(15).more
  @test rect(outcome(15)) !== nothing
  shot("kinds")
  # Code that ends with a semicolon shows no value
  fresh!(4, 9)
  typed(";")
  run!()
  @test outcome(4).full == "" && !outcome(4).failed
  # Code that can't be read says so
  fresh!(4, 8)
  typed("]")
  @test b.lines[4] == "x = 1 + ]2"
  run!()
  @test outcome(4).failed
  @test length(K.outcomes(e)) == 1   # the lines after it are pieces of their own
end

@testset "⇧Return runs the code and goes to the next piece" begin
  fresh!(4, 2)
  step!()
  @test outcome(4).brief == "3"
  @test b.caret == (5, 0)
  step!()
  @test outcome(5).brief == "30"
  @test b.caret == (7, 0)
  step!()
  @test outcome(10) !== nothing
  @test b.caret == (12, 0)
  @test length(b.lines) == length(split(TEXT, '\n'))   # no new lines
  # At the last piece, the caret stays at the end of it
  fresh!(15)
  step!()
  @test b.caret == (15, 7)
end

@testset "the line that opens the block runs every piece, as far as one that fails" begin
  fresh!(3)
  run!()
  @test [o.last for o in K.outcomes(e)] == [4, 5, 10, 12, 13, 14]
  @test outcome(14).failed
  shot("all")
end

@testset "a selection runs the code that's selected" begin
  fresh!(4)
  b.anchor, b.caret = (4, 4), (4, 9)
  frames()
  run!()
  @test outcome(4).brief == "3"
  @test b.anchor == (4, 4) && b.caret == (4, 9)
  # Whole lines, as far as the start of the line after them
  fresh!(4)
  b.anchor, b.caret = (4, 0), (6, 0)
  frames()
  run!()
  @test outcome(5) !== nothing && outcome(5).first == 4 && outcome(5).brief == "30"
end

@testset "a box follows its code, and goes when the code changes" begin
  fresh!(5)
  run!()
  # A new line above the code
  caret!(1, 6)
  key(Keys.enter)
  @test length(K.outcomes(e)) == 1 && outcome(6) !== nothing
  # A change to the line after it
  caret!(8, 0)
  typed("#")
  @test outcome(6) !== nothing
  # A change to the code itself
  caret!(6, 1)
  typed("y")
  @test isempty(K.outcomes(e))
end

@testset "Escape takes the boxes away, and then hides the caret" begin
  fresh!(4)
  run!()
  caret!(5)
  run!()
  key(Keys.escape)
  @test isempty(K.outcomes(e))
  @test !b.reading
  key(Keys.escape)
  @test b.reading
end

@testset "the keys do what they did in other places" begin
  n = length(split(TEXT, '\n'))
  # ⇧Return in a paragraph, and in code that isn't Julia, makes a new line
  for line in (18, 21)
    fresh!(line)
    step!()
    @test length(b.lines) == n + 1
    @test isempty(K.outcomes(e))
  end
  # ⌘Return there runs nothing. With no agent that waits for the page, it makes a new line, as it did before.
  fresh!(21)
  run!()
  @test isempty(K.outcomes(e)) && length(b.lines) == n + 1
end

@testset "a value that's a UI node shows as the node" begin
  fresh!(4, 9)
  key(Keys.enter)
  typed("Checkbox()")
  run!()
  o = outcome(5)
  @test o !== nothing && !o.failed
  @test o.brief == "Checkbox" && o.node !== nothing && o.open
  frames()
  @test rect(o.body) !== nothing
  shot("node")
end

@testset "a value has the colours of Julia code" begin
  "Each Text in the layout `node`, in the order they read"
  texts(node, out=K.Text[]) = begin
    node isa K.Text ? push!(out, node) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
    out
  end
  words(node) = [t.content for t in texts(node)]
  colour(node, word) = only(t.color for t in texts(node) if t.content == word)
  fresh!(12)
  run!()
  o = outcome(12)
  box = K.describe(o)
  @test join(words(box)) == "2×2 Matrix{Int64}:"
  @test colour(box, "Matrix") == K.colours.type
  @test all(t.color == K.colours.number for t in texts(box) if t.content == "2")
  click(middle(rect(o)))
  body = K.describe(o.body)
  @test colour(body, "3") == K.colours.number
  # Text that the code printed has the colour of the page's text, and what went wrong is red
  fresh!(13)
  K.edit!(b, (13, 0), (13, length(b.lines[13])), "println(\"Matrix 3\")")
  caret!(13)
  run!()
  @test words(K.describe(outcome(13))) == ["Matrix 3"]
  @test colour(K.describe(outcome(13)), "Matrix 3") == K.colours.ink
  caret!(14)
  run!()
  @test colour(K.describe(outcome(14)), "no") == K.SPELL_RED
  # A character that the code font lacks is drawn in a font that has it
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "collect(1:100)")
  caret!(4)
  run!()
  o = outcome(4)
  click(middle(rect(o)))
  @test occursin("⋮", o.rest)
  @test K.font_with('⋮') != K.CODE_FONT && !isempty(K.font_with('⋮'))
  @test [t.family for t in texts(K.describe(o.body)) if t.content == "⋮"] == [K.font_with('⋮')]
  # macOS finds a font for any character, like the star that starts the name of a module that Kip loaded
  @test !isempty(K.font_with('⭒')) && K.has(K.Face(K.font_with('⭒'), "", 12px, K.colours.ink, false), '⭒')
  @test [f.family for (_, f) in K.runs("Main.⭒Paint", K.outcome_face(12px))] == [K.CODE_FONT, K.font_with('⭒'), K.CODE_FONT]
  shot("colours")
end

@testset "code is in the light font, and a character that the font lacks is in one that has it" begin
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "3 ∈ [1, 2, 3]  # yes")
  caret!(5)
  segs = K.item(e, 4).content.lines[1].segs
  @test all(seg.face.family in (K.CODE_FONT, K.MONO) for seg in segs)
  @test join(seg.text for seg in segs) == b.lines[4]
  plain = first(seg for seg in segs if seg.text == "3")
  @test (plain.face.family, plain.face.style) == (K.CODE_FONT, K.CODE_STYLE)
  @test only(seg for seg in segs if occursin("yes", seg.text)).face.style == K.CODE_SLANT
  if K.CODE_FONT != K.MONO
    @test only(seg for seg in segs if occursin('∈', seg.text)).face.family == K.MONO
  end
  # The caret still lands where a click is: the columns of the line's parts run on from each other
  @test [seg.col for seg in segs] == cumsum([0; [seg.n for seg in segs[1:end-1]]])
  caret!(4)
  run!()
  @test outcome(4).brief == "true"
  shot("light")
end

@testset "code can use a name that a live block has, like width, for a thing of its own" begin
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "width = 2.4")
  K.edit!(b, (5, 0), (5, length(b.lines[5])), "height = width * 2")
  K.edit!(b, (12, 0), (12, length(b.lines[12])), "Row(width(100px), height(20px))")
  caret!(4)
  step!()
  step!()
  @test outcome(4).brief == "2.4" && outcome(5).brief == "4.8"
  # A live block's module keeps the name's own meaning, and gives it to a page that hasn't changed it
  @test K.sandbox(e).width !== 2.4
  @test !isdefined(K.sandbox(e), :double)
  was, b.path = b.path, joinpath(dir, "other.md")
  caret!(12)
  run!()
  @test !outcome(12).failed && outcome(12).node !== nothing
  # The units of a sheet are there too, on a page that hasn't used `m` for a thing of its own
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "12m * 2.4m")
  b.path = joinpath(dir, "other.md")
  caret!(4)
  run!()
  @test !outcome(4).failed
  @test endswith(outcome(4).brief, "m²")   # square metres
  empty!(K.outcomes(e))
  b.path = was
end

@testset "a line that ends near the edge of the window has its box under it" begin
  # A line of code that's as wide as the page, and comes to a value that's as long
  vl = K.item(e, 4).content.lines[1]
  wide = K.num(K.measure(first(vl.segs).face, "0"))
  n = floor(Int, (K.num(e.width) - K.num(vl.x)) / wide) - 1
  fresh!(4)
  K.edit!(b, (4, 0), (4, length(b.lines[4])), "string(\"" * "a"^(n - 10) * "\")")
  caret!(4)
  run!()
  o = outcome(4)
  @test o !== nothing && !o.failed
  it = K.item(e, 4)
  @test length(it.content.lines) == 1   # the line doesn't wrap
  @test K.num(rect(o).top) >= K.num(e.origin[2]) + K.num(it.top) + K.num(it.tall) - 6
  @test K.num(rect(o).left) < K.num(e.origin[1]) + 60
  @test K.num(rect(o).left) + K.num(rect(o).width) <= 1000
  shot("under")
end
