# A kind of block that a page defines

This page defines a kind of block. A code block in the language `counter` shows a button that counts its clicks, and keeps the count in the block's one line:

```counter
3
```

Click the button. Press ⌘E on the block to see its line, and ⌘Z to take a click back.

Ladder finds this page by its name: a block in the language `counter` is for `counter.md` in the folder of its page, when that folder has no `counter.jl`. Ladder runs the code of each `julia` block below, from the top, in one module. That module defines the kind of block, as the module of a Julia file does. A page in another folder names this page after the language: `counter ./pages/counter.md`.

When you save a change to this page, Ladder runs its code again, and the button above changes with it.

## What the code loads

The code says where each name that it uses comes from, as a Julia file does.

```julia
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" Keys KeyPress onkey
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe theme handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor changed!
```

## From the block's lines to a counter

Ladder gives the lines of the block to the function that has the language's name. It shows what the function makes.

```julia
"A button that counts the times you click it"
@def mutable struct Counter <: SemanticUI
  count::Int = 0
end

counter(lines) = Counter(count=something(tryparse(Int, strip(get(lines, 1, ""))), 0))
```

## How a counter is drawn

```julia
describe(c::Counter) =
  Box(padding(16px, 8px), radius(6px), background(ishovered(c) ? theme(c).dim : theme(c).accent),
    Text(c.count == 1 ? "Clicked 1 time" : "Clicked $(c.count) times", size=15px, color=theme(c).on_accent))

cursor(::Counter) = :hand
```

## What a click does

A click adds one, and asks Ladder for a write with `changed!`. Ladder then writes the block's line, and ⌘Z can take the click back.

```julia
onkey(c::Counter, ::KeyPress{Keys.mouse_left}) = (c.count += 1; changed!(c); handled)
```

## From a counter to the block's lines

Ladder asks `written` for the lines of the block when it writes them.

```julia
written(c::Counter) = [string(c.count)]
```
