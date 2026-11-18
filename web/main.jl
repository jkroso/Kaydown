# Draws a page of HTML: reads it, works out its styles, lays it out and draws
# it with Skia, with no browser.
#
#     p = page(html; wide=700)
#     p.wide, p.tall             # how big the page is, in px
#     draw(canvas, p)            # draw it, with its top left corner at the canvas's
#     draw(canvas, p; top=400, bottom=900)   # or only what's between two heights of it
#     save(p, "page.png")        # a picture of all of it
#     p.links                    # each rectangle of the page that's a link, and where it goes
#     p.words                    # its words in the order that the HTML has them, with where each letter is
#     link(p, x, y)              # the link at a point of the page, or nothing
#
# `zoom` makes everything in the page that much bigger, as a browser's zoom
# does. The page is still `wide` px wide.
#
# The page runs no script and asks the web for nothing. A picture that's
# written into the page (`src="data:..."`) is drawn. For any other picture,
# `load(address)` is asked for the bytes of its file, or nothing. With none, a
# picture is an empty box.
#
# The parts: dom.jl reads the HTML into a tree. css.jl reads CSS. style.jl
# works out the style of each element. box.jl makes the boxes. layout.jl gives
# each its size and place. paint.jl draws them. text.jl finds fonts and
# measures text.

@use Skia
@use Base64: base64decode
@use "./dom" document
@use "./box" boxes Box
@use "./style" styles isauto ispercent
@use "./layout" layout!
@use "./paint" => Paint

"The pictures of a page: each address that it names, with the picture's size and Skia's picture, or nothing"
mutable struct Pictures
  found::Dict{String,Any}
  load::Function
end

"Skia's picture of the bytes of a picture's file, with its size, or nothing"
decode(bytes::Vector{UInt8}) = begin
  isempty(bytes) && return nothing
  data = Skia.sk_data_new_with_copy(bytes, Csize_t(length(bytes)))
  image = Skia.sk_image_new_from_encoded(data)
  Skia.sk_data_unref(data)
  image == C_NULL && return nothing
  (Int(Skia.sk_image_get_width(image)), Int(Skia.sk_image_get_height(image)), Ptr{Cvoid}(image))
end

"The bytes that an address like `data:image/png;base64,...` holds, or nothing"
inline_bytes(src) = begin
  m = match(r"^data:[^,]*?(;base64)?,(.*)$"is, src)
  m === nothing && return nothing
  try
    m[1] === nothing ? Vector{UInt8}(replace(m[2], r"%([0-9a-fA-F]{2})" => s -> Char(Base.parse(UInt8, s[2:3], base=16)))) :
                       base64decode(replace(m[2], r"\s" => ""))
  catch
    nothing
  end
end

(p::Pictures)(src::AbstractString) = begin
  src = String(strip(src))
  isempty(src) && return nothing
  get!(p.found, src) do
    bytes = startswith(lowercase(src), "data:") ? inline_bytes(src) : p.load(src)
    bytes === nothing ? nothing : decode(Vector{UInt8}(bytes))
  end
end

release(p::Pictures) = begin
  for found in values(p.found)
    found === nothing || Skia.sk_image_unref(found[3])
  end
  empty!(p.found)
end

"A page of HTML that's laid out and ready to draw"
struct Page
  wide::Float64
  tall::Float64
  zoom::Float64
  list::Paint.List
  links::Vector{Paint.Link}
  words::Vector{Paint.Words}
  pictures::Pictures
end

# What lets a page that's wider than its window be as narrow as the window: a table, a picture or a block of code
# shrinks to the page, and a long word breaks
const FIT = """
table { max-width: 100% !important }
img, video { max-width: 100% !important }
img[width][height] { height: auto !important }
pre { white-space: pre-wrap !important }
body { overflow-wrap: break-word !important }
[data-fit-page] { width: auto !important; min-width: 0 !important }
table[data-fit-page] { width: 100% !important }
"""

"Mark each element under `b` whose style says a width that makes it wider than `wide` px, so that `FIT` takes the width away"
mark_wide!(b::Box, wide) = begin
  s = b.style
  if b.element !== nothing && b.kind != :image && b.kind != :text && !isauto(s.width) && !ispercent(s.width) && b.width > wide + 1
    b.element.attrs["data-fit-page"] = ""
  end
  foreach(k -> mark_wide!(k, wide), b.children)
end

"""
Lay out the page that `html` writes, `wide` px wide. `load(address)` gives the
bytes of a picture that the page names, or nothing. `css` is CSS that goes
after the page's own.

With `fit`, a page whose content is wider than `wide` is made to fit: a width
that the HTML gives a table or a cell, wider than the page, is taken away, and
a picture or a block of code shrinks to the page. Outlook gives the table
round an email the width of its sender's window, which can be 2000 px. A page
whose content still can't be that narrow is as wide as its content, up to
`widest` px, and `p.wide` says how wide that is.
"""
page(html::AbstractString; wide=700, zoom=1.0, load=src -> nothing, css="", fit=false, widest=2000) = begin
  doc = document(html)
  inner = wide / zoom
  pictures = Pictures(Dict{String,Any}(), load)
  finalizer(release, pictures)
  find = src -> pictures(src)
  lay(across, extra) = begin
    look = styles(doc, across; extra)
    root = boxes(doc, look; pictures=find)
    tall = layout!(root, across, doc.mode)
    (root, tall, Paint.list(root, across, tall; pictures=find))
  end
  root, tall, l = lay(inner, css)
  if fit && Paint.right(l) > inner + 1
    mark_wide!(root, inner)
    root, tall, l = lay(inner, css * FIT)
    needs = min(widest / zoom, ceil(Paint.right(l)))
    if needs > inner + 1
      inner = needs
      root, tall, l = lay(inner, css * FIT)
    end
  end
  z(link::Paint.Link) = (left=link.left * zoom, top=link.top * zoom, wide=link.wide * zoom, tall=link.tall * zoom, url=link.url)
  z(w::Paint.Words) = (before=w.before, top=w.top * zoom, tall=w.tall * zoom, edges=w.edges .* zoom, letters=w.letters, from=w.from)
  Page(ceil(inner * zoom), ceil(tall * zoom), Float64(zoom), l, zoom == 1 ? l.links : map(z, l.links), zoom == 1 ? l.words : map(z, l.words), pictures)
end

"""
Draw the page on a Skia canvas, with its top left corner at `(x, y)`. With
`top` and `bottom`, only what's between those two heights of the page is
drawn.
"""
draw(canvas, p::Page; x=0.0, y=0.0, top=-Inf, bottom=Inf) = begin
  Skia.sk_canvas_save(canvas)
  Skia.sk_canvas_translate(canvas, Float32(x), Float32(y))
  Skia.sk_canvas_scale(canvas, Float32(p.zoom), Float32(p.zoom))
  Paint.draw(canvas, p.list; top=top / p.zoom, bottom=bottom / p.zoom)
  Skia.sk_canvas_restore(canvas)
end

"The link at the point `(x, y)` of the page, or nothing"
link(p::Page, x, y) = begin
  # A link that's written later is drawn over one that's written before it
  i = findlast(l -> l.left <= x <= l.left + l.wide && l.top <= y <= l.top + l.tall, p.links)
  i === nothing ? nothing : p.links[i]
end

"""
Save a picture of the page as a PNG file, with `scale` pixels to the px.
`background` is the colour behind a page that has none of its own.
"""
save(p::Page, path::AbstractString; scale=2.0, background=0xffffffff) = begin
  w, h = max(1, round(Int, p.wide * scale)), max(1, round(Int, p.tall * scale))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, w, h))
  GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    surface == C_NULL && error("Skia could not make a picture $w by $h")
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, background)
    Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
    draw(canvas, p)
    image = Skia.sk_surface_make_image_snapshot(surface)
    encoded = Skia.sk_encode_png(C_NULL, image, Int32(6))
    write(path, unsafe_wrap(Array, Ptr{UInt8}(Skia.sk_data_get_data(encoded)), Skia.sk_data_get_size(encoded)))
    Skia.sk_data_unref(encoded)
    Skia.sk_image_unref(image)
    Skia.sk_surface_unref(surface)
  end
  path
end
