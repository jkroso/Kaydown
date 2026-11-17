# Kaydown

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it. A line keeps that look while you type. ⌘E, or the switch at the top right, shows the markup of the part of the page that the caret is in.

A code block does more than show code. What it does depends on its language:

- `ui` runs its Julia code and shows what the code makes.
- `julia` runs the line that the caret is in when you press ⌘Return, and shows what it comes to in a box after the line. It offers the names in scope as you type.
- `sheet` works things out, a row at a time.
- `spreadsheet` is a grid of cells with formulas.
- `mermaid` shows a diagram, like a flowchart.
- `takeoff` shows a building plan that you measure from, and makes a quote from what you measure.
- `schedule` shows the page's to-do items as bars on a line of days, and you drag the bars to plan the work.
- `chart` draws the numbers of a table as bars, as lines or as a pie.
- `board` shows the page's to-do items as cards in columns, and you drag a card to move it.
- `sketch` is a drawing: lines by hand, arrows, boxes, ovals and words.
- `find` lists the lines that match in every page of a folder, like each to-do item that isn't ticked.
- `email` lists the emails with a person.
- `ask` is a question from an agent, with answers to click.
- `changes` shows a diff from an agent, with a button on each change that accepts or rejects it.

A file can define a kind of block too. [Make a kind of block of your own](#make-a-kind-of-block-of-your-own) says how.

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

- `examples.md` lists everything that Kaydown does, with a link to an example of each. Start there to see it all.
- `welcome.md` shows what the editor does.
- `components.md` has a live block for each of UI.jl's components.
- `julia.md` has code to run with ⌘Return.
- `schedule.md` has a schedule to try.
- `settings.md`, `code-editor.md`, `key-bindings.md` and `email.md` are the four pages of the settings window.

## Use it with an agent

An agent like Claude Code can show you a page in Kaydown and read what you change in it. The agent writes a Markdown file, opens it in Kaydown and waits. You read the page, tick a box or type a note, and click the bell at the top right, or press ⌘Return. That button is called "Nudge Claude". The agent gets the lines that you changed. The agent can change the page while you read it, and Kaydown keeps what you're typing.

Two kinds of block are for an agent to write. A code block in the language `ask` is a question: its first lines are the question, a line that starts with `( )` is an answer that you choose one of, and a line that starts with `[ ]` is an answer that you choose any number of. You click an answer, or type in the field under them, and Kaydown writes that into the block. A code block in the language `changes` holds a diff, and shows each change with an Accept and a Reject button. Kaydown writes `[accepted]` or `[rejected]` at the end of the change's `@@` line, and changes no other file. Either way, the agent reads your answer in the lines that you changed. While an agent waits, a question has a Send button. `ask.jl` and `changes.jl` say how the blocks are written.

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

## Draw a table's numbers

A code block in the language `chart` draws the numbers of a table of the page: a table, a spreadsheet or a sheet. With nothing in the block, it draws the table that's nearest above it, as bars. The buttons at the top of the chart make it lines or a pie. The mouse over a bar says its number.

````
| Month | Sales | Costs |
|---|---|---|
| July | $4,200 | $2,900 |
| August | $5,100 | $3,100 |

```chart
title: Sales and costs
```
````

A line in the block can say more:

- `kind: lines` or `kind: pie` chooses the kind.
- `show: Sales` draws only that column. Without it, the chart draws each column of numbers.
- `by: Month` names the column whose words go under the bars.
- `from: Budget` draws the first table under the heading "Budget".

A chart can hold its own rows too, with a `|` between the cells. `chart.jl` says how the block is written.

## Move the tasks of a page across a board

A code block in the language `board` shows every to-do item of its page as a card, in the columns To do, Doing and Done. Drag a card to another column. The last column holds the items that are ticked: a card that you drop there ticks its item in the page, and a card that you drag out of it takes the tick away. Click a card twice to go to its item. The line `columns: Later, This week, Done` in the block names other columns. The block's lines hold the column of each card, and `board.jl` says how they're written.

## Draw a sketch

A code block in the language `sketch` is a drawing. The buttons at its top are the tools: one selects a shape, and the others draw by hand, a line, an arrow, a box, an oval and words. The dots choose a colour. Drag in the sketch to draw. With the first tool, click a shape to select it, drag it to move it, and press Delete to take it away. Each shape is a line of the block, so ⌘Z takes back the last thing you drew. `sketch.jl` says how the lines are written.

## List what's in the pages of a folder

A code block in the language `find` lists the lines that match in every page of its page's folder, and of the folders in that one. The name of each page is over that page's lines.

- An empty block lists each to-do item that isn't ticked.
- Words in the block list the lines that have every one of those words.
- `what: headings` lists headings, and `what: done items` lists the to-do items that are ticked.
- `in: jobs` looks only in the folder `jobs` beside the page.

Click a line of the list to open its page at that line. Click the box of a to-do item to tick it in its own page. If that page isn't open in Kaydown, or is open with nothing to save, Kaydown writes the tick to the page's file at once. That's the one time that Kaydown writes to a file without ⌘S. `find.jl` says how the block is written.

## Read and write email

Kaydown can keep a folder on your Mac that holds every email of an account. It can do that for more than one account, each in a folder of its own. The folder has the same folders in it as your email server has, and each email is one `.eml` file:

```
~/Mail/you@example.com/
  Inbox/
    2026-11-14 0932 Sam Lee - Roof quote.eml
  Sent/
  Drafts/
    Re Roof quote.md
```

An `.eml` file holds the email exactly as the server sent it, with what was attached to it inside. Mail, Quick Look and Spotlight read it too. Kaydown shows it as a page: the subject and who sent it at the top, then the email's text as Markdown, then a link to each attached file. You read that page, and you can't change it. Kaydown marks each email file as read-only on your Mac, so no other app changes one by mistake. A click on a link in an email opens it, with no key held. Because the file is the whole email, a later Kaydown can show it better with no new download.

1. Press ⌘, and click the Email tab.
2. Type your email address, your name and your password, and click Connect.
3. Press ⌘⇧I to show the inbox.

Kaydown knows Gmail, iCloud, Yahoo, AOL, Fastmail and Telstra by the address, and needs no servers for them. It also knows an address at a domain of your own whose email one of them holds, like a business address at Google. The form says which password the company takes. Gmail, iCloud, Yahoo, AOL and Fastmail take an app password: a password that you make for one app. A button opens the page that makes one. For any other address, the form shows the two servers to check. Kaydown keeps the password in the Mac's Keychain. Your email goes in a folder named for your address. Kaydown makes that folder in `~/Mail`, unless you choose another folder in the form.

Kaydown gets your inbox first, then the other folders. The Email page has two settings for this: how far back the emails go, from a month to every email, and whether the other folders come. While emails come, the page shows a bar, how many emails have come and how long the rest take. Gmail lets an app get 2,500 MB of email in a day, so Kaydown stops before that and goes on a day later.

In a folder of emails, the sidebar lists the emails, newest first. A click shows an email, and marks it as read. The top bar of an email has buttons that answer it, send it on, archive it and delete it. A right-click on an email in the list has the same, and marks it as not read.

An email that you write is a Markdown page. ⌘⇧N starts one in a window of its own, with `to` and `subject` at its top. Write it as you write any page. A line that holds only a link to a file sends the file with the email. ⌘⇧Return sends it. The email that went is then kept as an `.eml` file in the folder of sent email, and the draft goes.

The server is the one that's right. An email that another app deletes goes from the folder, and an email file that the Finder moves or deletes comes back. Each folder has a hidden list of its emails, which is only a copy: if it's lost, Kaydown makes it again from the files and the server, with no new download. `mail.jl` says how it works, and `mime.jl` how an email becomes a page.

To add another account, click Add an account on the Email page, type its address and its password, and click Connect. The row over the form has each account's address, and a click on one shows that account. A new email goes from the account whose folder the sidebar shows, and an answer goes from the account that got the email. Remove this account takes an account away from Kaydown, and leaves its emails in their folder.

It works with a server that takes a password. Outlook.com and Microsoft 365 only let an app sign in through Microsoft's own sign-in page, and Proton Mail needs its Bridge app. Kaydown works with neither yet, and the form says so.

### The emails with someone, in a page

A code block in the language `email` lists the emails with a person, newest first, from every folder but the drafts, the junk and the trash. Write a name or an address in it:

````
```email
with: sam@example.com
about: roof
```
````

`with` can name several people, with a comma between two of them. `about` lists only the emails whose subject has those words. A click opens an email. The Reply button starts an answer to the newest one, and New email starts one to the block's address. `emails.jl` says how the block is written.

## Make a kind of block of your own

A code block in a language that Kaydown doesn't know can show as a component, if a file defines the language. The file has a function with the language's name. Kaydown gives that function the lines of the block, and shows what it makes.

````
```progress
done: 0.7
label: Framing
```
````

This block is for `progress.jl` in the folder of its page. The file needs three things:

```julia
progress(lines)          # makes an object from the lines of the block
describe(p::Progress)    # draws the object, as UI.jl draws any node
written(p::Progress)     # the lines of the object's block now
```

- `progress` can return any value. A UI.jl node draws itself. Any other value shows as text.
- `written` is optional. With it, a block keeps what you do to it: Kaydown writes the lines that it gives into the block.
- Kaydown keeps the object until the block's lines change some other way: you type in them, or ⌘Z puts back older ones. Then it calls `progress` again.
- Kaydown loads the file again when you save it, and makes each of its blocks again. So a kind of block changes in the page as you write it.

Kaydown writes a block's lines at three times:

- **Before something reads the page's text.** That's ⌘S, the caret going into the block, a copy, a page of HTML, and another page taking the window. The file does nothing for this.
- **When the component asks.** It calls UI.jl's `changed!(p)`. Kaydown writes in the next frame that the mouse isn't held in, so a drag is one change. Writes less than a second apart are one step for ⌘Z.
- **At once.** The component calls `changed!(p, now=true)`, and Kaydown writes before that returns.

A change that only the first of these writes doesn't mark the page as edited until then, and ⌘Z can't take it back. So call `changed!(p)` after each change that you'd want to take back, as `pages/progress.jl` does when you click its bar. Keep `now=true` for a change that can't wait.

The line that opens the block can name where the function comes from, after the language:

- ```` ```progress ```` is for `progress.jl` beside the page.
- ```` ```progress ./widgets.jl ```` is for a file that has another name, so one file can define many kinds of block.
- ```` ```progress github.com/sam/blocks ```` is for a repository on GitHub. [Kip](https://github.com/jkroso/Kip.jl) gets it, as it does for `@use`.
- ```` ```progress github.com/sam/blocks@v2 ```` is for the `v2` branch of that repository.

Kaydown's own kinds of block come first. A file can't change what a `board` or a `chart` shows.

Kaydown asks before it runs the code of a GitHub repository for the first time. The block shows the repository's name and a button, **Run the code**. Kaydown keeps the repositories that you allow in `~/Library/Application Support/Kaydown/repositories`. Take a line out of that file to make Kaydown ask again. Kaydown doesn't ask about a file on your Mac, as it doesn't ask about the code of a `ui` block.

`pages/progress.jl` is a kind of block to copy, and `pages/welcome.md` shows it. The comment over `FileBlock` in `main.jl` says how it works.

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
julia -O0 --project=. test/rich_test.jl           # rich text and plain text: where the caret stops, what ⌫ and Return do, and the switch in the top bar
julia -O0 --project=. test/spelling_test.jl       # the red dots under a word that's spelt wrong, and what the page's menu does with it
julia -O0 --project=. test/sound_test.jl          # a line that holds only a sound file, and the Transcribe button under its player
julia -O0 --project=. test/video_test.jl          # a line that holds only a video file. It needs ffmpeg to make the video.
julia -O0 --project=. test/html_test.jl           # the page of HTML that ⌘⇧E saves
julia -O0 --project=. test/merge_test.jl          # your changes and an agent's changes to one page put together, and how the two talk
julia -O0 --project=. test/pasteboard_test.jl     # what the Mac's clipboard holds: text, files and pictures
julia -O0 --project=. test/examples_test.jl       # the page that lists every example: each link goes somewhere, and nothing is left out
julia -O0 --project=. test/media_folder_test.jl   # the hidden folder for the files that a page makes, and the hidden files in the sidebar
julia -O0 --project=. test/chart_test.jl          # how a chart is read and written, and where its bars, lines and slices go
julia -O0 --project=. test/chart_view_test.jl     # the chart of a table, a spreadsheet and a sheet, in a window that isn't on the screen
julia -O0 --project=. test/ask_test.jl            # how a question and its answers are read and written
julia -O0 --project=. test/ask_view_test.jl       # a question in the page: a click on an answer, and the field to type in
julia -O0 --project=. test/changes_test.jl        # how a diff is read, and how your choices are written into it
julia -O0 --project=. test/changes_view_test.jl   # the changes of a diff in the page, and the buttons that accept and reject them
julia -O0 --project=. test/board_test.jl          # how a board is read and written, and the column of each to-do item
julia -O0 --project=. test/board_view_test.jl     # the cards of a board, and a drag from one column to another
julia -O0 --project=. test/find_test.jl           # how a list of what's found is read and written, and which lines match
julia -O0 --project=. test/find_view_test.jl      # the list in the page, and a tick that goes to another page's file
julia -O0 --project=. test/sketch_test.jl         # how a sketch is read and written, and what a click is on
julia -O0 --project=. test/sketch_view_test.jl    # the tools of a sketch: drawing, moving and deleting shapes
julia -O0 --project=. test/file_block_test.jl     # a kind of block that a file defines: what it shows, and what goes back into its lines
julia -O0 --project=. test/emails_test.jl         # how a list of emails is read and written, and which emails it asks for
julia -O0 --project=. test/emails_view_test.jl    # the list of the emails with a person, in a page
julia -O0 --project=. test/mime_test.jl           # how an email becomes the page that a window shows, and a page an email
julia -O0 --project=. test/mail_test.jl           # the folder of emails that's kept in step with an email server, and sending
julia -O0 --project=. test/mail_view_test.jl      # the list of emails, the buttons of an email and of a draft, and the Email page of the settings
```

The tests are in the `test` folder. Run them from Kaydown's folder, as above. The first three need no Centient. `test/centient_fake.jl` answers in its place. The last two use no network and no email account. `test/mail_fake.jl` is a pretend email server that runs in the test.

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
