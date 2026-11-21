# Tests for checks in a file of Julia code, in main.jl: a comment like
# `# check: share("70%") == 0.7` runs in the module of the file's code, and a
# dot at the end of its line says how it went. Run them with
# `julia -O0 --project=. test/file_checks_test.jl`. They draw a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

# The folder has the same name each time, so that Kip compiles its file once
const dir = joinpath(tempdir(), "ladder-file-checks-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))

const source = joinpath(dir, "shares.jl")
write(source, """
"A share written as a percentage, like \\"70%\\", as a number from 0 to 1"
# check: share("70%") == 0.7
# check: share("5%") == 0.5
# check: share("half")
share(s) = parse(Float64, rstrip(s, '%')) / 100

#check:twice(2) == 4
twice(x) = 2x
""")

const e = K.build_editor(source)
const w = Window(e, size=(900px, 400px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(3)
const b = e.buf
results() = e.nodes[:file_checks].results
went(code) = results()[code].went

@testset "the comments that are checks" begin
  @test K.file_checks(b.lines) == [(2, "share(\"70%\") == 0.7"), (3, "share(\"5%\") == 0.5"), (4, "share(\"half\")"), (7, "twice(2) == 4")]
  @test K.file_checks(["# checks: none", "x = 1  # check: not at the start", "# check:", "  # check: indented(1)"]) == [(4, "indented(1)")]
end

@testset "a check of a function that hasn't run yet says to run it" begin
  @test went("twice(2) == 4") == :stop
  note = K.check_note(results()["twice(2) == 4"], false)
  @test occursin("twice", note) && endswith(note, "Press ⌘Return in its function to run it.")
end

@testset "the checks run again when code runs, and say how each went" begin
  K.run_code(e, join(b.lines, "\n"))
  frames()
  @test went("share(\"70%\") == 0.7") == :pass && went("twice(2) == 4") == :pass
  # A check that compares two values and fails says what the two were
  @test went("share(\"5%\") == 0.5") == :fail && K.check_note(results()["share(\"5%\") == 0.5"], false) == "0.05 == 0.5"
  # One that stops says why
  @test went("share(\"half\")") == :stop && occursin("half", results()["share(\"half\")"].said)
  @test K.check_note(results()["share(\"70%\") == 0.7"], false) == ""
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "file-checks.png"), w)
end

@testset "a check that changes runs again" begin
  K.edit!(b, (3, 16), (3, 17), "50")
  @test b.lines[3] == "# check: share(\"50%\") == 0.5"
  frames()
  @test went("share(\"50%\") == 0.5") == :pass
  # They don't run again while neither a check nor the code changed
  ran = e.nodes[:file_checks].ran
  K.edit!(b, (5, 0), (5, 0), " ")
  frames()
  @test e.nodes[:file_checks].ran === ran
end

@testset "a page of Markdown has no checks of this kind" begin
  page = joinpath(dir, "page.md")
  write(page, "# check: 1 == 2\n")
  K.open!(e, page)
  frames()
  @test !K.julia_file(e)
end

close(w)
