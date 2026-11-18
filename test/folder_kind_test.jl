# Tests for a kind of folder in the sidebar: a type under `AbstractDirectory`
# that code gives to a folder, with methods that say how the sidebar shows
# that folder. See the comment over `list_files!` in main.jl. Run them with
# `julia -O0 --project=. test/folder_kind_test.jl`. They draw a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/URI.jl/FSPath" FSPath
const px = K.px
const FS = K.FS

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))
const notes = joinpath(dir, "notes")
mkpath(joinpath(notes, "old"))
mkpath(joinpath(notes, "attic"))
mkpath(joinpath(dir, "plain"))
write(joinpath(notes, "one.md"), "# One\n")
write(joinpath(notes, "two.md"), "# Two\n")
write(joinpath(notes, "list.csv"), "a,b\n1,2\n")
write(joinpath(dir, "page.md"), "# A page\n")

# A kind of folder, as code from the startup page would make it. Its folders
# are of the kind too, and each of its Markdown files is a note.
@def struct NotesDirectory <: K.AbstractDirectory end
FS.kind(::NotesDirectory, path::FSPath) = NotesDirectory
FS.child(d::NotesDirectory, name::AbstractString) =
  endswith(name, ".md") ? FS.File{:note}(d.path * name, d) : invoke(FS.child, Tuple{K.AbstractDirectory,AbstractString}, d, name)
# How the sidebar shows it
K.entries(e, d::NotesDirectory) = filter(o -> o.path.name != "attic", invoke(K.entries, Tuple{Any,K.AbstractDirectory}, e, d))
K.folder_view(e, d::NotesDirectory) = (list=nothing, bar=K.Box(K.Text("My notes", size=12px)))
const asked = Ref(0)   # how many times a row asked for the icon of a folder of notes
K.entry_icon(::NotesDirectory) = (asked[] += 1; "box")
K.entry_marks(e, d::NotesDirectory) = (K.Box(K.Text("$(count(isfile, K.entries(e, d))) in here", size=11px)),)
K.entry_marks(e, f::FS.File{:note}) = (K.Box(K.Text("a note", size=11px)),)
const clicks = String[]
K.open!(e, d::NotesDirectory; record=true) = (push!(clicks, d.path.name); K.go_folder!(e, string(d.path)))

const e = K.build_editor(joinpath(dir, "page.md"))
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
e.panel || K.toggle_panel!(e)
frames()

"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
side() = texts(K.describe(e.nodes[:sidebar]))
"The item of the folder or file `name` in the sidebar's tree"
item(name) = only(i for i in K.file_tree(e).children if basename(i.firstchild.path) == name)
"The names that the sidebar's tree lists, from the top"
listed() = [basename(i.firstchild.path) for i in K.file_tree(e).children]
"The name of the icon of the folder or file `name` in the sidebar's folder"
icon(name) = K.entry_icon(K.object(e, joinpath(e.folder, name)))

@testset "a folder and a file are objects, which the folder at / made on the way down" begin
  @test listed() == ["notes", "plain", "page.md"] == basename.(e.listed)
  @test K.directory(e) isa FS.Directory && string(K.directory(e).path) == dir
  @test K.object(e, notes) isa FS.Directory && K.object(e, joinpath(dir, "page.md")) isa FS.File{:md}
  @test K.object(e, notes).parent === K.directory(e)
  top(o) = o.parent === nothing ? o : top(o.parent)
  @test top(K.object(e, notes)) == FS.root()
  # one that the sidebar doesn't list has an object too, and what isn't there has none
  @test K.object(e, joinpath(notes, "one.md")) isa FS.File{:md} && K.object(e, joinpath(dir, "nothing.md")) === nothing
  @test e.files == [joinpath(dir, "page.md")]
end

@testset "a folder with no kind shows as it did" begin
  @test icon("notes") == "folder" && icon("plain") == "folder" && icon("page.md") == "file-earmark-text"
  @test !any(t -> occursin("in here", t), side()) && !("My notes" in side())
  @test K.folder_view(e, K.directory(e)) == (list=nothing, bar=nothing) && K.hidden_button(e) != ()
end

@testset "a kind of folder has its own icon and its own words after its name" begin
  FS.kinds[FSPath(notes)] = NotesDirectory
  K.list_files!(e); frames()
  @test K.object(e, notes) isa NotesDirectory
  @test icon("notes") == "box" && icon("plain") == "folder"
  # the row of the folder asks for that icon when it's drawn
  asked[] = 0; frames(1)
  @test asked[] > 0
  # the folder lists what its own `entries` gives: not the attic
  @test "2 in here" ∉ side() && "3 in here" in side()
end

@testset "a click on it does what its `open!` says, and it lists itself its own way" begin
  K.choose!(e, item("notes")); frames()
  @test clicks == ["notes"] && e.folder == notes
  @test K.directory(e) isa NotesDirectory
  @test listed() == ["old", "list.csv", "one.md", "two.md"]
  @test "My notes" in side()
  # a folder in it is of the kind too, because the kind says so
  @test K.object(e, joinpath(notes, "old")) isa NotesDirectory && icon("old") == "box"
  # the kind chose the type of its Markdown files, and a function has a method for that type
  @test K.object(e, joinpath(notes, "one.md")) isa FS.File{:note} && K.object(e, joinpath(notes, "list.csv")) isa FS.File{:csv}
  @test count(==("a note"), side()) == 2
  @test e.files == [joinpath(notes, "one.md"), joinpath(notes, "two.md")]
end

@testset "a click on a file in it shows the file in the page" begin
  K.choose!(e, item("two.md")); frames()
  @test e.buf.path == joinpath(notes, "two.md") && e.folder == notes
  K.choose!(e, item("old")); frames()
  @test clicks == ["notes", "old"] && e.folder == joinpath(notes, "old") && isempty(listed())
end

@testset "the tables still add to a folder with no kind" begin
  K.go_folder!(e, dir); frames()
  K.FOLDER_MARKS[:kind_test] = (o, path) -> basename(path) == "plain" ? (K.Box(K.Text("a plain one", size=11px)),) : ()
  K.FOLDER_LISTS[:kind_test] = o -> o.folder == dir ? (list=nothing, bar=K.Box(K.Text("The top", size=12px))) : nothing
  frames()
  @test "a plain one" in side() && "The top" in side() && "3 in here" in side()
  delete!(K.FOLDER_MARKS, :kind_test); delete!(K.FOLDER_LISTS, :kind_test)
end

@testset "a folder that loses its kind is plain again" begin
  delete!(FS.kinds, FSPath(notes))
  K.list_files!(e); frames()
  @test K.object(e, notes) isa FS.Directory && icon("notes") == "folder" && !any(t -> occursin("in here", t), side())
end
