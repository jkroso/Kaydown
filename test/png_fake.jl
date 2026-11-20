# A PNG file from its colours, for the tests that need pictures. `write_png`
# writes one with no library: the bytes aren't packed.

# --- a PNG file from its colours ---------------------------------------------------------

const CRC = [foldl((c, _) -> isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1, 1:8, init=UInt32(n)) for n in 0:255]
crc(bytes) = ~foldl((c, b) -> CRC[(c ⊻ b) & 0xff + 1] ⊻ (c >> 8), bytes, init=0xffffffff)
adler(bytes) = begin
  a, b = 1, 0
  for x in bytes
    a = (a + x) % 65521
    b = (b + a) % 65521
  end
  UInt32(b) << 16 | UInt32(a)
end
be(n) = reverse(reinterpret(UInt8, [UInt32(n)]))
chunk(kind, data) = UInt8[be(length(data)); codeunits(kind); data; be(crc(UInt8[codeunits(kind); data]))]

"Write a PNG file that's `w` pixels wide and `h` tall. `colour(x, y)` gives the red, green and blue of each pixel."
write_png(path, w, h, colour) = begin
  raw = UInt8[]
  for y in 1:h
    push!(raw, 0x00)
    for x in 1:w
      append!(raw, UInt8.(colour(x, y)))
    end
  end
  # The pixels go in as they are, in parts of no more than 65535 bytes
  packed = UInt8[0x78, 0x01]
  parts = collect(Iterators.partition(raw, 65535))
  for (k, part) in enumerate(parts)
    n = UInt16(length(part))
    append!(packed, UInt8[k == length(parts), n & 0xff, n >> 8, ~n & 0xff, ~n >> 8])
    append!(packed, part)
  end
  append!(packed, be(adler(raw)))
  mkpath(dirname(path))
  write(path, UInt8[0x89; codeunits("PNG\r\n"); 0x1a; 0x0a; chunk("IHDR", UInt8[be(w); be(h); 8; 2; 0; 0; 0]);
                    chunk("IDAT", packed); chunk("IEND", UInt8[])])
  path
end

const RED, GREEN, BLUE, SAND = (200, 40, 40), (40, 160, 70), (50, 90, 200), (210, 180, 120)
