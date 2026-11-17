# A pretend maker of map pictures, for map_test.jl and map_view_test.jl. It
# takes the place of the program that map.jl runs, so the tests use neither
# MapKit nor the network. `helper` is a function for `Maps.HELPER`: it writes
# a picture that it draws itself, with streets, parks and a red dot on the
# place, and the latitude, the longitude and an address. The streets are in
# the same places of the world in every picture, as on a real map, so a
# picture with another middle shows them moved. `opener` is a function for
# `Maps.OPENER`: it opens nothing, and notes what it was asked to open.
#
# The place says what the helper does:
#
# - A place with "nowhere" in it isn't found, as Apple's maps find no such place.
# - A place with "offline" in it fails, as with no network.
# - A place with "slow" in it takes as long as `SLOW` seconds. So does every place while `slow[]` is true.
# - A place with "broken" in it gets a file that isn't a picture.
# - `-37.7701, 144.9610` and any other latitude and longitude gets the address "1 Found Street, Brunswick VIC 3056, Australia".
# - Any other place gets itself, with ", Australia" after it, as its address, and is at `ADDRESS`.

@use "../map" => Maps

"Each picture that was asked for: the place, the zoom, how wide and how tall it is in px, whether it's dark, and its middle"
const calls = NamedTuple[]
"The latitude and the longitude of every address"
const ADDRESS = (-37.769417, 144.940514)
"Each address that the Maps app was asked to open"
const opened = String[]
"How many seconds a slow place takes"
const SLOW = 0.4
"True while every place is slow"
const slow = Ref(false)

const CRC = [foldl((c, _) -> isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1, 1:8, init=UInt32(n)) for n in 0:255]
crc(bytes) = begin
  c = 0xffffffff
  for b in bytes
    c = CRC[((c ⊻ b) & 0xff) + 1] ⊻ (c >> 8)
  end
  ~c
end
adler(bytes) = begin
  a, b = UInt32(1), UInt32(0)
  for x in bytes
    a = (a + x) % 65521
    b = (b + a) % 65521
  end
  (b << 16) | a
end
be32(n) = (n = UInt32(n); UInt8[n >> 24, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff])
chunk(kind, data) = (body = UInt8[codeunits(kind); data]; UInt8[be32(length(data)); body; be32(crc(body))])

"The bytes of a PNG file that's `w` by `h` pixels. `colour(x, y)` gives the red, the green and the blue of each pixel."
png(colour, w, h) = begin
  raw = zeros(UInt8, h * (3w + 1))   # each row starts with a 0, which says that the row is written as it is
  for y in 0:h-1, x in 0:w-1
    at = y * (3w + 1) + 3x + 1
    raw[at+1], raw[at+2], raw[at+3] = colour(x, y)
  end
  # The pixels go in blocks that aren't made smaller, which a reader of PNG files takes as well as any
  packed = UInt8[0x78, 0x01]
  for from in 1:65535:length(raw)
    to = min(from + 65534, length(raw))
    n = UInt16(to - from + 1)
    append!(packed, UInt8[to == length(raw) ? 0x01 : 0x00, n % UInt8, (n >> 8) % UInt8, ~n % UInt8, (~n >> 8) % UInt8])
    append!(packed, raw[from:to])
  end
  append!(packed, be32(adler(raw)))
  UInt8[0x89; codeunits("PNG\r\n"); 0x1a; 0x0a; chunk("IHDR", UInt8[be32(w); be32(h); 8; 2; 0; 0; 0]); chunk("IDAT", packed); chunk("IEND", UInt8[])]
end

"""
A picture like a map, `wide` px by `tall` px with two pixels to the px. `centre`
is in its middle, and a red dot is on `pin`. The streets and the parks are
where they are on the map of the world at `zoom`.
"""
map_picture(wide, tall, dark, zoom, centre, pin) = begin
  land, street, park = dark ? ((52, 56, 66), (84, 90, 104), (40, 84, 64)) : ((236, 232, 220), (255, 255, 255), (178, 216, 160))
  left, top = Maps.spot(centre, zoom) .- (wide / 2, tall / 2)
  dot = Maps.point(pin, centre, zoom, wide, tall)
  png(2wide, 2tall) do x, y
    (x / 2 - dot[1])^2 + (y / 2 - dot[2])^2 <= 8^2 && return (232, 66, 54)
    wx, wy = left + x / 2, top + y / 2
    (mod(wx, 90) < 9 || mod(wy, 70) < 9) && return street
    (100 <= mod(wx, 630) < 260 && 80 <= mod(wy, 490) < 200) ? park : land
  end
end

const pictures = Dict{Any,Vector{UInt8}}()

helper(place, zoom, wide, tall, dark, centre, file, out, err) = begin
  push!(calls, (place=place, zoom=zoom, wide=wide, tall=tall, dark=dark, centre=centre))
  has(word) = occursin(word, lowercase(place))
  if has("nowhere")
    write(err, "error: Apple's maps found no such place\n")
    return 2
  elseif has("offline")
    write(err, "error: The Internet connection appears to be offline.\n")
    return 1
  end
  given = Maps.coordinates(place)
  pin = something(given, ADDRESS)
  middle = something(centre, pin)
  write(file, has("broken") ? b"not a picture" : get!(() -> map_picture(wide, tall, dark, zoom, middle, pin), pictures, (wide, tall, dark, zoom, middle, pin)))
  write(out, given === nothing ? "$(ADDRESS[1])\t$(ADDRESS[2])\t$place, Australia\n" : "$(pin[1])\t$(pin[2])\t1 Found Street, Brunswick VIC 3056, Australia\n")
  has("slow") || slow[] ? run(`sleep $SLOW`, wait=false) : 0
end

opener(url) = (push!(opened, url); nothing)
