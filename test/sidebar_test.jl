# Tests for which files the sidebar opens to show their headings. See
# show_open_file! in main.jl. Run them with `julia -O0 --project=. test/sidebar_test.jl`.
# They open files and click in a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Kaydown uses
@eval K settings_file() = $(joinpath(dir, "settings"))

for name in ("a.md", "b.md", "c.md")
  write(joinpath(dir, name), "# $name\n\nSome words.\n\n## Part of $name\n\nMore words.\n")
end
write(joinpath(dir, "tool.jl"), "f(x) = x + 1\n")

const e = K.build_editor(joinpath(dir, "a.md"))
const w = Window(e, size=(900px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

"Show the sidebar, or hide it, and draw the window until the sidebar has finished its slide"
sidebar!() = begin
  K.toggle_panel!(e)
  to = e.panel ? 1 : 0
  while K.opened(e) != to
    frame(w)
  end
  frames()
end
"The item of the file `name` in the sidebar"
file(name) = only(item for item in K.file_tree(e).children if basename(item.firstchild.path) == name)
"Is the group of the file `name` open, so the sidebar lists its headings?"
isopen(name) = !file(name).collapsed
"The headings that the sidebar lists, from the top"
headings() = [item.firstchild.title for item in K.items(K.file_tree(e)) if item.firstchild isa K.EntryLabel]
"Click the window at `x`, `y`"
click(x, y) = begin
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames()
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames()
end
"Click the middle of the part of the window that `node` is drawn in"
click(node) = (r = rect(node); click(r.left + r.width / 2, r.top + r.height / 2))
"Click the icon at the start of the row of the file `name`. It opens or closes the file's group."
click_icon(name) = (r = rect(file(name).firstchild); click(r.left + 8px, r.top + r.height / 2))

@testset "the sidebar opens the file that shows the first time it opens" begin
  sidebar!()
  @test isopen("a.md") && !isopen("b.md") && !isopen("c.md")
  @test headings() == ["a.md", "Part of a.md"]
end

@testset "another file that shows opens, and the old one closes" begin
  K.open!(e, joinpath(dir, "b.md")); frames()
  @test !isopen("a.md") && isopen("b.md")
  @test headings() == ["b.md", "Part of b.md"]
  # A link opens a file too
  K.follow!(e, "c.md"); frames()
  @test !isopen("b.md") && isopen("c.md")
end

@testset "a click on a file's name in the sidebar opens it, and closes the old one" begin
  click(file("a.md").firstchild)
  @test basename(e.buf.path) == "a.md"
  @test isopen("a.md") && !isopen("c.md")
end

@testset "a group that's closed by hand stays closed until another file shows" begin
  click_icon("a.md")
  @test !isopen("a.md")
  frames(5)
  @test !isopen("a.md")
  # Another file that's opened by its icon stays open while the file that shows doesn't change
  click_icon("c.md")
  @test isopen("c.md")
  frames(5)
  @test isopen("c.md") && basename(e.buf.path) == "a.md"
end

@testset "a file that isn't Markdown has no headings, but the old file still closes" begin
  K.open!(e, joinpath(dir, "b.md")); frames()
  @test isopen("b.md")
  K.open!(e, joinpath(dir, "tool.jl")); frames()
  @test !isopen("b.md")
  @test !(file("tool.jl") isa K.Tree.ItemGroup)
end

@testset "a file that shows while the sidebar is hidden is open when the sidebar shows" begin
  K.open!(e, joinpath(dir, "a.md")); frames()
  sidebar!()
  @test !e.panel
  K.open!(e, joinpath(dir, "b.md")); frames()
  sidebar!()
  @test isopen("b.md") && !isopen("a.md")
end

@testset "a folder that the sidebar shows again opens the file that shows" begin
  inner = mkpath(joinpath(dir, "inner"))
  write(joinpath(inner, "d.md"), "# d\n")
  K.go_folder!(e, inner); frames()
  @test basename(e.buf.path) == "b.md"
  K.go_folder!(e, dir); frames()
  @test isopen("b.md")
end
