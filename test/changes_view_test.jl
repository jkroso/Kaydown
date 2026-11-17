# Tests for the `changes` block of main.jl: the changes of a diff, with
# buttons that accept and reject each one. Run them with
# `julia -O0 --project=. test/changes_view_test.jl`. They click in a window
# that isn't on the screen. Set `KAYDOWN_SHOTS` to a folder, and they save a
# picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "review.md")
write(page, """
# A review

```changes
--- a/src/app.js
+++ b/src/app.js
@@ -10,4 +10,5 @@ function start() {
   const a = 1
-  const b = 2
+  const b = 3
+  const c = 4
   return a
@@ -30 +31 @@
-  stop()
+  stop(now)
--- a/Readme.md
+++ b/Readme.md
@@ -1,2 +1,2 @@
-# App
+# The app
 It starts with `start()`.
```

The end.

```changes
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
view(n) = e.nodes[(:block, K.CHANGES, page, n)]
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(key) = click(middle(rect(view(1).parts[(:button, key)])))
block() = (s = K.block_lines(e.buf, K.CHANGES, 1); e.buf.lines[s[1]+1:s[2]-1])

@testset "the block shows each change" begin
  v = view(1)
  @test length(v.data.hunks) == 3 && K.Diffs.summary(v.data) == "3 changes"
  # The lines of a change are as tall as the change has lines
  @test rect(v.parts[(:hunk, 1)]).height == px(5 * K.DIFF_ROW + 8) && rect(v.parts[(:hunk, 2)]).height == px(2 * K.DIFF_ROW + 8)
  @test rect(v.parts[(:hunk, 3)]).top > rect(v.parts[(:hunk, 2)]).top > rect(v.parts[(:hunk, 1)]).top
  @test isempty(view(2).data.hunks)
  @test any(en -> en.title == "Changes", K.outline(e.buf))
  @test !K.dirty(e.buf)
end

@testset "the buttons accept and reject a change" begin
  button((:accept, 1))
  @test block()[3] == "@@ -10,4 +10,5 @@ function start() { [accepted]" && view(1).data.hunks[1].state == :accepted && K.dirty(e.buf)
  button((:reject, 2))
  @test block()[9] == "@@ -30 +31 @@ [rejected]" && K.Diffs.summary(view(1).data) == "3 changes  ·  1 accepted  ·  1 rejected"
  shot("changes.png")
  # A click on the choice that a change has takes it away
  button((:reject, 2))
  @test block()[9] == "@@ -30 +31 @@"
  button((:reject, 1))
  @test endswith(block()[3], "{ [rejected]")
  K.undo!(e.buf); frames()
  @test endswith(block()[3], "{ [accepted]") && view(1).data.hunks[1].state == :accepted
  button(:reject_all)
  @test all(h -> h.state == :rejected, view(1).data.hunks) && count(l -> endswith(l, "[rejected]"), block()) == 3
  button(:accept_all)
  @test count(l -> endswith(l, "[accepted]"), block()) == 3 && length(block()) == 17
  @test e.buf.lines[findfirst(==("The end."), e.buf.lines)] == "The end."
  html = K.page_html(e)
  @test occursin("<strong>src/app.js · Lines 10 to 13 · Accepted</strong>", html) && occursin("+   const c = 4</span>", html)
end
