# Tests for the `takeoff` block of main.jl: the plan, the tools, the list of
# measures and the work with Centient. Run them with
# `julia --project=. takeoff_view_test.jl`. They click and type in a window
# that isn't on the screen. Centient is centient_fake.jl, so they need no
# Centient and change no books.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups onpinch
@use GeometryBasics: Vec2

# Centient's server is looked for in this folder, and the one there is the fake
const dir = mktempdir()
cp(joinpath(@__DIR__, "centient_fake.jl"), joinpath(dir, "mcp_server.jl"))
ENV["CENTIENT_SIDECAR"] = dir

@use "./main" => K
const P, px = K.Plans, K.px

# The example plan is of a house 16 m by 10 m, at 1:100. `house` gives the point of the page that's
# so many metres from the bottom left corner of the house.
const M = 72 / 25.4 * 10
house(x, y) = (150 + x * M, 841.89 - (330 + y * M))
written(p) = P.number(p[1]) * "," * P.number(p[2])

cp(joinpath(@__DIR__, "pages", "plan.pdf"), joinpath(dir, "plan.pdf"))
const page = joinpath(dir, "job.md")
write(page, """
# A job

```takeoff
plan: plan.pdf
page: 1
scale: 1:100

count | Power points | acme 77
  $(written(house(0.5, 1))) $(written(house(0.5, 8.6)))
length | Cable | +10%
  $(written(house(0.4, 0.4))) $(written(house(5.8, 0.4)))
area | Floor
  $(written(house(6, 0))) $(written(house(10, 0))) $(written(house(10, 5))) $(written(house(6, 5)))
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1300px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const v = only(node for node in values(e.nodes) if node isa K.TakeoffView)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Click a place on the plan. A wait before it keeps it from being the second click of two."
plan_click(x, y) = (sleep(0.4); click(K.window_point(v, house(x, y))))
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
command(k) = (w.keys |= Keys.cmd; key(k); w.keys ⊻= Keys.cmd)
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"The middle of a part of the takeoff, by the key that it's kept under"
part(key) = (r = rect(v.parts[key]); (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2)))
button(key) = click(part((:button, key)))
"Draw frames until `done()`, as the window would while Centient works"
settle(done, most=30) = (t = time(); while !done() && time() - t < most; frames(1); sleep(0.02); end; done())
amounts() = [P.amount(v.data, m) for m in v.data.measures]
block() = (s = K.takeoff_lines(e.buf, 1); e.buf.lines[s[1]+1:s[2]-1])

@testset "the block shows the plan and what's measured" begin
  @test K.plan_size(v) == (1190.55, 841.89) && K.plan_pages(v) == 1
  @test v.zoom > 0 && v.fitted == (joinpath(dir, "plan.pdf"), 1)
  @test amounts()[1] == 2
  @test amounts()[2] ≈ 5.4 * 1.1 atol=0.01
  @test amounts()[3] ≈ 20 atol=0.01
  @test K.outline(e.buf)[2].title == "Takeoff"
  @test occursin("<td>Floor</td><td>20 m²</td>", K.page_html(e))
  # Centient tells of the item that the count names
  @test settle(() -> K.known(v, "acme 77") !== nothing)
  @test K.known(v, "acme 77")["price"] == 12.5
end

@testset "counting and measuring" begin
  button((:tool, :count))
  @test v.tool == :count && v.current == 1
  plan_click(5.6, 2.2)
  @test amounts()[1] == 3 && block()[5] == "count | Power points | acme 77"
  @test occursin(written(house(5.6, 2.2)), block()[6])
  @test e.buf.caret[1] < v.first   # the caret stays out of the block, so the block doesn't show as lines
  @test K.dirty(e.buf)

  button((:tool, :length))
  @test v.current == 2
  plan_click(6.2, 9.6); plan_click(10.3, 9.6); plan_click(10.3, 5.8)
  @test length(v.draft) == 3
  key(Keys.backspace)   # takes the last corner back
  @test length(v.draft) == 2
  plan_click(10.3, 5.8)
  key(Keys.enter)
  @test isempty(v.draft) && length(v.data.measures[2].shapes) == 2
  @test amounts()[2] ≈ (5.4 + 7.9) * 1.1 atol=0.02
  # Two clicks in one place end a line, and one corner is no line
  plan_click(1, 9); plan_click(5, 9); click(K.window_point(v, house(5, 9)))
  @test isempty(v.draft) && length(v.data.measures[2].shapes) == 3
  plan_click(1, 5); key(Keys.enter)
  @test isempty(v.draft) && length(v.data.measures[2].shapes) == 3
  # Esc drops what's half drawn, then puts the arrow back
  plan_click(1, 5); plan_click(2, 5); key(Keys.escape)
  @test isempty(v.draft) && v.tool == :length
  key(Keys.escape)
  @test v.tool == :select

  typed("a")   # the letter of the area tool
  @test v.tool == :area && v.current == 3
  for p in ((10.6, 6.3), (12.9, 6.3), (12.9, 9.7), (10.6, 9.7)); plan_click(p...); end
  plan_click(10.6, 6.3)   # on the first corner
  @test isempty(v.draft) && length(v.data.measures[3].shapes) == 2
  @test P.amount(v.data, :area, v.data.measures[3].shapes[2]) ≈ 2.3 * 3.4 atol=0.02
end

@testset "selecting, moving and undoing" begin
  typed("v")
  # Over something that a click selects, the mouse is a hand. Over the paper, it's an arrow.
  area = v.parts[:area]
  pointer(x, y) = (at(K.window_point(v, house(x, y))); K.cursor(area))
  @test pointer(5.6, 2.2) == :hand   # a mark
  @test pointer(3, 0.4) == :hand     # the cable
  @test pointer(8, 2) == :hand       # inside the floor
  @test pointer(14, 3) == :arrow     # the paper
  plan_click(5.6, 2.2)
  @test v.picked == (1, 1, 3)
  key(Keys.delete)
  @test amounts()[1] == 2 && v.picked === nothing
  plan_click(8, 0)   # on the edge of the floor
  @test v.picked == (3, 1)
  # A drag moves a corner, and it's written when the button comes up
  before = block()
  press(K.window_point(v, house(12.9, 9.7))); at(K.window_point(v, house(12.5, 9.2))); at(K.window_point(v, house(12, 9)))
  @test block() == before
  release()
  @test block() != before
  @test P.amount(v.data, :area, v.data.measures[3].shapes[2]) < 7.5
  command(Keys.z)
  @test block() == before
  @test P.amount(v.data, :area, v.data.measures[3].shapes[2]) ≈ 7.82 atol=0.02
  # A plan that shows whole stays where it is when it's dragged, and gets no smaller
  was, small = v.at, v.zoom
  press(K.window_point(v, house(14, 3))); at(K.window_point(v, house(14, 3)) .+ (40, 25)); release()
  @test v.at == was && block() == before
  button(:smaller)
  @test v.zoom == small && v.at == was
  # ⌘ with the wheel makes it bigger round the mouse
  under = K.window_point(v, house(8, 5))
  at(under); w.keys |= Keys.cmd; foreach(_ -> onscroll(w, Vec2{px}(0px, 3px)), 1:3); w.keys ⊻= Keys.cmd; frames()
  @test v.zoom > 2small
  @test all(isapprox.(K.window_point(v, house(8, 5)), under, atol=0.01))
  # Now a drag moves it, as far as the edge of the page and no further
  was = v.at
  press(K.window_point(v, house(8, 5))); at(K.window_point(v, house(8, 5)) .+ (-40, -25)); release()
  @test v.at[1] > was[1] && v.at[2] > was[2] && block() == before
  press(K.window_point(v, house(8, 5))); at(K.window_point(v, house(8, 5)) .+ (5000, 5000)); release()
  @test all(v.at .≈ -K.PAPER_EDGE / v.zoom)   # the paper's corner, with the white that's kept round it
  button(:fit); frames()
  @test v.zoom ≈ small
  # A pinch on the trackpad makes it bigger round the mouse, with no key held, and no smaller than the whole page
  at(under); foreach(_ -> onpinch(w, 1.1), 1:8); frames()
  @test v.zoom ≈ small * 1.1^8
  @test all(isapprox.(K.window_point(v, house(8, 5)), under, atol=0.01))
  foreach(_ -> onpinch(w, 0.5), 1:4); frames()
  @test v.zoom ≈ small
  # A pinch over the text of the page does nothing
  at((500, 30)); onpinch(w, 1.5); frames()
  @test v.zoom ≈ small
end

@testset "the scale" begin
  button(:scale)
  @test v.asking == (:scale,) && K.plan_input(v).text == "1:100"
  command(Keys.a); typed("1:50"); key(Keys.enter)
  @test P.scale(v.data, 1) == 50 && v.asking === nothing && block()[3] == "scale: 1:50"
  @test amounts()[3] ≈ (20 + 7.82) / 4 atol=0.02
  # From a length that's known: the line under the house is 16 m
  typed("s")
  plan_click(0, -1.2); plan_click(16, -1.2)
  @test v.asking !== nothing && v.asking[1] == :length
  typed("16000mm"); key(Keys.enter)
  @test P.scale(v.data, 1) ≈ 100 atol=0.2
  @test v.tool == :select && isempty(v.draft)
  # What isn't a scale changes nothing, and says so
  button(:scale); command(Keys.a); typed("big"); key(Keys.enter)
  @test P.scale(v.data, 1) ≈ 100 atol=0.2
  @test v.wrong
end

@testset "the list of measures" begin
  # A new measure is a count until its item or a tool says what it is
  button(:add)
  @test length(v.data.measures) == 4 && v.data.measures[4].name == "Count 2" && v.tool == :count
  # It asks for its item, and takes the item's name. The conduit is sold by the metre, so it's a length, with the tool for one.
  # The search looks in the business's own items first.
  @test v.asking == (:item, 4) && K.ITEM_FROM[] == (:own,) && K.catalogue_words() == "Our catalogue"
  typed("conduit")
  @test settle(() -> !isempty(v.rows))
  @test v.search === nothing && [r["ref"] for r in v.rows] == ["item 1"]
  # What's found shows in a list that floats beside the text field, not on it, and goes when an item is chosen
  found() = [p for p in popups(w) if p.key == K.FOUND_KEY]
  field, list = rect(K.plan_input(v)), only(found()).scene
  @test list.top >= field.top + field.height || list.top + list.height <= field.top
  # A click in the text field is the field's, and the list stays
  click((K.num(field.left) + 20, K.num(field.top + field.height / 2)))
  @test v.asking == (:item, 4) && length(found()) == 1
  # The mouse picks the row that it's over
  v.pick = 0
  at(part((:found, 1))); frames()
  @test v.pick == 1
  key(Keys.down); key(Keys.up); key(Keys.enter)
  @test isempty(found())
  @test v.asking === nothing && v.data.measures[4].item == "item 1" && v.data.measures[4].name == "20mm conduit"
  @test v.data.measures[4].kind == :length && v.tool == :length && v.current == 4 && !v.wrong
  @test block()[end] == "length | 20mm conduit | item 1"
  plan_click(1, 7); plan_click(5, 7); key(Keys.enter)
  @test amounts()[4] ≈ 4 atol=0.02
  # The first click on a measure chooses it, and a click on its name then changes the name
  click(part((:cell, 2, :name)))
  @test v.current == 2 && v.asking === nothing && v.tool == :length
  click(part((:cell, 2, :name)))
  @test v.asking == (:name, 2)
  command(Keys.a); typed("Cable | 2.5mm"); key(Keys.enter)
  @test v.data.measures[2].name == "Cable / 2.5mm"   # a | would end the name in the block
  # What's typed is kept when the click goes somewhere else
  click(part((:cell, 2, :extra)))
  @test v.asking == (:extra, 2) && K.plan_input(v).text == "10"
  command(Keys.a); typed("15")
  click(part((:cell, 2, :name)))   # this click closes the field and opens the name
  @test v.data.measures[2].extra == 0.15
  key(Keys.escape)
  @test v.asking === nothing
  # A click on a measure chooses the tool of its kind, from the arrow too
  button((:tool, :select))
  r = rect(v.parts[(:row, 3)])
  click((K.num(r.left) + 16, K.num(r.top + r.height / 2)))   # on its mark, at the left of the row
  @test v.current == 3 && v.tool == :area
  button((:delete, 4))
  @test length(v.data.measures) == 3 && !any(l -> occursin("conduit", l), block())
  # A measure with no item and nothing drawn is what the tool you choose makes it
  button(:add); key(Keys.escape)
  @test v.asking === nothing && v.data.measures[4].kind == :area && v.data.measures[4].name == "Area 2"
  typed("l")
  @test v.current == 4 && v.data.measures[4].kind == :length && v.data.measures[4].name == "Length 2"
  @test block()[end] == "length | Length 2"
  plan_click(1, 6); plan_click(5, 6); key(Keys.enter)
  # Once something is drawn it stays what it is. Another tool draws for the last measure of its own kind.
  typed("c")
  @test v.current == 1 && v.data.measures[4].kind == :length
  # An item with another unit doesn't change it then. The block says that the price is for something else.
  # ⌥ in the empty field shows the suppliers whose catalogues Centient holds. One of them opens its catalogue.
  click(part((:cell, 4, :item)))
  @test v.asking == (:item, 4)
  key(Keys.opt)
  @test K.ITEM_FROM[] == (:suppliers,) && K.catalogue_words() == "Pick a catalogue"
  @test settle(() -> !isempty(v.rows))
  @test [r["slug"] for r in v.rows] == ["acme"]
  typed("ac"); key(Keys.enter)
  @test K.ITEM_FROM[] == (:catalogue, "acme", "Acme Electrical") && K.plan_input(v).text == "" && v.asking == (:item, 4)
  @test settle(() -> !isempty(v.rows))
  @test [r["ref"] for r in v.rows] == ["acme 77"]
  # ⌥ does nothing while there are words in the field
  typed("po"); key(Keys.opt)
  @test K.ITEM_FROM[][1] == :catalogue
  key(Keys.enter)
  @test v.data.measures[4].item == "acme 77" && v.data.measures[4].kind == :length && v.tool == :length
  @test v.wrong && occursin("is for each one, and this measure is a length", v.said)
  # The next search starts in the catalogue that the item came from. A click on the list's foot does what ⌥ does:
  # back to the suppliers, then to the business's own items.
  click(part((:cell, 4, :item))); click(part((:cell, 4, :item)))
  @test v.asking == (:item, 4) && K.catalogue_words() == "Acme Electrical"
  @test settle(() -> !isempty(v.rows))
  click(part(:catalogue_foot))
  @test K.ITEM_FROM[] == (:suppliers,) && v.asking == (:item, 4)
  click(part(:catalogue_foot))
  @test K.ITEM_FROM[] == (:own,)
  @test settle(() -> !isempty(v.rows))
  @test [r["ref"] for r in v.rows] == ["item 1"]
  key(Keys.escape)
  @test v.asking === nothing
  button((:delete, 4))
  @test length(v.data.measures) == 3
end

@testset "the columns of the table" begin
  names() = [v.data.measures[i].name for i in v.order]
  head(key) = click(part((:head, key)))
  menus() = [p for p in popups(w) if p.key == K.HEAD_KEY]
  frames()
  written, before = names(), block()
  @test length(written) == 3
  # A click on a heading of numbers sorts by it: low to high, then high to low, then as the block is written
  head(:amount)
  @test v.sort == (:amount, :asc) && issorted([amounts()[i] for i in v.order])
  head(:amount)
  @test issorted([amounts()[i] for i in v.order], rev=true) && names() != written
  head(:amount)
  @test v.sort === nothing && names() == written
  # A heading fills its cell, so a click away from its words uses it too
  cell, words = rect(v.parts[(:head, :amount)]), rect(v.parts[(:head, :amount)].words)
  @test K.num(cell.width) > K.num(words.width) + 20 && K.num(cell.height) >= 24
  corner = (K.num(cell.left) + 3, K.num(cell.top) + 3)
  at(corner)
  @test K.ishovered(v.parts[(:head, :amount)])
  click(corner)
  @test v.sort == (:amount, :asc)
  click(corner); click(corner)
  @test v.sort === nothing
  name = rect(v.parts[(:head, :name)])
  click((K.num(name.left + name.width) - 4, K.num(name.top + name.height / 2)))
  @test v.asking == (:filter, :name, "") && length(menus()) == 1
  key(Keys.escape)
  @test v.asking === nothing && isempty(menus())
  # A heading of text opens a menu under it, with its two orders and a field that searches the column
  head(:name)
  @test v.asking == (:filter, :name, "") && length(menus()) == 1
  @test only(menus()).scene.top > rect(v.parts[(:head, :name)]).top
  click(part((:sort, :name, :desc)))
  @test names() == sort(written, by=lowercase, rev=true) && length(menus()) == 1
  typed("cab")
  @test names() == ["Cable / 2.5mm"]
  key(Keys.enter)
  @test v.asking === nothing && isempty(menus()) && v.filters == Dict(:name => "cab")
  # Esc puts the search back as it was when the menu opened
  head(:name)
  @test K.plan_input(v).text == "cab"
  command(Keys.a); typed("zzz")
  @test isempty(v.order)
  key(Keys.escape)
  @test v.asking === nothing && isempty(menus()) && names() == ["Cable / 2.5mm"]
  # A click outside the menu closes it and keeps what's typed. A click on the order that's on takes it away.
  head(:name)
  click(part((:sort, :name, :desc)))
  command(Keys.a); typed("o")
  click(K.window_point(v, house(14, 3)))
  @test isempty(menus()) && v.sort === nothing && names() == ["Power points", "Floor"]
  # No words takes the search away
  head(:name); command(Keys.a); key(Keys.backspace); key(Keys.enter)
  @test isempty(v.filters) && names() == written
  # None of this changes the block, and a new measure shows though a search would hide it
  @test block() == before
  head(:name); typed("zzz"); key(Keys.enter)
  button(:add); key(Keys.escape)
  @test isempty(v.filters) && length(v.order) == 4
  button((:delete, 4))
  K.tool!(v, :select)
end

@testset "the units of a measure" begin
  units() = [p for p in popups(w) if p.key == K.UNIT_KEY]
  # The unit after an amount is what a click on it opens
  word(i) = v.parts[(:amount, i)].unit
  amount(i) = (r = rect(word(i)); click((K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))))
  cable = v.data.measures[2]
  line(m) = only(l for l in block() if occursin("| " * m.name, l))
  # A count with marks can be in pieces and no more, so it has no unit to click. A click on it chooses it.
  click(part((:amount, 1)))
  @test v.current == 1 && v.asking === nothing && isempty(units()) && word(1) === nothing
  # A click on a length's number chooses it too, and shows no list
  r = rect(v.parts[(:amount, 2)])
  click((K.num(r.left) + 8, K.num(r.top + r.height / 2)))
  @test v.current == 2 && v.asking === nothing && isempty(units())
  # A click on its unit lists the units of length, smallest first, under the unit. The one it's in is picked.
  amount(2)
  @test v.asking == (:unit, 2) && length(units()) == 1
  @test v.rows == ["mm", "cm", "inch", "ft", "yard", "m", "km", "mile"] && v.rows[v.pick] == "m"
  @test only(units()).scene.top > rect(word(2)).top
  # What's typed searches the names and the short forms. Return takes the unit that's picked.
  typed("mm")
  @test v.rows == ["mm"]
  key(Keys.enter)
  @test isempty(units()) && v.asking === nothing && cable.unit == "mm"
  @test startswith(line(cable), "length in mm | ")
  @test K.Plans.shown(cable, K.Plans.amount(v.data, cable)) == K.Plans.amount_number(1000K.Plans.amount(v.data, cable)) * " mm"
  # Esc, or a click somewhere else, closes the list and changes nothing
  amount(2); typed("ft"); key(Keys.escape)
  @test isempty(units()) && cable.unit == "mm"
  amount(2); key(Keys.down)
  click(K.window_point(v, house(14, 3)))
  @test isempty(units()) && cable.unit == "mm"
  # The arrows pick a unit, and the mouse picks the one it's over. A click takes it.
  amount(2)
  @test v.rows[v.pick] == "mm"
  key(Keys.down); key(Keys.down); key(Keys.up)
  @test v.rows[v.pick] == "cm"
  feet = findfirst(==("ft"), v.rows)
  at(part((:unit_row, feet)))
  @test v.pick == feet
  click(part((:unit_row, feet)))
  @test cable.unit == "ft" && startswith(line(cable), "length in ft | ")
  # A quote's line is in the measure's unit, and a cost is for the unit that the item is priced in
  q = K.quote_line(cable, 3.048)
  @test q["unit"] == "ft" && q["quantity"] == 10
  @test K.cost_of(cable, 3.048, Dict("unit" => "ft", "price" => 2.0)) ≈ 20
  @test K.cost_of(cable, 3.048, Dict("unit" => "m", "price" => 2.0)) ≈ 6.096
  # The price shows for one of the measure's unit: \$2 a metre is 61c a foot. A price a piece can't be.
  @test K.unit_price(cable, Dict("unit" => "m", "price" => 2.0)) ≈ 0.6096
  @test K.unit_price(cable, Dict("unit" => "lineal metre", "price" => 2.0)) ≈ 0.6096
  @test K.unit_price(cable, Dict("unit" => "each", "price" => 2.0)) === nothing
  @test K.unit_price(v.data.measures[1], Dict("unit" => "each", "price" => 12.5)) == 12.5
  # Its kind's own unit is written as none
  amount(2); typed("metre")
  @test v.rows == ["mm", "cm", "m", "km"] && v.rows[v.pick] == "m"   # it names m, and is only part of the others
  key(Keys.enter)
  @test cable.unit == "" && startswith(line(cable), "length | ")
  # A new measure with nothing drawn and no item lists every unit. One of another kind changes what it measures.
  button(:add); key(Keys.escape)
  n = length(v.data.measures)
  amount(n)
  @test length(v.rows) == 18 && v.rows[v.pick] == K.Plans.unit(v.data.measures[n])
  typed("square metre"); key(Keys.enter)
  m = v.data.measures[n]
  @test m.kind == :area && m.unit == "" && m.name == "Area 2" && v.tool == :area && v.current == n
  amount(n); typed("ft2")   # a keyboard's way to write ft²
  @test v.rows == ["ft²"]
  key(Keys.enter)
  @test m.unit == "ft²" && line(m) == "area in ft² | Area 2"
  # Once it has an item it keeps its kind, so it lists the units of its kind and no more
  m.item = "item 1"
  amount(n)
  @test v.rows == ["mm²", "inch²", "ft²", "yard²", "m²", "acre", "hectare", "km²", "mile²"]
  key(Keys.escape)
  button((:delete, n))
  @test length(v.data.measures) == 3 && cable.unit == ""
end

@testset "long words are cut short" begin
  m = v.data.measures[2]
  was = m.name
  m.name = "A cable with a very long name, longer than its cell in the table of measures by a long way"
  frames(3)
  cell = v.parts[(:cell, 2, :name)]
  name, item = rect(cell), rect(v.parts[(:cell, 2, :item)])
  # It takes no room from the item beside it. The two share the row, under their headings.
  @test name.width ≈ item.width
  @test name.left ≈ rect(v.parts[(:head, :name)]).left && item.left ≈ rect(v.parts[(:head, :item)]).left
  # Its words end with … and fit in the cell, and the mouse over it shows them whole
  shown = K.elide(m.name, 13px, name.width)
  @test endswith(shown, "…") && K.measure(K.Face(K.SANS, "", 13px, K.colours.ink, false), shown) <= name.width
  @test cell.full == m.name
  at(part((:cell, 2, :name)))
  @test any(p -> p.key == :tooltip, popups(w))
  # A short name fits, so it's whole and has no tooltip
  m.name = was
  at((10, 10)); frames(3)
  @test cell.full == "" && K.elide(was, 13px, rect(cell).width) == was
end

@testset "a heading's arrow doesn't move its words" begin
  K.tool!(v, :select)
  # Waste's words are at the left of its cell. With the mouse over it, its arrow shows after them.
  words = v.parts[(:head, :extra)].words
  at((10, 10)); frames()
  word = only(rect(words).children)
  cell = rect(v.parts[(:head, :extra)])
  at((K.num(cell.left) + 3, K.num(cell.top) + 3)); frames()
  @test K.ishovered(v.parts[(:head, :extra)]) && length(rect(words).children) == 2
  first, arrow = rect(words).children
  @test first.left == word.left && first.width == word.width && arrow.left > word.left
  at((10, 10)); frames()
end

@testset "a heading's tooltip is under its words and arrow from the first frame" begin
  # Amount's arrow shows when the mouse comes over it, on the frame after the mouse comes
  v.sort = nothing
  at((10, 10)); frames()
  r = rect(v.parts[(:head, :amount)].words)
  at((K.num(r.left + r.width) - 3, K.num(r.top + r.height / 2))); frames(1)
  r = rect(v.parts[(:head, :amount)].words)
  tip = only(p for p in popups(w) if p.key == :tooltip).scene
  @test tip.left + tip.width / 2 ≈ r.left + r.width / 2
  at((10, 10)); frames()
end

@testset "the quote" begin
  button(:quote)
  @test v.wrong && v.said == "Choose the customer first" && v.quoting === nothing
  button(:customer)
  @test v.asking == (:customer,)
  typed("smith")
  @test settle(() -> !isempty(v.rows))
  # The list of contacts is beside the field, not over it, and all of it is in the window
  list, field = only(p for p in popups(w) if p.key == K.FOUND_KEY).scene, rect(K.plan_input(v))
  @test list.top >= field.top + field.height || list.top + list.height <= field.top
  @test list.top >= 0px && list.top + list.height <= 1300px
  click(part((:found, 1)))
  @test isempty(popups(w))
  @test v.data.customer == "J Smith" && block()[4] == "customer: J Smith"
  button(:quote)
  @test v.quoting !== nothing
  @test settle(() -> v.quoting === nothing)
  @test !v.wrong && startswith(v.said, "Centient has quote Q-0007 for \$123.45 with GST")
  @test v.data.made == "Q-0007" && "quote: Q-0007" in block()
  # What Centient says went wrong shows at the foot of the block
  v.data.customer = "Nobody"
  button(:quote)
  @test settle(() -> v.quoting === nothing)
  @test v.wrong && v.said == "Centient has no contact called Nobody"
end

@testset "filling the window" begin
  scrolled, small = e.scroll.offset, v.box
  button(:full)
  @test v.full && K.full_takeoff(e) === v
  # The plan is as wide as the window, under the top bar and the tools, and still shows whole
  @test v.box[1] == 0 && v.box[3] == 1000 && v.box[4] > small[4]
  @test v.box[2] ≈ K.num(K.TOPBAR_H) + 38
  @test v.zoom ≈ K.fit_zoom(v, K.plan_size(v))
  # This window is tall, so the measures are under the plan. They work as they do in the page.
  @test !v.beside && K.num(rect(v.parts[(:row, 1)]).top) >= v.box[2] + v.box[4]
  @test K.num(rect(v.parts[(:button, :quote)]).top) < 1300
  click(part((:cell, 1, :name))); click(part((:cell, 1, :name)))
  @test v.asking == (:name, 1)
  key(Keys.escape)
  # What a button says is whole, though the button is at the left edge or the bottom of the window
  for b in (:add, :quote)
    at(part((:button, b))); frames()
    tip = only(popups(w)).scene
    @test tip.left >= 0px && tip.left + tip.width <= 1000px
    @test tip.top >= 0px && tip.top + tip.height <= 1300px
  end
  at((500, 400)); frames()
  @test isempty(popups(w))
  # The table is at the foot of the window, where a long list of items has no room under its field. So the list is
  # over the field from the first, while Centient still searches and the list is one line, and it stays there.
  click(part((:cell, 1, :item)))
  @test v.asking == (:item, 1)
  over() = (list = only(p for p in popups(w) if p.key == K.FOUND_KEY).scene; list.top + list.height <= rect(K.plan_input(v)).top)
  @test isempty(v.rows) && over()
  @test settle(() -> !isempty(v.rows))
  @test over()
  key(Keys.opt)
  @test over()
  @test settle(() -> !isempty(v.rows))
  @test over()
  key(Keys.opt); key(Keys.escape)
  @test v.asking === nothing && K.ITEM_FROM[] == (:own,)
  typed("c")
  n = amounts()[1]
  plan_click(3, 3)
  @test amounts()[1] == n + 1
  # Two fingers move a plan that's bigger than its view, with no click first
  under = K.window_point(v, house(8, 5))
  at(under); w.keys |= Keys.cmd; foreach(_ -> onscroll(w, Vec2{px}(0px, 3px)), 1:3); w.keys ⊻= Keys.cmd; frames()
  K.focus(e)
  was = v.at
  onscroll(w, Vec2{px}(-2px, -2px)); frames()
  @test v.at[1] > was[1] && v.at[2] > was[2]
  button(:fit); frames()
  # Esc puts the arrow back, then puts the takeoff back in the page, where the page was
  click(K.window_point(v, house(14, 3)))
  key(Keys.escape)
  @test v.tool == :select && v.full
  key(Keys.escape)
  @test !v.full && K.full_takeoff(e) === nothing
  frames()
  @test v.box[3] ≈ small[3] && v.box[4] ≈ small[4] && e.scroll.offset == scrolled
  @test v.zoom ≈ K.fit_zoom(v, K.plan_size(v))
end

@testset "the Done button ends a line and an outline" begin
  drawn(kind) = sum(length(m.shapes) for m in v.data.measures if m.kind == kind; init=0)
  newest(kind) = last(last(m for m in v.data.measures if m.kind == kind && !isempty(m.shapes)).shapes)
  inview(b) = b[1] >= v.box[1] && b[2] >= v.box[2] && b[1] + b[3] <= v.box[1] + v.box[3] && b[2] + b[4] <= v.box[2] + v.box[4]
  middle(b) = (b[1] + b[3] / 2, b[2] + b[4] / 2)
  button((:tool, :length))
  n = drawn(:length)
  @test K.done_box(v) === nothing
  plan_click(2, 7)
  @test K.done_box(v) === nothing   # one corner is no line
  plan_click(4, 7)
  b = K.done_box(v)
  @test b !== nothing && inview(b)
  # The line went to the right. The button is behind its last corner and under the line, so it's in the way of neither.
  x, y = K.window_point(v, house(4, 7))
  @test !K.on_done(v, x, y)
  @test b[1] + b[3] <= x + 0.01 && b[2] >= y + K.DONE_GAP - 0.01
  # A third corner, straight up from the second. The button goes behind that corner: under it, and to the right of the line.
  plan_click(4, 9)
  b = K.done_box(v)
  x, y = K.window_point(v, house(4, 9))
  @test inview(b) && b[2] >= y - 0.01 && b[1] >= x + K.DONE_GAP - 0.01
  # With the mouse over the button, the cursor is a hand and a tooltip names the key that does the same
  at(middle(b)); frames()
  @test K.cursor(v.parts[:area]) == :hand
  @test length(popups(w)) == 1
  # A click on it ends the line with the three corners. It puts no fourth corner down.
  sleep(0.4); click(middle(b))
  @test isempty(v.draft) && drawn(:length) == n + 1
  @test length(newest(:length).points) == 3
  @test K.done_box(v) === nothing && isempty(popups(w))
  @test v.tool == :length   # the tool stays, for the next line

  # An outline needs three corners
  button((:tool, :area))
  n = drawn(:area)
  plan_click(1, 1); plan_click(3, 1)
  @test K.done_box(v) === nothing
  plan_click(3, 3)
  b = K.done_box(v)
  @test b !== nothing && inview(b)
  sleep(0.4); click(middle(b))
  @test isempty(v.draft) && drawn(:area) == n + 1
  @test length(newest(:area).points) == 3

  # A count and the scale have no line to end
  button((:tool, :scale))
  plan_click(1, 5); @test K.done_box(v) === nothing
  key(Keys.escape); key(Keys.escape)
  @test v.tool == :select && K.done_box(v) === nothing
end

@testset "what's written reads back" begin
  again = P.takeoff(block())
  @test P.written(again) == block()
  @test isempty(K.problems)
  K.Centient.stop!()
end
