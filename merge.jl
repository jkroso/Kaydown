# Two versions of a text compared, and two sets of changes to one text put together.
# A text is its lines, as a document keeps them.
#
#     changes(["a", "b"], ["a", "c"])           # [(2:2, 2:2)]: line 2 of the old text became line 2 of the new
#     combine(base, mine, theirs)               # base with my changes and theirs
#     unified(["a", "b"], ["a", "c"])           # the changes the way `diff -u` shows them
#     follow(changes(old, new), 4)              # the line of `new` that line 4 of `old` became
#
# Kaydown uses these when a file changes on the disk while the document has
# changes that aren't saved, and to tell an agent what the user changed.

"A run of lines of the old text, and the run of lines of the new text that took its place. Either can be empty."
const Change = Tuple{UnitRange{Int},UnitRange{Int}}

# Past this many lines that differ, the two texts are taken to have nothing in common between
# their first difference and their last. It keeps the work, and the memory, small.
const MOST = 3000

"""
The places where `b` differs from `a`, first one first. Each is a run of lines
of `a` and the lines of `b` that took its place. `1:0` is no lines, before line 1.
"""
changes(a::AbstractVector{<:AbstractString}, b::AbstractVector{<:AbstractString})::Vector{Change} = begin
  n, m = length(a), length(b)
  # The lines that are the same at the start and at the end need no work
  head = 0
  while head < n && head < m && a[head+1] == b[head+1]
    head += 1
  end
  tail = 0
  while tail < n - head && tail < m - head && a[n-tail] == b[m-tail]
    tail += 1
  end
  (head == n && head == m) && return Change[]
  pairs = matches(view(a, head+1:n-tail), view(b, head+1:m-tail))
  out = Change[]
  i, j = head + 1, head + 1   # the next line of each text that hasn't been placed
  for (x, y) in pairs
    x, y = x + head, y + head
    (x > i || y > j) && push!(out, (i:x-1, j:y-1))
    i, j = x + 1, y + 1
  end
  (i <= n - tail || j <= m - tail) && push!(out, (i:n-tail, j:m-tail))
  out
end

"""
The lines of `a` and `b` that are the same line, as pairs of line numbers that
rise together: the longest such list there is. This is Myers' way of finding
it, which is quick when the texts differ in few lines.
"""
matches(a, b) = begin
  n, m = length(a), length(b)
  out = Tuple{Int,Int}[]
  (n == 0 || m == 0) && return out
  most = min(n + m, MOST)
  off = most + 2
  v = zeros(Int, 2most + 3)   # v[k + off] is how far along `a` the best path on diagonal k has got
  trace = Vector{Int}[]       # v as it was before each step, the part of it that the step can read
  found = -1
  for d in 0:most
    push!(trace, v[off-d-1:off+d+1])
    for k in -d:2:d
      x = (k == -d || (k != d && v[k-1+off] < v[k+1+off])) ? v[k+1+off] : v[k-1+off] + 1
      y = x - k
      while x < n && y < m && a[x+1] == b[y+1]
        x += 1; y += 1
      end
      v[k+off] = x
      if x >= n && y >= m
        found = d
        break
      end
    end
    found >= 0 && break
  end
  found < 0 && return out   # too different to compare
  # Walk back from the end of both texts to the start, a step at a time
  x, y = n, m
  for d in found:-1:1
    was = trace[d+1]            # diagonal k is at was[k + d + 2]
    k = x - y
    from = (k == -d || (k != d && was[k-1+d+2] < was[k+1+d+2])) ? k + 1 : k - 1
    x0 = was[from+d+2]
    y0 = x0 - from
    while x > x0 && y > y0
      push!(out, (x, y))
      x -= 1; y -= 1
    end
    x, y = x0, y0
  end
  while x > 0 && y > 0
    push!(out, (x, y))
    x -= 1; y -= 1
  end
  reverse!(out)
end

"""
The text that has my changes to `base` and theirs. Where both changed the same
lines, it keeps one side's lines: mine, or theirs with `keep=:theirs`. Lines
that one side added beside lines that the other side changed are both kept.
"""
combine(base, mine, theirs; keep::Symbol=:mine) = begin
  cm, ct = changes(base, mine), changes(base, theirs)
  out = String[]
  i = 1          # the next line of base to place
  im = it = 1    # the next change of each side
  dm = dt = 0    # how many lines longer each side is than base, up to line i
  # Where a change starts in base, and the line after its last. They're equal when it only adds lines.
  from(c) = first(c[1])
  upto(c) = last(c[1]) + 1
  # Of two changes that start at the same line, one that only adds lines goes first
  order(c) = (from(c), from(c) == upto(c) ? 0 : 1)
  while im <= length(cm) || it <= length(ct)
    # The change that comes first starts a group. A change of either side that
    # shares a line of base with the group joins it, and so do lines that both
    # sides added at the same place.
    mine_first = it > length(ct) || (im <= length(cm) && order(cm[im]) <= order(ct[it]))
    c = mine_first ? cm[im] : ct[it]
    lo, hi = from(c), upto(c)
    jm, jt = im + mine_first, it + !mine_first
    joins(c) = from(c) < hi || (from(c) == lo == hi && upto(c) == hi)
    while true
      if jm <= length(cm) && joins(cm[jm])
        hi = max(hi, upto(cm[jm])); jm += 1
      elseif jt <= length(ct) && joins(ct[jt])
        hi = max(hi, upto(ct[jt])); jt += 1
      else
        break
      end
    end
    append!(out, @view base[i:lo-1])
    # Each side's lines for lines lo to hi - 1 of base
    grown(cs, a, b) = sum(length(c[2]) - length(c[1]) for c in @view(cs[a:b-1]); init=0)
    gm, gt = grown(cm, im, jm), grown(ct, it, jt)
    my = @view mine[lo+dm:hi-1+dm+gm]
    their = @view theirs[lo+dt:hi-1+dt+gt]
    append!(out, jt == it ? my : jm == im ? their : keep == :theirs ? their : my)
    dm += gm; dt += gt
    im, it = jm, jt
    i = hi
  end
  append!(out, @view base[i:end])
  out
end

"The line of the new text that line `i` of the old text became. `cs` is `changes(old, new)`."
follow(cs::Vector{Change}, i::Int) = begin
  moved = 0
  for (a, b) in cs
    i < first(a) && break
    # A line that was changed goes to the same place in the lines that took its place
    i <= last(a) && return isempty(b) ? max(first(b) - 1, 1) : min(first(b) + i - first(a), last(b))
    moved += length(b) - length(a)
  end
  i + moved
end

"""
The changes from `a` to `b` as text, the way `diff -u` shows them: each group
starts with a line like `@@ -3,4 +3,5 @@`, a line of `a` that's gone starts
with `-`, a line of `b` that's new starts with `+`, and `context` lines that
didn't change show around them. Empty when the texts are the same.
"""
unified(a, b; context::Int=3) = begin
  cs = changes(a, b)
  io = IOBuffer()
  k = 1
  while k <= length(cs)
    # Changes that are close together show as one group
    last_k = k
    while last_k < length(cs) && first(cs[last_k+1][1]) - last(cs[last_k][1]) - 1 <= 2context
      last_k += 1
    end
    alo = max(first(cs[k][1]) - context, 1)
    ahi = min(last(cs[last_k][1]) + context, length(a))
    # The same lines show around the changes in both texts
    blo = first(cs[k][2]) - (first(cs[k][1]) - alo)
    bhi = last(cs[last_k][2]) + (ahi - last(cs[last_k][1]))
    span(lo, hi) = hi < lo ? "$(lo - 1),0" : "$lo,$(hi - lo + 1)"
    println(io, "@@ -", span(alo, ahi), " +", span(blo, bhi), " @@")
    i = alo
    for (x, y) in @view cs[k:last_k]
      foreach(l -> println(io, " ", l), @view a[i:first(x)-1])
      foreach(l -> println(io, "-", l), @view a[x])
      foreach(l -> println(io, "+", l), @view b[y])
      i = last(x) + 1
    end
    foreach(l -> println(io, " ", l), @view a[i:ahi])
    k = last_k + 1
  end
  String(take!(io))
end
