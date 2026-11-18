# Turns the boxes of a page that's laid out into a list of things to draw, and
# draws them with Skia.
#
#     list = list(root, wide, tall; pictures)      # what to draw, from the top of the page down
#     list.links           # each rectangle of the page that's a link, and where it goes
#     list.words           # the page's words in the order that the HTML has them, with where each letter is
#     draw(canvas, list)                           # draw all of it, with the page's corner at the canvas's
#     draw(canvas, list; top=400, bottom=900)      # or only what's between two heights of the page
#
# What's drawn: backgrounds in a colour, a picture or a gradient. Borders,
# with round corners. Shadows. Text, with the lines under and through it.
# Pictures. The bullets and numbers of lists. A box that cuts off what
# overflows, and a box that's partly see-through.

@use Skia
@use "./dom" Element attr
@use "./style" Style Len px isauto ispercent border colour alpha argb terms
@use "./text" Font font drawn normal
@use "./box" Box Piece Span Line floats placed

abstract type Item end

const Radii = NTuple{4,Float64}   # of the top left corner, the top right, the bottom right and the bottom left
const SQUARE = (0.0, 0.0, 0.0, 0.0)

"A rectangle in one colour"
struct Fill <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  color::UInt32
end

"The border of a box: how thick each side is, with its colour and its style"
struct Edge <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  widths::NTuple{4,Float64}
  colors::NTuple{4,UInt32}
  styles::NTuple{4,Symbol}
end

"Letters of one font on one line. `xs` is where each starts, from `x`."
mutable struct Glyphs <: Item
  x::Float64; y::Float64; w::Float64
  font::Font
  ids::Vector{UInt16}
  xs::Vector{Float32}
  color::UInt32
  blob::Ptr{Cvoid}
end

"A picture, stretched over a rectangle"
struct Picture <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  image::Ptr{Cvoid}
end

"A picture behind a box: at its own size or `size`, from `(ox, oy)`, again and again as `repeat` says"
struct Tiles <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  image::Ptr{Cvoid}
  ox::Float64; oy::Float64
  size::Tuple{Float64,Float64}
  repeat::Symbol
end

"Colours that run into each other across a box, along a line at `angle` degrees: 0 is up, 90 is to the right"
struct Gradient <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  angle::Float64
  colors::Vector{UInt32}
  stops::Vector{Float32}
end

"The shadow of a box"
struct Shadow <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
  dx::Float64; dy::Float64; blur::Float64; spread::Float64
  color::UInt32
end

"From here to the `Unclip` that matches, nothing is drawn outside the rectangle"
struct Clip <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  radii::Radii
end
struct Unclip <: Item end

"From here to the `Unfade` that matches, what's drawn is partly see-through"
struct Fade <: Item
  x::Float64; y::Float64; w::Float64; h::Float64
  opacity::Float64
end
struct Unfade <: Item end

const Link = @NamedTuple{left::Float64, top::Float64, wide::Float64, tall::Float64, url::String}
const Words = @NamedTuple{before::String, top::Float64, tall::Float64, edges::Vector{Float64}, letters::Vector{Char}, from::Int}

"What to draw of a page, in order"
mutable struct List
  items::Vector{Item}
  links::Vector{Link}
  words::Vector{Words}
  wide::Float64
  tall::Float64
  background::UInt32
  pictures::Function
  # What's known while the list is made
  before::String        # what goes between the next words and the ones before them when they're copied
  line::Any             # the line that the last words were in
  behind::Any           # the box whose background is the page's, which is drawn already
end

# --- making the list ----------------------------------------------------------------------

# The colour of the line round a picture that there isn't
const MISSING = 0x33808080

"The corners of a box `w` by `h`, in px: none rounder than the box has room for"
corners(s::Style, w, h) = begin
  r = map(l -> max(0.0, px(l, w)), s.radius)
  all(==(0.0), r) && return SQUARE
  f = min(1.0, w / max(r[1] + r[2], 1e-9), w / max(r[4] + r[3], 1e-9), h / max(r[1] + r[4], 1e-9), h / max(r[2] + r[3], 1e-9))
  map(x -> x * f, r)
end

"The corners of what's inside a border `widths` thick"
inner(r::Radii, widths) = (max(0.0, r[1] - max(widths[1], widths[4])), max(0.0, r[2] - max(widths[1], widths[2])),
                           max(0.0, r[3] - max(widths[3], widths[2])), max(0.0, r[4] - max(widths[3], widths[4])))

"The address in `url(...)`"
address(v) = (m = match(r"^url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)"i, strip(v)); m === nothing ? "" : String(strip(something(m[1], m[2], m[3]))))

const SIDES = Dict("top" => 0.0, "right" => 90.0, "bottom" => 180.0, "left" => 270.0)

"The gradient that `v` writes with `linear-gradient(...)`, over a box at `(x, y)`, or nothing"
gradient(v, x, y, w, h, radii) = begin
  m = match(r"^(?:-webkit-|-moz-|-o-)?(repeating-)?linear-gradient\((.*)\)$"is, strip(v))
  m === nothing && return nothing
  old = startswith(lowercase(strip(v)), "-")
  parts = [strip(p) for p in split_top(m[2])]
  isempty(parts) && return nothing
  angle = 180.0
  first = lowercase(parts[1])
  if (a = match(r"^(-?[0-9.]+)deg$", first)) !== nothing
    angle = Base.parse(Float64, a[1])
    old && (angle = 90 - angle)
    popfirst!(parts)
  elseif startswith(first, "to ") || (old && haskey(SIDES, first))
    names = split(replace(first, "to " => ""))
    angles = [SIDES[n] for n in names if haskey(SIDES, n)]
    isempty(angles) && return nothing
    angle = length(angles) == 1 ? angles[1] : (abs(angles[1] - angles[2]) > 180 ? 315.0 : sum(angles) / 2)
    old && (angle += 180)
    popfirst!(parts)
  end
  colors, stops = UInt32[], Float32[]
  for part in parts
    ws = terms(part)
    isempty(ws) && return nothing
    c = colour(ws[1])
    c isa UInt32 || return nothing
    push!(colors, c)
    at = length(ws) > 1 && endswith(ws[2], '%') ? tryparse(Float32, chop(ws[2])) : nothing
    push!(stops, at === nothing ? NaN32 : at / 100)
  end
  length(colors) < 2 && return nothing
  # A stop with no place is evenly between the ones that have one
  isnan(stops[1]) && (stops[1] = 0)
  isnan(stops[end]) && (stops[end] = 1)
  i = 1
  while i < length(stops)
    j = i + 1
    while isnan(stops[j]) j += 1 end
    for k in i+1:j-1
      stops[k] = stops[i] + (stops[j] - stops[i]) * (k - i) / (j - i)
    end
    i = j
  end
  Gradient(x, y, w, h, radii, angle, colors, stops)
end

"`s` cut at each comma that's in no brackets"
split_top(s) = begin
  out, depth, from = String[], 0, firstindex(s)
  for (i, c) in pairs(s)
    c == '(' ? (depth += 1) : c == ')' ? (depth -= 1) : nothing
    if c == ',' && depth == 0
      push!(out, s[from:prevind(s, i)])
      from = nextind(s, i)
    end
  end
  push!(out, s[from:end])
  out
end

"Add the shadows that `box-shadow: v` writes for a box"
shadows!(l::List, v, x, y, w, h, radii, color) = begin
  for one in split_top(v)
    ws = terms(strip(one))
    any(w -> lowercase(w) == "inset", ws) && continue
    nums = Float64[]
    c = color
    for word in ws
      m = match(r"^(-?[0-9.]+)(px)?$", lowercase(word))
      if m !== nothing
        push!(nums, Base.parse(Float64, m[1]))
      elseif (found = colour(word)) isa UInt32
        c = found
      end
    end
    length(nums) >= 2 || continue
    alpha(c) > 0 && push!(l.items, Shadow(x, y, w, h, radii, nums[1], nums[2], get(nums, 3, 0.0), get(nums, 4, 0.0), c))
  end
end

"""
Add what's behind and round a box with the style `s`: its shadow, its
background and its border. `widths` is how thick each side of its border is.
"""
decorate!(l::List, s::Style, x, y, w, h, widths=ntuple(i -> border(s, i), 4); background=true) = begin
  (s.visible && w > 0 && h > 0) || return
  radii = corners(s, w, h)
  isempty(s.shadow) || shadows!(l, s.shadow, x, y, w, h, radii, s.color)
  if background
    alpha(s.background) > 0 && push!(l.items, Fill(x, y, w, h, radii, s.background))
    isempty(s.image) || backdrop!(l, s, x, y, w, h, radii)
  end
  if any(>(0), widths)
    colors = map(c -> c isa UInt32 ? c : s.color, s.bordercolor)
    any(i -> widths[i] > 0 && alpha(colors[i]) > 0, 1:4) && push!(l.items, Edge(x, y, w, h, radii, widths, colors, s.borderstyle))
  end
end

"Add the picture or the gradient behind a box"
backdrop!(l::List, s::Style, x, y, w, h, radii) = begin
  if occursin("gradient(", s.image)
    g = gradient(s.image, x, y, w, h, radii)
    g === nothing || push!(l.items, g)
    return
  end
  found = l.pictures(address(s.image))
  found === nothing && return
  nw, nh, image = Float64(found[1]), Float64(found[2]), found[3]
  (nw > 0 && nh > 0) || return
  tw, th = nw, nh
  if s.bgsize == :cover || s.bgsize == :contain
    k = s.bgsize == :cover ? max(w / nw, h / nh) : min(w / nw, h / nh)
    tw, th = nw * k, nh * k
  elseif s.bgsize isa Tuple
    a, b = s.bgsize
    tw = isauto(a) ? NaN : px(a, w)
    th = isauto(b) ? NaN : px(b, h)
    isnan(tw) && isnan(th) ? ((tw, th) = (nw, nh)) : isnan(tw) ? (tw = th * nw / nh) : isnan(th) ? (th = tw * nh / nw) : nothing
  end
  (tw > 0 && th > 0) || return
  # A percent puts that point of the picture at that point of the box
  place(len, room) = len.px + len.pct * room
  ox, oy = place(s.bgposition[1], w - tw), place(s.bgposition[2], h - th)
  push!(l.items, Tiles(x, y, w, h, radii, image, ox, oy, (tw, th), s.repeat))
end

"Add the letters of `chars`, each as wide as `widths` says, with the first at `x` on the line at `y`"
glyphs!(l::List, f::Font, chars, widths, x, y, color) = begin
  run = nothing
  at = 0.0
  for (c, w) in zip(chars, widths)
    use, id, _ = drawn(f, c)
    if id != 0
      if run === nothing || run.font !== use
        run = Glyphs(x + at, y, 0.0, use, UInt16[], Float32[], color, C_NULL)
        finalizer(release, run)
        push!(l.items, run)
      end
      push!(run.ids, id)
      push!(run.xs, Float32(x + at - run.x))
      run.w = x + at + w - run.x
    end
    at += w
  end
end

release(g::Glyphs) = (g.blob == C_NULL || Skia.sk_textblob_unref(g.blob); g.blob = C_NULL; nothing)

"How far `b` is moved from where it was laid out, when its style has `position: relative`"
nudge(s::Style) = begin
  s.position == :relative || return (0.0, 0.0)
  top, right, bottom, left = s.inset
  (!isauto(left) ? left.px : !isauto(right) ? -right.px : 0.0, !isauto(top) ? top.px : !isauto(bottom) ? -bottom.px : 0.0)
end

"How far under the top of `b`'s border its first line of text stands, or nothing when it has no text"
first_baseline(b::Box) = begin
  isempty(b.lines) || return b.border[1] + b.padding[1] + b.lines[1].y + b.lines[1].baseline
  for k in b.children
    (k.kind in (:block, :table, :group, :row, :cell) && !floats(k) && !placed(k)) || continue
    y = first_baseline(k)
    y === nothing || return k.y + y
  end
  nothing
end

"Call `f` with each float in the text of `b`"
each_float(f, b::Box) = for k in b.children
  floats(k) ? f(k) : k.kind == :inline && each_float(f, k)
end

"Note where the text of the piece `q` is, so that it can be selected"
words!(l::List, line, q::Piece, x, top, tall) = begin
  edges = Float64[x]
  for w in q.widths
    push!(edges, edges[end] + w)
  end
  last = isempty(l.words) ? nothing : l.words[end]
  if last !== nothing && l.line === line && isempty(l.before) && abs(last.edges[end] - x) < 0.5
    # It goes on from the words before it
    append!(last.edges, @view edges[2:end])
    append!(last.letters, q.chars)
    l.words[end] = (before=last.before, top=min(last.top, top), tall=max(last.top + last.tall, top + tall) - min(last.top, top),
                    edges=last.edges, letters=last.letters, from=last.from)
  else
    from = last === nothing ? 0 : last.from + length(last.letters)
    before = last === nothing ? "" : l.before
    push!(l.words, (before=before, top=top, tall=tall, edges=edges, letters=copy(q.chars), from=from))
  end
  l.line = line
  l.before = ""
end

"Add a rectangle of the page that's a link"
link!(l::List, url, x, y, w, h) = begin
  (isempty(url) || w <= 0 || h <= 0 || !occursin(r"^(https?|mailto|tel):"i, url)) && return
  last = isempty(l.links) ? nothing : l.links[end]
  # A link's words on one line are one rectangle
  if last !== nothing && last.url == url && abs(last.top - y) < 0.5 && abs(last.tall - h) < 0.5 && abs(last.left + last.wide - x) < 0.5
    l.links[end] = (left=last.left, top=last.top, wide=x + w - last.left, tall=last.tall, url=url)
  else
    push!(l.links, (left=Float64(x), top=Float64(y), wide=Float64(w), tall=Float64(h), url=String(url)))
  end
end

"""
Add what `b` draws, and what's in it. `(ox, oy)` is the corner of the border of
the box that `b` is in.
"""
emit!(l::List, b::Box, ox, oy) = begin
  s = b.style
  background = b !== l.behind
  dx, dy = nudge(s)
  x, y = ox + b.x + dx, oy + b.y + dy
  w, h = b.width, b.height
  s.opacity <= 0 && return
  faded = s.opacity < 1
  faded && push!(l.items, Fade(x, y, w, h, s.opacity))
  b.kind in (:block, :cell, :caption) && isempty(l.before) && (l.before = "\n")
  b.kind == :cell && b.col > 1 && l.before != "\t" && !isempty(l.words) && (l.before = "\t")
  decorate!(l, s, x, y, w, h, b.border; background)
  b.element !== nothing && b.element.tag == "a" && link!(l, b.link, x, y, w, h)
  cx, cy = x + b.border[4] + b.padding[4], y + b.border[1] + b.padding[1]
  if b.kind == :image
    iw, ih = w - b.border[2] - b.border[4] - b.padding[2] - b.padding[4], h - b.border[1] - b.border[3] - b.padding[1] - b.padding[3]
    if b.picture !== nothing && s.visible && iw > 0 && ih > 0
      push!(l.items, Picture(cx, cy, iw, ih, inner(corners(s, w, h), b.border), b.picture))
    elseif s.visible && iw > 2 && ih > 2
      # A picture that there isn't shows where it would be, as a browser shows it
      push!(l.items, Edge(cx, cy, iw, ih, SQUARE, (1.0, 1.0, 1.0, 1.0), ntuple(_ -> MISSING, 4), ntuple(_ -> :solid, 4)))
      # The words that stand for the picture show in its box when they fit
      f = font(s.family, s.size, s.weight, s.italic)
      widths = [drawn(f, c)[3] for c in b.text]
      if !isempty(b.text) && sum(widths) + 4 <= iw + 0.5 && f.ascent + f.descent + 4 <= ih + 0.5
        glyphs!(l, f, collect(b.text), widths, cx + 2, cy + 2 + f.ascent, s.color)
      end
    end
    link!(l, b.link, x, y, w, h)
  end
  clipped = s.overflow != :visible && b.kind != :image
  if clipped
    push!(l.items, Clip(x + b.border[4], y + b.border[1], w - b.border[2] - b.border[4], h - b.border[1] - b.border[3], inner(corners(s, w, h), b.border)))
  end
  # The bullet or the number of a list item, to the left of its first line
  if !isempty(b.marker) && s.visible
    f = font(s.family, s.size, s.weight, s.italic)
    base = y + something(first_baseline(b), b.border[1] + b.padding[1] + f.ascent)
    # The sizes and the places are the ones that Safari draws a bullet and a number with
    rise = round(Int, f.ascent)
    off = rise * 2 ÷ 3
    if s.listtype in (:disc, :circle, :square)
      d = Float64((off + 1) ÷ 2)
      bx, by = cx - off - 7, base - rise + 3 * (rise - off) ÷ 2
      s.listtype == :disc ? push!(l.items, Fill(bx, by, d, d, (d / 2, d / 2, d / 2, d / 2), s.color)) :
      s.listtype == :square ? push!(l.items, Fill(bx, by, d, d, SQUARE, s.color)) :
      push!(l.items, Edge(bx, by, d, d, (d / 2, d / 2, d / 2, d / 2), (1.0, 1.0, 1.0, 1.0), ntuple(_ -> s.color, 4), ntuple(_ -> :solid, 4)))
    else
      widths = [drawn(f, c)[3] for c in b.marker]
      glyphs!(l, f, collect(b.marker), widths, cx - sum(widths) - drawn(f, ' ')[3] - off / 2, base, s.color)
    end
  end
  for line in b.lines
    for sp in line.spans
      k = sp.box
      widths = (k.border[1], sp.last ? k.border[2] : 0.0, k.border[3], sp.first ? k.border[4] : 0.0)
      decorate!(l, k.style, cx + sp.left, cy + sp.top, sp.right - sp.left, sp.bottom - sp.top, widths)
      k.element !== nothing && k.element.tag == "a" && link!(l, k.link, cx + sp.left, cy + sp.top, sp.right - sp.left, sp.bottom - sp.top)
    end
    for q in line.pieces
      if q.kind == :atom
        emit!(l, q.box, x, y)
      elseif q.kind == :text && !isempty(q.chars)
        t = q.box.style
        f = font(t.family, t.size, t.weight, t.italic)
        px0, base = cx + q.x, cy + q.y
        top, tall = base - f.ascent, f.ascent + f.descent
        words!(l, line, q, px0, top, tall)
        (t.visible && t.size > 0 && alpha(t.color) > 0) || continue
        q.space || glyphs!(l, f, q.chars, q.widths, px0, base, t.color)
        if t.lines != 0 && q.width > 0
          thick = max(1.0, round(f.thick))
          t.lines & 0x01 != 0 && push!(l.items, Fill(px0, round(base + max(1.0, f.under) - thick / 2), q.width, thick, SQUARE, t.linecolor))
          t.lines & 0x02 != 0 && push!(l.items, Fill(px0, round(base - f.xheight / 2 - thick / 2), q.width, thick, SQUARE, t.linecolor))
          t.lines & 0x04 != 0 && push!(l.items, Fill(px0, round(base - f.ascent), q.width, thick, SQUARE, t.linecolor))
        end
      end
    end
    # A line that a <br> ended is a line of its own when the words are copied
    line.hard && (l.before = "\n")
  end
  if isempty(b.lines)
    for k in b.children
      (placed(k) || k.kind in (:text, :inline, :break, :column)) && continue
      emit!(l, k, x, y)
    end
  else
    each_float(k -> emit!(l, k, x, y), b)
    l.before = "\n"
  end
  for k in b.over
    emit!(l, k, x, y)
  end
  clipped && push!(l.items, Unclip())
  faded && push!(l.items, Unfade())
  nothing
end

"""
What to draw of the page whose <html> element has the box `root`, which is
laid out `wide` px wide and `tall` px tall. `pictures` gives the picture of an
address, as `boxes` takes it.
"""
list(root::Box, wide, tall; pictures=src -> nothing) = begin
  l = List(Item[], Link[], Words[], Float64(wide), Float64(tall), 0x00000000, pictures, "", nothing, nothing)
  # The background of the page is the <html> element's, or the <body>'s when that has none
  body = findfirst(k -> k.element !== nothing && k.element.tag == "body", root.children)
  from = alpha(root.style.background) > 0 || !isempty(root.style.image) || body === nothing ? root : root.children[body]
  s = from.style
  l.background = s.background
  alpha(s.background) > 0 && push!(l.items, Fill(0.0, 0.0, l.wide, l.tall, SQUARE, s.background))
  isempty(s.image) || backdrop!(l, s, 0.0, 0.0, l.wide, l.tall, SQUARE)
  l.behind = from
  emit!(l, root, 0.0, 0.0)
  l
end

# --- drawing ------------------------------------------------------------------------------

rect(x, y, w, h) = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))

"A Skia path round a box with the corners `r`"
outline(x, y, w, h, r::Radii) = begin
  p = Skia.sk_path_new()
  if r == SQUARE
    Skia.sk_path_add_rect(p, rect(x, y, w, h), Skia.SK_PATH_DIRECTION_CW)
    return p
  end
  right, bottom = x + w, y + h
  corner(cx, cy, rad, from) = begin
    oval = rect(cx - rad, cy - rad, 2rad, 2rad)
    rad > 0 ? Skia.sk_path_arc_to_with_oval(p, oval, Float32(from), 90f0, false) : Skia.sk_path_line_to(p, Float32(cx), Float32(cy))
  end
  Skia.sk_path_move_to(p, Float32(x + r[1]), Float32(y))
  corner(right - r[2], y + r[2], r[2], -90)
  corner(right - r[3], bottom - r[3], r[3], 0)
  corner(x + r[4], bottom - r[4], r[4], 90)
  corner(x + r[1], y + r[1], r[1], 180)
  Skia.sk_path_close(p)
  p
end

with_paint(f, color::UInt32) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, color)
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(0))
  try f(paint) finally Skia.sk_paint_delete(paint) end
end

fill_shape(canvas, x, y, w, h, radii, paint) = begin
  if radii == SQUARE
    Skia.sk_canvas_draw_rect(canvas, rect(x, y, w, h), paint)
  else
    p = outline(x, y, w, h, radii)
    Skia.sk_canvas_draw_path(canvas, p, paint)
    Skia.sk_path_delete(p)
  end
end

clip_shape(canvas, x, y, w, h, radii) = begin
  if radii == SQUARE
    Skia.sk_canvas_clip_rect_with_operation(canvas, rect(x, y, w, h), Skia.SK_CLIP_OP_INTERSECT, true)
  else
    p = outline(x, y, w, h, radii)
    Skia.sk_canvas_clip_path_with_operation(canvas, p, Skia.SK_CLIP_OP_INTERSECT, true)
    Skia.sk_path_delete(p)
  end
end

paint!(canvas, i::Fill) = with_paint(paint -> fill_shape(canvas, i.x, i.y, i.w, i.h, i.radii, paint), i.color)

darker(c::UInt32) = (part(shift) = UInt32(((c >> shift) & 0xff) * 2 ÷ 3) << shift; (c & 0xff000000) | part(16) | part(8) | part(0))

"The colour that side `i` of a border is drawn in: a border that looks pressed in or raised has two sides darker"
shade(e::Edge, i) = begin
  st = e.styles[i]
  dark = st in (:inset, :groove) ? i in (1, 4) : st in (:outset, :ridge) ? i in (2, 3) : false
  dark ? darker(e.colors[i]) : e.colors[i]
end

paint!(canvas, e::Edge) = begin
  x, y, w, h = e.x, e.y, e.w, e.h
  t, r, b, l = e.widths
  colors = ntuple(i -> shade(e, i), 4)
  shown = [i for i in 1:4 if e.widths[i] > 0 && alpha(colors[i]) > 0]
  isempty(shown) && return
  plain = all(i -> e.styles[i] in (:solid, :inset, :outset, :groove, :ridge, :double), shown)
  if e.radii == SQUARE && plain
    # Each side is a shape with slanted ends, so that two colours meet at a corner on a slant
    for i in shown
      pts = i == 1 ? ((x, y), (x + w, y), (x + w - r, y + t), (x + l, y + t)) :
            i == 2 ? ((x + w, y), (x + w, y + h), (x + w - r, y + h - b), (x + w - r, y + t)) :
            i == 3 ? ((x + w, y + h), (x, y + h), (x + l, y + h - b), (x + w - r, y + h - b)) :
                     ((x, y + h), (x, y), (x + l, y + t), (x + l, y + h - b))
      p = Skia.sk_path_new()
      Skia.sk_path_move_to(p, Float32(pts[1][1]), Float32(pts[1][2]))
      foreach(q -> Skia.sk_path_line_to(p, Float32(q[1]), Float32(q[2])), pts[2:end])
      Skia.sk_path_close(p)
      with_paint(colors[i]) do paint
        # Sides of one colour that meet at a square corner show no seam without smoothing
        Skia.sk_paint_set_antialias(paint, false)
        Skia.sk_canvas_draw_path(canvas, p, paint)
      end
      Skia.sk_path_delete(p)
    end
    return
  end
  if plain || e.radii != SQUARE
    # A ring: the shape of the border's outside, with the shape of its inside cut out
    outer = outline(x, y, w, h, e.radii)
    hole = outline(x + l, y + t, max(0.0, w - l - r), max(0.0, h - t - b), inner(e.radii, e.widths))
    ring = Skia.sk_path_new()
    Skia.sk_path_op(outer, hole, Skia.sk_path_op_t(0), ring)
    with_paint(colors[shown[1]]) do paint
      Skia.sk_canvas_draw_path(canvas, ring, paint)
    end
    foreach(Skia.sk_path_delete, (outer, hole, ring))
    return
  end
  # Dashes and dots, along the middle of each side
  for i in shown
    wd = e.widths[i]
    a, z = i == 1 ? ((x, y + t / 2), (x + w, y + t / 2)) : i == 2 ? ((x + w - r / 2, y), (x + w - r / 2, y + h)) :
           i == 3 ? ((x, y + h - b / 2), (x + w, y + h - b / 2)) : ((x + l / 2, y), (x + l / 2, y + h))
    with_paint(colors[i]) do paint
      Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
      Skia.sk_paint_set_stroke_width(paint, Float32(wd))
      effect = C_NULL
      if e.styles[i] in (:dashed, :dotted)
        n = e.styles[i] == :dashed ? 3wd : wd
        gaps = Float32[n, n]
        effect = Skia.sk_path_effect_create_dash(gaps, Cint(2), 0f0)
        Skia.sk_paint_set_path_effect(paint, effect)
      end
      p = Skia.sk_path_new()
      Skia.sk_path_move_to(p, Float32(a[1]), Float32(a[2]))
      Skia.sk_path_line_to(p, Float32(z[1]), Float32(z[2]))
      Skia.sk_canvas_draw_path(canvas, p, paint)
      Skia.sk_path_delete(p)
      effect == C_NULL || Skia.sk_path_effect_unref(effect)
    end
  end
end

paint!(canvas, g::Glyphs) = begin
  if g.blob == C_NULL
    builder = Skia.sk_textblob_builder_new()
    n = length(g.ids)
    run = unsafe_load(Skia.sk_textblob_builder_alloc_run_pos_h(builder, g.font.raw, Cint(n), 0f0, C_NULL))
    GC.@preserve g begin
      unsafe_copyto!(run.glyphs, pointer(g.ids), n)
      unsafe_copyto!(run.pos, pointer(g.xs), n)
    end
    g.blob = Skia.sk_textblob_builder_make(builder)
    Skia.sk_textblob_builder_delete(builder)
  end
  with_paint(g.color) do paint
    Skia.sk_canvas_draw_text_blob(canvas, g.blob, Float32(g.x), Float32(g.y), paint)
  end
end

const SAMPLING = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_LINEAR)

draw_image(canvas, image, x, y, w, h) = begin
  src = rect(0, 0, Skia.sk_image_get_width(image), Skia.sk_image_get_height(image))
  with_paint(0xffffffff) do paint
    Skia.sk_canvas_draw_image_rect(canvas, image, src, rect(x, y, w, h), Ref(SAMPLING), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
  end
end

paint!(canvas, i::Picture) = begin
  i.image == C_NULL && return
  round = i.radii != SQUARE
  round && (Skia.sk_canvas_save(canvas); clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii))
  draw_image(canvas, i.image, i.x, i.y, i.w, i.h)
  round && Skia.sk_canvas_restore(canvas)
end

paint!(canvas, i::Tiles) = begin
  i.image == C_NULL && return
  Skia.sk_canvas_save(canvas)
  clip_shape(canvas, i.x, i.y, i.w, i.h, i.radii)
  tw, th = i.size
  across = i.repeat in (:repeat, :repeat_x)
  down = i.repeat in (:repeat, :repeat_y)
  x0 = across ? i.ox - ceil(i.ox / tw) * tw : i.ox
  y0 = down ? i.oy - ceil(i.oy / th) * th : i.oy
  nx = across ? min(200, ceil(Int, (i.w - x0) / tw)) : 1
  ny = down ? min(200, ceil(Int, (i.h - y0) / th)) : 1
  for r in 0:ny-1, c in 0:nx-1
    draw_image(canvas, i.image, i.x + x0 + c * tw, i.y + y0 + r * th, tw, th)
  end
  Skia.sk_canvas_restore(canvas)
end

paint!(canvas, g::Gradient) = begin
  # The line that the colours run along goes through the middle of the box, and is as long as CSS says for its angle
  a = deg2rad(g.angle)
  dx, dy = sin(a), -cos(a)
  half = (abs(g.w * dx) + abs(g.h * dy)) / 2
  mx, my = g.x + g.w / 2, g.y + g.h / 2
  points = [Skia.sk_point_t(Float32(mx - dx * half), Float32(my - dy * half)), Skia.sk_point_t(Float32(mx + dx * half), Float32(my + dy * half))]
  shader = Skia.sk_shader_new_linear_gradient(points, g.colors, g.stops, Cint(length(g.colors)), Skia.sk_tile_mode_t(0), C_NULL)
  with_paint(0xffffffff) do paint
    Skia.sk_paint_set_shader(paint, shader)
    fill_shape(canvas, g.x, g.y, g.w, g.h, g.radii, paint)
  end
  Skia.sk_shader_unref(shader)
end

paint!(canvas, s::Shadow) = begin
  Skia.sk_canvas_save(canvas)
  # The box's own shape is cut out, so that a see-through background doesn't show the shadow behind it
  shape = outline(s.x, s.y, s.w, s.h, s.radii)
  Skia.sk_canvas_clip_path_with_operation(canvas, shape, Skia.SK_CLIP_OP_DIFFERENCE, true)
  Skia.sk_path_delete(shape)
  with_paint(s.color) do paint
    blur = C_NULL
    if s.blur > 0
      blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, Float32(s.blur / 2), true)
      Skia.sk_paint_set_maskfilter(paint, blur)
    end
    grown = map(r -> r > 0 ? max(0.0, r + s.spread) : 0.0, s.radii)
    fill_shape(canvas, s.x + s.dx - s.spread, s.y + s.dy - s.spread, s.w + 2s.spread, s.h + 2s.spread, grown, paint)
    blur == C_NULL || Skia.sk_maskfilter_unref(blur)
  end
  Skia.sk_canvas_restore(canvas)
end

paint!(canvas, c::Clip) = (Skia.sk_canvas_save(canvas); clip_shape(canvas, c.x, c.y, c.w, c.h, c.radii))
paint!(canvas, ::Unclip) = Skia.sk_canvas_restore(canvas)
paint!(canvas, f::Fade) = (Skia.sk_canvas_save_layer_alpha(canvas, rect(f.x - 50, f.y - 50, f.w + 100, f.h + 100), round(UInt8, clamp(f.opacity, 0, 1) * 255)); nothing)
paint!(canvas, ::Unfade) = Skia.sk_canvas_restore(canvas)

"The top and the bottom of what an item draws"
reach(i::Item) = (i.y, i.y + i.h)
reach(g::Glyphs) = (g.y - 2g.font.size, g.y + g.font.size)
reach(s::Shadow) = (s.y + s.dy - s.spread - 2s.blur, s.y + s.h + s.dy + s.spread + 2s.blur)
reach(::Union{Clip,Unclip,Fade,Unfade}) = (-Inf, Inf)

"How far right what the page draws goes, in px from its left edge"
right(l::List) = begin
  x = 0.0
  for i in l.items
    i isa Union{Fill,Edge,Picture,Tiles,Gradient,Glyphs} && (x = max(x, i.x + i.w))
  end
  x
end

"True when nothing of what `i` draws is in the part of the canvas that can be drawn on now"
hidden(canvas, i::Item) = Skia.sk_canvas_quick_reject_rect(canvas, rect(i.x, i.y, i.w, i.h))
hidden(canvas, g::Glyphs) = Skia.sk_canvas_quick_reject_rect(canvas, rect(g.x - g.font.size, g.y - 2g.font.size, g.w + 2g.font.size, 3g.font.size))
hidden(canvas, s::Shadow) = begin
  far = s.spread + 2s.blur
  Skia.sk_canvas_quick_reject_rect(canvas, rect(s.x + s.dx - far, s.y + s.dy - far, s.w + 2far, s.h + 2far))
end
hidden(canvas, ::Union{Clip,Unclip,Fade,Unfade}) = false

"""
Draw the page, with its top left corner at the canvas's. With `top` and
`bottom`, only what's between those two heights of the page is drawn. What
the canvas cuts off, as a window does with what's scrolled out of it, isn't
drawn either.
"""
draw(canvas, l::List; top=-Inf, bottom=Inf) = begin
  for i in l.items
    a, z = reach(i)
    (z < top || a > bottom || hidden(canvas, i)) && continue
    paint!(canvas, i)
  end
end
