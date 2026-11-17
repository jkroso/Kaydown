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
# `[rejected]`. The block is still a diff that `git apply` reads. An agent
# writes the block, and reads your choices in the lines that you changed.
# Kaydown changes no file but the page.
#
# This file reads those lines and writes your choices. It draws nothing.

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
  lines::Vector{String}   # the lines of the block, as they were read
  hunks::Vector{Hunk}
end

const HEAD = r"^@@\s*(?:-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s*)?(?:@@)?\s*(.*)$"
const MARK = r"\s*\[(accepted|rejected)\]\s*$"

"The name of the file in a `---` or `+++` line, or \"\" for /dev/null"
filename(line::AbstractString) = begin
  name = strip(replace(chop(line, head=3, tail=0), r"\t.*$" => ""))
  name == "/dev/null" ? "" : String(replace(name, r"^[ab]/" => ""))
end

"Read changes from the lines of their block"
changes(lines) = begin
  c = Changes(String[String(l) for l in lines], Hunk[])
  n = length(c.lines)
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
    # A change that had no @@ line gets one to hold your choice
    haskey(starts, i) && starts[i].state != :open && push!(out, "@@" * mark(starts[i]))
    push!(out, haskey(heads, i) ? heads[i].head * mark(heads[i]) : line)
  end
  out
end

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

"How many changes there are, and how many are accepted and rejected, in words"
summary(c::Changes) = begin
  n = length(c.hunks)
  parts = [n == 1 ? "1 change" : "$n changes"]
  for (state, word) in ((:accepted, "accepted"), (:rejected, "rejected"))
    k = count(h -> h.state == state, c.hunks)
    k > 0 && push!(parts, "$k $word")
  end
  join(parts, "  ·  ")
end
