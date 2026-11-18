# Tests for the slider of the levels: the picture in the top bar opens out into
# it while the mouse is over the picture. See "the slider of the levels" in
# main.jl. Run them with `julia -O0 --project=. test/levels_test.jl`. They
# write a page, a JSON file, a file of text and a CSV file into a temporary folder, and click in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save
# pictures of the slider there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const page = file("index.md", "# Files\n\nSome **bold** words.\n")
const job = file("job.json", """{"job": "Kitchen", "rooms": 3, "client": {"name": "Sam Lee"}}\n""")
const notes = file("notes.txt", "Some notes.\n")
const prices = file("prices.csv", "Item,Price\nPaint,42.50\nTimber,8\nNails,3.20\n")
const blob = joinpath(dir, "blob.bin")
write(blob, UInt8[0x00, 0x01, 0x02, 0xff, 0xfe, 0x00])
const code = file("sums.jl", "1 + 1\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"Press ⌘E"
other() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())

"The picture in the top bar"
mode() = e.nodes[:mode]
"The slider, or nothing while it's closed"
slider() = (found = [p.content for p in popups(w) if p.key == K.LEVELS_KEY]; isempty(found) ? nothing : only(found))
"Put the mouse over the picture, and wait until the slider has opened all the way"
hover() = (at(middle(rect(mode()))); sleep(2K.OPENS_IN); frames(); slider())
"Take the mouse off the slider"
leave() = (at((500, 400)); frames())
"The stop of level `i`"
stop(i) = slider().stops[i]
# An icon is in the button as the box that it draws in, and the box knows the icon that it came from
icons(node, out=String[]) = begin
  (node isa K.GeometricUI && !(node isa K.Text)) || return out
  hasproperty(node, :from) && node.from isa K.Icon && push!(out, node.from.name)
  foreach(n -> icons(n, out), node.children)
  out
end
"The picture that the top bar shows while the slider is closed"
icon() = only(icons(K.describe(mode())))
"What the tooltip says, or nothing when there's none"
tip() = (found = [p for p in popups(w) if p.key == :tooltip]; isempty(found) ? nothing : only(found).content.content.children[1].content)

@testset "a page has two levels, and the slider has the snake and the ladder" begin
  @test slider() === nothing && icon() == "ladder"
  @test K.levels(e) == K.PAGE_LEVELS && K.level(e) == 2
  l = hover()
  @test l isa K.Levels && length(l.stops) == 2
  # The slider lies over the picture, with the ladder where the picture is
  m, s = rect(mode()), rect(l)
  @test s.left + s.width == m.left + m.width && s.top == m.top && s.width == 2K.MODE_W + K.TRACK_W
  @test rect(stop(2)).left == m.left && rect(stop(1)).left == s.left
  @test icons(K.describe(stop(1))) == ["snake"] && icons(K.describe(stop(2))) == ["ladder"]
  shot("levels-page.png")
  # The mouse is over the ladder, and the tip says what a click on it does
  @test K.stop_tip(e, 2) == "Go down a level, to the symbols of the part with the caret  ⌘E"
  @test K.stop_tip(e, 1) == K.stop_tip(e, 2) == K.tip(mode())
  # A click where the picture is goes down a level, as a click on the picture did
  click(middle(rect(mode())))
  @test e.plain && K.level(e) == 1 && K.low(e) && w.focus === e
  @test slider() === l   # the mouse is still over it
  @test K.stop_tip(e, 2) == "Go up a level, to the graphics that the symbols make  ⌘E"
  click(middle(rect(mode())))
  @test !e.plain && K.level(e) == 2
  # A click on the snake goes down, and another goes up again
  click(middle(rect(stop(1))))
  @test e.plain
  click(middle(rect(stop(1))))
  @test !e.plain
  # The slider goes when the mouse leaves it
  leave()
  @test slider() === nothing && icon() == "ladder"
end

@testset "a JSON file has four levels" begin
  K.open!(e, job)
  frames(3)
  @test e.buf.view == :file && K.levels(e) == (K.FILE_LEVELS..., "the tree of the file's values") && K.level(e) == 4 && icon() == "ladder"
  l = hover()
  @test length(l.stops) == 4
  @test rect(l).width == 2K.MODE_W + 2K.STOP_W
  # The stops are in the order of their levels, from the snake at the left
  @test issorted([rect(stop(i)).left for i in 1:4])
  @test icons(K.describe(stop(1))) == ["snake"] && isempty(icons(K.describe(stop(2)))) && icons(K.describe(stop(4))) == ["ladder"]
  shot("levels-json-tree.png")
  @test K.stop_tip(e, 1) == "Go down 3 levels, to the file's bits"
  @test K.stop_tip(e, 2) == "Go down 2 levels, to the file's bytes in hexadecimal"
  @test K.stop_tip(e, 3) == K.stop_tip(e, 4) == "Go down a level, to the file's text  ⌘E"
  # The mouse over a stop shows its tip
  at(middle(rect(stop(2))))
  @test tip() == K.stop_tip(e, 2)
  shot("levels-json-tip.png")
  # A click on a stop goes to its level
  click(middle(rect(stop(2))))
  @test e.buf.view == :hex && K.level(e) == 2 && K.json_page(e.buf)
  @test startswith(e.buf.lines[1], "00000000  7b 22 6a 6f 62 22 3a 20")
  @test K.stop_tip(e, 2) == "The window shows the file's bytes in hexadecimal"
  @test K.stop_tip(e, 4) == "Go up 2 levels, to the tree of the file's values  ⌘E"
  shot("levels-json-hex.png")
  # The words beside the picture are longer at one level than at another. The slider stays where it is, under the mouse.
  @test slider() === l && rect(mode()).left + rect(mode()).width == rect(l).left + rect(l).width
  click(middle(rect(stop(1))))
  @test e.buf.view == :bits && K.level(e) == 1
  # Each line has 6 bytes as bits, then the same bytes as characters
  @test e.buf.lines[1] == "00000000  01111011 00100010 01101010 01101111 01100010 00100010  {\"job\""
  @test e.buf.lines[2] == "00000006  00111010 00100000 00100010 01001011 01101001 01110100  : \"Kit"
  @test length(e.buf.lines) == cld(filesize(job), K.BITS_ROW)
  shot("levels-json-bits.png")
  # A click on the snake at the lowest level goes one level up
  click(middle(rect(stop(1))))
  @test e.buf.view == :hex
  click(middle(rect(stop(3))))
  @test e.buf.view == :text && startswith(e.buf.lines[1], "{\"job\"")
  shot("levels-json-text.png")
  click(middle(rect(stop(4))))
  @test e.buf.view == :file && K.level(e) == 4
  # A click on the ladder at the highest level goes one level down
  click(middle(rect(stop(4))))
  @test e.buf.view == :text
  leave()
  # Under the highest level, the top bar shows the snake
  @test slider() === nothing && icon() == "snake"
end

@testset "⌘E goes down from the tree, and up to it from any other level" begin
  K.file_level!(e, :file); frames()
  other()
  @test e.buf.view == :text
  other()
  @test e.buf.view == :file
  K.level!(e, 1); frames()
  @test e.buf.view == :bits
  other()
  @test e.buf.view == :file
end

@testset "a drag along the slider goes to each stop that the mouse comes to" begin
  hover()
  press(middle(rect(stop(4))))
  @test e.buf.view == :text   # the click on the ladder
  # The mouse moves a little on the ladder, and the level stays
  at(middle(rect(stop(4))) .+ (2, 0))
  @test e.buf.view == :text
  at(middle(rect(stop(2))))
  @test e.buf.view == :hex
  at(middle(rect(stop(1))))
  @test e.buf.view == :bits
  at(middle(rect(stop(4))))
  @test e.buf.view == :file
  release()
  # With the button up, the mouse over a stop changes nothing
  at(middle(rect(stop(2))))
  @test e.buf.view == :file
  leave()
end

@testset "a file that's read again stays at its level" begin
  K.level!(e, 2); frames()
  write(job, """{"job": "Bathroom"}\n""")
  K.READ[job] = 0.0   # as if the file's time had changed
  K.refresh!(e.buf); frames()
  @test e.buf.view == :hex && startswith(e.buf.lines[1], "00000000  7b 22 6a 6f 62 22 3a 20  22 42 61 74")
  K.level!(e, 1); frames()
  write(job, """{"job": "Laundry"}\n""")
  K.READ[job] = 0.0
  K.refresh!(e.buf); frames()
  @test e.buf.view == :bits && endswith(e.buf.lines[2], ": \"Lau")
end

@testset "the window stays at its place in the file from one level to the next" begin
  # 400 lines of 16 bytes each: line k of the text starts at byte 16(k - 1)
  long = file("long.json", "[\n" * join(("\"" * lpad(k, 12, '0') * "\"" for k in 2:399), ",\n") * "\n]\n")
  K.open!(e, long)
  frames(3)
  K.level!(e, 3); frames()
  @test e.buf.view == :text && e.buf.lines[101] == "\"000000000101\","
  top() = e.layout[findfirst(it -> it.top + it.tall > e.scroll.offset, e.layout)].first
  # Line 101 of the text is at the top of the window. It starts 1,586 bytes into the file.
  e.scroll.offset = K.item(e, 101).top; frames()
  @test top() == 101
  K.level!(e, 2); frames()
  @test e.buf.view == :hex && top() == 100 && startswith(e.buf.lines[100], "00000630") && endswith(e.buf.lines[100], ",.\"000000000101\"")
  K.level!(e, 1); frames()
  # Byte 1,584 is the first of a line of 6 bytes too
  @test e.buf.view == :bits && top() == 265 && startswith(e.buf.lines[265], "00000630")
  # That line starts two bytes before line 101 of the text, in line 100
  K.level!(e, 3); frames()
  @test e.buf.view == :text && top() == 100
  # In a narrow window the lines of bytes keep their columns, and the page scrolls sideways
  K.level!(e, 1); frames()
  @test !K.wraps(e) && all(it -> length(it.content.lines) == 1, e.layout[1:20])
  @test K.text_left(e) == K.PAGE_X
  # The tree shows from its top
  K.level!(e, 4); frames()
  @test e.buf.view == :file && e.scroll.offset == 0px
end

@testset "a file of text has three levels, and its text is the highest" begin
  K.open!(e, notes)
  frames(3)
  @test e.buf.view == :text && K.file_views(e.buf) == (:bits, :hex, :text)
  @test K.levels(e) == K.FILE_LEVELS && K.level(e) == 3 && !K.low(e) && icon() == "ladder"
  l = hover()
  @test length(l.stops) == 3 && rect(l).width == 2K.MODE_W + K.STOP_W
  @test K.stop_tip(e, 3) == K.stop_tip(e, 2) == "Go down a level, to the file's bytes in hexadecimal  ⌘E"
  shot("levels-text.png")
  click(middle(rect(stop(1))))
  @test e.buf.view == :bits && startswith(e.buf.lines[1], "00000000  01010011 01101111")
  click(middle(rect(stop(2))))
  @test e.buf.view == :hex && K.level(e) == 2 && length(l.stops) == 3
  # ⌘E goes back up to the text, and down again to the bytes
  other()
  @test e.buf.view == :text && e.buf.lines == ["Some notes."]
  other()
  @test e.buf.view == :hex
  click(middle(rect(stop(3))))
  @test e.buf.view == :text
  leave()
end

@testset "a CSV file has four levels, and its table is the highest" begin
  K.open!(e, prices)
  frames(3)
  @test e.buf.view == :file && K.sheet_page(e.buf) && K.file_views(e.buf) == K.FILE_VIEWS
  @test K.levels(e)[4] == "the file's table" && K.level(e) == 4 && icon() == "ladder"
  sheet = only(n for n in values(e.nodes) if n isa K.FileView && n.path == prices)
  sheet.table.sort = (2, :desc); frames()
  l = hover()
  @test length(l.stops) == 4
  @test K.stop_tip(e, 4) == "Go down a level, to the file's text  ⌘E"
  shot("levels-csv.png")
  click(middle(rect(stop(3))))
  @test e.buf.view == :text && e.buf.lines[1] == "Item,Price" && K.numbered(e.buf)
  @test K.stop_tip(e, 4) == "Go up a level, to the file's table  ⌘E"
  shot("levels-csv-text.png")
  click(middle(rect(stop(2))))
  @test e.buf.view == :hex && startswith(e.buf.lines[1], "00000000  49 74 65 6d 2c 50 72 69")
  click(middle(rect(stop(1))))
  @test e.buf.view == :bits
  # Back at the table, the rows are in the order that they were put in
  click(middle(rect(stop(4))))
  @test e.buf.view == :file && sheet.table.sort == (2, :desc)
  # A file that's read again while it shows its text goes on showing its text
  K.level!(e, 3); frames()
  write(prices, "Item,Price\nPaint,45\n")
  K.READ[prices] = 0.0
  K.refresh!(e.buf); frames()
  @test e.buf.view == :text && e.buf.lines == ["Item,Price", "Paint,45"]
  leave()
end

@testset "a file with one way to show has no slider" begin
  # A file of bytes, and its bytes after the button showed them
  K.open!(e, blob)
  frames(3)
  @test e.buf.view == :file && isempty(K.file_views(e.buf)) && isempty(K.mode_part(e))
  K.hex!(e); frames()
  @test e.buf.view == :hex && isempty(K.file_views(e.buf)) && isempty(K.mode_part(e))
  # A file of code in a language that Ladder doesn't change shows as text, so it has the levels of a file of text.
  # A file of Julia code has levels of its own: test/julia_levels_test.jl has those.
  K.open!(e, code)
  frames(3)
  @test e.buf.view == :code && isempty(K.file_views(e.buf)) && K.levels(e) == K.CODE_LEVELS
end

close(w)
