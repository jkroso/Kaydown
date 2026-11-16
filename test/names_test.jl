# Tests for the names that a code block offers while you type. See "the names
# a code block offers" in main.jl. Run them with `julia -O0 --project=. test/names_test.jl`.
# They type and press keys in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "walls.md")
const TEXT = """
# Walls

```julia
wall_length = 4.2
wall_height = 2.4
width = 0.09
# the area of one side
area = wall_length * wall_height

```

Some words about a wall.

```python
wall_colour = "white"

```

```
plain text with a wall

```
"""
write(page, TEXT)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const b = e.buf
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

"Put the text back as it was, with the caret at `line` and `col`"
fresh!(line, col=0) = begin
  b.lines = String.(split(TEXT, '\n'))
  b.version = (K.stamp[] += 1)   # a new version, as an edit gives
  b.reading = false
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
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The names in the list that shows, or nothing when no list shows"
names() = (found = K.suggestion(e); found === nothing ? nothing : found[3])
"True when the window draws the list"
drawn() = !isempty(K.suggestbox(e))

const shots = get(ENV, "NAMES_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a list of the page's names shows as a name is typed" begin
  fresh!(9)
  typed("w")
  @test names() === nothing   # one character is too few
  typed("a")
  @test names()[1:2] == ["wall_height", "wall_length"]   # the nearest first
  @test drawn()
  shot("list")
  typed("ll_l")
  @test names() == ["wall_length"]
  # A name fits when one of its words starts with what's typed
  fresh!(9)
  typed("he")
  @test "wall_height" in names()
  @test all(startswith(n, "he") for n in names() if n != "wall_height")   # the names that start with it come first
end

@testset "Tab and Return type the rest of the name" begin
  fresh!(9)
  typed("wi")
  @test first(names()) == "width"
  key(Keys.tab)
  @test b.lines[9] == "width" && b.caret == (9, 5)
  @test names() === nothing
  fresh!(9)
  typed("x = wa")
  key(Keys.down)
  key(Keys.enter)
  @test b.lines[9] == "x = wall_length"
  @test length(b.lines) == length(split(TEXT, '\n'))   # Return didn't make a new line
  # ⌘Z takes the name away again
  key(Keys.z, Keys.cmd)
  @test b.lines[9] == "x = wa"
end

@testset "esc hides the list, and then the keys are the text's again" begin
  fresh!(9)
  typed("wa")
  key(Keys.escape)
  @test names() === nothing && !b.reading
  # The list stays hidden while the same name is typed
  typed("l")
  @test names() === nothing
  key(Keys.enter)
  @test length(b.lines) == length(split(TEXT, '\n')) + 1
  @test b.lines[9] == "wal"
  # A new name in the same place has its list
  fresh!(9)
  typed("wa")
  @test names()[1:2] == ["wall_height", "wall_length"]
end

@testset "no list shows where a name isn't being typed" begin
  n = length(split(TEXT, '\n'))
  shown = String[]
  for text in ("# wa", "\"wa", "area.wa", "wall_length", "length", "@show")
    fresh!(9)
    typed(text)
    names() === nothing || push!(shown, text)
  end
  @test shown == []
  # 2wa is two times wa, so the name starts after the digit
  fresh!(9)
  typed("2wa")
  @test names()[1:2] == ["wall_height", "wall_length"]
  # A word of the language, and the middle of a word
  fresh!(9)
  typed("end")
  @test names() === nothing
  fresh!(9)
  typed("wal")
  caret!(9, 2)
  typed("x")
  @test names() === nothing
  # The caret moves through code with no list in its way
  fresh!(9)
  typed("wa")
  caret!(8, 2)
  caret!(9, 2)
  frames()
  @test names() === nothing
  # Text, and a block with no language
  for line in (12, 20)
    fresh!(line, line == 12 ? 0 : 0)
    typed("wa")
    @test names() === nothing
  end
  @test length(b.lines) == n
end

@testset "each language has its own names" begin
  fresh!(16)
  typed("wa")
  @test names() == ["wall_colour"]
  fresh!(9)
  typed("wall_c")
  @test names() === nothing
end

@testset "Julia code gets Julia's own names, before any code has run" begin
  @test !haskey(e.nodes, :sandbox)
  fresh!(9)
  typed("len")
  @test first(names()) == "length"
  fresh!(9)
  typed("x = printl")
  @test names() == ["println"]
  key(Keys.tab)
  @test b.lines[9] == "x = println"
  fresh!(9)
  typed("@sh")
  @test first(names()) == "@show"
  key(Keys.enter)
  @test b.lines[9] == "@show"
  # The page's own names come first
  fresh!(9)
  typed("wi")
  @test first(names()) == "width" && "widen" in names()
  @test length(names()) <= K.NAMES_SHOWN
  @test !haskey(e.nodes, :sandbox)   # the list doesn't start the page's module
  # Code in another language doesn't get them
  fresh!(16)
  typed("len")
  @test names() === nothing
end

@testset "Julia code gets the names that the page's code made when it ran" begin
  fresh!(9)
  typed("total_paint = 5")
  key(Keys.enter, Keys.cmd)   # runs the line
  @test !only(K.outcomes(e)).failed
  fresh!(9)   # the line is gone from the text
  typed("tot")
  @test first(names()) == "total_paint"
  # ... and the names that a live block has
  fresh!(9)
  typed("Sli")
  @test names() !== nothing && "Slider" in names()
  shot("made")
end

@testset "⌘Return still runs the code while the list shows" begin
  fresh!(9)
  typed("wall_length * wa")
  @test names() !== nothing
  key(Keys.enter, Keys.cmd)
  @test b.lines[9] == "wall_length * wa"
  @test length(K.outcomes(e)) == 1
end
