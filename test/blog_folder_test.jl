# Tests for a folder that's a blog, in main.jl: the folder's own page lists
# its pages as posts, and Publish makes each a page of HTML in the folder
# `docs`, commits that folder and pushes it. blog.jl says what a post is. Run
# them with `julia -O0 --project=. test/blog_folder_test.jl`. They make a
# repository in a temporary folder with the Mac's own git, with another
# folder as its remote, so nothing goes to the web. They draw a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a picture there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use GeometryBasics: Vec2
const px = K.px

const dir = realpath(mktempdir())
@eval K settings_file() = $(joinpath(dir, "settings"))
const blog = joinpath(dir, "blog")
const remote = joinpath(dir, "remote.git")
mkpath(joinpath(blog, "pics"))
git(args...; at=blog) = read(pipeline(setenv(`git -C $at $args`, merge(ENV, Dict("LC_ALL" => "C"))), stderr=devnull), String)
run(pipeline(`git init --bare -b main $remote`, stdout=devnull, stderr=devnull))
git("init", "-b", "main")
foreach(kv -> git("config", kv...), (("user.name", "Test"), ("user.email", "test@example.com"), ("commit.gpgsign", "false")))
git("remote", "add", "origin", remote)

const hello = joinpath(blog, "2026-11-20-hello.md")
const shed = joinpath(blog, "shed.md")
write(joinpath(blog, "index.md"), "# Sam's blog\n\nThings that I built.\n")
write(hello, "# Hello\n\nSee [the shed](shed.md).\n\n![A picture](pics/a.png)\n\n```sheet\nPosts = 2\nWords = posts * 300\n```\n")
write(shed, "---\ntitle: The shed\ndate: 2026-10-03\ndraft: true\n---\n\nNot done yet.\n")
write(joinpath(blog, "pics", "a.png"), read(joinpath(K.pages_dir[], "photos", "2 frame.png")))

const e = K.build_editor(hello)
const w = Window(e, size=(1000px, 800px))
# Each frame is drawn with the newest code, as the window's loop draws it
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
folder() = K.FS.get(FSPath(blog))
"Draw frames until the blog is published, as the window does while Publish works"
publish() = begin
  K.publish!(blog)
  started = time()
  while haskey(K.PUBLISHING, blog) && time() - started < 60
    frames(1)
    sleep(0.01)
  end
  frames()
end
site(name) = joinpath(blog, "docs", name)
sent(args...) = git(args...; at=remote)

@testset "Show Folder As makes the folder a blog" begin
  kind = only(filter(k -> k.name == "Blog", K.choices_for(K.KindChoice, e)))
  Base.invokelatest(K.show_folder_as!, e, folder(), kind)
  frames()
  @test folder() isa K.BlogDirectory && K.page_object(e) isa K.BlogDirectory && K.entry_icon(folder()) == "rss"
  v = e.nodes[(:blog, blog)]
  @test [K.Blogs.standing(blog, p) for p in K.blog_posts(blog)] == [:new, :draft]
  @test K.blog_name(blog) == "Sam's blog"
  @test !v.buttons[:publish].off && v.buttons[:open].off
  shot("blog.png")
end

@testset "Publish writes the site" begin
  publish()
  @test !haskey(K.PUBLISHING, blog)
  page = read(site("2026-11-20-hello.html"), String)
  # The post is a page of HTML, with a link to the other post's page, and a way back to the first page
  @test occursin("<h1>Hello</h1>", page) && occursin("href=\"shed.html\"", page) && occursin("<a href=\"index.html\">← Sam's blog</a>", page)
  @test occursin("<title>Hello</title>", page) && occursin("20 November 2026", page)
  # The sheet went in as a table of what its rows come to, as ⌘⇧E writes it
  @test occursin("<td>600</td>", page)
  # The picture that the post shows is in the site, and the draft isn't
  @test read(site("pics/a.png")) == read(joinpath(blog, "pics", "a.png")) && !isfile(site("shed.html"))
  first = read(site("index.html"), String)
  @test occursin("<h1>Sam's blog</h1>", first)
  @test occursin("Things that I built.", first) && occursin("<a href=\"2026-11-20-hello.html\">Hello</a>, 20 November 2026", first) && !occursin("shed", first)
  @test isfile(site(".nojekyll")) && readlines(site(".ladder-site")) == ["2026-11-20-hello.html", "index.html"]
  @test [K.Blogs.standing(blog, p) for p in K.blog_posts(blog)] == [:published, :draft]
end

@testset "Publish commits the site and pushes it, and nothing else" begin
  @test startswith(K.PUBLISHED[blog], "Published 1 post.")
  @test occursin("Publish the blog", sent("log", "--format=%s", "main"))
  files = split(strip(sent("ls-tree", "-r", "--name-only", "main")), '\n')
  @test sort(files) == ["docs/.ladder-site", "docs/.nojekyll", "docs/2026-11-20-hello.html", "docs/index.html", "docs/pics/a.png"]
  # The posts' own files are still the user's to commit
  @test occursin("?? shed.md", git("status", "--short")) && occursin("?? 2026-11-20-hello.md", git("status", "--short"))
  v = e.nodes[(:blog, blog)]
  @test !v.buttons[:open].off
  shot("blog-published.png")
end

@testset "a post that becomes a draft leaves the site" begin
  write(hello, "---\ndraft: true\n---\n\n" * read(hello, String))
  write(shed, replace(read(shed, String), "draft: true\n" => ""))
  empty!(K.BLOG_POSTS)
  publish()
  @test !isfile(site("2026-11-20-hello.html")) && isfile(site("shed.html"))
  page = read(site("shed.html"), String)
  # A post with no heading in its text has its title as the page's heading
  @test occursin("<h1>The shed</h1>", page) && occursin("3 October 2026", page)
  @test !occursin("Hello", read(site("index.html"), String))
  @test sort(split(strip(sent("ls-tree", "-r", "--name-only", "main")), '\n')) == ["docs/.ladder-site", "docs/.nojekyll", "docs/index.html", "docs/pics/a.png", "docs/shed.html"]
end

@testset "a blog with nowhere to send its site says so" begin
  git("remote", "remove", "origin")
  publish()
  @test occursin("no remote called origin", K.PUBLISHED[blog]) && isfile(site("shed.html"))
  @test K.blog_address(blog) == ""
end

close(w)
