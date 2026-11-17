# Tests for the `map` block of main.jl: the map of a place, its buttons, a
# drag that moves the map, a click that moves the place, and what the block
# shows while the picture isn't there. Run them with
# `julia -O0 --project=. test/map_view_test.jl`. They click in a window that
# isn't on the screen. They use neither the network nor the program that
# makes a picture of a map, and they open no app: map_fake.jl takes the
# place of both. Set `KAYDOWN_SHOTS` to a folder, and they save pictures of
# the page there.

@use Test: @test, @testset
@use "../main" => K
@use "./map_fake" => Fake
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
const px = K.px
const M = K.Maps

M.HELPER[] = Fake.helper
M.OPENER[] = Fake.opener
K.MEDIA_CACHE[] = mktempdir()   # the pictures are kept here, and not in the Mac's caches

const WATTLE = "8 Wattle Street, Brunswick VIC 3056"
const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# The job at Wattle Street

```map
$WATTLE
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
view(n=1) = e.nodes[(:block, K.MAP, page, n)]
shot(name, window=w) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), window)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at((from .+ to) ./ 2); at(to); release())
key(k, held=Keys(0)) = (w.keys = held; onkey(w, KeyPress{k}(0, w)); w.keys = Keys(0); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(name, n=1) = click(middle(rect(view(n).parts[(:button, name)])))
block(n=1) = (s = K.block_lines(e.buf, K.MAP, n); e.buf.lines[s[1]+1:s[2]-1])
wide() = round(Int, K.num(e.width))
"The file that keeps a picture of the page's width"
kept(place, zoom=15; dark=false, centre=nothing) = M.file(K.media_dir(), place, zoom, wide(), M.TALL, dark, centre)
"True when the page's first map shows that picture"
shows(place, zoom=15; kw...) = (s = view().shown; s !== nothing && s.file == kept(place, zoom; kw...) && s.zoom == zoom)
"What the helper is asked for a picture of the page's width"
asked(place, zoom=15; dark=false, centre=nothing) = (place=place, zoom=zoom, wide=wide(), tall=280, dark=dark, centre=centre)
"Where the picture of the page's first map is in the window"
area() = rect(view().parts[:area])
"The latitude and the longitude at a place of the window, on a map whose middle is `centre`"
under(place, centre, zoom=15) = (r = area(); M.latlon(place .- (K.num(r.left), K.num(r.top)), centre, zoom, K.num(r.width), K.num(r.height)))
"Draw frames until `done()` is true, for 10 seconds at most"
until(done) = (t = time(); while !done() && time() - t < 10; sleep(0.02); frames(1); end; done())
"The red, the green and the blue of the window's pixel at each of some places, as the window was last drawn"
colours(places...) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  dots = pixels(file)
  k = size(dots, 2) / K.num(K.window_size(e)[1])
  map(places) do (x, y)
    c = dots[round(Int, y * k), round(Int, x * k)]
    (Int((c >> 16) & 0xff), Int((c >> 8) & 0xff), Int(c & 0xff))
  end
end
colour(place) = colours(place)[1]
"True for the red of the pin: the dot that the fake draws on the place, and the pin that Kaydown draws"
red(c) = all(abs.(c .- (232, 66, 54)) .< 14)
"Write `lines` as the lines of the page's first map, as typing them does"
rewrite(lines...) = (K.write_block!(view(), K.MAP, String[lines...]); frames())
"The button beside the top right corner of the map that makes it fill the window, or nothing while it doesn't show"
corner() = (f = get(K.fills(e), objectid(view()), nothing); f === nothing || f.button === nothing || rect(f.button) === nothing ? nothing : f.button)

@testset "the map shows the picture of its place" begin
  v = view()
  @test Fake.calls == [asked(WATTLE)]
  @test shows(WATTLE) && isfile(kept(WATTLE)) && K.map_words(v) == ""
  @test v.shown.pin == Fake.ADDRESS && v.shown.centre == Fake.ADDRESS && K.map_middle(v) == Fake.ADDRESS
  # The picture is as wide as the page's text, but for the line round the block, and 280 px tall
  r = area()
  @test r.height == 280px && e.width - 4px <= r.width <= e.width
  # The fake picture has a red dot on the place, which is in the middle of the map
  @test red(colour(middle(r)))
  # The address that Apple has for the place is under the map
  @test K.map_address(v) == "$WATTLE, Australia"
  @test rect(v.parts[(:button, :open)]).top > r.top + r.height - 1px
  # The two buttons are on the map, in its top right corner. A map with its place in the middle has no third one.
  less, more = rect(v.parts[(:button, :out)]), rect(v.parts[(:button, :in)])
  @test r.top < less.top < r.top + 20px && less.left < more.left && r.left + r.width - 60px < more.left + more.width < r.left + r.width
  @test !haskey(v.parts, (:button, :home))
  @test any(en -> en.title == "Map", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Map", K.INSERTS)
  @test K.Searches.block_kind(K.MAP) == :map
  # The mouse over a map that a drag can move is a hand
  @test K.map_moves(v) && K.cursor(v.parts[:area]) == :hand
  # More frames ask for nothing more, and the file is as it was
  frames(5)
  @test length(Fake.calls) == 1 && !K.dirty(e.buf) && block() == [WATTLE]
  shot("map.png")
end

@testset "the + and the − change how much the map shows" begin
  v = view()
  button(:in)
  @test block() == [WATTLE, "zoom: 16"] && v.data.zoom == 16 && K.dirty(e.buf)
  @test Fake.calls[end] == asked(WATTLE, 16) && shows(WATTLE, 16)
  button(:out); button(:out)
  @test block() == [WATTLE, "zoom: 14"] && shows(WATTLE, 14) && length(Fake.calls) == 3
  # ⌘Z takes each change back, and the map of that zoom is kept, so nothing is asked for again
  K.undo!(e.buf); frames()
  @test block() == [WATTLE, "zoom: 15"] && shows(WATTLE)
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test block() == [WATTLE] && v.data.zoom == 15 && length(Fake.calls) == 3
  # At the least zoom, the − does nothing, and at the most, the + does nothing
  rewrite(WATTLE, "zoom: $(first(M.ZOOMS))")
  @test v.parts[(:button, :out)].off && !v.parts[(:button, :in)].off
  button(:out)
  @test block() == [WATTLE, "zoom: $(first(M.ZOOMS))"]
  rewrite(WATTLE, "zoom: $(last(M.ZOOMS))")
  @test v.parts[(:button, :in)].off
  button(:in)
  @test block() == [WATTLE, "zoom: $(last(M.ZOOMS))"]
  # A line that the block doesn't know stays where it is
  rewrite(WATTLE, "The back gate")
  button(:in)
  @test block() == [WATTLE, "zoom: 16", "The back gate"]
  rewrite(WATTLE)
end

@testset "Open in Maps" begin
  empty!(Fake.opened)
  button(:open)
  @test Fake.opened == ["maps://?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056"] && block() == [WATTLE]
end

@testset "a drag moves the map" begin
  v = view()
  m = middle(area())
  caret, scrolled, n = e.buf.caret, e.scroll.offset, length(Fake.calls)
  press(m); at(m .+ (60, -20)); at(m .+ (120, -40))
  # The picture moves with the mouse, and the pin with it. Nothing is written or asked for until the mouse lets go.
  @test red(colour(m .+ (120, -40))) && !red(colour(m)) && block() == [WATTLE] && length(Fake.calls) == n && v.at !== nothing
  shot("map-dragging.png")
  release()
  # The middle of what shows is the block's centre line, and the picture for that middle is asked for
  c = M.rounded(M.moved(Fake.ADDRESS, 120, -40, 15))
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && v.data.centre == c && v.at === nothing && v.grab === nothing
  @test Fake.calls[end] == asked(WATTLE, centre=c) && length(Fake.calls) == n + 1 && shows(WATTLE, centre=c)
  # The pin stays on the place, which is where the drag left it
  @test red(colour(m .+ (120, -40))) && !red(colour(m)) && K.map_address(v) == "$WATTLE, Australia"
  shot("map-dragged.png")
  # The page of HTML has the picture with that middle
  @test occursin(M.data_uri(kept(WATTLE, centre=c)), K.page_html(e))
  # The + keeps the middle
  button(:in)
  @test block() == [WATTLE, "zoom: 16", "centre: " * M.text(c)] && Fake.calls[end] == asked(WATTLE, 16, centre=c)
  button(:out)
  # A drag that leaves the map and lets go over the page's text moves the map all the same. It selects no text and scrolls nothing.
  to = (200.0, 560.0)
  press(m); at(m .+ (-100, 80)); at(to)
  @test v.at !== nothing && e.buf.caret == caret && e.buf.anchor == caret
  release()
  c2 = M.rounded(M.moved(c, (to .- m)..., 15))
  @test block()[3] == "centre: " * M.text(c2) && v.grab === nothing && shows(WATTLE, centre=c2)
  @test e.buf.caret == caret && e.buf.anchor == caret && e.scroll.offset == scrolled && w.focus === e
  # And so does one that leaves the map and comes back
  press(m); at(to); at((900.0, 120.0)); at(m .+ (30, 30)); release()
  c3 = M.rounded(M.moved(c2, 30, 30, 15))
  @test block()[3] == "centre: " * M.text(c3) && e.buf.caret == caret && e.buf.anchor == caret && e.scroll.offset == scrolled
  # ⌘Z takes back each drag, and then the two changes of zoom and the first drag
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c2)] && shows(WATTLE, centre=c2)
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && shows(WATTLE, centre=c)
  key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd); key(Keys.z, Keys.cmd)
  @test block() == [WATTLE] && shows(WATTLE) && red(colour(m)) && v.data.centre === nothing
end

@testset "a click moves the place" begin
  v = view()
  m = middle(area())
  p = m .+ (150, -60)
  n = length(Fake.calls)
  Fake.slow[] = true
  click(p)
  # The place is the latitude and the longitude of the point that was clicked. The middle that showed is written too, so the map stays still.
  clicked = M.text(under(p, Fake.ADDRESS))
  home = M.rounded(Fake.ADDRESS)
  @test block() == [clicked, "zoom: 15", "centre: " * M.text(home)] && Fake.calls[end] == asked(clicked, centre=home) && length(Fake.calls) == n + 1
  # Until the picture of the new place is there, the old picture stays where it is, and a pin is on the new place at once
  @test v.shown.file == kept(WATTLE) && K.map_words(v) == "" && K.map_address(v) == clicked
  old, head, dot = colours(m, p .+ (-7, -26), p .+ (0, -26))
  @test red(old) && red(head) && dot == (255, 255, 255)
  shot("map-clicked.png")
  @test until(() -> shows(clicked, centre=home))
  Fake.slow[] = false
  # Then the pin is where the click was, and the address is the one that Apple has for that point
  @test red(colour(p)) && !red(colour(m)) && K.map_address(v) == "1 Found Street, Brunswick VIC 3056, Australia"
  @test K.map_pin(v) == M.coordinates(clicked) && K.map_middle(v) == home
  shot("map-moved.png")
  # ⌘Z brings the old place back, with the place in the middle
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE] && shows(WATTLE) && red(colour(m))
  # A block that has a centre line keeps it. A press and a release 2 px apart are still a click.
  drag(m, m .+ (90, 0))
  c = v.data.centre
  @test c == M.rounded(M.moved(Fake.ADDRESS, 90, 0, 15))
  press(p); at(p .+ (2, 1)); release()
  @test block() == [M.text(under(p, c)), "zoom: 15", "centre: " * M.text(c)] && red(colour(p))
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && red(colour(m .+ (90, 0)))
  # With ⌥ held, a click shows the block's lines, as it does on any block
  s = K.block_lines(e.buf, K.MAP, 1)[1]
  w.keys = Keys.opt
  click(m)
  w.keys = Keys(0); frames()
  @test K.item(e, s + 1).content isa K.Flow && block()[1] == WATTLE
  e.buf.caret = e.buf.anchor = (1, 0); K.touch!(e); frames()
  @test K.item(e, s).content isa K.Live
end

@testset "a button puts the place back in the middle" begin
  v = view()
  m = middle(area())
  c = v.data.centre
  @test c !== nothing && red(colour(m .+ (90, 0)))
  # The third button is beside the − and the +
  home, less = rect(v.parts[(:button, :home)]), rect(v.parts[(:button, :out)])
  @test home !== nothing && home.left < less.left && home.top == less.top && !isempty(v.parts[(:button, :home)].tip)
  shot("map-home.png")
  button(:home)
  @test block() == [WATTLE, "zoom: 15"] && v.data.centre === nothing && shows(WATTLE) && red(colour(m))
  @test rect(v.parts[(:button, :home)]) === nothing
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(c)] && rect(v.parts[(:button, :home)]) !== nothing
  rewrite(WATTLE)
end

@testset "the button beside the map, and Return, make it fill the window" begin
  v = view()
  m = middle(area())
  # A click on the map doesn't fill the window any more: it moves the place
  @test K.zooming(e) === nothing
  # The button shows beside the map's top right corner while the mouse is over the map
  at(m); frames()
  @test corner() !== nothing
  click(middle(rect(corner())))
  z = K.zooming(e)
  @test z !== nothing && z.what == (:picture, kept(WATTLE)) && K.subject_size(z) == (2.0wide(), 560.0)
  frames()
  shot("map-full.png")
  # A drag there moves the picture in the window, as it does for any picture, and changes nothing in the block
  drag(m, m .+ (80, 40))
  @test block() == [WATTLE] && v.grab === nothing
  key(Keys.escape)
  @test K.zooming(e) === nothing && w.focus === e
  # With the caret on the map as a whole, Return makes it fill the window too
  s, t = K.block_lines(e.buf, K.MAP, 1)
  e.buf.caret = e.buf.anchor = (s - 1, 0); K.touch!(e); frames()
  key(Keys.down)
  @test K.picked(e.buf) == (s, t)
  key(Keys.enter)
  @test K.zooming(e) !== nothing
  key(Keys.escape)
  e.buf.caret = e.buf.anchor = (1, 0); K.touch!(e); frames()
  @test K.zooming(e) === nothing && block() == [WATTLE]
end

@testset "while the picture is made, the block is a grey box" begin
  v = view()
  tall = rect(v).height
  rewrite("12 Slow Street, Kew")
  @test !K.map_shows(v) && K.map_words(v) == "Finding the place…" && v.got[1].state == :coming
  @test rect(v).height == tall && K.map_address(v) == "12 Slow Street, Kew" && K.cursor(v.parts[:area]) == :arrow
  shot("map-finding.png")
  # A click and a drag on the grey box change nothing
  click(middle(area()) .+ (0, 60))
  drag(middle(area()), middle(area()) .+ (70, 20))
  @test K.zooming(e) === nothing && block() == ["12 Slow Street, Kew"]
  # The window draws again by itself, and the picture shows when it's there
  @test until(() -> K.map_shows(v))
  @test K.map_words(v) == "" && K.map_address(v) == "12 Slow Street, Kew, Australia" && K.cursor(v.parts[:area]) == :hand
  # Until the picture of another zoom is there, the picture of the last zoom shows in its place
  button(:in)
  @test shows("12 Slow Street, Kew") && v.data.zoom == 16 && K.map_words(v) == ""
  @test until(() -> v.shown.zoom == 16)
end

@testset "a place that can't be shown" begin
  v = view()
  rewrite("1 Nowhere Road, Atlantis")
  @test !K.map_shows(v) && K.map_words(v) == M.LOST && K.map_address(v) == "1 Nowhere Road, Atlantis"
  shot("map-lost.png")
  n = length(Fake.calls)
  frames(5)
  @test length(Fake.calls) == n   # Kaydown doesn't ask again
  html = K.page_html(e)
  @test !occursin("<img", html) && occursin("<a href=\"https://maps.apple.com/?q=1%20Nowhere%20Road%2C%20Atlantis\">1 Nowhere Road, Atlantis</a>", html)
  # No network
  rewrite("1 Offline Road, Kew")
  @test K.map_words(v) == M.FAILED * " It tries again in a minute." && v.got[1].state == :failed
  shot("map-failed.png")
  # A file that's no picture is taken away
  rewrite("1 Broken Road, Kew")
  @test !K.map_shows(v) && v.got[1].state == :failed && !isfile(kept("1 Broken Road, Kew"))
  # A latitude and a longitude show the address that Apple has for them
  rewrite("-37.7701, 144.9610", "zoom: far")
  @test shows("-37.7701, 144.9610") && K.map_address(v) == "1 Found Street, Brunswick VIC 3056, Australia"
  @test Fake.calls[end].place == "-37.7701, 144.9610" && K.map_pin(v) == (-37.7701, 144.961)
  # A middle that's no latitude and longitude is left out, and the place is in the middle
  rewrite("-37.7701, 144.9610", "centre: the park")
  @test shows("-37.7701, 144.9610") && red(colour(middle(area())))
  # An empty block says what to write in it, and has no buttons
  rewrite()
  @test isempty(block()) && rect(v).height < 100px
  shot("map-empty.png")
  @test K.page_html(e) !== nothing
  rewrite("zoom: 12")
  @test rect(v).height < 100px
  rewrite(WATTLE)
  @test shows(WATTLE)
end

@testset "a dark page has a dark map" begin
  v = view()
  K.theme!(e, :night); frames()
  @test Fake.calls[end] == asked(WATTLE, dark=true) && shows(WATTLE, dark=true)
  shot("map-dark.png")
  # The page of HTML is light, so it has the light map
  @test occursin(M.data_uri(kept(WATTLE)), K.page_html(e))
  K.theme!(e, :sepia); frames()
  @test shows(WATTLE)
end

@testset "the map as HTML" begin
  html = K.page_html(e)
  @test occursin("<img src=\"data:image/png;base64,iVBOR", html) && occursin("alt=\"A map of $WATTLE, Australia\" width=\"$(wide())\">", html)
  @test occursin("<p><a href=\"https://maps.apple.com/?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056\">$WATTLE, Australia</a></p>", html)
end

@testset "a page that can't be changed takes no drag and no click" begin
  locked = joinpath(dir, "locked.md")
  text = "# Locked\n\n```map\n$WATTLE\n```\n\nThe end.\n"
  write(locked, text)
  chmod(locked, 0o444)
  K.open!(e, locked); frames(3)
  v = e.nodes[(:block, K.MAP, locked, 1)]
  @test e.buf.fixed && K.map_shows(v) && !K.map_moves(v) && K.cursor(v.parts[:area]) == :arrow
  m = middle(rect(v.parts[:area]))
  n = length(Fake.calls)
  drag(m, m .+ (80, 30))
  click(m .+ (100, -50))
  @test v.grab === nothing && v.at === nothing && v.data.centre === nothing && v.data.place == WATTLE && length(Fake.calls) == n
  @test e.buf.lines[4] == WATTLE && !K.dirty(e.buf) && read(locked, String) == text && red(colour(m))
  shot("map-locked.png")
  K.open!(e, page); frames(3)
  @test shows(WATTLE) && K.map_moves(view())
end

@testset "a page of another width" begin
  v = view()
  n = length(Fake.calls)
  was = wide()
  K.page_width!(e, 420); frames()
  # The picture of the old width shows, and no other is asked for until the width has stayed for a moment
  @test wide() < was && length(Fake.calls) == n && v.shown.file == M.file(K.media_dir(), WATTLE, 15, was, 280, false)
  @test until(() -> length(Fake.calls) > n)
  @test Fake.calls[end].wide == wide() && shows(WATTLE)
  shot("map-narrow.png")
  # A drag works there too
  m = middle(area())
  drag(m, m .+ (-50, 40))
  @test block() == [WATTLE, "zoom: 15", "centre: " * M.text(M.rounded(M.moved(Fake.ADDRESS, -50, 40, 15)))] && red(colour(m .+ (-50, 40)))
  shot("map-narrow-dragged.png")
  key(Keys.z, Keys.cmd)
  @test block() == [WATTLE]
  # Paper has another width again. The page prints with the picture that's kept, and asks for no other.
  n = length(Fake.calls)
  @test length(K.print_pdf(e)) > 1000 && length(Fake.calls) == n
  frames()
  @test length(Fake.calls) == n && shows(WATTLE)
end

@testset "a window that isn't on the screen runs no program and opens no app" begin
  v = view()
  M.HELPER[], M.OPENER[] = M.run_program, M.open_app
  empty!(M.jobs)
  n = length(Fake.calls)
  rewrite("77 Fresh Street, Kew")
  frames(3)
  @test isempty(M.jobs) && length(Fake.calls) == n && K.map_words(v) == M.FAILED && v.got[1].state == :none
  # A picture that's kept shows all the same
  rewrite(WATTLE)
  @test shows(WATTLE)
  button(:open)
  @test length(Fake.opened) == 1
  M.HELPER[], M.OPENER[] = Fake.helper, Fake.opener
end
