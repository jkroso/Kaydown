# A question that the page asks you, with answers to choose from. In a
# document it's a code block in the language `ask`:
#
#     ```ask
#     Which database should the app use?
#     ( ) SQLite. It's one file, and needs no server.
#     (x) Postgres
#     > We already run Postgres for the other app.
#     ```
#
# The lines at the top are the question. A line that starts with `( )` is an
# answer, and you choose one of those. `(x)` is the one that's chosen. A line
# that starts with `[ ]` is an answer too, and you choose as many of those as
# you like: `[x]` is a chosen one. A line that starts with `>` is what you
# typed under the answers. A question with no answers to choose from has only
# that line.
#
# An agent writes the block, and reads your answer in the lines that you
# changed. This file reads and writes those lines. It draws nothing.

"The language of a code block that is a question"
const ASK = "ask"

"An answer to choose"
mutable struct Option
  text::String
  chosen::Bool
  many::Bool   # true when it's one of those that you choose any number of
end

mutable struct Question
  words::Vector{String}     # the lines of the question
  options::Vector{Option}
  note::String              # what was typed under the answers
end

Question() = Question(String[], Option[], "")

# An answer can start as a to-do item does, with a - before its box
const OPTION = r"^\s*(?:[-*]\s+)?([(\[])([ xX✓]?)[)\]]\s+(.*)$"
const NOTE = r"^\s*>\s?(.*)$"

"Read a question from the lines of its block"
question(lines) = begin
  q = Question()
  typed = String[]
  for line in lines
    isempty(strip(line)) && continue
    m = match(OPTION, line)
    if m !== nothing
      push!(q.options, Option(String(strip(m[3])), !isempty(strip(m[2])), m[1] == "["))
    elseif (m = match(NOTE, line)) !== nothing
      isempty(strip(m[1])) || push!(typed, strip(m[1]))
    else
      push!(q.words, String(strip(line)))
    end
  end
  q.note = join(typed, " ")
  q
end

"The lines of a question's block"
written(q::Question) = begin
  out = copy(q.words)
  for o in q.options
    box = o.many ? (o.chosen ? "[x]" : "[ ]") : (o.chosen ? "(x)" : "( )")
    push!(out, "$box $(o.text)")
  end
  isempty(strip(q.note)) || push!(out, "> " * q.note)
  out
end

"""
Choose answer `i`, or take the choice away if it's chosen already. One of the
answers that you choose one of takes the place of the one that was chosen.
"""
choose!(q::Question, i::Int) = begin
  o = q.options[i]
  was = o.chosen
  o.many || foreach(other -> other.many || (other.chosen = false), q.options)
  o.chosen = !was
  q
end

"True when the question has an answer: one that's chosen, or words that were typed"
answered(q::Question) = any(o -> o.chosen, q.options) || !isempty(strip(q.note))

"The whole question in a line"
asked(q::Question) = join(q.words, " ")
