# A video of YouTube that a page shows in an <iframe>. No player runs in this
# engine, so the frame shows the video's picture with its name and an arrow,
# and a click opens the video in a browser.
#
#     v = video("https://www.youtube.com/embed/kc9HwsxE1OY?start=10")
#     v.watch        # the address of the video's page, for a browser: "https://www.youtube.com/watch?v=kc9HwsxE1OY"
#     v.about        # the address where YouTube says the video's name and picture, as JSON
#     v.picture      # the address of the video's picture, or "" for a list of videos: only the JSON says the picture of a list
#     facts(bytes)   # the name and the address of the picture that the JSON at `v.about` says
#     sharper(a)     # the addresses of bigger pictures of the same video, the biggest first, and then `a`
#
# `video` gives nothing for any other address. This file asks the web for
# nothing: main.jl asks the page's `load` for the JSON and for the picture.

"`s` as it's written in an address: each character that means something there is written as % and its number"
escape(s::AbstractString) = join(c in 'a':'z' || c in 'A':'Z' || c in '0':'9' || c in "-._~" ? string(c) : join("%" * uppercase(string(x, base=16, pad=2)) for x in codeunits(string(c))) for c in s)

"""
What the address `src` of an <iframe> says of the video of YouTube that it
shows: one video, a list of videos, or a video of a list. Nothing for any
other address.
"""
video(src::AbstractString) = begin
  m = match(r"^(?:https?:)?//(?:www\.|m\.)?youtube(?:-nocookie)?\.com/embed/([^/?#]*)(?:\?([^#]*))?"i, strip(src))
  m === nothing && return nothing
  # A list with no video of its own is written as `videoseries`, or with no name at all
  id = m[1] == "videoseries" ? "" : String(m[1])
  list = ""
  for part in split(something(m[2], ""), '&')
    startswith(part, "list=") && (list = String(part[6:end]))
  end
  name(x) = occursin(r"^[\w-]+$", x)
  ((isempty(id) || name(id)) && (isempty(list) || name(list)) && !(isempty(id) && isempty(list))) || return nothing
  watch = isempty(id) ? "https://www.youtube.com/playlist?list=$list" : "https://www.youtube.com/watch?v=$id" * (isempty(list) ? "" : "&list=$list")
  (watch=watch, about="https://www.youtube.com/oembed?format=json&url=" * escape(watch), picture=isempty(id) ? "" : "https://i.ytimg.com/vi/$id/hqdefault.jpg")
end

"The text that JSON writes as `s` between its quotes: `\\u00e9` is é, and a new line is a space"
plain(s::AbstractString) = begin
  out = IOBuffer()
  chars = collect(s)
  hex(i) = i + 3 <= length(chars) ? tryparse(UInt32, String(chars[i:i+3]), base=16) : nothing
  i = 1
  while i <= length(chars)
    c = chars[i]
    if c == '\\' && i < length(chars)
      n = chars[i += 1]
      if n == 'u'
        code = hex(i + 1)
        code === nothing || (i += 4)
        # A character past U+FFFF is written as two halves
        if code !== nothing && 0xd800 <= code < 0xdc00 && i + 2 <= length(chars) && chars[i+1] == '\\' && chars[i+2] == 'u'
          low = hex(i + 3)
          low !== nothing && 0xdc00 <= low < 0xe000 && (code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00); i += 6)
        end
        code !== nothing && isvalid(Char, code) && print(out, Char(code))
      else
        print(out, n in ('n', 't', 'r') ? ' ' : n in ('b', 'f') ? "" : n)
      end
    else
      print(out, c)
    end
    i += 1
  end
  String(take!(out))
end

"The text of the field `name` of the JSON `json`, or \"\" when the JSON has no such field with text in it"
field(json::AbstractString, name::AbstractString) = begin
  m = match(Regex("\"" * name * "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""), json)
  m === nothing ? "" : plain(m[1])
end

"The name of a video and the address of its picture, as the JSON `bytes` that YouTube gives at `video(src).about` says: \"\" for what it doesn't say"
facts(bytes) = begin
  json = String(copy(Vector{UInt8}(bytes)))
  isvalid(json) || return ("", "")
  picture = field(json, "thumbnail_url")
  (field(json, "title"), startswith(picture, "https://") ? picture : "")
end

"""
The addresses to try for the picture at the address `picture`, the first
first. YouTube names a picture 480 px wide, which is blurred in a frame of
most pages. It has bigger ones of most videos, 1280 and 640 px wide, at
addresses that differ only in the file's name. A video that has none gives
no file there.
"""
sharper(picture::AbstractString) = begin
  m = match(r"^(https://i\.ytimg\.com/vi/[\w-]+/)hqdefault\.jpg$", picture)
  m === nothing ? [String(picture)] : [m[1] * "maxresdefault.jpg", m[1] * "sddefault.jpg", String(picture)]
end
