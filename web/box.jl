# Makes the boxes of a page from its elements and their styles. layout.jl
# gives each box its size and its place.
#
#     root = boxes(doc, look)     # the box of the <html> element
#     root.kind                   # :block
#     root.children               # the boxes in it
#
# A box is one of these kinds:
#
#   :block    a box that's laid out down the page, with boxes or lines of text in it
#   :inline   a part of a line of text that has a style of its own, like a link
#   :text     a run of text
#   :break    a <br>
#   :image    a picture
#   :table, :group, :row, :cell, :caption, :column    the parts of a table
#
# A box that's `atomic` goes in a line of text as one piece: an inline-block, or
# a picture.
#
# The boxes are made whole here, as CSS asks: text beside a block gets a block
# of its own, a cell that's in no row gets a row and a table, and a link that
# has a block in it is a block.

@use "./dom" Element Text Document Node attr
@use "./style" Style child
@use "./text" font width

"The top and the bottom margin of a box that can join with the margins next to them: the biggest, and the most negative"
struct Gap
  pos::Float64
  neg::Float64
end
Gap(m::Real) = m >= 0 ? Gap(m, 0.0) : Gap(0.0, m)
const NO_GAP = Gap(0.0, 0.0)
Base.join(a::Gap, b::Gap) = Gap(max(a.pos, b.pos), min(a.neg, b.neg))
Base.size(g::Gap) = g.pos + g.neg

"Something in a line of text: a word, a space, a box that's one piece, or the start or the end of an inline box"
mutable struct Piece{B}
  kind::Symbol               # :text, :atom, :open or :close
  box::B                     # the text's box, the box that's one piece, or the inline box
  chars::Vector{Char}
  widths::Vector{Float64}    # how wide each letter is
  width::Float64
  x::Float64                 # its left edge, from the left of the content of the block that the line is in
  y::Float64                 # of text: the line that its letters stand on. Of a box: its top. From the top of the block's content.
  space::Bool                # it's a space that a line can end with, and then it takes no room
  from::Int                  # of text: how many letters of its box's text come before it
end

"The part of an inline box that's in one line: where its background and its border go"
struct Span{B}
  box::B
  left::Float64
  right::Float64
  top::Float64
  bottom::Float64
  first::Bool      # the box starts in this line
  last::Bool       # and ends in it
end

mutable struct Line{B}
  y::Float64                 # its top, from the top of the block's content
  height::Float64
  baseline::Float64          # how far under its top its text stands
  pieces::Vector{Piece{B}}
  spans::Vector{Span{B}}
  hard::Bool                 # a <br> or a new line in the text ended it
end

Base.@kwdef mutable struct Box
  kind::Symbol
  style::Style
  element::Union{Element,Nothing} = nothing
  children::Vector{Box} = Box[]
  text::String = ""
  advances::Vector{Float64} = Float64[]   # of text: how wide each of its letters is
  atomic::Bool = false
  # Where it is, once it's laid out: its border, in px from the top left corner of the border of the box that it's in
  x::Float64 = 0.0
  y::Float64 = 0.0
  width::Float64 = 0.0
  height::Float64 = 0.0
  margin::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  padding::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  border::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  lines::Vector{Line{Box}} = Line{Box}[]
  over::Vector{Box} = Box[]            # the boxes with a place of their own that are placed from this box
  below::Gap = NO_GAP                  # the margin under it, joined with the margins of what ends where it ends
  baseline::Float64 = NaN              # how far under its top its last line of text stands
  extent::Tuple{Float64,Float64} = (NaN, NaN)   # how narrow it can be, and how wide it is with no line broken
  row::Int = 0                         # of a cell: its row and its column in the table, and how many of each it spans
  col::Int = 0
  rowspan::Int = 1
  colspan::Int = 1
  link::String = ""                    # where the link that it's in goes, or ""
  marker::String = ""                  # of a list item: its bullet or its number
  natural::Tuple{Float64,Float64} = (0.0, 0.0)   # of a picture: how big the picture itself is, or zeros when it isn't known
  shape::Float64 = NaN                 # of a picture that isn't there: its width over its height, as its tag's `width` and `height` say
  picture::Any = nothing               # of a picture: what the page's pictures have for it
  grid::Any = nothing                  # of a table: its rows and its columns
end

"True for a float or a box with a place of its own: it isn't part of the flow of the box that it's in"
floats(b::Box) = b.kind != :text && b.style.float != :none
placed(b::Box) = b.kind != :text && b.style.position in (:absolute, :fixed)
"True for a box that goes in a line of text"
inline(b::Box) = b.kind in (:text, :inline, :break) || b.atomic
"True for a box that starts its own flow: its floats and margins stay in it"
contained(b::Box) = b.atomic || b.kind in (:cell, :caption, :table) || floats(b) || placed(b) || b.style.overflow != :visible ||
                    b.style.display in (:flow_root, :flex, :inline_flex, :inline_block) || b.element !== nothing && b.element.parent === nothing

"A box that no element made, which looks like what's in `b`"
anonymous(kind, b::Box, children=Box[]) = begin
  s = child(b.style)
  s.display = kind == :block ? :block : :inline
  Box(kind=kind, style=s, children=children)
end

blank(b::Box) = b.kind == :text && b.style.whitespace in (:normal, :nowrap, :pre_line) && all(isspace, b.text) && !occursin(' ', b.text)

# --- the numbers and bullets of a list ----------------------------------------------------

const ROMAN = [1000 => "m", 900 => "cm", 500 => "d", 400 => "cd", 100 => "c", 90 => "xc", 50 => "l", 40 => "xl", 10 => "x", 9 => "ix", 5 => "v", 4 => "iv", 1 => "i"]
roman(n) = begin
  out = ""
  for (v, s) in ROMAN
    while n >= v
      out *= s
      n -= v
    end
  end
  out
end
letters(n) = (out = ""; while n > 0; n -= 1; out = string('a' + n % 26) * out; n ÷= 26; end; out)

"What a list item shows before its text: a bullet, or its number `n`"
marker(kind::Symbol, n) =
  kind == :disc ? "•" : kind == :circle ? "◦" : kind == :square ? "▪" : kind == :none ? "" : kind == :decimal ? "$n." :
  n < 1 ? "$n." : kind == :lower_alpha ? letters(n) * "." : kind == :upper_alpha ? uppercase(letters(n)) * "." :
  kind == :lower_roman ? roman(n) * "." : kind == :upper_roman ? uppercase(roman(n)) * "." : "$n."

"Which number the list item `e` has in its list"
number(e::Element) = begin
  list = e.parent
  list === nothing && return 1
  n = something(tryparse(Int, attr(list, "start")), 1) - 1
  for c in list.children
    c isa Element && c.tag == "li" || continue
    n = something(tryparse(Int, attr(c, "value")), n + 1)
    c === e && break
  end
  n
end

# --- the boxes ----------------------------------------------------------------------------

const KINDS = Dict(:inline => :inline, :block => :block, :list_item => :block, :flow_root => :block, :flex => :block, :inline_block => :block,
                   :inline_flex => :block, :table => :table, :inline_table => :table, :table_row_group => :group, :table_header_group => :group,
                   :table_footer_group => :group, :table_row => :row, :table_cell => :cell, :table_caption => :caption, :table_column => :column,
                   :table_column_group => :column)

capitalised(s) = replace(s, r"(?<![\p{L}\p{N}'’])\p{L}" => uppercase)
shown(text, s::Style) = s.transform == :uppercase ? uppercase(text) : s.transform == :lowercase ? lowercase(text) :
                        s.transform == :capitalize ? capitalised(text) : text

# `pictures(address)` gives the size of the picture that an <img> names, and what to draw it with, as
# `(width, height, picture)`, or nothing for a picture that there isn't
no_pictures(src) = nothing

"Add to `out` the boxes that the node makes. `link` is where the link that the node is in goes."
add!(out, n::Text, parent::Style, look, pictures, link) = isempty(n.text) || push!(out, Box(kind=:text, style=parent, text=shown(n.text, parent), link=link))
add!(out, e::Element, parent::Style, look, pictures, link) = begin
  s = look[e]
  s.display == :none && return
  e.tag == "a" && haskey(e.attrs, "href") && (link = strip(e.attrs["href"]))
  if e.tag == "br"
    push!(out, Box(kind=:break, style=s, element=e))
    return
  elseif e.tag == "img"
    b = Box(kind=:image, style=s, element=e, link=link)
    b.atomic = !(s.display in (:block, :list_item, :table, :flex, :flow_root)) && !floats(b) && !placed(b)
    found = pictures(attr(e, "src"))
    if found !== nothing
      b.natural = (Float64(found[1]), Float64(found[2]))
      b.picture = found[3]
    end
    if found === nothing
      # Until a picture is there, its tag's width and height say what shape it has
      w, h = tryparse(Float64, strip(attr(e, "width"))), tryparse(Float64, strip(attr(e, "height")))
      w !== nothing && h !== nothing && w > 0 && h > 0 && (b.shape = w / h)
    end
    if found === nothing && !isempty(strip(attr(e, "alt")))
      # A picture that there isn't is as big as the words that stand for it, with 2 px round them, as in a browser
      b.text = strip(attr(e, "alt"))
      f = font(s.family, s.size, s.weight, s.italic)
      b.natural = (4.0 + min(1024.0, ceil(width(f, b.text))), 4.0 + min(256.0, f.ascent + f.descent))
    end
    push!(out, b)
    return
  end
  kids = Box[]
  for c in e.children
    add!(kids, c, s, look, pictures, link)
  end
  if s.display == :contents
    append!(out, kids)
    return
  end
  b = Box(kind=KINDS[s.display], style=s, element=e, children=kids, link=link)
  b.atomic = s.display in (:inline_block, :inline_table, :inline_flex)
  if b.kind == :cell
    b.colspan = clamp(something(tryparse(Int, strip(attr(e, "colspan"))), 1), 1, 1000)
    b.rowspan = clamp(something(tryparse(Int, strip(attr(e, "rowspan"))), 1), 0, 65534)
  end
  s.display == :list_item && (b.marker = marker(s.listtype, e.tag == "li" ? number(e) : 1))
  complete!(b)
  push!(out, b)
end

"Wrap each run of `b`'s children for which `ok` is true in a box that `wrap` makes of them"
wrap_runs!(wrap, b::Box, ok) = begin
  any(ok, b.children) || return
  out, run = Box[], Box[]
  flush() = (isempty(run) || push!(out, wrap(copy(run))); empty!(run))
  for c in b.children
    ok(c) ? push!(run, c) : (flush(); push!(out, c))
  end
  flush()
  b.children = out
end

"Make the boxes in `b` whole: see the top of this file"
complete!(b::Box) = begin
  kids = b.children
  # The parts of a table that are in no table get one
  if b.kind in (:table, :group, :row)
    filter!(c -> !blank(c), kids)
  end
  b.kind == :row || wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> c.kind == :cell)
  if b.kind == :table
    wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> !(c.kind in (:group, :row, :caption, :column)))
  elseif b.kind == :group
    wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> c.kind != :row)
  elseif b.kind == :row
    wrap_runs!(ks -> complete!(anonymous(:cell, b, ks)), b, c -> c.kind != :cell)
  else
    wrap_runs!(b, c -> c.kind in (:group, :row, :caption, :column)) do ks
      t = anonymous(:table, b, ks)
      t.style.display = :table
      t.atomic = b.kind == :inline
      t
    end
  end
  # An inline box with a block in it is a block
  if b.kind == :inline && any(c -> !inline(c) && !floats(c) && !placed(c), b.children)
    b.kind = :block
    s = child(b.style)
    s.display = :block
    s.position = b.style.position
    s.inset = b.style.inset
    b.style = s
  end
  # Text beside a block gets a block of its own
  if b.kind in (:block, :cell, :caption) && any(c -> !inline(c) && !floats(c) && !placed(c), b.children)
    out, run = Box[], Box[]
    flush() = begin
      all(c -> blank(c) || floats(c) || placed(c), run) ? append!(out, filter(!blank, run)) : push!(out, anonymous(:block, b, copy(run)))
      empty!(run)
    end
    for c in b.children
      inline(c) || ((floats(c) || placed(c)) && !isempty(run)) ? push!(run, c) : (flush(); push!(out, c))
    end
    flush()
    b.children = out
  end
  b
end

"The box of the page's <html> element, with the boxes of all that's in it"
boxes(doc::Document, look; pictures=no_pictures) = begin
  out = Box[]
  add!(out, doc.root, Style(), look, pictures, "")
  isempty(out) ? Box(kind=:block, style=Style(display=:block)) : (out[1].kind = :block; out[1])
end
