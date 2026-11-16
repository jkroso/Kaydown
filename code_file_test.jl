# Tests for a Julia file that the page changes. See "A Julia file is one block
# of code" in main.jl. Run them with `julia --project=. code_file_test.jl`.
# They type and press keys in a window that isn't on the screen.

@use Test: @test, @testset
@use "./main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "walls.jl")
const TEXT = """
# The walls of a room
wall_length = 4.2
wall_height = 2.4

area(l, h) = begin
  l * h
end

area(wall_length, wall_height)
"""
write(file, TEXT)
const notes = joinpath(dir, "notes.md")
write(notes, "# Notes\n\n```jl\nwall_length = 4.2\n```\n")
write(joinpath(dir, "walls.py"), "wall_length = 4.2\n")
write(joinpath(dir, "bytes.jl"), UInt8[0x6a, 0x00, 0x01, 0x02, 0xff, 0x0a])

const e = K.build_editor(file)
const w = Window(e, size=(1000px, 800px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)

caret!(line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); frames())
key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
outcome(line) = (k = findfirst(o -> o.last == line, K.outcomes(e)); k === nothing ? nothing : K.outcomes(e)[k])

const shots = get(ENV, "CODE_FILE_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a Julia file opens as code that the page changes" begin
  b = e.buf
  @test b.view == :code && !K.readonly(b)
  @test b.lines == split(TEXT, '\n')
  @test length(e.layout) == length(b.lines)   # one line of the page for each line of the file
  @test all(k -> k.kind == K.Kind.code && k.lang == "jl", K.kinds(b))
  # The whole page is code, so its lines start at the edge of the page
  @test K.item(e, 2).content.lines[1].x == 0px
  @test K.julia_code(b, 5) == (1, length(b.lines))
end

@testset "typing changes the text, and ⌘S writes the file" begin
  b = e.buf
  caret!(3, length(b.lines[3]))
  typed("5")
  @test b.lines[3] == "wall_height = 2.45"
  @test K.dirty(b)
  @test read(file, String) == TEXT   # nothing is written yet
  key(Keys.s, Keys.cmd)
  @test !K.dirty(b)
  @test read(file, String) == replace(TEXT, "2.4\n" => "2.45\n")
  # Return in a function's body starts the new line under the text of the line before
  caret!(6, length(b.lines[6]))
  key(Keys.enter)
  @test b.lines[7] == "  " && b.caret == (7, 2)
  key(Keys.z, Keys.cmd)
  @test b.lines == split(replace(TEXT, "2.4\n" => "2.45\n"), '\n')
  # ↑ and ↓ move the caret through the lines
  caret!(2, 4)
  key(Keys.down)
  @test e.buf.caret == (3, 4)
  key(Keys.up)
  @test e.buf.caret == (2, 4)
end

@testset "⌘Return runs the expression that the caret is in" begin
  b = e.buf
  caret!(6, 1)   # in the body of the function
  key(Keys.enter, Keys.cmd)
  o = outcome(7)
  @test o !== nothing && !o.failed && o.first == 5
  caret!(2)
  key(Keys.enter, Keys.shft)
  key(Keys.enter, Keys.shft)
  @test outcome(2).brief == "4.2" && outcome(3).brief == "2.45"
  caret!(9)
  key(Keys.enter, Keys.cmd)
  @test outcome(9).brief == string(4.2 * 2.45)
  @test rect(outcome(9)) !== nothing
  shot("file")
  key(Keys.escape)
  @test isempty(K.outcomes(e))
end

@testset "the file offers names as its code is typed" begin
  b = e.buf
  caret!(10)
  typed("wall_l")
  @test K.suggestion(e) !== nothing && K.suggestion(e)[3] == ["wall_length"]
  key(Keys.tab)
  @test b.lines[10] == "wall_length"
  key(Keys.z, Keys.cmd)
  key(Keys.z, Keys.cmd)
end

@testset "a file that isn't Julia, and one that isn't text, are only shown" begin
  K.open!(e, joinpath(dir, "walls.py")); frames()
  @test e.buf.view == :text && K.readonly(e.buf)
  typed("x")
  @test e.buf.lines[1] == "wall_length = 4.2"
  K.open!(e, joinpath(dir, "bytes.jl")); frames()
  @test K.readonly(e.buf)
end

@testset "a page's code block still has its own look" begin
  K.open!(e, notes); frames()
  @test e.buf.view == :markdown
  # The same line of code as the file has, in a block with a background and room on its left
  @test K.item(e, 4).content.lines[1].x == K.BLOCK_X
  K.open!(e, file); frames()
  @test e.buf.view == :code
  @test K.item(e, 2).content.lines[1].x == 0px
  @test e.buf.lines[3] == "wall_height = 2.45"   # the file is as it was left
end
