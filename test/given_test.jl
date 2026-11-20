# Tests for names that one part of a page has from another, in main.jl and
# sheet.jl: a row of a sheet that uses a measure of a takeoff, a task of a
# time log or a row of another sheet, and a sum in a line of text that uses a
# row of a sheet. Run them with `julia -O0 --project=. test/given_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "../sheet" tally known name_values
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

@testset "a sheet with names from outside it" begin
  given = [("Kitchen floor", "18m^2"), ("Coats", "3")]
  rows = [("Tile", "0.36m^2"), ("Tiles", "ceil(kitchen floor / tile)"), ("Coats", "2"), ("Paint", "coats * 4")]
  @test [r.text for r in tally(rows; given)] == ["0.36m²", "50", "2", "8"]   # a row with the same name takes the name
  @test [r.failed for r in tally(rows)] == [false, true, false, false]
  @test known(rows, 2, given) == ["Kitchen floor", "Coats", "Tile"] && known(rows, 2) == ["Tile"]
  values = Dict(name_values([given; rows]))
  @test values["tiles"] == 50 && values["coats"] == 2 && string(values["kitchen_floor"]) == "18m²"
end

const dir = mktempdir()
const page = joinpath(dir, "kitchen.md")
write(page, """
# Kitchen

```takeoff
scale: 1:100

count | Power point
  10,10 20,20 30,30
area | Kitchen floor
  0,0 283.465,0 283.465,141.7325 0,141.7325
```

```timelog
2026-11-17 08:00-12:00 | Tiling
2026-11-18 08:00-10:30 | Tiling
```

```sheet
Tile = 0.5m^2
Tiles = floor(kitchen floor / tile)
Points = power point
```

The floor takes !`tiles` tiles. Each costs !`price = 12`, so they cost !`tiles * price`.

```sheet
Rate = 80
Labour = tiling / hr * rate
Both = labour + tiles * 12
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1500px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
sheet(n) = K.item(e, findall(==("```sheet"), e.buf.lines)[n] + 1).content
results(n) = [r.text for r in sheet(n).results]
said(code) = K.made(e, code, 1)[1]
row!(old, new) = (i = findfirst(==(old), e.buf.lines); K.edit!(e.buf, (i, 0), K.line_end(e.buf, i), new); frames())

@testset "what each kind of block gives" begin
  # 283.465 points of a page at 1:100 are 10 metres
  @test K.block_names(K.TAKEOFF, ["scale: 1:100", "", "count | Power point", "  10,10 20,20 30,30", "length | ", "  0,0 10,0"]) == [("Power point", "3.0")]
  @test K.block_names(K.TIMELOG, ["2026-11-17 08:00-12:00 | Tiling", "2026-11-18 08:00-10:30 | tiling"]) == [("Tiling", "6.5hr")]
  @test K.block_names(K.SHEET, ["A = 1", "2 + 2", " = 3"]) == [("A", "1")]
  @test K.block_names("board", ["x"]) == []
end

@testset "a row uses a measure of the takeoff over it" begin
  @test [name for (name, _) in K.page_given(e, findfirst(==("```sheet"), e.buf.lines))] == ["Power point", "Kitchen floor", "Tiling"]
  @test results(1) == ["0.5m²", "100", "3"]
  # A name from outside shows as a chip, as the name of a row does
  @test any(seg -> seg.face.chip && seg.text == "kitchen floor", sheet(1).exprs[2].lines[1].segs)
end

@testset "a sheet uses a task of the log, and a row of the sheet over it" begin
  @test results(2) == ["80", "520", "1,720"]
  # The first sheet is over the log's names for the second one, and not the other way
  @test length(K.page_given(e, findall(==("```sheet"), e.buf.lines)[2])) == 6
end

@testset "a sum in a line of text uses a row of a sheet" begin
  @test said("tiles") == "100" && said("tiles * price") == "1,200"
  # The sheet changes, and the sums and the next sheet follow
  row!("Tile = 0.5m^2", "Tile = 0.25m^2")
  @test results(1)[2] == "200" && said("tiles") == "200" && said("tiles * price") == "2,400" && results(2)[3] == "2,920"
  # The takeoff changes, and the sheet follows
  row!("  10,10 20,20 30,30", "  10,10 20,20 30,30 40,40")
  @test results(1)[3] == "4"
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test results(1) == ["0.5m²", "100", "3"] && said("tiles") == "100"
end

@testset "a name of the page's code stays as it is" begin
  m = K.workspace(e)
  @test Base.invokelatest(getfield, m, :price) == 12
  i = findfirst(==("Rate = 80"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, 0), "Sum = 5\nPrice = 99\n"); frames()
  @test Base.invokelatest(getfield, m, :sum) === sum && Base.invokelatest(getfield, m, :price) == 12
  @test said("tiles * price") == "1,200"
end

close(w)
