# Tests for the caret's glide: the caret moves to a new place in a short time,
# and doesn't jump there. See "the caret's glide" in main.jl. Run them with
# `julia -O0 --project=. test/caret_glide_test.jl`. They press keys and type in
# a window that isn't on the screen. With LADDER_SHOTS set to a folder, they
# save a picture of the caret on its way.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
const kept = joinpath(dir, "settings")
@eval K settings_file() = $kept

const page = joinpath(dir, "notes.md")
const other = joinpath(dir, "other.md")
write(page, "# A heading\n\nSome words on a line.\n\nAnd a last line of words.\n")
write(other, "# Other\n\nAnother page.\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frame(w))
type(text) = (foreach(c -> ontype(e, Typed(c, w)), text); frame(w))
caret!(p) = (e.buf.caret = e.buf.anchor = p; K.touch!(e); frame(w))
line(text) = findfirst(==(text), e.buf.lines)
"Draw frames until the caret has arrived"
arrive() = (sleep(K.GLIDE_TIME + 0.02); frames())
"The glide of the main caret"
glide() = e.glides[1]
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
frames()
K.focus(e)   # only the page that has the keyboard draws its caret
frames()

@testset "a caret on its way is between its two places" begin
  g = K.Glide((0.0, 0.0, 20.0), (90.0, 30.0, 40.0), 10.0, UInt(0), ((1, 0), 0))
  @test K.glided(g, 10.0) == g.from
  @test K.glided(g, 10.0 + K.GLIDE_TIME) == g.to && K.glided(g, 99.0) == g.to
  half = K.glided(g, 10.0 + K.GLIDE_TIME / 2)
  # It's fast at first, so half of the time takes it more than half of the way
  @test 45 < half[1] < 90 && 15 < half[2] < 30 && 30 < half[3] < 40
end

@testset "the caret of a page that has just opened is at its place" begin
  @test w.focus === e && e.glide
  @test glide().from == glide().to && !K.gliding(e) && !w.animating
end

@testset "an arrow key sends the caret off, and the window draws until it arrives" begin
  words = line("Some words on a line.")
  caret!((words, 0)); arrive()
  was = glide().to
  key(Keys.right)
  @test e.buf.caret == (words, 1)
  g = glide()
  # It left from where it was, for a place to the right on the same line
  @test g.from == was && g.to[1] > was[1] && g.to[2] == was[2] && g.to[3] == was[3]
  @test K.gliding(e) && w.animating
  # A frame that has nothing new goes on with the move
  frame(w)
  @test glide() === g && g.from == was
  arrive()
  @test !K.gliding(e) && !w.animating
  # ↓ takes it down the page, and to the height of the text there
  key(Keys.up); key(Keys.up); arrive()
  @test e.buf.caret[1] == line("# A heading")
  head = glide().to
  key(Keys.down); key(Keys.down)
  @test glide().to[2] > head[2] && glide().to[3] < head[3] && K.gliding(e)
  arrive()
end

@testset "a caret that's sent on before it arrives goes on from where it is" begin
  words = line("Some words on a line.")
  caret!((words, 0)); arrive()
  start = glide().to
  caret!((words, 20))
  g = glide()
  far = g.to
  shot("glide-on-its-way.png")
  # Half of the time later, it's sent to a place between the two
  e.buf.caret = e.buf.anchor = (words, 10)
  to = (start[1] + 5, start[2], start[3])
  at = K.glide_to!(e, 1, to, g.left_at + K.GLIDE_TIME / 2)
  @test start[1] < at[1] < far[1] && g.from == at && g.to == to
  arrive()
end

@testset "what's typed moves the caret the same way" begin
  last = line("And a last line of words.")
  caret!(K.line_end(e.buf, last)); arrive()
  was = glide().to
  type("!")
  @test e.buf.lines[last] == "And a last line of words.!"
  @test glide().from == was && glide().to[1] > was[1] && K.gliding(e)
  arrive()
end

@testset "a page that's laid out again has its caret at the new place at once" begin
  was = glide().to
  K.zoom!(e, 1.5); frame(w)
  @test glide().to != was && glide().from == glide().to && !K.gliding(e)
  K.zoom!(e, 1.0); frames()
  @test glide().to == was && !K.gliding(e)
  # So has another page that the window shows
  K.open!(e, other); frame(w)
  @test glide().from == glide().to && !K.gliding(e)
  K.open!(e, page); frames()
end

@testset "each of several carets moves from its own place" begin
  words, last = line("Some words on a line."), line("And a last line of words.!")
  caret!((words, 4))
  push!(e.buf.others, ((last, 4), (last, 4))); K.keep_others!(e.buf)
  frame(w); arrive()
  @test sort(collect(keys(e.glides))) == [1, 2]
  one, two = e.glides[1].to, e.glides[2].to
  @test two[2] > one[2] && e.glides[2].from == two
  key(Keys.right)
  @test length(K.others(e.buf)) == 1
  @test e.glides[1].from == one && e.glides[1].to[1] > one[1]
  @test e.glides[2].from == two && e.glides[2].to[1] > two[1]
  arrive()
  # With one caret again, only the main one is kept
  key(Keys.escape); caret!((words, 0)); arrive()
  @test collect(keys(e.glides)) == [1]
end

@testset "with the setting off, the caret jumps" begin
  words = line("Some words on a line.")
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.glide!(e, false)
    @test occursin("glide=false", read(K.settings_file(), String))
    @test !K.load_settings!(K.Editor()).glide
    caret!((words, 0)); frames()
    was = glide().to
    key(Keys.right)
    @test glide().from == glide().to && glide().to[1] > was[1] && !K.gliding(e) && !w.animating
    K.glide!(e, true)
    @test K.load_settings!(K.Editor()).glide
    e.remember = false
  end
  # The settings page has a box for it
  @test occursin("page_glide!", read(K.settings_page(), String))
end

close(w)
