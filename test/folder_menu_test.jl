# Tests for the menu of a folder in the sidebar. See "the menu of a file" in
# main.jl. Run them with `julia -O0 --project=. test/folder_menu_test.jl`.
# They right-click, type and press keys in a window that isn't on the screen,
# so the menu is the one that Ladder draws, not the Mac's own.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2

const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))
# What goes to the Trash here is only removed
const trashed = String[]
K.trasher[] = path -> (push!(trashed, path); rm(path; recursive=true); true)

const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\nSome words.\n")
mkpath(joinpath(dir, "Projects", "old"))
write(joinpath(dir, "Projects", "plan.md"), "# Plan\n\nThe plan.\n")
write(joinpath(dir, "Projects", "old", "first.md"), "# First\n")
mkpath(joinpath(dir, "Archive"))
mkpath(joinpath(dir, "v1.2"))

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.panel || K.toggle_panel!(e)
frames(3)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
right_click(place) = (at(place); onkey(w, KeyPress{Keys.mouse_right}(0, w)); frames())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())

"The names that the sidebar's tree lists, from the top"
listed() = [basename(i.firstchild.path) for i in K.file_tree(e).children]
"The row of the folder or file `name` in the sidebar"
row(name) = only(i for i in K.file_tree(e).children if basename(i.firstchild.path) == name).firstchild
"The menu that Ladder drew, or nothing"
menu() = (ps = [p for p in popups(w) if p.key == :menu]; isempty(ps) ? nothing : only(ps).content)
"Choose the item called `name` in the menu that Ladder drew, with ↓ and Return"
choose(name) = begin
  m = menu()
  foreach(_ -> key(Keys.down), 1:findfirst(==(name), m.items))
  key(Keys.enter)
end
renaming() = K.renaming(e, :sidebar)
"Right-click the folder `name` in the sidebar and choose `item` from its menu"
folder_menu(name, item) = (right_click(middle(rect(row(name)))); choose(item))

@testset "a right-click on a folder in the sidebar shows its menu" begin
  @test listed() == ["Archive", "Projects", "v1.2", "notes.md"]
  right_click(middle(rect(row("Projects"))))
  @test menu() !== nothing
  # The Finder can show a folder, so Show in Finder isn't grey
  @test menu().items == ["Rename", "Copy Path", "Show in Finder", "Move to Trash"]
  key(Keys.escape)
  @test menu() === nothing
end

@testset "Rename puts a text field with all of the folder's name where the name was" begin
  folder_menu("Projects", "Rename")
  @test renaming() == joinpath(dir, "Projects")
  @test w.focus === K.renamer(e)
  i = K.renamer(e)
  @test i.text == "Projects"
  @test (i.anchor, i.cursor) == (0, length("Projects"))
  typed("Work")
  key(Keys.enter)
  @test renaming() == ""
  @test !isdir(joinpath(dir, "Projects")) && isdir(joinpath(dir, "Work"))
  # What was in the folder is in it still
  @test read(joinpath(dir, "Work", "plan.md"), String) == "# Plan\n\nThe plan.\n"
  @test isfile(joinpath(dir, "Work", "old", "first.md"))
  @test listed() == ["Archive", "v1.2", "Work", "notes.md"]
  # The keyboard goes back to the sidebar
  @test w.focus === K.file_tree(e)
end

@testset "a dot in a folder's name isn't an ending that the new name keeps" begin
  folder_menu("v1.2", "Rename")
  @test (K.renamer(e).anchor, K.renamer(e).cursor) == (0, 4)
  typed("v2")
  key(Keys.enter)
  @test isdir(joinpath(dir, "v2")) && !ispath(joinpath(dir, "v2.2")) && !ispath(joinpath(dir, "v1.2"))
end

@testset "a name that another folder has changes nothing, and the field stays" begin
  folder_menu("Work", "Rename")
  typed("Archive")
  key(Keys.enter)
  @test renaming() == joinpath(dir, "Work")
  @test isdir(joinpath(dir, "Work")) && isempty(readdir(joinpath(dir, "Archive")))
  key(Keys.escape)
  @test renaming() == "" && isdir(joinpath(dir, "Work"))
end

@testset "a page of a folder that's renamed keeps showing, with its changes" begin
  plan = joinpath(dir, "Work", "plan.md")
  K.open!(e, plan); frames()
  typed("Edited ")
  @test K.dirty(e.buf)
  # The sidebar shows the folder above, and the page of the folder stays
  K.go_folder!(e, dir); frames()
  folder_menu("Work", "Rename")
  typed("Jobs")
  key(Keys.enter)
  moved = joinpath(dir, "Jobs", "plan.md")
  @test e.buf.path == moved && K.dirty(e.buf)
  @test haskey(e.buffers, moved) && !haskey(e.buffers, plan)
  # Going back from it still finds the page that showed before
  @test page in e.back
  K.save!(e.buf)
  @test occursin("Edited ", read(moved, String))
  @test !ispath(plan)
end

@testset "Move to Trash takes the folder away with what's in it" begin
  plan = joinpath(dir, "Jobs", "plan.md")
  @test e.buf.path == plan
  K.focus(e)
  typed("More ")
  @test K.dirty(e.buf)
  empty!(trashed)
  folder_menu("Jobs", "Move to Trash")
  @test trashed == [joinpath(dir, "Jobs")]
  @test !ispath(joinpath(dir, "Jobs"))
  @test listed() == ["Archive", "v2", "notes.md"]
  # The page that showed was in the folder, so the sidebar's first page shows
  @test e.buf.path == page
  @test !any(p -> startswith(p, joinpath(dir, "Jobs")), keys(e.buffers))
end

@testset "changes that weren't saved went to the Trash with the folder" begin
  saved = String[]
  K.trasher[] = path -> (push!(saved, read(joinpath(path, "plan.md"), String)); rm(path; recursive=true); true)
  mkpath(joinpath(dir, "Drafts"))
  draft = joinpath(dir, "Drafts", "plan.md")
  write(draft, "# Draft\n")
  K.open!(e, draft); frames()
  typed("Unsaved ")
  K.go_folder!(e, dir); frames()
  folder_menu("Drafts", "Move to Trash")
  @test length(saved) == 1 && occursin("Unsaved ", only(saved))
end

@testset "a left-click on a folder still shows it in the sidebar" begin
  at(middle(rect(row("v2"))))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frames()
  @test e.folder == joinpath(dir, "v2")
  @test menu() === nothing
end
