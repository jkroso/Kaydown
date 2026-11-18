# Changes to files, for you to accept or reject one at a time. In a document
# they're a code block in the language `changes`, which holds a diff as `git
# diff` and `diff -u` write one:
#
#     ```changes
#     --- a/src/app.js
#     +++ b/src/app.js
#     @@ -10,4 +10,5 @@ function start() {
#        const a = 1
#     -  const b = 2
#     +  const b = 3
#     +  const c = 4
#        return a
#     @@ -30 +31 @@ [accepted]
#     -  stop()
#     +  stop(now)
#     ```
#
# A line that starts with `@@` starts a change. The lines under it are the
# file's lines there: one that starts with `-` goes, one that starts with `+`
# comes, and one that starts with a space stays. `+++` names the file.
#
# Your choice is written at the end of the change's `@@` line: `[accepted]` or
# `[rejected]`. What you say about a line is written at the end of the block,
# in two lines that start with `#`. The first says which change and which of
# its lines you mean, and has that line after it. The second has your words:
#
#     # Comment on change 1, line 3: +  const b = 3
#     # Why 3?
#
# `git apply` reads past lines at the end of a diff that aren't part of it, so
# the block is still a diff that `git apply` reads. Between two changes of
# one file such lines would stop it, so they're never written there. An agent
# writes the block, and reads your choices and your comments in the lines that
# you changed. Ladder changes no file but the page.
#
# This file reads those lines and writes your choices. It also says which
# line that comes is a new version of which line that goes, and which of their
# words are different, so the page can mark those words and put the two lines
# side by side. It draws nothing.

"The language of a code block that holds changes"
const CHANGES = "changes"

"One line of a change. `sign` is `+`, `-` or a space. `old` and `new` are the line's numbers in the file before and after, or 0."
struct Row
  sign::Char
  text::String
  old::Int
  new::Int
end

"One change: some lines of a file that go, and the lines that come in their place"
mutable struct Hunk
  file::String        # the file that it changes, or ""
  at::Int             # the line of the block that its @@ line is on, or 0 when it has none
  head::String        # its @@ line, without your choice
  about::String       # what its @@ line says after the numbers, like the function that the lines are in
  rows::Vector{Row}
  first::Int          # the line of the block that its first row is on
  state::Symbol       # :open, :accepted or :rejected
end

mutable struct Changes
  lines::Vector{String}                 # the lines of the block, as they were read
  hunks::Vector{Hunk}
  notes::Dict{Tuple{Int,Int},String}    # what you said about a line: the change that it's in, and which of the change's lines it is
  said::BitSet                          # the lines of the block that hold what you said
end

Changes(lines, hunks) = Changes(lines, hunks, Dict{Tuple{Int,Int},String}(), BitSet())

const HEAD = r"^@@\s*(?:-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s*)?(?:@@)?\s*(.*)$"
const MARK = r"\s*\[(accepted|rejected)\]\s*$"
const NOTE = r"^# Comment on change (\d+), line (\d+):"

"The name of the file in a `---` or `+++` line, or \"\" for /dev/null"
filename(line::AbstractString) = begin
  name = strip(replace(chop(line, head=3, tail=0), r"\t.*$" => ""))
  name == "/dev/null" ? "" : String(replace(name, r"^[ab]/" => ""))
end

"Read changes from the lines of their block"
changes(lines) = begin
  c = Changes(String[String(l) for l in lines], Hunk[])
  n = length(c.lines)
  # What you said about a line: a line that says which line, then lines of words
  i = 1
  while i <= n
    m = match(NOTE, c.lines[i])
    m === nothing && (i += 1; continue)
    push!(c.said, i)
    words = String[]
    i += 1
    while i <= n && startswith(c.lines[i], "#") && !occursin(NOTE, c.lines[i])
      push!(words, String(chop(c.lines[i], head=startswith(c.lines[i], "# ") ? 2 : 1, tail=0)))
      push!(c.said, i)
      i += 1
    end
    text = join(words, " ")
    isempty(strip(text)) || (c.notes[(parse(Int, m[1]), parse(Int, m[2]))] = text)
  end
  file = ""
  i = 1
  while i <= n
    line = c.lines[i]
    if startswith(line, "--- ") && i < n && startswith(c.lines[i+1], "+++ ")
      # A file that's deleted has its name in the first of the two lines only
      file = something(filter(!isempty, [filename(c.lines[i+1]), filename(line)])..., "")
      i += 2
      continue
    end
    m = startswith(line, "@@") ? match(HEAD, line) : nothing
    bare = m === nothing && !isempty(line) && line[1] in ('+', '-')   # a change with no @@ line
    if m === nothing && !bare
      i += 1
      continue
    end
    state, about, head = :open, "", ""
    old = new = 0
    left = nothing   # how many lines of the old file and of the new file are still to come, when the @@ line says
    if m !== nothing
      rest = something(m[5], "")
      mark = match(MARK, rest)
      mark === nothing || (state = Symbol(mark[1]))
      about = String(strip(replace(rest, MARK => "")))
      head = String(rstrip(replace(line, MARK => "")))
      if m[1] !== nothing
        old, new = parse(Int, m[1]), parse(Int, m[3])
        left = (m[2] === nothing ? 1 : parse(Int, m[2]), m[4] === nothing ? 1 : parse(Int, m[4]))
      end
    end
    h = Hunk(file, m === nothing ? 0 : i, head, about, Row[], m === nothing ? i : i + 1, state)
    j = h.first
    while j <= n
      text = c.lines[j]
      startswith(text, "\\") && (j += 1; continue)   # "\ No newline at end of file"
      if left !== nothing
        left == (0, 0) && break
      else
        (startswith(text, "@@") || startswith(text, "diff ") || (startswith(text, "--- ") && j < n && startswith(c.lines[j+1], "+++ "))) && break
      end
      sign = isempty(text) ? ' ' : text[1]
      sign in (' ', '+', '-') || break
      # A change whose @@ line has no numbers doesn't say where its lines are
      push!(h.rows, Row(sign, isempty(text) ? "" : String(chop(text, head=1, tail=0)),
                        sign == '+' || left === nothing ? 0 : old, sign == '-' || left === nothing ? 0 : new))
      sign == '+' || (old += 1)
      sign == '-' || (new += 1)
      left === nothing || (left = (left[1] - (sign != '+'), left[2] - (sign != '-')))
      j += 1
    end
    # The empty lines at the end of a change that has no numbers aren't part of it
    if left === nothing
      while !isempty(h.rows) && h.rows[end].sign == ' ' && isempty(strip(h.rows[end].text))
        pop!(h.rows)
      end
    end
    isempty(h.rows) || push!(c.hunks, h)
    i = max(j, i + 1)
  end
  c
end

"The lines of the block, with your choice at the end of each change's @@ line"
written(c::Changes) = begin
  out = String[]
  starts = Dict(h.first => h for h in c.hunks if h.at == 0)
  heads = Dict(h.at => h for h in c.hunks if h.at > 0)
  mark(h) = h.state == :open ? "" : " [$(h.state)]"
  for (i, line) in enumerate(c.lines)
    i in c.said && continue
    # A change that had no @@ line gets one to hold your choice
    haskey(starts, i) && starts[i].state != :open && push!(out, "@@" * mark(starts[i]))
    push!(out, haskey(heads, i) ? heads[i].head * mark(heads[i]) : line)
  end
  # What you said goes at the end, where `git apply` reads past it
  for (k, j) in sort!(collect(keys(c.notes)))
    text = replace(c.notes[(k, j)], r"[\r\n]+" => " ")
    isempty(strip(text)) && continue
    row = k <= length(c.hunks) && j <= length(c.hunks[k].rows) ? c.hunks[k].rows[j] : nothing
    push!(out, String(rstrip("# Comment on change $k, line $j:" * (row === nothing ? "" : " " * row.sign * row.text))))
    push!(out, "# " * text)
  end
  out
end

"Say `text` about line `j` of change `k`. Empty words take away what was said."
note!(c::Changes, k::Int, j::Int, text::AbstractString) =
  (isempty(strip(text)) ? delete!(c.notes, (k, j)) : (c.notes[(k, j)] = String(text)); c)

"Accept or reject change `k`. The choice that it has already is taken away."
choose!(c::Changes, k::Int, state::Symbol) = (h = c.hunks[k]; h.state = h.state == state ? :open : state; c)

"Accept or reject every change"
choose!(c::Changes, state::Symbol) = (foreach(h -> h.state = state, c.hunks); c)

"How many lines a change adds, and how many it takes away"
counts(h::Hunk) = (count(r -> r.sign == '+', h.rows), count(r -> r.sign == '-', h.rows))
counts(c::Changes) = (sum(h -> counts(h)[1], c.hunks, init=0), sum(h -> counts(h)[2], c.hunks, init=0))

"Where a change is in its file, in words: `Line 12`, `Lines 10 to 14`, or \"\" when the block doesn't say"
place(h::Hunk) = begin
  numbers = [r.new > 0 ? r.new : r.old for r in h.rows if r.new > 0 || r.old > 0]
  isempty(numbers) && return ""
  lo, hi = extrema(numbers)
  lo == hi ? "Line $lo" : "Lines $lo to $hi"
end

"How many changes there are, how many are accepted and rejected, and how many comments you made, in words"
summary(c::Changes) = begin
  n = length(c.hunks)
  parts = [n == 1 ? "1 change" : "$n changes"]
  for (state, word) in ((:accepted, "accepted"), (:rejected, "rejected"))
    k = count(h -> h.state == state, c.hunks)
    k > 0 && push!(parts, "$k $word")
  end
  said = length(c.notes)
  said > 0 && push!(parts, said == 1 ? "1 comment" : "$said comments")
  join(parts, "  ·  ")
end

# --- which lines are versions of each other ---------------------------------------------------
#
# In a change, some lines go and then some lines come. A line that comes is
# often a line that went with a few words changed. `matched` finds those pairs,
# and the words of each line that the other doesn't have.

"The least that two lines have the same, from 0 to 1, for one to be a version of the other"
const ALIKE = 0.4

"The words of a line, each with the place of its first character. A word is a run of letters and digits, a run of spaces, or one other character."
words(text) = begin
  out = Tuple{Int,String}[]
  col = 1
  for m in eachmatch(r"[\p{L}\p{N}_]+|\s+|.", text)
    push!(out, (col, String(m.match)))
    col += length(m.match)
  end
  out
end

"For the words `a` and the words `b`: a true for each word that the other line doesn't have in the same order"
differ(a, b) = begin
  n, m = length(a), length(b)
  gone, come = trues(n), trues(m)
  # Lines too long to compare are all different
  n * m > 1_000_000 && return gone, come
  most = zeros(Int32, n + 1, m + 1)   # how many words the ends of the two lines share, from word i and word j on
  for i in n:-1:1, j in m:-1:1
    most[i, j] = a[i] == b[j] ? most[i+1, j+1] + 1 : max(most[i+1, j], most[i, j+1])
  end
  i = j = 1
  while i <= n && j <= m
    if a[i] == b[j]
      gone[i] = come[j] = false
      i += 1
      j += 1
    elseif most[i+1, j] >= most[i, j+1]
      i += 1
    else
      j += 1
    end
  end
  gone, come
end

"The characters of the words that are marked, as ranges. One space between two marked words is marked with them."
spans(ws, marked) = begin
  out = UnitRange{Int}[]
  for (k, (col, word)) in enumerate(ws)
    lone = !marked[k] && 1 < k < length(ws) && marked[k-1] && marked[k+1] && word == " "
    (marked[k] || lone) || continue
    stop = col + length(word) - 1
    !isempty(out) && last(out[end]) == col - 1 ? (out[end] = first(out[end]):stop) : push!(out, col:stop)
  end
  out
end

"""
Compare the line `old` with the line `new`. The first result is how much they
have the same, from 0 to 1. Spaces don't count. The others are the characters
of `old` that `new` doesn't have, and the characters of `new` that `old`
doesn't have.
"""
compare(old, new) = begin
  a, b = words(old), words(new)
  gone, come = differ(last.(a), last.(b))
  size(ws, keep) = sum((length(w) for (k, (_, w)) in enumerate(ws) if keep(k) && !all(isspace, w)), init=0)
  whole = max(size(a, k -> true), size(b, k -> true))
  alike = whole == 0 ? 1.0 : size(a, k -> !gone[k]) / whole
  alike, spans(a, gone), spans(b, come)
end

"""
For each row of the change `h`: the row that's the other version of it, or 0,
and the characters of it that the other version doesn't have. A line that goes
is matched with a line that comes after it in the same run of lines, when the
two are alike enough. The matches keep the order of the lines.
"""
matched(h::Hunk; text=r -> r.text) = begin
  rows = h.rows
  other = zeros(Int, length(rows))
  marks = [UnitRange{Int}[] for _ in rows]
  j = 1
  while j <= length(rows)
    rows[j].sign == '-' || (j += 1; continue)
    a = j
    while j <= length(rows) && rows[j].sign == '-'
      j += 1
    end
    b = j
    while j <= length(rows) && rows[j].sign == '+'
      j += 1
    end
    n, m = b - a, j - b   # how many lines go, and how many come
    m == 0 && continue
    found = Dict{Tuple{Int,Int},Any}()
    look(x, y) = get!(() -> compare(text(rows[a+x-1]), text(rows[b+y-1])), found, (x, y))
    if n * m <= 900
      # The set of matches whose lines have the most the same
      best = zeros(n + 1, m + 1)
      for x in n:-1:1, y in m:-1:1
        alike = look(x, y)[1]
        best[x, y] = max(best[x+1, y], best[x, y+1], alike >= ALIKE ? best[x+1, y+1] + alike : 0.0)
      end
      x = y = 1
      while x <= n && y <= m
        alike = look(x, y)[1]
        if alike >= ALIKE && best[x, y] == best[x+1, y+1] + alike
          other[a+x-1], other[b+y-1] = b + y - 1, a + x - 1
          x += 1
          y += 1
        elseif best[x+1, y] >= best[x, y+1]
          x += 1
        else
          y += 1
        end
      end
    else
      # A long run is matched line for line
      for k in 1:min(n, m)
        look(k, k)[1] >= ALIKE && ((other[a+k-1], other[b+k-1]) = (b + k - 1, a + k - 1))
      end
    end
    for x in 1:n
      y = other[a+x-1]
      y == 0 && continue
      alike, gone, come = look(x, y - b + 1)
      # Two lines that are the same but for their spaces have nothing to mark
      alike < 1 && ((marks[a+x-1], marks[y]) = (gone, come))
    end
  end
  other, marks
end

"""
The rows of the change `h` in two columns: for each line across, the row that
shows at the left and the row that shows at the right, or 0 for an empty side.
A line that stays is on both sides. A line that goes is at the left, beside
the line that's the other version of it. `other` is the first result of `matched`.
"""
sides(h::Hunk, other=matched(h)[1]) = begin
  rows = h.rows
  out = Tuple{Int,Int}[]
  j = 1
  while j <= length(rows)
    if rows[j].sign == ' '
      push!(out, (j, j))
      j += 1
      continue
    end
    a = j
    while j <= length(rows) && rows[j].sign == '-'
      j += 1
    end
    b = j
    while j <= length(rows) && rows[j].sign == '+'
      j += 1
    end
    x, y = a, b
    while x < b || y < j
      lone_x, lone_y = x < b && other[x] == 0, y < j && other[y] == 0
      if lone_x || lone_y
        # Two lines with no other version share a line across, as they do in any view like this
        push!(out, (lone_x ? x : 0, lone_y ? y : 0))
        lone_x && (x += 1)
        lone_y && (y += 1)
      elseif x < b && y < j
        # The matches keep the order of the lines, so these two are each other's
        push!(out, (x, y))
        x += 1
        y += 1
      else
        push!(out, (x < b ? x : 0, x < b ? 0 : y))
        x < b ? (x += 1) : (y += 1)
      end
    end
  end
  out
end
