# A list of the lines that match in every page of a folder. In a document it's
# a code block in the language `find`:
#
#     ```find
#     what: to-do items
#     with: plumber
#     in: jobs
#     ```
#
# `what` is the kind of line to list:
#
# - `to-do items`: the to-do items that aren't ticked
# - `done items`: the ones that are
# - `headings`
# - `lines`: any line of text
#
# `with` holds words, and a line is listed only when it has every one of
# them. `in` names a folder beside the page. Without it, the list is of the
# page's own folder, and the folders in that one.
#
# An empty block lists every to-do item that isn't ticked. A block with only
# words in it lists the lines that have those words.
#
# This file reads and writes those lines, and finds what matches in the lines
# of a page. It draws nothing, and reads no file.

@use "./markdown" Kind Line classify spans isdone

"The language of a code block that is a list of what was found"
const FIND = "find"

"The kinds of line that a list can be of, and the words that a block can name each one by"
const WHATS = (todo=("to-do items", "to-dos", "todos", "todo", "to-do", "tasks", "open items"),
               done=("done items", "done", "ticked", "ticked items", "finished"),
               heading=("headings", "heading"),
               line=("lines", "line", "text"))

mutable struct Query
  what::Union{Nothing,Symbol}   # :todo, :done, :heading or :line, or nothing when the block doesn't say
  with::Vector{String}          # the words that a line must have
  folder::String                # the folder to look in, or "" for the page's own
  other::Vector{String}         # the lines that this file doesn't know, kept as they are
end

Query() = Query(nothing, String[], "", String[])

"The kind of line that `words` name, or nothing"
what(words::AbstractString) = begin
  w = lowercase(strip(words))
  for k in keys(WHATS)
    w in WHATS[k] && return k
  end
  nothing
end

"The kind of line that the list is of. A block that doesn't say lists lines when it has words to find, and to-do items when it has none."
kind(q::Query) = q.what !== nothing ? q.what : isempty(q.with) ? :todo : :line

"Read what to find from the lines of its block"
query(lines) = begin
  q = Query()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = match(r"^(\w+)\s*:\s*(.*)$", text)
    key, value = m === nothing ? ("", "") : (lowercase(m[1]), String(strip(m[2])))
    if key == "what" && what(value) !== nothing
      q.what = what(value)
    elseif key == "with"
      append!(q.with, split(value))
    elseif key == "in"
      q.folder = value
    elseif m !== nothing
      push!(q.other, String(text))
    elseif what(text) !== nothing
      q.what = what(text)       # the kind by itself, like `headings`
    else
      append!(q.with, split(text))   # words by themselves are the words to find
    end
  end
  q
end

"The lines of the block"
written(q::Query) = begin
  out = String[]
  q.what === nothing || push!(out, "what: " * WHATS[q.what][1])
  isempty(q.with) || push!(out, "with: " * join(q.with, " "))
  isempty(q.folder) || push!(out, "in: " * q.folder)
  append!(out, q.other)
  out
end

"A line that was found"
struct Match
  path::String    # the file that it's in
  line::Int       # the line of that file
  text::String    # its text as it reads, without the marks of bold and the like
  kind::Symbol    # :todo, :done, :heading or :line
end

"The text of a line as it reads: without what starts it, like the # of a heading, and without the marks of bold and the like"
reads(text::AbstractString, l::Line) = String(strip(join(s.text for s in spans(String(chop(text, head=min(l.prefix, length(text)), tail=0))) if !s.markup)))

"""
The lines of the page at `path` that `q` asks for. `lines` holds the page's
text. A line of code isn't a line of the page's text, and neither is its front
matter.
"""
matches(q::Query, path::AbstractString, lines, kinds=classify(lines)) = begin
  want = kind(q)
  words = lowercase.(q.with)
  out = Match[]
  for (i, l) in enumerate(kinds)
    l.kind in (Kind.blank, Kind.fence, Kind.code, Kind.rule) && continue
    is = l.kind == Kind.todo ? (isdone(lines[i]) ? :done : :todo) : l.kind == Kind.heading ? :heading : :line
    (is == want || want == :line) || continue
    # A line that hasn't the words as it's written hasn't them as it reads, and is quick to rule out
    isempty(words) || (raw = lowercase(lines[i]); all(w -> occursin(w, raw), words)) || continue
    text = l.kind == Kind.table ? String(strip(lines[i])) : reads(lines[i], l)
    isempty(text) && continue
    low = lowercase(text)
    all(w -> occursin(w, low), words) || continue
    push!(out, Match(String(path), i, text, is))
  end
  out
end

"""
The line of a page that the match `m` is on now, or nothing when the page no
longer has it. The page can have changed since `m` was found, so this is the
line nearest to where it was that still reads the same and is of the same kind.
"""
locate(m::Match, lines, kinds=classify(lines)) = begin
  fits(i) = begin
    1 <= i <= length(lines) || return false
    l = kinds[i]
    is = l.kind == Kind.todo ? (isdone(lines[i]) ? :done : :todo) : l.kind == Kind.heading ? :heading : :line
    is == m.kind && reads(lines[i], l) == m.text
  end
  for far in 0:length(lines)
    fits(m.line - far) && return m.line - far
    fits(m.line + far) && return m.line + far
  end
  nothing
end

"`line` with the box of its to-do item ticked, or with its tick taken away"
ticked(line::AbstractString, done::Bool) = begin
  i = findfirst('[', line)
  i === nothing && return String(line)
  chars = collect(line)
  k = length(line[1:i])   # the place of the [ among the characters
  k < length(chars) && (chars[k+1] = done ? 'x' : ' ')
  String(chars)
end

"""
What the list is of and where it looks, in words, for `n` lines in `pages`
pages: `3 to-do items in 2 pages of this folder`
"""
summary(q::Query, n::Int, pages::Int) = begin
  one, many = kind(q) == :todo ? ("to-do item", "to-do items") : kind(q) == :done ? ("item that's done", "items that are done") :
              kind(q) == :heading ? ("heading", "headings") : ("line", "lines")
  with = isempty(q.with) ? "" : " with “" * join(q.with, " ") * "”"
  place = isempty(q.folder) ? "this folder" : "the folder " * q.folder
  n == 0 && return "No $many$with in $place"
  "$n $(n == 1 ? one : many)$with in $(pages == 1 ? "1 page" : "$pages pages") of $place"
end
