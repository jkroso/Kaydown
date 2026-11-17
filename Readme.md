# Kaydown

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it.

A code block does more than show code. What it does depends on its language:

- `ui` runs its Julia code and shows what the code makes.
- `julia` runs the line that the caret is in when you press ⌘Return, and shows what it comes to in a box after the line. It offers the names in scope as you type.
- `sheet` works things out, a row at a time.
- `spreadsheet` is a grid of cells with formulas.
- `mermaid` shows a diagram, like a flowchart.
- `takeoff` shows a building plan that you measure from, and makes a quote from what you measure.
- `schedule` shows the page's to-do items as bars on a line of days, and you drag the bars to plan the work.

A page shows more than text:

- A line that holds only a picture, a video or a sound file shows it, or a player for it. The page's Insert menu records a sound from the microphone, and a button under the player writes down what's said in it, on the Mac.
- A button beside a diagram, a picture or a page of a PDF file makes it fill the window, where you zoom it with a pinch.
- A Julia file opens as one block of code, which you change and run as you do a `julia` block.

"Kaydown" is a working name, after Alan Kay.

## Get the app

1. Download `Kaydown-<version>.zip` from the [newest release](https://github.com/jkroso/Kaydown/releases/latest).
2. Open the zip file.
3. Move Kaydown to your Applications folder, and open it.

The app needs a Mac with Apple silicon, and macOS 12 or later. To write down what's said in a recording, it needs macOS 26 or later. It opens on its welcome page, which shows what the editor does.

The app updates itself. [How the app updates itself](#how-the-app-updates-itself) says how, and how to turn that off.

## Run it from the source

You need Julia and [Kip](https://github.com/jkroso/Kip.jl).

```sh
julia --project=. main.jl                # opens the welcome page
julia --project=. main.jl ~/notes        # opens a file or a folder
```

The `pages` folder has the pages that come with Kaydown:

- `welcome.md` shows what the editor does.
- `components.md` has a live block for each of UI.jl's components.
- `julia.md` has code to run with ⌘Return.
- `schedule.md` has a schedule to try.
- `settings.md`, `code-editor.md` and `key-bindings.md` are the three pages of the settings window.

## Use it with an agent

An agent like Claude Code can show you a page in Kaydown and read what you change in it. The agent writes a Markdown file, opens it in Kaydown and waits. You read the page, tick a box or type a note, and click the bell at the top right, or press ⌘Return. That button is called "Nudge Claude". The agent gets the lines that you changed. The agent can change the page while you read it, and Kaydown keeps what you're typing.

The `plugin` folder is a plugin for Claude Code. It has a skill that tells Claude when and how to show a page, and a command, `kaydown`, that the skill runs. To install it, type these in Claude Code:

```
/plugin marketplace add jkroso/Kaydown
/plugin install kaydown@kaydown
```

For another agent, put `plugin/bin` on your `PATH` and give the agent `plugin/skills/page/SKILL.md` to read.

```sh
kaydown show plan.md    # opens the page in Kaydown
kaydown wait plan.md    # waits until you press Nudge Claude, then prints the lines that you changed
```

The top of `agent.jl` says how the command and Kaydown talk to each other.

## Measure from a plan

A code block in the language `takeoff` shows a page of a PDF file, or a picture. Drop the file on the block. Set the scale, then count fittings, measure lengths and measure areas with the tools at the top left of the block. Corners snap to the lines of a PDF plan, and one tool cuts a shape out of an area, like a window out of a wall. The table under the plan shows what each measure comes to, and its headings sort and search it. A button makes the block fill the window, so that the plan is as big as it can be. `pages/welcome.md` has one to try, and `takeoff.jl` says how the block is written.

Kaydown works with [Centient](https://centient.com.au) if it's on your Mac. Two buttons under the table start a measure. **Add a measure** asks for a few words that describe what it measures, and its item is defined later, in Centient. **Add from catalogue** asks for a specific item from Centient, with its price: one of your own items, or a product from a supplier's catalogue that you choose with ⌥. The item's unit says what the measure is, and chooses the tool: a length for an item sold by the metre, an area for one sold by the square metre, and a count for the rest. **Make quote in Centient** makes a quote in Centient's books with a line for each measure. Centient's app doesn't have to be open.

Kaydown doesn't read Centient's books itself. It starts Centient's MCP server, `sidecar/mcp_server.jl` in Centient's folder, and that program runs Centient's own commands. `centient.jl` says where Kaydown looks for it. To use a Centient that's somewhere else, set `CENTIENT_SIDECAR` to its `sidecar` folder.

A window of Centient that's open doesn't show the new quote until it loads its list of sales again.

## Plan the tasks of a page

A code block in the language `schedule` finds every to-do item of its page, and shows each one as a bar on a line of days. Drag the right end of a bar to say how many working days the task takes. Drag from the circle after a bar to another task, and that task waits for this one. Drag a bar to say the first day that its task can start. A button makes the block fill the window. The block's lines hold what you set, by the name of each task, and `schedule.jl` says how they're written.

On a page with a schedule, a to-do item reads as it always does. Move the mouse over it, and the task's days show at the end of its line, with a button each side of them that makes the task a day shorter or longer. `pages/schedule.md` has a schedule to try.

## Test it

```sh
julia -O0 --project=. test/takeoff_test.jl        # how a takeoff is read, written and worked out
julia -O0 --project=. test/centient_test.jl       # how Kaydown talks to Centient's server
julia -O0 --project=. test/takeoff_view_test.jl   # the block itself, in a window that isn't on the screen
julia -O0 --project=. test/zoom_test.jl           # a picture, a diagram or a page that fills the window
julia -O0 --project=. test/schedule_test.jl       # how a schedule is read, written and worked out
julia -O0 --project=. test/schedule_view_test.jl  # the schedule's bars and links, in a window that isn't on the screen
julia -O0 --project=. test/project_page_test.jl   # a video or a sound on the web, and the button that makes a job in Centient
julia -O0 --project=. test/outcome_test.jl        # the code that ⌘Return runs in a `julia` block, and the box of what it comes to
julia -O0 --project=. test/names_test.jl          # the list of names that a code block offers while you type
julia -O0 --project=. test/code_file_test.jl      # a Julia file that the page changes, as one block of code
julia -O0 --project=. test/code_settings_test.jl  # the settings of code: long lines, line numbers, the guide, the indent, the font and size
julia -O0 --project=. test/weight_test.jl         # the weights of the page's text and of code: the weights a font has, bold text, the settings file
julia -O0 --project=. test/keys_test.jl           # the key bindings: the commands, the bundles of shortcuts and the page that changes them
julia -O0 --project=. test/highlight_test.jl      # the colours of the parts of a line of code, and of the code in a string
julia -O0 --project=. test/detail_test.jl         # what the box of a function and of a module shows when it's open
julia -O0 --project=. test/update_test.jl         # the app's own updates: a newer version comes, is checked and takes the app's place
julia -O0 --project=. test/window_test.jl         # the settings window, ⌘W, and the settings that every window shares
julia -O0 --project=. test/title_test.jl          # the menu of the file's name in the top bar
julia -O0 --project=. test/selection_test.jl      # where the colour of the selection goes
julia -O0 --project=. test/spelling_test.jl       # the red dots under a word that's spelt wrong, and what the page's menu does with it
julia -O0 --project=. test/sound_test.jl          # a line that holds only a sound file, and the Transcribe button under its player
julia -O0 --project=. test/video_test.jl          # a line that holds only a video file. It needs ffmpeg to make the video.
julia -O0 --project=. test/html_test.jl           # the page of HTML that ⌘⇧E saves
julia -O0 --project=. test/merge_test.jl          # your changes and an agent's changes to one page put together, and how the two talk
julia -O0 --project=. test/pasteboard_test.jl     # what the Mac's clipboard holds: text, files and pictures
julia -O0 --project=. test/media_folder_test.jl   # the hidden folder for the files that a page makes, and the hidden files in the sidebar
```

The tests are in the `test` folder. Run them from Kaydown's folder, as above. The first three need no Centient. `test/centient_fake.jl` answers in its place.

`-O0` tells Julia not to optimise the code that it compiles while a test runs, so a test starts in about half the time. The compiled files that Kip keeps are still made with full optimisation, so the app runs at its usual speed.

## Change it

Kaydown loads UI.jl by its GitHub path. To use your own copy of UI.jl, link it once:

```julia
using Kip
Kip.link("/path/to/UI.jl")
```

To write down what's said in a recording, Kaydown runs `transcribe.swift`, which uses the speech recognition in macOS 26 and later. Run from the source, Kaydown compiles it the first time, so it needs Swift, which comes with Xcode's command line tools. The app has it compiled already.

UI.jl has a script that runs an app and reloads each file when you save it:

```sh
julia --project=. ../UI.jl/examples/hot_reload.jl main.jl pages/components.md
```

## Build the app

```sh
julia --project=. app/build.jl             # writes build/Kaydown.app
julia --project=. app/build.jl --install   # and copies it into /Applications
```

The app runs without Julia installed. It is signed for your Mac only. `app/bundle.jl` lists what the build needs and the settings it takes.

The build uses the same copy of UI.jl that `main.jl` runs with: your UI.jl folder if it has changes that aren't committed, or its last commit if not. It prints a line when it builds from uncommitted changes. `release.jl --publish` stops if there are any.

## Make a release

1. Change the version in the `VERSION` file, and commit. Write it with three numbers, like `0.2.0`.
2. Run `julia --project=. release.jl`. It builds the app, signs it with a Developer ID certificate and has Apple notarise it. It writes `build/Kaydown-<version>.zip` and `build/latest.txt`.
3. Open the app from the zip file to check it.
4. Run `julia --project=. release.jl --publish`. It builds again, then tags the commit and puts the two files on GitHub as a release.

The top of `release.jl` says how to store your Apple account for the notarising step. You do that once.

The release goes to the GitHub repo that `update.jl` names as `REPO`. That repo must be public, because each copy of the app reads it without an account.

## How the app updates itself

A copy of the app from a release looks for a newer release when it opens, and once a day after that. It reads `latest.txt` from the newest release, which names the version and its zip file. If the version is newer, the app gets the zip file while you work, and checks that the app in it has the signature of the same developer as itself. The new app takes the old one's place after you quit Kaydown. The settings page has a box that turns this off, a line that says how far an update has got, and a button to look for one now.

An app that `app/build.jl` built is signed for your Mac only, and doesn't update itself. `update.jl` says how it all works, and how to try an update without a release.
