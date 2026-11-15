# Tests for takeoff.jl. Run them with `julia --project=. takeoff_test.jl`.

@use Test: @test, @testset
@use "./takeoff" => T

const BLOCK = ["plan: ground-floor.pdf", "page: 2", "scale: 1:100", "scale 2: 1:50", "customer: J Smith", "colour: red", "",
               "count | Double power point | item 412",
               "  120,340 410,380 505,120",
               "  2: 10,10",
               "length | 20mm conduit | item 77 | +10%",
               "  0,0 720,0 720,720",
               "  2: 0,0 72,0",
               "area | Floor tiles",
               "  0,0 720,0 720,720 0,720"]

@testset "reading" begin
  t = T.takeoff(BLOCK)
  @test t.plan == "ground-floor.pdf" && t.page == 2 && t.customer == "J Smith" && t.made == ""
  @test t.scales == Dict(0 => 100.0, 2 => 50.0)
  @test t.other == ["colour" => "red"]
  @test [m.kind for m in t.measures] == [:count, :length, :area]
  @test [m.name for m in t.measures] == ["Double power point", "20mm conduit", "Floor tiles"]
  @test [m.item for m in t.measures] == ["item 412", "item 77", ""]
  @test [m.extra for m in t.measures] == [0.0, 0.1, 0.0]
  @test [s.page for s in t.measures[1].shapes] == [1, 2]
  @test t.measures[2].shapes[1].points == [(0.0, 0.0), (720.0, 0.0), (720.0, 720.0)]
  # An empty block, and lines that say nothing, give an empty takeoff
  @test isempty(T.takeoff(String[]).measures)
  @test isempty(T.takeoff(["", "what", "  1,2 3,4"]).measures)
  # Waste with no item
  @test T.takeoff(["area | Tiles | | +5%"]).measures[1].extra == 0.05
  @test T.takeoff(["area | Tiles | +5%"]).measures[1].item == ""
  @test T.scale("1:100") == 100 && T.scale("1 : 50") == 50 && T.scale("20") == 20 && T.scale("1/200") == 200
  @test T.scale("big") === nothing && T.scale("1:0") === nothing
end

@testset "writing" begin
  t = T.takeoff(BLOCK)
  @test T.written(t) == BLOCK
  # What's written reads back as the same takeoff
  @test T.written(T.takeoff(T.written(t))) == T.written(t)
  @test T.written(T.Takeoff()) == String[]
  # The marks of a count share lines, ten to a line, a page at a time
  m = T.Measure(:count, "Lights")
  foreach(i -> T.mark!(m, 1, (Float64(i), 2.5)), 1:12)
  T.mark!(m, 3, (7.0, 8.0))
  T.mark!(m, 1, (13.0, 2.5))
  rows = T.drawn(m)
  @test length(rows) == 3
  @test rows[1] == "  " * join(("$i,2.5" for i in 1:10), " ")
  @test rows[2] == "  11,2.5 12,2.5 13,2.5"
  @test rows[3] == "  3: 7,8"
  @test T.number(12.04) == "12" && T.number(12.06) == "12.1" && T.number(-3) == "-3"
end

@testset "what a measure comes to" begin
  t = T.takeoff(BLOCK)
  count, len, area = t.measures
  @test T.amount(t, count) == 4
  # 720 points are 10 inches of paper. At 1:100 that's 25.4 m, and at 1:50 an inch is 1.27 m.
  @test T.amount(t, len) ≈ (2 * 25.4 + 1.27) * 1.1
  @test T.amount(t, area) ≈ 25.4^2
  @test T.shown(:count, 4.0) == "4" && T.shown(:length, 12.346) == "12.35 m" && T.shown(:area, 40.0) == "40 m²"
  # A page with no scale has no lengths yet, and its counts are still counts
  bare = T.takeoff(["length | Pipe", "  0,0 10,0", "count | Taps", "  1,1"])
  @test T.amount(bare, bare.measures[1]) === nothing
  @test T.amount(bare, bare.measures[2]) == 1
  # A scale from a length that's known: 720 points that are 12.7 m make 1:50
  @test T.scale((0.0, 0.0), (720.0, 0.0), 12.7) ≈ 50
  @test T.scale((0.0, 0.0), (0.0, 0.0), 12.7) === nothing
  @test T.inside([(0.0, 0.0), (4.0, 0.0), (4.0, 3.0)]) == 6
  @test T.inside([(0.0, 0.0), (4.0, 3.0), (4.0, 0.0)]) == 6   # the other way round
  @test T.inside([(0.0, 0.0), (4.0, 0.0)]) == 0
end

@testset "the unit of a measure" begin
  # It's written after the kind, and a measure with none is in its kind's own unit
  t = T.takeoff(["scale: 1:100", "", "length in mm | Cable |  | +10%", "  0,0 720,0", "area in ft² | Tiles", "count | Taps"])
  len, area, taps = t.measures
  @test (len.unit, area.unit, taps.unit) == ("mm", "ft²", "")
  @test (T.unit(len), T.unit(area), T.unit(taps)) == ("mm", "ft²", "Piece")
  @test len.extra == 0.1 && len.name == "Cable"
  @test T.written(t) == ["scale: 1:100", "", "length in mm | Cable |  | +10%", "  0,0 720,0", "area in ft² | Tiles", "count | Taps"]
  # Its kind's own unit is written as none, and a unit of another kind, or none that Centient knows, is left out
  @test T.takeoff(["length in m | Cable"]).measures[1].unit == ""
  @test T.takeoff(["length in ft² | Cable"]).measures[1].unit == ""
  @test T.takeoff(["length in furlong | Cable"]).measures[1].unit == ""
  @test T.measure("width in mm | Cable") === nothing
  # The amount shows in its unit. A foot and an inch are marks. Less than one shows three figures.
  @test T.shown(len, 25.4) == "25400 mm"
  @test T.shown(:length, 12.54, "km") == "0.0125 km" && T.shown(:length, 3.048, "ft") == "10'" && T.shown(:length, 0.0254, "inch") == "1\""
  @test T.shown(:area, 10_000.0, "hectare") == "1 hectare" && T.shown(:count, 4.0, "Piece") == "4"
  @test T.in_unit(1.0, "mm") ≈ 1000
  @test T.in_unit(1.0, "ft²") ≈ 10.7639 atol=1e-4
  @test T.unit_kind("yard") == :length && T.unit_kind("acre") == :area && T.unit_kind("Piece") == :count && T.unit_kind("hr") === nothing
end

@testset "the kind of measure for an item's unit" begin
  @test all(u -> T.kind_for(u) == :length, ("m", "M", "metre", "Metres", "per metre", "lm", "LM", "lin. m", "lineal metre", "/m", "mm"))
  @test all(u -> T.kind_for(u) == :area, ("m²", "m2", "sqm", "SQM", "sq. m", "square metres", "per m²", "square meter"))
  @test all(u -> T.kind_for(u) == :count, ("Piece", "each", "", "hr", "box", "kg", "L", "pack of 10"))
  @test T.kind_for(nothing) == :count
  # Centient's own names for units
  @test all(u -> T.kind_for(u) == :length, ("ft", "inch", "yard", "mile", "km"))
  @test all(u -> T.kind_for(u) == :area, ("ft²", "acre", "hectare", "km²"))
end

@testset "what's under the mouse" begin
  t = T.takeoff(BLOCK)
  @test T.corner(t, 1, (121.0, 341.0), 5) == (1, 1, 1)
  @test T.corner(t, 1, (721.0, 1.0), 5) in ((2, 1, 2), (3, 1, 2))
  @test T.corner(t, 1, (300.0, 300.0), 5) === nothing
  @test T.corner(t, 2, (10.0, 10.0), 5) == (1, 2, 1)
  # A line is nearer than the outline it's in
  @test T.shape(t, 1, (400.0, 1.0), 5) in ((2, 1), (3, 1))
  @test T.shape(t, 1, (1.0, 400.0), 5) == (3, 1)     # the edge that closes the outline
  @test T.shape(t, 1, (300.0, 500.0), 5) == (3, 1)   # inside it
  @test T.shape(t, 1, (900.0, 900.0), 5) === nothing
  @test T.shape(t, 1, (410.0, 381.0), 5) == (1, 1)
  @test T.shape(t, 2, (36.0, 2.0), 5) == (2, 2)
end

@testset "changing it" begin
  t = T.takeoff(BLOCK)
  T.remove!(t.measures[1], 1, 2)
  @test t.measures[1].shapes[1].points == [(120.0, 340.0), (505.0, 120.0)]
  T.remove!(t.measures[1], 2, 1)
  @test length(t.measures[1].shapes) == 1   # the page's last mark took its shape with it
  T.remove!(t.measures[2], 2, 1)
  @test length(t.measures[2].shapes) == 1   # a line needs two corners
  T.remove!(t.measures[3], 1, 1)
  @test length(t.measures[3].shapes) == 1 && length(t.measures[3].shapes[1].points) == 3
  T.remove!(t.measures[3], 1, 1)
  @test isempty(t.measures[3].shapes)       # an outline needs three
end
