# Works out how each element of a page looks: its `Style`, from the page's
# CSS, what its tag says (`<td bgcolor=red width=50%>`), and what a browser
# gives each tag to start with.
#
#     doc = document(html)
#     look = styles(doc, 700)      # for a page 700 px wide
#     s = look[element]
#     s.display, s.color, s.size   # :block, 0xff000000, 16.0
#     px(s.width, 700)             # a length in px, where a percent is of 700
#
# A length is a `Len`: so many px, a share of something that's known later
# (the width of the box that the element is in), or `auto`.
# A colour is a UInt32 like 0xAARRGGBB.

@use "./dom" Element Text Document attr walk
@use "./css" Declaration Rule sheet declarations matches media pieces

# --- lengths and colours ------------------------------------------------------------------

struct Len
  px::Float64
  pct::Float64    # a share of what the length is a percent of: 0.5 for 50%
  em::Float64     # so many of the element's font size. It's px by the time the style is made.
  auto::Bool
end

Len(px::Real) = Len(px, 0, 0, false)
const AUTO = Len(0, 0, 0, true)
const ZERO = Len(0)
percent(share) = Len(0, share, 0, false)

"`l` in px, where a percent is of `base`"
px(l::Len, base=0.0) = l.px + l.pct * (isfinite(base) ? base : 0.0)
isauto(l::Len) = l.auto
ispercent(l::Len) = l.pct != 0
Base.:+(a::Len, b::Len) = Len(a.px + b.px, a.pct + b.pct, a.em + b.em, false)
Base.:-(a::Len, b::Len) = Len(a.px - b.px, a.pct - b.pct, a.em - b.em, false)
Base.:*(a::Len, k::Real) = Len(a.px * k, a.pct * k, a.em * k, false)

"What's known of the page while a style is worked out"
struct Context
  wide::Float64     # how wide the page is, in px
  root::Float64     # the font size of the <html> element
  quirks::Bool      # a number with no unit is px
end

const UNITS = Dict("px" => 1.0, "pt" => 4 / 3, "pc" => 16.0, "in" => 96.0, "cm" => 96 / 2.54, "mm" => 96 / 25.4, "q" => 96 / 101.6)
const NUMBER = r"^([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)([a-z%]*)$"

"The length that `v` writes, or nothing. With `bare`, a number with no unit is px."
len(v::AbstractString, c::Context; bare=c.quirks, percent=true) = begin
  v = lowercase(strip(v))
  v == "auto" && return AUTO
  startswith(v, "calc(") && endswith(v, ")") && return calc(SubString(v, 6, lastindex(v) - 1), c)
  m = match(NUMBER, v)
  m === nothing && return nothing
  x = tryparse(Float64, m[1])
  x === nothing && return nothing
  unit = m[2]
  unit == "" ? (x == 0 || bare ? Len(x) : nothing) :
  unit == "%" ? (percent ? Len(0, x / 100, 0, false) : nothing) :
  unit == "em" ? Len(0, 0, x, false) : unit in ("ex", "ch") ? Len(0, 0, x / 2, false) :
  unit == "rem" ? Len(x * c.root) : unit == "vw" ? Len(x * c.wide / 100) : unit == "vh" ? Len(x * 8) :
  haskey(UNITS, unit) ? Len(x * UNITS[unit]) : nothing
end

"True for a length that's less than nothing whatever it's a share of. A sum like `100% - 20px` isn't."
negative(l::Len) = max(l.px, l.pct, l.em) <= 0 && min(l.px, l.pct, l.em) < 0

"A length that isn't `auto` and isn't less than nothing"
size_len(v, c; kw...) = (l = len(v, c; kw...); l === nothing || l.auto || negative(l) ? nothing : l)
"A length that can be `auto`, and isn't less than nothing"
box_len(v, c; kw...) = (l = len(v, c; kw...); l === nothing || negative(l) ? nothing : l)

"What a sum in `calc()` comes to: lengths added and taken away, and made so many times bigger or smaller"
calc(s::AbstractString, c::Context) = begin
  tokens = [m.match for m in eachmatch(r"\(|\)|[*/]|[+-](?=\s)|[+-]?[0-9.]+[a-z%]*", s)]
  i = Ref(1)
  peek() = i[] <= length(tokens) ? tokens[i[]] : ""
  take() = (t = peek(); i[] += 1; t)
  value() = begin
    t = take()
    if t == "("
      v = sum()
      take()
      return v
    end
    l = len(t, c; bare=false)
    l !== nothing ? l : (x = tryparse(Float64, t)) === nothing ? nothing : x
  end
  product() = begin
    a = value()
    while peek() in ("*", "/")
      op = take()
      b = value()
      (a === nothing || b === nothing) && return nothing
      a = op == "*" ? (a isa Len && b isa Real ? a * b : a isa Real && b isa Len ? b * a : a isa Real && b isa Real ? a * b : nothing) :
          b isa Real && b != 0 ? (a isa Len ? a * (1 / b) : a / b) : nothing
    end
    a
  end
  sum() = begin
    a = product()
    while peek() in ("+", "-")
      op = take()
      b = product()
      (a isa Len && b isa Len) || return nothing
      a = op == "+" ? a + b : a - b
    end
    a
  end
  v = sum()
  v isa Len ? v : nothing
end

const COLOURS = Dict{String,UInt32}(
  "black" => 0xff000000, "silver" => 0xffc0c0c0, "gray" => 0xff808080, "grey" => 0xff808080, "white" => 0xffffffff, "maroon" => 0xff800000,
  "red" => 0xffff0000, "purple" => 0xff800080, "fuchsia" => 0xffff00ff, "magenta" => 0xffff00ff, "green" => 0xff008000, "lime" => 0xff00ff00,
  "olive" => 0xff808000, "yellow" => 0xffffff00, "navy" => 0xff000080, "blue" => 0xff0000ff, "teal" => 0xff008080, "aqua" => 0xff00ffff,
  "cyan" => 0xff00ffff, "orange" => 0xffffa500, "aliceblue" => 0xfff0f8ff, "antiquewhite" => 0xfffaebd7, "aquamarine" => 0xff7fffd4,
  "azure" => 0xfff0ffff, "beige" => 0xfff5f5dc, "bisque" => 0xffffe4c4, "blanchedalmond" => 0xffffebcd, "blueviolet" => 0xff8a2be2,
  "brown" => 0xffa52a2a, "burlywood" => 0xffdeb887, "cadetblue" => 0xff5f9ea0, "chartreuse" => 0xff7fff00, "chocolate" => 0xffd2691e,
  "coral" => 0xffff7f50, "cornflowerblue" => 0xff6495ed, "cornsilk" => 0xfffff8dc, "crimson" => 0xffdc143c, "darkblue" => 0xff00008b,
  "darkcyan" => 0xff008b8b, "darkgoldenrod" => 0xffb8860b, "darkgray" => 0xffa9a9a9, "darkgrey" => 0xffa9a9a9, "darkgreen" => 0xff006400,
  "darkkhaki" => 0xffbdb76b, "darkmagenta" => 0xff8b008b, "darkolivegreen" => 0xff556b2f, "darkorange" => 0xffff8c00, "darkorchid" => 0xff9932cc,
  "darkred" => 0xff8b0000, "darksalmon" => 0xffe9967a, "darkseagreen" => 0xff8fbc8f, "darkslateblue" => 0xff483d8b, "darkslategray" => 0xff2f4f4f,
  "darkslategrey" => 0xff2f4f4f, "darkturquoise" => 0xff00ced1, "darkviolet" => 0xff9400d3, "deeppink" => 0xffff1493, "deepskyblue" => 0xff00bfff,
  "dimgray" => 0xff696969, "dimgrey" => 0xff696969, "dodgerblue" => 0xff1e90ff, "firebrick" => 0xffb22222, "floralwhite" => 0xfffffaf0,
  "forestgreen" => 0xff228b22, "gainsboro" => 0xffdcdcdc, "ghostwhite" => 0xfff8f8ff, "gold" => 0xffffd700, "goldenrod" => 0xffdaa520,
  "greenyellow" => 0xffadff2f, "honeydew" => 0xfff0fff0, "hotpink" => 0xffff69b4, "indianred" => 0xffcd5c5c, "indigo" => 0xff4b0082,
  "ivory" => 0xfffffff0, "khaki" => 0xfff0e68c, "lavender" => 0xffe6e6fa, "lavenderblush" => 0xfffff0f5, "lawngreen" => 0xff7cfc00,
  "lemonchiffon" => 0xfffffacd, "lightblue" => 0xffadd8e6, "lightcoral" => 0xfff08080, "lightcyan" => 0xffe0ffff,
  "lightgoldenrodyellow" => 0xfffafad2, "lightgray" => 0xffd3d3d3, "lightgrey" => 0xffd3d3d3, "lightgreen" => 0xff90ee90, "lightpink" => 0xffffb6c1,
  "lightsalmon" => 0xffffa07a, "lightseagreen" => 0xff20b2aa, "lightskyblue" => 0xff87cefa, "lightslategray" => 0xff778899,
  "lightslategrey" => 0xff778899, "lightsteelblue" => 0xffb0c4de, "lightyellow" => 0xffffffe0, "limegreen" => 0xff32cd32, "linen" => 0xfffaf0e6,
  "mediumaquamarine" => 0xff66cdaa, "mediumblue" => 0xff0000cd, "mediumorchid" => 0xffba55d3, "mediumpurple" => 0xff9370db,
  "mediumseagreen" => 0xff3cb371, "mediumslateblue" => 0xff7b68ee, "mediumspringgreen" => 0xff00fa9a, "mediumturquoise" => 0xff48d1cc,
  "mediumvioletred" => 0xffc71585, "midnightblue" => 0xff191970, "mintcream" => 0xfff5fffa, "mistyrose" => 0xffffe4e1, "moccasin" => 0xffffe4b5,
  "navajowhite" => 0xffffdead, "oldlace" => 0xfffdf5e6, "olivedrab" => 0xff6b8e23, "orangered" => 0xffff4500, "orchid" => 0xffda70d6,
  "palegoldenrod" => 0xffeee8aa, "palegreen" => 0xff98fb98, "paleturquoise" => 0xffafeeee, "palevioletred" => 0xffdb7093, "papayawhip" => 0xffffefd5,
  "peachpuff" => 0xffffdab9, "peru" => 0xffcd853f, "pink" => 0xffffc0cb, "plum" => 0xffdda0dd, "powderblue" => 0xffb0e0e6, "rebeccapurple" => 0xff663399,
  "rosybrown" => 0xffbc8f8f, "royalblue" => 0xff4169e1, "saddlebrown" => 0xff8b4513, "salmon" => 0xfffa8072, "sandybrown" => 0xfff4a460,
  "seagreen" => 0xff2e8b57, "seashell" => 0xfffff5ee, "sienna" => 0xffa0522d, "skyblue" => 0xff87ceeb, "slateblue" => 0xff6a5acd,
  "slategray" => 0xff708090, "slategrey" => 0xff708090, "snow" => 0xfffffafa, "springgreen" => 0xff00ff7f, "steelblue" => 0xff4682b4,
  "tan" => 0xffd2b48c, "thistle" => 0xffd8bfd8, "tomato" => 0xffff6347, "turquoise" => 0xff40e0d0, "violet" => 0xffee82ee, "wheat" => 0xfff5deb3,
  "whitesmoke" => 0xfff5f5f5, "yellowgreen" => 0xff9acd32, "transparent" => 0x00000000,
  "-webkit-link" => 0xff0000ee, "windowtext" => 0xff000000, "window" => 0xffffffff, "buttonface" => 0xffefefef, "buttontext" => 0xff000000)

argb(r, g, b, a=1.0) = UInt32(round(clamp(a, 0, 1) * 255)) << 24 | UInt32(round(clamp(r, 0, 255))) << 16 | UInt32(round(clamp(g, 0, 255))) << 8 | UInt32(round(clamp(b, 0, 255)))
alpha(c::UInt32) = (c >> 24) / 255

"The colour of six or eight hex digits, or of three or four"
hex(h) = begin
  all(c -> isdigit(c) || 'a' <= c <= 'f', h) || return nothing
  n = length(h)
  n in (3, 4) && (h = join(c^2 for c in h))
  n in (3, 4, 6, 8) || return nothing
  x = Base.parse(UInt32, h[1:6], base=16)
  a = length(h) == 8 ? Base.parse(UInt32, h[7:8], base=16) : 0x000000ff
  a << 24 | x
end

hue(p, q, t) = (t = mod(t, 1); t < 1 / 6 ? p + (q - p) * 6t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p)

"""
The colour that `v` writes, or nothing: a name, #rgb, #rrggbb, rgb(), rgba(),
hsl() or hsla(). `currentcolor` is the symbol `:current`. With `loose`, as in
a tag's `bgcolor`, the hex digits need no # before them.
"""
colour(v::AbstractString; loose=false) = begin
  v = lowercase(strip(v))
  haskey(COLOURS, v) && return COLOURS[v]
  v == "currentcolor" && return :current
  startswith(v, '#') && return hex(SubString(v, 2))
  m = match(r"^(rgba?|hsla?)\(\s*([^)]*)\)$", v)
  if m !== nothing
    parts = split(replace(m[2], r"[,/]" => " "))
    length(parts) in (3, 4) || return nothing
    number(p, full) = endswith(p, '%') ? (x = tryparse(Float64, chop(p))) === nothing ? nothing : x / 100 * full : tryparse(Float64, replace(p, r"deg$" => ""))
    a = length(parts) == 4 ? number(parts[4], 1.0) : 1.0
    a === nothing && return nothing
    if startswith(m[1], "rgb")
      rgb = number.(parts[1:3], 255.0)
      any(isnothing, rgb) && return nothing
      return argb(rgb..., a)
    end
    h, s, l = number(parts[1], 360.0), number(parts[2], 1.0), number(parts[3], 1.0)
    (h === nothing || s === nothing || l === nothing) && return nothing
    q = l < 0.5 ? l * (1 + s) : l + s - l * s
    p = 2l - q
    return argb(255hue(p, q, h / 360 + 1 / 3), 255hue(p, q, h / 360), 255hue(p, q, h / 360 - 1 / 3), a)
  end
  loose && length(v) in (3, 6) ? hex(v) : nothing
end

# --- a style ------------------------------------------------------------------------------

const Sides{T} = NTuple{4,T}   # the top, the right, the bottom and the left
sides(x) = (x, x, x, x)

"How an element looks. What a child gets from its parent is under the line."
Base.@kwdef mutable struct Style
  display::Symbol = :inline
  position::Symbol = :static
  float::Symbol = :none
  clear::Symbol = :none
  opacity::Float64 = 1.0
  overflow::Symbol = :visible
  borderbox::Bool = false                       # the width and the height are of the border, not of the content
  width::Len = AUTO
  height::Len = AUTO
  minwidth::Len = ZERO
  minheight::Len = ZERO
  maxwidth::Len = AUTO                          # `auto` for none
  maxheight::Len = AUTO
  margin::Sides{Len} = sides(ZERO)
  padding::Sides{Len} = sides(ZERO)
  border::Sides{Len} = sides(Len(3))            # how thick each line is. It's nothing while its style is :none.
  borderstyle::Sides{Symbol} = sides(:none)
  bordercolor::Sides{Any} = sides(:current)
  radius::Sides{Len} = sides(ZERO)              # of the top left corner, the top right, the bottom right and the bottom left
  inset::Sides{Len} = sides(AUTO)               # top, right, bottom and left, for an element with a position
  background::UInt32 = 0x00000000
  image::String = ""                            # the background's picture: `url(...)` or a gradient, as it's written
  repeat::Symbol = :repeat                      # :repeat, :no_repeat, :repeat_x or :repeat_y
  bgposition::Tuple{Len,Len} = (ZERO, ZERO)
  bgsize::Any = :auto                           # :auto, :cover, :contain, or the width and the height
  valign::Tuple{Symbol,Len} = (:baseline, ZERO)
  decoration::UInt8 = 0x00                      # the lines that this element asks for: 1 under, 2 through, 4 over
  tablelayout::Symbol = :auto
  shadow::String = ""
  loose::Tuple{Bool,Bool} = (false, false)      # its top and its bottom margin are the ones that a browser gives its tag, which a page with no doctype drops at the edge of a cell
  # ---------------------------------------------------------------------------------------
  visible::Bool = true
  color::UInt32 = 0xff000000
  family::Vector{String} = String[]
  size::Float64 = 16.0
  weight::Int = 400
  italic::Bool = false
  lineheight::Tuple{Symbol,Float64} = (:normal, 0.0)   # :normal, :number (so many font sizes) or :px
  align::Symbol = :start                        # :start, :left, :right, :center, :justify, and :wk_left, :wk_center, :wk_right, which move blocks too
  transform::Symbol = :none
  letterspacing::Len = ZERO
  wordspacing::Len = ZERO
  whitespace::Symbol = :normal                  # :normal, :nowrap, :pre, :pre_wrap or :pre_line
  indent::Len = ZERO
  wrap::Symbol = :normal                        # :normal, :break_word (a long word breaks to fit), :anywhere (and its box can be that narrow) or :all (any word breaks)
  collapse::Bool = false                        # the borders of a table's cells are one line
  cellspacing::Tuple{Float64,Float64} = (0.0, 0.0)
  listtype::Symbol = :disc
  listinside::Bool = false
  captionbottom::Bool = false
  lines::UInt8 = 0x00                           # the lines that its text is drawn with, from this element and the ones round it
  linecolor::UInt32 = 0xff000000
end

const INHERITED = (:visible, :color, :family, :size, :weight, :italic, :lineheight, :align, :transform, :letterspacing, :wordspacing, :whitespace,
                   :indent, :wrap, :collapse, :cellspacing, :listtype, :listinside, :captionbottom, :lines, :linecolor)
const DEFAULT = Style()

"The style that a child of an element with the style `parent` starts with"
child(parent::Style) = begin
  s = Style()
  for f in INHERITED
    setfield!(s, f, getfield(parent, f))
  end
  s
end

"How thick the border of side `i` is, in px"
border(s::Style, i) = s.borderstyle[i] in (:none, :hidden) ? 0.0 : s.border[i].px

"How tall a line of text is, for a font whose own line is `normal` px tall"
lineheight(s::Style, normal) = s.lineheight[1] == :normal ? Float64(normal) : s.lineheight[1] == :number ? s.lineheight[2] * s.size : s.lineheight[2]

# --- what each property takes -------------------------------------------------------------

struct Prop
  field::Symbol
  side::Int          # which of the four sides, or 0 for the whole field
  read::Function     # (value in lower case, value, Context, parent's Style) → what the field takes, or nothing
end

const PROPS = Dict{String,Prop}()
prop!(read, name, field, side=0) = PROPS[name] = Prop(field, side, read)
"A property that takes one of `words`. Each is the symbol of its name, or what it's paired with."
words!(name, field, words...) = begin
  table = Dict{String,Any}(w isa Pair ? w : w => Symbol(replace(w, '-' => '_')) for w in words)
  prop!((v, _, _, _) -> get(table, v, nothing), name, field)
end

const SIDE_NAMES = ("top", "right", "bottom", "left")
const DISPLAYS = Dict("inline" => :inline, "block" => :block, "inline-block" => :inline_block, "none" => :none, "list-item" => :list_item,
  "table" => :table, "inline-table" => :inline_table, "table-row" => :table_row, "table-cell" => :table_cell, "table-row-group" => :table_row_group,
  "table-header-group" => :table_header_group, "table-footer-group" => :table_footer_group, "table-column" => :table_column,
  "table-column-group" => :table_column_group, "table-caption" => :table_caption, "flex" => :flex, "inline-flex" => :inline_flex,
  "grid" => :block, "inline-grid" => :inline_block, "flow-root" => :flow_root, "contents" => :contents, "-webkit-box" => :flex, "-webkit-inline-box" => :inline_flex)
prop!((v, _, _, _) -> get(DISPLAYS, v, nothing), "display", :display)
words!("position", :position, "static", "relative", "absolute", "fixed", "sticky" => :relative)
words!("float", :float, "none", "left", "right")
words!("clear", :clear, "none", "left", "right", "both")
words!("overflow", :overflow, "visible", "hidden", "clip" => :hidden, "scroll" => :hidden, "auto" => :hidden)
words!("box-sizing", :borderbox, "border-box" => true, "content-box" => false)
words!("visibility", :visible, "visible" => true, "hidden" => false, "collapse" => false)
words!("background-repeat", :repeat, "repeat", "no-repeat", "repeat-x", "repeat-y")
words!("table-layout", :tablelayout, "auto", "fixed")
words!("font-style", :italic, "normal" => false, "italic" => true, "oblique" => true)
words!("text-align", :align, "start", "left", "right", "center", "justify", "end" => :right, "-webkit-left" => :wk_left, "-webkit-right" => :wk_right,
       "-webkit-center" => :wk_center, "-moz-center" => :wk_center, "-moz-left" => :wk_left, "-moz-right" => :wk_right, "match-parent" => :start)
words!("text-transform", :transform, "none", "uppercase", "lowercase", "capitalize")
words!("white-space", :whitespace, "normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces" => :pre_wrap)
words!("border-collapse", :collapse, "collapse" => true, "separate" => false)
words!("list-style-position", :listinside, "inside" => true, "outside" => false)
words!("caption-side", :captionbottom, "bottom" => true, "top" => false)
words!("list-style-type", :listtype, "disc", "circle", "square", "decimal", "none", "lower-alpha", "upper-alpha", "lower-roman", "upper-roman",
       "lower-latin" => :lower_alpha, "upper-latin" => :upper_alpha, "decimal-leading-zero" => :decimal)
words!("overflow-wrap", :wrap, "normal", "break-word", "anywhere")
words!("word-wrap", :wrap, "normal", "break-word", "anywhere")
words!("word-break", :wrap, "normal", "break-all" => :all, "break-word" => :anywhere, "keep-all" => :normal)

prop!((v, _, _, _) -> (x = tryparse(Float64, endswith(v, '%') ? chop(v) : v)) === nothing ? nothing : clamp(endswith(v, '%') ? x / 100 : x, 0, 1), "opacity", :opacity)
prop!((v, _, c, _) -> box_len(v, c), "width", :width)
prop!((v, _, c, _) -> box_len(v, c), "height", :height)
prop!((v, _, c, _) -> v == "auto" ? ZERO : size_len(v, c), "min-width", :minwidth)
prop!((v, _, c, _) -> v == "auto" ? ZERO : size_len(v, c), "min-height", :minheight)
prop!((v, _, c, _) -> v == "none" ? AUTO : size_len(v, c), "max-width", :maxwidth)
prop!((v, _, c, _) -> v == "none" ? AUTO : size_len(v, c), "max-height", :maxheight)
const THICK = Dict("thin" => Len(1), "medium" => Len(3), "thick" => Len(5))
const LINES = Dict(w => Symbol(w) for w in ("none", "hidden", "solid", "dashed", "dotted", "double", "groove", "ridge", "inset", "outset"))
for (i, side) in enumerate(SIDE_NAMES)
  prop!((v, _, c, _) -> len(v, c), "margin-$side", :margin, i)
  prop!((v, _, c, _) -> size_len(v, c), "padding-$side", :padding, i)
  prop!((v, _, c, _) -> haskey(THICK, v) ? THICK[v] : size_len(v, c; percent=false), "border-$side-width", :border, i)
  prop!((v, _, _, _) -> get(LINES, v, nothing), "border-$side-style", :borderstyle, i)
  prop!((v, _, _, _) -> colour(v), "border-$side-color", :bordercolor, i)
  prop!((v, _, c, _) -> len(v, c), side, :inset, i)
end
for (i, corner) in enumerate(("top-left", "top-right", "bottom-right", "bottom-left"))
  prop!((v, _, c, _) -> size_len(first(split(v)), c), "border-$corner-radius", :radius, i)
end
prop!((v, _, _, s) -> (x = colour(v)) === :current ? s.color : x, "color", :color)
prop!((v, _, _, _) -> (x = colour(v)) isa UInt32 ? x : nothing, "background-color", :background)
prop!((v, raw, _, _) -> v == "none" ? "" : startswith(v, "url(") || occursin("gradient(", v) ? String(raw) : nothing, "background-image", :image)
prop!("background-position", :bgposition) do v, _, c, _
  place(w, across) = w == "center" ? percent(0.5) : w in ("left", "top") ? ZERO : w in ("right", "bottom") ? percent(1) : len(w, c)
  ws = split(v)
  length(ws) == 1 && (ws = ws[1] in ("top", "bottom") ? ["center", ws[1]] : [ws[1], "center"])
  length(ws) == 2 || return nothing
  ws[1] in ("top", "bottom") || ws[2] in ("left", "right") ? reverse!(ws) : ws
  x, y = place(ws[1], true), place(ws[2], false)
  x === nothing || y === nothing || x.auto || y.auto ? nothing : (x, y)
end
prop!("background-size", :bgsize) do v, _, c, _
  v in ("cover", "contain", "auto") && return Symbol(v)
  ws = split(v)
  length(ws) in (1, 2) || return nothing
  w = len(ws[1], c)
  h = length(ws) == 2 ? len(ws[2], c) : AUTO
  w === nothing || h === nothing ? nothing : (w, h)
end
prop!("vertical-align", :valign) do v, _, c, _
  v in ("baseline", "top", "middle", "bottom", "sub", "super", "text-top", "text-bottom") && return (Symbol(replace(v, '-' => '_')), ZERO)
  l = len(v, c)
  l === nothing || l.auto ? nothing : (:length, l)
end
prop!("text-decoration-line", :decoration) do v, _, _, _
  v == "none" && return 0x00
  bits = 0x00
  for w in split(v)
    bits |= w == "underline" ? 0x01 : w == "line-through" ? 0x02 : w == "overline" ? 0x04 : w == "blink" ? 0x00 : return nothing
  end
  bits
end
prop!((v, raw, _, _) -> v == "none" ? "" : String(raw), "box-shadow", :shadow)

const GENERIC = ("serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "ui-sans-serif", "ui-serif", "ui-monospace", "ui-rounded")
prop!("font-family", :family) do v, raw, _, _
  names = [String(strip(strip(n), ['"', '\''])) for n in pieces(raw, ',')]
  names = filter(!isempty, map(n -> lowercase(n) in GENERIC ? lowercase(n) : n, names))
  isempty(names) ? nothing : names
end
const SIZES = Dict("xx-small" => 9.0, "x-small" => 10.0, "small" => 13.0, "medium" => 16.0, "large" => 18.0, "x-large" => 24.0, "xx-large" => 32.0,
                   "xxx-large" => 48.0, "-webkit-xxx-large" => 48.0)
prop!("font-size", :size) do v, _, c, parent
  haskey(SIZES, v) && return SIZES[v]
  v == "smaller" && return parent.size / 1.2
  v == "larger" && return parent.size * 1.2
  l = size_len(v, c)
  l === nothing ? nothing : l.px + (l.pct + l.em) * parent.size
end
prop!("font-weight", :weight) do v, _, _, parent
  v == "normal" ? 400 : v == "bold" ? 700 : v == "bolder" ? (parent.weight < 400 ? 400 : parent.weight < 600 ? 700 : 900) :
  v == "lighter" ? (parent.weight < 600 ? 100 : parent.weight < 800 ? 400 : 700) :
  (x = tryparse(Float64, v)) !== nothing && 1 <= x <= 1000 ? round(Int, x) : nothing
end
prop!("line-height", :lineheight) do v, _, c, _
  v == "normal" && return (:normal, 0.0)
  (x = tryparse(Float64, v)) !== nothing && return x >= 0 ? (:number, x) : nothing
  l = size_len(v, c)
  # A percent or an em is of this element's font size, which isn't known yet
  l === nothing ? nothing : l.pct != 0 || l.em != 0 ? (:em, l.pct + l.em) : (:px, l.px)
end
spacing(v, c) = v == "normal" ? ZERO : (l = len(v, c; percent=false)) === nothing || l.auto ? nothing : l
prop!((v, _, c, _) -> spacing(v, c), "letter-spacing", :letterspacing)
prop!((v, _, c, _) -> spacing(v, c), "word-spacing", :wordspacing)
prop!((v, _, c, _) -> (l = len(v, c)) === nothing || l.auto ? nothing : l, "text-indent", :indent)
prop!("border-spacing", :cellspacing) do v, _, c, _
  ls = [size_len(w, c; percent=false) for w in split(v)]
  (isempty(ls) || length(ls) > 2 || any(isnothing, ls)) && return nothing
  (ls[1].px, ls[end].px)
end

# --- properties that stand for several ----------------------------------------------------

"`v` cut at its spaces, with what's in brackets or quotes kept whole"
terms(v) = filter(!isempty, strip.(pieces(replace(v, r"\s+" => " "), ' ')))

"One to four values as the four sides: `1px 2px` is the top and bottom, then the right and left"
four(ws) = length(ws) == 1 ? (ws[1], ws[1], ws[1], ws[1]) : length(ws) == 2 ? (ws[1], ws[2], ws[1], ws[2]) :
           length(ws) == 3 ? (ws[1], ws[2], ws[3], ws[2]) : length(ws) == 4 ? (ws[1], ws[2], ws[3], ws[4]) : nothing

"The width, the style and the colour that a `border` value writes, each as it's written, or nothing"
border_parts(v) = begin
  width = style = color = nothing
  for w in terms(v)
    lw = lowercase(w)
    if haskey(LINES, lw)
      style === nothing || return nothing
      style = lw
    elseif haskey(THICK, lw) || occursin(r"^[0-9.]", lw)
      width === nothing || return nothing
      width = lw
    elseif colour(lw) !== nothing
      color === nothing || return nothing
      color = lw
    else
      return nothing
    end
  end
  (something(width, "medium"), something(style, "none"), something(color, "currentcolor"))
end

"The longer names that the property `name` stands for, each with its value, or nothing when it stands for itself"
expand(name, value) = begin
  out = Pair{String,String}[]
  if name in ("margin", "padding")
    vs = four(terms(value))
    vs === nothing && return out
    for (side, v) in zip(SIDE_NAMES, vs)
      push!(out, "$name-$side" => v)
    end
  elseif name in ("border-width", "border-style", "border-color")
    vs = four(terms(value))
    vs === nothing && return out
    kind = name[8:end]
    for (side, v) in zip(SIDE_NAMES, vs)
      push!(out, "border-$side-$kind" => v)
    end
  elseif name == "border" || name in ("border-top", "border-right", "border-bottom", "border-left")
    parts = border_parts(value)
    parts === nothing && return out
    for side in (name == "border" ? SIDE_NAMES : (name[8:end],)), (kind, v) in zip(("width", "style", "color"), parts)
      push!(out, "border-$side-$kind" => v)
    end
  elseif name in ("border-radius", "-webkit-border-radius", "-moz-border-radius")
    vs = four(terms(first(split(value, '/'))))
    vs === nothing && return out
    for (corner, v) in zip(("top-left", "top-right", "bottom-right", "bottom-left"), vs)
      push!(out, "border-$corner-radius" => v)
    end
  elseif name == "background"
    color, image, repeat, place, size = "transparent", "none", "repeat", String[], nothing
    ws = terms(replace(value, r"\s*/\s*" => " / "))
    i = 1
    while i <= length(ws)
      w = ws[i]
      lw = lowercase(w)
      if lw == "/"
        j = i + 1
        while j <= length(ws) && j <= i + 2 && (lowercase(ws[j]) in ("cover", "contain", "auto") || occursin(r"^[0-9.]", ws[j])) j += 1 end
        size = join(ws[i+1:j-1], " ")
        i = j - 1
      elseif startswith(lw, "url(") || occursin("gradient(", lw)
        image = w
      elseif lw in ("repeat", "no-repeat", "repeat-x", "repeat-y")
        repeat = lw
      elseif lw in ("left", "right", "top", "bottom", "center") || occursin(r"^-?[0-9.]", lw)
        push!(place, lw)
      elseif lw in ("scroll", "fixed", "local", "border-box", "padding-box", "content-box", "none")
      elseif colour(lw) isa UInt32
        color = lw
      else
        return out
      end
      i += 1
    end
    push!(out, "background-color" => color, "background-image" => image, "background-repeat" => repeat,
          "background-position" => (isempty(place) ? "0% 0%" : join(place, " ")), "background-size" => something(size, "auto"))
  elseif name == "font"
    ws = terms(value)
    i = 1
    style, weight = "normal", "normal"
    while i <= length(ws) && !occursin(r"^[0-9.]", ws[i]) && !haskey(SIZES, lowercase(ws[i])) && !(lowercase(ws[i]) in ("smaller", "larger"))
      w = lowercase(ws[i])
      w in ("italic", "oblique") ? (style = w) : w in ("bold", "bolder", "lighter") ? (weight = w) : nothing
      i += 1
    end
    # A weight like 600 looks like a size: it's a weight when a size comes after it
    if i < length(ws) && occursin(r"^[1-9]00$", ws[i]) && (occursin(r"^[0-9.]", ws[i+1]) || haskey(SIZES, lowercase(ws[i+1])))
      weight = ws[i]
      i += 1
    end
    i < length(ws) || return out   # a size and a family are both needed
    size = split(ws[i], '/')
    push!(out, "font-style" => style, "font-weight" => weight, "font-size" => size[1], "line-height" => (length(size) > 1 ? size[2] : "normal"),
          "font-family" => join(ws[i+1:end], " "))
  elseif name == "list-style"
    for w in terms(value)
      lw = lowercase(w)
      lw in ("inside", "outside") ? push!(out, "list-style-position" => lw) : startswith(lw, "url(") ? nothing : push!(out, "list-style-type" => lw)
    end
  elseif name == "text-decoration"
    lines = filter(w -> lowercase(w) in ("none", "underline", "line-through", "overline"), terms(value))
    isempty(lines) || push!(out, "text-decoration-line" => join(lines, " "))
  elseif name in ("overflow-x", "overflow-y")
    push!(out, "overflow" => value)
  elseif name == "overflow" && occursin(' ', strip(value))
    push!(out, "overflow" => first(split(value)))
  elseif name in ("padding-inline-start", "margin-inline-start")
    push!(out, "$(name[1:end-13])-left" => value)
  elseif name in ("padding-inline-end", "margin-inline-end")
    push!(out, "$(name[1:end-11])-right" => value)
  elseif name in ("margin-block-start", "padding-block-start")
    push!(out, "$(name[1:end-12])-top" => value)
  elseif name in ("margin-block-end", "padding-block-end")
    push!(out, "$(name[1:end-10])-bottom" => value)
  elseif name in ("margin-inline", "padding-inline", "margin-block", "padding-block")
    ws = terms(value)
    length(ws) in (1, 2) || return out
    a, b = endswith(name, "inline") ? ("left", "right") : ("top", "bottom")
    push!(out, "$(first(split(name, '-')))-$a" => ws[1], "$(first(split(name, '-')))-$b" => ws[end])
  elseif name in ("-webkit-box-sizing", "-moz-box-sizing")
    push!(out, "box-sizing" => value)
  elseif name in ("-webkit-box-shadow", "-moz-box-shadow")
    push!(out, "box-shadow" => value)
  else
    return nothing
  end
  out
end

get_side(s::Style, p::Prop) = p.side == 0 ? getfield(s, p.field) : getfield(s, p.field)[p.side]
set_side!(s::Style, p::Prop, v) = begin
  T = fieldtype(Style, p.field)
  p.side == 0 ? setfield!(s, p.field, convert(T, v)) : setfield!(s, p.field, convert(T, Base.setindex(getfield(s, p.field), v, p.side)))
end

"Give the style `s` what `name: value` declares. A value that the property can't take changes nothing."
set!(s::Style, name::AbstractString, value::AbstractString, c::Context, parent::Style) = begin
  p = get(PROPS, name, nothing)
  if p === nothing
    longer = expand(name, value)
    longer === nothing && return
    for (n, v) in longer
      set!(s, n, v, c, parent)
    end
    return
  end
  v = lowercase(strip(value))
  got = v == "inherit" ? get_side(parent, p) : v in ("initial", "unset", "revert") ? get_side(p.field in INHERITED && v != "initial" ? parent : DEFAULT, p) :
        p.read(v, value, c, parent)
  got === nothing || set_side!(s, p, got)
  nothing
end

"Turn the ems of the lengths of `s` into px, now that its font size is known, and work out what follows from its other values"
settle!(s::Style, parent::Style, tag="") = begin
  # A table takes no centring from a tag's `align` round it: what's in it starts at the left again
  tag == "table" && s.align in (:wk_left, :wk_center, :wk_right) && (s.align = :start)
  flat(l::Len) = l.em == 0 ? l : Len(l.px + l.em * s.size, l.pct, 0, l.auto)
  for f in (:width, :height, :minwidth, :minheight, :maxwidth, :maxheight, :indent, :letterspacing, :wordspacing)
    setfield!(s, f, flat(getfield(s, f)))
  end
  for f in (:margin, :padding, :border, :radius, :inset)
    setfield!(s, f, map(flat, getfield(s, f)))
  end
  s.bgposition = map(flat, s.bgposition)
  s.bgsize isa Tuple && (s.bgsize = map(flat, s.bgsize))
  s.valign = (s.valign[1], flat(s.valign[2]))
  s.lineheight[1] == :em && (s.lineheight = (:px, s.lineheight[2] * s.size))
  s.bordercolor = map(c -> c === :current ? s.color : c, s.bordercolor)
  # A float and an element with a place of its own are blocks
  if s.display != :none && (s.float != :none || s.position in (:absolute, :fixed))
    s.position in (:absolute, :fixed) && (s.float = :none)
    s.display = s.display in (:inline, :inline_block, :table_cell, :table_row, :table_row_group, :table_header_group, :table_footer_group,
                              :table_caption, :table_column, :table_column_group, :contents) ? :block :
                s.display == :inline_table ? :table : s.display == :inline_flex ? :flex : s.display
  end
  # The lines under and through text go on through the text of what's in the element, but not into a box of its own
  apart = s.display in (:inline_block, :inline_table, :inline_flex) || s.float != :none || s.position in (:absolute, :fixed)
  s.lines = (apart ? 0x00 : parent.lines) | s.decoration
  s.decoration != 0 && (s.linecolor = s.color)
  s
end

# --- what a browser gives each tag --------------------------------------------------------

const BROWSER = sheet("""
html, body, div, p, h1, h2, h3, h4, h5, h6, address, blockquote, center, dl, dt, dd, ol, ul, menu, dir, pre, listing, xmp, plaintext, hr, form,
fieldset, legend, article, aside, footer, header, main, nav, section, figure, figcaption, details, summary, hgroup, optgroup, search { display: block }
head, meta, title, link, style, script, base, template, area, param, datalist, noembed, noframes, iframe, object, embed, audio, video, canvas, svg, map,
source, track, select, textarea, dialog, input[type=hidden], [hidden] { display: none }
body { margin: 8px }
p, dl { margin: 1em 0 }
blockquote, figure { margin: 1em 40px }
h1 { font-size: 2em; margin: 0.67em 0; font-weight: bold }
h2 { font-size: 1.5em; margin: 0.83em 0; font-weight: bold }
h3 { font-size: 1.17em; margin: 1em 0; font-weight: bold }
h4 { margin: 1.33em 0; font-weight: bold }
h5 { font-size: 0.83em; margin: 1.67em 0; font-weight: bold }
h6 { font-size: 0.67em; margin: 2.33em 0; font-weight: bold }
b, strong, th { font-weight: bold }
i, em, cite, var, address, dfn { font-style: italic }
u, ins { text-decoration: underline }
s, strike, del { text-decoration: line-through }
a:any-link { color: -webkit-link; text-decoration: underline }
big { font-size: larger }
small { font-size: smaller }
sub { vertical-align: sub; font-size: smaller }
sup { vertical-align: super; font-size: smaller }
pre, listing, xmp, plaintext { white-space: pre; margin: 1em 0; font-family: monospace; font-size: 13px }
code, kbd, samp, tt { font-family: monospace; font-size: 0.8125em }
pre code, pre kbd, pre samp, pre tt { font-size: 1em }
center { text-align: -webkit-center }
hr { border: 1px inset gray; margin: 0.5em auto; overflow: hidden }
ul, menu, dir { list-style-type: disc; margin: 1em 0; padding-left: 40px }
ol { list-style-type: decimal; margin: 1em 0; padding-left: 40px }
li { display: list-item }
ul ul, ol ul { list-style-type: circle }
ul ul ul, ul ol ul, ol ul ul, ol ol ul { list-style-type: square }
ul ul, ul ol, ol ul, ol ol { margin-top: 0; margin-bottom: 0 }
dd { margin-left: 40px }
table { display: table; border-collapse: separate; border-spacing: 2px; border-color: gray; box-sizing: border-box; text-indent: 0 }
thead { display: table-header-group; vertical-align: middle; border-color: inherit }
tbody { display: table-row-group; vertical-align: middle; border-color: inherit }
tfoot { display: table-footer-group; vertical-align: middle; border-color: inherit }
tr { display: table-row; vertical-align: inherit; border-color: inherit }
td, th { display: table-cell; vertical-align: inherit; padding: 1px }
th { text-align: center }
caption { display: table-caption; text-align: center }
col { display: table-column }
colgroup { display: table-column-group }
img, input, button { display: inline-block }
button { padding: 1px 6px; border: 2px outset buttonface; background-color: buttonface; color: buttontext; font-size: 13.33px; text-align: center }
input { padding: 1px 2px; border: 2px inset gray; font-size: 13.33px; width: 150px; height: 15px }
fieldset { border: 2px groove gray; margin: 0 2px; padding: 0.35em 0.75em 0.625em }
mark { background-color: yellow; color: black }
nobr { white-space: nowrap }
""")

# In a page with no doctype, a table doesn't take its text's size and weight from what it's in
const QUIRKS = sheet("table { font-size: medium; font-weight: normal; font-style: normal; white-space: normal; line-height: normal; text-align: start }")

# The tags whose margins a page with no doctype drops at the top of the page and at the edges of a cell
const LOOSE = Set(["p", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "menu", "dir", "dl", "pre", "listing", "plaintext", "xmp"])

# --- what a tag says about its looks ------------------------------------------------------

const FONT_SIZES = ("x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large")
const ALIGNS = Dict("left" => "-webkit-left", "right" => "-webkit-right", "center" => "-webkit-center", "middle" => "-webkit-center", "justify" => "justify")

"The length that a tag writes like `width=600` or `width=\"50%\"`, as CSS writes it, or nothing"
measure(v; zero=true) = begin
  m = match(r"^\s*([0-9]*\.?[0-9]+)\s*(%)?", v)
  m === nothing && return nothing
  !zero && Base.parse(Float64, m[1]) == 0 && return nothing
  m[1] * (m[2] === nothing ? "px" : "%")
end

"The table that the cell or the row `e` is in"
table_of(e::Element) = begin
  p = e.parent
  while p !== nothing && p.tag != "table"
    p = p.parent
  end
  p
end

"How thick the `border` of a table's tag says its border is, in px. A border with no number is 1 px."
border_attr(table::Element) = begin
  haskey(table.attrs, "border") || return 0.0
  m = match(r"^\s*([0-9]*\.?[0-9]+)", table.attrs["border"])
  m === nothing ? 1.0 : Base.parse(Float64, m[1])
end

"The address in a tag's `background`, as CSS writes a picture"
url(v) = "url(\"" * replace(strip(v), '"' => "%22") * "\")"

"What the tag of `e` says about how it looks, as declarations, which any CSS for the element wins over"
hints(e::Element) = begin
  out = Pair{String,String}[]
  a(name) = strip(get(e.attrs, name, ""))
  has(name) = haskey(e.attrs, name)
  say(name, v) = v === nothing || isempty(v) || push!(out, name => v)
  tag = e.tag
  if tag == "body"
    say("background-color", a("bgcolor"))
    say("color", a("text"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    for (attr, sides) in (("marginwidth", ("left", "right")), ("leftmargin", ("left",)), ("rightmargin", ("right",)),
                          ("marginheight", ("top", "bottom")), ("topmargin", ("top",)), ("bottommargin", ("bottom",)))
      has(attr) && foreach(side -> say("margin-$side", measure(a(attr))), sides)
    end
  elseif tag == "table"
    say("width", measure(a("width"); zero=false))
    say("height", measure(a("height")))
    say("background-color", a("bgcolor"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    if has("border")
      n = border_attr(e)
      say("border-width", "$(n)px")
      say("border-style", n > 0 ? "outset" : "none")
    end
    say("border-color", a("bordercolor"))
    has("cellspacing") && say("border-spacing", measure(a("cellspacing")))
    align = lowercase(a("align"))
    align in ("left", "right") && say("float", align)
    align == "center" && (say("margin-left", "auto"); say("margin-right", "auto"))
    has("hspace") && (say("margin-left", measure(a("hspace"))); say("margin-right", measure(a("hspace"))))
    has("vspace") && (say("margin-top", measure(a("vspace"))); say("margin-bottom", measure(a("vspace"))))
  elseif tag in ("td", "th")
    say("width", measure(a("width"); zero=false))
    say("height", measure(a("height"); zero=false))
    say("background-color", a("bgcolor"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
    lowercase(a("valign")) in ("top", "middle", "bottom", "baseline") && say("vertical-align", lowercase(a("valign")))
    has("nowrap") && say("white-space", "nowrap")
    table = table_of(e)
    if table !== nothing
      haskey(table.attrs, "cellpadding") && say("padding", measure(table.attrs["cellpadding"]))
      # A table with a border draws a line round each of its cells
      if border_attr(table) > 0
        say("border-width", "1px")
        say("border-style", "inset")
        say("border-color", get(table.attrs, "bordercolor", "gray"))
      end
    end
  elseif tag in ("tr", "thead", "tbody", "tfoot")
    say("background-color", a("bgcolor"))
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
    lowercase(a("valign")) in ("top", "middle", "bottom", "baseline") && say("vertical-align", lowercase(a("valign")))
    tag == "tr" && say("height", measure(a("height"); zero=false))
  elseif tag in ("col", "colgroup")
    say("width", measure(a("width"); zero=false))
  elseif tag == "img"
    say("width", measure(a("width")))
    say("height", measure(a("height")))
    if has("border") && (w = measure(a("border"))) !== nothing
      say("border-width", w)
      say("border-style", "solid")
    end
    align = lowercase(a("align"))
    align in ("left", "right") && say("float", align)
    align in ("top", "middle", "bottom", "texttop") && say("vertical-align", align == "texttop" ? "text-top" : align)
    align in ("absmiddle", "abscenter") && say("vertical-align", "middle")
    has("hspace") && (say("margin-left", measure(a("hspace"))); say("margin-right", measure(a("hspace"))))
    has("vspace") && (say("margin-top", measure(a("vspace"))); say("margin-bottom", measure(a("vspace"))))
  elseif tag == "font"
    say("color", a("color"))
    say("font-family", a("face"))
    if (m = match(r"^([+-]?)(\d+)", a("size"))) !== nothing
      n = Base.parse(Int, m[2])
      n = m[1] == "+" ? 3 + n : m[1] == "-" ? 3 - n : n
      say("font-size", FONT_SIZES[clamp(n, 1, 7)])
    end
  elseif tag in ("p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "center")
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
  elseif tag == "hr"
    say("width", measure(a("width")))
    has("size") && say("height", measure(a("size")))
    if has("color")
      say("border-color", a("color"))
      say("background-color", a("color"))
      say("border-style", "solid")
    end
    align = lowercase(a("align"))
    align == "left" && (say("margin-left", "0"); say("margin-right", "auto"))
    align == "right" && (say("margin-left", "auto"); say("margin-right", "0"))
  elseif tag in ("ul", "ol", "li")
    kind = a("type")
    say("list-style-type", get(Dict("1" => "decimal", "a" => "lower-alpha", "A" => "upper-alpha", "i" => "lower-roman", "I" => "upper-roman"), kind, lowercase(kind)))
  elseif tag == "br"
    clear = lowercase(a("clear"))
    say("clear", clear == "all" ? "both" : clear)
  end
  out
end

# --- the style of each element ------------------------------------------------------------

"The rules of a page, and which of them can be for an element, by what the last part of its selector asks"
struct Sheet
  ids::Dict{String,Vector{Rule}}
  classes::Dict{String,Vector{Rule}}
  tags::Dict{String,Vector{Rule}}
  rest::Vector{Rule}
end

Sheet(rules) = begin
  s = Sheet(Dict(), Dict(), Dict(), Rule[])
  for r in rules
    part = r.selector.parts[1]
    into = !isempty(part.id) ? get!(() -> Rule[], s.ids, part.id) : !isempty(part.classes) ? get!(() -> Rule[], s.classes, part.classes[1]) :
           !isempty(part.tag) ? get!(() -> Rule[], s.tags, part.tag) : s.rest
    push!(into, r)
  end
  s
end

"Call `f` with each rule of `s` that's for the element `e`"
each_rule(f, s::Sheet, e::Element) = begin
  try_all(rules) = foreach(r -> matches(r.selector, e) && f(r), rules)
  id = attr(e, "id")
  isempty(id) || haskey(s.ids, id) && try_all(s.ids[id])
  for k in split(attr(e, "class"))
    haskey(s.classes, k) && try_all(s.classes[k])
  end
  haskey(s.tags, e.tag) && try_all(s.tags[e.tag])
  try_all(s.rest)
end

const BROWSER_SHEET = Sheet(BROWSER)
const QUIRKS_SHEET = Sheet(QUIRKS)

"""
The style of each element of `doc`, on a page `wide` px wide. `extra` is CSS
that the page didn't write, which goes after the page's own.
"""
styles(doc::Document, wide; extra="") = begin
  rules = Rule[]
  for (text, m) in doc.sheets
    append!(rules, sheet(text; media=isempty(strip(m)) ? String[] : [m], order=length(rules)))
  end
  isempty(extra) || append!(rules, sheet(extra; order=length(rules)))
  filter!(r -> all(q -> media(q, wide), r.media), rules)
  page = Sheet(rules)
  out = IdDict{Element,Style}()
  quirks = doc.mode == :quirks
  rootsize = Ref(16.0)
  found = Tuple{Bool,Int,NTuple{3,Int},Int,String,String}[]
  visit(e::Element, parent::Style) = begin
    c = Context(wide, rootsize[], quirks)
    s = child(parent)
    empty!(found)
    add(origin, weight, order, name, value, important) = push!(found, (important, origin, weight, order, name, value))
    from(sheet, origin) = each_rule(sheet, e) do r
      for d in r.declarations
        add(origin, r.selector.weight, r.order, d.name, d.value, d.important)
      end
    end
    from(BROWSER_SHEET, 0)
    quirks && from(QUIRKS_SHEET, 0)
    for (i, (name, value)) in enumerate(hints(e))
      add(1, (0, 0, 0), i, name, value, false)
    end
    from(page, 2)
    for (i, d) in enumerate(declarations(attr(e, "style")))
      add(3, (0, 0, 0), i, d.name, d.value, d.important)
    end
    sort!(found; alg=MergeSort, by=x -> x[1:4])
    top = bottom = false
    for (_, origin, _, _, name, value) in found
      # Whether the margins that win are the browser's own
      name in ("margin", "margin-top", "margin-block", "margin-block-start") && (top = origin == 0)
      name in ("margin", "margin-bottom", "margin-block", "margin-block-end") && (bottom = origin == 0)
      # A tag's own lengths and colours are read more loosely than CSS
      if origin == 1
        value = name in ("background-color", "color", "border-color") && !(colour(value) isa UInt32) ?
                ((x = colour(value; loose=true)) isa UInt32 ? "#" * string(x & 0x00ffffff, base=16, pad=6) : continue) : value
      end
      set!(s, name, value, c, parent)
    end
    settle!(s, parent, e.tag)
    e.tag in LOOSE && (s.loose = (top, bottom))
    e.parent === nothing && (rootsize[] = s.size)
    out[e] = s
    for k in e.children
      k isa Element && visit(k, s)
    end
  end
  visit(doc.root, Style())
  out
end
