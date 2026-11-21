# Tests for a change that's asked for, in main.jl: the command Ask For Change
# takes what to change, a block of Julia code or a part of the window, and
# words. It starts with what the caret is on, and a click chooses another. An
# agent changes the code, and Ladder runs the code that changed. The command Keep This Change adds the function at the caret to the
# startup page. Run them with `julia -O0 --project=. test/ask_change_test.jl`.
# The agent here is a small script, so no real agent runs. They draw windows
# that aren't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect window_tool
@use GeometryBasics: Vec2
const px = K.px

# The folder has the same name each time, so that Kip compiles its file once
const dir = joinpath(tempdir(), "ladder-ask-change-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
K.STARTUP_FOLDER[] = dir
const page = joinpath(dir, "tank.md")
const source = joinpath(dir, "level.jl")

# A kind of block with a node of its own
write(source, """
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe

"How full a tank is"
@def mutable struct Level <: SemanticUI
  level::Int = 0
end

level(lines) = Level(level=something(tryparse(Int, strip(get(lines, 1, ""))), 0))

"How wide the bar of a tank is"
wide(l::Level) = 200px

"A bar as wide as the tank is full"
describe(l::Level) =
  Box(width(wide(l)), height(30px), background("steelblue"))
""")
write(page, "# A tank\n\n```level\n3\n```\n\nThe end.\n\n```julia\nx = 1\n```\n")

"An agent of these tests: it writes the words that it was given to a file, notes its folder, and runs `change` on the code"
agent(name, change, said...) = begin
  path = joinpath(dir, name)
  write(path, "#!/bin/sh\nprintf '%s' \"\$1\" > \"$dir/asked.txt\"\npwd > \"$dir/where.txt\"\n$change\n" * join(("echo \"$s\"" for s in said), "\n") * "\n")
  path
end
const wider = agent("wider.sh", "sed -i '' 's/^wide(l::Level) = 200px/wide(l::Level) = 120px/' \"$source\"", "I read the file.", "", "The bar is 120 pixels wide now.")
const thinner = agent("thinner.sh", "sed -i '' 's/height(30px)/height(12px)/' \"$source\"", "The bar is 12 pixels tall now.")
const broken = agent("broken.sh", "sed -i '' 's/^wide(l::Level) = \\([0-9]*px\\)\$/wide(l::Level) = \\1; nothing_of_that_name + 1/' \"$source\"", "Done.")
const quiet = agent("quiet.sh", "true", "I looked, and it's as you say.")
const stopped = joinpath(dir, "stopped.sh")
write(stopped, "#!/bin/sh\necho 'No network.'\nexit 3\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
node() = e.nodes[(:block, "level", page, 1)].value
picker(win=w) = window_tool(win)::K.CodePicker

# The file of code, in a window of its own
const code = K.build_editor(source)
const cw = Window(code, size=(700px, 800px))
frames(cw, 3)
"What Ask For Change offers in the window of `o`, with the caret at `at`"
offered(o, at) = (o.buf.caret = o.buf.anchor = at; frames(K.window_of(o), 2); K.choices_for(K.ToChange, o))

"Draw frames of the window `win` until the agent has ended, for a few seconds at most"
finish(win=w) = begin
  from = time()
  while picker(win).asked !== nothing && picker(win).asked.ended == 0 && time() - from < 20
    frames(win, 1)
    sleep(0.05)
  end
  frames(win)
end
"Ask for a change to `c` with the script `script` as the agent, and wait for the agent"
ask(script, c, words; win=w) = begin
  K.AGENT_COMMAND[] = `sh $script`
  K.ask_for_change!(win.ui, c, words)
  finish(win)
  picker(win).asked
end
asked() = read(joinpath(dir, "asked.txt"), String)

"Press the key `k` in window `win` with the keys `held` down"
press(win, k, held...) = begin
  foreach(h -> win.keys |= h, held)
  onkey(win, KeyPress{k}(0, win))
  foreach(h -> win.keys ⊻= h, held)
  haskey(win.ui.nodes, :palette) && (win.ui.nodes[:palette].moved = 0.0)
  frames(win)
end
typed(win, s) = (foreach(c -> ontype(win, Typed(c, win)), s); frames(win))
"Click the window `win` at `(x, y)`"
click(win, x, y) = begin
  win.mouse = typeof(win.mouse)(x, y)
  onmouse(win, MouseMove(Vec2{px}(x, y), win))
  frames(win, 1)
  win.keys |= Keys.mouse_left
  onkey(win, KeyPress{Keys.mouse_left}(0, win))
  win.keys ⊻= Keys.mouse_left
  onkey(win, KeyRelease{Keys.mouse_left}(0, win))
  frames(win)
end
"The middle of line `i` of the page of `o`, a little in from its left"
on_line(o, i) = (it = K.item(o, i); (o.origin[1] + 30px, o.origin[2] + it.top + it.tall / 2))
middle(r) = (r.left + r.width / 2, r.top + r.height / 2)

@testset "what the agent said, and the parts of a file's code" begin
  @test K.agent_said("I read the file.\n\nThe bar is\n12 pixels tall.\n\n") == "The bar is 12 pixels tall."
  @test K.agent_said("  \n") == ""
  lines = ["\"Words\"", "f(x) = 1", "", "# A comment", "g(x) = begin", "  2", "end", "", ""]
  @test K.part_texts(lines) == [(1, "\"Words\"\nf(x) = 1\n\n# A comment"), (5, "g(x) = begin\n  2\nend")]
  @test K.part_lines(lines, 6) == (5, 7) && K.part_lines(lines, 2) == (1, 4)
  # The first line of code after documentation and comments
  @test K.code_start(lines, 1) == 2 && K.code_start(lines, 3) == 5
  @test K.code_start(["\"\"\"", "Words", "\"\"\"", "f(x) = 1"], 1) == 4 && K.code_start(["\"\"\"Words", "more\"\"\"", "f(x) = 1"], 1) == 3
  @test K.code_start(["\"\"\"Words\"\"\"", "f(x) = 1"], 1) == 2 && K.code_start(["# only words", ""], 1) == 1
end

@testset "a file of Julia code offers its blocks, the one that the caret is in first" begin
  offers = offered(code, (14, 3))
  blocks = filter(c -> c.node === nothing, offers)
  mod = K.loaded_module(realpath(source))
  # Each piece of code at the top of the file, with its documentation, and none of the lines that only load code
  @test [(c.words, c.note, c.first, c.last) for c in blocks] == [
    ("wide(l::Level)", "function · line 14", 13, 14), ("Level", "mutable struct · line 7", 6, 9),
    ("level(lines)", "function · line 11", 11, 11), ("describe(l::Level)", "function · line 17", 16, 18)]
  @test all(c -> c.file == realpath(source) && c.mod === mod, blocks)
  # The block that the caret is in comes first, then the parts of the window in focus, then the other blocks
  @test first(offers) === first(blocks) && offers[2].node !== nothing && last(offers) === last(blocks)
  # On a line of the code's documentation, the caret is in that block
  @test first(offered(code, (16, 0))).words == "describe(l::Level)"
  # What the agent is told
  prompt = K.change_prompt(blocks[1], "make it wider")
  @test occursin("a block of the file's Julia code", prompt) && occursin("$(realpath(source)), lines 13 to 14. It starts:\n\n    wide(l::Level) = 200px", prompt)
  @test occursin("The user's words: make it wider", prompt) && occursin("only files in $(realpath(dir))", prompt)
end

@testset "a page offers the thing that a block shows, which its file draws" begin
  first_one = first(offered(e, (3, 0)))
  @test first_one.node === node() && first_one.words == "Level" && first_one.note == "drawn at level.jl:17"
  @test (first_one.file, first_one.first, first_one.last) == (realpath(source), 16, 18)
  prompt = K.change_prompt(first_one, "make it red")
  @test occursin("a part of its window, a Level. The function that draws that part", prompt) && occursin("lines 16 to 18", prompt)
  # Then the block itself and the page, which Ladder's own code draws
  @test any(c -> c.node isa K.FileBlock, offered(e, (3, 0))) && !any(c -> c.node === node(), offered(e, (7, 0)))
  # A `julia` code block of the page is a block to change, with no code that runs after the change
  block = first(offered(e, (10, 2)))
  @test (block.words, block.note, block.first, block.last, block.node, block.mod) == ("x = 1", "julia block · line 10", 10, 10, nothing, nothing)
  @test occursin("a block of Julia code on a page of Markdown", K.change_prompt(block, "add one")) && block in offered(e, (7, 0))
end

@testset "the node starts as what the caret is on, and a click chooses another" begin
  K.focus(e)
  e.buf.caret = e.buf.anchor = (3, 0)
  frames(w)
  press(w, Keys.p, Keys.cmd, Keys.shft)
  typed(w, "ask for change")
  press(w, Keys.enter)
  p = K.palette(e)
  said() = K.chip_value(p, K.palette_chips(p), 1)
  # What the caret was on is the node, so the keyboard is in the words
  @test said().node === node() && p.at == 2 && K.click_chip(e, p) == 1
  # A click on the page's `julia` block chooses it, and the keyboard stays in the words
  click(w, on_line(e, 10)...)
  @test said().words == "x = 1" && p.at == 2 && e.popup == :commands && e.buf.caret == (3, 0)
  # A click on the bar chooses the thing that the block shows
  click(w, middle(rect(node()))...)
  @test said().node === node() && p.at == 2
  # A click on the palette's own bar isn't a choice
  @test K.on_palette(p, K.num(w.size[1]) / 2, K.num(w.size[2]) - 30)
  press(w, Keys.escape)
  press(w, Keys.escape)
  @test e.popup == :none && K.click_chip(e, p) === nothing
end

@testset "the palette asks for the block and the words, and the agent changes the block" begin
  code.buf.caret = code.buf.anchor = (14, 3)
  K.AGENT_COMMAND[] = `sh $wider`
  K.focus(code)
  press(cw, Keys.p, Keys.cmd, Keys.shft)
  typed(cw, "ask for change")
  press(cw, Keys.enter)
  p = K.palette(code)
  chips = K.palette_chips(p)
  @test p.command.name == :ask_for_change && [K.chip_name(c) for c in chips] == ["Node", "Request"] && K.chip_kind(code, chips[1]) == :search
  # The node is the block that the caret is in, so the keyboard is in the words
  @test K.chip_value(p, chips, 1).words == "wide(l::Level)" && p.at == 2
  # A click on another block of the file chooses it, and a click on the first chooses it again
  @test K.num(on_line(code, 17)[2]) < K.palette(code).plan.band.y
  click(cw, on_line(code, 17)...)
  @test K.chip_value(p, chips, 1).words == "describe(l::Level)" && p.at == 2
  click(cw, on_line(code, 14)...)
  @test K.chip_value(p, chips, 1).words == "wide(l::Level)" && code.buf.caret == (14, 3)
  typed(cw, "make the bar wider")
  press(cw, Keys.enter)
  @test p.at == 3
  press(cw, Keys.enter)
  @test code.popup == :none
  a = picker(cw).asked
  @test a !== nothing && a.words == "make the bar wider" && a.place.first == 13
  # A line goes round the block while the agent works
  @test K.asked_rect(code, a.place) !== nothing
  finish(cw)
  # The agent got the words and the block's place, and ran in the folder of the file
  @test occursin("The user's words: make the bar wider", asked()) && occursin("lines 13 to 14", asked())
  @test realpath(strip(read(joinpath(dir, "where.txt"), String))) == realpath(dir)
  # The window shows the file as the agent left it, Ladder ran the code that changed, and the label has what the agent said
  @test "wide(l::Level) = 120px" in code.buf.lines && !K.dirty(code.buf)
  frames(w, 3)
  @test rect(node()).width == 120px
  @test a.ended > 0 && !a.failed && a.said == "The bar is 120 pixels wide now."
  # The label goes after a few seconds
  a.ended -= 9
  frames(cw)
  @test picker(cw).asked === nothing
end

@testset "a change to a part of the window" begin
  @test rect(node()).height == 30px
  a = ask(thinner, first(offered(e, (3, 0))), "make the bar thinner")
  @test occursin("a Level", asked()) && rect(node()).height == 12px
  @test !a.failed && a.said == "The bar is 12 pixels tall now."
  picker().asked = nothing
  # Words with nothing in them ask for nothing
  @test_throws ErrorException K.ask_for_change!(e, first(offered(e, (3, 0))), "  ")
end

@testset "an agent that stops, changes nothing, or leaves code that doesn't run" begin
  level = first(offered(e, (3, 0)))
  a = ask(stopped, level, "make it green")
  @test a.failed && a.said == "The agent stopped. No network."
  a = ask(quiet, level, "is it blue?")
  @test !a.failed && a.said == "Nothing changed. I looked, and it's as you say."
  # A second change can't be asked for while the agent is at work
  K.AGENT_COMMAND[] = `sh -c "sleep 5"`
  K.ask_for_change!(e, level, "make it red")
  @test picker().asked.ended == 0
  @test_throws ErrorException K.ask_for_change!(e, level, "and blue")
  kill(picker().asked.process)
  finish()
  picker().asked = nothing
  # Code that fails as it loads: the label says so. The file's block has nothing to show until the code is put right.
  a = ask(broken, level, "make it wider")
  @test a.failed && startswith(a.said, "The new code doesn't run.") && occursin("nothing_of_that_name", a.said)
  picker().asked = nothing
end

@testset "only the code that changed runs again" begin
  mod = K.loaded_module(realpath(source))
  before = K.text(source)
  write(source, replace(read(source, String), r"wide\(l::Level\) = \d+px; nothing_of_that_name \+ 1" => "wide(l::Level) = 80px"))
  @test K.reload_changed!(mod, realpath(source), before) == (1, "")
  frames(w, 3)
  @test rect(node()).width == 80px
  @test K.reload_changed!(mod, realpath(source), K.text(source)) == (0, "")
end

@testset "a file whose code Ladder never ran changes, and nothing runs" begin
  notes = joinpath(dir, "notes.jl")
  write(notes, "\"Twice a number\"\ntwice(x) = 2x\n")
  shown = K.build_editor(notes)
  win = Window(shown, size=(600px, 400px))
  frames(win, 3)
  c = first(offered(shown, (2, 3)))
  @test c.words == "twice(x)" && c.mod === nothing
  a = ask(agent("triple.sh", "sed -i '' 's/2x/3x/' \"$notes\"", "It's three times now."), c, "make it three times"; win)
  @test !a.failed && a.said == "It's three times now." && "twice(x) = 3x" in shown.buf.lines
end

@testset "Keep This Change adds the function to the startup page" begin
  @test K.loaded_name(realpath(source)) == "ladder-ask-change-test/level.jl"
  @test K.loaded("ladder-ask-change-test/level.jl") === K.loaded_module(realpath(source))
  @test_throws ErrorException K.loaded("no-such-file.jl")
  b = code.buf
  frames(cw, 3)
  i = findfirst(startswith("wide(l::Level)"), b.lines)
  b.caret = b.anchor = (i, 3)
  # Only a file that the app writes again when it starts has a change to keep
  @test_throws ErrorException K.keep_change!(code)
  K.SOURCE_FILES["/built/level.jl"] = realpath(source)
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 50px")
  K.keep_change!(code)
  frames(w, 3)
  # The function is as it's kept, in the app that runs
  @test rect(node()).width == 50px
  kept = read(K.startup_page(), String)
  @test occursin("## Kept: `wide(l::Level)` of ladder-ask-change-test/level.jl\n\n```julia\n@eval Ladder.loaded(\"ladder-ask-change-test/level.jl\") begin\n\"How wide the bar of a tank is\"\nwide(l::Level) = 50px\nend\n```\n", kept)
  # A function that was kept before is kept as it is now, in the same place
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 70px")
  K.keep_change!(code)
  kept = read(K.startup_page(), String)
  @test count("## Kept:", kept) == 1 && occursin("wide(l::Level) = 70px\nend", kept) && !occursin("50px", kept)
  # The startup page's code gives the function to the module of its file
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 90px")
  K.run_code(code, b.lines[i])
  frames(w, 3)
  @test rect(node()).width == 90px
  K.run_startup!()
  frames(w, 3)
  @test rect(node()).width == 70px
  delete!(K.SOURCE_FILES, "/built/level.jl")
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
