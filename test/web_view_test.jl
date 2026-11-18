# Tests for web/view.jl: a page of HTML in a window that isn't on the screen.
# Run them with `julia -O0 --project=. test/web_view_test.jl`. Set
# `LADDER_SHOTS` to a folder, and they save a picture of the window there.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window Keys
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/testing" click! move!
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "../web/view" View

const HTML = """<!DOCTYPE html><body style="margin:20px;font:16px/20px Helvetica;background:#f4f4f4">
  <div style="background:white;border-radius:8px;border:1px solid #ddd;padding:16px">
  <h1 style="margin:0 0 10px;font-size:22px;line-height:26px">Your order has shipped</h1>
  <p style="margin:0 0 10px">Hello <b>Jake</b>, your order is on its way.</p>
  <a href="https://example.com/track" style="display:block;width:160px;line-height:36px;background:#0a66c2;color:white;text-align:center;border-radius:6px;text-decoration:none">Track your order</a>
  </div></body>"""

@testset "a page of HTML in a window" begin
  opened = String[]
  v = View(html=HTML, wide=400px, open=url -> push!(opened, url))
  w = Window(v, size=(400px, 300px))
  frame(w)
  r = rect(v)
  # The margin, the card's border and padding, the heading, the paragraph and the button, each with the room under it
  @test r.width == 400px && r.height == px(v.page.tall) && v.page.tall == 2 * (20 + 1 + 16) + 26 + 10 + 20 + 10 + 36
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "web-view.png"), w)
  # A click on the link opens it, and a click beside it opens nothing
  l = only(v.page.links)
  click!(w, (r.left + px(l.left + 5), r.top + px(l.top + 5)))
  @test opened == ["https://example.com/track"]
  click!(w, (r.left + px(l.left + l.wide + 20), r.top + px(l.top + 5)))
  @test length(opened) == 1
  # The page is laid out once, and again when its width changes
  page = v.page
  frame(w)
  @test v.page === page
  v.wide = 300px
  frame(w)
  @test v.page !== page && rect(v).width == 300px
end

@testset "a page with scripts in a window" begin
  opened = String[]
  said = String[]
  html = """<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica;background:white">
    <button id=b style="display:block;width:100px;height:30px">Add</button>
    <a id=stay href="https://example.com/stay" style="display:block;height:20px">stay</a>
    <a href="https://example.com/go" style="display:block;height:20px">go</a>
    <ul id=list style="margin:0"></ul>
    <script>
      var list = document.getElementById('list')
      document.getElementById('b').addEventListener('click', () => { list.appendChild(document.createElement('li')).textContent = 'item ' + list.children.length })
      document.getElementById('stay').addEventListener('click', e => { e.preventDefault(); console.log('stayed') })
      var go = false
      var timer = setInterval(() => { if (go) { clearInterval(timer); list.appendChild(document.createElement('li')).textContent = 'from a timer' } }, 10)
    </script></body>"""
  v = View(html=html, wide=300px, scripts=true, open=url -> push!(opened, url), say=(level, text) -> push!(said, text))
  w = Window(v, size=(300px, 300px))
  frame(w)
  r = rect(v)
  @test v.page.tall == 70 && r.height == 70px
  # A click that a script hears changes the page, and the window is as tall as the page is now
  click!(w, (r.left + 20px, r.top + 10px))
  frame(w)
  @test v.page.tall == 90 && rect(v).height == 90px
  # A link opens, unless a script said to do no more with the click
  click!(w, (r.left + 20px, r.top + 40px))
  @test isempty(opened) && said == ["stayed"]
  click!(w, (r.left + 20px, r.top + 60px))
  @test opened == ["https://example.com/go"]
  # The page's timer runs when it's due
  v.live.scripts.js["go"] = true
  sleep(0.05)
  frame(w)
  @test v.page.tall == 110
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "web-view-scripts.png"), w)
  # The scripts go on when the window is narrower, and they stop when the page is another
  live = v.live
  v.wide = 200px
  frame(w)
  @test v.live === live && v.page.wide == 200 && v.live.scripts.js["innerWidth"] == 200
  v.html = "<p>another</p>"
  frame(w)
  @test v.live !== live && !isopen(live)
end
