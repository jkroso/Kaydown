# A kind of block that this file defines. A code block in the language
# `progress` shows a bar that says how much of something is done:
#
#     ```progress
#     done: 0.7
#     label: Framing
#     ```
#
# Ladder finds this file by its name: a block in the language `progress` is
# for `progress.jl` in the folder of its page. Ladder gives the lines of the
# block to the function `progress`, and shows what it makes. Click in the bar,
# or drag in it, to say how much is done. The bar then asks for a write with
# `changed!`, and Ladder asks `written` for the lines and writes them into
# the block. Without `changed!`, Ladder still writes them when the page is
# saved, but ⌘Z couldn't take the change back. See welcome.md.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" Keys KeyPress MouseMove onkey onmouse
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe theme handled
@use "github.com/jkroso/UI.jl/Interface/draw" rect cursor changed!

"How much of something is done, from 0 to 1, and what it's called"
@def mutable struct Progress <: SemanticUI
  done::Float64 = 0.0
  label::String = ""
  other::Vector{String} = String[]   # the lines that this file doesn't know, kept as they are
end

"How much is done as a line writes it, 0.7 or 70%, or nothing for other words"
share(words) = begin
  words = strip(words)
  n = tryparse(Float64, rstrip(words, '%'))
  n === nothing ? nothing : clamp(endswith(words, '%') ? n / 100 : n, 0, 1)
end

"Read a Progress from the lines of its block"
progress(lines) = begin
  p = Progress()
  for line in lines
    m = match(r"^\s*(done|label)\s*:\s*(.*?)\s*$"i, line)
    if m !== nothing && lowercase(m[1]) == "label"
      p.label = String(m[2])
    elseif m !== nothing && share(m[2]) !== nothing
      p.done = share(m[2])
    elseif !isempty(strip(line))
      push!(p.other, line)
    end
  end
  p
end

"The lines of a Progress's block"
written(p::Progress) = [["done: $(p.done)"]; isempty(p.label) ? String[] : ["label: $(p.label)"]; p.other]

"What the words beside the bar say: Framing 70%"
words(p::Progress) = strip("$(p.label) $(round(Int, 100p.done))%")

describe(p::Progress) =
  Row(width(grow=GrowType.Grow), height(28px), child_gap=12px, Alignment.Center,
    Box(width(grow=GrowType.Grow), height(10px), radius(5px), background(theme(p).line), Alignment.Start,
      Box(width(percent=p.done), height(10px), radius(5px), background(theme(p).accent))),
    Box(Text(String(words(p)), size=14px, color=theme(p).dim)))

"Where the last frame put the bar, or nothing before the first frame"
bar(p::Progress) = (r = rect(p); r === nothing ? nothing : r.children[1])

"Say that the part of the bar to the left of `x` is done, to the nearest 1%"
reach!(p::Progress, x) = begin
  b = bar(p)
  b === nothing && return handled
  p.done = round(clamp(Float64((x - b.left) / b.width), 0, 1), digits=2)
  changed!(p)   # Ladder writes the block's lines once the mouse lets go
  handled
end

cursor(::Progress) = :hand
onkey(p::Progress, ev::KeyPress{Keys.mouse_left}) = reach!(p, ev.window.mouse[1])
onmouse(p::Progress, ev::MouseMove) = Keys.mouse_left in ev.window.keys ? reach!(p, ev.position[1]) : nothing
