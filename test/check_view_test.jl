# Tests for the `check` block, in main.jl: each line of the block is a line of
# Julia that must be true, and shows a tick or a cross. The lines run in the
# module of the page's code, and run again when the page's code runs. Run them
# with `julia -O0 --project=. test/check_view_test.jl`. They draw a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "room.md")
write(page, """
# A room

```julia
walls = [4.0, 3.0, 4.0, 3.0]
ceiling = 2.4
area() = sum(walls) * ceiling
```

```check
# The room as it was measured
length(walls) == 4
area() ≈ 33.6
area() < 30
ceiling
no_such_name > 1
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
view() = e.nodes[(:block, K.CHECK, page, 1)]
went() = [r.went for r in view().results]
"Run the page's Julia block, as ⌘Return in it does"
run_page() = (i = findfirst(==("```julia"), e.buf.lines); t = findnext(==("```"), e.buf.lines, i); K.run_code(e, join(e.buf.lines[i+1:t-1], "\n")); frames())

@testset "the lines that are checks" begin
  @test K.checks(["# Words", "", "  a == 1  ", "b > 2"]) == ["a == 1", "b > 2"]
  @test K.check_words(K.Checked[]) == "No checks yet. Write one on each line, like total == 12."
  one(went) = K.Checked("x", went, "")
  @test K.check_words([one(:pass)]) == "The check passes" && K.check_words([one(:pass), one(:pass)]) == "All 2 checks pass"
  @test K.check_words([one(:pass), one(:fail), one(:stop)]) == "1 of 3 checks passes" && K.check_words([one(:fail)]) == "0 of 1 check pass"
end

@testset "before the page's code has run, each line stops at a name that nothing made" begin
  @test length(view().results) == 5 && all(==(:stop), went())
  @test occursin("walls", view().results[1].said)
end

@testset "each line shows how it went" begin
  run_page()
  rs = view().results
  @test went() == [:pass, :pass, :fail, :fail, :stop]
  # A line that compares two values and fails says what each was
  @test rs[3].said == "33.6 < 30" && isempty(rs[1].said)
  @test rs[4].said == "It came to 2.4, which is neither true nor false."
  @test occursin("no_such_name", rs[5].said)
  @test K.check_words(rs) == "2 of 5 checks pass"
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "check.png"), w)
end

@testset "the checks run again when the page's code runs, and when a line changes" begin
  i = findfirst(==("ceiling = 2.4"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "ceiling = 2.0")
  frames()
  @test went()[3] == :fail   # the code hasn't run yet
  run_page()
  @test went() == [:pass, :fail, :pass, :fail, :stop] && view().results[2].said == "28.0 ≈ 33.6"
  # A line of the block that changes runs again, with the caret out of the block
  i = findfirst(==("area() ≈ 33.6"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "area() ≈ 28")
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test went() == [:pass, :pass, :pass, :fail, :stop]
end

@testset "a click runs them again" begin
  ran = Ref(0)
  @eval K.workspace(e) counted() = ($ran[] += 1; true)
  i = findfirst(==("ceiling"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "counted()")
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test went()[4] == :pass && ran[] == 1
  frames()
  @test ran[] == 1   # a frame alone runs nothing
  r = rect(view())
  pos = Vec2{px}(r.left + 40px, r.top + 12px)
  w.mouse = typeof(w.mouse)(pos...)
  onmouse(w, MouseMove(pos, w))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
  @test ran[] == 2
end

@testset "the block as HTML, and in the Insert menu" begin
  html = K.check_html(e, view())
  @test occursin("<strong>4 of 5 checks pass</strong>", html) && occursin("<li>✓ <code>length(walls) == 4</code></li>", html)
  @test occursin("<li>✗ <code>no_such_name &gt; 1</code>: ", html)
  @test any(x -> x isa Tuple && x[1] == "Check", K.INSERTS) && K.known_lang("check")
end

close(w)
