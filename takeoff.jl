# A takeoff is the list of what a job needs, measured from its plans: how many
# of each fitting, how long each run of pipe or cable is, how big each floor or
# wall is. In a document it's a code block in the language `takeoff`:
#
#     ```takeoff
#     plan: ground-floor.pdf
#     page: 1
#     scale: 1:100
#     customer: J Smith
#
#     count | Double power point | item 412
#       120,340 410,380 505,120
#     length | 20mm conduit | item 77 | +10%
#       100,100 300,100 300,400
#       2: 80,80 200,80
#     area | Floor tiles
#       50,50 400,50 400,300 50,300
#     ```
#
# The lines at the top say which file holds the plan, which of its pages
# shows, and the plan's scale. `scale 2: 1:50` gives page 2 a scale of its own.
#
# Each measure has a line with its kind, its name, the item of the catalogue
# that it's for, and how much to add for waste. Under it, each line that starts
# with spaces is one thing drawn on the plan: the marks of a count, the corners
# of a line for a length, or the corners of an outline for an area. `2:` at its
# start puts it on page 2.
#
# A point is measured from the top left of the page, in points: there are 72
# to an inch of paper. A picture has no paper size, so one of its pixels is one
# point, and its scale comes from a length that you know.
#
# This file reads and writes those lines, and works out what each measure
# comes to. It draws nothing.

"The language of a code block that is a takeoff"
const TAKEOFF = "takeoff"

const Point = NTuple{2,Float64}

"One thing drawn on a page of the plan: marks to count, a line of several corners, or an outline"
struct Shape
  page::Int
  points::Vector{Point}
end

"The kinds of measure, as they're written, and the unit that each comes to"
const KINDS = (:count, :length, :area)
const UNITS = (count="", length="m", area="m²")

"One line of the takeoff: what's measured, the catalogue item it's for, and where it is on the plan"
mutable struct Measure
  kind::Symbol            # :count, :length or :area
  name::String
  item::String            # what names the item in the catalogue, like "item 412", or "" when it has none yet
  extra::Float64          # the share added for waste: 0.1 adds 10%
  shapes::Vector{Shape}
end

Measure(kind::Symbol, name::AbstractString="") = Measure(kind, String(name), "", 0.0, Shape[])

mutable struct Takeoff
  plan::String                       # the file of the plan, as the block names it
  page::Int                          # the page that shows
  scales::Dict{Int,Float64}          # how many times bigger the job is than each page. 0 is for the pages with no scale of their own.
  customer::String
  made::String                       # the quote that was made from it, as the catalogue's app names it
  other::Vector{Pair{String,String}} # the lines at the top that this file doesn't know, kept as they are
  measures::Vector{Measure}
end

Takeoff() = Takeoff("", 1, Dict{Int,Float64}(), "", "", Pair{String,String}[], Measure[])

# --- reading ---------------------------------------------------------------------

"The scale that `text` gives, like 100 for \"1:100\", or nothing when it gives none"
scale(text::AbstractString) = begin
  m = match(r"^\s*(?:1\s*[:/]\s*)?(\d+(?:\.\d+)?)\s*$", text)
  m === nothing && return nothing
  n = parse(Float64, m[1])
  n > 0 ? n : nothing
end

"A scale as it's written: 1:100"
scale_text(n::Real) = "1:" * number(n)

"A number with one decimal place, or none when it's a whole number"
number(x::Real) = (r = round(Float64(x), digits=1); r == round(r) ? string(round(Int, r)) : string(r))

"The points that `text` lists, like \"10,20 30.5,40\". A part that isn't a point is left out."
points(text::AbstractString) = begin
  out = Point[]
  for m in eachmatch(r"(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)", text)
    push!(out, (parse(Float64, m[1]), parse(Float64, m[2])))
  end
  out
end

"The share that `text` adds, like 0.1 for \"+10%\", or nothing when it isn't written that way"
extra(text::AbstractString) = begin
  m = match(r"^\s*\+?\s*(\d+(?:\.\d+)?)\s*%\s*$", text)
  m === nothing ? nothing : parse(Float64, m[1]) / 100
end

"""
The kind of measure for an item that's sold by `unit`, as the catalogue writes
it: a length for metres, an area for square metres, and a count for anything
else, like a piece, a box or an hour.
"""
kind_for(unit::AbstractString) = begin
  u = replace(lowercase(strip(unit)), r"^(per|/)\s*" => "", r"[\s.]+" => " ")
  u = strip(replace(u, r"\b(lineal|linear|lin)\b" => "", "meter" => "metre", r"metres$" => "metre"))
  u in ("m²", "m2", "m^2", "sqm", "sq m", "sq metre", "square metre", "square m") ? :area :
  u in ("m", "lm", "l/m", "metre", "mm", "cm") ? :length : :count
end
kind_for(unit) = :count

"The measure that a line starts, or nothing when the line doesn't start one"
measure(line::AbstractString) = begin
  cells = String.(strip.(split(line, '|')))
  kind = Symbol(lowercase(cells[1]))
  kind in KINDS || return nothing
  m = Measure(kind, length(cells) >= 2 ? cells[2] : "")
  for cell in cells[3:end]
    isempty(cell) && continue
    e = extra(cell)
    e === nothing ? (m.item = cell) : (m.extra = e)
  end
  m
end

"The takeoff that the lines of a block describe. The lines are those between the two ``` lines."
takeoff(lines) = begin
  t = Takeoff()
  for line in lines
    isempty(strip(line)) && continue
    if startswith(line, r"\s") && !isempty(t.measures)
      # Something drawn for the measure above
      m = match(r"^\s+(?:(\d+)\s*:)?(.*)$", line)
      found = points(m[2])
      isempty(found) || push!(last(t.measures).shapes, Shape(m[1] === nothing ? 1 : parse(Int, m[1]), found))
      continue
    end
    made = measure(line)
    made === nothing || (push!(t.measures, made); continue)
    m = match(r"^([^:|]+):\s*(.*)$", line)
    m === nothing && continue
    key, value = lowercase(strip(m[1])), String(strip(m[2]))
    paged = match(r"^scale\s+(\d+)$", key)
    if key == "plan"
      t.plan = value
    elseif key == "page"
      t.page = max(1, something(tryparse(Int, value), 1))
    elseif key == "scale" || paged !== nothing
      n = scale(value)
      n === nothing || (t.scales[paged === nothing ? 0 : parse(Int, paged[1])] = n)
    elseif key == "customer"
      t.customer = value
    elseif key == "quote"
      t.made = value
    else
      push!(t.other, String(strip(m[1])) => value)
    end
  end
  t
end

# --- writing ---------------------------------------------------------------------

const MOST_MARKS = 10   # the marks of a count on one line. More go on the next line.

"The lines under a measure: one for each thing drawn. The marks of a count on one page share lines."
drawn(m::Measure) = begin
  row(page, ps) = "  " * (page == 1 ? "" : "$page: ") * join((number(x) * "," * number(y) for (x, y) in ps), " ")
  m.kind == :count || return [row(s.page, s.points) for s in m.shapes if !isempty(s.points)]
  out = String[]
  for page in sort!(unique(s.page for s in m.shapes))
    marks = reduce(vcat, (s.points for s in m.shapes if s.page == page), init=Point[])
    append!(out, (row(page, part) for part in Iterators.partition(marks, MOST_MARKS)))
  end
  out
end

"The lines of the block that describes `t`, without its two ``` lines"
written(t::Takeoff) = begin
  out = String[]
  isempty(t.plan) || push!(out, "plan: " * t.plan)
  isempty(t.plan) || push!(out, "page: $(t.page)")
  for page in sort!(collect(keys(t.scales)))
    push!(out, (page == 0 ? "scale: " : "scale $page: ") * scale_text(t.scales[page]))
  end
  isempty(t.customer) || push!(out, "customer: " * t.customer)
  isempty(t.made) || push!(out, "quote: " * t.made)
  append!(out, (k * ": " * v for (k, v) in t.other))
  isempty(out) || isempty(t.measures) || push!(out, "")
  for m in t.measures
    cells = [string(m.kind), m.name]
    isempty(m.item) || push!(cells, m.item)
    m.extra > 0 && (isempty(m.item) && push!(cells, ""); push!(cells, "+" * number(100m.extra) * "%"))
    push!(out, join(cells, " | "))
    append!(out, drawn(m))
  end
  out
end

# --- what each measure comes to ------------------------------------------------------

"The scale of page `page`, or nothing when it has none yet"
scale(t::Takeoff, page::Int) = get(t.scales, page, get(t.scales, 0, nothing))

"How many metres of the job one point of a page stands for, at a scale of 1 to `n`"
metres(n::Real) = n * 0.0254 / 72

"The scale of a page where the points `a` and `b` are `real` metres apart on the job"
scale(a::Point, b::Point, real::Real) = (d = hypot(b[1] - a[1], b[2] - a[2]); d > 0 && real > 0 ? real / metres(1) / d : nothing)

"How long the line through `ps` is, in points"
along(ps::Vector{Point}) = sum(hypot(ps[i+1][1] - ps[i][1], ps[i+1][2] - ps[i][2]) for i in 1:length(ps)-1; init=0.0)

"How big the outline with the corners `ps` is, in square points"
inside(ps::Vector{Point}) = begin
  n = length(ps)
  n < 3 && return 0.0
  abs(sum(ps[i][1] * ps[mod1(i + 1, n)][2] - ps[mod1(i + 1, n)][1] * ps[i][2] for i in 1:n)) / 2
end

"What one shape of a measure of this kind comes to, before anything is added for waste: a count, metres or square metres. It's nothing when its page has no scale."
amount(t::Takeoff, kind::Symbol, s::Shape) = begin
  kind == :count && return Float64(length(s.points))
  n = scale(t, s.page)
  n === nothing && return nothing
  kind == :length ? along(s.points) * metres(n) : inside(s.points) * metres(n)^2
end

"""
What `m` comes to, with what it adds for waste: a count, metres or square
metres. It's nothing when a page that it's drawn on has no scale.
"""
amount(t::Takeoff, m::Measure) = begin
  total = 0.0
  for s in m.shapes
    a = amount(t, m.kind, s)
    a === nothing && return nothing
    total += a
  end
  total * (1 + m.extra)
end

"An amount as the list shows it: 12, 12.4 m or 38.25 m²"
shown(kind::Symbol, amount::Real) = begin
  kind == :count && return string(round(Int, amount))
  r = round(amount, digits=2)
  (r == round(r) ? string(round(Int, r)) : string(r)) * " " * getfield(UNITS, kind)
end

# --- finding what's under the mouse ---------------------------------------------------

"How far `p` is from the line between `a` and `b`"
apart(p::Point, a::Point, b::Point) = begin
  dx, dy = b[1] - a[1], b[2] - a[2]
  len = dx^2 + dy^2
  k = len == 0 ? 0.0 : clamp(((p[1] - a[1]) * dx + (p[2] - a[2]) * dy) / len, 0.0, 1.0)
  hypot(p[1] - a[1] - k * dx, p[2] - a[2] - k * dy)
end

"""
The corner or the mark on page `page` that's nearest to `p`, if one is within
`reach`: the place of its measure, of its shape and of the point. It's nothing
when none is that near.
"""
corner(t::Takeoff, page::Int, p::Point, reach::Real) = begin
  best, found = Float64(reach), nothing
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == page || continue
    for (k, q) in enumerate(s.points)
      d = hypot(q[1] - p[1], q[2] - p[2])
      d <= best && ((best, found) = (d, (i, j, k)))
    end
  end
  found
end

"True when `p` is in the outline with the corners `ps`"
within(p::Point, ps::Vector{Point}) = begin
  n, hit = length(ps), false
  for i in 1:n
    a, b = ps[i], ps[mod1(i + 1, n)]
    (a[2] > p[2]) != (b[2] > p[2]) && p[1] < a[1] + (p[2] - a[2]) * (b[1] - a[1]) / (b[2] - a[2]) && (hit = !hit)
  end
  hit
end

"""
The shape on page `page` that's under `p`: the place of its measure and of the
shape. A mark and a line are under `p` when they're within `reach` of it, and
so is the edge of an outline. The inside of an outline counts when nothing
else is under `p`. It's nothing when no shape is there.
"""
shape(t::Takeoff, page::Int, p::Point, reach::Real) = begin
  best, found, filled = Float64(reach), nothing, nothing
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == page || continue
    ps = s.points
    d = m.kind == :count || length(ps) == 1 ? minimum(q -> hypot(q[1] - p[1], q[2] - p[2]), ps, init=Inf) :
        minimum(apart(p, ps[k], ps[k+1]) for k in 1:length(ps)-1; init=Inf)
    m.kind == :area && length(ps) > 2 && (d = min(d, apart(p, ps[end], ps[1])))
    d <= best && ((best, found) = (d, (i, j)))
    m.kind == :area && filled === nothing && within(p, ps) && (filled = (i, j))
  end
  something(found, Some(filled))
end

# --- changing it -------------------------------------------------------------------

"Add a mark to the count `m` on page `page`"
mark!(m::Measure, page::Int, p::Point) = begin
  i = findlast(s -> s.page == page, m.shapes)
  i === nothing ? push!(m.shapes, Shape(page, [p])) : push!(m.shapes[i].points, p)
  m
end

"Take point `k` of shape `j` away from `m`. A shape that's left with too few points to be one goes too."
remove!(m::Measure, j::Int, k::Int) = begin
  ps = m.shapes[j].points
  deleteat!(ps, k)
  least = m.kind == :count ? 1 : m.kind == :length ? 2 : 3
  length(ps) < least && deleteat!(m.shapes, j)
  m
end

export TAKEOFF, Takeoff, Measure, Shape, Point, takeoff, written, amount, shown, scale, scale_text, metres,
       corner, shape, mark!, remove!, number
