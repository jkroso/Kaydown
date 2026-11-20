# The bytes of a .DS_Store file, as the Finder writes one in the Trash, for the
# tests of the Trash. `store` makes a file with one node of records.

"The bytes of a .DS_Store file with one node that holds `recs`, each a file's name, four letters and a text"
store(recs) = begin
  be(n) = reverse(reinterpret(UInt8, [UInt32(n)]))
  text(s) = (u = transcode(UInt16, s); [be(length(u)); vcat([[UInt8(c >> 8), UInt8(c & 0xff)] for c in u]...)])
  node = [be(0); be(length(recs)); vcat([[text(file); codeunits(id); codeunits("ustr"); text(value)] for (file, id, value) in recs]...)]
  tree = [be(2); be(0); be(length(recs)); be(1); be(0x1000)]
  # Three blocks: the list of the blocks at 8192, the tree's own block at 32, and its one node at 4096.
  # An address has the block's size in its last five bits, as a power of two.
  addresses = [8192 | 11, 32 | 5, 4096 | 12]
  info = [be(3); be(0); vcat(be.(addresses)...); zeros(UInt8, 4 * 253); be(1); UInt8(4); codeunits("DSDB"); be(1)]
  b = zeros(UInt8, 4 + 8192 + 2048)
  b[1:4] = be(1)
  b[5:8] = codeunits("Bud1")
  b[9:20] = [be(8192); be(2048); be(8192)]
  put(at, bytes) = (b[at+5:at+4+length(bytes)] = bytes)   # each place is counted from the fifth byte
  put(32, tree); put(4096, node); put(8192, info)
  b
end
