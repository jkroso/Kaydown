# Tests for sheet.jl: a sheet that works a row out backwards, from the answer
# that a row under it must come to. Run them with
# `julia -O0 --project=. test/sheet_test.jl`.

@use Test: @test, @testset
@use "../sheet" => S

texts(rows) = [r.text for r in S.tally(rows)]

@testset "a sheet from the top down" begin
  @test texts([("Wall length", "12m"), ("Wall height", "2.4m"), ("Area", "wall length * wall height")]) == ["12m", "2.4m", "28.8m²"]
  @test S.tally([("A", "nope")])[1].failed
  # A row can define a function, and a row under it can use the function
  @test texts([("", "double(x) = 2x"), ("B", "double(4)")])[2] == "8"
end

@testset "a row with a ? and what comes after it" begin
  @test S.unknown("? 12m") == "12m" && S.unknown(" ?") == "" && S.unknown("12m") === nothing
  # With no answer under it, the row is the value after the ?
  @test texts([("Wall length", "? 12m"), ("Twice", "wall length * 2")]) == ["12m", "24m"]
  @test texts([("N", "?")]) == ["1"]
end

@testset "a row that says what it must come to" begin
  ids = Set([:litres, :area])
  @test S.goal(Meta.parse("ceil(litres / 4) = 3"), ids) !== nothing && S.goal(Meta.parse("area * 2 = 30"), ids) !== nothing
  @test S.goal(Meta.parse("double(x) = 2x"), ids) === nothing && S.goal(Meta.parse("area * 2"), ids) === nothing
  @test S.goal(Meta.parse("area == 3"), ids) === nothing
end

@testset "the sheet works a row out backwards" begin
  rows = [("Wall length", "? 12m"), ("Wall height", "2.4m"), ("Area", "wall length * wall height"),
          ("Litres", "area * 2 / (16m^2 / litre) = 6litre"), ("Tins", "ceil(litres / 4litre)")]
  out = S.tally(rows)
  @test [r.text for r in out] == ["20m", "2.4m", "48m²", "6litre", "2"]
  @test out[1].solved && !out[1].failed && !any(r -> r.solved, out[2:end])
  # The value of each name is the one that the answer gives
  @test string(Dict(S.name_values(rows))["wall_length"]) == "20m"
  # A plain number, and a sum that isn't a straight line
  @test texts([("Side", "?"), ("Area", "side^2 = 49")]) == ["7", "49"]
  @test texts([("Rate", "? 50"), ("Hours", "38"), ("Pay", "rate * hours + 100 = 3140")])[1] == "80"
  # A sum that goes up in steps: any wall that takes 3 tins is an answer
  out = S.tally([("Wall", "? 10m"), ("Litres", "wall * 2.4m * 2 / (16m^2 / litre)"), ("Tins", "ceil(litres / 4litre) = 3")])
  @test out[1].solved && out[3].text == "3"
  # Nothing gives the answer
  out = S.tally([("X", "?"), ("Y", "x * 0 = 5")])
  @test out[1].failed && !out[1].solved
  # The answer has another kind of unit than the sum
  @test S.tally([("X", "? 1m"), ("Y", "x * 2 = 5litre")])[1].failed
  # A second row with a ?, after the first one's answer
  @test texts([("A", "?"), ("B", "a * 2 = 10"), ("C", "? 1m"), ("D", "c * b = 30m")]) == ["5", "10", "3m", "30m"]
  # The sheet has names from outside it
  @test [r.text for r in S.tally([("Tile", "? 0.1m^2"), ("Tiles", "floor / tile = 100")]; given=[("Floor", "50m^2")])] == ["0.5m²", "100"]
end

@testset "a row over a range" begin
  @test S.ends("8m to 20m", String[]) == ("8m", "20m") && S.ends("8m", String[]) === nothing
  # The word in a name, or in a string, makes no range
  @test S.ends("door to wall * 2", ["Door to wall"]) === nothing && S.ends("\"a to b\"", String[]) === nothing
  @test S.steps(12) == 24 && S.steps(1) == 20 && S.steps(0.37) == 37 && S.steps(0) == 1
  rows = [("Wall height", "2.4m"), ("Wall length", "8m to 20m"), ("Area", "wall length * wall height"), ("Coats", "2"),
          ("Litres", "area * coats / (16m^2 / litre)"), ("", "wall length * 2")]
  @test S.ranged(rows) == 2 && S.ranged(rows[1:1]) == 0
  # Each row shows what it comes to at the two ends
  @test texts(rows) == ["2.4m", "8m to 20m", "19.2m² to 48m²", "2", "2.4litre to 6litre", "16m to 40m"]
  # One place of the range
  @test [r.text for r in S.tally(rows; at=0.5)] == ["2.4m", "14m", "33.6m²", "2", "4.2litre", "28m"]
  c = S.cases(rows)
  @test c.table[1] == ["Wall length", "Area", "Litres"] && length(c.table) == 26 && c.places[1] == 0 && c.places[end] == 1
  @test c.table[2] == ["8m", "19.2m²", "2.4litre"] && c.table[3][1] == "8.5m" && c.table[end] == ["20m", "48m²", "6litre"]
  @test S.cases(rows[1:1]) === nothing && S.cases([("A", "1 to 5")]) === nothing
  # A plain number, and names from outside the sheet
  c = S.cases([("Tiles", "floor / (side * side)")]; given=[("Floor", "36m^2"), ("Side", "0.2m to 0.6m")])
  @test c.table[1] == ["Side", "Tiles"] && c.table[2] == ["0.2m", "900"] && c.table[end] == ["0.6m", "100"]
  # A sheet can have a row over a range and a row that's worked out backwards
  @test texts([("Long", "2 to 4"), ("Wide", "?"), ("Area", "long * wide = 12")]) == ["2 to 4", "6 to 3", "12"]
end
