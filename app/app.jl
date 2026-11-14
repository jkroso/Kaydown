# The entry point for the Kaydown app. build.jl compiles it with JuliaC.
#
# The code at the top level runs once, while the app is being built. It loads
# UI.jl and Kaydown, reads the icons the app uses, and types into a document
# off screen so that code is compiled ahead of time. `main` runs each time the
# app opens.
#
# The app holds a copy of its welcome pages and of the source of each file it
# loaded. When it opens it writes them into its folder in ~/Library/Application
# Support, so the pages and their live blocks work on a Mac without the source.

include("start.jl")

@use ".." build_editor open_editor WELCOME restyle! problems pages_dir SIDEBAR_ICONS FILE_ICONS todo_at inbox Agent INSERTS
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/abstract" focus
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" load_icon
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use GeometryBasics: Vec2
# What the live blocks of the example pages load. A file that's loaded now is
# in the app. The app can't load a file that it hasn't seen.
@use "github.com/jkroso/UI.jl/Interface/Semantic" => Semantic
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => ListTree
@use "../pages/widgets" => widgets

building && start_packages()

# Icons are read from UI.jl's Icons folder the first time they're drawn. Reading
# them now keeps them in the app, so it doesn't need that folder.
foreach(load_icon, ["check", "chevron-down", "chevron-right", "chevron-up", "copy", "file-earmark", "file-earmark-text", "folder", "highlighter",
                    "layout-sidebar", "pause-fill", "play-fill", "record-fill", "search", "stop-fill", "text-center", "text-left",
                    "text-paragraph", "text-right", "x-lg", SIDEBAR_ICONS..., FILE_ICONS...])

# The welcome page's text, to type into while the app warms up
const page = read(WELCOME, String)

# --- what the app needs on a Mac without the source ----------------------------
#
# A live block names the code it uses by path, like "github.com/jkroso/UI.jl/Interface/Semantic"
# or "./widgets.jl". Kip turns the path into a file and gives back the module it
# loaded from that file. The app has the modules, but the files are on the Mac
# that built it. So the app keeps the text of each file, writes the files out
# when it opens, and tells Kip which module goes with each one.

const PAGES = dirname(WELCOME)
"The text of each of the app's own pages, by file name. The model, the video and the recording that the pages show are here too, as the bytes of their files."
const pages = Dict(name => read(joinpath(PAGES, name), String)
                   for name in ("welcome.md", "components.md", "settings.md", "widgets.jl", "knot.stl", "knot.mp4", "hello.m4a"))

"The `user/repo/file` that a file Kip got from GitHub has there, or nothing for any other file"
place(path) = begin
  if startswith(path, Kip.refs * "/")
    # Kip keeps a copy of each commit at refs/user/repo/commit
    user, repo, _, rest... = splitpath(relpath(path, Kip.refs))
    return joinpath(user, repo, rest...)
  end
  # A repo that's linked to a folder on this Mac is used from that folder
  for user in readdir(Kip.repos), repo in readdir(joinpath(Kip.repos, user))
    dir = joinpath(Kip.repos, user, repo)
    ispath(dir) || continue
    dir = realpath(dir)
    startswith(path, dir * "/") && return joinpath(user, repo, relpath(path, dir))
  end
  nothing
end

"Each file Kip loaded from a GitHub repo: where it is on this Mac, its place in the repo and its text"
const sources = [(path, place(path), read(path, String)) for path in keys(Kip.modules)
                 if isabspath(path) && isfile(path) && place(path) !== nothing]
"The registered packages that were loaded by a GitHub path, as `user/repo`"
const packages = [joinpath(m[1], m[2]) for m in (match(r"^github\.com/([^/]+)/([^/@]+)", k) for k in keys(Kip.modules)) if m !== nothing]
const widgets_file = realpath(joinpath(PAGES, "widgets.jl"))

"Kaydown's folder for its own files"
support() = joinpath(homedir(), "Library", "Application Support", "Kaydown")

"Write `text` to `file` unless it holds that already"
put(file, text) = (isfile(file) && read(file, String) == text) || (mkpath(dirname(file)); write(file, text))

"""
Write the pages and the source files into `dir`, and tell Kip to look there.
Returns the path of the welcome page. A page you changed is kept until a newer
version of the app has a page that's different from the one it wrote.
"""
unpack(dir) = begin
  repos = joinpath(dir, "source")
  for (old, at, text) in sources
    file = joinpath(repos, at)
    put(file, text)
    Kip.modules[realpath(file)] = Kip.modules[old]
  end
  # Kip loads a registered package by name if its folder has a Project.toml with a name
  foreach(p -> put(joinpath(repos, p, "Project.toml"), "name = \"$(splitext(basename(p))[1])\"\n"), packages)
  setglobal!(Kip, :repos, repos)
  setglobal!(Kip, :refs, joinpath(dir, "refs"))
  welcome = joinpath(dir, "Welcome")
  for (name, text) in pages
    file, was = joinpath(welcome, name), joinpath(dir, "written", name)
    # Leave a page alone if you changed it and this version's page is the one it wrote before
    (isfile(file) && isfile(was) && read(was, String) == text) && continue
    put(file, text)
    put(was, text)
  end
  Kip.modules[realpath(joinpath(welcome, "widgets.jl"))] = Kip.modules[widgets_file]
  pages_dir[] = welcome
  joinpath(welcome, "welcome.md")
end

"""
Draw every part of each page in `dir`, and fail if a live block on one shows an
error. An editor only runs the blocks that are on screen, so this scrolls down
each page a screen at a time.
"""
check_pages(dir) =
  for name in ("welcome.md", "components.md", "settings.md")
    empty!(problems)
    e = build_editor(joinpath(dir, name))
    w = Window(e, title="check", size=(1100px, 800px))
    frame(w)
    for top in 0:600:ceil(Int, e.scroll.content_height.value)
      e.scroll.offset = px(top)
      frame(w); frame(w)
    end
    isempty(problems) || error("A live block in $name failed: ", join(unique(problems), "\n"))
  end

"""
Open a copy of the welcome page in a throwaway folder and send input to a
window that isn't on screen. While the app is built this compiles the code it
runs. `--self-test` runs it again inside the finished app, to check that code
is all still there.
"""
warm_up() = begin
  dir = mktempdir()
  write(joinpath(dir, "welcome.md"), page)
  write(joinpath(dir, "notes.md"), "# Notes\n\nSome text.\n")
  e = build_editor(joinpath(dir, "welcome.md"))
  # A word that's spelt wrong adds items to the page's menu, and the clicks below count on where its items are
  e.spelling = false
  w = Window(e, title="warm up", size=(1100px, 800px))
  focus(e)
  hold(keys) = foreach(k -> (w.keys |= k), keys)
  release(keys) = foreach(k -> (w.keys ⊻= k), keys)
  press(k, mods...) = (hold(mods); onkey(w, KeyPress{k}(0, w)); onkey(w, KeyRelease{k}(0, w)); release(mods); frame(w))
  mouse(x, y) = (pos = Vec2{px}(px(x), px(y)); onmouse(w, MouseMove(pos, w)); w.mouse = pos; frame(w))
  click(x, y) = begin
    mouse(x, y)
    hold((Keys.mouse_left,)); onkey(w, KeyPress{Keys.mouse_left}(0, w))
    release((Keys.mouse_left,)); onkey(w, KeyRelease{Keys.mouse_left}(0, w))
    frame(w)
  end
  right_click(x, y) = begin
    mouse(x, y)
    hold((Keys.mouse_right,)); onkey(w, KeyPress{Keys.mouse_right}(0, w))
    release((Keys.mouse_right,)); onkey(w, KeyRelease{Keys.mouse_right}(0, w))
    frame(w)
  end
  frame(w)
  # Each set of colours and each font
  for theme in (:paper, :night, :sepia), font in ("Helvetica Neue", "Charter")
    e.theme, e.font = theme, font
    restyle!(e)
    frame(w)
  end
  # Down the whole page a line at a time: through the table, the code, the live blocks and the sheet
  for _ in 1:length(e.buf.lines)
    press(Keys.down)
    # Type, go to the next cell and back, select and undo, in whatever the caret is in
    press(Keys.a); press(Keys.backspace)
    press(Keys.tab); press(Keys.tab, Keys.shft)
    press(Keys.right, Keys.shft); press(Keys.left)
    press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  end
  # A new line at the end, a list and a new sheet
  press(Keys.down, Keys.cmd); press(Keys.enter)
  foreach(press, (Keys.minus, Keys.space, Keys.a, Keys.enter, Keys.enter))
  foreach(press, (Keys.tilde, Keys.tilde, Keys.tilde, Keys.s, Keys.h, Keys.e, Keys.e, Keys.t, Keys.enter))
  foreach(press, (Keys.a, Keys.tab, Keys.var"2", Keys.enter, Keys.b, Keys.tab, Keys.a, Keys.enter, Keys.enter))
  # Select everything, copy nothing, make it bold and undo
  press(Keys.a, Keys.cmd); press(Keys.b, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.escape)
  # Bigger and smaller text, the sidebar and the file finder
  press(Keys.equal, Keys.cmd); press(Keys.minus, Keys.cmd); press(Keys.var"0", Keys.cmd)
  press(Keys.backslash, Keys.cmd); press(Keys.backslash, Keys.cmd)
  # The sidebar with the keyboard: the headings of each file, then Return on a heading and on a file
  press(Keys.backslash, Keys.cmd, Keys.shft)
  for _ in 1:2
    press(Keys.right); press(Keys.down); press(Keys.right); press(Keys.down); press(Keys.left); press(Keys.left); press(Keys.down)
  end
  press(Keys.up); press(Keys.right); press(Keys.down); press(Keys.enter)
  press(Keys.backslash, Keys.cmd, Keys.shft); press(Keys.up); press(Keys.enter)
  # A click on a name in the sidebar, and on the arrow beside it
  click(60, 88); click(19, 88)
  # The menu of a file: open it and click away, then rename the file and change your mind
  right_click(60, 88); click(700, 500)
  right_click(60, 88); click(80, 104)
  press(Keys.a); press(Keys.escape); press(Keys.escape)
  # The menu of the page: open it and click away, then add a block of each kind from its Insert menu.
  # Kaydown draws the menu here, 28px for each item, with Insert as its fifth item. A recording is
  # left out, since it would record from the microphone while the app is built.
  right_click(500, 300); click(900, 600)
  blocks = [x[1] for x in INSERTS if x isa Tuple]
  for n in eachindex(blocks)
    blocks[n] == "Recording" && continue
    right_click(500, 300); click(540, 426); click(540, 286 + 28n)
    # Type in the new block, press Return and type again, then undo it all
    press(Keys.a); press(Keys.enter); press(Keys.b)
    press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  end
  # A line that holds a sound file shows a player, with a button that transcribes it. Every Mac has this sound.
  press(Keys.down, Keys.cmd); press(Keys.enter)
  foreach(c -> ontype(e, Typed(c, w)), "![A sound](/System/Library/Sounds/Glass.aiff)")
  press(Keys.enter)
  press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  # A to-do item, then a click on its box to tick it
  right_click(500, 300); click(540, 426); click(540, 286 + 28 * 7)
  press(Keys.a); press(Keys.up, Keys.cmd)
  x = e.origin[1] + 6px
  y = findfirst(y -> todo_at(e, (x, px(y))) !== nothing, 80:4:780)
  y === nothing || click(x.value, (80:4:780)[y])
  press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  # Select All from the menu. Nothing here cuts, copies or pastes, so the clipboard stays as it was.
  right_click(500, 300); click(540, 342); press(Keys.escape)
  press(Keys.backslash, Keys.cmd)
  frame(w)
  press(Keys.o, Keys.cmd); press(Keys.n); press(Keys.escape)
  # The page drawn for paper. A window that isn't on the screen shows no print panel.
  press(Keys.p, Keys.cmd)
  # The settings page and back
  press(Keys.comma, Keys.cmd); press(Keys.comma, Keys.cmd)
  # The mouse over the top bar's buttons, and a click and a drag on the page
  foreach(x -> mouse(x, 22), (50, 550, 1000, 1075))
  press(Keys.up, Keys.cmd)
  click(400, 200); click(400, 200); click(500, 400)
  # The layout inspector
  press(Keys.i, Keys.cmd, Keys.opt); press(Keys.i, Keys.cmd, Keys.opt)
  # Something else changes the file while the page has a change that isn't saved, and the page keeps both
  press(Keys.down, Keys.cmd); press(Keys.enter)
  file = e.buf.path
  write(file, "A line from outside\n\n" * read(file, String))
  frame(w)
  e.buf.lines[1] == "A line from outside" || error("The page didn't take a change that was made to its file")
  # An agent waits for the page, and ⌘Return sends it. This process stands in for the agent's
  # script, and the files that the two talk through go in a folder of their own.
  Agent.place[] = mktempdir()
  write(joinpath(Agent.place[], "$(getpid()).wait"), realpath(file) * "\nthe agent\n")
  delete!(e.nodes, :agents)
  frame(w)
  press(Keys.enter, Keys.cmd)
  isfile(joinpath(Agent.place[], "$(getpid()).sent")) || error("The page wasn't sent to the agent that waited for it")
  rm(Agent.place[], recursive=true)
  Agent.place[] = ""
  delete!(e.nodes, :agents)
  rm(dir, recursive=true)
end

warm_up()
check_pages(PAGES)

if building
  relocate!()
  # Skia's calls were compiled with the old path, so compile them again
  warm_up()
  check_pages(PAGES)
end

"The app's self-test: the pages as the app writes them out, then some typing"
self_test() = begin
  dir = mktempdir()
  check_pages(dirname(unpack(dir)))
  warm_up()
  rm(dir, recursive=true)
end

"Open the file or folder named in `args`, or the welcome page"
open_kaydown(args) = begin
  welcome = unpack(support())
  # The window opens the files that macOS asks for: one you double-clicked to start the app, and any after that
  Opened.listen()
  inbox[] = Opened.files
  Opened.wake[] = Libdl.dlsym(Libdl.dlopen(GLFW.libglfw), :glfwPostEmptyEvent)
  open_editor(any(a -> !startswith(a, "-"), args) ? args : [welcome; args])
end

function (@main)(args::Vector{String})
  run_app(open_kaydown, args, self_test)
end
