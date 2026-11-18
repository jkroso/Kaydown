# Tests for what code from the startup page can add to Ladder: the tables that
# Ladder calls at its own times, a command with its key, and an item of the
# Insert menu. See "what code from the startup page adds to" in main.jl. Run
# them with `julia -O0 --project=. test/extend_test.jl`. They add a small
# extension of their own, called `:notes`, and click in a window that isn't on
# the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const notes = joinpath(dir, "notes")
mkpath(joinpath(notes, "old"))
write(joinpath(notes, "one.md"), "---\nkind: note\n---\n\nThe first note.\n")
write(joinpath(notes, "two.md"), "# Two\n")
write(joinpath(dir, "page.md"), "# A page\n\n```ui\nnotes_count()\n```\n")

const e = K.build_editor(joinpath(notes, "one.md"))
const w = Window(e, size=(1000px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end
press(key, mods...) = begin
  foreach(k -> (w.keys |= k), mods)
  onkey(w, KeyPress{key}(0, w)); onkey(w, KeyRelease{key}(0, w))
  foreach(k -> (w.keys ⊻= k), mods)
  frames()
end
middle(r) = (K.num(r[1] + r[3] / 2), K.num(r[2] + r[4] / 2))
"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
bar() = texts(K.describe(e.nodes[:topbar]))
side() = texts(K.describe(e.nodes[:sidebar]))
"True when the page that shows is in the folder of notes"
innotes(e) = startswith(e.buf.path, notes * "/")
"Take the test's extension out of every table"
forget() = foreach(t -> delete!(t, :notes), (K.EACH_FRAME, K.AT_QUIT, K.BAR_PARTS, K.BUTTONS, K.PAGE_TITLES, K.MATTER_TITLES, K.FOLDER_LISTS,
                                             K.FOLDER_MARKS, K.PAGE_NAMES, K.FIELD_KEYS, K.SETTINGS_FOLDERS))

@testset "with nothing added, Ladder is as it was" begin
  forget()
  @test K.bar_parts(e) == () && K.folder_marks(e, notes) == () && K.folder_list(e) == (list=nothing, bar=nothing)
  @test K.page_title(e) === nothing && K.first_answer(K.MATTER_TITLES, e) === nothing
  @test "one.md" in bar() || "one" in bar()
end

@testset "a turn in each frame" begin
  seen = Any[]
  K.EACH_FRAME[:notes] = o -> push!(seen, o)
  frames(3)
  @test length(seen) == 3 && all(o -> o === e, seen)
  # The same name again takes the place of the function that was there
  K.EACH_FRAME[:notes] = o -> nothing
  frames(2)
  @test length(seen) == 3 && haskey(K.EACH_FRAME, :notes)
end

@testset "a button in the top bar, with what it does and says" begin
  done = Ref(0)
  busy = Ref(false)
  K.BUTTONS[:notes] = (run=o -> (done[] += 1), tip=o -> "File the note", off=o -> busy[], strong=true)
  K.BAR_PARTS[:notes] = o -> innotes(o) ? (K.button(o, :notes, "archive"),) : ()
  frames()
  b = e.nodes[:notes]
  @test b isa K.ToolButton && b.rect[3] > 0px && K.tip(b) == "File the note" && !K.off(b)
  click(middle(b.rect))
  @test done[] == 1
  # A page that the function has no buttons for gets none
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test K.bar_parts(e) == ()
  K.open!(e, joinpath(notes, "one.md")); frames()
  @test length(K.bar_parts(e)) == 1
  # While the code says the button is off, it shows that
  busy[] = true
  @test K.off(e.nodes[:notes]) && K.cursor(e.nodes[:notes]) == :arrow
  busy[] = false
end

@testset "the name of the page in the top bar, and of its card" begin
  K.PAGE_TITLES[:notes] = o -> innotes(o) ? "A note of mine" : nothing
  K.MATTER_TITLES[:notes] = o -> innotes(o) ? "NOTE" : nothing
  frames()
  @test K.page_title(e) == "A note of mine" && "A note of mine" in bar()
  card = texts(K.describe(e.nodes[:matter]))
  @test "NOTE" in card && !("FRONTMATTER" in card)
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test K.page_title(e) === nothing && any(t -> startswith(t, "page"), bar())
  K.open!(e, joinpath(notes, "one.md")); frames()
end

@testset "a list for a folder in the sidebar, a line over it, and a mark on a folder's row" begin
  e.panel || K.toggle_panel!(e)
  frames(3)
  @test any(t -> occursin("two", t), side()) && K.hidden_button(e) != ()
  K.FOLDER_LISTS[:notes] = o -> o.folder == notes ? (list=K.Box(K.Text("The notes, listed my way", size=13px)), bar=K.Box(K.Text("2 notes", size=12px))) : nothing
  K.FOLDER_MARKS[:notes] = (o, path) -> basename(path) == "old" ? (K.Box(K.Text("9 old", size=11px)),) : ()
  frames(3)
  @test "The notes, listed my way" in side() && "2 notes" in side() && !any(t -> occursin("two", t), side())
  # The eye that shows hidden files is for a list of files
  @test K.hidden_button(e) == ()
  # A line with no list leaves the tree of the folder's files, where the folder's row has its mark
  K.FOLDER_LISTS[:notes] = o -> o.folder == notes ? (list=nothing, bar=K.Box(K.Text("2 notes", size=12px))) : nothing
  frames(3)
  @test "2 notes" in side() && any(t -> occursin("two", t), side()) && "9 old" in side() && K.hidden_button(e) != ()
  # Another folder is listed as ever
  K.go_folder!(e, dir); frames(3)
  @test !("2 notes" in side()) && any(t -> occursin("page", t), side())
  K.go_folder!(e, notes); frames(3)
end

@testset "a command with a key, in a group of the key bindings page" begin
  # What this test added when it ran before in the same process goes first
  delete!(K.COMMANDS, :note_file); filter!(g -> first(g) != "Notes", K.COMMAND_GROUPS)
  ran = Ref(0)
  n = length(K.COMMANDS)
  K.add_commands!("Notes", [K.Command(:note_file, "File the note", :window, "ctrl+cmd+n", (o, win, _) -> (ran[] += 1))])
  @test length(K.COMMANDS) == n + 1 && first(last(K.COMMAND_GROUPS)) == "Notes" && K.caps(first(K.keys_now(e).of[:note_file])) == "⌃⌘N"
  press(Keys.n, Keys.ctrl, Keys.cmd)
  @test ran[] == 1
  # The same command again takes the place of the one that was there, and its group isn't there twice
  K.add_commands!("Notes", [K.Command(:note_file, "File it", :window, "ctrl+cmd+n", (o, win, _) -> (ran[] += 10))])
  @test length(K.COMMANDS) == n + 1 && count(g -> first(g) == "Notes", K.COMMAND_GROUPS) == 1 && K.COMMANDS[:note_file].title == "File it"
  press(Keys.n, Keys.ctrl, Keys.cmd)
  @test ran[] == 11
end

@testset "an item of the Insert menu" begin
  menu = last(K.PAGE_MENU[findfirst(x -> x isa Pair && first(x) == "Insert", K.PAGE_MENU)])
  was = findfirst(x -> x isa Tuple && x[1] == "Note", K.INSERTS)
  was === nothing || (deleteat!(K.INSERTS, was); deleteat!(menu, was))
  n = length(K.INSERTS)
  K.add_insert!("Note", ["```note", "", "```"], (2, 0), before="Map")
  i = findfirst(x -> x isa Tuple && x[1] == "Note", K.INSERTS)
  @test length(K.INSERTS) == n + 1 && K.INSERTS[i+1][1] == "Map" && menu[i] == "Note" && menu[i+1] == "Map" && length(menu) == length(K.INSERTS)
  # Again, it takes the place of the item that was there
  K.add_insert!("Note", ["```note", "to: ", "```"], (2, 4))
  @test length(K.INSERTS) == n + 1 && K.INSERTS[i][2] == ["```note", "to: ", "```"] && length(menu) == length(K.INSERTS)
end

@testset "names for the code of a window's pages" begin
  K.PAGE_NAMES[:notes] = (m, o) -> Core.eval(m, :(const notes_count = $(() -> K.Text("2 notes in all", size=14px))))
  # A window that's made once the name is added has it
  empty!(K.problems)   # what a live block of a test before this one said, when the tests share a process
  other = K.build_editor(joinpath(dir, "page.md"))
  second = Window(other, size=(900px, 600px))
  foreach(_ -> frame(second), 1:3)
  @test isdefined(K.sandbox(other), :notes_count)
  # The page's live block calls it, and shows what it gives
  @test K.problems == String[]
end

@testset "a key that the code takes while a field has the keyboard" begin
  # A field of the code's own has the keyboard, as a field of a form in a live block has
  field = K.own!(e, K.TextInput())
  K.focus(field)
  took = Any[]
  K.FIELD_KEYS[:notes] = (o, win, key) -> win.focus === field && key == Keys.enter && (push!(took, key); true)
  @test w.focus === field
  press(Keys.enter)
  @test took == [Keys.enter] && e.buf.lines == K.text(e.buf.path)   # and the page's text didn't get the key
  # A key that the code doesn't take goes on as ever
  press(Keys.a)
  @test length(took) == 1
  K.focus(e); frames()
end

@testset "a folder whose pages are pages of the settings" begin
  mine = joinpath(dir, "mine")
  mkpath(mine)
  write(joinpath(mine, "notes-settings.md"), "# Notes\n")
  s = K.build_editor(joinpath(mine, "notes-settings.md"))
  s.settings = true
  @test !K.issettings(s)
  K.SETTINGS_FOLDERS[:notes] = mine
  @test K.issettings(s)
  K.open!(s, joinpath(dir, "page.md"))
  @test !K.issettings(s)
  forget()
end
