# Tests for what a pipe sends to the `ladder` command, in plugin/bin/ladder:
# `git log | ladder` writes what the command prints to a file of its own, with
# an ending that says what it is, and shows the file in Ladder. Run them with
# `julia -O0 --project=. test/pipe_test.jl`. They open no window: with
# LADDER_QUIET set, the command only writes the file.

@use Test: @test, @testset

const ladder = joinpath(@__DIR__, "..", "plugin", "bin", "ladder")
const dir = mktempdir()

"Send `text` to the command through a pipe, with `args`. It gives what the command printed, what it said went wrong, and its exit code."
pipe(text, args...) = begin
  out, err = IOBuffer(), IOBuffer()
  cmd = addenv(`$ladder $args`, "LADDER_QUIET" => "1", "LADDER_PIPED" => dir)
  p = run(pipeline(ignorestatus(cmd), stdin=IOBuffer(text), stdout=out, stderr=err))
  (strip(String(take!(out))), strip(String(take!(err))), p.exitcode)
end

@testset "what a pipe sends is a file of its kind" begin
  file, _, code = pipe("name,price\nscrews,48\noil,62\n", "--name", "costs")
  @test code == 0 && file == joinpath(dir, "costs.csv") && read(file, String) == "name,price\nscrews,48\noil,62\n"
  @test endswith(pipe("{\"a\": [1, 2]}\n", "--name", "j")[1], "j.json")
  @test endswith(pipe("[\n  1,\n  2\n]\n", "--name", "list")[1], "list.json")
  @test endswith(pipe("# Plan\n\nSome words.\n", "--name", "m")[1], "m.md")
  @test endswith(pipe("---\ntitle: Plan\n---\n", "--name", "front")[1], "front.md")
  # Words with a comma in one line aren't a table, and nor is a line that only starts like JSON
  @test endswith(pipe("Hello, world\nplain\n", "--name", "p")[1], "p.txt")
  @test endswith(pipe("[link] and words\nmore\n", "--name", "q")[1], "q.txt")
  @test endswith(pipe("commit 5fcb960\nAuthor: Sam\nDate:   Fri, 20 Nov 2026\n", "--name", "log")[1], "log.txt")
  # Without a name, the file has the time
  @test occursin(r"/\d{4}-\d\d-\d\d \d\d\.\d\d\.\d\d\.txt$", pipe("words\n")[1])
end

@testset "what the options say" begin
  # --as says the kind, whatever the text looks like
  file, _, _ = pipe("a;b\n1;2\n", "--as", "csv", "--name", "semi")
  @test file == joinpath(dir, "semi.csv")
  _, said, code = pipe("x\n", "--as", "pdf")
  @test code == 1 && occursin("csv, json, md or txt", said)
  @test pipe("x\n", "--name", "a/b")[3] == 1
  # The colours that a command writes for a terminal are left out
  file, _, _ = pipe("\e[31mred\e[0m and \e[1;32mgreen\e[0m\n", "--name", "colours")
  @test read(file, String) == "red and green\n"
  # A command that prints nothing has nothing to show
  _, said, code = pipe("")
  @test code == 1 && occursin("printed nothing", said)
  # A command of the tool still works when something comes in from a pipe
  _, said, code = pipe("x\n", "show", joinpath(dir, "nothing-here.md"))
  @test code == 1 && occursin("there's no file or folder", said)
  @test isempty(filter(startswith("."), readdir(dir)))
end
