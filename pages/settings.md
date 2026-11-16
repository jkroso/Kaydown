# Settings

Kaydown keeps these choices, and uses them the next time it opens. Each one changes every window as you choose it. The tabs at the top of this window show the settings for code and for the keys. Press ⌘W to close this window.

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

## Font weight

```ui
weights = page_weights()
length(weights) < 2 ? Text("$(page_font()) has one weight for text: $(page_weight()).", size=page_text_size() * 1px) :
  Box(width(240px), Dropdown(options=weights, selected=something(findfirst(==(page_weight()), weights), 1),
                             onchange=dropdown -> page_weight!(weights[dropdown.selected])))
```

The list has the weights that the font has, up to Semibold, by the names that the font gives them. Bold text and headings are heavier than the rest. Most of the fonts above have one weight for text. Helvetica Neue has five, from UltraLight to Medium.

If you choose a font that doesn't have your weight, the text shows the font's nearest weight. Kaydown keeps your choice for the next font that has it.

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

## Updates

```ui
Checkbox(label="Update Kaydown automatically", checked=app_updates(), onchange=box -> app_updates!(box.checked))
```

```ui
say(text) = Text(text, size=page_text_size() * 1px)
offer = update_offer()
isempty(offer) ? say(update_news()) :
  Column(Alignment.Start, child_gap=12px, say(update_news()), Button(label=offer, onclick=button -> update!()))
```

With this on, Kaydown looks for a newer version when it opens, and once a day after that. It gets the new version while you work. The new version takes the place of this one when you quit Kaydown. To look for one, Kaydown asks GitHub which version is the newest. It sends nothing about you or your files.

---

This page is a Markdown file, like any other in Kaydown. To see the code of a setting, hold ⌥ and click it.
