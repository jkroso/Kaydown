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
  ccall((:CGImageRelease, GRAPHICS), Cvoid, (Object,), made)
  image == C_NULL && return nothing
  v.at = t
  v.shown = Frame(Ptr{Cvoid}(image), w, h)
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
