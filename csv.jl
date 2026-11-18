# Reads a CSV file as the rows of a table. A page shows the file as a table
# when a line holds only a link to it, written as a picture is:
#
#     ![Prices](prices.csv)
#
# Each line of the file is a row, and a mark is between two cells of a row. The
# mark is a comma, a tab or a semicolon: the one that the first row has most
# of. A .tsv file has tabs. A cell that holds the mark, a quote or a line break
# is in quotes, and a quote in such a cell is written twice:
#
#     Item,Note
#     Paint,"Two coats, low sheen"
#     Timber,"The ""good"" pine"
#
# The first row has the names of the columns. A line with nothing on it is no
# row. A table keeps the first `MOST_COLUMNS` columns and the first `MOST_ROWS`
# rows under the names, and a file is read as far as `MOST_BYTES`.
#
# This file reads the rows, and says which columns hold numbers. It draws nothing.

@use "./chart" isnumber

const MOST_COLUMNS = 40
const MOST_ROWS = 5_000         # under the row of names
const MOST_BYTES = 4_000_000    # a longer file is read this far

"The table that a file holds"
struct Table
  rows::Vector{Vector{String}}   # the text of each cell. The first row has the names of the columns.
  numbers::Vector{Bool}          # true for each column that holds numbers
  more::Bool                     # the file has rows after these
  problem::String                # why there's no table to show, or ""
end

"A table with no rows, and why it has none"
nothing_to_show(problem) = Table(Vector{String}[], Bool[], false, problem)

"""
The cells of one row of a CSV file. `mark` is the character between two
cells. A cell that has the mark in it is in quotes, and a quote in such a cell
is written twice.
"""
cells(line, mark::Char) = begin
  out, cell, quoted = String[], IOBuffer(), false
  chars = collect(line)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if quoted && c == '"' && i < length(chars) && chars[i+1] == '"'
      write(cell, '"')
      i += 1
    elseif c == '"'
      quoted = !quoted
    elseif c == mark && !quoted
      push!(out, String(take!(cell)))
    else
      write(cell, c)
    end
    i += 1
  end
  push!(out, String(take!(cell)))
  out
end

"The mark between the cells of `line`: the one of a comma, a tab and a semicolon that it has most of. A mark in quotes doesn't count."
mark(line) = begin
  marks = (',', '\t', ';')
  counts, quoted = [0, 0, 0], false
  for c in line
    k = findfirst(==(c), marks)
    c == '"' ? (quoted = !quoted) : k === nothing || quoted || (counts[k] += 1)
  end
  marks[argmax(counts)]
end

"""
The rows of `text`, each as the text of its line. A line break between two
quotes is part of a cell, so its row goes on to the next line. A line with
nothing on it is no row. No more than `most` rows are read.
"""
records(text; most=typemax(Int)) = begin
  out, row, quoted = String[], IOBuffer(), false
  add!() = (s = String(take!(row)); isempty(strip(s)) || push!(out, s))
  for c in text
    if c == '\n' && !quoted
      add!()
      length(out) >= most && return out
    else
      c == '"' && (quoted = !quoted)
      write(row, c)
    end
  end
  add!()
  out
end

"""
Which columns of `rows` hold numbers. The first row has the names. A column
holds numbers when most of its cells that hold something are numbers, as a
chart counts them: `\$1,200`, `45%` and `2.4 m` are numbers.
"""
numbers(rows) = begin
  wide = isempty(rows) ? 0 : maximum(length, rows)
  map(1:wide) do c
    full = [row[c] for row in @view(rows[2:end]) if c <= length(row) && !isempty(strip(row[c]))]
    !isempty(full) && 2count(isnumber, full) > length(full)
  end
end

"The table that `text` holds, which is the text of a CSV file. Each row has a cell for each column."
table(text::AbstractString) = begin
  text = replace(text, "\r\n" => "\n", '\r' => '\n')
  startswith(text, '﻿') && (text = chop(text, head=1, tail=0))   # the mark that some apps start a file with
  lines = records(text, most=MOST_ROWS + 2)
  isempty(lines) && return Table(Vector{String}[], Bool[], false, "")
  more = length(lines) > MOST_ROWS + 1
  more && pop!(lines)
  between = mark(lines[1])
  # The spaces around a cell's text aren't part of it
  rows = [String[strip(cell) for cell in first(cells(line, between), MOST_COLUMNS)] for line in lines]
  wide = maximum(length, rows)
  foreach(row -> append!(row, fill("", wide - length(row))), rows)
  Table(rows, numbers(rows), more, "")
end

"""
The table in the file at `path`. When the file isn't there, isn't text or has
no rows, the table has no rows, and its `problem` says why in words for the
page. It never throws.
"""
load(path) = begin
  name = basename(path)
  isfile(path) || return nothing_to_show("Ladder can't find the file $name.")
  try
    bytes = open(io -> read(io, MOST_BYTES + 1), path)
    more = length(bytes) > MOST_BYTES
    if more
      # A file that was cut short can stop part way through a row, so it ends at its last whole line
      stop = findlast(==(0x0a), @view bytes[1:MOST_BYTES])
      stop === nothing && return nothing_to_show("Ladder can't read $name as a table.")
      resize!(bytes, stop)
    end
    0x00 in view(bytes, 1:min(length(bytes), 4000)) && return nothing_to_show("Ladder can't read $name as a table. It isn't a file of text.")
    text = String(bytes)
    isvalid(text) || return nothing_to_show("Ladder can't read $name as a table. It isn't a file of text.")
    t = table(text)
    isempty(t.rows) && return nothing_to_show("The file $name has no rows yet.")
    Table(t.rows, t.numbers, t.more || more, "")
  catch
    nothing_to_show("Ladder can't read the file $name.")
  end
end
