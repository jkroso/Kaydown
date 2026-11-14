# Kaydown

Kaydown is a Markdown editor made with UI.jl. This page is a Markdown file. Each line is drawn the way it will read, and the markup characters stay out of sight. **Click a line** and its markup shows again, so you can change it. Press ⌘S to write your changes to the file.

## Text

You can write in **bold**, in *italic* or in ***both***. Use backticks for `code`, and square brackets for [a link](https://github.com/jkroso/UI.jl). Hold ⌘ and click a link to open it. A name like snake_case_name keeps its underscores.

> A line that starts with > is a quote.
> It can run over several lines.

A word that the Mac's dictionary doesn't have, like teh, gets a line of red dots under it. Right-click the word to choose the word you meant. Press ⌘F to find text in the page.

A line can point to a footnote[^note]. The footnote is a line of its own, anywhere in the file, and the page gives each footnote a number. Hold ⌘ and click the number to go to the footnote.

[^note]: This is the footnote. Its line starts with the same name in square brackets, and a colon.

A line that holds only a picture, like `![plan](plan.png)`, shows the picture. Drop a picture on the page from the Finder to add one. Any other file that you drop goes in as a path that you can click.

## Lists

1. Press Return at the end of this line. The next number is typed for you.
2. Press Return on an empty item to end the list.
3. Press Tab to move an item in, and shift-Tab to move it back out.

- A long item wraps onto the next line, and the text of that line starts under the text of the first line, not under the bullet.
  - Items can sit inside other items.
- Select some words and press ⌘B or ⌘I.

- [x] An item that starts with `- [x]` has a box with a tick in it.
- [ ] Click the box of an item like this one to tick it.

## Tables

| Keys | What they do |
|------|--------------|
| ⌘O | Finds a file in this folder by name |
| ⌘F | Finds text in the page. Return goes to the next place that has it. |
| ⌘P | Prints the page, or saves it as a PDF |
| ⌘⇧E | Saves the page as a page of HTML, for a website |
| ⌘, | Opens the settings page. Press it again to go back. |
| ⌘\ | Shows and hides the list of files |
| ⌘⇧\ | Gives the list of files the keyboard. Press esc to go back to the text. |
| ⌘Z and ⌘⇧Z | Undo and redo |
| ⌥← and ⌥→ | Move the caret a word at a time |
| ⌘+ and ⌘- | Make the text bigger and smaller. ⌘0 puts it back to the size it started at. |

Click a cell and type. Tab goes to the next cell and Return goes down a row. Both add a row when they reach the end of the table.

## Code

```julia
# Only the lines on screen are built
describe(d::Document) = begin
  e = editor(d)
  title = "Lines $(first(e.shown)) to $(last(e.shown))"
  Column(fixed(e.width), spacer(28px), map(describe, e.layout[e.shown])...)
end
```

The line that opens a code block names its language, and the code is coloured to match. Try changing `julia` to `python`.

## Live blocks

A code block in the language `ui` holds Julia code. The page runs the code and shows what it makes: a node from any Julia module, or any other value as text.

```ui
@use "./widgets.jl" Counter
Counter()
```

```ui
@use "./widgets.jl" Meter
Meter(done=0.7)
```

A block can use UI.jl's components and layout with no line that loads them: `Slider`, `STLViewer`, `Column`, `px` and the rest. A file path is `fs"notes.md"` and a colour is `colorant"tomato"`. The two blocks above load `widgets.jl` because it's a file of this folder.

A file path shows as a breadcrumb. Click its last name to list what's in the folder, and click a file in the list to make it the path. Under a file is what's in it: a picture, its text, which you can scroll through, a 3D model that you can drag to turn, a player for a sound or a video, the pages of a PDF, a CSV file as a table, or the picture that the Finder shows for a file like a Word file. Click `knot.stl` to see a model.

```ui
fs"."
```

To change the code, move the caret into the block with ↑ or ↓, or hold ⌥ and click the block.

Code can run in a line of text too. Write a `!` and then the code between backticks, like \!`fs"."`. This page is in the folder !`fs"."` and its colours are !`page_theme()`. A number works too: 12 × 2.4 is !`12 * 2.4`. Click a line to see its code.

The page [components.md](components.md) has a live block for each of UI.jl's components: checkboxes, switches, a slider, a menu, a colour picker, a viewer for 3D models, players for sound and video, a text field, a tree and an inspector. It shows shadows too. Hold ⌘ and click the link to open it.

## Sheets

A code block in the language `sheet` works things out. Each row has a name and a Julia expression. An expression can use the names of the rows above it, and numbers can have units.

```sheet
Wall length = 12m
Wall height = 2.4m
Area = wall length * wall height
Coats = 2
Coverage = 16m^2 / litre
Litres = area * coats / coverage
Tins = ceil(litres / 4litre)
```

Click a cell and type. Tab goes to the next cell and Return starts a row. To see the sheet as lines of code, hold ⌥ and click it.

## Spreadsheets

A code block in the language `spreadsheet` is a grid of cells. Each column has a letter and each row has a number, so `B2` is the second cell of the second row. A cell that starts with `=` is a formula: a Julia expression that can use the other cells by name. `D2:D4` is every cell from D2 to D4.

```spreadsheet
| Wall  | Length | Height | Area         |
| North | 12m    | 2.4m   | = B2 * C2    |
| East  | 8m     | 2.4m   | = B3 * C3    |
| South | 12m    | 2.4m   | = B4 * C4    |
| Total |        |        | = sum(D2:D4) |
```

Click a cell and type. A cell shows what its formula comes to, and it shows the formula while the caret is in it. Tab goes to the next cell and Return goes down a row. The bar over the grid adds and removes a row or a column, and each formula still names the same cells after that. To see the spreadsheet as lines of code, hold ⌥ and click it.

---

The button at the top left shows the files in this folder. Click the icon beside a file to see its headings and its components, such as a slider, a sheet or a spreadsheet. Click one to go to it. Press ⌘⇧\ to use the list with the keyboard: ↑ and ↓ move through it, → and ← show and hide what's under an item, and Return opens a file or goes to a heading.

Click a file in the list that isn't Markdown to see it in the page. Kaydown shows such a file and never changes it, so the top bar says "Read only". A file of code shows its text, which you can select, copy and search. A picture, a model, a sound, a video, a PDF and a CSV file each show as what they are. Any other file is a binary file, and a button shows its bytes in hexadecimal. The button at the top right opens the file in the app that your Mac uses for it.

Right-click a file in the list to rename it, copy its path or move it to the Trash.

Right-click the page to cut, copy or paste. The menu's Insert item adds a new block where you clicked: a heading, a list, a to-do item, a table, a sheet, a spreadsheet, a live block and more.

A file can start with front matter: lines like `title: Notes` between two lines of `---`. Kaydown shows it as a block of its own, and leaves it out of the word count.

Press ⌘, to open the settings: the colours, the font, the size of the text, the width of the page and what the count at the top right shows. A button there makes Kaydown the app that opens your Markdown files.
