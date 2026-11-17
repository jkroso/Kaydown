# Tests for sketch.jl. Run them with `julia -O0 --project=. test/sketch_test.jl`.

@use Test: @test, @testset
@use "../sketch" => S

const BLOCK = ["pen 12,30 14,32.5 18,40", "line 10,10 80,60", "arrow red 10,10 80,60", "box 100,50 200,120",
               "oval blue 300,50 400,150", "text green 120,80 The sink  goes here", "star 1,1 2,2", "box 1,1"]

@testset "reading and writing" begin
  s = S.sketch(BLOCK)
  @test [x.kind for x in s.shapes] == [:pen, :line, :arrow, :box, :oval, :text]
  @test [x.colour for x in s.shapes] == [:ink, :ink, :red, :ink, :blue, :green]
  @test s.shapes[1].points == [(12.0, 30.0), (14.0, 32.5), (18.0, 40.0)] && s.shapes[6].points == [(120.0, 80.0)]
  @test s.shapes[6].text == "The sink goes here" && s.other == ["star 1,1 2,2", "box 1,1"]
  @test S.written(s) == ["pen 12,30 14,32.5 18,40", "line 10,10 80,60", "arrow red 10,10 80,60", "box 100,50 200,120",
                         "oval blue 300,50 400,150", "text green 120,80 The sink goes here", "star 1,1 2,2", "box 1,1"]
  @test S.written(S.sketch(S.written(s))) == S.written(s)
  # The words of a text can start with a number, and a colour's name can be one of them
  t = S.sketch(["text 5,20 3,4 is a place", "text 5,40 red is a colour"])
  @test t.shapes[1].text == "3,4 is a place" && t.shapes[2].text == "red is a colour" && t.shapes[2].colour == :ink
  @test isempty(S.written(S.Sketch())) && S.figure(12.04) == "12" && S.figure(12.26) == "12.3"
end

@testset "how big it is" begin
  s = S.sketch(BLOCK)
  @test S.bounds(s.shapes[4]) == (100.0, 50.0, 200.0, 120.0) && S.bounds(s.shapes[1]) == (12.0, 30.0, 18.0, 40.0)
  l, t, r, b = S.bounds(s.shapes[6])
  @test l == 120 && t < 80 < b && r > 200
  @test S.tall(S.Sketch()) == S.LEAST && S.tall(s) == S.LEAST
  push!(s.shapes, S.Shape(:line, :ink, [(0.0, 0.0), (10.0, 400.0)]))
  @test S.tall(s) == 400 + S.ROOM
end

@testset "what a click is on" begin
  s = S.sketch(BLOCK)
  @test S.hit(s, (45.0, 36.0)) == 3          # on the arrow, which is over the line
  @test S.hit(s, (150.0, 51.0)) == 4 && S.hit(s, (150.0, 75.0)) == 6   # the edge of the box, and the words in it
  @test S.hit(s, (150.0, 108.0)) === nothing # in the box, under the words
  @test S.hit(s, (300.0, 100.0)) == 5 && S.hit(s, (350.0, 100.0)) === nothing   # the edge of the oval, and its middle
  @test S.hit(s, (15.0, 34.0)) == 1 && S.hit(s, (600.0, 200.0)) === nothing
  S.move!(s.shapes[4], 10, -5)
  @test s.shapes[4].points == [(110.0, 45.0), (210.0, 115.0)]
  @test S.slight(S.Shape(:box, :ink, [(5.0, 5.0), (6.0, 6.0)])) && !S.slight(s.shapes[4]) && !S.slight(s.shapes[1])
end

@testset "a line drawn by hand" begin
  straight = [(Float64(x), 10.0 + 0.2 * (x % 2)) for x in 0:50]
  @test S.simplify(straight) == [(0.0, 10.0), (50.0, 10.0)]
  bent = [[(Float64(x), 0.0) for x in 0:20]; [(20.0, Float64(y)) for y in 1:20]]
  @test S.simplify(bent) == [(0.0, 0.0), (20.0, 0.0), (20.0, 20.0)]
  @test S.simplify([(1.0, 1.0)]) == [(1.0, 1.0)]
  a, b = S.barbs((0.0, 0.0), (100.0, 0.0))
  @test a[1] ≈ 89 && b[1] ≈ 89 && a[2] ≈ -b[2] && abs(a[2]) > 3
end

@testset "a sketch as a picture" begin
  s = S.sketch([BLOCK; "text 5,200 Nuts & <bolts>"])
  picture = S.svg(s, colours=(ink="#222", red="#c00", blue="#00c", green="#0a0", orange="#f80"))
  @test startswith(picture, "<svg") && endswith(picture, "</svg>") && occursin("viewBox=\"0 0 720 253\"", picture)
  @test occursin("<rect x=\"100\" y=\"50\" width=\"100\" height=\"70\"", picture) && occursin("<ellipse cx=\"350\" cy=\"100\" rx=\"50\" ry=\"50\"", picture)
  @test occursin("stroke=\"#c00\"", picture) && occursin("Nuts &amp; &lt;bolts&gt;", picture) && count("<polyline", picture) == 4
end
