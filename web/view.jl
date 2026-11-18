# A page of HTML in a window that UI.jl draws.
#
#     View(html="<p>Hi <a href='https://example.com'>there</a></p>", wide=600px)
#
# It's `wide` across and as tall as the page. The mouse is a hand over a link,
# and a click on a link calls `open(url)`, which opens it in the browser unless
# you give another function. `zoom`, `fit`, `load`, `css`, `high` and `base`
# are what `page` in main.jl takes. `v.page` is the page that's laid out, with
# its links and its words.
#
# The page is laid out again only when the HTML, the width or the zoom changes,
# so a window that redraws often costs no more than the drawing.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" onkey KeyPress Keys flt
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific" ConcreteRect
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe handled window_of
@use "github.com/jkroso/UI.jl/Interface/draw" draw cursor open_url rect
@use "./main" => Web

@def mutable struct View <: SemanticUI
  html::String = ""
  wide::px = 600px
  zoom::Float64 = 1.0
  fit::Bool = false
  css::String = ""
  load::Any = src -> nothing
  open::Any = open_url
  high::Any = nothing     # how high the window that the page is seen through is, or nothing for a page as tall as its content
  base::String = ""       # the address of the page
  page::Any = nothing     # the page that's laid out
  made::Any = nothing     # what it was laid out for
end

"The page of `v`, laid out for its HTML, its width and its zoom as they are now"
page!(v::View) = begin
  want = (hash(v.html), Float64(flt(v.wide)), v.zoom, v.fit, v.css, v.high, v.base)
  if v.made != want
    v.page = Web.page(v.html; wide=want[2], zoom=v.zoom, fit=v.fit, css=v.css, load=v.load, high=v.high, base=v.base)
    v.made = want
  end
  v.page
end

describe(v::View) = (p = page!(v); Box(width(v.wide), height(px(p.tall))))

draw(ctx, size, ui::ConcreteRect, v::View) = v.page === nothing || Web.draw(ctx, v.page; x=Float64(flt(ui.left)), y=Float64(flt(ui.top)))

"The link of the page that the mouse is over, or nothing"
link(v::View) = begin
  w = window_of(v)
  (w === nothing || v.page === nothing) && return nothing
  r = rect(v)
  r === nothing && return nothing
  # A page that's wider than `wide` is drawn at its own size, so a px of it is a px of the window
  Web.link(v.page, Float64(flt(w.mouse[1] - r.left)), Float64(flt(w.mouse[2] - r.top)))
end

cursor(v::View) = link(v) === nothing ? :arrow : :hand
onkey(v::View, ::KeyPress{Keys.mouse_left}) = begin
  l = link(v)
  l === nothing && return
  v.open(l.url)
  handled
end

export View
