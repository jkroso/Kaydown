# Tests for webpage.jl: what it reads of the pictures that webpage.swift made
# of a page of HTML, the links of a page, and how the pictures are asked for
# and kept. Run them with `julia -O0 --project=. test/webpage_test.jl`. They
# use neither WebKit nor the web: webpage_fake.jl takes the place of the
# program.

@use Test: @test, @testset
@use "../webpage" => W
@use "../map" => Maps
@use "./webpage_fake" => Fake

W.HELPER[] = Fake.helper
W.OPENER[] = Fake.opener
const HTML = """<p>Hi <a href="https://example.com/a">one</a> and <a href="mailto:sam@example.com">two</a></p>"""

@testset "what the program made" begin
  dir = mktempdir()
  out = joinpath(dir, "ab.txt")
  write(joinpath(dir, "ab-1.png"), "x")
  write(joinpath(dir, "ab-2.png"), "x")
  write(out, "page\t700\t1310\nstrip\t1024\tab-1.png\nstrip\t286\tab-2.png\n" *
             "link\t158.0\t493.0\t384.0\t33.0\thttps://example.com/session?id=5&key=e\nlink\t10\t20\t30\t40\tmailto:sam@example.com\nmore\tthat a later program says\n")
  s = W.shot(out)
  @test (s.wide, s.tall) == (700, 1310)
  @test s.strips == [joinpath(dir, "ab-1.png") => 1024, joinpath(dir, "ab-2.png") => 286]
  @test s.links == [(left=158.0, top=493.0, wide=384.0, tall=33.0, url="https://example.com/session?id=5&key=e"),
                    (left=10.0, top=20.0, wide=30.0, tall=40.0, url="mailto:sam@example.com")]
  # The link at a point, and none beside it
  @test W.link(s, 160, 500).url == "https://example.com/session?id=5&key=e" && W.link(s, 25, 40).url == "mailto:sam@example.com"
  @test W.link(s, 157, 500) === nothing && W.link(s, 160, 527) === nothing && W.link(s, 600, 900) === nothing
  # Where two links are at one point, it's the one that the page draws over the other
  write(out, "page\t100\t50\nstrip\t50\tab-1.png\nlink\t0\t0\t100\t50\thttps://under.example\nlink\t10\t10\t20\t20\thttps://over.example\n")
  s = W.shot(out)
  @test W.link(s, 15, 15).url == "https://over.example" && W.link(s, 50, 40).url == "https://under.example"
  # A file that says nothing to draw, strips that don't add up to the page, and a strip that's gone
  @test W.shot(joinpath(dir, "none.txt")) === nothing
  for text in ["", "page\t700\t1310\n", "strip\t50\tab-1.png\n", "page\tx\t50\nstrip\t50\tab-1.png\n", "page\t100\t60\nstrip\t50\tab-1.png\n",
               "page\t100\t50\nstrip\t50\tgone.png\n", "page\t100\t50\nstrip\t0\tab-1.png\nstrip\t50\tab-2.png\n"]
    write(out, text)
    @test W.shot(out) === nothing
  end
end

@testset "what a page has from the web" begin
  @test W.remote("""<img src="https://example.com/logo.png">""") && W.remote("""<IMG alt="x" SRC = 'http://example.com/a.gif'>""")
  @test W.remote("""<td background="https://example.com/b.png">""") && W.remote("""<div style="background: url( 'https://example.com/c.png')">""")
  @test W.remote("""<link rel="stylesheet" href="https://fonts.example/css">""")
  # A link to a web page fetches nothing, and nor does a picture that's inside the page
  @test !W.remote("""<a href="https://example.com">a</a> <img src="data:image/png;base64,AAAA"> <img src="cid:logo">""")
  @test !W.remote("") && !W.remote("<p>See https://example.com</p>")
end

@testset "the pictures of a page are asked for once, and kept" begin
  empty!(Fake.calls)
  dir = mktempdir()
  p = W.picture!(dir, HTML, 700)
  @test p.state == :there && isfile(p.file) && dirname(p.file) == dir
  @test Fake.calls == [(html=HTML, wide=700, zoom=1.0, pictures=false)]
  s = W.shot(p.file)
  @test (s.wide, s.tall) == (700, 400) && length(s.strips) == 1 && isfile(first(s.strips[1]))
  @test [l.url for l in s.links] == ["https://example.com/a", "mailto:sam@example.com"] && W.link(s, 30, 110).url == "mailto:sam@example.com"
  # The same page again runs no program
  @test W.picture!(dir, HTML, 700) == p && length(Fake.calls) == 1
  # Another width, another zoom, and the pictures from the web are each another set of pictures
  wider = W.picture!(dir, HTML, 800)
  bigger = W.picture!(dir, HTML, 700, zoom=1.25)
  fetched = W.picture!(dir, HTML, 700, pictures=true)
  @test length(unique([p.file, wider.file, bigger.file, fetched.file])) == 4 && all(q -> q.state == :there, (wider, bigger, fetched))
  @test Fake.calls[2:4] == [(html=HTML, wide=800, zoom=1.0, pictures=false), (html=HTML, wide=700, zoom=1.25, pictures=false),
                            (html=HTML, wide=700, zoom=1.0, pictures=true)]
  # A tall page is in strips of 1024 px or less
  tall = W.shot(W.picture!(dir, HTML * "<!-- tall 2500 -->", 700).file)
  @test tall.tall == 2500 && last.(tall.strips) == [1024, 1024, 452] && all(isfile ∘ first, tall.strips)
  # The folder keeps the pictures of one page when the others are taken away
  W.tidy!(dir, wider.file)
  @test W.shot(wider.file) !== nothing && !isfile(p.file) && !isfile(fetched.file)
  @test all(f -> startswith(f, chopsuffix(basename(wider.file), ".txt")), readdir(dir))
  # A file whose name starts with a dot stays, like the one that says you asked for an email's pictures
  touch(joinpath(dir, ".pictures"))
  W.tidy!(dir, wider.file)
  @test isfile(joinpath(dir, ".pictures"))
  # Without `start`, pictures that aren't kept aren't made
  n = length(Fake.calls)
  @test W.picture!(dir, HTML, 700, start=false).state == :none && length(Fake.calls) == n
end

@testset "pictures that can't be made, and ones that take a while" begin
  empty!(Fake.calls)
  dir = mktempdir()
  Fake.offline[] = true
  p = W.picture!(dir, HTML, 700)
  @test p.state == :failed && p.problem == W.FAILED && !isfile(p.file)
  # It isn't tried again at once
  @test W.picture!(dir, HTML, 700).state == :failed && length(Fake.calls) == 1
  Fake.offline[] = false
  # A Mac with no Swift says what's missing, in words about an email
  swiftless(args...) = 127
  W.HELPER[] = swiftless
  @test W.picture!(dir, HTML, 710).problem == W.NO_SWIFT
  W.HELPER[] = Fake.helper
  # A slow program is `:coming` until it's done
  Fake.slow[] = true
  p = W.picture!(dir, HTML, 720)
  @test p.state == :coming && p.wait > 0
  started = time()
  while (p = W.picture!(dir, HTML, 720)).state == :coming && time() - started < 10; sleep(0.05) end
  @test p.state == :there && W.shot(p.file).wide == 720
  Fake.slow[] = false
end

# This one runs webpage.swift with WebKit, so it needs a Mac with Swift. The
# first run compiles the program, which takes a while.
if Sys.isapple() && Sys.which("swiftc") !== nothing
  @testset "the program lets content with a width of its own be as narrow as the page" begin
    dir = mktempdir()
    runs = Ref(0)
    "What the program makes of `html` on a page 700 px wide"
    drawn(html) = begin
      n = runs[] += 1
      source, out = joinpath(dir, "$n.html"), joinpath(dir, "$n.txt")
      write(source, html)
      wait(W.run_program(source, 700, 1.0, false, joinpath(dir, "$n"), out, joinpath(dir, "$n.err")))
      W.shot(out)
    end
    # Outlook gives the table round an email the width of its sender's window. The words wrap at the page all the same.
    words = "Hi Jake, these words go on and on, as words in an email do, so that they need more than one line. " ^ 10
    outlook = """<table width="1938" style="width:1453.8pt"><tr><td width="1938" style="width:1453.8pt"><p>$words</p>
                 <table width="600"><tr><td width="300">Left</td><td width="300"><a href="https://example.com/right">Right</a></td></tr></table>
                 </td></tr></table>"""
    s = drawn(outlook)
    @test s.wide == 700 && s.tall > 100
    # A cell whose width fits the page keeps it
    @test only(s.links).left > 300 && only(s.links).left + only(s.links).wide < 700
    # A picture that's wider than the page shrinks to it, and keeps its shape. A link round it says how big it is.
    s = drawn("""<p><a href="https://example.com/p" style="display:inline-block"><img width="1500" height="300" alt="A wide picture"></a></p>""")
    @test s.wide == 700 && only(s.links).wide <= 692 && only(s.links).tall < 200
    # A long word, like a key, goes on in the next line
    @test drawn("<p>" * "abcdefghij" ^ 200 * "</p>").wide == 700
    # Content that can't be as narrow as the page makes the page wider
    s = drawn("""<div style="display:flex"><div style="flex:none;width:500px">One</div><div style="flex:none;width:500px">Two</div></div>""")
    @test s.wide >= 1000
    # Content that fits is drawn as it is
    @test drawn("""<table width="600"><tr><td>Short</td></tr></table>""").wide == 700
  end
end

@testset "a link opens with the Mac's app for it" begin
  empty!(Fake.opened)
  W.open_link("https://example.com/a?b=c&d=e")
  @test Fake.opened == ["https://example.com/a?b=c&d=e"]
  # An opener that fails stops nothing
  W.OPENER[] = url -> error("no browser")
  @test W.open_link("https://example.com") === nothing
  W.OPENER[] = Fake.opener
end
