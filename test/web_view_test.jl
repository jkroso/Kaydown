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
