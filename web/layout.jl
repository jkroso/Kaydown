# Gives each box of a page its size and its place, as CSS says.
#
#     root = boxes(doc, look)
#     tall = layout!(root, 700, doc.mode)   # on a page 700 px wide. It gives how tall the page is.
#     root.x, root.y, root.width, root.height
#
# A box's place is its border's top left corner, in px from the top left
# corner of the border of the box that it's in. A block whose content is text
# has `lines`, each with its pieces: words, spaces and boxes.
#
# What's here: blocks down the page, with their margins joined as CSS joins
# them. Lines of text, broken to fit, with each piece on its line as
# `vertical-align` says. Floats, with text and tables beside them. Tables,
# with their columns as wide as their content asks. Boxes with a place of
# their own (`position: absolute`). A box with `display: flex` is laid out as a
# block.

@use "./dom" Element attr
@use "./style" Style Len px isauto ispercent border lineheight
@use "./text" Font font normal drawn advances space
@use "./box" Box Piece Span Line Gap NO_GAP floats placed inline contained blank

"What layout knows of the page"
struct Pass
  mode::Symbol                   # :standards, :limited or :quirks
  pending::Vector{Vector{Box}}   # the boxes with a place of their own that wait for the box that they're placed from
end

face(s::Style) = font(s.family, s.size, s.weight, s.italic)

"How far over and under the line that its text stands on a line of the style `s` goes"
strut(s::Style, f::Font=face(s)) = begin
  half = (lineheight(s, normal(f)) - (f.ascent + f.descent)) / 2
  (f.ascent + half, f.descent + half)
end

margin(l::Len, cw) = l.auto ? 0.0 : px(l, cw)

"Work out the margins, the padding and the borders of `b`, in a box whose content is `cw` px wide"
edges!(b::Box, cw) = begin
  s = b.style
  b.padding = map(l -> max(0.0, px(l, cw)), s.padding)
  b.border = ntuple(i -> border(s, i), 4)
  b.margin = map(l -> margin(l, cw), s.margin)
  b
end

across(t::NTuple{4,Float64}) = t[2] + t[4]
down(t::NTuple{4,Float64}) = t[1] + t[3]
"How much of the width of `b` its padding and its borders take"
chrome(b::Box) = across(b.padding) + across(b.border)

# --- floats -------------------------------------------------------------------------------

"The floats of a flow: the margin edges of each, as its left, top, right and bottom"
mutable struct Flow
  lefts::Vector{NTuple{4,Float64}}
  rights::Vector{NTuple{4,Float64}}
  top::Float64    # the top of the last float. One that comes later is no higher.
end
Flow() = Flow(NTuple{4,Float64}[], NTuple{4,Float64}[], -Inf)

"The left and the right edge of the room between the floats, from `y1` down to `y2`, in a box from `x1` to `x2`"
band(f::Flow, y1, y2, x1, x2) = begin
  l, r = x1, x2
  for (a, b, c, d) in f.lefts
    b < y2 && d > y1 && d > b && c > a && (l = max(l, c))
  end
  for (a, b, c, d) in f.rights
    b < y2 && d > y1 && d > b && c > a && (r = min(r, a))
  end
  (l, r)
end

"The first place under `y` where a float ends, or nothing"
next_bottom(f::Flow, y) = begin
  found = Inf
  for list in (f.lefts, f.rights), r in list
    r[4] > y && (found = min(found, r[4]))
  end
  isfinite(found) ? found : nothing
end

"Where the floats of a side, or of both, end"
clear_y(f::Flow, side::Symbol) = begin
  y = -Inf
  side in (:left, :both) && foreach(r -> y = max(y, r[4]), f.lefts)
  side in (:right, :both) && foreach(r -> y = max(y, r[4]), f.rights)
  y
end

"Find the place of the float `k`, which is laid out, in a box from `x1` to `x2`, no higher than `y`. It gives the corner of its margin."
place_float!(f::Flow, k::Box, x1, x2, y) = begin
  mw = k.width + across(k.margin)
  mh = k.height + down(k.margin)
  y = max(y, f.top)
  k.style.clear != :none && (y = max(y, clear_y(f, k.style.clear)))
  l, r = x1, x2
  while true
    l, r = band(f, y, y + max(mh, 1.0), x1, x2)
    (r - l >= mw - 0.01 || (l <= x1 && r >= x2)) && break
    ny = next_bottom(f, y)
    ny === nothing && break
    y = ny
  end
  x = k.style.float == :left ? l : r - mw
  push!(k.style.float == :left ? f.lefts : f.rights, (x, y, x + mw, y + mh))
  f.top = y
  (x, y)
end

# --- how wide a box wants to be -----------------------------------------------------------

"How narrow `b` can be with its margins, and how wide it is with them when no line is broken"
outer_extent(b::Box, p::Pass) = begin
  lo, hi = extent(b, p)
  m = margin(b.style.margin[2], 0.0) + margin(b.style.margin[4], 0.0)
  (lo + m, hi + m)
end

"""
How narrow the border of `b` can be, and how wide it is when no line of its
text is broken. Without `own`, what `b`'s own style says of its width is left
out, as it is for a cell, whose table decides.
"""
extent(b::Box, p::Pass; own=true) = begin
  own && !isnan(b.extent[1]) && return b.extent
  s = b.style
  b.kind == :table && return (b.extent = table_extent(b, p))
  pad = max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px) + border(s, 2) + border(s, 4)
  lo, hi = 0.0, 0.0
  if b.kind == :image
    hi = image_size(b, Inf)[1]
    lo = ispercent(s.width) || ispercent(s.maxwidth) ? 0.0 : hi
    return (b.extent = (lo + pad, hi + pad))
  elseif b.kind in (:block, :cell, :caption) && !isempty(b.children)
    if all(k -> inline(k) || floats(k) || placed(k), b.children)
      lo = lines!(b, p, nothing, 0.0, 0.0, 0.0; measure=:min)[2]
      hi = lines!(b, p, nothing, 0.0, 0.0, Inf; measure=:max)[2]
    else
      run = 0.0
      for k in b.children
        placed(k) && continue
        a, z = outer_extent(k, p)
        lo = max(lo, a)
        run = floats(k) ? run + z : z
        hi = max(hi, run)
        floats(k) || (run = 0.0)
      end
    end
  end
  if own
    inner(l) = max(0.0, l.px - (s.borderbox ? pad : 0.0))
    isauto(s.width) || ispercent(s.width) || (lo = hi = inner(s.width))
    ispercent(s.minwidth) || (lo = max(lo, inner(s.minwidth)); hi = max(hi, inner(s.minwidth)))
    isauto(s.maxwidth) || ispercent(s.maxwidth) || (lo = min(lo, inner(s.maxwidth)); hi = min(hi, inner(s.maxwidth)))
  end
  out = (lo + pad, hi + pad)
  own && (b.extent = out)
  out
end

# --- pictures -----------------------------------------------------------------------------

"How wide and how tall the picture of `b` is, without its padding and border, in a box whose content is `cw` px wide"
image_size(b::Box, cw) = begin
  s = b.style
  nw, nh = b.natural
  ratio = !isnan(b.shape) ? b.shape : nw > 0 && nh > 0 ? nw / nh : NaN
  known(l) = !isauto(l) && !(ispercent(l) && !isfinite(cw))
  pad = max(0.0, px(s.padding[2], cw)) + max(0.0, px(s.padding[4], cw)) + border(s, 2) + border(s, 4)
  padv = max(0.0, px(s.padding[1], cw)) + max(0.0, px(s.padding[3], cw)) + border(s, 1) + border(s, 3)
  w = known(s.width) ? max(0.0, px(s.width, cw) - (s.borderbox ? pad : 0.0)) : nothing
  h = isauto(s.height) || ispercent(s.height) ? nothing : max(0.0, s.height.px - (s.borderbox ? padv : 0.0))
  if w === nothing && h === nothing
    w, h = nw, nh
  elseif h === nothing
    h = isnan(ratio) ? nh : w / ratio
  elseif w === nothing
    w = isnan(ratio) ? nw : h * ratio
  end
  fixed = !(isauto(s.height) || ispercent(s.height))
  if known(s.maxwidth) && w > (m = max(0.0, px(s.maxwidth, cw) - (s.borderbox ? pad : 0.0)))
    fixed || w <= 0 || (h *= m / w)
    w = m
  end
  if !ispercent(s.minwidth) && w < (m = s.minwidth.px)
    fixed || w <= 0 || (h *= m / w)
    w = m
  end
  if !isauto(s.maxheight) && !ispercent(s.maxheight) && h > s.maxheight.px
    known(s.width) || h <= 0 || (w *= s.maxheight.px / h)
    h = s.maxheight.px
  end
  !ispercent(s.minheight) && h < s.minheight.px && (h = s.minheight.px)
  (w, h)
end

"Give the picture `b` its size"
image!(b::Box, cw) = begin
  edges!(b, cw)
  w, h = image_size(b, cw)
  b.width = w + chrome(b)
  b.height = h + down(b.padding) + down(b.border)
  b.baseline = NaN
  b
end

# --- blocks -------------------------------------------------------------------------------

"The width of a box from what its style says, without its padding and border, or nothing when the style says none"
said_width(b::Box, cw) = begin
  s = b.style
  (isauto(s.width) || (ispercent(s.width) && !isfinite(cw))) && return nothing
  max(0.0, px(s.width, cw) - (s.borderbox ? chrome(b) : 0.0))
end

"`w`, the width of the content of `b`, kept between its least and its greatest width"
bounded(b::Box, w, cw) = begin
  s = b.style
  inner(l) = max(0.0, px(l, cw) - (s.borderbox ? chrome(b) : 0.0))
  isauto(s.maxwidth) || (ispercent(s.maxwidth) && !isfinite(cw)) || (w = min(w, inner(s.maxwidth)))
  ispercent(s.minwidth) && !isfinite(cw) || (w = max(w, inner(s.minwidth)))
  w
end

"""
Give the block `b` its width and its side margins, in a box whose content is
`cw` px wide. `room` is how much of that is free beside floats, for a block
that can't have a float over it.
"""
block_width!(b::Box, cw; room=cw) = begin
  edges!(b, cw)
  s = b.style
  said = said_width(b, cw)
  w = said === nothing ? max(0.0, room - across(b.margin) - chrome(b)) : said
  w = bounded(b, w, cw)
  b.width = w + chrome(b)
  centre!(b, room)
end

"Give `b`, whose width is known, the side margins that its `auto` margins come to in `room` px"
centre!(b::Box, room) = begin
  s = b.style
  free = room - b.width - across(b.margin)
  free > 0 || return b
  al, ar = isauto(s.margin[4]), isauto(s.margin[2])
  al && ar ? (b.margin = (b.margin[1], free / 2, b.margin[3], free / 2)) :
  al ? (b.margin = (b.margin[1], b.margin[2], b.margin[3], free)) : nothing
  b
end

"Give `b` the width that fits its content, but no more than `room` px with its margins, and lay out what's in it"
shrink!(b::Box, cw, p::Pass; room=cw) = begin
  if b.kind == :table
    return table!(b, cw, p; room=room)
  elseif b.kind == :image
    return image!(b, cw)
  end
  edges!(b, cw)
  said = said_width(b, cw)
  if said === nothing
    lo, hi = extent(b, p)
    said = min(max(lo, room - across(b.margin)), hi) - chrome(b)
  end
  b.width = bounded(b, max(0.0, said), cw) + chrome(b)
  content!(b, p, Flow(), 0.0, 0.0)
end

"True for the box of the page's body or of a cell, in a page with no doctype: the margins that a browser gives a paragraph, a heading or a list are dropped at its top"
drops(b::Box, p::Pass) = p.mode == :quirks && b.element !== nothing && b.element.tag in ("body", "td", "th")

"""
The margin over `b` that can join with the margin of what's over it: its own,
joined with the margins of what starts where it starts. With `drop`, a margin
that a browser gave is nothing.
"""
top_gap(b::Box, cw, p::Pass; drop=false) = begin
  s = b.style
  g = drop && s.loose[1] ? NO_GAP : Gap(margin(s.margin[1], cw))
  (b.kind == :block && !contained(b) && border(s, 1) == 0 && px(s.padding[1], cw) <= 0) || return g
  drop = drop || drops(b, p)
  for k in b.children
    (placed(k) || floats(k)) && continue
    (inline(k) || k.style.clear != :none) && break
    g = join(g, top_gap(k, cw, p; drop))
    hollow(k, cw) || break
    drop && k.style.loose[2] || (g = join(g, Gap(margin(k.style.margin[3], cw))))
  end
  g
end

"True for a block with nothing in it and no height, whose top and bottom margins join"
hollow(b::Box, cw) = begin
  s = b.style
  b.kind == :block && !contained(b) && border(s, 1) == 0 && border(s, 3) == 0 && px(s.padding[1], cw) <= 0 && px(s.padding[3], cw) <= 0 &&
    (isauto(s.height) || ispercent(s.height) || s.height.px == 0) && s.minheight.px == 0 &&
    all(k -> placed(k) || floats(k) || blank(k) || hollow(k, cw), b.children)
end

"True when `b`, which is laid out, took no room, so that the margins over it and under it join"
through(b::Box) = b.kind == :block && b.height == 0 && !contained(b) && isempty(b.lines) && down(b.padding) + down(b.border) == 0

"""
Lay out what's in the block `b`, whose width is known, and give `b` its
height. `(fx, fy)` is where the corner of `b`'s border is in `flow`, the floats
that it's among. A block that keeps its own floats starts a flow of its own.
"""
content!(b::Box, p::Pass, flow::Flow, fx, fy) = begin
  s = b.style
  own = contained(b)
  own && ((flow, fx, fy) = (Flow(), 0.0, 0.0))
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  cw = max(0.0, b.width - chrome(b))
  vertical = down(b.padding) + down(b.border)
  anchor = s.position != :static || (b.element !== nothing && b.element.parent === nothing)
  anchor && push!(p.pending, Box[])
  empty!(b.lines)
  b.baseline = NaN
  if isempty(b.children)
    h, under = 0.0, NO_GAP
  elseif all(k -> inline(k) || floats(k) || placed(k), b.children)
    h = lines!(b, p, flow, fx + cx, fy + cy, cw)[1]
    under = NO_GAP
    isempty(b.lines) || (b.baseline = cy + b.lines[end].y + b.lines[end].baseline)
  else
    h, under = stack!(b, p, flow, fx + cx, fy + cy, cw)
    for k in Iterators.reverse(b.children)
      (placed(k) || floats(k) || isnan(k.baseline)) && continue
      b.baseline = k.y + k.baseline
      break
    end
  end
  # A block that keeps its floats is as tall as they are
  own && (h = max(h, clear_y(flow, :both) - cy))
  fixed = !isauto(s.height) && !ispercent(s.height)
  sinks = !own && !fixed && b.border[3] == 0 && b.padding[3] == 0 && s.minheight.px == 0
  if sinks
    b.below = join(Gap(b.margin[3]), under)
  else
    h += Base.size(under)
    b.below = Gap(b.margin[3])
  end
  inner(l) = max(0.0, l.px - (s.borderbox ? vertical : 0.0))
  # A cell is as tall as its content here. Its table makes it as tall as its style says, and its row.
  fixed && b.kind != :cell && (h = inner(s.height))
  # Browsers take no greatest height for a cell
  b.kind == :cell || isauto(s.maxheight) || ispercent(s.maxheight) || (h = min(h, inner(s.maxheight)))
  ispercent(s.minheight) || (h = max(h, inner(s.minheight)))
  b.height = h + vertical
  if anchor
    over!(b, pop!(p.pending), p)
  end
  b
end

"""
Lay out the boxes in `b` one under the other. `(x0, y0)` is where the corner of
`b`'s content is in `flow`, and `cw` is how wide the content is. It gives how
tall they are together, and the margin under the last that's still to join
with what comes next.
"""
stack!(b::Box, p::Pass, flow::Flow, x0, y0, cw) = begin
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  y = 0.0
  pending = NO_GAP
  first = true
  lifts = !contained(b) && b.border[1] == 0 && b.padding[1] == 0
  align = b.style.align
  drop = drops(b, p)
  last = nothing   # the last box in the flow
  for k in b.children
    if placed(k)
      k.x, k.y = cx, cy + y
      push!(p.pending[end], k)
      continue
    elseif k.kind == :column
      continue
    elseif floats(k)
      shrink!(k, cw, p)
      at = y0 + y + (first && lifts ? 0.0 : Base.size(pending))
      x, top = place_float!(flow, k, x0, x0 + cw, at)
      k.x, k.y = cx + (x - x0) + k.margin[4], cy + (top - y0) + k.margin[1]
      continue
    end
    g = top_gap(k, cw, p; drop=drop && first)
    ky = y + (first && lifts ? 0.0 : Base.size(join(pending, g)))
    cleared = false
    if k.style.clear != :none
      under = clear_y(flow, k.style.clear) - y0
      under > ky && ((ky, cleared) = (under, true))
    end
    kx = 0.0
    if k.kind in (:table, :image) || contained(k)
      # A table, a picture or a block with its own flow is never under a float: it's beside it, or below it
      while true
        l, r = band(flow, y0 + ky, y0 + ky + 1.0, x0, x0 + cw)
        room = r - l
        k.kind == :table ? table!(k, cw, p; room=room) : k.kind == :image ? (image!(k, cw); centre!(k, room)) : block_width!(k, cw; room=room)
        fits = k.width + across(k.margin) <= room + 0.01
        if !fits && room < cw - 0.01 && (ny = next_bottom(flow, y0 + ky)) !== nothing
          ky = ny - y0
          continue
        end
        kx = l - x0
        kx += aligned(k, align, room)
        break
      end
      k.x, k.y = cx + kx + k.margin[4], cy + ky
      k.kind == :block && content!(k, p, flow, 0.0, 0.0)
    else
      block_width!(k, cw)
      kx = aligned(k, align, cw)
      k.x, k.y = cx + kx + k.margin[4], cy + ky
      content!(k, p, flow, x0 + kx + k.margin[4], y0 + ky)
    end
    if through(k) && !cleared
      drop && first && k.style.loose[2] || (pending = join(join(pending, g), k.below))
    else
      y = ky + k.height
      pending = k.kind == :block ? k.below : Gap(k.margin[3])
      first = false
      last = k
    end
  end
  # A cell of a page with no doctype drops the margin that a browser gave the last thing in it
  drop && b.kind == :cell && last !== nothing && last.style.loose[2] && pending == Gap(last.margin[3]) && (pending = NO_GAP)
  (y, pending)
end

"How far right a block moves in `room` px because the text round it is centred or to the right with a tag's `align`"
aligned(k::Box, align::Symbol, room) = begin
  free = room - k.width - across(k.margin)
  free > 0 || return 0.0
  s = k.style
  (isauto(s.margin[2]) || isauto(s.margin[4])) && return 0.0
  align == :wk_center ? free / 2 : align == :wk_right ? free : 0.0
end

"Lay out and place the boxes with a place of their own that are placed from `b`, which is laid out"
over!(b::Box, boxes::Vector{Box}, p::Pass) = begin
  empty!(b.over)
  cbw = b.width - across(b.border)
  cbh = b.height - down(b.border)
  for k in boxes
    s = k.style
    top, right, bottom, left = s.inset
    room = cbw - (isauto(left) ? 0.0 : px(left, cbw)) - (isauto(right) ? 0.0 : px(right, cbw))
    if k.kind in (:table, :image) || isauto(left) || isauto(right) || !isauto(s.width)
      shrink!(k, cbw, p; room=max(0.0, room))
    else
      block_width!(k, cbw; room=max(0.0, room))
      content!(k, p, Flow(), 0.0, 0.0)
    end
    x = !isauto(left) ? px(left, cbw) + k.margin[4] : !isauto(right) ? cbw - px(right, cbw) - k.width - k.margin[2] : k.margin[4]
    y = !isauto(top) ? px(top, cbh) + k.margin[1] : !isauto(bottom) ? cbh - px(bottom, cbh) - k.height - k.margin[3] : k.margin[1]
    k.x, k.y = b.border[4] + x, b.border[1] + y
    push!(b.over, k)
  end
end

# --- lines of text ------------------------------------------------------------------------

"What's known while the lines of a block are made"
mutable struct Liner
  b::Box
  p::Pass
  flow::Union{Flow,Nothing}
  fx::Float64                   # where the corner of the block's content is among the floats
  fy::Float64
  cw::Float64
  measure::Symbol               # :none, or :min or :max to find only how wide the lines are
  lines::Vector{Line{Box}}
  cur::Vector{Piece{Box}}       # what's in the line so far
  curw::Float64
  word::Vector{Piece{Box}}      # what's been read since the last place where the line can break
  wordw::Float64
  y::Float64                    # the top of the line
  left::Float64                 # where the line starts, and how wide it can be, between the floats
  avail::Float64
  open::Vector{Box}             # the inline boxes that are open where the reading has got to
  carried::Vector{Box}          # the inline boxes that were open where the line started
  spaced::Bool                  # the last thing read was a space, or the line has only just started
  content::Bool                 # the line has a word or a box in it
  first::Bool                   # it's the block's first line
  widest::Float64
  beside::Float64               # how wide the floats in the text are together, when only measuring
end

style_now(L::Liner) = isempty(L.open) ? L.b.style : L.open[end].style
wraps(s::Style) = s.whitespace in (:normal, :pre_wrap, :pre_line)

"Work out where the line at `L.y` starts and how wide it can be"
room!(L::Liner) = begin
  if L.measure != :none || L.flow === nothing
    L.left, L.avail = 0.0, L.measure == :min ? 0.0 : L.measure == :max ? Inf : L.cw
  else
    tall = max(1.0, sum(strut(L.b.style)))
    l, r = band(L.flow, L.fy + L.y, L.fy + L.y + tall, L.fx, L.fx + L.cw)
    L.left, L.avail = l - L.fx, r - l
  end
  if L.first
    indent = px(L.b.style.indent, isfinite(L.cw) ? L.cw : 0.0)
    L.left += indent
    L.avail -= indent
  end
end

text_piece(box, chars, widths, from; space=false) = Piece{Box}(:text, box, chars, widths, sum(widths; init=0.0), 0.0, 0.0, space, from)

"""
Put what's been read since the last place where the line can break into the
line. If it doesn't fit, it starts the next line.
"""
commit!(L::Liner) = begin
  isempty(L.word) && return
  if L.measure != :max
    L.content && L.curw + L.wordw > L.avail + 0.01 && newline!(L)
    if L.wordw > L.avail + 0.01
      # Beside a float there may be more room further down
      while L.measure == :none && L.flow !== nothing && L.avail < L.cw - 0.01 && L.wordw > L.avail + 0.01
        ny = next_bottom(L.flow, L.fy + L.y)
        ny === nothing && break
        L.y = ny - L.fy
        room!(L)
      end
      i = findfirst(q -> q.kind == :text, L.word)
      # A long word can break between any two letters when its style says so. With `overflow-wrap: break-word`, that
      # doesn't make the box that it's in any narrower.
      how = i === nothing ? :normal : L.word[i].box.style.wrap
      if L.wordw > L.avail + 0.01 && how != :normal && !(how == :break_word && L.measure == :min) && wraps(L.word[i].box.style)
        return split!(L)
      end
    end
  end
  L.content |= any(q -> q.kind in (:text, :atom), L.word)
  append!(L.cur, L.word)
  L.curw += L.wordw
  empty!(L.word)
  L.wordw = 0.0
  nothing
end

"Put a word that's too long for a line into as many lines as it needs, broken between any two letters"
split!(L::Liner) = begin
  word = copy(L.word)
  empty!(L.word)
  L.wordw = 0.0
  for q in word
    if q.kind != :text
      L.content && L.curw + q.width > L.avail + 0.01 && newline!(L)
      push!(L.cur, q)
      L.curw += q.width
      L.content |= q.kind == :atom
      continue
    end
    i, n = 1, length(q.chars)
    while i <= n
      j, w = i, 0.0
      while j <= n && (L.curw + w + q.widths[j] <= L.avail + 0.01 || (j == i && !L.content))
        w += q.widths[j]
        j += 1
      end
      if j == i
        newline!(L)
        continue
      end
      push!(L.cur, text_piece(q.box, q.chars[i:j-1], q.widths[i:j-1], q.from + i - 1))
      L.curw += w
      L.content = true
      i = j
      i <= n && newline!(L)
    end
  end
end

"End the line. A line with nothing in it is no line, unless a <br> ends it."
newline!(L::Liner; forced=false) = begin
  ps = L.cur
  used = L.curw
  # The spaces that a line ends with take no room
  k = length(ps)
  while k >= 1 && (ps[k].space || ps[k].kind in (:open, :close))
    if ps[k].space
      used -= ps[k].width
      ps[k].width = 0.0
      fill!(ps[k].widths, 0.0)
    end
    k -= 1
  end
  if L.content || forced || any(q -> q.kind in (:open, :close) && q.width > 0, ps)
    L.widest = max(L.widest, used)
    if L.measure == :none
      line = finish(L, ps, used, forced)
      push!(L.lines, line)
      L.y += line.height
    end
  else
    # The inline boxes that opened in a line that came to nothing are still open
    for q in ps
      q.kind == :open ? push!(L.carried, q.box) : q.kind == :close && !isempty(L.carried) ? pop!(L.carried) : nothing
    end
  end
  L.cur = Piece{Box}[]
  L.curw = 0.0
  L.content = false
  L.spaced = true
  L.first = false
  room!(L)
  nothing
end

mutable struct Frame
  box::Union{Box,Nothing}
  style::Style
  font::Font
  shift::Float64      # how far under the line's own baseline its text stands
  used::Bool          # it has text in this line, so its height counts
  left::Float64
  first::Bool
end

"How far over the line that its parent's text stands on the text of an inline box, or a box in a line, stands"
raised(s::Style, parent::Frame, top, bottom) = begin
  how, by = s.valign
  how == :sub ? -parent.style.size / 5 : how == :super ? parent.style.size / 3 :
  how == :length ? px(by, lineheight(s, normal(face(s)))) :
  how == :middle ? parent.font.xheight / 2 - (top - bottom) / 2 :
  how == :text_top ? parent.font.ascent - top : how == :text_bottom ? bottom - parent.font.descent : 0.0
end

"Make the line of the pieces `ps`, which are `used` px wide together: how tall it is, and where each piece is in it"
finish(L::Liner, ps, used, forced) = begin
  s0 = L.b.style
  quirky = L.p.mode != :standards
  above, below = -Inf, -Inf
  grow(top, bottom) = (above = max(above, top); below = max(below, bottom))
  # In a page that isn't of today's kind, the block's own text height counts only for a line that has text right in
  # the block, or that a <br> ended with nothing else in it
  frames = Frame[Frame(nothing, s0, face(s0), 0.0, !quirky || (forced && !any(q -> q.kind in (:text, :atom), ps)), 0.0, false)]
  for box in L.carried
    s = box.style
    f = face(s)
    top, bottom = strut(s, f)
    push!(frames, Frame(box, s, f, frames[end].shift - raised(s, frames[end], top, bottom), !quirky, 0.0, false))
  end
  spans = Tuple{Box,Float64,Float64,Float64,Float64,Bool,Bool}[]
  close(fr::Frame, right, last) = begin
    over, under = strut(fr.style, fr.font)
    fr.used && grow(over - fr.shift, under + fr.shift)
    k = fr.box
    push!(spans, (k, fr.left, right, fr.shift - fr.font.ascent - k.padding[1] - k.border[1], fr.shift + fr.font.descent + k.padding[3] + k.border[3], fr.first, last))
  end
  later = Tuple{Piece{Box},Float64,Symbol}[]
  x = 0.0
  for q in ps
    q.x = x
    if q.kind == :open
      s = q.box.style
      f = face(s)
      top, bottom = strut(s, f)
      push!(frames, Frame(q.box, s, f, frames[end].shift - raised(s, frames[end], top, bottom), !quirky || q.width > 0, x + q.box.margin[4], true))
    elseif q.kind == :close
      length(frames) > 1 && close(pop!(frames), x + q.width - q.box.margin[2], true)
    elseif q.kind == :text
      fr = frames[end]
      fr.used = true
      q.y = fr.shift
      # A letter that's drawn in another font, like an emoji, makes the line as tall as that font needs
      if fr.style.lineheight[1] == :normal
        for ch in q.chars
          use = drawn(fr.font, ch)[1]
          use === fr.font || grow(use.ascent + use.gap / 2 - fr.shift, use.descent + use.gap / 2 + fr.shift)
        end
      end
    else
      k = q.box
      h = k.height + down(k.margin)
      base = isnan(k.baseline) || k.style.overflow != :visible ? h : k.margin[1] + k.baseline
      fr = frames[end]
      how = k.style.valign[1]
      if how in (:top, :bottom)
        push!(later, (q, h, how))
      else
        top = how == :middle ? fr.font.xheight / 2 + h / 2 - fr.shift :
              how == :text_top ? fr.font.ascent - fr.shift : how == :text_bottom ? h - fr.font.descent - fr.shift :
              base - fr.shift + raised(k.style, fr, base, h - base)
        grow(top, h - top)
        q.y = -top
      end
    end
    x += q.width
  end
  open_now = Box[fr.box for fr in frames[2:end]]
  while length(frames) > 1
    close(pop!(frames), x, false)
  end
  frames[1].used && grow(strut(s0, frames[1].font)...)
  isfinite(above) || ((above, below) = (0.0, 0.0))
  tall = above + below
  for (q, h, how) in later
    h > tall && (how == :bottom ? (above += h - tall) : (below += h - tall); tall = h)
  end
  for (q, h, how) in later
    q.y = how == :top ? -above : below - h
  end
  free = L.avail - used
  align = s0.align
  dx = L.left + (free > 0 ? (align in (:center, :wk_center) ? free / 2 : align in (:right, :wk_right) ? free : 0.0) : 0.0)
  base = L.y + above
  for q in ps
    q.x += dx
    q.y += base
  end
  L.carried = open_now
  Line{Box}(L.y, tall, above, ps, [Span{Box}(b, l + dx, r + dx, t + base, bt + base, first, last) for (b, l, r, t, bt, first, last) in spans], forced)
end

isideograph(c::Char) = '⺀' <= c <= '鿿' || '가' <= c <= '힯' || '豈' <= c <= '﫿' || '＀' <= c <= '￯' || '\U20000' <= c <= '\U3ffff'

"Read the text of the box `t` into the line: its words, and its spaces as CSS keeps them"
text!(L::Liner, t::Box) = begin
  s = t.style
  f = face(s)
  ls, ws = s.letterspacing.px, s.wordspacing.px
  collapse = s.whitespace in (:normal, :nowrap, :pre_line)
  newlines = s.whitespace in (:pre, :pre_wrap, :pre_line)
  wrap = wraps(s)
  cs = collect(t.text)
  n = length(cs)
  # The width of each letter is found once, in the run of text that it's in
  length(t.advances) == n || (t.advances = advances(f, cs))
  gap = space(f) + ls + ws
  chars, widths, from = Char[], Float64[], 0
  flush() = begin
    isempty(chars) && return
    q = text_piece(t, chars, widths, from)
    push!(L.word, q)
    L.wordw += q.width
    chars, widths = Char[], Float64[]
  end
  for (i, ch) in enumerate(cs)
    if ch == '\n' && newlines
      flush()
      commit!(L)
      newline!(L; forced=true)
      continue
    elseif ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f'
      if collapse
        L.spaced && continue
        flush()
        q = text_piece(t, [' '], [gap], i - 1; space=true)
        if wrap
          commit!(L)
          push!(L.cur, q)
          L.curw += q.width
        else
          push!(L.word, q)
          L.wordw += q.width
        end
        L.spaced = true
      else
        w = ch == '\t' ? 8gap : gap
        if wrap
          flush()
          commit!(L)
          push!(L.cur, text_piece(t, [' '], [w], i - 1; space=true))
          L.curw += w
          L.content = true
        else
          isempty(chars) && (from = i - 1)
          push!(chars, ' ')
          push!(widths, w)
        end
        L.spaced = false
      end
      continue
    end
    w = t.advances[i]
    wide = wrap && isideograph(ch)
    wide && (flush(); commit!(L))
    isempty(chars) && (from = i - 1)
    push!(chars, ch)
    push!(widths, w + (w > 0 ? ls : 0.0))
    L.spaced = false
    if wrap && (wide || s.wrap == :all || ch == '​' ||
                (ch == '-' && i > 1 && i < n && (isletter(cs[i-1]) || isdigit(cs[i-1])) && isletter(cs[i+1])))
      flush()
      commit!(L)
    end
  end
  flush()
end

"Read the inline box, the text or the box `k` into the line"
read!(L::Liner, k::Box) = begin
  b = L.b
  if placed(k)
    if L.measure == :none
      k.x, k.y = b.border[4] + b.padding[4] + L.left + L.curw, b.border[1] + b.padding[1] + L.y
      push!(L.p.pending[end], k)
    end
  elseif floats(k)
    if L.measure != :none
      lo, hi = outer_extent(k, L.p)
      L.measure == :min ? (L.widest = max(L.widest, lo)) : (L.beside += hi)
      return
    end
    commit!(L)
    shrink!(k, L.cw, L.p)
    mw = k.width + across(k.margin)
    # A float that doesn't fit beside what the line has goes under the line
    under = L.content && L.curw + mw > L.avail + 0.01 ? sum(strut(b.style)) : 0.0
    x, top = place_float!(L.flow, k, L.fx, L.fx + L.cw, L.fy + L.y + under)
    k.x, k.y = b.border[4] + b.padding[4] + (x - L.fx) + k.margin[4], b.border[1] + b.padding[1] + (top - L.fy) + k.margin[1]
    room!(L)
  elseif k.kind == :text
    text!(L, k)
  elseif k.kind == :break
    commit!(L)
    newline!(L; forced=true)
    if k.style.clear != :none && L.measure == :none && L.flow !== nothing
      L.y = max(L.y, clear_y(L.flow, k.style.clear) - L.fy)
      room!(L)
    end
  elseif k.kind == :inline
    edges!(k, isfinite(L.cw) ? L.cw : 0.0)
    push!(L.word, Piece{Box}(:open, k, Char[], Float64[], k.margin[4] + k.border[4] + k.padding[4], 0.0, 0.0, false, 0))
    L.wordw += L.word[end].width
    push!(L.open, k)
    for c in k.children
      read!(L, c)
    end
    pop!(L.open)
    q = Piece{Box}(:close, k, Char[], Float64[], k.margin[2] + k.border[2] + k.padding[2], 0.0, 0.0, false, 0)
    # The end of an inline box stays with what's before it
    if isempty(L.word)
      push!(L.cur, q)
      L.curw += q.width
    else
      push!(L.word, q)
      L.wordw += q.width
    end
  else
    wrap = wraps(style_now(L))
    w = if L.measure == :none
      shrink!(k, L.cw, L.p)
      k.width + across(k.margin)
    else
      lo, hi = outer_extent(k, L.p)
      L.measure == :min ? lo : hi
    end
    wrap && commit!(L)
    push!(L.word, Piece{Box}(:atom, k, Char[], Float64[], w, 0.0, 0.0, false, 0))
    L.wordw += w
    wrap && commit!(L)
    L.spaced = false
  end
  nothing
end

"""
Make the lines of the block `b` from the text and the boxes in it. `(fx, fy)`
is where the corner of `b`'s content is in `flow`, and `cw` is how wide the
content is. It gives how tall the lines are together, and how wide the widest
is. With `measure`, it only finds how wide: `:min` with each line as short as
it can be, `:max` with no line broken.
"""
lines!(b::Box, p::Pass, flow, fx, fy, cw; measure=:none) = begin
  L = Liner(b, p, flow, fx, fy, cw, measure, Line{Box}[], Piece{Box}[], 0.0, Piece{Box}[], 0.0, 0.0, 0.0, 0.0, Box[], Box[], true, false, true, 0.0, 0.0)
  room!(L)
  for k in b.children
    read!(L, k)
  end
  commit!(L)
  newline!(L)
  measure == :none || return (0.0, L.widest + L.beside)
  b.lines = L.lines
  # Each box in a line gets its place, from the corner of `b`'s border
  cx, cy = b.border[4] + b.padding[4], b.border[1] + b.padding[1]
  for line in L.lines, q in line.pieces
    q.kind == :atom || continue
    q.box.x, q.box.y = cx + q.x + q.box.margin[4], cy + q.y + q.box.margin[1]
  end
  (L.y, L.widest)
end

# --- tables -------------------------------------------------------------------------------

"The rows and the columns of a table"
mutable struct Grid
  rows::Vector{Box}
  groups::Vector{Box}
  cells::Vector{Box}
  captions::Vector{Box}
  ncols::Int
  said::Vector{Len}            # the width that a <col> says for each column
  low::Vector{Float64}         # how narrow each column can be
  high::Vector{Float64}        # how wide each is with no line broken
  share::Vector{Float64}       # the share of the table that each asks for, as a percent does, or 0
  fixed::Vector{Float64}       # the width in px that a cell or a <col> says for each, or NaN
end

"Find the rows of the table `t`, and the row and the column of each of its cells"
grid(t::Box) = begin
  t.grid === nothing || return t.grid::Grid
  heads, bodies, feet = Box[], Box[], Box[]
  groups, captions, said = Box[], Box[], Len[]
  col!(c::Box) = begin
    n = c.element === nothing ? 1 : clamp(something(tryparse(Int, strip(attr(c.element, "span"))), 1), 1, 1000)
    foreach(_ -> push!(said, c.style.width), 1:n)
  end
  for k in t.children
    if k.kind == :group
      push!(groups, k)
      rows = filter(r -> r.kind == :row, k.children)
      append!(k.style.display == :table_header_group ? heads : k.style.display == :table_footer_group ? feet : bodies, rows)
    elseif k.kind == :row
      push!(bodies, k)
    elseif k.kind == :caption
      push!(captions, k)
    elseif k.kind == :column
      cols = filter(c -> c.kind == :column, k.children)
      isempty(cols) ? col!(k) : foreach(col!, cols)
    end
  end
  rows = [heads; bodies; feet]
  cells = Box[]
  busy = Int[]   # the last row that a cell from a row above takes of each column
  for (r, row) in enumerate(rows)
    col = 1
    for cell in row.children
      cell.kind == :cell || continue
      while col <= length(busy) && busy[col] >= r
        col += 1
      end
      cell.row, cell.col = r, col
      span = cell.rowspan == 0 ? length(rows) - r + 1 : min(cell.rowspan, length(rows) - r + 1)
      cell.rowspan = span
      for c in col:col+cell.colspan-1
        c > length(busy) && resize_zero!(busy, c)
        busy[c] = r + span - 1
      end
      col += cell.colspan
      push!(cells, cell)
    end
  end
  n = length(busy)
  t.grid = Grid(rows, groups, cells, captions, n, said, zeros(n), zeros(n), zeros(n), fill(NaN, n))
end

resize_zero!(v::Vector{Int}, n) = (old = length(v); resize!(v, n); v[old+1:n] .= 0; v)

"Share `extra` px among the columns `cols` of `w`, by how wide each is in `by`, or evenly when they're nothing"
spread!(w, cols, extra, by) = begin
  total = sum(by[c] for c in cols)
  for c in cols
    w[c] += total > 0 ? extra * by[c] / total : extra / length(cols)
  end
end

"The room between the columns of the table `t`, and round them, and the room between its rows"
spacing(t::Box) = t.style.collapse ? (0.0, 0.0) : t.style.cellspacing

"How much of the width of the table `t` isn't its columns: its border, its padding and the room between its columns"
table_chrome(t::Box, g::Grid) = begin
  s = t.style
  pad = s.collapse ? 0.0 : max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px)
  border(s, 2) + border(s, 4) + pad + spacing(t)[1] * (g.ncols + 1)
end

"Work out what each column of the table `t` asks for: how narrow it can be, how wide it wants to be, and what its cells say of its width"
columns!(t::Box, g::Grid, p::Pass) = begin
  fill!(g.low, 0.0); fill!(g.high, 0.0); fill!(g.share, 0.0); fill!(g.fixed, NaN)
  hs = spacing(t)[1]
  for (c, l) in enumerate(g.said)
    c > g.ncols && break
    isauto(l) && continue
    ispercent(l) ? (g.share[c] = l.pct) : (g.fixed[c] = l.px)
  end
  wants(cell) = begin
    lo, hi = extent(cell, p; own=false)
    s = cell.style
    pad = max(0.0, s.padding[2].px) + max(0.0, s.padding[4].px) + border(s, 2) + border(s, 4)
    said = isauto(s.width) || ispercent(s.width) ? NaN : s.width.px + (s.borderbox ? 0.0 : pad)
    # A cell is no narrower than its least width, and that's all of its own style that counts for how narrow it can be
    least = ispercent(s.minwidth) ? 0.0 : s.minwidth.px + (s.borderbox ? 0.0 : pad)
    (max(lo, least), max(hi, least), said, ispercent(s.width) ? s.width.pct : 0.0)
  end
  for cell in g.cells
    cell.colspan == 1 || continue
    c = cell.col
    lo, hi, said, share = wants(cell)
    g.low[c] = max(g.low[c], lo)
    if !isnan(said)
      g.fixed[c] = isnan(g.fixed[c]) ? said : max(g.fixed[c], said)
    else
      g.high[c] = max(g.high[c], hi)
    end
    g.share[c] = max(g.share[c], share)
  end
  for c in 1:g.ncols
    # A column whose cell says a width wants that width, and never less than its content needs
    isnan(g.fixed[c]) || (g.fixed[c] = max(g.fixed[c], g.low[c]); g.high[c] = g.fixed[c])
    g.high[c] = max(g.high[c], g.low[c])
  end
  # A cell over several columns makes them wider when they're too narrow for it together
  for cell in sort(filter(c -> c.colspan > 1, g.cells); by=c -> c.colspan)
    cols = cell.col:min(cell.col + cell.colspan - 1, g.ncols)
    lo, hi, said, share = wants(cell)
    between = hs * (length(cols) - 1)
    isnan(said) || (hi = max(lo, said))
    need = lo - between - sum(g.low[c] for c in cols)
    loose = [c for c in cols if isnan(g.fixed[c])]
    need > 0 && spread!(g.low, isempty(loose) ? cols : loose, need, g.high)
    for c in cols
      g.high[c] = max(g.high[c], g.low[c])
    end
    need = hi - between - sum(g.high[c] for c in cols)
    need > 0 && spread!(g.high, isempty(loose) ? cols : loose, need, g.high)
    if share > 0
      had = sum(g.share[c] for c in cols)
      rest = [c for c in cols if g.share[c] == 0]
      share > had && !isempty(rest) && foreach(c -> g.share[c] = (share - had) / length(rest), rest)
    end
  end
  g
end

"How narrow the table `t` can be, and how wide it wants to be"
table_extent(t::Box, p::Pass) = begin
  g = columns!(t, grid(t), p)
  s = t.style
  extra = table_chrome(t, g)
  lo, hi = sum(g.low) + extra, sum(g.high) + extra
  # A column that asks for a share of the table makes the table wide enough to give it
  total = sum(g.share)
  if 0 < total < 1
    plain = sum(g.high[c] for c in 1:g.ncols if g.share[c] == 0; init=0.0)
    hi = max(hi, plain / (1 - total) + extra)
    for c in 1:g.ncols
      g.share[c] > 0 && (hi = max(hi, g.high[c] / g.share[c] + extra))
    end
  end
  for k in g.captions
    lo = max(lo, outer_extent(k, p)[1])
  end
  isauto(s.width) || ispercent(s.width) || (lo = max(lo, s.width.px); hi = lo)
  ispercent(s.minwidth) || (lo = max(lo, s.minwidth.px); hi = max(hi, lo))
  isauto(s.maxwidth) || ispercent(s.maxwidth) || (hi = max(lo, min(hi, s.maxwidth.px)))
  (lo, max(lo, hi))
end

"How wide each column of a table is, when the columns have `target` px together"
column_widths(g::Grid, target) = begin
  w = copy(g.low)
  left = target - sum(w)
  left <= 0 && return w
  # First the columns that ask for a share of the table, then the ones that say a width, then the rest
  give!(cols, want) = begin
    need = [max(0.0, want(c) - w[c]) for c in cols]
    total = sum(need; init=0.0)
    total > 0 || return
    part = min(1.0, left / total)
    for (c, x) in zip(cols, need)
      w[c] += x * part
    end
    left -= total * part
  end
  shared = [c for c in 1:g.ncols if g.share[c] > 0]
  fixed = [c for c in 1:g.ncols if g.share[c] == 0 && !isnan(g.fixed[c])]
  loose = [c for c in 1:g.ncols if g.share[c] == 0 && isnan(g.fixed[c])]
  give!(shared, c -> g.share[c] * target)
  give!(fixed, c -> g.fixed[c])
  give!(loose, c -> g.high[c])
  # What's still free goes to the columns that said no width
  if left > 0.01
    cols = !isempty(loose) ? loose : !isempty(fixed) ? fixed : shared
    isempty(cols) || spread!(w, cols, left, cols === shared ? g.share : g.high)
  end
  w
end

"Move what's in `b` down by `dy`"
lower!(b::Box, dy) = begin
  dy == 0 && return
  foreach(k -> k.y += dy, b.children)
  foreach(k -> k.y += dy, b.over)
  for line in b.lines
    line.y += dy
    foreach(q -> q.y += dy, line.pieces)
    line.spans = [Span{Box}(s.box, s.left, s.right, s.top + dy, s.bottom + dy, s.first, s.last) for s in line.spans]
  end
  isnan(b.baseline) || (b.baseline += dy)
end

"""
Lay out the table `t`, in a box whose content is `cw` px wide. `room` is how
much of that is free for it, beside floats.
"""
table!(t::Box, cw, p::Pass; room=cw) = begin
  g = grid(t)
  s = t.style
  edges!(t, cw)
  s.collapse && (t.padding = (0.0, 0.0, 0.0, 0.0))
  lo, hi = extent(t, p)
  hs, vs = spacing(t)
  extra = across(t.border) + across(t.padding) + hs * (g.ncols + 1)
  # A table's width is of its border
  wide = if isauto(s.width) || (ispercent(s.width) && !isfinite(cw))
    max(lo, min(hi, room - across(t.margin)))
  else
    max(lo, px(s.width, cw) + (s.borderbox || t.element !== nothing && t.element.tag == "table" ? 0.0 : across(t.border) + across(t.padding)))
  end
  isauto(s.maxwidth) || (ispercent(s.maxwidth) && !isfinite(cw)) || (wide = max(lo, min(wide, px(s.maxwidth, cw))))
  ispercent(s.minwidth) && !isfinite(cw) || (wide = max(wide, px(s.minwidth, cw)))
  t.width = wide
  centre!(t, room)
  widths = column_widths(g, wide - extra)
  left = t.border[4] + t.padding[4]
  colx = Float64[]
  x = left + hs
  for w in widths
    push!(colx, x)
    x += w + hs
  end
  # The captions that go over the table
  y = 0.0
  for k in g.captions
    k.style.captionbottom && continue
    block_width!(k, wide)
    content!(k, p, Flow(), 0.0, 0.0)
    k.x, k.y = k.margin[4], y + k.margin[1]
    y += k.height + down(k.margin)
  end
  top = y
  # Each cell is laid out as wide as its columns, which says how tall its row has to be
  nrows = length(g.rows)
  tall = zeros(nrows)
  natural = Dict{Box,Float64}()
  for cell in g.cells
    cols = cell.col:min(cell.col + cell.colspan - 1, g.ncols)
    cell.width = sum(widths[c] for c in cols; init=0.0) + hs * (length(cols) - 1)
    edges!(cell, wide)
    cell.margin = (0.0, 0.0, 0.0, 0.0)
    content!(cell, p, Flow(), 0.0, 0.0)
    natural[cell] = cell.height
    # A cell is at least as tall as its style says
    h = cell.style.height
    isauto(h) || ispercent(h) || (cell.height = max(cell.height, h.px + (cell.style.borderbox ? 0.0 : down(cell.padding) + down(cell.border))))
    cell.rowspan == 1 && (tall[cell.row] = max(tall[cell.row], cell.height))
  end
  for (r, row) in enumerate(g.rows)
    h = row.style.height
    isauto(h) || ispercent(h) || (tall[r] = max(tall[r], h.px))
  end
  for cell in g.cells
    cell.rowspan > 1 || continue
    rows = cell.row:cell.row+cell.rowspan-1
    need = cell.height - vs * (length(rows) - 1) - sum(tall[r] for r in rows)
    need > 0 && spread!(tall, rows, need, tall)
  end
  # A table that says a height shares what's over among its rows
  if !isauto(s.height) && !ispercent(s.height) && nrows > 0
    need = s.height.px - down(t.border) - down(t.padding) - vs * (nrows + 1) - sum(tall)
    need > 0 && spread!(tall, 1:nrows, need, tall)
  end
  rowy = Float64[]
  y = top + t.border[1] + t.padding[1] + vs
  for h in tall
    push!(rowy, y)
    y += h + vs
  end
  bottom = y + t.padding[3] + t.border[3]
  inner = (left + hs, wide - extra + hs * (g.ncols - 1))   # where the rows start, and how wide they are
  for (r, row) in enumerate(g.rows)
    row.x, row.y, row.width, row.height = inner[1], rowy[r], inner[2], tall[r]
  end
  for cell in g.cells
    rows = cell.row:cell.row+cell.rowspan-1
    h = sum(tall[r] for r in rows) + vs * (length(rows) - 1)
    how = cell.style.valign[1]
    lower!(cell, how == :top ? 0.0 : how == :bottom ? h - natural[cell] : how == :baseline ? 0.0 : (h - natural[cell]) / 2)
    cell.height = h
    # A cell's place is from the corner of its row
    cell.x, cell.y = colx[cell.col] - inner[1], 0.0
  end
  # A group of rows is the box round its rows, and its rows' places are from its corner
  for group in g.groups
    rows = filter(r -> r.kind == :row, group.children)
    if isempty(rows)
      group.x, group.y, group.width, group.height = inner[1], top, inner[2], 0.0
      continue
    end
    group.x, group.y = inner[1], minimum(r -> r.y, rows)
    group.width, group.height = inner[2], maximum(r -> r.y + r.height, rows) - group.y
    for r in rows
      r.x -= group.x
      r.y -= group.y
    end
  end
  y = bottom
  for k in g.captions
    k.style.captionbottom || continue
    block_width!(k, wide)
    content!(k, p, Flow(), 0.0, 0.0)
    k.x, k.y = k.margin[4], y + k.margin[1]
    y += k.height + down(k.margin)
  end
  t.height = y
  t.baseline = NaN
  t
end

# --- the page -----------------------------------------------------------------------------

"""
Lay out the page whose <html> element has the box `root`, `wide` px wide.
`mode` is what the page's doctype says of how it's laid out. It gives how
tall the page is.
"""
layout!(root::Box, wide, mode::Symbol=:standards) = begin
  p = Pass(mode, Vector{Box}[])
  block_width!(root, Float64(wide))
  root.x, root.y = root.margin[4], root.margin[1]
  content!(root, p, Flow(), 0.0, 0.0)
  root.y + root.height + root.margin[3]
end
