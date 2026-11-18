# A list of the emails with one person, in a page. In a document it's a code
# block in the language `email`:
#
#     ```email
#     with: Sam Lee, sam@example.com
#     about: roof
#     ```
#
# `with` names the people: a name, a part of a name, or an address, with a
# comma between two of them. An email is listed when it's from one of them or
# to one of them. `about` holds words, and an email is listed only when its
# subject has every one of them. A block with only a name or an address in it
# lists the emails with that person.
#
# The emails are the ones that Ladder keeps on the Mac: mail.jl says how.
# This file reads and writes the block's lines, and says whether an email is
# one that the block asks for. It reads no email.

"The language of a code block that is a list of emails"
const EMAIL = "email"

mutable struct Wanted
  with::Vector{String}    # the people: a name or an address each
  about::Vector{String}   # the words that the subject must have
  other::Vector{String}   # the lines that this file doesn't know, kept as they are
end

Wanted() = Wanted(String[], String[], String[])

"The people in a list that has commas between them"
people(text::AbstractString) = String[strip(p) for p in split(text, ',') if !isempty(strip(p))]

"Read what the list is of from the lines of its block"
wanted(lines) = begin
  w = Wanted()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = match(r"^(\w+)\s*:\s*(.*)$", text)
    key, value = m === nothing ? ("", "") : (lowercase(m[1]), String(strip(m[2])))
    if key == "with"
      append!(w.with, people(value))
    elseif key == "about"
      append!(w.about, split(value))
    elseif m !== nothing
      push!(w.other, String(text))
    else
      append!(w.with, people(text))   # a name or an address by itself
    end
  end
  w
end

"The lines of the block"
written(w::Wanted) = begin
  out = String[]
  isempty(w.with) || push!(out, "with: " * join(w.with, ", "))
  isempty(w.about) || push!(out, "about: " * join(w.about, " "))
  append!(out, w.other)
  out
end

"True when the words of `subject` are the ones that the block asks for"
about(w::Wanted, subject::AbstractString) = (s = lowercase(subject); all(word -> occursin(lowercase(word), s), w.about))

"""
True when `names` has one of the block's people in it. `names` is who an email
is from and who it's to, as text: their names, their addresses, or both. Each
word of a person's name has to be there, in any case.
"""
with(w::Wanted, names::AbstractString) = begin
  s = lowercase(names)
  any(person -> all(word -> occursin(word, s), split(lowercase(person))), w.with)
end

"True when one of the block's people is an address, so that the names of an email's people aren't enough to tell"
addressed(w::Wanted) = any(person -> occursin('@', person), w.with)

"The first address among the block's people, or \"\""
address(w::Wanted) = (i = findfirst(person -> occursin('@', person), w.with); i === nothing ? "" : w.with[i])

"What the list is of, in words, for `n` emails: `3 emails with Sam Lee`"
summary(w::Wanted, n::Int) = begin
  who = length(w.with) <= 2 ? join(w.with, " and ") : join(w.with[1:end-1], ", ") * " and " * w.with[end]
  topic = isempty(w.about) ? "" : " about “" * join(w.about, " ") * "”"
  n == 0 ? "No emails with $who$topic" : "$n email$(n == 1 ? "" : "s") with $who$topic"
end
