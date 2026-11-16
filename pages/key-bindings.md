# Key bindings

A key binding is the keys that you press to do something, like ⌘S to save. These are the same in every window, on a page and in a file of code. Kaydown keeps them, and uses them the next time it opens.

## Bundle

```ui
bundles = key_bundles()
RadioGroup(labels=bundles, selected=something(findfirst(==(key_bundle()), bundles), 1),
           onchange=group -> key_bundle!(bundles[group.selected]))
```

A bundle gives every command its keys. Kaydown has the keys that this app started with. The others have the keys of another editor, for the commands that Kaydown has too.

- **VS Code**: ⌘P finds a file, ⌥↑ and ⌥↓ move a line, and ⇧⌥↓ copies it. Printing moves to ⌘⌥P.
- **Sublime Text**: ⌘P finds a file, ⌃⌘↑ and ⌃⌘↓ move a line, ⌘⇧D copies it, ⌃⇧K deletes it, and ⌘K then ⌘B shows the sidebar. Printing moves to ⌘⌥P.
- **Emacs**: ⌃A, ⌃E, ⌃F, ⌃B, ⌃N and ⌃P move the caret, ⌃D and ⌃K delete, ⌃W cuts, ⌥W copies, ⌃Y pastes, ⌃S finds, ⌃/ undoes, and ⌃X then ⌃S saves. The Mac's own keys, like ⌘S, still work.

When you choose a bundle, every command gets that bundle's keys. The keys that you changed yourself go back too.

## Commands

```ui
key_list()
```

To change the keys of a command, click the command, then press the new keys. Hold ⌘, ⌃ or ⌥ with a letter, a number or a sign. If another command had those keys, it loses them, and a line under the command says which one. Press esc to leave the keys as they are.

A command that you changed shows the words "Put back". Click them to give the command its bundle's keys again.

```ui
keys_changed() ? Button(label="Put every key back", onclick=button -> key_reset!()) :
                 Text("Every command has its bundle's keys.", size=page_text_size() * 1px)
```

Some keys have no command, so they aren't in the list. Return, esc and Space do what fits the place the caret is in. ⇧ with a key that moves the caret selects the text that the caret passes. A text field, like the one that finds a file, keeps the Mac's own keys.

---

This page is a Markdown file, like any other in Kaydown. To see the code of a setting, hold ⌥ and click it.
