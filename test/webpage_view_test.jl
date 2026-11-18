# Tests for how the window shows an email as it was sent: the pictures of its
# HTML in place of its words, its links, the button that gets its pictures
# from the web, and what shows while the pictures aren't there. See "an email
# as it was sent" in main.jl. Run them with
# `julia -O0 --project=. test/webpage_view_test.jl`. They click in a window
# that isn't on the screen. They use neither WebKit nor the web, and they
# open no app: webpage_fake.jl takes the place of the program. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "./webpage_fake" => Fake
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
const px = K.px
const W = K.Webpages

W.HELPER[] = Fake.helper
W.OPENER[] = Fake.opener
empty!(Fake.calls)   # what a test before this one asked for, when the tests share a process
K.MEDIA_CACHE[] = mktempdir()                          # the pictures are kept here, and not in the Mac's caches
K.Eml.CACHE[] = mktempdir()                            # and the files that came with an email here

const dir = mktempdir()
"Write an email file whose body is `body`, of the kind `type`, and give its path. With `file`, a PDF comes with it."
email(name, body; type="text/html", file=false) = begin
  head = "From: Sam Lee <sam@example.com>\r\nTo: you@example.com\r\nSubject: $name\r\nDate: Sat, 14 Nov 2026 09:32:00 +1100\r\nMIME-Version: 1.0\r\n"
  text = "Content-Type: $type; charset=utf-8\r\n\r\n$body\r\n"
  pdf = "Content-Type: application/pdf; name=\"Roof quote.pdf\"\r\nContent-Disposition: attachment; filename=\"Roof quote.pdf\"\r\n" *
        "Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjcK\r\n"
  path = joinpath(dir, "$name.eml")
  write(path, file ? head * "Content-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\n$text--m\r\n$pdf--m--\r\n" : head * text)
  path
end
const LINKS = """<p>Hi Jake, the <a href="https://example.com/quote?job=7&v=2">quote</a> is here. Write to <a href="mailto:sam@example.com">me</a>.</p>"""
const quote_email = email("The quote", LINKS, file=true)
const logo_email = email("A logo", """<p>Our logo</p><img src="https://example.com/logo.png">""")
const plain_email = email("Plain words", "Hi Jake,\r\n\r\nNo HTML here.", type="text/plain")
const tall_email = email("A long one", "<p>A long email</p><!-- tall 1500 -->")

const e = K.build_editor(quote_email)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.plain && K.level!(e)   # the page starts at the high level, whatever the test before this one left
frames(3)
K.focus(e)
shot(name, window=w) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), window)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release(n=2) = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(n))
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
"Draw frames until `done()` is true, for 10 seconds at most"
until(done) = (t = time(); while !done() && time() - t < 10; sleep(0.02); frames(1); end; done())
"Show the email at `path` in the window"
show(path, n=3) = (K.open!(e, path); frames(n))

"The email as it was sent, as the window keeps it"
sent() = e.nodes[:sent_email]
"The part of the page that stands for the email's words, or nothing while the page shows the words"
item() = (i = findfirst(it -> it.content isa K.Live && it.content.node isa K.SentEmail, e.layout); i === nothing ? nothing : e.layout[i])
"True when the page shows the pictures of the email"
shows() = item() !== nothing && sent().shown !== nothing
"Where the pictures are in the window"
page() = rect(sent().parts[:page])
"The place in the window of a point of the email, in px from the email's top left corner, which is inside the line round it"
spot(x, y) = (r = page(); (K.num(r.left) + 1 + x, K.num(r.top) + 1 + y))
"The place in the window of the middle of link `i` of the email"
link(i) = (b = Fake.box(i); spot(b.left + b.wide / 2, b.top + b.tall / 2))
"How wide the pictures of an email are: as wide as the page's text, less the line on each side of the email"
wide() = round(Int, K.num(e.width)) - 2
"What the helper is asked for a page of the window's width"
asked(html; pictures=false, zoom=1.0) = (html=html, wide=wide(), zoom=zoom, pictures=pictures)
"The red, the green and the blue of the window's pixel at a place, as the window was last drawn"
colour(place) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  dots = pixels(file)
  k = size(dots, 2) / K.num(K.window_size(e)[1])
  c = dots[round(Int, place[2] * k), round(Int, place[1] * k)]
  (Int((c >> 16) & 0xff), Int((c >> 8) & 0xff), Int(c & 0xff))
end
"The lines of the page that show as text"
texts() = [e.buf.lines[it.first] for it in e.layout if it.content isa K.Flow]
"The part of the page that shows the icons of the files that came with the email, or nothing"
files() = (i = findfirst(it -> it.content isa K.Live && it.content.node isa K.AttachedFiles, e.layout); i === nothing ? nothing : e.layout[i])

@testset "an email with HTML shows as it was sent" begin
  @test shows() && Fake.calls == [asked(LINKS)]
  it = item()
  # The pictures stand for the email's words, and for nothing else of the page
  t = K.front_matter(e.buf.lines)
  @test it.first == t + 1 && e.buf.lines[it.last+1] == "[Roof quote.pdf]($(K.Eml.attachments(quote_email))/Roof%20quote.pdf)"
  @test !any(l -> occursin("quote", l) && occursin("Hi Jake", l), texts())
  # The link to the file shows as the file's icon
  @test !any(l -> occursin("Roof quote.pdf", l), texts()) && files().first == files().last == it.last + 1
  # They're as wide as the page's text, and as tall as the program made them
  r = page()
  @test K.num(r.width) == wide() + 2 && K.num(r.height) == 402
  @test colour(spot(300, 200)) == Fake.colour(false)
  # The card of the email is over them, and the link to the file under them
  @test e.layout[1].first == 1 && e.layout[1].top < it.top && e.layout[end].top >= it.top + it.tall - 1px
  # An email with nothing from the web has no button that fetches it
  @test !sent().remote && !haskey(sent().parts, (:button, :pictures))
  shot("sent-1-email.png")
end

@testset "a link of the email opens, and the mouse over it says where it goes" begin
  empty!(Fake.opened)
  area = sent().parts[:page]
  at(link(1))
  @test K.cursor(area) == :hand && K.sent_link(area).url == "https://example.com/quote?job=7&v=2" && !isempty(popups(w))
  shot("sent-2-over-a-link.png")
  click(link(1))
  @test Fake.opened == ["https://example.com/quote?job=7&v=2"]
  click(link(2))
  @test Fake.opened[end] == "mailto:sam@example.com" && length(Fake.opened) == 2
  # Beside the links, the email is a picture: a click there opens nothing
  at(spot(300, 300))
  @test K.cursor(area) == :arrow && K.sent_link(area) === nothing
  click(spot(300, 300))
  @test length(Fake.opened) == 2 && shows()
  # What a tooltip says of an address
  @test K.sent_address("mailto:sam@example.com") == "sam@example.com" && K.sent_address("https://example.com/a") == "https://example.com/a"
  long = "https://example.com/" * "a"^200 * "/end"
  @test length(K.sent_address(long)) == 86 && startswith(K.sent_address(long), "https://example.com/aaa") && endswith(K.sent_address(long), "aaa/end")
end

@testset "down a level, the email shows its words, and up again its pictures" begin
  n = length(Fake.calls)
  # Each stop's tip is of its own level
  @test K.stop_tip(e, 2) == "The window shows the HTML email. A click goes down a level  ⌘E"
  @test K.stop_tip(e, 1) == "Show plain text email  ⌘E" == K.tip(e.nodes[:mode])
  K.level!(e); frames()
  @test e.plain && item() === nothing && any(l -> occursin("Hi Jake, the [quote]", l), texts())
  @test K.stop_tip(e, 2) == "Show HTML email  ⌘E" == K.tip(e.nodes[:mode])
  @test K.stop_tip(e, 1) == "The window shows the plain text email"
  shot("sent-3-words.png")
  K.level!(e); frames()
  # The pictures are kept, so no program runs for them again
  @test !e.plain && shows() && length(Fake.calls) == n
end

@testset "while the find bar is open, the email shows its words" begin
  K.open_find!(e); frames()
  @test item() === nothing && any(l -> occursin("Hi Jake", l), texts())
  K.close_find!(e); frames()
  @test shows()
end

@testset "the files that came with an email show as icons, and a click opens one" begin
  it = files()
  f = it.content.node.files[1]
  path = joinpath(K.Eml.attachments(quote_email), "Roof quote.pdf")
  @test f.name == "Roof quote.pdf" && f.path == path && f.lines == ["Roof quote.pdf"] && !f.cut && f.bytes == "9 bytes"
  @test K.file_icon(f.path) == "file-earmark-pdf"
  # The icon is under the email, at the left of the page's text
  r = rect(f)
  @test r.top >= page().top + page().height && abs(K.num(r.left - page().left)) <= 1
  at(middle(r))
  @test K.cursor(f) == :hand && K.ishovered(f)
  shot("sent-7-files.png")
  click(middle(r))
  @test e.buf.path == path
  # Down a level, the email shows the link as it's written
  show(quote_email)
  K.level!(e); frames()
  @test files() === nothing && any(l -> occursin("[Roof quote.pdf]", l), texts())
  K.level!(e); frames()
  @test files() !== nothing
end

@testset "many files go on in the next row, and a long name on two lines" begin
  pdf(name) = "--m\r\nContent-Type: application/pdf; name=\"$name\"\r\nContent-Disposition: attachment; filename=\"$name\"\r\n" *
              "Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjcK\r\n"
  names = ["Invoice-VQHURGAU-0001.pdf", "Receipt-2443-7647-3599.pdf", "A very long name of a file that goes on and on and on.pdf", "Plan.zip"]
  path = joinpath(dir, "Files.eml")
  write(path, "From: Sam Lee <sam@example.com>\r\nTo: you@example.com\r\nSubject: Files\r\nDate: Sat, 14 Nov 2026 09:32:00 +1100\r\n" *
              "MIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Four files</p>\r\n" *
              join(pdf.(names)) * "--m--\r\n")
  show(path)
  it = files()
  v = it.content.node
  @test [f.name for f in v.files] == names && it.last == length(e.buf.lines)
  shot("sent-8-four-files.png")
  # A name that's too wide goes on two lines. One that's too long for two loses letters from its middle, and keeps its end.
  @test length(v.files[1].lines) == 2 && join(v.files[1].lines) == names[1] && !v.files[1].cut
  long = v.files[3]
  @test long.cut && length(long.lines) == 2 && occursin("…", long.lines[2]) && endswith(long.lines[2], ".pdf")
  @test K.file_icon(v.files[4].path) == "file-earmark-zip"
  # Each file is in the same row while they fit across, and they go on in the next row when they don't
  tops() = [rect(f).top for f in v.files]
  @test length(unique(tops())) == 1
  was = e.widest
  K.page_width!(e, 300); frames()
  @test length(unique(tops())) == 2 && files().tall > it.tall
  shot("sent-9-two-rows.png")
  e.widest = was; K.rewrap!(e); frames()
  show(quote_email)
end

@testset "an email asks the web for nothing until you click Load pictures" begin
  show(logo_email)
  html = K.Eml.webpage(logo_email)
  @test shows() && sent().remote && !sent().pictures && Fake.calls[end] == asked(html) && colour(spot(300, 200)) == Fake.colour(false)
  @test !isfile(K.sent_mark(logo_email))
  button = sent().parts[(:button, :pictures)]
  top = page().top
  @test button.words == "Load pictures" && rect(button).top < top
  shot("sent-4-no-pictures.png")
  click(middle(rect(button)))
  @test until(() -> sent().shown.want[3])
  frames()
  @test sent().pictures && Fake.calls[end] == asked(html, pictures=true) && colour(spot(300, 200)) == Fake.colour(true)
  # The button has gone, so the email is where the button was
  @test page().top < top && isfile(K.sent_mark(logo_email))
  shot("sent-5-pictures.png")
  # The email shows its pictures from then on, in a new window too, and with no program
  n = length(Fake.calls)
  other = K.build_editor(logo_email)
  second = Window(other, size=(1000px, 900px))
  foreach(_ -> frame(second), 1:3)
  v = other.nodes[:sent_email]
  @test v.pictures && v.shown !== nothing && v.shown.want[3] && length(Fake.calls) == n
end

@testset "an email with no HTML shows its words" begin
  n = length(Fake.calls)
  show(plain_email)
  @test item() === nothing && any(==("No HTML here."), texts()) && length(Fake.calls) == n
  @test K.sent_html(e) === nothing && K.level_names(e) == K.PAGE_LEVELS
  # A page that isn't an email has nothing to do with any of this
  note = joinpath(dir, "note.md")
  write(note, "# A note\n\nSome words.\n")
  show(note)
  @test item() === nothing && K.level_names(e) == K.PAGE_LEVELS && length(Fake.calls) == n
end

@testset "a tall email is drawn in strips, one under the other" begin
  show(tall_email)
  @test shows() && length(sent().keys) == 2 && last.(sent().shown.shot.strips) == [1024, 476]
  @test K.num(page().height) == 1502 && item().tall >= 1500px
  @test colour(spot(300, 200)) == Fake.colour(false, 1)
  # The second strip is under the first
  e.scroll.offset = item().top + 900px; frames()
  @test colour(spot(300, 1100)) == Fake.colour(false, 2)
  shot("sent-6-strips.png")
end

@testset "another width gets other pictures, once it has stayed a moment" begin
  show(quote_email)
  was = wide()
  n = length(Fake.calls)
  K.page_width!(e, 500); frames(1)
  @test wide() != was
  # The pictures that were made for the width before show, as wide as the page is now
  @test shows() && sent().shown.want[1] == was && K.num(page().width) == wide() + 2 && length(Fake.calls) == n
  @test until(() -> sent().shown.want[1] == wide())
  @test Fake.calls[end] == asked(LINKS) && length(Fake.calls) == n + 1
  # A bigger text size makes everything in the email bigger
  z = e.zoom
  K.zoom!(e, 1.25); frames(1)
  @test until(() -> sent().shown.want[2] == 1.25) && Fake.calls[end] == asked(LINKS, zoom=1.25)
  K.zoom!(e, z); K.page_width!(e, was); frames()
  @test until(() -> sent().shown.want[1:2] == (was, round(Float64(z), digits=2)))
end

@testset "an email whose pictures can't be made shows its words, and the ladder says why" begin
  Fake.offline[] = true
  show(email("No luck", "<p>These words show all the same.</p>"))
  @test item() === nothing && any(==("These words show all the same."), texts())
  @test K.stop_tip(e, 2) == W.FAILED
  Fake.offline[] = false
  # Pictures that aren't whole are no pictures
  Fake.broken[] = true
  show(email("Cut short", "<p>These words show too.</p>"))
  @test item() === nothing && any(==("These words show too."), texts()) && K.stop_tip(e, 2) == W.FAILED
  Fake.broken[] = false
end

@testset "while the first pictures are made, the email has an empty space" begin
  Fake.slow[] = true
  show(email("Slow", "<p>These words wait.</p>"), 1)
  it = item()
  @test it !== nothing && sent().shown === nothing && sent().got.state == :coming
  @test !any(==("These words wait."), texts()) && abs(K.num(page().height) - K.num(K.SENT_EMPTY)) <= 1
  @test until(shows) && K.num(page().height) == 402
  Fake.slow[] = false
end

@testset "a window that isn't on the screen runs no program" begin
  W.HELPER[] = W.run_program
  n = length(K.Maps.jobs)
  show(email("Fresh", "<p>Fresh words.</p>"))
  @test item() === nothing && sent().got.state == :none && length(K.Maps.jobs) == n && any(==("Fresh words."), texts())
  W.HELPER[] = Fake.helper
end
