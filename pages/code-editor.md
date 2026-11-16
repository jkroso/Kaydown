# Code editor

These settings say how code shows, in a file of code and in a code block on a page. Each one changes every window as you choose it.

## Files of code

These three are for a file of code or of text, like a `.jl` file.

```ui
Column(Alignment.Start, child_gap=12px,
  Checkbox(label="Wrap long lines", checked=code_wrap(), onchange=box -> code_wrap!(box.checked)),
  Checkbox(label="Show line numbers", checked=code_numbers(), onchange=box -> code_numbers!(box.checked)),
  Checkbox(label="Shade the line the caret is on", checked=code_shade(), onchange=box -> code_shade!(box.checked)))
```

With Wrap long lines on, a line that's too long for the window goes on under itself, one indent further in than the line starts. With it off, the line goes on past the right edge of the window. Move two fingers sideways on the trackpad to see the rest of it, or hold ⇧ and turn the mouse's wheel. The page also moves sideways to keep the caret in sight.

## Line-length guide

```ui
guides = [0, 80, 92, 100, 120]
RadioGroup(labels=["None", "80", "92", "100", "120"], selected=something(findfirst(==(code_guide()), guides), 1),
           onchange=group -> code_guide!(guides[group.selected]))
```

A file of code gets a faint line down it after this many characters, so you can see when a line gets too long. Julia's own code keeps its lines to 92 characters.

## Indent

```ui
widths = [2, 4]
RadioGroup(labels=["2 spaces", "4 spaces"], selected=something(findfirst(==(code_indent()), widths), 1),
           onchange=group -> code_indent!(widths[group.selected]))
```

This is for all code, in a file or in a code block on a page. Tab moves a line in by this many spaces, and ⇧Tab moves it back out. A new line after one that opens a block starts this much further in. Backspace in the spaces at the start of a line takes away this many.

## Code font

```ui
fonts = code_fonts()
Box(width(300px), Dropdown(options=fonts, families=code_family.(fonts), selected=something(findfirst(==(code_font()), fonts), 1),
                           onchange=dropdown -> code_font!(fonts[dropdown.selected])))
```

This is for all code, in a file or in a code block on a page. The list has each font on this Mac whose letters are all one width. Code shows in the font's light weight when it has one, as SF Mono does.

## Code size

```ui
Slider(value=code_text_size(), min=10, max=30, step=1, format=size -> round(Int, size),
       onchange=slider -> code_text_size!(slider.value))
```

This is for all code too. The number is the height of code in pixels. Code grows and shrinks with the page's text, when you change Text size on the General page or press ⌘+ and ⌘-.
