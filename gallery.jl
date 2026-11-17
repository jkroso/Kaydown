# A gallery shows the pictures of a folder as a grid of small squares. In a
# document it's a code block in the language `gallery`:
#
#     ```gallery
#     in: photos
#     sort: newest
#     size: large
#     plans/front.png
#     ```
#
# `in` names a folder beside the page. An empty block shows the pictures in
# the page's own folder. Any other line is the path of one picture, so a block
# can list its pictures by hand. A block that has such lines and no `in` line
# shows only the pictures that it lists.
#
# The folder's pictures are in the order of their names, as a person reads
# them: photo 2 comes before photo 10. The pictures that the block lists come
# after them, in the order of their lines. `sort: newest` puts every picture
# in the order of its file's date, the newest first.
#
# `size` is small, medium or large, and says how big each square is at the
# least. Without it, the squares are medium.
#
# This file reads and writes those lines, lists the pictures, and works out
# the grid. It draws nothing.

"The language of a code block that is a gallery"
const GALLERY = "gallery"

"The sizes that a gallery's squares can be, with the least px that a side of each is"
const SIDES = (small=80, medium=132, large=220)

"The sizes that the small picture of a file can be: how many pixels its longer side has"
const PIXELS = (256, 400, 640, 1024)

"The px between two squares of the grid"
const GAP = 8

mutable struct Gallery
  folder::Union{Nothing,String}   # the folder that `in` names, or nothing when the block has no such line
  sort::Symbol                    # :name or :newest
  size::Symbol                    # a key of SIDES
  listed::Vector{String}          # the pictures that the block lists by hand, as their lines write them
  other::Vector{String}           # the lines like `key: value` that this file doesn't know, kept as they are
end

Gallery() = Gallery(nothing, :name, :medium, String[], String[])

"One picture of a gallery: the path of its file, the file's name, and when the file last changed"
struct Picture
  path::String
  name::String
  at::Float64
end

"Read a gallery from the lines of its block. A line that it can't read changes nothing."
gallery(lines) = begin
  g = Gallery()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    # A line like `key: value` is never a path. One of the gallery's own keys needs no space after its colon.
    m = something(match(r"^(in|sort|size)\s*:\s*(.*)$"i, text), match(r"^([A-Za-z][\w -]*?)\s*:(?:\s+(.*))?$", text), Some(nothing))
    if m === nothing
      push!(g.listed, String(text))
      continue
    end
    key, value = lowercase(m[1]), String(strip(something(m[2], "")))
    if key == "in"
      g.folder = value in (".", "./") ? "" : String(rstrip(value, '/'))
    elseif key == "sort"
      lowercase(value) in ("newest", "new", "date") && (g.sort = :newest)
      lowercase(value) in ("name", "names") && (g.sort = :name)
    elseif key == "size"
      Symbol(lowercase(value)) in keys(SIDES) && (g.size = Symbol(lowercase(value)))
    else
      push!(g.other, String(text))
    end
  end
  g
end

"The lines of a gallery's block. A gallery that says no more than an empty block says has no lines."
written(g::Gallery) = begin
  out = String[]
  g.folder === nothing || push!(out, isempty(g.folder) ? "in: ." : "in: $(g.folder)")
  g.sort == :name || push!(out, "sort: $(g.sort)")
  g.size == :medium || push!(out, "size: $(g.size)")
  append!(out, g.other)
  append!(out, g.listed)
end

"The size after `size`, for a button that goes round the three sizes: medium, large, small and medium again"
next_size(size::Symbol) = size == :medium ? :large : size == :large ? :small : :medium

"""
The folder whose pictures the gallery shows, for a page in the folder `dir`.
It's nothing for a gallery that shows only the pictures that it lists.
"""
folder(g::Gallery, dir) = g.folder === nothing ? (isempty(g.listed) ? String(dir) : nothing) : abspath(joinpath(dir, expanduser(g.folder)))

"What the gallery calls its folder: the name that the block gives it, or “this folder” for the page's own"
folder_name(g::Gallery) = g.folder === nothing || isempty(g.folder) ? "this folder" : g.folder

"`name` written so that names sort as a person reads them: photo 2 comes before photo 10"
order(name) = replace(lowercase(name), r"\d+" => n -> lpad(n, 20, '0'))

"True when the name of the file at `path` ends as one of `kinds` does, like .png"
ispicture(path, kinds) = lowercase(splitext(path)[2]) in kinds

"The picture in the file at `path`"
Picture(path::AbstractString) = Picture(String(path), basename(path), mtime(path))

"""
What the gallery shows, for a page in the folder `dir`. `kinds` holds the ends
of the names of the files that are pictures, like .png. It gives:

- `pictures`: the pictures, in the order that the gallery shows them
- `folder`: how many of them come from the gallery's folder
- `lost`: the lines of the block that name no picture
- `problem`: why there are no pictures, or "" when there are some
"""
pictures(g::Gallery, dir; kinds) = begin
  out, lost = Picture[], String[]
  from = folder(g, dir)
  there = from !== nothing && isdir(from)
  if there
    names = try readdir(from) catch; String[] end
    for name in sort!(names, by=n -> (order(n), n))
      path = joinpath(from, name)
      startswith(name, '.') || !ispicture(name, kinds) || !isfile(path) || push!(out, Picture(path))
    end
  end
  count = length(out)
  for line in g.listed
    path = abspath(joinpath(dir, expanduser(line)))
    if !(isfile(path) && ispicture(path, kinds))
      push!(lost, line)
    elseif !any(p -> p.path == path, out)
      push!(out, Picture(path))
    end
  end
  g.sort == :newest && sort!(out, by=p -> (-p.at, order(p.name)))
  problem = !isempty(out) ? "" :
            from !== nothing && !there ? "There's no folder called “$(g.folder)” beside this page." :
            from === nothing ? "No pictures" : "No pictures in $(folder_name(g))"
  (pictures=out, folder=count, lost=lost, problem=problem)
end

"What the top of a gallery says: how many pictures it shows and where they are, like “12 pictures in photos”"
summary(g::Gallery, found) = begin
  n = length(found.pictures)
  n == 0 && return found.problem
  said(k) = k == 1 ? "1 picture" : "$k pictures"
  (g.folder === nothing && !isempty(g.listed)) && return said(n)
  rest = n - found.folder
  rest == 0 ? "$(said(n)) in $(folder_name(g))" : "$(said(found.folder)) in $(folder_name(g)), and $rest more"
end

"What a gallery says of the lines that name no picture, or \"\" when each line names one"
lost_words(lost) = isempty(lost) ? "" : length(lost) == 1 ? "No picture at $(lost[1])" : "No picture at " * join(lost[1:end-1], ", ") * " or " * lost[end]

"""
The grid for `n` pictures in a block whose pictures have `wide` px of room:
how many columns it has, how many rows, and how many px a side of each square
is. It has as many columns as fit, and the squares grow to take all the room,
so the gap between them is always `GAP`.
"""
grid(n::Integer, wide::Real, size::Symbol) = begin
  least = SIDES[size]
  columns = max(1, floor(Int, (wide + GAP) / (least + GAP)))
  side = max(1.0, (wide - GAP * (columns - 1)) / columns)
  (columns=columns, rows=cld(n, columns), side=side)
end

"How tall a grid of `rows` rows is, with squares that are `side` px"
tall(rows::Integer, side::Real) = rows == 0 ? 0.0 : rows * side + (rows - 1) * GAP

"""
The rows of a grid that show between `top` and `bottom`, which are px down
from the top of the grid. It's empty when no row shows there.
"""
rows_between(top::Real, bottom::Real, rows::Integer, side::Real) = begin
  step = side + GAP
  from = max(1, floor(Int, top / step) + 1)
  to = min(rows, floor(Int, bottom / step) + 1)
  from:to
end

"""
How many pixels the longer side of a file's small picture has, for squares
that are `side` px. A square shows the middle of its picture, on a screen with
two pixels to the px, so a picture that's wider than it's tall needs more
pixels than twice the square's px.
"""
pixels(side::Real) = PIXELS[something(findfirst(>=(2.7side), PIXELS), lastindex(PIXELS))]

"The pictures of row `r` of a grid with `columns` columns, as places among `n` pictures"
row_places(r::Integer, columns::Integer, n::Integer) = (r - 1) * columns + 1:min(r * columns, n)

"""
The part of a picture that's `w` wide and `h` tall that a square shows: the
biggest square in its middle. It's a left, a top, a width and a height.
"""
crop(w::Real, h::Real) = (s = min(w, h); ((w - s) / 2, (h - s) / 2, s, s))

"""
Copy the file at `path` into `folder`, and return where it is now. The folder
is made if it isn't there. A file that's in the folder already stays where it
is. If the folder has another file of that name, the copy gets a number after
its name. It's nothing when the file can't be copied.
"""
keep(folder, path) = begin
  path = abspath(path)
  dirname(path) == abspath(folder) && return path
  try
    mkpath(folder)
    stem, ext = splitext(basename(path))
    to, n = joinpath(folder, stem * ext), 1
    while ispath(to)
      to = joinpath(folder, "$stem-$(n += 1)$ext")
    end
    cp(path, to)
    to
  catch
    nothing
  end
end
