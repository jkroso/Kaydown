# Settings

Kaydown keeps these choices, and uses them the next time it opens. Press ⌘, to go back to your page.

## Colours

```ui
names = ["Sepia", "Paper", "Night"]
RadioGroup(labels=names, selected=findfirst(==(page_theme()), names),
           onchange=group -> page_theme!(names[group.selected]))
```

## Font

```ui
fonts = unique([page_font(), "Charter", "Helvetica Neue", "Georgia", "Palatino", "Lucida Grande", "Menlo"])
Box(width(240px), Dropdown(options=fonts, selected=1, onchange=dropdown -> page_font!(fonts[dropdown.selected])))
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
