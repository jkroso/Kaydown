# Tests for a sheet with a row over a range, in main.jl: a chart draws what
# the sheet comes to at each value of that row, and the sheet shows the value
# that the mouse is on in the chart. Run them with
# `julia -O0 --project=. test/range_view_test.jl`. They move the mouse in a
# window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they
# save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "paint.md")
write(page, """
# Paint

```sheet
Wall height = 2.4m
Wall length = 8m to 20m
Area = wall length * wall height
Litres = area * 2 / (16m^2 / litre)
```

```chart
show: Litres
```

| Wall | Length |
|---|---|
| Garage | 14m |
| Shed | 9m |
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const chart = e.nodes[(:block, K.CHART, page, 1)]
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
sheet() = K.item(e, findfirst(==("```sheet"), e.buf.lines) + 1).content
results() = [r.text for r in sheet().results]
spot(m) = (chart.box[1] + m.at[1] + m.at[3] / 2, chart.box[2] + m.at[2] + m.at[4] / 2)
bar(label) = spot(only(m for m in chart.marks if m.kind == :bar && m.label == label))
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

@testset "the sheet shows both ends of its range" begin
  @test results() == ["2.4m", "8m to 20m", "19.2m² to 48m²", "2.4litre to 6litre"]
  @test !any(r -> r.solved, sheet().results)
end

@testset "the chart draws the sheet at each value of the row" begin
  d = K.shown!(chart)
  @test isempty(d.problem) && length(d.labels) == 25 && d.labels[1] == "8m" && d.labels[2] == "8.5m" && d.labels[end] == "20m"
  @test [s.name for s in d.series] == ["Litres"] && d.series[1].values[1] == 2.4 && d.series[1].values[end] == 6.0 && d.after == " litre"
  @test count(m -> m.kind == :bar, chart.marks) == 25
  # Without `show`, the chart draws each row that changes
  K.write_block!(chart, K.CHART, String[]); frames()
  @test [s.name for s in K.shown!(chart).series] == ["Area", "Litres"]
  K.undo!(e.buf); frames()
end

@testset "the mouse on a value of the chart" begin
  at(bar(13))   # the thirteenth value is 14m
  @test K.pointed(chart) == "14m" && K.pointed(e) == "14m"
  @test results() == ["2.4m", "14m", "33.6m²", "4.2litre"]
  @test sheet().results[2].solved && !sheet().results[3].solved   # the row over the range shows that it's at one value
  shot("range.png")
  # A row of a table with that value as its name is marked too
  @test K.marked(e, "14m")
  at(bar(1))
  @test results() == ["2.4m", "8m", "19.2m²", "2.4litre"]
  at((990, 10))
  @test results() == ["2.4m", "8m to 20m", "19.2m² to 48m²", "2.4litre to 6litre"]
end

@testset "the range changes, and the chart with it" begin
  i = findfirst(==("Wall length = 8m to 20m"), e.buf.lines)
  K.edit!(e.buf, (i, 0), K.line_end(e.buf, i), "Wall length = 10m to 12m"); frames()
  d = K.shown!(chart)
  @test d.labels[1] == "10m" && d.labels[2] == "10.1m" && d.labels[end] == "12m" && length(d.labels) == 21
  # A sheet with no range is a table of its rows again
  K.edit!(e.buf, (i, 0), K.line_end(e.buf, i), "Wall length = 10m"); frames()
  K.write_block!(chart, K.CHART, String[]); frames()
  @test K.shown!(chart).labels == ["Wall height", "Wall length", "Area", "Litres"]
end

close(w)
