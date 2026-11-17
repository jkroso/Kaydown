# Code that runs where it is

Put the caret in a line of code and press ⌘Return. The page runs the line, and shows what it comes to in a box after the line. ⇧Return runs the line and goes to the next one, so you can go down a block with it.

```julia
width = 2.4
height = 3.6
area = width * height
```

## An expression of several lines

The caret can be in any line of the expression, or in the comment above it.

```julia
# The paint for a wall, in litres, at 12 square metres to the litre
paint(area; coats=2) = begin
  coats * area / 12
end

paint(area)
```

## A value with more to show

A box with an arrow has more than its first line. Click the box to show the rest, and click it again to hide it.

```julia
grid = [row * column for row in 1:4, column in 1:6]
Dict("wall" => area, "paint" => paint(area))
rand(40, 40)
```

## What the code prints, and what goes wrong

Text that the code prints shows in the box. What goes wrong shows in red. Code that ends with a semicolon shows a tick and no value.

```julia
println("The wall is ", area, " square metres")
sqrt(-1)
total = sum(grid);
```

## Names

Type the first two letters of a name that the page's code has, like `ar` or `pa`, on the empty line of this block. A list under the caret shows the names that start that way. ↑ and ↓ choose one, Return or Tab types the rest of it, and Escape hides the list.

```julia

```

## Functions and modules

The box of a function opens to show the function's documentation and a table of its methods. The box of a module opens to show the module's readme, or its documentation, and a table of the names that it defines. Type in the field over that table to search the names. The wheel moves through an open box.

```julia
length
Base.Iterators
```

## Structs

The box of a struct opens to show a line for each of the struct's fields: the field's name and its value. A line with an arrow has a value that has parts of its own. Click the line to show them under it, and click it again to hide them.

```julia
struct Wall
  long::Float64
  name::String
end
struct Room
  walls::Vector{Wall}
  door::Wall
end
Room([Wall(4.2, "north"), Wall(3.0, "east")], Wall(0.9, "door"))
```

## The whole block, a selection and a node

Put the caret in the line that opens a block, the one with the three backticks, and ⌘Return runs every line of the block. Select part of a line, like `1:6` in the grid above, and ⌘Return runs that part alone.

A value that's a part of a window shows as itself. Run this line and drag the slider. In a file of code, like `widgets.jl`, such a value doesn't show as itself. Its box lists its fields, and then its children.

```julia
Slider(value=0.4)
```

A box goes when you change its code. Escape takes every box off the page.
