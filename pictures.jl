# Pictures that macOS makes, for the files that Skia can't read itself.
#
# - `picture(path)` reads a picture of a kind that macOS knows and Skia doesn't,
#   like HEIC, TIFF and SVG.
# - `thumbnail(path)` is the picture that the Finder shows for a file: the first
#   page of a Word file, the letters of a font and so on.
# - `pdf_page(path, n, wide)` draws one page of a PDF file.
#
# Each gives the key of a picture, to draw with `Image(key)`, or nothing when
# macOS has no picture for the file. A picture is made once and kept, so it
# costs nothing to ask for it in every frame. This file only works on macOS.

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool
@use "github.com/jkroso/UI.jl/Interface/image" register_image has_image

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const QuickLook = "/System/Library/Frameworks/QuickLook.framework/QuickLook"
const ImageIO = "/System/Library/Frameworks/ImageIO.framework/ImageIO"
const CoreGraphics = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
const CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

const Object = Ptr{Cvoid}
const Rect = NTuple{4,Float64}   # where it starts, how wide it is and how tall

release(object) = object == C_NULL || ccall((:CFRelease, CoreFoundation), Cvoid, (Object,), object)
fileurl(path) = msg(cls("NSURL"), "fileURLWithPath:", nsstring(abspath(path)))

"The bytes of a PNG file of `image`, one of macOS's CGImages"
png(image::Object) = begin
  data = msg(cls("NSMutableData"), "data")
  to = ccall((:CGImageDestinationCreateWithData, ImageIO), Object, (Object, Object, Csize_t, Object), data, nsstring("public.png"), 1, C_NULL)
  to == C_NULL && return UInt8[]
  ccall((:CGImageDestinationAddImage, ImageIO), Cvoid, (Object, Object, Object), to, image, C_NULL)
  done = ccall((:CGImageDestinationFinalize, ImageIO), Bool, (Object,), to)
  release(to)
  done || return UInt8[]
  n = ccall((:objc_msgSend, libobjc), UInt, (Object, Object), data, sel("length"))
  copy(unsafe_wrap(Array, Ptr{UInt8}(msg(data, "bytes")), n))
end

# The keys of the files that macOS had no picture for, so that it's asked once
const none = Set{String}()

"""
The key of the picture that `make()` gives: one of macOS's CGImages, which is
released here, or C_NULL. The picture is kept under `key`.
"""
keep(make, key::String) = begin
  has_image(key) && return key
  (key in none || !Sys.isapple()) && return nothing
  bytes = try
    with_pool() do
      image = make()
      image == C_NULL && return UInt8[]
      out = png(image)
      release(image)
      out
    end
  catch
    UInt8[]
  end
  isempty(bytes) && (push!(none, key); return nothing)
  try
    register_image(key, bytes)
  catch
    push!(none, key)
    nothing
  end
end

"A key for the file at `path` that changes when the file does"
stamp(kind, path, more...) = join((kind, abspath(path), mtime(path), more...), ':')

"""
The picture in the file at `path`, of any kind that macOS reads. A picture
that's made of shapes, like an SVG, is drawn `side` pixels along its longer side.
"""
picture(path::AbstractString, side::Integer=1600) = begin
  key = stamp("picture", path, side)
  keep(() -> read_picture(path, side, key), key)
end

# How big macOS says each picture of `picture` is, in px. A picture that's made of shapes has more pixels than that.
const sizes = Dict{String,NTuple{2,Float64}}()

"How wide and how tall the picture that `picture` kept under `key` is on a page, in px, or nothing for any other picture"
natural(key::AbstractString) = get(sizes, key, nothing)

read_picture(path, side, key) = begin
  Base.Libc.Libdl.dlopen(AppKit)
  # macOS finds the kind of picture from the bytes, so the end of the file's name doesn't matter
  data = msg(cls("NSData"), "dataWithContentsOfFile:", nsstring(abspath(path)))
  data == C_NULL && return C_NULL
  image = msg(msg(msg(cls("NSImage"), "alloc"), "initWithData:", data), "autorelease")
  image == C_NULL && return C_NULL
  w, h = ccall((:objc_msgSend, libobjc), NTuple{2,Float64}, (Object, Object), image, sel("size"))
  (w > 0 && h > 0) || return C_NULL
  sizes[key] = (w, h)
  # A picture made of pixels comes at its own size. One made of shapes comes at the size that's asked for.
  k = side / max(w, h)
  room = Ref{Rect}((0.0, 0.0, w * k, h * k))
  made = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{Cvoid}, Object, Object), image,
               sel("CGImageForProposedRect:context:hints:"), room, C_NULL, C_NULL)
  # The picture belongs to the NSImage, which goes when this is done, so take a share in it
  made == C_NULL || ccall((:CFRetain, CoreFoundation), Object, (Object,), made)
  made
end

"The picture that the Finder shows for the file at `path`, no more than `side` pixels wide or tall"
thumbnail(path::AbstractString, side::Integer=1000) = keep(stamp("thumbnail", path, side)) do
  ccall((:QLThumbnailImageCreate, QuickLook), Object, (Object, Object, NTuple{2,Float64}, Object),
        C_NULL, fileurl(path), (Float64(side), Float64(side)), C_NULL)
end

"How many pages the PDF file at `path` has, or 0 if it isn't a PDF file that macOS can read"
pdf_pages(path::AbstractString) = Sys.isapple() ? with_pool() do
  pdf = ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))
  pdf == C_NULL && return 0
  n = Int(ccall((:CGPDFDocumentGetNumberOfPages, CoreGraphics), Csize_t, (Object,), pdf))
  release(pdf)
  n
end : 0

"Page `n` of the PDF file at `path`, drawn `wide` pixels wide on white paper"
pdf_page(path::AbstractString, n::Integer, wide::Integer) = keep(stamp("pdf", path, n, wide)) do
  pdf = ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))
  pdf == C_NULL && return C_NULL
  page = ccall((:CGPDFDocumentGetPage, CoreGraphics), Object, (Object, Csize_t), pdf, n)
  page == C_NULL && (release(pdf); return C_NULL)
  # 1 is the part of the page that shows: its crop box
  _, _, w, h = ccall((:CGPDFPageGetBoxRect, CoreGraphics), Rect, (Object, Int32), page, 1)
  # A page can say that it's turned on its side
  ccall((:CGPDFPageGetRotationAngle, CoreGraphics), Int32, (Object,), page) % 180 == 0 || ((w, h) = (h, w))
  (w > 0 && h > 0) || (release(pdf); return C_NULL)
  tall = max(1, round(Int, wide * h / w))
  colours = ccall((:CGColorSpaceCreateDeviceRGB, CoreGraphics), Object, ())
  # 8 bits for each of red, green, blue and alpha. The 1 says that alpha comes last.
  paper = ccall((:CGBitmapContextCreate, CoreGraphics), Object, (Object, Csize_t, Csize_t, Csize_t, Csize_t, Object, UInt32),
                C_NULL, wide, tall, 8, 0, colours, 1)
  release(colours)
  paper == C_NULL && (release(pdf); return C_NULL)
  ccall((:CGContextSetRGBFillColor, CoreGraphics), Cvoid, (Object, Float64, Float64, Float64, Float64), paper, 1.0, 1.0, 1.0, 1.0)
  ccall((:CGContextFillRect, CoreGraphics), Cvoid, (Object, Rect), paper, (0.0, 0.0, Float64(wide), Float64(tall)))
  ccall((:CGContextScaleCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, wide / w, wide / w)
  # This puts the page in a box of its own size, the right way up
  place = ccall((:CGPDFPageGetDrawingTransform, CoreGraphics), NTuple{6,Float64}, (Object, Int32, Rect, Int32, Bool),
                page, 1, (0.0, 0.0, w, h), 0, true)
  ccall((:CGContextConcatCTM, CoreGraphics), Cvoid, (Object, NTuple{6,Float64}), paper, place)
  ccall((:CGContextDrawPDFPage, CoreGraphics), Cvoid, (Object, Object), paper, page)
  image = ccall((:CGBitmapContextCreateImage, CoreGraphics), Object, (Object,), paper)
  release(paper)
  release(pdf)
  image
end

# The PDF files that a takeoff shows, kept open while they don't change, so that a part of a page is quick to draw.
# Each has when its file last changed and macOS's document.
const open_pdfs = Dict{String,Tuple{Float64,Object}}()

"macOS's document for the PDF file at `path`, or C_NULL if it isn't a PDF file that macOS can read. It's kept, so don't release it."
pdf(path::AbstractString) = begin
  path = abspath(path)
  at = mtime(path)
  kept = get(open_pdfs, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  kept === nothing || release(kept[2])
  doc = Sys.isapple() && isfile(path) ? with_pool(() -> ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))) : C_NULL
  open_pdfs[path] = (at, doc)
  doc
end

"Page `n` of a PDF document, how wide and how tall it shows in points, and whether it's turned on its side. It's nothing when there's no such page."
pdf_box(doc::Object, n::Integer) = begin
  doc == C_NULL && return nothing
  page = ccall((:CGPDFDocumentGetPage, CoreGraphics), Object, (Object, Csize_t), doc, n)
  page == C_NULL && return nothing
  _, _, w, h = ccall((:CGPDFPageGetBoxRect, CoreGraphics), Rect, (Object, Int32), page, 1)
  ccall((:CGPDFPageGetRotationAngle, CoreGraphics), Int32, (Object,), page) % 180 == 0 || ((w, h) = (h, w))
  (w > 0 && h > 0) ? (page, w, h) : nothing
end

"How wide and how tall page `n` of the PDF file at `path` is, in points: 72 to an inch of paper. It's nothing when there's no such page."
pdf_size(path::AbstractString, n::Integer) = begin
  found = pdf_box(pdf(path), n)
  found === nothing ? nothing : (found[2], found[3])
end

"""
A part of page `n` of the PDF file at `path`, as pixels. The page is drawn `k`
pixels to the point, on white paper. The part starts `x` pixels from the left
of that drawing and `y` from its top, and is `w` pixels wide and `h` tall. Each
pixel is a number with blue in its lowest byte, then green, red and alpha. It's
nothing when the page can't be drawn.
"""
pdf_part(path::AbstractString, n::Integer, k::Real, x::Real, y::Real, w::Integer, h::Integer) = begin
  (w > 0 && h > 0 && k > 0) || return nothing
  found = pdf_box(pdf(path), n)
  found === nothing && return nothing
  page, pw, ph = found
  with_pool() do
    colours = ccall((:CGColorSpaceCreateDeviceRGB, CoreGraphics), Object, ())
    # 8 bits for each of blue, green, red and alpha, in that order. 2 says that alpha is in the highest byte, and 8192 that the low byte comes first.
    paper = ccall((:CGBitmapContextCreate, CoreGraphics), Object, (Object, Csize_t, Csize_t, Csize_t, Csize_t, Object, UInt32),
                  C_NULL, w, h, 8, 0, colours, 2 | 8192)
    release(colours)
    paper == C_NULL && return nothing
    ccall((:CGContextSetRGBFillColor, CoreGraphics), Cvoid, (Object, Float64, Float64, Float64, Float64), paper, 1.0, 1.0, 1.0, 1.0)
    ccall((:CGContextFillRect, CoreGraphics), Cvoid, (Object, Rect), paper, (0.0, 0.0, Float64(w), Float64(h)))
    # macOS measures up from the bottom, so the part's bottom edge is what's put at the bottom of the pixels
    ccall((:CGContextTranslateCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, -Float64(x), h + Float64(y) - ph * k)
    ccall((:CGContextScaleCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, Float64(k), Float64(k))
    place = ccall((:CGPDFPageGetDrawingTransform, CoreGraphics), NTuple{6,Float64}, (Object, Int32, Rect, Int32, Bool),
                  page, 1, (0.0, 0.0, pw, ph), 0, true)
    ccall((:CGContextConcatCTM, CoreGraphics), Cvoid, (Object, NTuple{6,Float64}), paper, place)
    ccall((:CGContextDrawPDFPage, CoreGraphics), Cvoid, (Object, Object), paper, page)
    from = Ptr{UInt32}(ccall((:CGBitmapContextGetData, CoreGraphics), Ptr{Cvoid}, (Object,), paper))
    row = Int(ccall((:CGBitmapContextGetBytesPerRow, CoreGraphics), Csize_t, (Object,), paper)) ÷ 4
    out = Vector{UInt32}(undef, w * h)
    # A row of macOS's pixels can be longer than the part is wide
    for r in 0:h-1
      unsafe_copyto!(pointer(out, r * w + 1), from + 4r * row, w)
    end
    release(paper)
    out
  end
end

export picture, natural, thumbnail, pdf_pages, pdf_page, pdf_size, pdf_part
