# What the Mac's clipboard holds: text, files that were copied in the Finder,
# and a picture or other media that was copied as data, like a screenshot.
#
#     files()   # ["/Users/sam/Desktop/plan.png"]: the files that ⌘C copied in the Finder
#     media()   # ("png", bytes) for a picture that was copied, or nothing
#     text()    # the text that was copied, or ""
#
# Each takes a clipboard to read, which is the Mac's own unless you give
# another. This file only works on macOS.

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const Object = Ptr{Cvoid}

"A test puts a clipboard of its own here, to leave the Mac's clipboard as it is"
const other = Ref{Object}(C_NULL)

"The clipboard to read: the Mac's own, or the one that a test named"
board() = begin
  other[] == C_NULL || return other[]
  Base.Libc.Libdl.dlopen(AppKit)
  msg(cls("NSPasteboard"), "generalPasteboard")
end

"A new clipboard that nothing else uses, for a test"
private_board() = (Base.Libc.Libdl.dlopen(AppKit); msg(cls("NSPasteboard"), "pasteboardWithUniqueName"))

"How many bytes or items `x` holds"
howmany(x::Object, name) = ccall((:objc_msgSend, libobjc), UInt, (Object, Object), x, sel(name))

"The text that the clipboard holds, or \"\""
text(pb::Object=board()) = begin
  Sys.isapple() || return ""
  with_pool(() -> jstring(msg(pb, "stringForType:", nsstring("public.utf8-plain-text"))))
end

"The files and folders that the clipboard holds, as paths: what ⌘C in the Finder copies"
files(pb::Object=board()) = begin
  out = String[]
  Sys.isapple() || return out
  with_pool() do
    items = msg(pb, "pasteboardItems")
    items == C_NULL && return out
    for i in 0:Int(howmany(items, "count"))-1
      item = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), items, sel("objectAtIndex:"), i)
      address = msg(item, "stringForType:", nsstring("public.file-url"))
      address == C_NULL && continue
      url = msg(cls("NSURL"), "URLWithString:", address)
      url == C_NULL && continue
      # The Finder can name a file by its number on the disk. This gives its path.
      url = msg(url, "filePathURL")
      url == C_NULL && continue
      path = jstring(msg(url, "path"))
      ispath(path) && push!(out, path)
    end
    out
  end
end

# The kinds of media that a clipboard can hold as data, by macOS's name for each, and the end
# of the name of a file of that kind. The first kind that the clipboard has is the one taken,
# so a picture that's there as a PNG and as a PDF is taken as a PNG.
const KINDS = ["public.png" => "png", "public.jpeg" => "jpg", "com.compuserve.gif" => "gif", "org.webmproject.webp" => "webp",
               "public.tiff" => "tiff", "com.adobe.pdf" => "pdf", "public.mpeg-4" => "mp4", "com.apple.quicktime-movie" => "mov",
               "public.mp3" => "mp3", "com.apple.m4a-audio" => "m4a", "com.microsoft.waveform-audio" => "wav"]

"The bytes of an NSData"
bytes(data::Object) = copy(unsafe_wrap(Array, Ptr{UInt8}(msg(data, "bytes")), Int(howmany(data, "length"))))

"A TIFF picture as the data of a PNG file, which is smaller and shows anywhere"
png(tiff::Object) = begin
  picture = msg(cls("NSBitmapImageRep"), "imageRepWithData:", tiff)
  picture == C_NULL && return C_NULL
  # 4 is NSBitmapImageFileTypePNG
  ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt, Object), picture, sel("representationUsingType:properties:"),
        4, msg(cls("NSDictionary"), "dictionary"))
end

"""
The picture, sound, video or PDF that the clipboard holds as data: the end of
the name of a file of its kind, like "png", and its bytes. Nothing if it holds
none. A screenshot that's copied is one of these.
"""
media(pb::Object=board()) = begin
  Sys.isapple() || return nothing
  with_pool() do
    for (kind, ext) in KINDS
      data = msg(pb, "dataForType:", nsstring(kind))
      data == C_NULL && continue
      if ext == "tiff"
        data = png(data)
        data == C_NULL && continue
        ext = "png"
      end
      howmany(data, "length") == 0 && continue
      return (ext, bytes(data))
    end
    nothing
  end
end
