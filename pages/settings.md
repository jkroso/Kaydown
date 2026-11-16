# Settings

Kaydown keeps these choices, and uses them the next time it opens. Each one changes every window as you choose it. Press ⌘W to close this window.

## Colours

```ui
names = ["Sepia", "Paper", "Night"]
RadioGroup(labels=names, selected=findfirst(==(page_theme()), names),
           onchange=group -> page_theme!(names[group.selected]))
```

## Font

```ui
fonts = unique([page_font(), "Charter", "Helvetica Neue", "Georgia", "Palatino", "Lucida Grande", "Menlo"])
Box(width(240px), Dropdown(options=fonts, families=fonts, selected=1, onchange=dropdown -> page_font!(fonts[dropdown.selected])))
```

## Text size

```ui
Slider(value=page_text_size(), min=11, max=40, step=1, format=size -> round(Int, size),
       onchange=slider -> page_text_size!(slider.value))
```

The number is the height of the text in pixels. ⌘+ and ⌘- change it by one, and ⌘0 puts it back to 17.

## Page width

```ui
Slider(value=page_width(), min=400, max=1200, step=20, format=width -> round(Int, width),
       onchange=slider -> page_width!(slider.value))
```

The number is the width of the page in pixels, while the text is 17 pixels tall. Bigger text gets a wider page, so a line holds as many words as before. A window that is too narrow for the page shows it as wide as it can.

## Word count

```ui
counts = ["Words", "Characters", "Reading time"]
RadioGroup(labels=counts, selected=findfirst(==(page_count()), counts),
           onchange=group -> page_count!(counts[group.selected]))
```

The top right of the window shows the one you choose. A click on it there changes it too.

## Spelling

```ui
Checkbox(label="Check spelling", checked=page_spelling(), onchange=box -> page_spelling!(box.checked))
```

With this on, a word that the Mac's dictionary doesn't have gets a line of red dots under it. Right-click the word to see the words it may have been meant to be, or to teach the dictionary the word. Code isn't checked.

## Code

These three are for a file of code or of text, like a `.jl` file.

```ui
Column(Alignment.Start, child_gap=12px,
  Checkbox(label="Wrap long lines", checked=code_wrap(), onchange=box -> code_wrap!(box.checked)),
  Checkbox(label="Show line numbers", checked=code_numbers(), onchange=box -> code_numbers!(box.checked)),
  Checkbox(label="Shade the line the caret is on", checked=code_shade(), onchange=box -> code_shade!(box.checked)))
```

With Wrap long lines on, a line that's too long for the window goes on under itself, one indent further in than the line starts. With it off, the line goes on past the right edge of the window. Move two fingers sideways on the trackpad to see the rest of it, or hold ⇧ and turn the mouse's wheel. The page also moves sideways to keep the caret in sight.

### Line-length guide

```ui
guides = [0, 80, 92, 100, 120]
RadioGroup(labels=["None", "80", "92", "100", "120"], selected=something(findfirst(==(code_guide()), guides), 1),
           onchange=group -> code_guide!(guides[group.selected]))
```

A file of code gets a faint line down it after this many characters, so you can see when a line gets too long. Julia's own code keeps its lines to 92 characters.

### Indent

```ui
widths = [2, 4]
RadioGroup(labels=["2 spaces", "4 spaces"], selected=something(findfirst(==(code_indent()), widths), 1),
           onchange=group -> code_indent!(widths[group.selected]))
```

This is for all code, in a file or in a code block on a page. Tab moves a line in by this many spaces, and ⇧Tab moves it back out. A new line after one that opens a block starts this much further in. Backspace in the spaces at the start of a line takes away this many.

### Code font

```ui
fonts = code_fonts()
Box(width(300px), Dropdown(options=fonts, families=code_family.(fonts), selected=something(findfirst(==(code_font()), fonts), 1),
                           onchange=dropdown -> code_font!(fonts[dropdown.selected])))
```

This is for all code, in a file or in a code block on a page. The list has each font on this Mac whose letters are all one width. Code shows in the font's light weight when it has one, as SF Mono does.

### Code size

```ui
Slider(value=code_text_size(), min=10, max=30, step=1, format=size -> round(Int, size),
       onchange=slider -> code_text_size!(slider.value))
```

This is for all code too. The number is the height of code in pixels. Code grows and shrinks with the page's text, when you change Text size or press ⌘+ and ⌘-.

## Default app

```ui
app = markdown_app()
say(text) = Text(text, size=page_text_size() * 1px)
app == "Kaydown" ? say("Kaydown opens the Markdown files on this Mac.") :
!app_installed() ? say("Put the Kaydown app in your Applications folder, then come back to this page.") :
  Column(Alignment.Start, child_gap=12px,
         say(isempty(app) ? "No app is set to open Markdown files." : "$app opens the Markdown files on this Mac now."),
         Button(label="Make Kaydown the default app", onclick=button -> default_app!()))
```

The default app is the one that opens a Markdown file when you double-click it in the Finder. macOS asks you to confirm the change.

---

This page is a Markdown file, like any other in Kaydown. To see the code of a setting, hold ⌥ and click it.
