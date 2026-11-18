# Ladder

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it. A line keeps that look while you type. ⌘E, or a click on the ladder at the top right, goes down a level: the part of the page that the caret is in shows its markup. A snake takes the ladder's place, and a click on it goes back up. Hold the mouse over the ladder and it opens into a slider, with the snake at its low end, the ladder at its high end, and a stop for each level that the window can show at. A page has two levels. A file of text that Ladder only shows has three: its bits, its bytes in hexadecimal, and its text. A JSON file has the tree of its values over those, and a CSV file has its table. In a file of Julia code, the levels are of what the code comes to when you run it with ⌘Return. At the highest level, the box after the code shows its value. A level down it shows the code as Julia infers it, with the type of each step. Under that it shows the LLVM code, and under that the assembly with the machine code of each instruction. The file's own code shows as it's written at every level. A `julia` code block of a page has the same four levels. Each block has a level of its own, and while the caret is in a block the ladder is that block's: the top bar asks the part of the page that the caret is in for its levels. Click a stop, or drag along the slider, to go to a level. While a block fills the window, like a takeoff or a schedule, ⌘E goes down to the lines of that block: they fill the window as text, with the caret in them. ⌘E again makes the block fill the window again, and Esc puts the lines back among the lines of the page.

A code block does more than show code. What it does depends on its language:

- `ui` runs its Julia code and shows what the code makes.
- `julia` runs the line that the caret is in when you press ⌘Return, and shows what it comes to in a box after the line. It offers the names that code at the caret can use as you type, and says what each one is: the type of a value, or `function`, `struct`, `module` or `macro`.
- In any code, a bracket or a quote that you type comes with the one that closes it, and the caret stays between the two. With text selected, the pair goes round the text. The two brackets that the caret is between glow.
- `sheet` works things out, a row at a time.
- `spreadsheet` is a grid of cells with formulas.
- `mermaid` shows a diagram, like a flowchart, a mind map or a Gantt chart.
- `takeoff` shows a building plan that you measure from, and makes a quote from what you measure.
- `schedule` shows the page's to-do items as bars on a line of days, and you drag the bars to plan the work.
- `chart` draws the numbers of a table as bars, as lines or as a pie.
- `board` shows the page's to-do items as cards in columns, and you drag a card to move it.
- `calendar` shows a month, with the page's tasks, its to-do items that have a day, and events of its own.
- `columns` holds a number, and shows that many of the blocks after it side by side.
- `sketch` is a drawing: lines by hand, arrows, boxes, ovals and words.
- `signature` is a place to sign: a person draws their signature in a box, and the page says who signed and when.
- `contact` is the card of a person or a company. A click on its email address starts an email, and a vCard file from the Contacts app makes one.
- `gallery` shows the pictures of a folder as a grid of small squares, and a click makes one fill the window.
- `map` shows the map of a place, with a pin on the place.
- `find` lists the to-do items that aren't ticked in every page of a folder. With words in it, it lists the lines that have those words. It can list another kind of line, or a kind of block, like every takeoff.
- `timelog` keeps the hours that you work on each task, with a button that starts and stops the clock.
- `ask` is a question from an agent, with answers to click.
- `changes` shows a diff from an agent, with a button on each change that accepts or rejects it.

A file can define a kind of block too. [Make a kind of block of your own](#make-a-kind-of-block-of-your-own) says how.

A page shows more than text:

- A quote whose first line is `> [!NOTE]` shows as a callout: a note that stands out, with an icon and a colour of its own. The other kinds are `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and `[!CAUTION]`. GitHub reads the same lines the same way. Words after the `]` are the callout's title.
- A formula that's written in TeX between dollar signs shows as maths: `$x^2$` in a line of text, and on lines of its own between a line of `$$` and another.
- A line that holds only a CSV file shows the file as a table. [Show a CSV file as a table](#show-a-csv-file-as-a-table) says more.
- A line that holds only a picture, a video or a sound file shows it, or a player for it. The page's Insert menu records a sound from the microphone, and a button under the player writes down what's said in it, on the Mac.
- A line that holds only the address of a web page, written as a picture is, like `![Julia](https://julialang.org)`, shows the page as a card. [Show a web page as a card](#show-a-web-page-as-a-card) says more.
- A button beside a diagram, a picture or a page of a PDF file makes it fill the window, where you zoom it with a pinch.
- A diagram that fills the window can be changed there. Click a box or a line to select it, click it twice to type its words, drag the point on a box's edge onto another box to draw a line, and use the buttons under it to add a box, draw a line, change a shape or take a part away. Each change is written in the code of the block.
- A Julia file opens as one block of code, which you change and run as you do a `julia` block. There, the box of a value that's a part of a window lists the value's fields and its children.
- ⌃⌘⇧P shows the page as slides, one at a time, for when you show a plan to someone. [Show a page as slides](#show-a-page-as-slides) says how.

## Get the app

1. Download `Ladder-<version>.zip` from the [newest release](https://github.com/jkroso/Ladder/releases/latest).
2. Open the zip file.
3. Move Ladder to your Applications folder, and open it.

The app needs a Mac with Apple silicon, and macOS 12 or later. To write down what's said in a recording, it needs macOS 26 or later. It opens on its welcome page, which shows what the editor does.

The app updates itself. [How the app updates itself](#how-the-app-updates-itself) says how, and how to turn that off.

## Run it from the source

You need Julia and [Kip](https://github.com/jkroso/Kip.jl).

```sh
julia --project=. main.jl                # opens the welcome page
julia --project=. main.jl ~/notes        # opens a file or a folder
```

The `pages` folder has the pages that come with Ladder:

- `examples.md` lists everything that Ladder does, with a link to an example of each. Start there to see it all.
- `welcome.md` shows what the editor does.
- `components.md` has a live block for each of UI.jl's components.
- `julia.md` has code to run with ⌘Return.
- `schedule.md` has a schedule to try.
- `counter.md` defines a kind of block, and shows it.
- The `settings` folder has the pages of the settings. ⌘, shows `settings.md`, which has a link to each of the others: `code-editor.md`, `key-bindings.md` and `startup.md`, your startup page.

## Use it with an agent

An agent like Claude Code can show you a page in Ladder and read what you change in it. The agent writes a Markdown file, opens it in Ladder and waits. You read the page, tick a box or type a note, and click the bell at the top right, or press ⌘Return. That button is called "Nudge Claude". The agent gets the lines that you changed. The agent can change the page while you read it, and Ladder keeps what you're typing.

Two kinds of block are for an agent to write. A code block in the language `ask` is a question: its first lines are the question, a line that starts with `( )` is an answer that you choose one of, and a line that starts with `[ ]` is an answer that you choose any number of. You click an answer, or type in the field under them, and Ladder writes that into the block. A code block in the language `changes` holds a diff, and shows each change with an Accept and a Reject button. Ladder writes `[accepted]` or `[rejected]` at the end of the change's `@@` line, and changes no other file. The lines of a change have the colours of code in the language of their file, which Ladder knows from the end of the file's name. Where a line that comes is another version of a line that goes, a darker mark shows the words that are different. A line that's too long goes on under itself. Two buttons at the top of the block choose how the lines show: the new lines under the old lines, or the old lines at the left and the new lines at the right. That choice is a setting, so every block of changes in every window shows the same way. A block that's less than 600 px wide always shows the new lines under the old. A click on a line of a change opens a field under it, for what you say to the agent about that line. Ladder writes your words at the end of the block as you type them, in two lines that start with `#`: the first says which change and which of its lines you mean, and the second has your words. `git apply` reads past those lines. Return closes the field, and Esc puts back what the comment said before. A comment shows under its line. A click on it opens it again, and the bin beside the field takes it away. Either way, the agent reads your answer in the lines that you changed. The bell in the top bar sends them, and so does ⌘Return. `ask.jl` and `changes.jl` say how the blocks are written.

The `plugin` folder is a plugin for Claude Code. It has a skill that tells Claude when and how to show a page, and a command, `ladder`, that the skill runs. To install it, type these in Claude Code:

```
/plugin marketplace add jkroso/Ladder
/plugin install ladder@ladder
```

For another agent, put `plugin/bin` on your `PATH` and give the agent `plugin/skills/page/SKILL.md` to read.

```sh
ladder show plan.md    # opens the page in Ladder
ladder wait plan.md    # waits until you press Nudge Claude, then prints the lines that you changed
```

The top of `agent.jl` says how the command and Ladder talk to each other.

## Draw a diagram

A code block in the language `mermaid` shows the diagram that its lines describe, in the language of [Mermaid](https://mermaid.js.org). The first line says which kind it is. Ladder draws nine kinds:

- `flowchart` (or `graph`): boxes with arrows between them.
- `sequenceDiagram`: the messages that people or programs send each other, in order.
- `stateDiagram-v2`: the states of a thing, and what takes it from one to the next.
- `classDiagram`: the classes of a program, and how they're related.
- `pie`: a circle cut into slices.
- `mindmap`: one idea in the middle, with the ideas that belong to it on its left and its right. A line that starts further in belongs to the line above it. An idea can have a shape: `[a box]`, `(a round box)`, `((a circle))`.
- `erDiagram`: the tables of a database as boxes, each with rows like `string name PK "a comment"`, and lines between them. The signs at the ends of a line say how many there are, in the crow's-foot way: `||--o{` is from exactly one to none or more.
- `gantt`: tasks as bars on a line of days, in sections. A task is `Name :done, id, 2024-03-04, 3d`. It can start `after` another task's id, and `excludes weekends` leaves Saturday and Sunday out.
- `timeline`: periods from left to right, each with its events under it: `2024 : An event : Another one`.

A diagram has the page's colours and font, and it's drawn smaller when the page is narrower than it. A kind that Ladder can't draw, and code with a line that it can't read, shows as code. The page of HTML that ⌘⇧E saves has each diagram as a picture. A diagram of the first five kinds can be changed while it fills the window. The last four are changed in their code. `pages/welcome.md` has an example of each of the last four, and the file of each kind in UI.jl's `Interface/Semantic/Mermaid` folder says what its code can have.

## Measure from a plan

A code block in the language `takeoff` shows a page of a PDF file, or a picture. Drop the file on the block. Set the scale, then count fittings, measure lengths and measure areas with the tools at the top left of the block. Corners snap to the lines of a PDF plan, and one tool cuts a shape out of an area, like a window out of a wall. The table under the plan shows what each measure comes to, and its headings sort and search it. A button makes the block fill the window, so that the plan is as big as it can be. `pages/welcome.md` has one to try, and `takeoff.jl` says how the block is written.

Ladder works with [Centient](https://centient.com.au) if it's on your Mac. Two buttons under the table start a measure. **Add a measure** asks for a few words that describe what it measures, and its item is defined later, in Centient. **Add from catalogue** asks for a specific item from Centient, with its price: one of your own items, or a product from a supplier's catalogue that you choose with ⌥. The item's unit says what the measure is, and chooses the tool: a length for an item sold by the metre, an area for one sold by the square metre, and a count for the rest. **Make quote in Centient** makes a quote in Centient's books with a line for each measure. Centient's app doesn't have to be open.

Ladder doesn't read Centient's books itself. It starts Centient's MCP server, `sidecar/mcp_server.jl` in Centient's folder, and that program runs Centient's own commands. `centient.jl` says where Ladder looks for it. To use a Centient that's somewhere else, set `CENTIENT_SIDECAR` to its `sidecar` folder.

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

## Show a CSV file as a table

A line that holds only a link to a CSV file, written as a picture is, shows the file as a table:

```
![Prices](prices.csv)
```

- The path starts at the page's folder. A `.tsv` file works the same way.
- The first row of the file has the names of the columns. A column of numbers has its text on the right.
- The table looks like a table of the page, but you can't type in it. The numbers are the file's.
- A small line over the table has the words of the link and the file's name.
- A long file shows its first 30 rows. A line under them says how many more there are. Click it to see them all.
- When the file changes on the disk, the table shows the new numbers.
- A file that isn't there, or that isn't a table, shows a line that says so.
- Click the table to see its line as it's written. The caret goes onto the table as a whole, as it does onto a picture.
- A `chart` block draws the table that's nearest above it, and a line like this counts as a table.
- `from: prices.csv` in a chart draws the file's numbers from anywhere in the page.
- ⌘⇧E writes the file's rows into the page of HTML, as a table.
- A CSV file that you drop on the page goes in as a line like this.

Ladder reads a comma, a tab or a semicolon as the mark between two cells. A cell in quotes can hold the mark, a quote written twice, and a line break. Ladder reads the first 5,000 rows and the first 40 columns of a file. `csv.jl` reads the file, and `pages/welcome.md` has a table to try.

## Move the tasks of a page across a board

A code block in the language `board` shows every to-do item of its page as a card, in the columns To do, Doing and Done. Drag a card to another column. The last column holds the items that are ticked: a card that you drop there ticks its item in the page, and a card that you drag out of it takes the tick away. Click a card twice to go to its item. The line `columns: Later, This week, Done` in the block names other columns. The block's lines hold the column of each card, and `board.jl` says how they're written.

## See the days of a page on a month

A code block in the language `calendar` shows one month as a grid of days, from Monday to Sunday. Each day shows the things of the page that are on it:

- Each task of the page's `schedule`, on every working day that the task runs.
- Each to-do item that has a day in its text, like `- [ ] Order the tiles 2026-11-25`. An item that's ticked is fainter and has a tick. Such an item shows on that day only, and not on the days that the schedule gives it.
- Each event of the calendar's own. An event is a line of the block: a day, a `|`, and the event's words.

````
```calendar
month: 2026-11

2026-11-25 | Concrete pour
2026-11-27 | Council inspection
```
````

The arrows at the top go to the month before and the month after. Ladder writes the month that shows into the block, as `month: 2026-11`, so the file keeps it. **Today** takes that line away, and a block without it shows the month of today. Today's number is in a circle, and Saturday and Sunday are a little fainter.

- Click a thing to select it. Click it twice to go to its line of the page.
- Click the box of a to-do item to tick the item in the page.
- Drag a to-do item or an event to another day. Ladder writes the new day into the item's text or the event's line. A task doesn't move here: the schedule says when it's done.
- Click an empty part of a day twice to add an event there. Type its words and press Return. Esc leaves the event out.

A day has room for three things. A day with more shows two of them and how many more there are. Click those words, and the week grows to show them all. `calendar.jl` says how the block is written.

## Keep the hours of a job

A code block in the language `timelog` keeps the hours that you work on each task. Each line of the block is one stretch of work: the day, the time it started, a `-`, the time it stopped, a `|`, and the task. A line with no stop time is the one that runs now.

````
```timelog
rate: 85

2026-11-17 07:30-12:00 | Framing
2026-11-17 12:30-15:45 | Framing
2026-11-18 08:10- | Roofing
```
````

The block shows a row for each stretch, with its day, its times, its hours and its task. A day shows once, on the first of its rows. Under the rows are the total, and the hours of each task when the log has more than one.

- Type a task in the field at the top, and click Start. Ladder adds a line for now, with no stop time. An empty field starts the task of the last line.
- While a line runs, its row counts up, and the button is lit and reads Stop. Click it, and Ladder writes the time now into the line.
- Only one line runs at a time. To change to another task, type it and click Start, or press Return. Ladder stops the line that runs, and starts the new one.
- The field lists the tasks that the log already has, and fewer of them as you type. Click one, or pick one with ↓ and press Return, to put it in the field.
- Click a time or a task in a row to change it where it is. Return writes it into the line, and Esc leaves it as it was.

Two lines at the top of the block can say more:

- `rate: 85` is the dollars for each hour. The total and each task then show money too, like $1,105.00.
- `round: 15` rounds each stretch to the nearest 15 minutes when the hours are added up. The lines keep the true times.

Times are written with 24 hours, like `07:30`. Ladder also reads `7:30am` and `3:45pm`, and writes them with 24 hours. A stop time that's earlier than the start time is on the next day, so `22:00-01:30` is 3 h 30 min. A line that Ladder can't read shows in grey, as it's written, and counts for nothing. A `chart` block under a log draws the hours of each task. `timelog.jl` says how the block is written.

## Show a web page as a card

Write the address of a web page as you would a picture's, on a line of its own:

```
![Julia](https://julialang.org)
```

The line shows a card: the page's title, two lines of its description, its picture, and the name of its site beside the site's icon. Hold ⌘ and click the card to open the page in your browser. Click it with no key held to see the line as it's written, and change the address there. The page's Insert menu has a Link Card, which writes `![](https://)` and puts the caret after the `https://`.

What's at the address decides what the line shows:

- An address that ends as a picture's, a video's, a sound's or a CSV file's does, like `https://julialang.org/logo.png`, shows the picture, the player or the table, as it always did.
- Any other address shows a card when it's a web page. When it turns out to be a picture, like a picture whose address doesn't end in `.png`, the line shows the picture.
- The words between the `[` and the `]` are the card's title while the card has none: until the page comes, or when the page has no title.

A web address by itself stays text, and a link with words, like `[Julia](https://julialang.org)`, stays a link. An email shows no cards: each such line in it shows a picture.

Ladder gets each page once, in the background. It reads only the start of the page, and only what the page says of itself: its `og:title`, `og:description`, `og:image` and `og:site_name`, or its title and its description where those are missing. It keeps those texts and the picture in `~/Library/Caches/Ladder/cards`, so the card shows at once the next time, and with no network. Until the page comes, and when Ladder can't get it, the card shows the address. In a page of HTML, each card is a link in a box. `linkcard.jl` says how a page is read.

## Put blocks of a page side by side

A code block in the language `columns` holds a number. That many of the blocks after it show side by side, as columns of one width. The blocks stay the page's own lines, so you type in a column as you type anywhere else.

````
```columns
3
```

### Option A

Cheapest.

- Two days

### Option B

Lasts longer.

- Three days

### Option C

Both.

---

This paragraph is under the columns.
````

- A block is a paragraph, a list, a quote, a table, a code block, a picture, or a block like a diagram or a chart. Empty lines between blocks don't count.
- A heading takes the blocks under it into its column, up to the next heading of its level or a higher one. A lower heading, like `####` under `###`, stays in the column. Any other block is a column by itself.
- A line across the page (`---`) ends the columns, and so does another `columns` block. The line shows under the columns, as wide as the page.
- Several numbers are the share of the width of each column. `2 1` is two columns, and the first is twice as wide as the second. One number alone is always a count.
- When fewer columns follow than the number says, the columns that are missing keep their room.
- Each column wraps its text at its own width, and a table, a picture or a diagram in a column is made for that width. The columns line up at the top, with a gap between them.
- ← and → move the caret through the columns in the order of the file. ↑ and ↓ stay in one column, and leave the columns from its first and last line. A click puts the caret in the column under the mouse.
- In a narrow window, the blocks show one under another.

The `columns` block itself takes no room in the page, and shows nothing there. The caret steps over it. To change the number, press ⌘E, or click the ladder at the top right, and press ↑ from the first column. The block shows its lines while the caret is on them, and ⌘E again goes back up. A click on "Columns" in the sidebar's list of the page's headings puts the caret in the block too. A block that doesn't say how many columns shows a faint line with words that say how to write it. The language `column` means the same as `columns`.

The sidebar and a `find` block see the blocks in the columns as the page's own blocks, which they are. A page of HTML and a printed page show the columns too. `columns.jl` says how the block is written.

## Draw a sketch

A code block in the language `sketch` is a drawing. In the page it shows only the drawing. Click it, pinch outwards on it, or click the button that shows beside its top right corner, and it fills the window with its tools at the top. The buttons at its top are the tools: one selects a shape, and the others draw by hand, a line, an arrow, a box, an oval and words. The dots choose a colour. Drag in the sketch to draw. For words, click where they go, type them there and press Return. Click words twice with the first tool to change them where they are. With the first tool, click a shape to select it, drag it to move it, and press Delete to take it away. The shape that's selected glows, and has a circle on each of its corners or ends. Drag a circle to move that corner. The numbers after the dots say how the shape is drawn: how thick its line is, how round the corners of a box are, and how big words are. The buttons each side of a number change it, or click the number, type another and press Return. With a tool that draws, they change the shapes that you draw next. Esc chooses the first tool, and Esc with that tool puts the sketch back in the page. So does the last button at the top. ⌘E, or a click on the ladder, while the sketch fills the window shows the lines of its block as text. While a sketch, a takeoff, a schedule, the lines of one, a picture or a diagram fills the window, the sidebar isn't there, and the top bar has none of the sidebar's buttons: not the one that shows it, the eye or the two arrows. The file's name is in the middle of the window then. Each shape is a line of the block, so ⌘Z takes back the last thing you drew. `sketch.jl` says how the lines are written.

## Sign a page

A code block in the language `signature` is a place where a person signs the page with the mouse or the trackpad. A builder shows a client a quote in a page, and the client signs it there.

````
```signature
name: Sam Lee
```
````

The block shows a box with a line to sign on, and the name under it. A block with no `name:` line has a field under the box. Type the name there, and the block writes it as its `name:` line.

- Press in the box and drag to draw. Each stroke is a line of the block, so the file holds the signature, and ⌘Z takes back the last stroke.
- The first stroke writes the day and the time, as `signed: 2026-11-18 09:14`. From then on the block says "Signed by Sam Lee on 18 November 2026" under the signature.
- The first stroke must be a drag, so a click by mistake doesn't sign the page. After that, a click is a dot, like the one over an i.
- A stroke that leaves the box goes on when the mouse comes back. The page's text doesn't select meanwhile, and the page doesn't scroll.
- While the mouse is over a signed block, a Clear button shows under the box. It takes the strokes and the day away in one change, and ⌘Z brings them back.
- A page that can't be changed, like an email or a file that's read-only, takes no strokes.

The places of a stroke are in the box's own measure, 420 wide and 130 tall. So the signature keeps its shape when the text is bigger and when the window is narrow. The page of HTML and the printed page show the signature with who signed and when under it. `signature.jl` says how the lines are written.

## Keep the card of a person or a company

A code block in the language `contact` is the card of a person or a company. It shows a round picture, the name, and a row for each detail.

````
```contact
Ada Lovelace
role: Engineer
company: Analytical Engines
email: ada@example.com
mobile: 0400 123 456
address: 12 Example St, Sydney NSW 2000
web: example.com
photo: ada.jpg
note: Met at the 2026 conference.
ABN: 12 345 678 901

Analytical Engines
kind: company
email: hello@example.com
```
````

The first line of a contact is its name. Each other line is a label, a colon and a value. Capitals in a label don't matter.

- `role` and `company` show under the name, like "Engineer, Analytical Engines".
- `email`, `address`, `web` and `note` are a row each. `website` and `url` are other words for `web`.
- `phone` is a phone number. So are `mobile`, `work`, `home` and `fax`, and the row shows that word before the number.
- `photo` names a picture file, from the page's folder, or a picture on the web. Without it, the card shows the person's initials.
- `kind: company` says that the contact is a company. Its picture is a building, and it has no line under its name.
- Any other label, like `ABN`, is a row with the label and the value.

A label can be there more than once: two `email` lines are two rows. A line with no label is read by its shape: an email address, a web address, a phone number, or else a note. An empty line ends a contact, and the next line is the name of the next one. So a block can hold several contacts, and each one has a card.

- Click a row to use it. An email address starts a new email, a phone number starts a call, an address shows in the Maps app, and a web address opens in the browser.
- While the mouse is over a row, a button at its right end copies its value.
- Click the name, the role, the company or the value of a row twice to change it where it is. Return keeps the change, esc leaves it, and a click somewhere else keeps it. A value that you empty takes its line out of the block. A click on a row waits a moment before it opens anything, in case a second click comes.
- While the mouse is over a card, two buttons show at its top right. The + opens a menu: Email, Phone, Address, Website and Note. Choose one and type its value. The other button opens the contact in the Contacts app, which asks to add it.
- While the mouse is over the block, a button under the last card adds a contact.
- Drag a contact from the Contacts app onto the page, and the page gets a block with that contact. Dropped on a block of contacts, it joins that block. A vCard file (`.vcf`) from the Finder does the same, and so does ⌘V with a contact that you copied in the Contacts app.
- A page that can't be changed, like an email or a file that's read-only, takes no changes. Its rows still open and copy.

Each change is one step for ⌘Z. The page of HTML has a card for each contact, with links for the email address and the phone number, and the class names of the h-card microformat. `contact.jl` says how the lines are written, and reads and writes vCards.

## Show the pictures of a folder

A code block in the language `gallery` shows the pictures of a folder as a grid of small squares. Use it for the photos of a job site, in the job's page:

````
```gallery
in: photos
```
````

- `in: photos` names a folder beside the page. An empty block shows the pictures in the page's own folder.
- Any other line is the path of one picture, so a block can list its pictures by hand. A block with such lines and no `in:` line shows only those pictures.
- `sort: newest` puts the newest file first. Without it, the folder's pictures are in the order of their names, and photo 2 comes before photo 10.
- `size: small` or `size: large` sets how big the squares are. Without it, they're medium.

The grid has as many squares in a row as fit the page, with the same gap between them. Each square shows the middle of its picture, cut to fit. The top of the block says how many pictures there are and where they are. The button there changes the size of the squares, and writes the size into the block, so ⌘Z takes it back.

Click a picture, and it fills the window, as a picture in the text does. There, ← and → go to the picture before it and the next one, and Esc puts the page back. The bar under the picture says where it is in the gallery, like “2 of 6”, and the name of its file. The button on each side of those words goes to the picture before and to the next one. While the mouse is near the left or the right edge of the window, a large arrow shows there that does the same. At the first picture and the last, the button that has nowhere to go is faint. In the page, the mouse over a picture shows the name of its file.

Drop a picture on the gallery from the Finder, and Ladder copies it into the gallery's folder. A gallery that only lists its pictures gets a line for the picture, and the file stays where it is.

A big folder doesn't stop the window. macOS makes a small picture of each file, as it does for the Finder, and Ladder asks for a few of them in each frame. It builds only the rows of the grid that are in the window. It reads the folder again every few seconds, so a new photo shows by itself. `gallery.jl` says how the block is written.

## Show the map of a place

A code block in the language `map` shows the map round a place, with a pin on the place and the address under it. The map is as wide as the page's text.

````
```map
1 Macquarie Street, Sydney NSW 2000
```
````

- The first line is the place: an address, or a latitude and a longitude like `-37.7701, 144.9610`.
- The − and the + on the map show more and less of what's round the place. The block keeps that as a line like `zoom: 15`. Each step up shows half as much from side to side.
- Drag the map to move it. When you let go, the block keeps the middle of what shows as a line like `centre: -33.86120, 151.21010`. The pin stays on the place. `center` is read as the same word.
- Click the map to move the place. The pin goes where you clicked at once, and the block's first line becomes that point's latitude and longitude, like `-33.85930, 151.21320`. The map stays where it is. The address of the point shows under the map a moment later, when Apple has sent it.
- ⌘Z takes back a drag or a click.
- When the place isn't in the middle of the map, a third button beside the − puts it back there. It takes the `centre` line away.
- **Open in Maps** opens the Mac's Maps app at the place.
- The button that shows beside the map's top right corner makes the map fill the window, as a picture does. So does Return with the caret on the map.
- A page that can't be changed, like a file that's read-only, takes no drag and no click.
- The address under the map is the one that Apple has for the place. Check it: when Apple doesn't know an address, the pin can go on another address that's like it.
- Write a street address. The name of a place alone, like "Sydney Opera House", isn't enough for Apple to find it.
- Apple's maps find where an address is and make the picture, so the first map of a place needs the network. Until the picture is there, the block is a grey box. Ladder keeps each picture and each place on the Mac, so the map shows at once the next time, with no network. When Ladder can't get a picture, the block says so, and Ladder tries again a minute later.
- Ladder draws the pin itself, over the picture. A place that isn't in the part of the map that shows has no pin.
- A dark page has a dark map. The page of HTML that ⌘⇧E saves has the picture in it, with the address under it as a link to Apple Maps.

Ladder never asks where the Mac is, so macOS asks you for nothing. `map.jl` says how the block is written, and `map.swift` asks Apple's maps for the place and for the picture.

## List what's in the pages of a folder

A code block in the language `find` looks through every page of its page's folder, and of the folders in that one. It lists the lines that the block asks for, with the name of each page over that page's lines. The top of the list says what it lists, how many lines it found and where it looked, like "6 to-do items in 2 pages of this folder".

The top of the list changes what the block asks for, so you needn't see its lines:

- A field holds the words that a line must have. Type in it, and the list keeps only the lines that have every word. Return gives the keyboard back to the page.
- A button shows the kind of thing that the list is of. Click it, and a list of every kind floats under it. This is the list that a takeoff shows for the units of a measure.
- If the page has folders beside it, a second button shows the folder that the list looks in. Click it for the same kind of list, with those folders in it.

The list under a button has a field at its top, and the keyboard is in that field when the list opens. Type there, and the list keeps the rows that have what you typed. A kind is found by its other names too: "tasks" finds To-do items, and "images" finds Pictures. The up and down arrows pick a row, and so does the mouse. Return or a click takes the row. Esc, or a click somewhere else, closes the list and changes nothing.

The kinds are:

- The kinds of line: to-do items, done items, headings, lines, paragraphs, bullet points, numbered items, quotes and table rows.
- Links and pictures, which list the lines that have one.
- The kinds of block: code blocks, sheets, spreadsheets, live blocks, diagrams, takeoffs, schedules, charts, boards, calendars, columns, sketches, signatures, contacts, maps, find lists, email lists, time logs, questions and changes.

A block shows in the list as the heading that it's under, with the icon of its kind. A block of code, and a block with no heading over it, shows as its own first line. The words in the first field are looked for in that heading and in the lines of the block. A kind of block that a file of your own defines is listed with the code blocks.

Each change goes into the block's lines, and ⌘Z takes it back. The lines can be written by hand too:

- An empty block lists each to-do item that isn't ticked.
- `what: headings` lists headings, `what: done items` lists the to-do items that are ticked, and `what: lines` lists every line of text. `what:` takes the name of any kind in the button's list, like `what: takeoffs`.
- `with: plumber sam` keeps only the lines that have every one of those words.
- `in: jobs` looks only in the folder `jobs` beside the page.
- Words by themselves, with no `what:` line, list the lines of any kind that have those words.

Click a line of the list to open its page at that line. A click on a block opens its page with the caret under the block. Click the box of a to-do item to tick it in its own page. The item stays in the list, ticked, until another page shows, and the top of the list no longer counts it. A second click on its box takes the tick away. If that page isn't open in Ladder, or is open with nothing to save, Ladder writes the tick to the page's file at once. That's the one time that Ladder writes to a file without ⌘S. `find.jl` says how the block is written.

## Read an email file

An `.eml` file holds the email exactly as the server sent it, with what was attached to it inside. Mail, Quick Look and Spotlight read it too. Ladder shows it as a page: the subject and who sent it at the top, then the email's text as Markdown, then a link to each attached file. You read that page, and you can't change it. A click on a link in an email opens it, with no key held. Because the file is the whole email, a later Ladder can show it better with no new download.

An email that was written as HTML shows as its sender made it, with its colours, its layout and its buttons. ⌘E, or a click on the ladder in the top bar, goes down a level: the email then shows its text as Markdown. The same key goes up again. While the find bar is open, the email shows its text, with a mark on each place that the bar found.

Ladder asks the web for nothing to show an email, so its sender can't tell when you open it. A picture that the email has from a web site is an empty box. Click Load pictures, over the email, to get those pictures. That email shows its pictures from then on. The mouse over a link of an email says where the link goes.

Ladder gets no email and sends none. [Mail.lad](https://github.com/jkroso/Mail.lad) does that. It's code that your startup page loads: see "Start with a page of your own". It keeps a folder of `.eml` files in step with your email server, lists a folder's emails in the sidebar, puts buttons at the top of an email that answer it, and sends a page that you write as an email.

## Make a kind of block of your own

A code block in a language that Ladder doesn't know can show as a component, if a file defines the language. The file has a function with the language's name. Ladder gives that function the lines of the block, and shows what it makes.

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
- `written` is optional. With it, a block keeps what you do to it: Ladder writes the lines that it gives into the block.
- Ladder keeps the object until the block's lines change some other way: you type in them, or ⌘Z puts back older ones. Then it calls `progress` again.
- Ladder loads the file again when you save it, and makes each of its blocks again. So a kind of block changes in the page as you write it.

Ladder writes a block's lines at three times:

- **Before something reads the page's text.** That's ⌘S, the caret going into the block, a copy, a page of HTML, and another page taking the window. The file does nothing for this.
- **When the component asks.** It calls UI.jl's `changed!(p)`. Ladder writes in the next frame that the mouse isn't held in, so a drag is one change. Writes less than a second apart are one step for ⌘Z.
- **At once.** The component calls `changed!(p, now=true)`, and Ladder writes before that returns.

A change that only the first of these writes doesn't mark the page as edited until then, and ⌘Z can't take it back. So call `changed!(p)` after each change that you'd want to take back, as `pages/progress.jl` does when you click its bar. Keep `now=true` for a change that can't wait.

The line that opens the block can name where the function comes from, after the language:

- ```` ```progress ```` is for `progress.jl` beside the page.
- ```` ```progress ./widgets.jl ```` is for a file that has another name, so one file can define many kinds of block.
- ```` ```progress github.com/sam/blocks ```` is for a repository on GitHub. [Kip](https://github.com/jkroso/Kip.jl) gets it, as it does for `@use`.
- ```` ```progress github.com/sam/blocks@v2 ```` is for the `v2` branch of that repository.

Ladder's own kinds of block come first. A file can't change what a `board` or a `chart` shows.

### A page that defines a kind of block

The file can be a Markdown page: `progress.md` beside the page, when there's no `progress.jl`, or a path that ends in `.md`, like `progress ./kinds/progress.md` or `progress github.com/sam/blocks/progress.md`. Ladder runs the code of each `julia` block of that page, from the top, in one module. The module defines the kind of block, as the module of a Julia file does: it needs the function with the language's name, and it can have `written`.

So the page can say in words what its code does, and it can hold a block of its own kind to try. The code names what it loads with `@use` lines, as a Julia file does. If the code fails, the block says which line of the page failed. `pages/counter.md` is one to copy.

Ladder asks before it runs the code of a GitHub repository for the first time. The block shows the repository's name and a button, **Run the code**. Ladder keeps the repositories that you allow in `~/Library/Application Support/Ladder/repositories`. Take a line out of that file to make Ladder ask again. Ladder doesn't ask about a file on your Mac, as it doesn't ask about the code of a `ui` block.

`pages/progress.jl` is a kind of block to copy, `pages/counter.md` is one that a page defines, and `pages/welcome.md` shows the first. The comment over `FileBlock` in `main.jl` says how it works.

## Start with a page of your own

When you open Ladder without a file, it shows your startup page. The first time, Ladder writes that page, with links to the welcome page and the settings. After that the page is yours, and Ladder never writes to it. It is `startup.md`, in the folder of the settings' pages, and the Settings page has a link to it.

A link to a folder, like `[Email](~/Mail)`, shows that folder in the sidebar, and the page stays. A path can start at your home folder with `~`. So the startup page can be the way to each folder that you work in. Hold ⌘ and click a link to go there.

Each time Ladder starts, it also runs the Julia code of that page: each `julia` block, from the top, in one module. Julia does the same with its `startup.jl`. So the page is where you load code that adds to Ladder, and the words round each block can say what the code is for.

````
```julia
@use "github.com/you/something" => Something
Something.start(Ladder)
```
````

The code has `@use`, as a Julia file that Kip loads has, and the name `Ladder`, which is Ladder's own module. Code that adds to Ladder calls Ladder's functions, as Ladder's own files do.

Ladder also has tables for what it does at its own times. Code puts a function in a table under a name of its own, and Ladder calls the function at that time:

| Table | What the function does |
|---|---|
| `EACH_FRAME` | `f(e)` gets a turn in each frame of each window, like a look for new email. |
| `AT_QUIT` | `f()` runs when Ladder quits. |
| `BAR_PARTS` | `f(e)` gives more buttons for the top bar, for the page that shows. |
| `BUTTONS` | What such a button does, what its tooltip says, and when it's off. |
| `PAGE_TITLES` | `f(e)` gives what the top bar calls the page, in place of its file's name. |
| `MATTER_TITLES` | `f(e)` gives what the card of the page's front matter is called. |
| `MATTER_CARDS` | `f(e, rows)` gives a node that shows in place of the card of the page's front matter, or nothing. |
| `FOLDER_LISTS` | `f(e)` gives a list for the sidebar's folder, in place of the tree of its files, and a line over it. |
| `FOLDER_MARKS` | `f(e, path)` adds to the row of a folder in the sidebar, like how many of its emails aren't read. |
| `PAGE_NAMES` | `f(m, e)` gives the code of a window's pages more names. |
| `FIELD_KEYS` | `f(e, w, K)` takes a key while a field of a live block has the keyboard. |
| `SETTINGS_FOLDERS` | A folder whose pages show in the settings window. |

```julia
Ladder.EACH_FRAME[:clock] = e -> tick(e)
```

A kind of block goes in `Ladder.BLOCKS`, as Ladder's own kinds do. `Ladder.add_insert!` puts it in the Insert menu, and `Ladder.add_commands!` adds commands, with their keys, to the ones on the Key bindings page. The comment over the tables in `main.jl` says more. [Mail.lad](https://github.com/jkroso/Mail.lad) is an example that uses each of them. If a block fails, the blocks after it don't run, Ladder opens all the same, and the window says which line of the page failed. A change to the page's code runs the next time Ladder starts.

## Go back to the file that showed before

Each window keeps the files that it showed, in the order that it showed them. ⌘⌥← goes back to the file that showed before the one that shows now, at the place that it was scrolled to. ⌘⌥→ goes forward again. While the sidebar is open, two arrows at its top right go back and forward too. An arrow is faint when it has no file to go to. The two buttons at the side of a mouse go back and forward as well, if the mouse has them. It works after a link, a click in the list of files, the file finder, and any other way of showing a file. The key bindings page changes the keys. ⌘[ and ⌘] already show the email before and the next email.

## Save a page when you leave its window

Ladder writes a page to its file when you press ⌘S, and at no other time. The settings page has a box that changes that: **Save a page when I leave its window**. With it on, a window writes each of its pages that has changes when it stops being the front window: when you click another window, or change to another app. A page that has no file yet stays as it is. Closing a window doesn't save its pages.

## Show a page as slides

⌃⌘⇧P shows the page one part at a time, for when you show a plan to a client or a crew. So does Show as Slides in the menu that a right-click on the page opens. It starts at the slide that the caret is in.

- A slide starts at each heading of level 1 or 2, and at each line across the page, like `---`. That line doesn't show. What's before the first heading is the first slide. Front matter is in no slide, and a heading of level 3 or lower stays inside its slide.
- The window shows one slide and nothing else of the app: no sidebar, and nothing in the top bar. The slide is in the middle of the window. Its text is up to twice as big as the page's, so that the slide suits the window's height. A slide that's too tall at the page's own size scrolls.
- Everything in a slide shows as it does in the page: a diagram, a chart, a table, a picture, a sheet, a formula. A video plays, and stops when another slide shows. Nothing that you type changes the text, and there's no caret.
- →, ↓, Space, Page Down and Return go to the next slide. ←, ↑, Page Up and ⇧Space go back. Home and End go to the first slide and the last.
- A click on the right half of the window goes on, and a click on the left half goes back. A click on a to-do item's box still ticks it, and a click on a link opens it. A link to a heading of the page shows that heading's slide.
- The number of the slide is at the bottom right, like "3 / 12". A thin bar along the bottom edge shows how far through the slides it is.
- Esc, or ⌃⌘⇧P again, shows the page again. The caret is at the start of the slide that showed last. The page's text is the size it was.
- When the file changes on the disk, as when an agent changes the page, the slides show the new text. The slide with the same number stays, or the last one when there are fewer.

The slides belong to one window, so another window still shows the page as a page. The key is the same in every bundle of key bindings, and the key bindings page changes it. `slides.jl` says which lines each slide shows.

## Test it

```sh
julia -O0 --project=. test/takeoff_test.jl        # how a takeoff is read, written and worked out
julia -O0 --project=. test/centient_test.jl       # how Ladder talks to Centient's server
julia -O0 --project=. test/takeoff_view_test.jl   # the block itself, in a window that isn't on the screen
julia -O0 --project=. test/zoom_test.jl           # a picture, a diagram or a page that fills the window
julia -O0 --project=. test/diagram_edit_test.jl   # changing a diagram while it fills the window
julia -O0 --project=. test/diagram_kinds_test.jl  # a mind map, an entity relationship diagram, a Gantt chart and a timeline in a page
julia -O0 --project=. test/schedule_test.jl       # how a schedule is read, written and worked out
julia -O0 --project=. test/schedule_view_test.jl  # the schedule's bars and links, in a window that isn't on the screen
julia -O0 --project=. test/project_page_test.jl   # a video or a sound on the web, and the button that makes a job in Centient
julia -O0 --project=. test/outcome_test.jl        # the code that ⌘Return runs in a `julia` block, and the box of what it comes to
julia -O0 --project=. test/outcome_parts_test.jl  # the fields of a struct and the children of a node, which that box lists
julia -O0 --project=. test/names_test.jl          # the list of names that a code block offers while you type, and what it says each name is
julia -O0 --project=. test/call_test.jl           # the box that lists what a function takes, when you type the ( of a call
julia -O0 --project=. test/code_file_test.jl      # a Julia file that the page changes, as one block of code
julia -O0 --project=. test/code_settings_test.jl  # the settings of code: long lines, line numbers, the guide, the indent, the font and size
julia -O0 --project=. test/weight_test.jl         # the weights of the page's text and of code: the weights a font has, bold text, the settings file
julia -O0 --project=. test/keys_test.jl           # the key bindings: the commands, the bundles of shortcuts and the page that changes them
julia -O0 --project=. test/highlight_test.jl      # the colours of the parts of a line of code, and of the code in a string
julia -O0 --project=. test/detail_test.jl         # what the box of a function and of a module shows when it's open
julia -O0 --project=. test/update_test.jl         # the app's own updates: a newer version comes, is checked and takes the app's place
julia -O0 --project=. test/window_test.jl         # the settings window, ⌘W, and the settings that every window shares
julia -O0 --project=. test/title_test.jl          # the menu of the file's name in the top bar
julia -O0 --project=. test/back_test.jl           # going back to the file that showed before, and forward again
julia -O0 --project=. test/selection_test.jl      # where the colour of the selection goes
julia -O0 --project=. test/level_test.jl          # ⌘E, and a click on the ladder, while a schedule fills the window
julia -O0 --project=. test/julia_levels_test.jl   # a file of Julia code down a level: the inferred code, the LLVM code and the assembly of what ran
julia -O0 --project=. test/julia_block_levels_test.jl   # a `julia` code block of a page down a level: each block has its own level, and the ladder is about the block with the caret
julia -O0 --project=. test/levels_test.jl         # the slider that the ladder opens into, and the levels of a JSON file, a CSV file and a file of text
julia -O0 --project=. test/sketch_level_test.jl   # and while a sketch fills the window
julia -O0 --project=. test/full_bar_test.jl       # the top bar has none of the sidebar's buttons while something fills the window
julia -O0 --project=. test/slides_test.jl         # which lines of a page each slide shows, and how much bigger a slide's text is
julia -O0 --project=. test/slides_view_test.jl    # a page as slides: the keys, the clicks, a tick, esc and a file that changes, in a window that isn't on the screen
julia -O0 --project=. test/rich_test.jl           # rich text and plain text: where the caret stops, what ⌫ and Return do, and the snake and the ladder in the top bar
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
julia -O0 --project=. test/csv_test.jl            # how a CSV file is read: its rows, cells in quotes, and the columns of numbers
julia -O0 --project=. test/csv_view_test.jl       # a CSV file as a table in the page: a long file, a file that changes, the chart of its numbers
julia -O0 --project=. test/math_test.jl           # how the TeX of a formula is read, where its characters go, and its MathML
julia -O0 --project=. test/math_view_test.jl      # a formula in a line of text and on lines of its own, in a window that isn't on the screen
julia -O0 --project=. test/ask_test.jl            # how a question and its answers are read and written
julia -O0 --project=. test/ask_view_test.jl       # a question in the page: a click on an answer, and the field to type in
julia -O0 --project=. test/changes_test.jl        # how a diff is read, how your choices and comments are written into it, and which words of a line are different
julia -O0 --project=. test/changes_view_test.jl   # the changes of a diff in the page, the buttons that accept and reject them, the old lines beside the new, and a comment on a line
julia -O0 --project=. test/board_test.jl          # how a board is read and written, and the column of each to-do item
julia -O0 --project=. test/board_view_test.jl     # the cards of a board, and a drag from one column to another
julia -O0 --project=. test/gallery_test.jl        # how a gallery is read and written, which pictures it shows, and its grid
julia -O0 --project=. test/gallery_view_test.jl   # the squares of a gallery, a picture that fills the window, and a picture that's dropped on it
julia -O0 --project=. test/calendar_test.jl       # how a calendar is read and written, the day in a to-do item's text, and the things of each day
julia -O0 --project=. test/calendar_view_test.jl  # the month of a calendar: its arrows, a tick, a drag to another day and a new event
julia -O0 --project=. test/linkcard_test.jl       # how the HTML of a web page is read into a card, how a page is told from a picture, and what the card keeps on the Mac
julia -O0 --project=. test/linkcard_view_test.jl  # a line that shows a card: while a page is on its way, a picture that has no .png, the caret on the line, and a click that opens a card
julia -O0 --project=. test/columns_test.jl        # what a `columns` block says, which blocks it puts in columns, and the room of each
julia -O0 --project=. test/columns_view_test.jl   # blocks side by side: typing, clicks, the arrows and a selection in a column, a narrow window, HTML and paper
julia -O0 --project=. test/find_test.jl           # how a list of what's found is read and written, and which lines match
julia -O0 --project=. test/find_view_test.jl      # the list in the page, and a tick that goes to another page's file
julia -O0 --project=. test/sketch_test.jl         # how a sketch is read and written, what a click is on, and the places that change a shape
julia -O0 --project=. test/sketch_view_test.jl    # a sketch in the page, and its tools while it fills the window: drawing, moving, changing and deleting shapes
julia -O0 --project=. test/signature_test.jl      # how a signature is read and written: its strokes, its name and its day
julia -O0 --project=. test/signature_view_test.jl # a signature in the page: strokes drawn with the mouse, ⌘Z, the Clear button and the name's field
julia -O0 --project=. test/contact_test.jl        # how contacts are read and written, what a click on a row opens, and the vCards that are written and read
julia -O0 --project=. test/contact_view_test.jl   # the cards of a block of contacts: a click on a row, words changed where they are, a new detail, and a vCard file that's dropped
julia -O0 --project=. test/map_test.jl            # how a map is read and written, its link to Apple Maps, the places and the pictures that are kept, and where a latitude and a longitude is in a picture
julia -O0 --project=. test/map_view_test.jl       # a map in the page: its pin, its buttons, a drag that moves it, a click that moves its place, the grey box while its picture is made, and a place that isn't found
julia -O0 --project=. test/file_block_test.jl     # a kind of block that a file defines: what it shows, and what goes back into its lines
julia -O0 --project=. test/autosave_test.jl       # the setting that saves a page when you leave its window
julia -O0 --project=. test/children_test.jl       # the parts of the page as the document's children, and a walk from one part to another
julia -O0 --project=. test/timelog_test.jl        # how a time log is read and written, and how its hours and its money are added up
julia -O0 --project=. test/timelog_view_test.jl   # the rows of a time log, the button that starts and stops the clock, and a time changed in its row
julia -O0 --project=. test/startup_test.jl        # the startup page: the page that Ladder writes the first time, its code that runs when Ladder starts, and what the window says when the code fails
julia -O0 --project=. test/folder_link_test.jl    # a link to a folder, which shows the folder in the sidebar
julia -O0 --project=. test/extend_test.jl         # what code from the startup page adds to Ladder: buttons, a list for the sidebar, commands, work in each frame
julia -O0 --project=. test/eml_test.jl            # what Ladder shows of an email file: its page, its front matter, and the links to its files
julia -O0 --project=. test/mime_test.jl           # how an email becomes the page that a window shows, and a page an email
julia -O0 --project=. test/webpage_test.jl        # webpage.jl: the link and the words at a point of a page, and the pictures that WebKit makes of a page, which the email view no longer uses
julia -O0 --project=. test/webpage_view_test.jl   # an email as it was sent: its page in the window, its links, its words that you select, the Load pictures button, and its words a level down
julia -O0 --project=. test/web_test.jl            # web/, which draws a page of HTML with no browser: how it reads HTML and CSS, each element's style, where layout puts each box, and a page's links and words
julia -O0 --project=. test/web_view_test.jl       # a page of HTML in a window: its size, a click on a link, and a new width
```

The tests are in the `test` folder. Run them from Ladder's folder, as above. The first three need no Centient. `test/centient_fake.jl` answers in its place. The last two use no network and no email account. `test/mail_fake.jl` is a pretend email server that runs in the test.

`-O0` tells Julia not to optimise the code that it compiles while a test runs, so a test starts in about half the time. The compiled files that Kip keeps are still made with full optimisation, so the app runs at its usual speed.

To test while you change the code, keep one Julia process open and run the tests in it:

```sh
test/hot                          # start the process, and leave it running
test/hot test/board_view_test.jl  # in another terminal: run one test in it
test/hot all                      # run every test in it, and list what failed
test/hot stop                     # end the process
```

The first test loads Ladder from its source, which takes about half a minute. After that a test takes seconds, and all of them take about three minutes. Before each test, the process loads what changed in the source files, with the code that UI.jl's hot reload uses. `test/hot.jl` says more.

- A method that you delete stays until the process starts again.
- The tests share the one process, so a few fail there and pass by themselves, like the ones that count the open windows. Run a test that fails there in a process of its own: `KIP_FROZEN=1 julia -O0 --project=. test/board_view_test.jl`. With `KIP_FROZEN=1`, Kip loads each file from its source and compiles none first, so the test starts in about 40 seconds whatever you changed.
- Run the tests of what you changed in a process of their own before you call the work done.

## Change it

Ladder loads UI.jl by its GitHub path. To use your own copy of UI.jl, link it once:

```julia
using Kip
Kip.link("/path/to/UI.jl")
```

To write down what's said in a recording, Ladder runs `transcribe.swift`, which uses the speech recognition in macOS 26 and later. Run from the source, Ladder compiles it the first time, so it needs Swift, which comes with Xcode's command line tools. The app has it compiled already.

To find the place of a map and to make its picture, Ladder runs `map.swift`, which uses MapKit, the maps that are part of macOS. It needs macOS 26 or later. Run from the source, Ladder compiles it the first time, as it does `transcribe.swift`. The app has it compiled already.

To show an email as it was sent, Ladder lays its HTML out itself, with the code in `web/`: it reads the HTML and its CSS, lays out blocks, lines of text, floats and tables, and draws them with Skia, as it draws the rest of the window. No browser takes part, so an email is text that you select, and it's laid out again in a few thousandths of a second when the window's width changes. `web/main.jl` says what each file of it does. It doesn't run scripts, and it asks the web for nothing.

`webpage.swift` makes pictures of a page of HTML with WebKit, the part of macOS that draws web pages. Ladder showed an email with those pictures before it had `web/`. They're a way to check `web/` against a browser: the program also says where WebKit puts each line of a page's words.

UI.jl has a script that runs an app and reloads each file when you save it:

```sh
julia --project=. ../UI.jl/examples/hot_reload.jl main.jl pages/components.md
```

## Build the app

```sh
julia --project=. app/build.jl             # writes build/Ladder.app
julia --project=. app/build.jl --install   # and copies it into /Applications
```

The app runs without Julia installed. It is signed for your Mac only. `app/bundle.jl` lists what the build needs and the settings it takes.

The build uses the same copy of UI.jl that `main.jl` runs with: your UI.jl folder if it has changes that aren't committed, or its last commit if not. It prints a line when it builds from uncommitted changes. `release.jl --publish` stops if there are any.

## Make a release

1. Change the version in the `VERSION` file, and commit. Write it with three numbers, like `0.2.0`.
2. Run `julia --project=. release.jl`. It builds the app, signs it with a Developer ID certificate and has Apple notarise it. It writes `build/Ladder-<version>.zip` and `build/latest.txt`.
3. Open the app from the zip file to check it.
4. Run `julia --project=. release.jl --publish`. It builds again, then tags the commit and puts the two files on GitHub as a release.

The top of `release.jl` says how to store your Apple account for the notarising step. You do that once.

The release goes to the GitHub repo that `update.jl` names as `REPO`. That repo must be public, because each copy of the app reads it without an account.

## How the app updates itself

A copy of the app from a release looks for a newer release when it opens, and once a day after that. It reads `latest.txt` from the newest release, which names the version and its zip file. If the version is newer, the app gets the zip file while you work, and checks that the app in it has the signature of the same developer as itself. The new app takes the old one's place after you quit Ladder. The settings page has a box that turns this off, a line that says how far an update has got, and a button to look for one now.

An app that `app/build.jl` built is signed for your Mac only, and doesn't update itself. `update.jl` says how it all works, and how to try an update without a release.
