# Tests for ⌘W: it closes the file, and the window stays open with no file in it.
# ⌘W in a window with no file closes the window. See "closing a file" in main.jl.
# Run them with `julia -O0 --project=. test/close_test.jl`. They press keys in
# windows that aren't on the screen.

@use "../main" => K
@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png

const px = K.px
const cmd, opt = Keys.cmd, Keys.opt

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))

"A folder of its own with the pages `names` in it, and a window that isn't on the screen on the first of them"
window(names...) = begin
  folder = mktempdir(dir)
  foreach(name -> write(joinpath(folder, name), "# $name\n\nThe text of $name.\n"), names)
  e = K.build_editor(joinpath(folder, first(names)))
  w = K.window!(e, size=(900px, 700px))
  frames(w)
  e, w, folder
end
frames(w, n=2) = foreach(_ -> frame(w), 1:n)
"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
"Every piece of text that a node shows"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.SemanticUI ? texts(K.describe(node), out) :
  node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
shot(w, name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

@testset "⌘W closes the file, and the window stays open" begin
  e, w, folder = window("a.md", "b.md")
  @test K.caps(first(K.bundle_keys("Ladder")[:close])) == "⌘W"
  press(w, Keys.w, cmd)
  @test e in K.editors
  @test K.nofile(e) && isempty(e.buf.path)
  shot(w, "close-nofile.png")
  # The page says that no file is open, and which keys find one and close the window. The top bar names no file.
  said = texts(e.nodes[:page])
  @test said == ["No file is open", "⌘O finds a file", "⌘W closes the window"]
  @test isempty(texts(e.nodes[:title]))
  # Nothing can be typed in it
  ontype(w, Typed('x', w)); frames(w)
  @test e.buf.lines == [""] && K.nofile(e)
  # A file opens in it as in any window
  K.open!(e, joinpath(folder, "b.md")); frames(w)
  @test basename(e.buf.path) == "b.md" && !K.nofile(e)
  close(w)
end

@testset "⌘W in a window with no file closes the window" begin
  e, w, _ = window("a.md")
  press(w, Keys.w, cmd)
  @test e in K.editors
  press(w, Keys.w, cmd)
  @test !(e in K.editors)
end

@testset "a file that closes keeps its changes, and ⌘⌥← shows it again" begin
  e, w, _ = window("a.md")
  K.type!(e, "words"); frames(w)
  @test K.dirty(e.buf)
  lines = copy(e.buf.lines)
  press(w, Keys.w, cmd)
  @test K.nofile(e) && basename.(e.back) == ["a.md"]
  press(w, Keys.left, cmd, opt)
  @test basename(e.buf.path) == "a.md" && e.buf.lines == lines && K.dirty(e.buf)
  close(w)
end

@testset "the settings window closes at once" begin
  e, w, _ = window("a.md")
  press(w, Keys.comma, cmd)
  s = K.settings_editor()
  sw = K.window_of(s)
  frames(sw)
  press(sw, Keys.w, cmd)
  @test K.settings_editor() === nothing && !(s in K.editors)
  # The other window still shows its file
  @test basename(e.buf.path) == "a.md"
  close(w)
  @test isempty(K.editors)
end
