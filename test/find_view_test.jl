# Tests for the `find` block of main.jl: the lines that match in the pages of
# a folder. Run them with `julia -O0 --project=. test/find_view_test.jl`. They
# click in a window that isn't on the screen. Set `KAYDOWN_SHOTS` to a folder,
# and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "today.md")
const kitchen = joinpath(dir, "jobs", "kitchen.md")
const bath = joinpath(dir, "jobs", "bath.md")
mkpath(joinpath(dir, "jobs"))
mkpath(joinpath(dir, ".hidden"))
write(joinpath(dir, ".hidden", "secret.md"), "- [ ] Not this one\n")
write(joinpath(dir, "notes.txt"), "- [ ] Not a page\n")
write(kitchen, "# Kitchen\n\n- [ ] Call the plumber\n- [x] Order the bench\n- [ ] Choose the tiles\n")
write(bath, "# Bath\n\nThe plumber comes on Monday.\n\n- [ ] Seal the floor\n")
write(page, """
# Today

- [ ] Ring Sam

```find
```

```find
plumber
```

```find
what: to-do items
in: nowhere
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1100px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
list(n) = e.nodes[(:block, K.FIND, page, n)]
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
found(n) = [(relpath(m.path, dir), m.text, m.kind) for m in K.found!(list(n)).matches]
row(n, i) = list(n).parts[(:row, i)]
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
block(n) = (s = K.block_lines(e.buf, K.FIND, n); e.buf.lines[s[1]+1:s[2]-1])
choice(n, key) = list(n).parts[key]   # the button that opens the menu of kinds, or the one of folders
menu() = (i = findfirst(p -> p.key == :menu, popups(w)); i === nothing ? nothing : popups(w)[i].content)
"Click the button `c`, and choose the item `name` of the menu that it opens"
choose(c, name) = begin
  click(middle(rect(c)))
  m = menu()
  m.onselect(findfirst(==(name), m.items)); K.hide_menu!(w); frames()
end

@testset "the list has the lines of every page of the folder" begin
  # The folder's own pages come first, then those of each folder in it
  @test found(1) == [("today.md", "Ring Sam", :todo), ("jobs/bath.md", "Seal the floor", :todo),
                     ("jobs/kitchen.md", "Call the plumber", :todo), ("jobs/kitchen.md", "Choose the tiles", :todo)]
  @test found(2) == [("jobs/bath.md", "The plumber comes on Monday.", :line), ("jobs/kitchen.md", "Call the plumber", :todo)]
  @test isempty(found(3)) && occursin("nowhere", K.found!(list(3)).problem)
  # The name of each page is over its lines
  @test [list(1).parts[(:page, k)].path for k in 1:3] == [page, bath, kitchen]
  @test rect(list(1).parts[(:page, 3)]).top < rect(row(1, 3)).top < rect(row(1, 4)).top
  @test rect(list(1).parts[(:page, 2)]).top < rect(row(1, 2)).top < rect(list(1).parts[(:page, 3)]).top
  @test any(en -> en.title == "Find", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Find", K.INSERTS)
  shot("find.png")
end

@testset "a click on a box ticks the item in its own page" begin
  # A page that isn't open is changed in its file
  click(middle(rect(row(1, 3).box)))
  @test readlines(kitchen)[3] == "- [x] Call the plumber"
  # The item stays in the list, ticked, and a second click takes the tick away
  @test found(1)[3] == ("jobs/kitchen.md", "Call the plumber", :done) && length(found(1)) == 4
  click(middle(rect(row(1, 3).box)))
  @test readlines(kitchen)[3] == "- [ ] Call the plumber" && found(1)[3][3] == :todo && isempty(list(1).kept)
  # The page that shows is changed as a click on its own box changes it: nothing is written, and ⌘Z takes it back
  click(middle(rect(row(1, 1).box)))
  @test e.buf.lines[3] == "- [x] Ring Sam" && K.dirty(e.buf) && readlines(page)[3] == "- [ ] Ring Sam"
  @test found(1)[1] == ("today.md", "Ring Sam", :done)
  K.undo!(e.buf); frames()
  @test e.buf.lines[3] == "- [ ] Ring Sam" && found(1)[1][3] == :todo
end

@testset "a file that changes on the disk" begin
  write(bath, "# Bath\n\n- [ ] Seal the floor\n- [ ] Hang the door\n")
  # The list looks at the folder again after a few seconds. The test doesn't wait for them.
  empty!(K.FOLDER_PAGES); frames()
  @test found(1)[2:3] == [("jobs/bath.md", "Seal the floor", :todo), ("jobs/bath.md", "Hang the door", :todo)]
  html = K.page_html(e)
  @test occursin("<strong>jobs/kitchen</strong>", html) && occursin("<li>☐ Hang the door</li>", html)
end

@testset "a click on a line opens its page at that line" begin
  click(middle(rect(row(1, 5))) .+ (60, 0))
  @test e.buf.path == kitchen && e.buf.caret[1] == 5 && w.focus === e
  # A page that's open, with nothing to save, is saved when a list ticks one of its items
  K.open!(e, page); frames()
  @test found(1)[5] == ("jobs/kitchen.md", "Choose the tiles", :todo)
  click(middle(rect(row(1, 5).box)))
  @test readlines(kitchen)[5] == "- [x] Choose the tiles" && !K.dirty(e.buffers[kitchen])
  click(middle(rect(list(1).parts[(:page, 2)])))
  @test e.buf.path == bath
end

@testset "the top of the list says what it lists, and counts only what matches" begin
  K.open!(e, page); frames()
  # The page was left, so the item that was ticked in the list before has gone from it
  @test all(m -> m[3] == :todo, found(1)) && isempty(list(1).kept)
  n = length(found(1))
  @test K.search_words(list(1)) == "$n to-do items in 3 pages of this folder"
  @test K.search_words(list(2)) == "1 line with “plumber” in 1 page of this folder"
  @test K.search_words(list(3)) == "No to-do items in the folder nowhere"
  # An item that's ticked here stays in the list, and the top no longer counts it
  click(middle(rect(row(1, 2).box)))
  @test found(1)[2][3] == :done && length(found(1)) == n
  @test K.search_words(list(1)) == "$(n - 1) to-do items in 3 pages of this folder"
  # It goes when another page shows
  K.open!(e, kitchen); K.open!(e, page); frames()
  @test length(found(1)) == n - 1 && all(m -> m[3] == :todo, found(1))
end

@testset "the top of the list changes what the block asks for" begin
  v = list(1)
  input = K.search_input(v)
  @test isempty(block(1)) && [m[2] for m in found(1)] == ["Ring Sam", "Hang the door", "Call the plumber"]
  @test K.choice_words(choice(1, :kind)) == "To-do items" && K.choice_words(choice(2, :kind)) == "Lines"
  # A click in the field gives it the keyboard. What's typed goes into the block, and the list is still of to-do items.
  click(middle(rect(input)))
  @test w.focus === input
  typed("plum")
  @test block(1) == ["what: to-do items", "with: plum"] && found(1) == [("jobs/kitchen.md", "Call the plumber", :todo)]
  @test K.search_words(v) == "1 to-do item with “plum” in 1 page of this folder" && K.choice_words(choice(1, :kind)) == "To-do items"
  # A space after a word stays in the field while the next word is typed
  typed(" ")
  @test input.text == "plum " && block(1) == ["what: to-do items", "with: plum"]
  typed("call")
  @test block(1) == ["what: to-do items", "with: plum call"] && length(found(1)) == 1
  shot("find-typed.png")
  # Return gives the keyboard back to the page
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  @test w.focus === e && block(1) == ["what: to-do items", "with: plum call"]
  # A click on the kind of line opens a menu of the kinds, under the button
  click(middle(rect(choice(1, :kind))))
  @test menu() !== nothing && menu().items == ["To-do items", "Done items", "Headings", "Lines"]
  @test any(p -> p.key == :menu && p.anchor[2] > rect(choice(1, :kind)).top, popups(w))
  K.hide_menu!(w); frames()
  @test block(1) == ["what: to-do items", "with: plum call"]
  choose(choice(1, :kind), "Headings")
  @test block(1) == ["what: headings", "with: plum call"] && isempty(found(1)) && K.choice_words(choice(1, :kind)) == "Headings"
  @test K.search_words(v) == "No headings with “plum call” in this folder"
  choose(choice(1, :kind), "Lines")
  @test block(1) == ["what: lines", "with: plum call"] && found(1) == [("jobs/kitchen.md", "Call the plumber", :todo)]
  # ⌘Z takes back the button, then the words, and the field follows
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test block(1) == ["what: to-do items", "with: plum call"] && input.text == "plum call"
  K.undo!(e.buf); frames()
  @test isempty(block(1)) && input.text == "" && length(found(1)) == 3
  # The folders beside the page are the ones to choose from, with the one that a block names
  @test K.search_folders(v) == ["jobs"] && K.search_folders(list(3)) == ["nowhere", "jobs"]
  @test K.choice_words(choice(1, :folder)) == "This folder" && K.choice_words(choice(3, :folder)) == "nowhere"
  click(middle(rect(choice(1, :folder))))
  @test menu().items == ["This folder", "jobs"]
  K.hide_menu!(w); frames()
  choose(choice(1, :folder), "jobs")
  @test block(1) == ["in: jobs"] && [m[1] for m in found(1)] == ["jobs/bath.md", "jobs/kitchen.md"] && K.choice_words(choice(1, :folder)) == "jobs"
  @test K.search_words(v) == "2 to-do items in 2 pages of the folder jobs"
  shot("find-bar.png")
  choose(choice(1, :folder), "This folder")
  @test isempty(block(1)) && length(found(1)) == 3
  # The other lists of the page stay as they were
  @test block(2) == ["plumber"] && block(3) == ["what: to-do items", "in: nowhere"]
end
