# Tests for where a name is defined, in main.jl: in Julia code, a click on a
# name with ⌘ held goes to where the name is defined, and so does the command
# Go To Definition. The command Go To lists the functions and the sections of
# a file of code. Run them with `julia -O0 --project=. test/definition_test.jl`.
# They click in a window that isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame cursor
@use GeometryBasics: Vec2
const px = K.px

# The folder has the same name each time, so that Kip compiles its files once
const dir = joinpath(tempdir(), "ladder-definition-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))

# A file that another file loads
const walls = joinpath(dir, "walls.jl")
write(walls, """
"A wall, by its length"
struct Wall
  long::Float64
end

"How much paint a wall takes"
paint(w::Wall) = w.long * 2.4 / 10
""")

const rooms = joinpath(dir, "rooms.jl")
write(rooms, """
@use "./walls" => Walls Wall

# --- the rooms -------------------------------------------------------------

const HEIGHT = 2.4

struct Room
  walls::Vector{Wall}
end

area(r::Room) = sum(w -> w.long, r.walls) * HEIGHT
area(w::Wall) = w.long * HEIGHT

# --- the paint ---------------------------------------------------------------

function litres(r::Room, coats=2)
  total = 0.0
  for wall in r.walls
    total += Walls.paint(wall) * coats
  end
  total = round(total, digits=1)   # a string with area( in it: "area(r)"
  total + area(r)
end
""")
# Ladder loaded the file, as it loads the file of a kind of block
Base.invokelatest(K.Kip.require, rooms, dir)

const e = K.build_editor(rooms)
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
const b = e.buf
line(words) = findfirst(l -> occursin(words, l), b.lines)
"The place of the first `name` on the line that has `words`, a few characters into the name"
at(words, name; into=1) = (i = line(words); (i, length(b.lines[i], 1, first(findfirst(name, b.lines[i])) - 1) + into))
"Where a click on that place goes"
goes(words, name; into=1) = K.definition(e, at(words, name; into))

@testset "the name at a place" begin
  @test K.name_at(b, at("total + area(r)", "area")).name == "area"
  @test K.name_at(b, at("total + area(r)", "area", into=0)).name == "area" && K.name_at(b, at("total + area(r)", "area", into=4)).name == "area"
  found = K.name_at(b, at("Walls.paint(wall)", "paint"))
  @test found.name == "paint" && found.owners == ["Walls"]
  # A word of the language, a number, a string and a comment have no name
  @test K.name_at(b, at("function litres", "function")) === nothing && K.name_at(b, at("total = 0.0", "0.0")) === nothing
  @test K.name_at(b, at("a string with", "string")) === nothing && K.name_at(b, at("\"area(r)\"", "area(r)\"")) === nothing
  @test K.name_at(b, at("the rooms", "rooms")) === nothing
end

@testset "a name that the file makes" begin
  # A name of the function that the click is in, where it was last made before the click
  @test goes("total + area(r)", "total") == (line("total = round"), 2)
  @test goes("total += Walls", "total") == (line("total = 0.0"), 2)
  @test goes("Walls.paint(wall)", "wall)") == (line("for wall in"), 6)
  @test goes("for wall in r.walls", "r.walls") == (line("function litres"), 16)
  # A name of the whole file
  @test goes("* HEIGHT", "HEIGHT") == (line("const HEIGHT"), 6)
  @test goes("function litres(r::Room", "Room") == (line("struct Room"), 7)
  # A function with two methods: the first, and from the first the second, and from the second the first again
  first_one, second = (line("area(r::Room)"), 0), (line("area(w::Wall)"), 0)
  @test goes("total + area(r)", "area") == first_one
  @test K.definition(e, first_one) == second && K.definition(e, second) == first_one
end

@testset "a name that another file makes" begin
  m = goes("Walls.paint(wall)", "paint")
  @test m isa Method && K.code_place(m) == (realpath(walls), 7)
  m = goes("walls::Vector{Wall}", "Wall")
  @test m isa Method && K.code_place(m)[1] == realpath(walls)
  # A part of a value, after a dot, has no place, and nor has a name that nothing made
  @test goes("sum(w -> w.long", "long") === nothing
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "nowhere_at_all(1)")
  @test K.definition(e, (length(b.lines), 3)) === nothing
  K.undo!(b)
end

"Hold ⌘ and click the place `p` of the page"
click(p) = begin
  it = K.item(e, p[1])
  _, x = K.spot(it.content, p[2])
  pos = Vec2{px}(e.origin[1] + x + 1px, e.origin[2] + it.top + it.tall / 2)
  w.mouse = typeof(w.mouse)(pos...)
  onmouse(w, MouseMove(pos, w))
  w.keys |= Keys.cmd
  frames(1)
  hand = cursor(e.nodes[:document]) == :hand
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd
  frames()
  hand
end

@testset "a click with ⌘ held goes there" begin
  # The mouse is a hand over a name that has a place to go to
  @test click(at("total + area(r)", "area"))
  @test b.caret == (line("area(r::Room)"), 0)
  @test click(b.caret) && b.caret == (line("area(w::Wall)"), 0)
  # A name with no place leaves the caret where the click put it, and the mouse isn't a hand
  p = at("sum(w -> w.long", "long")
  @test !click(p) && b.caret[1] == p[1]
  # A name of another file shows in a window beside this one, at its line
  @test click(at("Walls.paint(wall)", "paint"))
  shown = only(filter(o -> o.buf.path == realpath(walls), K.editors))
  @test shown.buf.caret[1] == 7 && shown.buf.view == :code
end

@testset "the command Go To Definition" begin
  b.caret = b.anchor = at("* HEIGHT", "HEIGHT")
  K.go_to_definition!(e)
  @test b.caret == (line("const HEIGHT"), 6)
  b.caret = b.anchor = at("the paint", "paint")
  @test_throws ErrorException K.go_to_definition!(e)
end

@testset "Go To lists the sections and the names of a file of code" begin
  places = K.choices_for(K.HeadingLine, e)
  @test [(K.worded(p), K.sidenote(p)) for p in places] == [
    ("Walls", "line 1"), ("Wall", "line 1"),
    ("the rooms", "section · line 3"), ("HEIGHT", "Float64 · line 5"), ("Room", "struct · line 7"),
    ("area(r::Room)", "function · line 11"), ("area(w::Wall)", "function · line 12"),
    ("the paint", "section · line 14"), ("litres(r::Room, coats=2)", "function · line 16")]
  K.go_to!(e, places[end])
  frames()
  @test b.caret[1] == 16 && e.layout[first(e.shown)].first <= 16
  # A page of Markdown still lists its headings
  page = joinpath(dir, "page.md")
  write(page, "# One\n\nWords.\n\n## Two\n")
  K.open!(e, page)
  frames()
  @test [(K.worded(p), K.sidenote(p)) for p in K.choices_for(K.HeadingLine, e)] == [("One", "line 1"), ("Two", "line 5")]
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
