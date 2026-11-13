# Components

Each block on this page is a `ui` code block. Its code makes one of the components in `Interface/Semantic`, and the page shows it. Try them: each one keeps what you do to it until its code changes.

To see the code of a block, hold ⌥ and click the block. A block can use each component by its name, with no line that loads it. A block can make a layout too, like a `Column` with components in it.

## Sums in a line of text

Code can run in a line of text too. Write a `!` and then the code between backticks, and the line shows what the code comes to. Click a line to see its code.

A wall that is !`l = 16m` long and !`h = 2.4m` high has an area of !`area = l * h`. Two coats of paint that covers !`coverage = 16m²` a litre take !`area * 2 / (coverage / litre)`. A car that goes 150km in 2 hours travels at !`150km / 2hr`, which is !`convert(m/s, 150km / 2hr)`. A person who is 5 feet 10 inches tall is !`convert(cm, 5ft + 10inch)` tall.

The numbers have units from Units.jl: lengths like `m`, `km`, `ft` and `inch`, times like `s`, `minute` and `hr`, masses like `kg`, and volumes like `litre`. A sheet has the same units.

A component can go in a line as well: here is a switch !`Toggle(on=true)` and the folder of this page, !`fs"."`.

## Checkboxes and switches

```ui
Column(Checkbox(label="Check the spelling", checked=true),
       Checkbox(label="Use smart quotes"),
       Checkbox(label="Show the word count", checked=true))
```

```ui
switch(name, on) = Row(child_gap=12px, Toggle(on=on), Text(name, size=17px))
Column(Alignment.Start, child_gap=8px, switch("Wi-Fi", true), switch("Bluetooth", false))
```

## Choices

```ui
names = ["Sepia", "Paper", "Night"]
RadioGroup(labels=names, selected=findfirst(==(page_theme()), names),
           onchange=group -> page_theme!(names[group.selected]))
```

These choices set the colours of the page. `page_theme()` gives the name of the colours in use, and `page_theme!("Night")` changes them.

Click the box to open its menu. The font you pick becomes the font of the page's text.

```ui
fonts = ["Charter", "Helvetica Neue", "Menlo", "Lucida Grande"]
Box(width(240px), Dropdown(options=fonts, selected=something(findfirst(==(page_font()), fonts), 1),
                           onchange=dropdown -> page_font!(fonts[dropdown.selected])))
```

## Numbers and colours

Drag the slider, or click it and press ← and →. It sets the size of the page's text, and shows the size as a number.

```ui
Slider(value=page_text_size(), min=11, max=40, step=1, format=size -> round(Int, size),
       onchange=slider -> page_text_size!(slider.value))
```

```ui
ColorPicker()
```

## 3D models

The viewer shows the model in an STL file or a 3MF file, the kinds of file that a 3D printer's program reads. Drag the model to turn it. Hold ⌘ and scroll to make it bigger or smaller. Click it twice to put it back as it was.

```ui
STLViewer("knot.stl")
```

Under the model are its number of triangles and its width, depth and height, in the units of its file. The path can start from the folder of this page, as `knot.stl` does. Give the viewer a `height` or a `color` to change how it looks.

## Shadows

A container can cast a shadow. `shadow(x, y, blur)` moves it right and down, then blurs it. You can give it a colour, and `spread` makes it bigger. Change a number in the code to see what it does.

```ui
card(name, cast) = Box(width(150px), height(90px), padding(16px), radius(10px), background("white"), cast,
                       Text(name, size=15px, color=rgb(40, 40, 40)))
Row(padding(22px, 28px), child_gap=40px,
    card("Soft", shadow(0, 6, 18)),
    card("Hard", shadow(6, 6, 0, "gray")),
    card("Glow", shadow(0, 0, 14, "dodgerblue", spread=2px)))
```

The editor uses a shadow under each thing that floats over the page: the file finder that ⌘O opens, the list of names under a sheet and the bar of buttons over a table.

## Text

Click the box and type. Press Escape to go back to the page.

```ui
Box(width(320px), TextInput(placeholder="Type your name"))
```

```ui
Row(child_gap=24px, KeyCombo(:S, :cmd), KeyCombo(:Z, :cmd, :shift), KeyCombo(:P, :cmd), KeyCombo(:ArrowUp, :opt))
```

Move the mouse over the box to see its tooltip.

```ui
Tooltip("Move the mouse here", "A tooltip can hold any node", placement=:right)
```

## Trees

Click a name with an arrow to open it. Use the arrow keys to move through the tree. A tree and a menu each have an `Item`, so the block has a line that loads the tree's.

```ui
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" Item
Box(width(320px), ListTree(
  ItemGroup("examples",
    ItemGroup("markdown_editor",
      Item("components.md"),
      Item("welcome.md"),
      Item("widgets.jl")),
    Item("26_finder.jl"),
    Item("28_markdown_editor.jl")),
  ItemGroup("Interface",
    ItemGroup("Semantic",
      Item("Checkbox.jl"),
      Item("Slider.jl")),
    Item("draw.jl"))))
```

The inspector shows what's in a Julia value. Click a value to change it.

```ui
settings = Dict{String,Any}("font" => "Charter", "size" => 17, "spelling" => true,
                            "recent" => ["welcome.md", "components.md"])
Box(width(420px), Inspector(inspect(settings, label="settings")))
```
