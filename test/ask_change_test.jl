# Tests for a change that's asked for, in main.jl: the command Ask For a
# Change takes words, and the next click picks a thing. An agent changes the
# function that draws the thing, and Ladder runs the code that changed. The
# command Keep This Change adds the function at the caret to the startup page.
# Run them with `julia -O0 --project=. test/ask_change_test.jl`. The agent
# here is a small script, so no real agent runs. They click in a window that
# isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
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
write(page, "# A tank\n\n```level\n3\n```\n\nThe end.\n")

# The agent of these tests: it writes the words that it was given to a file, and changes one number of the code
const agent = joinpath(dir, "agent.sh")
write(agent, """
#!/bin/sh
printf '%s' "\$1" > "$dir/asked.txt"
pwd > "$dir/where.txt"
sed -i '' 's/height(30px)/height(12px)/' "$source"
echo "I read the file."
echo
echo "The bar is 12 pixels tall now."
""")
const broken = joinpath(dir, "broken.sh")
write(broken, """
#!/bin/sh
sed -i '' 's/^wide(l::Level) = 200px/wide(l::Level) = 200px; nothing_of_that_name + 1/' "$source"
echo "Done."
""")
const stopped = joinpath(dir, "stopped.sh")
write(stopped, "#!/bin/sh\necho 'No network.'\nexit 3\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
node() = e.nodes[(:block, "level", page, 1)].value
"Click the bar"
click() = begin
  r = rect(node())
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w, 1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end
picker() = window_tool(w)::K.CodePicker
"Draw frames until the agent has ended, for a few seconds at most"
finish() = begin
  from = time()
  while picker().asked !== nothing && picker().asked.ended == 0 && time() - from < 20
    frames(w, 1)
    sleep(0.05)
  end
  frames()
end
"Ask for a change with the script `script` as the agent, click the bar, and wait for the agent"
ask(script, words) = begin
  K.AGENT_COMMAND[] = `sh $script`
  K.ask_for_change!(e, words)
  click()
  finish()
  picker().asked
end

@testset "what the agent said, and the parts of a file's code" begin
  @test K.agent_said("I read the file.\n\nThe bar is\n12 pixels tall.\n\n") == "The bar is 12 pixels tall."
  @test K.agent_said("  \n") == ""
  lines = ["\"Words\"", "f(x) = 1", "", "# A comment", "g(x) = begin", "  2", "end", "", ""]
  @test K.part_texts(lines) == [(1, "\"Words\"\nf(x) = 1\n\n# A comment"), (5, "g(x) = begin\n  2\nend")]
  @test K.part_lines(lines, 6) == (5, 7) && K.part_lines(lines, 2) == (1, 4)
  prompt = K.change_prompt("/code/bar.jl", 12, "describe(b::Bar) =", :Bar, "make it red")
  @test occursin("/code/bar.jl, at line 12", prompt) && occursin("The user's words: make it red", prompt) && occursin("only files in /code", prompt)
end

@testset "the command takes words, and the next click picks the thing" begin
  @test rect(node()).height == 30px
  @test_throws ErrorException K.ask_for_change!(e, "  ")
  K.AGENT_COMMAND[] = `sh $agent`
  K.ask_for_change!(e, "make the bar thinner")
  @test picker().picking && picker().asking == "make the bar thinner"
  click()
  a = picker().asked
  # The click went to the picker, and the agent started for that thing
  @test !picker().picking && isempty(picker().asking) && nameof(typeof(a.node)) == :Level && a.file == realpath(source) && a.words == "make the bar thinner"
  finish()
  # The agent got the words and the function's place, and ran in the folder of the file
  asked = read(joinpath(dir, "asked.txt"), String)
  at = findfirst(startswith("describe(l::Level)"), a.before)
  @test occursin("The user's words: make the bar thinner", asked) && occursin("$(realpath(source)), at line $at", asked) && occursin("a Level", asked)
  @test realpath(strip(read(joinpath(dir, "where.txt"), String))) == realpath(dir)
  # Ladder ran the code that changed, so the bar is drawn the new way, and the label has what the agent said
  @test rect(node()).height == 12px
  @test a.ended > 0 && !a.failed && a.said == "The bar is 12 pixels tall now."
  # The label goes after a few seconds
  a.ended -= 9
  frames()
  @test picker().asked === nothing
end

@testset "an agent that stops, and code that doesn't run" begin
  a = ask(stopped, "make it green")
  @test a.failed && a.said == "The agent stopped. No network."
  # A second change can't be asked for while the agent is at work
  K.AGENT_COMMAND[] = `sh -c "sleep 5"`
  K.ask_for_change!(e, "make it red")
  click()
  @test picker().asked.ended == 0
  @test_throws ErrorException K.ask_for_change!(e, "and blue")
  kill(picker().asked.process)
  finish()
  picker().asked = nothing
  # Esc leaves the command before the click
  K.ask_for_change!(e, "make it red")
  onkey(w, KeyPress{Keys.escape}(0, w))
  @test !picker().picking && isempty(picker().asking)
  # Code that fails as it loads: the label says so. The file's block has nothing to show until the code is put right.
  a = ask(broken, "make it wider")
  @test a.failed && startswith(a.said, "The new code doesn't run.") && occursin("nothing_of_that_name", a.said)
  picker().asked = nothing
  K.AGENT_COMMAND[] = nothing
end

@testset "only the code that changed runs again" begin
  mod = K.loaded_module(realpath(source))
  before = K.text(source)
  write(source, replace(read(source, String), "wide(l::Level) = 200px; nothing_of_that_name + 1" => "wide(l::Level) = 80px"))
  @test K.reload_changed!(mod, realpath(source), before) == (1, "")
  frames(w, 3)
  @test rect(node()).width == 80px
  @test K.reload_changed!(mod, realpath(source), K.text(source)) == (0, "")
end

@testset "Keep This Change adds the function to the startup page" begin
  @test K.loaded_name(realpath(source)) == "ladder-ask-change-test/level.jl"
  @test K.loaded("ladder-ask-change-test/level.jl") === K.loaded_module(realpath(source))
  @test_throws ErrorException K.loaded("no-such-file.jl")
  shown = K.build_editor(source)
  win = Window(shown, size=(700px, 500px))
  frames(win, 3)
  b = shown.buf
  i = findfirst(startswith("wide(l::Level)"), b.lines)
  b.caret = b.anchor = (i, 3)
  # Only a file that the app writes again when it starts has a change to keep
  @test_throws ErrorException K.keep_change!(shown)
  K.SOURCE_FILES["/built/level.jl"] = realpath(source)
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 50px")
  K.keep_change!(shown)
  frames(w, 3)
  # The function is as it's kept, in the app that runs
  @test rect(node()).width == 50px
  kept = read(K.startup_page(), String)
  @test occursin("## Kept: `wide(l::Level)` of ladder-ask-change-test/level.jl\n\n```julia\n@eval Ladder.loaded(\"ladder-ask-change-test/level.jl\") begin\n\"How wide the bar of a tank is\"\nwide(l::Level) = 50px\nend\n```\n", kept)
  # A function that was kept before is kept as it is now, in the same place
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 70px")
  K.keep_change!(shown)
  kept = read(K.startup_page(), String)
  @test count("## Kept:", kept) == 1 && occursin("wide(l::Level) = 70px\nend", kept) && !occursin("50px", kept)
  # The startup page's code gives the function to the module of its file
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 90px")
  K.run_code(shown, b.lines[i])
  frames(w, 3)
  @test rect(node()).width == 90px
  K.run_startup!()
  frames(w, 3)
  @test rect(node()).width == 70px
  # The caret on no function
  b.caret = b.anchor = (length(b.lines), 0)
  K.edit!(b, b.caret, b.caret, "\n\n# Only words\n")
  b.caret = b.anchor = (length(b.lines) - 1, 0)
  delete!(K.SOURCE_FILES, "/built/level.jl")
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
