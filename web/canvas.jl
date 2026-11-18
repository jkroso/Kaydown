# What a script draws on a <canvas>: the surface of each canvas element, and
# the drawing that a 2D context does on it, with Skia.
#
#     b = board(element)                 # the surface of a <canvas>, made when it's first asked for
#     rect!(b, 10, 10, 50, 20; how=:fill)
#     add!(b.shape, b.state.m, "M", (0.0, 0.0)); add!(b.shape, b.state.m, "L", (40.0, 30.0)); paint!(b, :stroke)
#     write!(b, "Hello", 10, 40)
#     image!(b)                          # Skia's picture of what's drawn, as it is now
#     found(element)                     # the surface of a <canvas> that something has drawn on, or nothing
#
# context.jl gives these to a page's scripts as `canvas.getContext('2d')`, and
# paint.jl draws the surface in the canvas's box. A surface is as many pixels
# as the element's `width` and `height` say: 300 by 150 with none.
#
# What's here: paths with lines, curves and arcs, filled and stroked, with
# both ways to say what's inside (`nonzero` and `evenodd`). Rectangles. Text.
# Pictures, other canvases and videos (`drawImage`). Colours, gradients of the
# three kinds and patterns. Shadows. Line widths, ends, corners and dashes.
# Moves, turns and stretches. Cuts (`clip`). How drawing mixes with what's
# there (`globalAlpha`, `globalCompositeOperation`). Reading and writing
# pixels. A PNG, a JPEG or a WebP of the surface.
#
# What isn't: `filter`, `letterSpacing` and the like, `isPointInStroke`, and
# any context but `2d`: nothing draws in 3D (WebGL).

@use Skia
@use Base64: base64encode
@use "./dom" Element attr
@use "./style" colour CURRENT
@use "./text" Font font drawn

const Matrix = NTuple{6,Float64}   # a, b, c, d, e, f, as CSS and a canvas have them
const SAME = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

"The move `m`, then within it the move `n`"
times(m, n) = (m[1] * n[1] + m[3] * n[2], m[2] * n[1] + m[4] * n[2], m[1] * n[3] + m[3] * n[4], m[2] * n[3] + m[4] * n[4],
               m[1] * n[5] + m[3] * n[6] + m[5], m[2] * n[5] + m[4] * n[6] + m[6])
moved(m, x, y) = (m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6])
skia(m) = Ref(Skia.sk_matrix_t(Float32(m[1]), Float32(m[3]), Float32(m[5]), Float32(m[2]), Float32(m[4]), Float32(m[6]), 0f0, 0f0, 1f0))
"The move that undoes `m`, or nothing for one that flattens everything onto a line"
undo(m) = begin
  det = m[1] * m[4] - m[2] * m[3]
  (isfinite(det) && abs(det) > 1e-12) || return nothing
  (m[4] / det, -m[2] / det, -m[3] / det, m[1] / det, (m[3] * m[6] - m[4] * m[5]) / det, (m[2] * m[5] - m[1] * m[6]) / det)
end
box(x, y, w, h) = Ref(Skia.sk_rect_t(Float32(min(x, x + w)), Float32(min(y, y + h)), Float32(max(x, x + w)), Float32(max(y, y + h))))

"Colours that run into each other, as a fill or a stroke"
struct Gradient
  kind::Symbol                 # :linear, :radial or :conic
  at::NTuple{6,Float64}        # of a line: its two ends. Of circles: the centre and the radius of each. Round a point: the angle, then the point.
  stops::Vector{Tuple{Float64,UInt32}}
end

"A picture that's laid side by side, as a fill or a stroke"
struct Pattern
  source::Any                  # what `picture` of the board's caller knows a picture by
  across::Bool                 # it's laid again and again across, and down
  down::Bool
end

"How a context draws: what `save()` keeps and `restore()` brings back"
mutable struct State
  m::Matrix
  fill::Any                    # a colour, a Gradient or a Pattern
  stroke::Any
  wide::Float64                # of a line
  cap::Symbol                  # :butt, :round or :square
  join::Symbol                 # :miter, :round or :bevel
  miter::Float64
  dash::Vector{Float32}
  phase::Float64
  alpha::Float64
  blend::Int                   # Skia's number for how the drawing mixes with what's there
  font::Font
  align::Symbol                # :start, :end, :left, :right or :center
  base::Symbol                 # :alphabetic, :top, :hanging, :middle, :ideographic or :bottom
  shadow::UInt32
  blur::Float64
  dx::Float64
  dy::Float64
  smooth::Bool                 # a picture that's made bigger is smoothed
end
State() = State(SAME, 0xff000000, 0xff000000, 1.0, :butt, :miter, 10.0, Float32[], 0.0, 1.0, 3, font(["sans-serif"], 10.0), :start, :alphabetic, 0x00000000, 0.0, 0.0, 0.0, true)
Base.copy(s::State) = State((getfield(s, f) for f in fieldnames(State))...)

"A path that's being made"
mutable struct Shape
  path::Ptr{Skia.sk_path_t}
  open::Bool                   # it has a point to go on from
  Shape() = finalizer(s -> Skia.sk_path_delete(s.path), new(Skia.sk_path_new(), false))
end

"The surface of a <canvas>, and how its context draws now"
mutable struct Board
  wide::Int
  high::Int
  pixels::Vector{UInt8}        # red, green, blue and how solid, for each pixel. The colours are already made fainter by how solid the pixel is.
  surface::Ptr{Skia.sk_surface_t}
  canvas::Ptr{Skia.sk_canvas_t}
  state::State
  saved::Vector{State}
  shape::Shape                 # the path of the context, in the pixels of the surface
  picture::Function            # what a picture is to this page: gives Skia's picture of an element, its width and its height, or nothing
  changes::Int                 # how many times it was drawn on
  image::Ptr{Cvoid}            # Skia's picture of the surface as it was after `shown` changes, or C_NULL
  shown::Int
end

# No surface has more pixels than this, across or down
const MOST = 8192
# And none takes more room than a surface of this many pixels: 256 MB
const ROOM = 64_000_000

"How wide and how high the surface of the <canvas> element `e` is, in pixels"
extent(e::Element) = begin
  side(name, default) = (n = tryparse(Float64, strip(attr(e, name))); n === nothing || !isfinite(n) || n < 0 ? default : clamp(floor(Int, n), 0, MOST))
  w, h = side("width", 300), side("height", 150)
  # A surface that would be too big is made smaller, with the same shape
  w * h > ROOM && ((w, h) = (floor(Int, w * sqrt(ROOM / (w * h))), floor(Int, h * sqrt(ROOM / (w * h)))))
  (w, h)
end

Board(wide::Integer, high::Integer; picture=source -> nothing) = begin
  b = Board(wide, high, UInt8[], C_NULL, C_NULL, State(), State[], Shape(), picture, 0, C_NULL, -1)
  finalizer(release, b)
  clear!(b, wide, high)
end

release(b::Board) = begin
  b.surface == C_NULL || Skia.sk_surface_unref(b.surface)
  b.image == C_NULL || Skia.sk_image_unref(b.image)
  b.surface = b.canvas = b.image = C_NULL
  nothing
end

"Make the surface `wide` by `high` pixels, with nothing drawn on it, and its context as a new one is"
clear!(b::Board, wide::Integer=b.wide, high::Integer=b.high) = begin
  release(b)
  b.wide, b.high = wide, high
  b.pixels = zeros(UInt8, 4 * max(1, wide) * max(1, high))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, max(1, wide), max(1, high)))
  # Skia draws straight into `pixels`, so reading and writing pixels needs no copy
  b.surface = GC.@preserve info Skia.sk_surface_make_raster_direct(pointer_from_objref(info), b.pixels, Csize_t(4 * max(1, wide)), C_NULL)
  b.surface == C_NULL && error("Skia could not make a surface $wide by $high")
  b.canvas = Skia.sk_surface_get_canvas(b.surface)
  b.state = State()
  empty!(b.saved)
  b.shape = Shape()
  b.changes += 1
  b
end

# The surface of each <canvas> that something has asked for. A surface goes when Julia frees its element.
const BOARDS = WeakKeyDict{Element,Board}()

"The surface of the <canvas> element `e`. It's made when it's first asked for, and made again, empty, when the element's size has changed."
board(e::Element; picture=source -> nothing) = begin
  w, h = extent(e)
  b = get!(() -> Board(w, h; picture), BOARDS, e)
  (b.wide, b.high) == (w, h) || clear!(b, w, h)
  b
end

"The surface of the <canvas> element `e` when something has asked for it, or nothing"
found(e::Element) = begin
  b = get(BOARDS, e, nothing)
  b === nothing && return nothing
  (b.wide, b.high) == extent(e) || clear!(b, extent(e)...)
  b
end

touch!(b::Board) = (b.changes += 1; nothing)

"Skia's picture of the surface as it is now, or C_NULL for a surface with no pixels. It's good until the surface is drawn on again."
image!(b::Board) = begin
  (b.wide == 0 || b.high == 0) && return C_NULL
  b.image != C_NULL && b.shown == b.changes && return b.image
  b.image == C_NULL || Skia.sk_image_unref(b.image)
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, b.wide, b.high))
  data = Skia.sk_data_new_with_copy(b.pixels, Csize_t(length(b.pixels)))
  b.image = Ptr{Cvoid}(GC.@preserve info Skia.sk_image_new_raster_data(pointer_from_objref(info), data, Csize_t(4 * b.wide)))
  Skia.sk_data_unref(data)
  b.shown = b.changes
  b.image
end

# --- how it draws -------------------------------------------------------------------------

save!(b::Board) = (push!(b.saved, copy(b.state)); Skia.sk_canvas_save(b.canvas); nothing)
restore!(b::Board) = begin
  isempty(b.saved) && return
  b.state = pop!(b.saved)
  Skia.sk_canvas_restore(b.canvas)
  nothing
end

"Move, turn or stretch what's drawn from now on: `m` is the whole move, from the surface's own pixels"
matrix!(b::Board, m) = begin
  all(isfinite, m) || return
  b.state.m = Matrix(Float64.(m))
  Skia.sk_canvas_set_matrix(b.canvas, skia(b.state.m))
  nothing
end
"Move, turn or stretch what's drawn from now on by `m`, within how it's moved already"
turn!(b::Board, m) = matrix!(b, times(b.state.m, m))

"The colour that `text` writes, as a UInt32 like 0xAARRGGBB, or nothing"
ink(text::AbstractString) = begin
  c = colour(lowercase(strip(text)))
  c isa UInt32 ? (c == CURRENT ? 0xff000000 : c) : nothing
end

"A colour as a context gives it back: `#rrggbb`, or `rgba(r, g, b, a)` for one that's see-through"
written(c::UInt32) = begin
  r, g, bl, a = (c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff, c >> 24
  a == 0xff && return "#" * string(c & 0x00ffffff, base=16, pad=6)
  # With two digits when that says the same colour, as a browser writes it
  short = round(a / 255, digits=2)
  solid = round(Int, short * 255) == a ? short : round(a / 255, digits=3)
  "rgba($r, $g, $bl, $(isinteger(solid) ? Int(solid) : solid))"
end

const BLENDS = Dict("source-over" => 3, "source-in" => 5, "source-out" => 7, "source-atop" => 9, "destination-over" => 4, "destination-in" => 6,
                    "destination-out" => 8, "destination-atop" => 10, "lighter" => 12, "copy" => 1, "xor" => 11, "multiply" => 24, "screen" => 14,
                    "overlay" => 15, "darken" => 16, "lighten" => 17, "color-dodge" => 18, "color-burn" => 19, "hard-light" => 20, "soft-light" => 21,
                    "difference" => 22, "exclusion" => 23, "hue" => 25, "saturation" => 26, "color" => 27, "luminosity" => 28)

const SMOOTH = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_NONE)
const SHARP = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_NEAREST, Skia.SK_MIPMAP_MODE_NONE)

faint(c::UInt32, alpha) = (c & 0x00ffffff) | (round(UInt32, clamp((c >> 24) * alpha, 0.0, 255.0)) << 24)

"Skia's shader for a gradient or a pattern, or C_NULL when it draws nothing"
shader(b::Board, g::Gradient) = begin
  isempty(g.stops) && return C_NULL
  colors = UInt32[s[2] for s in g.stops]
  places = Float32[s[1] for s in g.stops]
  n = Cint(length(colors))
  mode = Skia.sk_tile_mode_t(0)
  if g.kind == :linear
    points = [Skia.sk_point_t(Float32(g.at[1]), Float32(g.at[2])), Skia.sk_point_t(Float32(g.at[3]), Float32(g.at[4]))]
    Skia.sk_shader_new_linear_gradient(points, colors, places, n, mode, C_NULL)
  elseif g.kind == :radial
    Skia.sk_shader_new_two_point_conical_gradient(Ref(Skia.sk_point_t(Float32(g.at[1]), Float32(g.at[2]))), Float32(g.at[3]),
                                                  Ref(Skia.sk_point_t(Float32(g.at[4]), Float32(g.at[5]))), Float32(g.at[6]), colors, places, n, mode, C_NULL)
  else
    # It starts at its angle, and Skia starts at the right
    r, x, y = g.at[1], g.at[2], g.at[3]
    m = times(times((1.0, 0.0, 0.0, 1.0, x, y), (cos(r), sin(r), -sin(r), cos(r), 0.0, 0.0)), (1.0, 0.0, 0.0, 1.0, -x, -y))
    Skia.sk_shader_new_sweep_gradient(Ref(Skia.sk_point_t(Float32(x), Float32(y))), colors, places, n, mode, 0f0, 360f0, skia(m))
  end
end
shader(b::Board, p::Pattern) = begin
  got = b.picture(p.source)
  got === nothing && return C_NULL
  mode(again) = Skia.sk_tile_mode_t(again ? 1 : 3)
  Skia.sk_image_make_shader(got[1], mode(p.across), mode(p.down), Ref(b.state.smooth ? SMOOTH : SHARP), C_NULL)
end

"""
Call `f` with Skia's paint for what the context draws now: `how` is `:fill`,
`:stroke`, or `:picture` for a picture, which takes no colour. Nothing is
drawn with a gradient that has no colours.
"""
brush(f, b::Board, how::Symbol) = begin
  s = b.state
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  made = effect = shade = C_NULL
  try
    with = how == :stroke ? s.stroke : how == :fill ? s.fill : 0xffffffff
    if with isa UInt32
      Skia.sk_paint_set_color(paint, faint(with, s.alpha))
    else
      made = shader(b, with)
      made == C_NULL && return nothing
      Skia.sk_paint_set_shader(paint, made)
      Skia.sk_paint_set_color(paint, faint(0xffffffff, s.alpha))
    end
    s.blend == 3 || Skia.sk_paint_set_blend_mode(paint, Skia.sk_blend_mode_t(s.blend))
    if how == :stroke
      Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
      Skia.sk_paint_set_stroke_width(paint, Float32(s.wide))
      Skia.sk_paint_set_stroke_cap(paint, Skia.sk_stroke_cap_t(s.cap == :round ? 1 : s.cap == :square ? 2 : 0))
      Skia.sk_paint_set_stroke_join(paint, Skia.sk_stroke_join_t(s.join == :round ? 1 : s.join == :bevel ? 2 : 0))
      Skia.sk_paint_set_stroke_miter(paint, Float32(s.miter))
      if !isempty(s.dash) && any(>(0), s.dash)
        effect = Skia.sk_path_effect_create_dash(s.dash, Cint(length(s.dash)), Float32(s.phase))
        Skia.sk_paint_set_path_effect(paint, effect)
      end
    end
    if (s.shadow >> 24) != 0 && (s.blur > 0 || s.dx != 0 || s.dy != 0)
      shade = Skia.sk_imagefilter_new_drop_shadow(Float32(s.dx), Float32(s.dy), Float32(s.blur / 2), Float32(s.blur / 2), faint(s.shadow, s.alpha), C_NULL, C_NULL)
      Skia.sk_paint_set_imagefilter(paint, shade)
    end
    f(paint)
    touch!(b)
  finally
    Skia.sk_paint_delete(paint)
    made == C_NULL || Skia.sk_shader_unref(made)
    effect == C_NULL || Skia.sk_path_effect_unref(effect)
    shade == C_NULL || Skia.sk_imagefilter_unref(shade)
  end
  nothing
end

# --- rectangles ---------------------------------------------------------------------------

"Fill or stroke a rectangle, or with `how=:clear` take away what's drawn in it"
rect!(b::Board, x, y, w, h; how::Symbol=:fill) = begin
  all(isfinite, (x, y, w, h)) || return
  if how == :clear
    paint = Skia.sk_paint_new()
    Skia.sk_paint_set_blend_mode(paint, Skia.sk_blend_mode_t(0))
    Skia.sk_canvas_draw_rect(b.canvas, box(x, y, w, h), paint)
    Skia.sk_paint_delete(paint)
    return touch!(b)
  end
  (how == :fill && (w == 0 || h == 0)) && return
  brush(paint -> Skia.sk_canvas_draw_rect(b.canvas, box(x, y, w, h), paint), b, how)
end

# --- paths --------------------------------------------------------------------------------

"Start the path again, with nothing in it"
Base.empty!(s::Shape) = (Skia.sk_path_rewind(s.path); s.open = false; s)

"The last point of the path, or nothing"
last_point(s::Shape) = begin
  p = Ref(Skia.sk_point_t(0f0, 0f0))
  Skia.sk_path_get_last_point(s.path, p) ? (Float64(p[].x), Float64(p[].y)) : nothing
end

"Add to `into` the path that `f` makes, moved by `m`. With `joined`, a line goes from where `into` had got to, to where it starts."
part!(f, into::Shape, m, joined::Bool) = begin
  made = Skia.sk_path_new()
  f(made)
  Skia.sk_path_add_path_matrix(into.path, made, skia(m), Skia.sk_path_add_mode_t(joined && into.open ? 1 : 0))
  Skia.sk_path_delete(made)
  into.open = true
  into
end

"How far round an arc goes from the angle `from` to `to`, in radians: never more than once round"
sweep(from, to, back::Bool) = begin
  d = to - from
  back ? (d <= -2π ? -2π : d > 0 ? mod(d, 2π) - 2π : d) : (d >= 2π ? 2π : d < 0 ? mod(d, 2π) : d)
end

"Add an arc of the oval with its centre at the origin to the Skia path `made`"
arc_of(made, rx, ry, from, to, back) = begin
  oval = Ref(Skia.sk_rect_t(Float32(-rx), Float32(-ry), Float32(rx), Float32(ry)))
  turn = rad2deg(sweep(from, to, back))
  # Skia draws nothing for an arc that goes all the way round, so it's made in two halves
  if abs(turn) >= 360
    Skia.sk_path_arc_to_with_oval(made, oval, Float32(rad2deg(from)), Float32(turn / 2), true)
    Skia.sk_path_arc_to_with_oval(made, oval, Float32(rad2deg(from) + turn / 2), Float32(turn / 2), false)
  else
    Skia.sk_path_arc_to_with_oval(made, oval, Float32(rad2deg(from)), Float32(turn), true)
  end
end

"The four corners of a rounded rectangle: for each, how far across and how far down it's round"
corners(radii, w, h) = begin
  r = radii isa Real ? Any[radii] : collect(Any, radii)
  one(x) = x isa Real ? (Float64(x), Float64(x)) : (Float64(x[1]), Float64(x[2]))
  r = map(one, isempty(r) ? Any[0.0] : r)
  four = length(r) == 1 ? [r[1], r[1], r[1], r[1]] : length(r) == 2 ? [r[1], r[2], r[1], r[2]] : length(r) == 3 ? [r[1], r[2], r[3], r[2]] : r[1:4]
  # Corners that would meet are all made smaller together
  top, bottom, left, right = four[1][1] + four[2][1], four[4][1] + four[3][1], four[1][2] + four[4][2], four[2][2] + four[3][2]
  k = min(1.0, (abs(w) / x for x in (top, bottom) if x > 0)..., (abs(h) / x for x in (left, right) if x > 0)...)
  [(c[1] * k, c[2] * k) for c in four]
end

"""
Add one step to a path, as a context's own function of that name does. `m` is
how the context is moved now: a path is kept in the pixels of the surface.

`M` moveTo, `L` lineTo, `Q` quadraticCurveTo, `C` bezierCurveTo, `Z` closePath,
`R` rect, `U` roundRect, `A` arc, `E` ellipse, `T` arcTo, and `S` the path
that SVG writes as text.
"""
add!(s::Shape, m, op::AbstractString, a) = begin
  n = op == "S" || op == "U" ? a : Float64[Float64(x) for x in a]
  op in ("S", "U") || all(isfinite, n) || return s
  if op == "M"
    Skia.sk_path_move_to(s.path, Float32.(moved(m, n[1], n[2]))...)
    s.open = true
  elseif op == "L"
    p = Float32.(moved(m, n[1], n[2]))
    s.open ? Skia.sk_path_line_to(s.path, p...) : Skia.sk_path_move_to(s.path, p...)
    s.open = true
  elseif op == "Q"
    s.open || add!(s, m, "M", n[1:2])
    Skia.sk_path_quad_to(s.path, Float32.(moved(m, n[1], n[2]))..., Float32.(moved(m, n[3], n[4]))...)
  elseif op == "C"
    s.open || add!(s, m, "M", n[1:2])
    Skia.sk_path_cubic_to(s.path, Float32.(moved(m, n[1], n[2]))..., Float32.(moved(m, n[3], n[4]))..., Float32.(moved(m, n[5], n[6]))...)
  elseif op == "Z"
    s.open && Skia.sk_path_close(s.path)
  elseif op == "R"
    x, y, w, h = n
    part!(s, m, false) do made
      Skia.sk_path_move_to(made, Float32(x), Float32(y))
      Skia.sk_path_line_to(made, Float32(x + w), Float32(y))
      Skia.sk_path_line_to(made, Float32(x + w), Float32(y + h))
      Skia.sk_path_line_to(made, Float32(x), Float32(y + h))
      Skia.sk_path_close(made)
    end
    # The path goes on from the rectangle's first corner
    Skia.sk_path_move_to(s.path, Float32.(moved(m, x, y))...)
  elseif op == "U"
    x, y, w, h = Float64.(a[1:4])
    all(isfinite, (x, y, w, h)) || return s
    # A rectangle with a width or a height below nothing is the same one, written from its other corner
    w < 0 && ((x, w) = (x + w, -w))
    h < 0 && ((y, h) = (y + h, -h))
    c = corners(length(a) > 4 ? a[5] : 0.0, w, h)
    # A quarter of an oval, as a curve that's very near it
    k = 0.5522847498
    part!(s, m, false) do made
      to(px, py) = Skia.sk_path_line_to(made, Float32(px), Float32(py))
      bend(a1, b1, a2, b2, px, py) = Skia.sk_path_cubic_to(made, Float32(a1), Float32(b1), Float32(a2), Float32(b2), Float32(px), Float32(py))
      Skia.sk_path_move_to(made, Float32(x + c[1][1]), Float32(y))
      to(x + w - c[2][1], y)
      bend(x + w - c[2][1] * (1 - k), y, x + w, y + c[2][2] * (1 - k), x + w, y + c[2][2])
      to(x + w, y + h - c[3][2])
      bend(x + w, y + h - c[3][2] * (1 - k), x + w - c[3][1] * (1 - k), y + h, x + w - c[3][1], y + h)
      to(x + c[4][1], y + h)
      bend(x + c[4][1] * (1 - k), y + h, x, y + h - c[4][2] * (1 - k), x, y + h - c[4][2])
      to(x, y + c[1][2])
      bend(x, y + c[1][2] * (1 - k), x + c[1][1] * (1 - k), y, x + c[1][1], y)
      Skia.sk_path_close(made)
    end
    Skia.sk_path_move_to(s.path, Float32.(moved(m, x, y))...)
  elseif op == "A"
    x, y, r, from, to = n[1:5]
    r < 0 && error("The radius of an arc can't be less than nothing")
    part!(made -> arc_of(made, r, r, from, to, length(n) > 5 && n[6] != 0), s, times(m, (1.0, 0.0, 0.0, 1.0, x, y)), true)
  elseif op == "E"
    x, y, rx, ry, turned, from, to = n[1:7]
    (rx < 0 || ry < 0) && error("The radius of an oval can't be less than nothing")
    around = times(times(m, (1.0, 0.0, 0.0, 1.0, x, y)), (cos(turned), sin(turned), -sin(turned), cos(turned), 0.0, 0.0))
    part!(made -> arc_of(made, rx, ry, from, to, length(n) > 7 && n[8] != 0), s, around, true)
  elseif op == "T"
    x1, y1, x2, y2, r = n[1:5]
    r < 0 && error("The radius of an arc can't be less than nothing")
    s.open || add!(s, m, "M", (x1, y1))
    back, from = undo(m), last_point(s)
    (back === nothing || from === nothing) && return s
    part!(s, m, true) do made
      Skia.sk_path_move_to(made, Float32.(moved(back, from...))...)
      Skia.sk_path_arc_to_with_points(made, Float32(x1), Float32(y1), Float32(x2), Float32(y2), Float32(r))
    end
  elseif op == "S"
    part!(made -> Skia.sk_path_parse_svg_string(made, String(a[1])), s, m, false)
  end
  s
end

"The path that the steps `steps` make: each is the name of a step, then what it takes"
shape(steps, m=SAME) = begin
  s = Shape()
  foreach(step -> add!(s, m, String(step[1]), step[2:end]), steps)
  s
end

"Skia's path of `s` as it is where the context is moved by `m`, or nothing when there's no such path. The caller deletes it."
within(s::Shape, m, rule) = begin
  back = undo(m)
  back === nothing && return nothing
  made = Skia.sk_path_new()
  Skia.sk_path_transform_to_dest(s.path, skia(back), made)
  Skia.sk_path_set_filltype(made, Skia.sk_path_fill_type_t(rule == "evenodd" ? 1 : 0))
  made
end

"Fill or stroke the path `s`: the context's own with none. `rule` is `nonzero` or `evenodd`: what counts as inside a path that crosses itself."
paint!(b::Board, how::Symbol, s::Shape=b.shape; rule="nonzero") = begin
  made = within(s, b.state.m, rule)
  made === nothing && return
  try brush(paint -> Skia.sk_canvas_draw_path(b.canvas, made, paint), b, how) finally Skia.sk_path_delete(made) end
end

"Cut what's drawn from now on to the inside of the path `s`, until `restore!`"
clip!(b::Board, s::Shape=b.shape; rule="nonzero") = begin
  Skia.sk_path_set_filltype(s.path, Skia.sk_path_fill_type_t(rule == "evenodd" ? 1 : 0))
  Skia.sk_canvas_set_matrix(b.canvas, skia(SAME))
  Skia.sk_canvas_clip_path_with_operation(b.canvas, s.path, Skia.SK_CLIP_OP_INTERSECT, true)
  Skia.sk_canvas_set_matrix(b.canvas, skia(b.state.m))
  nothing
end

"True when the pixel `(x, y)` of the surface is inside the path `s`"
inside(s::Shape, x, y; rule="nonzero") = begin
  Skia.sk_path_set_filltype(s.path, Skia.sk_path_fill_type_t(rule == "evenodd" ? 1 : 0))
  Skia.sk_path_contains(s.path, Float32(x), Float32(y))
end

# --- text ---------------------------------------------------------------------------------

const UNITS = Dict("px" => 1.0, "pt" => 4 / 3, "pc" => 16.0, "in" => 96.0, "cm" => 96 / 2.54, "mm" => 96 / 25.4, "em" => 16.0, "rem" => 16.0, "%" => 0.16)
const GENERIC = ("serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "ui-sans-serif", "ui-serif", "ui-monospace", "ui-rounded", "math", "emoji")

"The font that a context's `font` names, like `italic bold 16px Georgia, serif`, or nothing when it can't be read"
lettering(text::AbstractString) = begin
  m = match(r"^\s*((?:[a-z0-9-]+\s+)*?)([0-9]*\.?[0-9]+)(px|pt|pc|in|cm|mm|em|rem|%)(?:\s*/\s*[^\s,]+)?\s+(.+?)\s*$"is, text)
  m === nothing && return nothing
  before = split(lowercase(m[1]))
  weight = "bold" in before || "bolder" in before ? 700 : "lighter" in before ? 300 : something((tryparse(Int, w) for w in before if occursin(r"^[1-9]00$", w))..., 400)
  size = Base.parse(Float64, m[2]) * UNITS[lowercase(m[3])]
  names = [String(strip(strip(n), ['"', '\''])) for n in split(m[4], ',')]
  names = filter(!isempty, map(n -> lowercase(n) in GENERIC ? lowercase(n) : n, names))
  (isempty(names) || size <= 0) && return nothing
  font(names, size, weight, "italic" in before || "oblique" in before)
end

"A font as a context gives it back"
written(f::Font, weight, italic) = string(italic ? "italic " : "", weight == 400 ? "" : weight == 700 ? "bold " : "$weight ", isinteger(f.size) ? Int(f.size) : f.size, "px ", f.family)

"The letters of `text` as a context draws them: a tab and a line's end are a space"
letters(text) = Char[c in ('\t', '\n', '\r', '\f', '\v') ? ' ' : c for c in text]

"How wide `text` is in the context's font, in px"
measure(b::Board, text::AbstractString) = sum(c -> drawn(b.state.font, c)[3], letters(text); init=0.0)

"Fill or stroke `text` with its line at `(x, y)`. Text that's wider than `most` px is squeezed to fit."
write!(b::Board, text::AbstractString, x, y; how::Symbol=:fill, most=Inf) = begin
  (isfinite(x) && isfinite(y)) || return
  s, f = b.state, b.state.font
  chars = letters(text)
  got = [drawn(f, c) for c in chars]
  wide = sum(g -> g[3], got; init=0.0)
  (isempty(chars) || most <= 0) && return
  squeeze = wide > most ? most / wide : 1.0
  left = s.align in (:start, :left) ? x : s.align == :center ? x - wide * squeeze / 2 : x - wide * squeeze
  line = s.base == :top ? y + f.ascent : s.base == :hanging ? y + 0.8f.ascent : s.base == :middle ? y + (f.ascent - f.descent) / 2 :
         s.base in (:bottom, :ideographic) ? y - f.descent : y
  brush(b, how) do paint
    Skia.sk_canvas_save(b.canvas)
    Skia.sk_canvas_translate(b.canvas, Float32(left), Float32(line))
    squeeze == 1 || Skia.sk_canvas_scale(b.canvas, Float32(squeeze), 1f0)
    # The letters of one font go together. A letter that the font doesn't have comes from another.
    i, at = 1, 0.0
    while i <= length(got)
      use = got[i][1]
      ids, xs, from = UInt16[], Float32[], at
      while i <= length(got) && got[i][1] === use
        got[i][2] == 0 || (push!(ids, got[i][2]); push!(xs, Float32(at - from)))
        at += got[i][3]
        i += 1
      end
      isempty(ids) && continue
      builder = Skia.sk_textblob_builder_new()
      run = unsafe_load(Skia.sk_textblob_builder_alloc_run_pos_h(builder, use.raw, Cint(length(ids)), 0f0, C_NULL))
      GC.@preserve ids xs begin
        unsafe_copyto!(run.glyphs, pointer(ids), length(ids))
        unsafe_copyto!(run.pos, pointer(xs), length(xs))
      end
      blob = Skia.sk_textblob_builder_make(builder)
      Skia.sk_textblob_builder_delete(builder)
      Skia.sk_canvas_draw_text_blob(b.canvas, blob, Float32(from), 0f0, paint)
      Skia.sk_textblob_unref(blob)
    end
    Skia.sk_canvas_restore(b.canvas)
  end
end

# --- pictures and pixels ------------------------------------------------------------------

"""
Draw Skia's picture `image`, `iw` by `ih` px. `from` is the part of it that's
drawn, and `to` is where on the surface: each is a left, a top, a width and a
height.
"""
stamp!(b::Board, image, iw, ih, from, to) = begin
  (all(isfinite, from) && all(isfinite, to)) || return
  (image == C_NULL || from[3] == 0 || from[4] == 0) && return
  brush(b, :picture) do paint
    Skia.sk_canvas_draw_image_rect(b.canvas, image, box(from...), box(to...), Ref(b.state.smooth ? SMOOTH : SHARP), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
  end
end

"The part of the surface that's both on it and in the rectangle: its left, its top, its right and its bottom"
onboard(b::Board, x, y, w, h) = (clamp(x, 0, b.wide), clamp(y, 0, b.high), clamp(x + w, 0, b.wide), clamp(y + h, 0, b.high))

"""
The pixels of a rectangle of the surface: four bytes for each, which are how
red, how green, how blue and how solid it is. A pixel that's off the surface
is four zeros.
"""
pixels(b::Board, x::Integer, y::Integer, w::Integer, h::Integer) = begin
  out = zeros(UInt8, 4 * w * h)
  x0, y0, x1, y1 = onboard(b, x, y, w, h)
  for row in y0:y1-1, col in x0:x1-1
    i = 4 * (row * b.wide + col)
    o = 4 * ((row - y) * w + (col - x))
    a = b.pixels[i+4]
    a == 0 && continue
    # The surface keeps each colour made fainter by how solid the pixel is
    for k in 1:3
      out[o+k] = a == 0xff ? b.pixels[i+k] : UInt8(min(255, div(Int(b.pixels[i+k]) * 255 + a ÷ 2, a)))
    end
    out[o+4] = a
  end
  out
end

"Put the pixels `data`, which `pixels` gives for a rectangle `w` by `h`, on the surface with their corner at `(x, y)`, in place of what's there"
pixels!(b::Board, data::AbstractVector{UInt8}, x::Integer, y::Integer, w::Integer, h::Integer) = begin
  length(data) >= 4 * w * h || error("There are too few pixels for a rectangle $w by $h")
  x0, y0, x1, y1 = onboard(b, x, y, w, h)
  for row in y0:y1-1, col in x0:x1-1
    i = 4 * (row * b.wide + col)
    o = 4 * ((row - y) * w + (col - x))
    a = data[o+4]
    for k in 1:3
      b.pixels[i+k] = a == 0xff ? data[o+k] : UInt8(div(Int(data[o+k]) * a + 127, 255))
    end
    b.pixels[i+4] = a
  end
  touch!(b)
end

"The bytes of a picture file of the surface: `kind` is `image/png`, `image/jpeg` or `image/webp`, and `quality` is from 0 to 1"
encoded(b::Board, kind::AbstractString="image/png", quality=0.92) = begin
  image = image!(b)
  image == C_NULL && return UInt8[]
  q = quality isa Real && 0 <= quality <= 1 ? Float64(quality) : 0.92
  data = kind == "image/jpeg" ? Skia.sk_encode_jpeg(C_NULL, image, Cint(round(Int, 100q))) :
         kind == "image/webp" ? Skia.sk_encode_webp(C_NULL, image, Float32(100q), true) : Skia.sk_encode_png(C_NULL, image, Cint(6))
  data == C_NULL && return UInt8[]
  out = copy(unsafe_wrap(Array, Ptr{UInt8}(Skia.sk_data_get_data(data)), Skia.sk_data_get_size(data)))
  Skia.sk_data_unref(data)
  out
end

"The surface as an address that holds a picture file of it: `data:image/png;base64,...`"
address(b::Board, kind::AbstractString="image/png", quality=0.92) = begin
  kind = lowercase(kind) in ("image/jpeg", "image/webp") ? lowercase(kind) : "image/png"
  bytes = encoded(b, kind, quality)
  isempty(bytes) ? "data:," : "data:$kind;base64," * base64encode(bytes)
end
