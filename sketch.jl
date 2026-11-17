# A sketch is a drawing made of lines, boxes, ovals, arrows and words. In a
# document it's a code block in the language `sketch`, with a line for each
# shape:
#
#     ```sketch
#     pen 12,30 14,32 18,40 25,44
#     line 10,10 80,60
#     arrow red 10,10 80,60
#     box 100,50 200,120
#     oval blue 100,50 200,120
#     text 120,80 The sink goes here
#     ```
#
# The first word is the kind of shape. A colour can come next: `red`, `blue`,
# `green` or `orange`. Without one, the shape is the colour of the page's
# text. Then come the shape's places, each as `x,y`. A sketch is 720 wide,
# whatever the width of the page, and as tall as its shapes need. `pen` is a
# line drawn by hand, through every place. `line` and `arrow` go from the
# first place to the second. `box` and `oval` have the two places as opposite
# corners. `text` starts at its place, and its words are the rest of the line.
#
# This file reads and writes those lines, and works out what a click is on.
# It draws nothing in a window. `svg` writes a sketch as a picture for a page
# of HTML.

"The language of a code block that is a sketch"
const SKETCH = "sketch"
const WIDE = 720.0       # how wide every sketch is, in its own measure
const LEAST = 220.0      # how tall a sketch with nothing low in it is
const ROOM = 48.0        # the room under a sketch's lowest shape
const TEXT_SIZE = 16.0   # how big the words of a sketch are
const KINDS = (:pen, :line, :arrow, :box, :oval, :text)
const COLOURS = (:ink, :red, :blue, :green, :orange)

const Place = NTuple{2,Float64}

mutable struct Shape
  kind::Symbol
  colour::Symbol
  points::Vector{Place}
  text::String
end

Shape(kind, colour, points) = Shape(kind, colour, points, "")

mutable struct Sketch
  shapes::Vector{Shape}
  other::Vector{String}   # the lines that this file doesn't know, kept as they are
end

Sketch() = Sketch(Shape[], String[])

"The place that `x,y` names, or nothing"
place(word::AbstractString) = begin
  m = match(r"^(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$", word)
  m === nothing ? nothing : (parse(Float64, m[1]), parse(Float64, m[2]))
end

"Read a sketch from the lines of its block"
sketch(lines) = begin
  s = Sketch()
  for line in lines
    isempty(strip(line)) && continue
    words = split(strip(line))
    kind = Symbol(lowercase(words[1]))
    at = 2
    colour = :ink
    if length(words) >= 2 && Symbol(lowercase(words[2])) in COLOURS
      colour = Symbol(lowercase(words[2]))
      at = 3
    end
    points = Place[]
    while at <= length(words) && (p = place(words[at])) !== nothing && !(kind == :text && !isempty(points))
      push!(points, p)
      at += 1
    end
    text = kind == :text ? join(words[at:end], " ") : ""
    good = kind == :text ? length(points) == 1 && !isempty(text) :
           kind == :pen ? length(points) >= 2 && at > length(words) :
           kind in KINDS && length(points) == 2 && at > length(words)
    good ? push!(s.shapes, Shape(kind, colour, points, text)) : push!(s.other, String(strip(line)))
  end
  s
end

"A number of a place as it's written: 12 not 12.0, and no more than one figure after the point"
figure(x::Real) = (r = round(x, digits=1); r == round(r) ? string(round(Int, r)) : string(r))

"The lines of a sketch's block"
written(s::Sketch) = begin
  out = map(s.shapes) do shape
    parts = String[string(shape.kind)]
    shape.colour == :ink || push!(parts, string(shape.colour))
    append!(parts, ("$(figure(x)),$(figure(y))" for (x, y) in shape.points))
    shape.kind == :text && push!(parts, shape.text)
    join(parts, " ")
  end
  [out; s.other]
end

"How wide the words of a text shape are, when nothing measures them: about half their size for each letter"
guess(text::AbstractString, size::Real) = 0.55 * size * length(text)

"The left, top, right and bottom of a shape. `measure(text, size)` says how wide the words of a text shape are."
bounds(shape::Shape, measure=guess) = begin
  if shape.kind == :text
    x, y = shape.points[1]
    return (x, y - TEXT_SIZE, x + measure(shape.text, TEXT_SIZE), y + 0.3TEXT_SIZE)
  end
  xs, ys = first.(shape.points), last.(shape.points)
  (minimum(xs), minimum(ys), maximum(xs), maximum(ys))
end

"How tall a sketch is: enough for its lowest shape, with room under it to draw more"
tall(s::Sketch) = max(LEAST, ceil(maximum(shape -> bounds(shape)[4], s.shapes, init=0.0) + ROOM))

"How far the place `p` is from the line between `a` and `b`"
apart(p::Place, a::Place, b::Place) = begin
  d = b .- a
  len = sum(abs2, d)
  t = len == 0 ? 0.0 : clamp(sum((p .- a) .* d) / len, 0.0, 1.0)
  hypot((p .- (a .+ t .* d))...)
end

"""
A line drawn by hand, with fewer places: a place that's less than `slack` from
the line between its neighbours that stay is left out. The line keeps its shape,
and its line of the block is short.
"""
simplify(points::Vector{Place}, slack::Real=0.8) = begin
  length(points) <= 2 && return copy(points)
  far, most = 0, 0.0
  for i in 2:length(points)-1
    d = apart(points[i], points[1], points[end])
    d > most && ((far, most) = (i, d))
  end
  most <= slack && return [points[1], points[end]]
  [simplify(points[1:far], slack)[1:end-1]; simplify(points[far:end], slack)]
end

"How far the place `p` is from what a shape draws: its line, its edge or its words"
distance(shape::Shape, p::Place, measure=guess) = begin
  k = shape.kind
  if k == :text
    l, t, r, b = bounds(shape, measure)
    return hypot(max(l - p[1], 0.0, p[1] - r), max(t - p[2], 0.0, p[2] - b))
  elseif k == :box
    l, t, r, b = bounds(shape)
    corners = [(l, t), (r, t), (r, b), (l, b), (l, t)]
    return minimum(apart(p, corners[i], corners[i+1]) for i in 1:4)
  elseif k == :oval
    l, t, r, b = bounds(shape)
    rx, ry = max((r - l) / 2, 1e-6), max((b - t) / 2, 1e-6)
    # How far out from the middle the place is, where the edge is 1
    out = hypot((p[1] - (l + r) / 2) / rx, (p[2] - (t + b) / 2) / ry)
    return abs(out - 1) * min(rx, ry)
  end
  minimum(apart(p, shape.points[i], shape.points[i+1]) for i in 1:length(shape.points)-1)
end

"The place of the shape that's within `reach` of `p`, or nothing. The shape that was drawn last is over the others, so it's the first that's looked at."
hit(s::Sketch, p::Place, reach::Real=6.0, measure=guess) = begin
  for i in length(s.shapes):-1:1
    distance(s.shapes[i], p, measure) <= reach && return i
  end
  nothing
end

"Move a shape by `(dx, dy)`"
move!(shape::Shape, dx::Real, dy::Real) = (shape.points = [(x + dx, y + dy) for (x, y) in shape.points]; shape)

"True for a shape that's too small to see: a line, a box or an oval whose two places are almost one"
slight(shape::Shape) = shape.kind in (:line, :arrow, :box, :oval) && hypot((shape.points[2] .- shape.points[1])...) < 3

"The two ends of the head of an arrow that points from `from` to `tip`"
barbs(from::Place, tip::Place, long::Real=11.0) = begin
  d = tip .- from
  len = max(hypot(d...), 1e-6)
  along, across = d ./ len, (-d[2], d[1]) ./ len
  back = tip .- along .* long
  (back .+ across .* 0.45long, back .- across .* 0.45long)
end

# --- a sketch as a picture for a page of HTML -------------------------------------------

xml(s::AbstractString) = replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

"""
A sketch as an SVG picture. `colours` gives the colour of each name in
`COLOURS`, as CSS writes a colour.
"""
svg(s::Sketch; colours, family="sans-serif") = begin
  out = IOBuffer()
  f = figure
  through(points) = join(("$(f(x)),$(f(y))" for (x, y) in points), " ")
  println(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $(f(WIDE)) $(f(tall(s)))\" width=\"$(f(WIDE))\" font-family=\"$(xml(family))\" role=\"img\">")
  for shape in s.shapes
    c = colours[shape.colour]
    stroke = "fill=\"none\" stroke=\"$c\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
    if shape.kind == :text
      x, y = shape.points[1]
      println(out, "<text x=\"$(f(x))\" y=\"$(f(y))\" font-size=\"$(f(TEXT_SIZE))\" fill=\"$c\">$(xml(shape.text))</text>")
    elseif shape.kind == :box
      l, t, r, b = bounds(shape)
      println(out, "<rect x=\"$(f(l))\" y=\"$(f(t))\" width=\"$(f(r - l))\" height=\"$(f(b - t))\" rx=\"3\" $stroke/>")
    elseif shape.kind == :oval
      l, t, r, b = bounds(shape)
      println(out, "<ellipse cx=\"$(f((l + r) / 2))\" cy=\"$(f((t + b) / 2))\" rx=\"$(f((r - l) / 2))\" ry=\"$(f((b - t) / 2))\" $stroke/>")
    else
      println(out, "<polyline points=\"$(through(shape.points))\" $stroke/>")
      if shape.kind == :arrow
        a, b = barbs(shape.points[1], shape.points[2])
        println(out, "<polyline points=\"$(through([a, shape.points[2], b]))\" $stroke/>")
      end
    end
  end
  print(out, "</svg>")
  String(take!(out))
end
