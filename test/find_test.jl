# Tests for find.jl. Run them with `julia -O0 --project=. test/find_test.jl`.

@use Test: @test, @testset
@use "../find" => F

const PAGE = ["---", "title: Call the plumber", "---",
              "# The **Kitchen** job", "",
              "- [x] Call the plumber",
              "- [ ] Call the *plumber* again",
              "  - [ ] Order the tap",
              "The plumber is Sam.",
              "```",
              "- [ ] plumber in code",
              "```",
              "| Trade | Who |",
              "## Later"]

texts(ms) = [m.text for m in ms]

@testset "reading and writing" begin
  q = F.query(["what: done items", "with: Plumber  tap", "in: jobs/2026", "sort: newest"])
  @test q.what == :done && q.with == ["Plumber", "tap"] && q.folder == "jobs/2026" && q.other == ["sort: newest"]
  @test F.written(q) == ["what: done items", "with: Plumber tap", "in: jobs/2026", "sort: newest"]
  # An empty block lists the to-do items, and words by themselves are the words to find
  @test F.kind(F.query(String[])) == :todo && isempty(F.written(F.query(String[])))
  bare = F.query(["plumber"])
  @test bare.with == ["plumber"] && F.kind(bare) == :line && F.written(bare) == ["with: plumber"]
  @test F.query(["headings"]).what == :heading && F.query(["what: todos"]).what == :todo && F.query(["what: lines"]).what == :line
end

@testset "what matches" begin
  find(lines...) = F.matches(F.query(collect(lines)), "/notes/job.md", PAGE)
  @test texts(find()) == ["Call the plumber again", "Order the tap"]
  @test [m.line for m in find()] == [7, 8] && all(m -> m.kind == :todo && m.path == "/notes/job.md", find())
  @test texts(find("what: done items")) == ["Call the plumber"]
  @test texts(find("headings")) == ["The Kitchen job", "Later"]
  # Every word has to be in the line, in any case. Code and front matter aren't the page's text.
  @test texts(find("PLUMBER")) == ["Call the plumber", "Call the plumber again", "The plumber is Sam."]
  @test texts(find("plumber sam")) == ["The plumber is Sam."] && isempty(find("plumber electrician"))
  @test texts(find("what: to-do items", "with: plumber")) == ["Call the plumber again"]
  @test texts(find("trade")) == ["| Trade | Who |"]
end

@testset "a line that moved, and its tick" begin
  m = F.matches(F.Query(), "job.md", PAGE)[2]
  @test F.locate(m, PAGE) == 8
  @test F.locate(m, ["A new line"; PAGE]) == 9 && F.locate(m, PAGE[4:end]) == 5
  @test F.locate(m, replace(PAGE, "  - [ ] Order the tap" => "  - [x] Order the tap")) === nothing
  @test F.locate(m, ["# Nothing"]) === nothing
  @test F.ticked("  - [ ] Order the tap", true) == "  - [x] Order the tap" && F.ticked("- [x] Ça va [here]", false) == "- [ ] Ça va [here]"
  @test F.ticked("no box", true) == "no box"
end

@testset "what the list is of, in words" begin
  @test F.summary(F.Query(), 3, 2) == "3 to-do items in 2 pages of this folder" && F.summary(F.Query(), 1, 1) == "1 to-do item in 1 page of this folder"
  @test F.summary(F.query(["plumber sam"]), 2, 1) == "2 lines with “plumber sam” in 1 page of this folder"
  @test F.summary(F.query(["headings"]), 0, 0) == "No headings in this folder"
  @test F.summary(F.query(["in: jobs"]), 2, 1) == "2 to-do items in 1 page of the folder jobs" && F.summary(F.query(["done", "in: jobs"]), 0, 0) == "No items that are done in the folder jobs"
end
