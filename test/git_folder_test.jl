# Tests for a folder with a git repository in it: the marks in the sidebar, the
# line over the sidebar's list, and the repository's page. See "a folder with a
# git repository in it" in main.jl, and git.jl. Run them with
# `julia -O0 --project=. test/git_folder_test.jl`. They make a repository in a
# temporary folder with the Mac's own git, and click in a window that isn't on
# the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const G = K.Git

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const hold = joinpath(dir, "code")
const repo = joinpath(hold, "work")
mkpath(joinpath(repo, "src", "deep"))
mkpath(joinpath(hold, "plain"))
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
git("init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n\nWhat this is.\n")
write(joinpath(repo, "notes.md"), "# Notes\n")
write(joinpath(repo, "src", "a.jl"), "a = 1\n")
write(joinpath(repo, "src", "deep", "b.jl"), "b = 2\n")
git("add", "-A")
git("commit", "-m", "The first commit")
write(joinpath(repo, "notes.md"), "# Notes\n\nMore.\n")
write(joinpath(repo, "src", "deep", "b.jl"), "b = 3\n")
write(joinpath(repo, "new.md"), "# New\n")

const e = K.build_editor(joinpath(repo, "Readme.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2))
"Ask git again now, as the window does after some seconds"
again() = (G.forget!(); settle())
settle()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "git-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
"The words of what follows the name of the folder or the file at `path` in the sidebar"
marks(path) = [m.children[1] isa K.Text ? m.children[1].content : "dot" for m in K.entry_marks(e, K.object(e, path))]

@testset "a folder with a .git in it is a folder that git keeps, and so is each folder in it" begin
  @test K.directory(e) isa K.GitDirectory
  @test K.object(e, joinpath(repo, "src")) isa K.GitDirectory
  @test K.FS.get(K.FSPath(joinpath(repo, "src", "deep"))) isa K.GitDirectory
  @test K.FS.get(K.FSPath(joinpath(hold, "plain"))) isa K.FS.Directory
  @test K.FS.get(K.FSPath(hold)) isa K.FS.Directory
end

@testset "a changed file has a letter in the sidebar, and a folder with one has a dot" begin
  @test marks(joinpath(repo, "notes.md")) == ["M"]
  @test marks(joinpath(repo, "new.md")) == ["U"]
  @test marks(joinpath(repo, "Readme.md")) == []
  @test marks(joinpath(repo, "src")) == ["dot"]
  shot("sidebar")
end

@testset "the line over the list has the branch and how many files have changes" begin
  bar = e.nodes[:git_bar]
  @test bar.root == repo
  @test rect(bar) !== nothing
  @test K.changes_words(length(G.state(repo).changes)) == "3 changes"
  # A file that's saved shows in the count when git is asked again
  write(joinpath(repo, "Readme.md"), "# Work\n\nWhat this is now.\n")
  again()
  @test marks(joinpath(repo, "Readme.md")) == ["M"]
  @test length(G.state(repo).changes) == 4
end

@testset "a click on the line shows the repository's page, and the sidebar stays" begin
  click(middle(e.nodes[:git_bar]))
  @test e.buf.path == repo
  @test e.folder == repo
  v = e.nodes[(:repo, repo)]
  @test v isa K.RepoView
  @test rect(v) !== nothing
  @test sort!([k[2] for k in keys(v.rows) if k[1] == :change]) == ["Readme.md", "new.md", "notes.md", "src/deep/b.jl"]
  @test count(k -> k[1] == :commit, keys(v.rows)) == 1
  @test K.branch_words(G.state(repo)) == "On the branch main"
  shot("page")
end

@testset "a click on a file of the repository's page shows the file" begin
  v = e.nodes[(:repo, repo)]
  click(middle(v.rows[(:change, "notes.md")]))
  @test e.buf.path == joinpath(repo, "notes.md")
  # The arrow that goes back shows the repository's page again
  K.go_back!(e)
  frames()
  @test e.buf.path == repo
  # A file in a folder shows too, and the sidebar lists its folder
  click(middle(v.rows[(:change, "src/deep/b.jl")]))
  @test e.buf.path == joinpath(repo, "src", "deep", "b.jl")
  @test e.folder == joinpath(repo, "src", "deep")
  settle()
  @test K.directory(e) isa K.GitDirectory
  @test e.nodes[:git_bar].root == repo   # the line is over the list of a folder in the repository too
  @test marks(joinpath(repo, "src", "deep", "b.jl")) == ["M"]
end

@testset "a repository in the list of the folder that it's in has its branch and its changes" begin
  K.go_folder!(e, hold)
  settle()
  @test K.directory(e) isa K.FS.Directory
  @test K.folder_view(e, K.directory(e)).bar === nothing
  @test marks(repo) == ["main", "4"]
  @test marks(joinpath(hold, "plain")) == []
  shot("list")
end

@testset "a window that's opened on a repository shows its first page of text" begin
  other = K.build_editor(repo)
  @test other.buf.path == joinpath(repo, "new.md")
  @test K.directory(other) isa K.GitDirectory
end

@testset "a page of its own gives a folder in a repository another kind" begin
  desk = joinpath(repo, "desk")
  mkpath(desk)
  write(joinpath(desk, ".ladder"), "```julia\nLadder.DesktopDirectory\n```\n")
  K.folder_pages!(desk)
  @test Base.invokelatest(K.FS.get, K.FSPath(desk)) isa K.DesktopDirectory
end

close(w)
