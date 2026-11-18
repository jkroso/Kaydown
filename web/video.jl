# The pictures of a video file. macOS reads the file (AVFoundation), so this
# shows what QuickTime plays: MP4, MOV and M4V. It only works on macOS.
#
#     v = video(bytes, "walk.mp4")    # or nothing, for a file that macOS can't read
#     v.wide, v.high                  # how big its pictures are, in pixels
#     v.long                          # how many seconds it plays for
#     f = frame(v, 2.5)               # the picture that it shows 2.5 seconds in, or nothing
#     f.image                         # Skia's picture of it
#
# A picture is read when it's asked for, which takes a few ms: nothing plays
# in the background, and no sound is made. Hold the `Frame` for as long as its
# picture is drawn: Skia's picture is freed when Julia frees the frame.
#
# Which <video> elements of a page play is kept here too, by element:
#
#     p = play(element)               # how far the element's video has got: made when it's first asked for
#     spot(p, 12.5)                   # where in the video it is 12.5 s after the page was first shown, and whether it plays then
#     play!(p, 12.5), pause!(p, 12.5), seek!(p, 12.5, 3.0)
#
# A video with `autoplay` plays from when its page is first shown.
#
# A picture file that moves is read here too: a GIF, and a PNG or a WebP with
# several pictures in it. macOS reads those as well (ImageIO).
#
#     r = reel(bytes)                 # or nothing, for a file with one picture or one that can't be read
#     r.wide, r.high, r.long          # how big its pictures are, and how many seconds one run of them takes
#     r.runs                          # how many times it runs: Inf for one that never stops
#     frame(r, 2.5)                   # the picture that it shows 2.5 seconds after it started

@use Skia

const OBJC = "/usr/lib/libobjc.A.dylib"
const AVFOUNDATION = "/System/Library/Frameworks/AVFoundation.framework/AVFoundation"
const COREMEDIA = "/System/Library/Frameworks/CoreMedia.framework/CoreMedia"
const GRAPHICS = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
const FOUNDATION = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

const Object = Ptr{Cvoid}

"A time in a file, the way macOS counts it: `value ÷ timescale` seconds"
struct CMTime
  value::Int64
  timescale::Int32
  flags::UInt32
  epoch::Int64
end

struct CGSize
  wide::Float64
  high::Float64
end

struct CGRect
  x::Float64
  y::Float64
  wide::Float64
  high::Float64
end

class(name) = ccall((:objc_getClass, OBJC), Object, (Cstring,), name)
selector(name) = ccall((:sel_registerName, OBJC), Object, (Cstring,), name)
send(to, name) = ccall((:objc_msgSend, OBJC), Object, (Object, Object), to, selector(name))
send(to, name, with::Object) = ccall((:objc_msgSend, OBJC), Object, (Object, Object, Object), to, selector(name), with)
send(to, name, a::Object, b::Object) = ccall((:objc_msgSend, OBJC), Object, (Object, Object, Object, Object), to, selector(name), a, b)
cmtime(seconds) = ccall((:CMTimeMakeWithSeconds, COREMEDIA), CMTime, (Float64, Int32), seconds, 600)

"One picture of a video. Skia's picture is freed when Julia frees this."
mutable struct Frame
  image::Ptr{Cvoid}
  wide::Int
  high::Int
  Frame(image, wide, high) = finalizer(f -> Skia.sk_image_unref(f.image), new(image, wide, high))
end

"A video file that macOS reads"
mutable struct Video
  asset::Object         # macOS's AVURLAsset, or C_NULL once it's closed
  maker::Object         # its AVAssetImageGenerator, which gives the picture at a time
  file::String          # the file that the bytes were written to, which goes when the video does
  wide::Int
  high::Int
  long::Float64
  at::Float64           # the time of the picture that was last asked for
  shown::Union{Frame,Nothing}
end

# No page shows a video bigger than this many pixels across or down
const MOST = 2048

"What a video file's name ends with, when macOS reads such a file"
ending(name) = begin
  m = match(r"\.(mp4|m4v|mov|qt|3gp|3g2)(?:[?#].*)?$"i, name)
  m === nothing ? ".mp4" : "." * lowercase(m[1])
end

"""
The video that `bytes` are the file of, or nothing when macOS can't read it.
`name` is the file's name or its address: what it ends with says what kind
of file it is. macOS reads a video from a file, so the bytes are written to
one, which is deleted when Julia frees the video.
"""
video(bytes::Vector{UInt8}, name::AbstractString="") = begin
  (Sys.isapple() && !isempty(bytes)) || return nothing
  file = tempname() * ending(name)
  write(file, bytes)
  v = video(file)
  v === nothing ? (rm(file; force=true); nothing) : (v.file = file; v)
end

"The video in the file at `path`, or nothing when macOS can't read it"
video(path::AbstractString) = begin
  (Sys.isapple() && isfile(path)) || return nothing
  # The classes of AVFoundation only have their names once it's loaded
  Base.Libc.Libdl.dlopen(AVFOUNDATION)
  text = ccall((:CFStringCreateWithCString, FOUNDATION), Object, (Object, Cstring, UInt32), C_NULL, abspath(path), 0x08000100)
  url = send(send(class("NSURL"), "alloc"), "initFileURLWithPath:", text)
  ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), text)
  asset = send(send(class("AVURLAsset"), "alloc"), "initWithURL:options:", url, C_NULL)
  send(url, "release")
  asset == C_NULL && return nothing
  maker = send(send(class("AVAssetImageGenerator"), "alloc"), "initWithAsset:", asset)
  # A phone's video is stored on its side: this turns each picture upright
  ccall((:objc_msgSend, OBJC), Cvoid, (Object, Object, Bool), maker, selector("setAppliesPreferredTrackTransform:"), true)
  # The picture of the time that's asked for, and not the nearest one that's quick to read
  for name in ("setRequestedTimeToleranceBefore:", "setRequestedTimeToleranceAfter:")
    ccall((:objc_msgSend, OBJC), Cvoid, (Object, Object, CMTime), maker, selector(name), cmtime(0.0))
  end
  ccall((:objc_msgSend, OBJC), Cvoid, (Object, Object, CGSize), maker, selector("setMaximumSize:"), CGSize(MOST, MOST))
  long = ccall((:CMTimeGetSeconds, COREMEDIA), Float64, (CMTime,), ccall((:objc_msgSend, OBJC), CMTime, (Object, Object), asset, selector("duration")))
  v = finalizer(close, Video(asset, maker, "", 0, 0, isfinite(long) ? max(0.0, long) : 0.0, NaN, nothing))
  first = frame(v, 0.0)
  first === nothing && (close(v); return nothing)
  v.wide, v.high = first.wide, first.high
  v
end

Base.close(v::Video) = begin
  v.asset == C_NULL && return
  send(v.maker, "release")
  send(v.asset, "release")
  v.asset = v.maker = C_NULL
  v.shown = nothing
  isempty(v.file) || rm(v.file; force=true)
  nothing
end

"""
The picture that the video shows `seconds` after its start, or nothing when
macOS can't read one. A time after its end gives its last picture. The
picture that was asked for last is kept, so asking again costs nothing.
"""
frame(v::Video, seconds::Real) = begin
  v.asset == C_NULL && return nothing
  # A little before the end, since the last moment of a file often has no picture
  t = clamp(Float64(seconds), 0.0, max(0.0, v.long - 0.05))
  v.shown !== nothing && v.at == t && return v.shown
  made = ccall((:objc_msgSend, OBJC), Object, (Object, Object, CMTime, Ptr{Cvoid}, Ptr{Cvoid}), v.maker, selector("copyCGImageAtTime:actualTime:error:"), cmtime(t), C_NULL, C_NULL)
  made == C_NULL && return nothing
  shown = picture(made)
  ccall((:CGImageRelease, GRAPHICS), Cvoid, (Object,), made)
  shown === nothing && return nothing
  v.at = t
  v.shown = shown
end

"macOS's picture `made` as a `Frame`, or nothing when it has no pixels"
picture(made::Object) = begin
  w = Int(ccall((:CGImageGetWidth, GRAPHICS), Csize_t, (Object,), made))
  h = Int(ccall((:CGImageGetHeight, GRAPHICS), Csize_t, (Object,), made))
  image = C_NULL
  if w > 0 && h > 0
    # macOS draws its picture into pixels of the kind that Skia takes: red, green, blue, then how solid, each a byte
    pixels = zeros(UInt8, 4 * w * h)
    space = ccall((:CGColorSpaceCreateDeviceRGB, GRAPHICS), Object, ())
    into = ccall((:CGBitmapContextCreate, GRAPHICS), Object, (Ptr{UInt8}, Csize_t, Csize_t, Csize_t, Csize_t, Object, UInt32), pixels, w, h, 8, 4w, space, 1)
    if into != C_NULL
      ccall((:CGContextDrawImage, GRAPHICS), Cvoid, (Object, CGRect, Object), into, CGRect(0, 0, w, h), made)
      ccall((:CGContextRelease, GRAPHICS), Cvoid, (Object,), into)
      info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, w, h))
      data = Skia.sk_data_new_with_copy(pixels, Csize_t(length(pixels)))
      image = GC.@preserve info Skia.sk_image_new_raster_data(pointer_from_objref(info), data, Csize_t(4w))
      Skia.sk_data_unref(data)
    end
    ccall((:CGColorSpaceRelease, GRAPHICS), Cvoid, (Object,), space)
  end
  image == C_NULL ? nothing : Frame(Ptr{Cvoid}(image), w, h)
end

# --- which videos play --------------------------------------------------------------------

"How far the video of a <video> element has got"
mutable struct Play
  since::Float64    # how many seconds after its page was first shown it was last started, stopped or moved
  was::Float64      # how far through the video it was then, in seconds, or NaN for its start
  going::Bool       # it plays since then
  from::Float64     # where the video starts, and how long its file is: the layout says, once the file is read
  long::Float64
end

# A page's elements are freed with the page, and what's kept of them here goes then
const PLAYS = WeakKeyDict{Any,Play}()

"How far the video of the <video> element `e` has got. One with `autoplay` plays from when its page is first shown."
play(e) = get!(() -> Play(0.0, NaN, haskey(e.attrs, "autoplay"), 0.0, Inf), PLAYS, e)

"True when the element's video was never started, stopped or moved: one that waits shows its poster then"
untouched(p::Play) = isnan(p.was) && !p.going

"Where in its video `p` is, `at` seconds after its page was first shown, and whether it plays then. `again` is for a video that starts again at its end."
spot(p::Play, at, again::Bool=false) = begin
  was = isnan(p.was) ? p.from : p.was
  (p.going && p.long > p.from) || return (min(was, p.long), false)
  t = was + max(0.0, at - p.since)
  again && isfinite(p.long) ? (p.from + mod(t - p.from, p.long - p.from), true) : (min(t, p.long), t < p.long)
end

"Start the video, `at` seconds after its page was first shown. One that's at its end starts again."
play!(p::Play, at, again::Bool=false) = begin
  t, going = spot(p, at, again)
  going || ((p.since, p.was, p.going) = (Float64(at), t >= p.long ? p.from : t, true))
  p
end

"Stop the video where it is"
pause!(p::Play, at, again::Bool=false) = begin
  t, _ = spot(p, at, again)
  p.since, p.was, p.going = Float64(at), t, false
  p
end

"Go to `t` seconds from the start of the video"
seek!(p::Play, at, t, again::Bool=false) = begin
  _, going = spot(p, at, again)
  p.since, p.was, p.going = Float64(at), clamp(Float64(t), 0.0, p.long), going || (p.going && t < p.long)
  p
end

# --- pictures that move -------------------------------------------------------------------

const IMAGEIO = "/System/Library/Frameworks/ImageIO.framework/ImageIO"

"A picture file with several pictures that show one after the other: a GIF, or a PNG or a WebP that moves"
mutable struct Reel
  source::Object                        # macOS's CGImageSource, or C_NULL once it's closed
  wide::Int
  high::Int
  starts::Vector{Float64}               # when each picture starts to show, in seconds from the start of a run
  long::Float64                         # how many seconds one run takes
  runs::Float64                         # how many times it runs: Inf for one that never stops
  first::Frame                          # its first picture, which shows where nothing moves
  frames::Vector{Union{Frame,Nothing}}  # the pictures that are read and kept
  room::Int                             # how many bytes the kept pictures take
end

# The pictures of one file are kept up to this many bytes. Past that, a picture is read again each time it shows.
const KEPT = 48_000_000

"""
True when `bytes` may be a picture file that moves: a GIF, a PNG with the
part that says how its pictures follow each other, or a WebP that says it
moves. It's a quick look at the start of the file, so that macOS is asked
only for such a file.
"""
moves(bytes::Vector{UInt8}) = begin
  n = length(bytes)
  n > 12 || return false
  bytes[1:4] == b"GIF8" && return true
  starts(at, text) = at + length(text) - 1 <= n && view(bytes, at:at+length(text)-1) == codeunits(text)
  # In a PNG that moves, `acTL` comes before the first pixels. In a WebP, `ANIM` comes near the start.
  bytes[1:4] == UInt8[0x89, 0x50, 0x4e, 0x47] && return any(i -> starts(i, "acTL"), 1:min(n - 4, 4096))
  starts(1, "RIFF") && starts(9, "WEBP") && return any(i -> starts(i, "ANIM"), 13:min(n - 4, 256))
  false
end

"One of ImageIO's named values, or C_NULL where this macOS has none of that name"
named(name::Symbol) = begin
  at = Base.Libc.Libdl.dlsym(Base.Libc.Libdl.dlopen(IMAGEIO), name; throw_error=false)
  at === nothing ? C_NULL : unsafe_load(Ptr{Object}(at))
end

"The number under `key` in one of macOS's dictionaries, or nothing"
number(dict::Object, key::Object) = begin
  (dict == C_NULL || key == C_NULL) && return nothing
  found = ccall((:CFDictionaryGetValue, FOUNDATION), Object, (Object, Object), dict, key)
  found == C_NULL && return nothing
  out = Ref(0.0)
  ccall((:CFNumberGetValue, FOUNDATION), Bool, (Object, Clong, Ref{Float64}), found, 13, out) ? out[] : nothing
end

# For each kind of file: the names that ImageIO keeps its part of a picture's facts under, how long the picture shows, and how many times the file runs
const KINDS = ((:kCGImagePropertyGIFDictionary, :kCGImagePropertyGIFUnclampedDelayTime, :kCGImagePropertyGIFDelayTime, :kCGImagePropertyGIFLoopCount),
               (:kCGImagePropertyPNGDictionary, :kCGImagePropertyAPNGUnclampedDelayTime, :kCGImagePropertyAPNGDelayTime, :kCGImagePropertyAPNGLoopCount),
               (:kCGImagePropertyWebPDictionary, :kCGImagePropertyWebPUnclampedDelayTime, :kCGImagePropertyWebPDelayTime, :kCGImagePropertyWebPLoopCount))

"What the facts `facts` of a picture, or of a file, say under the name `which` of the names in `KINDS`: 2 and 3 for how long a picture shows, 4 for how many times the file runs"
fact(facts::Object, which) = begin
  facts == C_NULL && return nothing
  for kind in KINDS
    part = ccall((:CFDictionaryGetValue, FOUNDATION), Object, (Object, Object), facts, named(kind[1]))
    part == C_NULL && continue
    for i in which
      found = number(part, named(kind[i]))
      found === nothing || return found
    end
  end
  nothing
end

"""
The pictures of the file `bytes`, when it's a picture file that moves, or
nothing: for a file with one picture, and for one that macOS can't read.
"""
reel(bytes::Vector{UInt8}) = begin
  (Sys.isapple() && moves(bytes)) || return nothing
  data = ccall((:CFDataCreate, FOUNDATION), Object, (Object, Ptr{UInt8}, Clong), C_NULL, bytes, length(bytes))
  source = ccall((:CGImageSourceCreateWithData, IMAGEIO), Object, (Object, Object), data, C_NULL)
  ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), data)
  source == C_NULL && return nothing
  n = Int(ccall((:CGImageSourceGetCount, IMAGEIO), Csize_t, (Object,), source))
  made = n > 1 ? ccall((:CGImageSourceCreateImageAtIndex, IMAGEIO), Object, (Object, Csize_t, Object), source, 0, C_NULL) : C_NULL
  first = made == C_NULL ? nothing : picture(made)
  made == C_NULL || ccall((:CGImageRelease, GRAPHICS), Cvoid, (Object,), made)
  first === nothing && (ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), source); return nothing)
  starts, at = Float64[], 0.0
  for i in 0:n-1
    facts = ccall((:CGImageSourceCopyPropertiesAtIndex, IMAGEIO), Object, (Object, Csize_t, Object), source, i, C_NULL)
    shows = something(fact(facts, (2, 3)), 0.1)
    facts == C_NULL || ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), facts)
    push!(starts, at)
    # A picture that says it shows for next to no time shows for a tenth of a second, as in a browser
    at += shows <= 0.011 ? 0.1 : shows
  end
  facts = ccall((:CGImageSourceCopyProperties, IMAGEIO), Object, (Object, Object), source, C_NULL)
  # A file that says nothing of it runs once. One that says 0 never stops.
  runs = something(fact(facts, (4,)), 1.0)
  facts == C_NULL || ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), facts)
  kept = Vector{Union{Frame,Nothing}}(nothing, n)
  kept[1] = first
  finalizer(close, Reel(source, first.wide, first.high, starts, at, runs <= 0 ? Inf : runs, first, kept, 4 * first.wide * first.high))
end

Base.close(r::Reel) = begin
  r.source == C_NULL && return
  ccall((:CFRelease, FOUNDATION), Cvoid, (Object,), r.source)
  r.source = C_NULL
  nothing
end

"When the file stops moving, in seconds after it started: Inf for one that never stops"
stops(r::Reel) = r.long * r.runs

"When the file next shows another picture, in seconds after it started, for a time `seconds` after it started: Inf for one that has stopped"
after(r::Reel, seconds::Real) = begin
  t = max(0.0, Float64(seconds))
  (r.long <= 0 || t >= stops(r)) && return Inf
  run, within = fld(t, r.long), mod(t, r.long)
  i = searchsortedlast(r.starts, within)
  run * r.long + (i < length(r.starts) ? r.starts[i+1] : r.long)
end

"The picture that the file shows `seconds` after it started. One that has stopped shows its last picture."
frame(r::Reel, seconds::Real) = begin
  t = Float64(seconds)
  i = t <= 0 || r.long <= 0 ? 1 : t >= stops(r) ? length(r.starts) : searchsortedlast(r.starts, mod(t, r.long))
  kept = r.frames[i]
  (kept !== nothing || r.source == C_NULL) && return something(kept, r.first)
  made = ccall((:CGImageSourceCreateImageAtIndex, IMAGEIO), Object, (Object, Csize_t, Object), r.source, i - 1, C_NULL)
  made == C_NULL && return r.first
  shown = picture(made)
  ccall((:CGImageRelease, GRAPHICS), Cvoid, (Object,), made)
  shown === nothing && return r.first
  size = 4 * shown.wide * shown.high
  r.room + size <= KEPT && (r.frames[i] = shown; r.room += size)
  shown
end
