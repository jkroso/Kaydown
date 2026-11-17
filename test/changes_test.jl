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

@testset "the words that are different" begin
  alike, gone, come = D.compare("  const b = 2", "  const b = 3")
  @test alike > 0.8 && gone == [13:13] && come == [13:13]
  # One space between two words that are different is marked with them
  alike, gone, come = D.compare("say(\"Hi You\")", "say(\"Hello There\")")
  @test gone == [6:11] && come == [6:16]
  @test D.compare("stop()", "stop(now)")[2:3] == ([], [6:8])
  @test D.compare("alpha beta", "gamma delta")[1] == 0
  @test D.compare("", "")[1] == 1
  @test D.words("a_1 +  b") == [(1, "a_1"), (4, " "), (5, "+"), (6, "  "), (8, "b")]
end

@testset "the lines that are versions of each other" begin
  # The line that goes is matched with the line that's most like it, not with the first line that comes
  h = D.changes(["@@ -1,3 +1,4 @@", " greet(name) = begin", "-  println(\"Hello \", name)", "+  isempty(name) && return",
                 "+  println(\"Hello, \", name, \"!\")", " end"]).hunks[1]
  other, marks = D.matched(h)
  # The new line has all the words of the old one, so only the new line has words to mark
  @test other == [0, 4, 0, 2, 0] && isempty(marks[3]) && isempty(marks[2]) && marks[4] == [17:17, 26:30]
  @test D.sides(h) == [(1, 1), (0, 3), (2, 4), (5, 5)]
  # Lines that aren't alike have no match, and still share a line across
  h = D.changes(["@@", "-alpha beta", "-one(two)", "+gamma delta", " same"]).hunks[1]
  other, marks = D.matched(h)
  @test other == [0, 0, 0, 0] && all(isempty, marks)
  @test D.sides(h) == [(1, 3), (2, 0), (4, 4)]
  # Lines that only come, and lines that only go
  h = D.changes(["@@", "+a", "+b", " c", "-d"]).hunks[1]
  @test D.sides(h) == [(0, 1), (0, 2), (3, 3), (4, 0)] && D.matched(h)[1] == [0, 0, 0, 0]
  # A line that only moved in or out has nothing to mark
  h = D.changes(["@@", "-  x = 1", "+    x = 1"]).hunks[1]
  @test D.matched(h) == ([2, 1], [[], []])
end

@testset "what you say about a line" begin
  c = D.changes(BLOCK)
  D.note!(c, 1, 3, "Why 3?")
  D.note!(c, 2, 1, "- keep this\nline")
  out = D.written(c)
  # The comments are at the end of the block, each with the line that it's about
  @test out[1:length(BLOCK)] == BLOCK && out[end-3:end] == ["# Comment on change 1, line 3: +  const b = 3", "# Why 3?",
                                                              "# Comment on change 2, line 1: -  stop()", "# - keep this line"]
  again = D.changes(out)
  @test again.notes == Dict((1, 3) => "Why 3?", (2, 1) => "- keep this line") && D.written(again) == out
  @test length(again.hunks) == 3 && [length(h.rows) for h in again.hunks] == [5, 2, 1]
  @test D.summary(again) == "3 changes  ·  1 accepted  ·  2 comments"
  # A choice and a comment are written together, and the words keep a space at their end while you type
  D.choose!(again, 1, :rejected); D.note!(again, 1, 3, "Why 3? ")
  out = D.written(again)
  @test out[5] == "@@ -10,4 +10,5 @@ function start() { [rejected]" && out[end-2] == "# Why 3? " && D.changes(out).notes[(1, 3)] == "Why 3? "
  # Empty words take the comment away
  D.note!(again, 1, 3, " "); D.note!(again, 2, 1, "")
  @test D.written(again)[[1:4; 6:end]] == BLOCK[[1:4; 6:end]] && isempty(again.notes)
  # A change with no numbers gets its comment too, after its last line
  c = D.changes(["-hello", "+hello there", " world"])
  D.note!(c, 1, 2, "Too long")
  out = D.written(c)
  @test out == ["-hello", "+hello there", " world", "# Comment on change 1, line 2: +hello there", "# Too long"]
  again = D.changes(out)
  @test length(again.hunks) == 1 && length(again.hunks[1].rows) == 3 && again.notes == Dict((1, 2) => "Too long")
end
