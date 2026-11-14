# Kaydown

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it. A code block in the language `ui` runs its Julia code and shows what the code makes. A code block in the language `sheet` works things out, a row at a time. A code block in the language `spreadsheet` is a grid of cells with formulas. A code block in the language `mermaid` shows a diagram, like a flowchart. A line that holds only a sound file shows a player, and the page's Insert menu records one from the microphone. A button under the player writes down what's said in it, on the Mac.

"Kaydown" is a working name, after Alan Kay.

## Run it

You need Julia and [Kip](https://github.com/jkroso/Kip.jl).

```sh
julia --project=. main.jl                # opens the welcome page
julia --project=. main.jl ~/notes        # opens a file or a folder
```

`pages/welcome.md` shows what the editor does. `pages/components.md` has a live block for each of UI.jl's components.

## Use it with an agent

An agent like Claude Code can show you a page in Kaydown and read what you change in it. The agent writes a Markdown file, opens it in Kaydown and waits. You read the page, tick a box or type a note, and click the paper plane at the top right, or press ⌘Return. That button is called "Nudge Claude". The agent gets the lines that you changed. The agent can change the page while you read it, and Kaydown keeps what you're typing.

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
