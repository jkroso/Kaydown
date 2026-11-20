# Tests for blog.jl: what a post of a blog is, how it stands beside the site,
# and the address of the site. Run them with
# `julia -O0 --project=. test/blog_test.jl`. They open no window.

@use Test: @test, @testset
@use Dates: Date
@use "../blog" => B

const dir = realpath(mktempdir())
page!(name, text) = (path = joinpath(dir, name); write(path, text); path)

@testset "a post" begin
  p = B.post(page!("2026-11-20-hello.md", "# Hello there\n\nWords.\n"))
  @test p.name == "2026-11-20-hello" && p.title == "Hello there" && p.day == Date(2026, 11, 20) && !p.draft
  # Front matter comes first: the title, the day, and whether it's a draft
  p = B.post(page!("shed.md", "---\ntitle: \"The shed\"\ndate: 2026-10-03\ndraft: true\n---\n\n# Another heading\n"))
  @test p.title == "The shed" && p.day == Date(2026, 10, 3) && p.draft
  # With neither, the title is the file's name, and the day is the day that the file was saved
  p = B.post(page!("plain.md", "Just words.\n"))
  @test p.title == "plain" && p.day == Date(Libc.strftime("%Y-%m-%d", time()))
  @test B.matter(["# No front matter", "title: x"]) == Dict{String,String}()
  @test B.day("on 2026-13-40 and 2026-02-28") == Date(2026, 2, 28) && B.day("no day") === nothing
  @test B.long(Date(2026, 11, 3)) == "3 November 2026"
end

@testset "the posts of a folder" begin
  page!("index.md", "# Sam's blog\n\nHello.\n")
  page!("_notes.md", "# Not a post\n")
  page!(".hidden.md", "# Not a post\n")
  write(joinpath(dir, "picture.png"), "png")
  list = B.posts(dir)
  # The newest is first, and the first page, the hidden pages and the other files are no posts
  @test [p.name for p in list][end-1:end] == ["2026-11-20-hello", "shed"] && length(list) == 3 && list[1].name == "plain"
end

@testset "how a post stands beside the site" begin
  hello, shed = B.post(joinpath(dir, "2026-11-20-hello.md")), B.post(joinpath(dir, "shed.md"))
  @test B.standing(dir, hello) == :new && B.standing(dir, shed) == :draft
  mkpath(B.site(dir))
  write(B.page(dir, hello), "<html>")
  @test B.page(dir, hello) == joinpath(dir, "docs", "2026-11-20-hello.html") && B.standing(dir, hello) == :published
  # A post that's saved after its page was made has changed
  run(`touch -t 203001010000 $(hello.path)`)
  @test B.standing(dir, hello) == :changed
  @test B.words(:new) == "not on the site yet" && B.words(:published) == ""
end

@testset "the address of the site" begin
  @test B.address("git@github.com:sam/blog.git") == "https://sam.github.io/blog/"
  @test B.address("https://github.com/Sam/blog") == "https://sam.github.io/blog/"
  @test B.address("https://github.com/sam/sam.github.io.git\n") == "https://sam.github.io/"
  @test B.address("git@example.com:sam/blog.git") == "" && B.address("") == ""
end

@testset "the pages of the site" begin
  html = "<a href=\"shed.md\">Shed</a> <a href=\"two%20words.md#top\">Two</a> <a href=\"https://example.com/a.md\">Out</a> <a href=\"#here\">Here</a> <img src=\"pics/a b.png\"> <img src=\".media/x.png\"> <img src=\"https://example.com/y.png\">"
  made = B.linked(html)
  @test occursin("href=\"shed.html\"", made) && occursin("href=\"two%20words.html#top\"", made) && occursin("https://example.com/a.md", made)
  # The files that a page shows are the ones in the blog's own folder
  @test B.assets(made) == ["pics/a b.png", ".media/x.png"]
  @test B.assets("<img src=\"pics/a%20b.png\"><img src=\"pics/a%20b.png\">") == ["pics/a b.png"]
  list = [B.Post("/b/one.md", "one", "One", Date(2026, 11, 2), false), B.Post("/b/two words.md", "two words", "Two", Date(2026, 11, 1), false), B.Post("/b/d.md", "d", "Draft", Date(2026, 11, 3), true)]
  @test B.index(["# Blog", "", "Hello."], list) == ["# Blog", "", "Hello.", "", "- [One](one.md), 2 November 2026", "- [Two](two%20words.md), 1 November 2026"]
  page = B.framed("<head><title>one</title></head>\n<body>\n<p>Words</p></body>", "Sam&#39;s blog", "A \$5 title", list[1], heading=true)
  @test occursin("<title>A \$5 title</title>", page) && occursin("<body>\n<p style=", page) && occursin("← Sam&#39;s blog</a>", page)
  @test occursin("2 November 2026</p>\n<h1>A \$5 title</h1>\n<p>Words</p>", page)
  @test !occursin("<h1>", B.framed("<title>x</title><body>\n", "b", "t", list[1]))
end
