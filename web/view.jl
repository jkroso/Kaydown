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
#
# With `scripts=true`, the page's scripts run: see live.jl. A click is told to
# the scripts first, and a link opens unless a script said to do no more. The
# page's timers run when they're due, and the page is laid out again after a
# script changes it. `say(level, text)` is called with each line that a script
# prints, and `v.live.scripts.log` keeps them.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" onkey KeyPress Keys flt
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific" ConcreteRect
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe handled window_of
@use "github.com/jkroso/UI.jl/Interface/draw" draw cursor open_url rect redraw_in!
@use "./main" => Web
@use "./live" => Live

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
  scripts::Bool = false   # run the page's scripts
  say::Any = (level, text) -> nothing   # called with each line that a script prints
  live::Any = nothing     # the page with its scripts running
  started::Any = nothing  # what its scripts were started for
end

"The page of `v`, laid out for its HTML, its width and its zoom as they are now"
page!(v::View) = begin
  want = (hash(v.html), Float64(flt(v.wide)), v.zoom, v.fit, v.css, v.high, v.base)
  v.scripts && return running!(v, want)
  if v.live !== nothing
    close(v.live)
    v.live = v.made = nothing
  end
  if v.made != want
    v.page = Web.page(v.html; wide=want[2], zoom=v.zoom, fit=v.fit, css=v.css, load=v.load, high=v.high, base=v.base)
    v.made = want
  end
  v.page
end

"The page of `v` as its scripts have left it. Its timers that are due run first."
running!(v::View, want) = begin
  # The scripts start again for another page. For another width, they're told that the window changed.
  key = (want[1], v.fit, v.css, v.base)
  if v.live === nothing || v.started != key
    v.live === nothing || close(v.live)
    v.live = Live.live(v.html; wide=want[2], zoom=v.zoom, fit=v.fit, css=v.css, load=v.load, high=v.high, base=v.base, say=v.say)
    v.started = key
  else
    resize!(v.live, want[2]; high=v.high, zoom=v.zoom)
  end
  wait = Live.step!(v.live)
  # A window draws only when something asks, so the next timer asks. A script that waits for the next frame gets 60 a second.
  wait === nothing || redraw_in!(v, max(wait, 1 / 60))
  v.made = want
  v.page = Live.page!(v.live)
end

describe(v::View) = (p = page!(v); Box(width(v.wide), height(px(p.tall))))

draw(ctx, size, ui::ConcreteRect, v::View) = v.page === nothing || Web.draw(ctx, v.page; x=Float64(flt(ui.left)), y=Float64(flt(ui.top)))

"The point of the page that the mouse is over, or nothing"
point(v::View) = begin
  w = window_of(v)
  (w === nothing || v.page === nothing) && return nothing
  r = rect(v)
  r === nothing && return nothing
  # A page that's wider than `wide` is drawn at its own size, so a px of it is a px of the window
  (Float64(flt(w.mouse[1] - r.left)), Float64(flt(w.mouse[2] - r.top)))
end

"The link of the page that the mouse is over, or nothing"
link(v::View) = (at = point(v); at === nothing ? nothing : Web.link(v.page, at...))

cursor(v::View) = link(v) === nothing ? :arrow : :hand
onkey(v::View, ::KeyPress{Keys.mouse_left}) = begin
  at = point(v)
  at === nothing && return
  if v.live !== nothing
    go = Live.click!(v.live, at...)
    # A script that heard the click may have changed the page
    redraw_in!(v, 0)
    go || return handled
  end
  l = Web.link(v.page, at...)
  l === nothing && return
  v.open(l.url)
  handled
end

export View
