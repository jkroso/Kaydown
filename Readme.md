# Kaydown

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it. A code block in the language `ui` runs its Julia code and shows what the code makes. In a code block in the language `julia`, ⌘Return runs the line that the caret is in, and shows what it comes to in a box after the line. A code block in the language `sheet` works things out, a row at a time. A code block in the language `spreadsheet` is a grid of cells with formulas. A code block in the language `mermaid` shows a diagram, like a flowchart. A button beside a diagram, a picture or a page of a PDF file makes it fill the window, where you zoom it with a pinch. A code block in the language `takeoff` shows a building plan that you measure from, and makes a quote from what you measure. A code block in the language `schedule` shows the page's to-do items as bars on a line of days, and you drag the bars to plan the work. A line that holds only a sound file shows a player, and the page's Insert menu records one from the microphone. A button under the player writes down what's said in it, on the Mac.

"Kaydown" is a working name, after Alan Kay.

## Run it

You need Julia and [Kip](https://github.com/jkroso/Kip.jl).

```sh
julia --project=. main.jl                # opens the welcome page
julia --project=. main.jl ~/notes        # opens a file or a folder
```

`pages/welcome.md` shows what the editor does. `pages/components.md` has a live block for each of UI.jl's components.

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

A code block in the language `takeoff` shows a page of a PDF file, or a picture. Drop the file on the block. Set the scale, then count fittings, measure lengths and measure areas with the tools at the top left of the block. The table under the plan shows what each measure comes to, and its headings sort and search it. A button makes the block fill the window, so that the plan is as big as it can be. `pages/welcome.md` has one to try, and `takeoff.jl` says how the block is written.

Kaydown works with [Centient](https://centient.com.au) if it's on your Mac. Each measure can have an item from Centient, with its price: one of your own items, or a product from a supplier's catalogue that you choose with ⌥. The item's unit says what a new measure is, and chooses the tool: a length for an item sold by the metre, an area for one sold by the square metre, and a count for the rest. **Make quote in Centient** makes a quote in Centient's books with a line for each measure. Centient's app doesn't have to be open.

Kaydown doesn't read Centient's books itself. It starts Centient's MCP server, `sidecar/mcp_server.jl` in Centient's folder, and that program runs Centient's own commands. `centient.jl` says where Kaydown looks for it. To use a Centient that's somewhere else, set `CENTIENT_SIDECAR` to its `sidecar` folder.

A window of Centient that's open doesn't show the new quote until it loads its list of sales again.

## Plan the tasks of a page

A code block in the language `schedule` finds every to-do item of its page, and shows each one as a bar on a line of days. Drag the right end of a bar to say how many working days the task takes. Drag from the circle after a bar to another task, and that task waits for this one. Drag a bar to say the first day that its task can start. A button makes the block fill the window. The block's lines hold what you set, by the name of each task, and `schedule.jl` says how they're written.

On a page with a schedule, a to-do item reads as it always does. Move the mouse over it, and the task's days show at the end of its line, with a button each side of them that makes the task a day shorter or longer. `pages/schedule.md` has a schedule to try.

## Test it

```sh
julia --project=. takeoff_test.jl        # how a takeoff is read, written and worked out
julia --project=. centient_test.jl       # how Kaydown talks to Centient's server
julia --project=. takeoff_view_test.jl   # the block itself, in a window that isn't on the screen
julia --project=. zoom_test.jl           # a picture, a diagram or a page that fills the window
julia --project=. schedule_test.jl       # how a schedule is read, written and worked out
julia --project=. schedule_view_test.jl  # the schedule's bars and links, in a window that isn't on the screen
julia --project=. project_page_test.jl   # a video or a sound on the web, and the button that makes a job in Centient
julia --project=. merge_test.jl
julia --project=. pasteboard_test.jl
```

The first three need no Centient. `centient_fake.jl` answers in its place.

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

1. Change the version in the `VERSION` file, and commit.
2. Run `julia --project=. release.jl`. It builds the app, signs it with a Developer ID certificate and has Apple notarise it. It writes `build/Kaydown-<version>.zip`.
3. Open the app from the zip file to check it.
4. Run `julia --project=. release.jl --publish`. It builds again, then tags the commit and puts the zip file on GitHub as a release.

The top of `release.jl` says how to store your Apple account for the notarising step. You do that once.
