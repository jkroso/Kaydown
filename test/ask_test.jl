# Tests for ask.jl. Run them with `julia -O0 --project=. test/ask_test.jl`.

@use Test: @test, @testset
@use "../ask" => A

const BLOCK = ["Which database should the app use?", "It holds the orders.", "",
               "( ) SQLite. It's one file.", "(x) Postgres", "- [ ] Keep a copy in the cloud", "[x] Keep a copy on this Mac",
               "> We run Postgres already.", "> Ask Sam."]

@testset "reading and writing" begin
  q = A.question(BLOCK)
  @test q.words == ["Which database should the app use?", "It holds the orders."] && A.asked(q) == "Which database should the app use? It holds the orders."
  @test [o.text for o in q.options] == ["SQLite. It's one file.", "Postgres", "Keep a copy in the cloud", "Keep a copy on this Mac"]
  @test [o.chosen for o in q.options] == [false, true, false, true] && [o.many for o in q.options] == [false, false, true, true]
  @test q.note == "We run Postgres already. Ask Sam." && A.answered(q)
  @test A.written(q) == ["Which database should the app use?", "It holds the orders.", "( ) SQLite. It's one file.", "(x) Postgres",
                         "[ ] Keep a copy in the cloud", "[x] Keep a copy on this Mac", "> We run Postgres already. Ask Sam."]
  @test A.written(A.question(A.written(q))) == A.written(q)
  # Words in brackets aren't an answer
  odd = A.question(["(a) Which one?", "[See the plan](plan.md)", "() Yes", "(X) No"])
  @test odd.words == ["(a) Which one?", "[See the plan](plan.md)"] && [o.chosen for o in odd.options] == [false, true]
  open = A.question(["What should the button say?"])
  @test isempty(open.options) && open.note == "" && !A.answered(open) && A.written(open) == ["What should the button say?"]
  @test isempty(A.written(A.question(String[])))
end

@testset "choosing" begin
  q = A.question(BLOCK)
  A.choose!(q, 1)
  @test [o.chosen for o in q.options] == [true, false, false, true]   # one of the first two, and the boxes stay as they were
  A.choose!(q, 1)
  @test [o.chosen for o in q.options] == [false, false, false, true]
  A.choose!(q, 3); A.choose!(q, 4)
  @test [o.chosen for o in q.options] == [false, false, true, false]
  q.note = ""
  A.choose!(q, 3)
  @test !A.answered(q) && A.written(q)[end] == "[ ] Keep a copy on this Mac"
end
