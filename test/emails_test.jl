# Tests for emails.jl. Run them with `julia -O0 --project=. test/emails_test.jl`.

@use Test: @test, @testset
@use "../emails" => E

@testset "reading and writing" begin
  w = E.wanted(["with: Sam Lee, sam@example.com", "about: Roof  quote", "newest: first"])
  @test w.with == ["Sam Lee", "sam@example.com"] && w.about == ["Roof", "quote"] && w.other == ["newest: first"]
  @test E.written(w) == ["with: Sam Lee, sam@example.com", "about: Roof quote", "newest: first"]
  # A name or an address by itself is who the emails are with
  @test E.wanted(["sam@example.com"]).with == ["sam@example.com"] && E.written(E.wanted(["Sam Lee"])) == ["with: Sam Lee"]
  @test isempty(E.wanted(String[]).with) && isempty(E.written(E.Wanted()))
end

@testset "the emails that a block asks for" begin
  w = E.wanted(["with: Sam Lee, kim@example.com", "about: roof"])
  @test E.with(w, "Sam Lee Jake Example") && E.with(w, "LEE, SAM") && !E.with(w, "Sam Jones")
  @test E.with(w, "Kim <kim@example.com>") && !E.with(w, "Kim Park")
  @test E.about(w, "Re: The ROOF quote") && !E.about(w, "The quote") && E.about(E.Wanted(), "Anything")
  @test E.addressed(w) && E.address(w) == "kim@example.com" && !E.addressed(E.wanted(["Sam"])) && E.address(E.wanted(["Sam"])) == ""
  @test !E.with(E.Wanted(), "Sam Lee")
end

@testset "what the list is of, in words" begin
  @test E.summary(E.wanted(["Sam Lee"]), 3) == "3 emails with Sam Lee" && E.summary(E.wanted(["Sam Lee"]), 1) == "1 email with Sam Lee"
  @test E.summary(E.wanted(["with: Sam, Kim", "about: roof"]), 0) == "No emails with Sam and Kim about “roof”"
  @test E.summary(E.wanted(["with: Sam, Kim, Lou"]), 2) == "2 emails with Sam, Kim and Lou"
end
