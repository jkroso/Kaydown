# Tests for changes.jl. Run them with `julia -O0 --project=. test/changes_test.jl`.

@use Test: @test, @testset
@use "../changes" => D

const BLOCK = ["diff --git a/src/app.js b/src/app.js",
               "index 83db48f..bf2a3c1 100644",
               "--- a/src/app.js",
               "+++ b/src/app.js",
               "@@ -10,4 +10,5 @@ function start() {",
               "   const a = 1",
               "-  const b = 2",
               "+  const b = 3",
               "+  const c = 4",
               "   return a",
               "@@ -30 +31 @@ [accepted]",
               "-  stop()",
               "+  stop(now)",
               "\\ No newline at end of file",
               "--- a/notes.txt",
               "+++ /dev/null",
               "@@ -1 +0,0 @@",
               "--- old notes"]

@testset "reading" begin
  c = D.changes(BLOCK)
  @test length(c.hunks) == 3 && [h.file for h in c.hunks] == ["src/app.js", "src/app.js", "notes.txt"]
  h = c.hunks[1]
  @test h.at == 5 && h.first == 6 && h.state == :open && h.about == "function start() {" && h.head == BLOCK[5]
  @test [r.sign for r in h.rows] == [' ', '-', '+', '+', ' '] && h.rows[2].text == "  const b = 2"
  @test [(r.old, r.new) for r in h.rows] == [(10, 10), (11, 0), (0, 11), (0, 12), (12, 13)]
  @test D.counts(h) == (2, 1) && D.place(h) == "Lines 10 to 13"
  @test c.hunks[2].state == :accepted && c.hunks[2].about == "" && c.hunks[2].head == "@@ -30 +31 @@" && length(c.hunks[2].rows) == 2
  # The numbers of the @@ line say that this line is a line that goes, not the name of a file
  @test c.hunks[3].rows == [D.Row('-', "-- old notes", 1, 0)] && D.place(c.hunks[3]) == "Line 1"
  @test D.counts(c) == (3, 3) && D.summary(c) == "3 changes  ·  1 accepted"
  @test isempty(D.changes(String[]).hunks) && isempty(D.changes(["Some words", "", "more words"]).hunks)
end

@testset "choosing and writing" begin
  c = D.changes(BLOCK)
  @test D.written(c) == BLOCK
  D.choose!(c, 1, :rejected)
  out = D.written(c)
  @test out[5] == "@@ -10,4 +10,5 @@ function start() { [rejected]" && out[11] == BLOCK[11] && length(out) == length(BLOCK)
  D.choose!(c, 2, :accepted)   # it was accepted, so this takes the choice away
  @test D.written(c)[11] == "@@ -30 +31 @@"
  D.choose!(c, :accepted)
  out = D.written(c)
  @test out[5] == "@@ -10,4 +10,5 @@ function start() { [accepted]" && out[17] == "@@ -1 +0,0 @@ [accepted]"
  again = D.changes(out)
  @test all(h -> h.state == :accepted, again.hunks) && again.hunks[1].about == "function start() {" && D.written(again) == out
  @test D.summary(again) == "3 changes  ·  3 accepted"
end

@testset "a change with no numbers" begin
  c = D.changes(["Change the greeting:", "-hello", "+hello there", " world", "", "@@ in the footer", "-bye", "+goodbye"])
  @test length(c.hunks) == 2 && c.hunks[1].at == 0 && c.hunks[1].first == 2 && length(c.hunks[1].rows) == 3
  @test c.hunks[2].about == "in the footer" && D.place(c.hunks[1]) == ""
  D.choose!(c, 1, :accepted); D.choose!(c, 2, :rejected)
  out = D.written(c)
  @test out == ["Change the greeting:", "@@ [accepted]", "-hello", "+hello there", " world", "", "@@ in the footer [rejected]", "-bye", "+goodbye"]
  again = D.changes(out)
  @test [h.state for h in again.hunks] == [:accepted, :rejected] && again.hunks[1].at == 2 && D.written(again) == out
  D.choose!(again, 1, :accepted)
  @test D.written(again)[2] == "@@"
end
