# Kaydown
#
# A Markdown editor made with UI.jl, modelled on Constly. You type Markdown, and each line is drawn
# the way it will read: headings are big, **bold** is bold, tables are tables.
# The markup characters show again on the line the caret is in, so you can
# change them. A table stays a table while you type in its cells. It opens the real files on your disk, and ⌘S writes your changes
# to the file. It never writes anything until you press ⌘S. A Julia file opens as one block of
# code that you change the same way: ⌘Return runs the expression that the caret is in.
#
# Give it a Markdown file or a folder, or it opens its own welcome page:
#
#     julia --project=. main.jl ~/notes/todo.md
#
# Things to try:
#   - Type. Return carries a list on. Tab and shift-Tab indent a list item.
#   - Click a cell of a table and type. Tab and shift-Tab go to the next and the
#     last cell, and Return goes down a row. Both add a row at the end.
#   - Click a cell of the sheet and type. Each row has a name and a Julia
#     expression, and shows what it comes to. ⌥-click shows the sheet as code.
#   - Click a cell of the spreadsheet and type. A cell that starts with = is a
#     formula, like = B2 * C2 or = sum(D2:D4), and shows what it comes to.
#   - Write a code block in the language `mermaid` to show a diagram: a
#     flowchart, a sequence diagram and so on. ⌥-click shows it as code.
#   - Move the mouse over a diagram, a picture, a page of a PDF file, a model or
#     a video, and click the button beside its top right corner to make it fill the window.
#     Pinch, or scroll with ⌘ held, to zoom it there, and drag it to move it.
#   - Write a code block in the language `takeoff` to measure from a plan: drop
#     a PDF file on it, count fittings, measure lengths and areas, choose each
#     item from Centient's catalogue and make a quote in Centient.
#   - Write a code block in the language `schedule` to plan the page's to-do
#     items: each one is a bar on a line of days. Drag a bar's end to say how
#     long the task takes, and drag from the circle at its end to the task that
#     waits for it. The mouse over a to-do item shows the task's days.
#   - ⌘B and ⌘I make the selection bold or italic. ⌘Z and ⌘⇧Z undo and redo.
#   - Double-click selects a word, triple-click a line. ⌘-click opens a link.
#   - ⌘F finds text in the page. Return goes to the next place that has it.
#   - Write ![name](picture.png) on a line of its own to show a picture, or drop
#     a file on the page from the Finder. ⌘V pastes a file that you copied in
#     the Finder the same way, and a picture that you copied, like a screenshot.
#   - Write [^1] in a line and [^1]: on another line to make a footnote.
#   - Right-click a word with red dots under it to put its spelling right.
#   - The button at the top left, or ⌘\, shows the other files in the folder.
#     Drag the right edge of that list to make it wider or narrower.
#     ⌘O finds a Markdown file by name.
#   - Click a file in that list that isn't Markdown to see it. Kaydown shows it
#     and doesn't change it: the text of a file of code, a picture, a model, a
#     sound, a video, a PDF file, a table. A file that it has no way to show is
#     a binary file, and a button shows its bytes in hexadecimal. The button at
#     the top right opens the file in the app that the Mac uses for it.
#   - Click the icon beside a file in that list to see the file's headings and
#     components, and click one to go to it. ⌘⇧\ gives that list the keyboard: ↑ and ↓
#     move through it, → and ← show and hide what's under an item, Return
#     opens the item and esc goes back to the text.
#   - Right-click a file in that list, or the file's name in the top bar, to
#     rename it, copy its path, show it in the Finder or move it to the Trash.
#   - Right-click the page to cut, copy and paste, and to insert a new block
#     where you clicked: a heading, a list, a to-do item, a table, a sheet, a
#     spreadsheet, a code block, a live block, a takeoff, a schedule, a recording or a divider.
#   - A line that holds only a sound file, like ![Recording](memo.m4a), shows
#     a player. Insert › Recording records one from the microphone. A button
#     under the player writes down what's said, in a paragraph under it.
#   - Start a list item with `- [ ]` to make a to-do item. Click its box to
#     tick it.
#   - Write a code block in the language `julia`, put the caret in a line of
#     it and press ⌘Return. The page runs the line and shows what it comes to
#     in a box after the line. ⇧Return runs the line and goes to the next one.
#     Click a box that has an arrow to see the rest of its value.
#   - Type the start of a name in a code block. A list under the caret shows
#     the page's names that start the same way. ↑ and ↓ choose one, and Return
#     or Tab types the rest of it.
#   - Write !`code` in a line of text. The page runs the code and shows what
#     it makes in the line: a node like a switch or a file path, or a value
#     as text. Click the line to see the code again.
#   - Start a file with front matter: lines like `title: Notes` between two
#     lines of ---, or lines like `title = "Notes"` between two lines of +++.
#     It shows as a block of its own.
#   - Let an agent like Claude Code show you a page (see agent.jl and the plugin
#     folder). While it waits, a button at the top right sends it the lines that
#     you changed. ⌘Return does the same. The agent can change the file while
#     you type, and the page keeps both. A bar shows for a few seconds beside
#     each line that the agent changed, and a button with an eye in the
#     top bar shows those bars again. The list of files has a dot beside
#     a page that an agent waits for. While the list is hidden, the dot is
#     beside the button that shows it.
#   - Click the word count to count characters or reading time instead.
#   - ⌘+ and ⌘- change the text size by a pixel. ⌘0 puts it back.
#   - ⌘P prints the page, or saves it as a PDF. ⌘⇧E saves it as a page of HTML.
#   - ⌘, opens the settings page in a window of its own, where you choose the
#     colours, the font, the text size, the width of the page, what the
#     count at the top right counts and how code shows. A button there makes
#     Kaydown the app that opens Markdown files. ⌘, again closes that window.
#   - ⌘W closes a window. Kaydown quits when its last window closes.
#   - ⌘⌥I opens the layout inspector.
#
# It uses these UI.jl features: a `Scroll` that only builds the lines
# on screen, a `draw` method that adds the caret and selection over a node,
# italic and bold fonts by name, a colour for each part of a line of code, a
# `Stack` to float the file finder over the page, and
# `hide_titlebar!` for a window without a title bar, with
# `place_window_buttons!` to line its close, minimise and zoom buttons up with the top bar.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" measure_text rectangle rounded_rectangle sk_color fontmgr
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI WrapMode Theme with_theme adopt_theme! light describe describe! reuse! detach! add_child! window_of focus handled carry!
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor open_url viewport show_tooltip! hide_tooltip! hittest show_menu! hide_menu! redraw_in! rect popup! close_popup! MouseScroll Pinch onpinch placed! with_clip with_round_clip clipboard!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool send
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font register_font
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect image_source has_image
@use "github.com/jkroso/UI.jl/Interface/inspector" toggle_inspector!
@use "github.com/jkroso/UI.jl/Interface/window" hide_titlebar! place_window_buttons! drag_window! set_dark! nswindow system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer Mesh load!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" AudioPlayer VideoPlayer pause!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" AudioRecorder record! stop! plays
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid problem
@use "github.com/jkroso/UI.jl/Interface/media" silence! recording picture_size
@use "github.com/jkroso/UI.jl/Interface/Semantic/ThreeMF" => ThreeMF
@use "./pictures" picture natural thumbnail pdf_pages pdf_page pdf_size pdf_part
@use "./spelling" misspelt guesses learn!
@use "./transcribe" Transcription check! finished phrases words_between
@use "./html" html footnotes NOTE escape
@use "./markdown" Kind Line Span Cell classify spans tablecells isdivider words isdone front_matter MATTER TOML_MATTER
@use "./highlight" tokens
@use "./sheet" SHEET Result sheetcells parts uses tally known units shown
@use "./spreadsheet" SPREADSHEET Value spreadcells spreadtexts isformula letters answers moved
@use "./merge" changes combine follow
@use "./agent" => Agent
@use "./pasteboard" => Pasteboard
@use "./takeoff" => Plans
@use "./schedule" => Schedules
@use "./centient" => Centient
@use "github.com/jkroso/UI.jl/Interface/draw" Bubble
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use Colors: @colorant_str, RGBA, Colorant
@use InteractiveUtils: clipboard
@use Dates: Dates, Date, Day

# --- look --------------------------------------------------------------------

const SANS = isfile("/System/Library/Fonts/SFNS.ttf") ? ".SF NS" : "Helvetica"
const SERIF = "Charter"
const MONO = "Menlo"
# Code is drawn in the light weight of the Mac's own font with letters of one width, so it reads
# lighter than the page's text. Menlo has no light weight. A Mac without that font draws code in
# Menlo, and so does a character that the font lacks, like ∈.
const CODE_FONT, CODE_STYLE = isfile("/System/Library/Fonts/SFNSMono.ttf") ? (".SF NS Mono", "Light") : (MONO, "")
const CODE_SLANT = String(strip(CODE_STYLE * " Italic"))   # the style of a comment
const CODE_SCALE = 0.86   # how big code is beside the page's text, until the settings page changes it

"""
The font of code and its weight, for the window that's being laid out and
drawn. Each window sets them from its settings as it starts a frame, so each
part of the window that shows code uses the font that the settings page chose.
"""
const code_type = Ref((CODE_FONT, CODE_STYLE))
codefont() = code_type[][1]
codestyle() = code_type[][2]
codeslant() = String(strip(codestyle() * " Italic"))   # the style of a comment
const SPARE_FONT = "Apple Symbols"   # it has the characters that Julia writes and Menlo lacks too, like the ⋮ in a big matrix
const SYMBOL_FONT = "Lucida Grande"

Base.@kwdef mutable struct Palette
  bg::Colorant        # the page
  ink::Colorant       # text
  dim::Colorant       # quotes, the title, the word count
  faint::Colorant     # markup characters like ** and #
  marker::Colorant    # bullets and list numbers
  line::Colorant      # table lines and rules
  chip::Colorant      # behind `code`
  chip_line::Colorant
  block::Colorant     # behind a code block
  head::Colorant      # a table's heading row
  stripe::Colorant    # every second row of a table
  accent::Colorant    # links
  select::Colorant
  panel::Colorant     # the sidebar
  hover::Colorant
  active::Colorant    # the open file in the sidebar
  float::Colorant     # the file finder, and the other things that float over the page
  shade::Colorant     # dims the window behind the file finder
  # In a code block
  comment::Colorant
  string::Colorant
  number::Colorant
  keyword::Colorant
  call::Colorant      # the name of a function being called
  type::Colorant
end

const SEPIA = Palette(bg=colorant"rgb(243,236,218)", ink=colorant"rgb(60,52,42)", dim=colorant"rgb(128,116,98)",
                      faint=colorant"rgb(176,164,140)", marker=colorant"rgb(150,136,112)",
                      line=colorant"rgb(212,203,180)", chip=colorant"rgb(234,227,206)",
                      chip_line=colorant"rgb(217,208,185)", block=colorant"rgb(236,229,209)",
                      head=colorant"rgb(234,227,207)", stripe=colorant"rgb(238,231,212)",
                      accent=colorant"rgb(156,86,38)", select=RGBA(0.72, 0.52, 0.2, 0.28),
                      panel=colorant"rgb(236,228,208)", hover=colorant"rgb(228,220,198)",
                      active=colorant"rgb(222,213,189)", float=colorant"rgb(248,243,229)",
                      shade=RGBA(0.2, 0.15, 0.05, 0.18),
                      comment=colorant"rgb(150,138,115)", string=colorant"rgb(84,116,44)",
                      number=colorant"rgb(170,98,20)", keyword=colorant"rgb(150,58,108)",
                      call=colorant"rgb(48,98,140)", type=colorant"rgb(36,116,110)")

const PAPER = Palette(bg=colorant"rgb(255,255,255)", ink=colorant"rgb(36,36,36)", dim=colorant"rgb(120,120,120)",
                      faint=colorant"rgb(178,178,178)", marker=colorant"rgb(140,140,140)",
                      line=colorant"rgb(224,224,224)", chip=colorant"rgb(243,243,243)",
                      chip_line=colorant"rgb(226,226,226)", block=colorant"rgb(246,246,246)",
                      head=colorant"rgb(244,244,244)", stripe=colorant"rgb(250,250,250)",
                      accent=colorant"rgb(22,100,210)", select=RGBA(0.26, 0.52, 0.96, 0.28),
                      panel=colorant"rgb(246,246,246)", hover=colorant"rgb(236,236,236)",
                      active=colorant"rgb(226,226,226)", float=colorant"rgb(255,255,255)",
                      shade=RGBA(0, 0, 0, 0.16),
                      comment=colorant"rgb(140,140,140)", string=colorant"rgb(30,120,60)",
                      number=colorant"rgb(180,95,0)", keyword=colorant"rgb(170,40,130)",
                      call=colorant"rgb(30,90,180)", type=colorant"rgb(0,120,130)")

const NIGHT = Palette(bg=colorant"rgb(30,30,32)", ink=colorant"rgb(222,220,214)", dim=colorant"rgb(150,148,142)",
                      faint=colorant"rgb(100,99,96)", marker=colorant"rgb(132,130,124)",
                      line=colorant"rgb(62,62,66)", chip=colorant"rgb(46,46,50)",
                      chip_line=colorant"rgb(66,66,72)", block=colorant"rgb(40,40,43)",
                      head=colorant"rgb(44,44,48)", stripe=colorant"rgb(36,36,39)",
                      accent=colorant"rgb(110,170,255)", select=RGBA(0.35, 0.58, 1.0, 0.35),
                      panel=colorant"rgb(38,38,41)", hover=colorant"rgb(52,52,56)",
                      active=colorant"rgb(62,62,68)", float=colorant"rgb(44,44,48)",
                      shade=RGBA(0, 0, 0, 0.4),
                      comment=colorant"rgb(112,112,118)", string=colorant"rgb(160,200,120)",
                      number=colorant"rgb(230,170,100)", keyword=colorant"rgb(200,130,220)",
                      call=colorant"rgb(120,170,250)", type=colorant"rgb(110,200,200)")

const THEMES = (sepia=SEPIA, paper=PAPER, night=NIGHT)
const colours = deepcopy(SEPIA)

# A component's label is 13/12 of its theme's size. This makes a label as tall as the page's text.
const LABEL = 12 / 13

"The page's colours, font and text size, for the components that a live block shows"
component_theme(zoom=1.0) = Theme(size=TEXT_SIZE * zoom * LABEL, surface=colours.float, text=colours.ink, dim=colours.dim, line=colours.line,
                          track=colours.faint, hover=colours.hover, select=colours.active,
                          accent=colours.accent, on_accent=colours.bg, family=SANS, mono=SHEET_FONT, mono_style=SHEET_WEIGHT,
                          number=colours.number, string=colours.string, symbol=colours.call,
                          keyword=colours.keyword, type=colours.type)

"Draw with the colours in `p` from now on"
use!(p::Palette) = foreach(n -> setfield!(colours, n, getfield(p, n)), fieldnames(Palette))

const TOPBAR_H = 44px
const PANEL_W = 230px     # how wide the sidebar is until you drag its edge
const PANEL_MIN = 160px   # the narrowest and widest that you can drag it
const PANEL_MAX = 480px
const PROSE_W = 780px    # the widest the text gets, before zooming, until the settings page changes it
const PAGE_X = 32px      # the least space beside the text
const PAGE_TOP = 28px
const PAGE_BOTTOM = 160px
const CODE_END = 100px   # how much of a code file still shows at the top of the window when it's scrolled to the end
const CHIP_X = 5px       # space inside a `code` chip, left and right of its text
const BLOCK_X = 16px     # space inside a code block, left of its text
const QUOTE_X = 18px
const CELL_X = 14px
const CELL_Y = 9px

const grow = GrowType.Grow
const clear = RGBA(0, 0, 0, 0)
# The shadow under what floats over the page: a popup, a list of names, the bar over a table
const lifted = shadow(0, 8, 24, RGBA(0, 0, 0, 0.22))
fixed(w) = width(preferred=w, grow=GrowType.None)
spacer(h) = Box(width(grow=grow), height(h))
num(l) = Float64(convert(px, l).value)

label(s, size=13px; color=colours.ink, weight="") =
  Text(s, size=size, family=SANS, subfamily=weight, color=color, wrap=WrapMode.none)

# --- fonts and measuring -------------------------------------------------------

"How a run of text is drawn. A chip is the box behind `code`."
struct Face
  family::String
  style::String
  size::px
  color::Colorant
  chip::Bool
  lang::String   # the language of code whose parts each get a colour, or "" for text in one colour
end

Face(family, style, size, color, chip) = Face(family, style, size, color, chip, "")
Face(f::Face; style=f.style, size=f.size, color=f.color, family=f.family, chip=f.chip, lang=f.lang) =
  Face(family, style, size, color, chip, lang)

const measured = Dict{Tuple{String,String,Float32,String},px}()

"How wide `s` is in `face`. It's kept, because the same words are measured every frame."
measure(face::Face, s::AbstractString) = begin
  isempty(s) && return 0px
  length(measured) > 200_000 && empty!(measured)
  get!(measured, (face.family, face.style, Float32(num(face.size)), String(s))) do
    px(measure_text(skia_font(face.family, face.size, face.style), s)[1])
  end
end

# --- a line laid out ---------------------------------------------------------------
#
# A line of the document can wrap into several lines on screen. A Flow says
# where each run of its text goes, so the same numbers place the text, the
# caret and the selection, and turn a click back into a column.

"The node that a piece of inline code made, with the room it takes in its line"
struct Inline
  node::Any      # a Shown
  w::px
  h::px
end

"A run of a line's text before it's wrapped"
struct Piece
  text::String
  col::Int       # the column of its first character
  n::Int         # how many characters of the line it stands for
  face::Face
  atomic::Bool   # true when `text` isn't the line's own text, like a • for a -
  link::String
  node::Union{Nothing,Inline}   # what's drawn in place of the text, for inline code that made a node
end

"A run of text placed on one line of the screen"
struct Seg
  text::String
  col::Int
  n::Int
  face::Face
  atomic::Bool
  link::String
  x::px          # from the left edge of the page's text
  w::px
  node::Union{Nothing,Inline}
end

"One line on screen"
struct VLine
  segs::Vector{Seg}
  x::px          # where its text starts
  from::Int      # the columns it covers
  to::Int
  top::px        # how far it is under the first line
  high::px       # a line with a tall node in it is taller than the others
end

struct Flow
  lines::Vector{VLine}
  lh::px         # the height of a line on screen that has only text
  size::px       # the font size, which sets the caret's height
  above::px
  below::px
  kind::Kind
  raw::Bool      # true when the markup characters are showing
end

tall(f::Flow) = f.above + sum(vl -> vl.high, f.lines, init=0px) + f.below

"How far screen line `k` of `f` is under the top of `f`"
line_top(f::Flow, k::Int) = f.above + f.lines[k].top

"The screen line of `f` that's `dy` under the top of `f`"
line_at(f::Flow, dy::px) = something(findlast(vl -> f.above + vl.top <= dy, f.lines), 1)

const INLINE_GAP = 4px   # the least room above and below a node in a line of text, in all

"Wrap `pieces` to `limit`. Lines start at `left`, and all but the first at `hang`."
wrap(pieces, limit::px; lh, size, left=0px, hang=left, above=0px, below=0px, kind=Kind.paragraph, raw=false) = begin
  lines = VLine[]
  segs = Seg[]
  x = start = left
  top = 0px
  flush!() = begin
    from = isempty(segs) ? (isempty(lines) ? 0 : last(lines).to) : first(segs).col
    to = isempty(segs) ? from : last(segs).col + last(segs).n
    high = max(lh, maximum(s -> s.node === nothing ? 0px : s.node.h + INLINE_GAP, segs, init=0px))
    push!(lines, VLine(segs, start, from, to, top, high))
    top += high
    segs = Seg[]
    x = start = hang
  end
  # Add `text`, which is `n` characters from `col`, to the line being built
  add!(p::Piece, text, col, n) = begin
    pad = p.face.chip ? 2(CHIP_X + 1px) : 0px
    if !isempty(segs) && !p.atomic && !last(segs).atomic && last(segs).col + last(segs).n == col && last(segs).face === p.face && last(segs).link == p.link
      s = pop!(segs)
      joined = s.text * text
      push!(segs, Seg(joined, s.col, s.n + n, s.face, false, s.link, s.x, measure(s.face, joined) + pad, nothing))
      x = s.x + last(segs).w
    else
      w = p.node === nothing ? measure(p.face, text) + pad : p.node.w
      push!(segs, Seg(text, col, n, p.face, p.atomic, p.link, x, w, p.node))
      x += w
    end
  end
  # Cut the pieces into words, each with the spaces after it. What inline code made is one word.
  words = Tuple{Piece,String,Int,Int}[]
  for p in pieces
    if p.atomic
      push!(words, (p, p.text, p.col, p.n))
      continue
    end
    col = p.col
    for m in eachmatch(r"\S+\s*|\s+", p.text)
      n = length(m.match)
      push!(words, (p, String(m.match), col, n))
      col += n
    end
  end
  # How far a word reaches past where it starts. A `code` chip has room inside it on each side.
  # Spaces at the end of a line may hang past the edge, but the spaces in a chip are inside it.
  reach((p, text, col, n), last) =
    p.node !== nothing ? p.node.w :
    p.atomic ? measure(p.face, text) :
    p.face.chip ? measure(p.face, text) + (col == p.col ? 2(CHIP_X + 1px) : 0px) :
    measure(p.face, last ? rstrip(text) : text)
  i = 1
  while i <= length(words)
    # Words with no space between them go onto a line together, like a `code` chip and the comma after it
    j = i
    while j < length(words) && !endswith(words[j][2], r"\s") && !startswith(words[j+1][2], r"\s")
      j += 1
    end
    w = sum(k -> reach(words[k], k == j), i:j)
    if w <= limit - hang
      x + w > limit && x > start && flush!()
      foreach(k -> add!(words[k][1], words[k][2:4]...), i:j)
    else
      # Words that are too wide for a whole line together break where they must
      for k in i:j
        x + reach(words[k], k == j) > limit && x > start && flush!()
        add!(words[k][1], words[k][2:4]...)
      end
    end
    i = j + 1
  end
  flush!()
  Flow(lines, lh, size, above, below, kind, raw)
end

"""
How far into `seg` the gap after its first `k` characters is. In a `code` chip the text
is inside the chip's padding, so even the gaps at its two ends are inside the chip.
"""
inset(seg::Seg, k::Int) = begin
  seg.atomic && return k <= 0 ? 0px : seg.w
  pad = seg.face.chip ? CHIP_X + 1px : 0px
  k <= 0 && return pad
  k >= seg.n && return seg.w - pad
  pad + measure(seg.face, first(seg.text, k))
end

"Where column `col` is on the screen line `vl`"
xcol(vl::VLine, col::Int) = begin
  for (i, seg) in enumerate(vl.segs)
    col < seg.col && return seg.x
    col == seg.col && return seg.x + inset(seg, 0)
    if col <= seg.col + seg.n
      # The gap before a `code` chip is the start of its code, so the caret shows inside the chip
      i < length(vl.segs) && col == seg.col + seg.n && (next = vl.segs[i+1]).face.chip && next.col == col &&
        return next.x + inset(next, 0)
      return seg.x + inset(seg, col - seg.col)
    end
  end
  isempty(vl.segs) ? vl.x : last(vl.segs).x + last(vl.segs).w
end

"The screen line that column `col` is on, and where it is on that line"
spot(f::Flow, col::Int) = begin
  for (k, vl) in enumerate(f.lines), seg in vl.segs
    col < seg.col + seg.n && return (k, xcol(vl, col))
  end
  (length(f.lines), xcol(last(f.lines), col))
end

"The column nearest to `x` on screen line `k`"
colat(f::Flow, k::Int, x::px) = begin
  vl = f.lines[k]
  isempty(vl.segs) && return vl.from
  col = vl.to
  for (i, seg) in enumerate(vl.segs)
    (x < seg.x + seg.w || i == length(vl.segs)) || continue
    if seg.atomic
      col = x < seg.x + seg.w/2 ? seg.col : seg.col + seg.n
    else
      col = seg.col + seg.n
      for c in 1:seg.n
        if x < seg.x + (inset(seg, c - 1) + inset(seg, c))/2
          col = seg.col + c - 1
          break
        end
      end
    end
    break
  end
  # The end of a wrapped line is the start of the next one, so stop a character short
  k < length(f.lines) && col >= vl.to ? max(vl.from, vl.to - 1) : col
end

# --- the document ----------------------------------------------------------------

const Pos = Tuple{Int,Int}   # a line, from 1, and a column, from 0

"An open file"
Base.@kwdef mutable struct Buffer
  path::String = ""
  lines::Vector{String} = [""]
  caret::Pos = (1, 0)
  anchor::Pos = (1, 0)                  # where the selection starts. The caret is its other end.
  undo::Vector{Any} = Any[]
  redo::Vector{Any} = Any[]
  version::Int = 0                      # changes with every edit
  saved::Int = 0                        # the version that's in the file
  typed::Float64 = 0.0                  # when a character was last typed, to undo words not letters
  offset::px = 0px                      # how far it's scrolled
  across::px = 0px                      # how far it's scrolled to the right, in a file of code whose long lines don't wrap
  kinds::Vector{Line} = Line[]
  kinds_at::Int = -1
  words::Int = 0
  chars::Int = 0
  # After Escape the caret is hidden, and every line shows as it reads, until a click puts the caret back
  reading::Bool = false
  # How the file shows. A Markdown file is a document that you change, and :code is a file of
  # code that you change, which is one block of code. Any other file is only shown: :text shows
  # its text, :hex shows its bytes, and :file shows a viewer of its kind.
  view::Symbol = :markdown
  about::String = ""                    # what the top bar says of a file that's only shown, like how much of it shows
  disk::Vector{String} = [""]           # the file's text as it was last read or written
  # The text as an agent last knew it: what you last sent it, with every change that was made to the file from outside since
  told::Vector{String} = [""]
  sent::Vector{String} = [""]           # the text as it was when you last sent it to an agent, or when the file was opened
end

"True when the file is only shown. Kaydown changes Markdown files and the files of code in `CODE_FILES`, and no others."
readonly(b::Buffer) = !(b.view in (:markdown, :code))

const stamp = Ref(0)

load(path) = begin
  READ[path] = mtime(path)
  code = !ismarkdown(path) && iscode(path)
  ismarkdown(path) || code || return look(path)
  lines = text(path)
  b = Buffer(path=path, lines=lines, disk=copy(lines), told=copy(lines), view=code ? :code : :markdown)
  b.sent = b.told   # nothing has changed from outside yet
  code && return b
  # The caret starts at the text, after any front matter, so the front matter shows as a card
  t = front_matter(b.lines)
  if t > 0
    i = something(findnext(l -> !isempty(strip(l)), b.lines, t + 1), min(t + 1, length(b.lines)))
    b.caret = b.anchor = (i, 0)
  end
  b
end
text(path) = String.(split(replace(read(path, String), "\r\n" => "\n"), '\n'))

const READ = Dict{String,Float64}()   # when each open file was last read or written, as the disk tells it

"""
Read the file again if something else changed it on the disk, like an agent
that's working on the page with you. A document with changes that aren't saved
keeps them, and gets the file's changes too. Where both changed the same lines,
the document keeps its own. Returns the lines of the document that changed, as
`changes` gives them, or nothing.
"""
refresh!(b::Buffer) = begin
  (isempty(b.path) || !isfile(b.path)) && return
  at = mtime(b.path)
  at == get(READ, b.path, 0.0) && return
  READ[b.path] = at
  unsaved = false
  if readonly(b)
    # A file that's only shown is read again as it was shown: as bytes, or as its kind of file
    new = b.view == :hex ? Buffer(path=b.path, view=:hex, lines=hexlines(b.path), about=hex_about(b.path)) : look(b.path)
    b.view, b.about = new.view, new.about
    lines = new.lines
  else
    theirs = text(b.path)
    theirs == b.disk && return
    # An agent knows the changes it made to the file, and none of yours until you send them
    b.told = combine(b.disk, b.told, theirs, keep=:theirs)
    lines = dirty(b) ? combine(b.disk, b.lines, theirs) : theirs
    b.disk = theirs
    unsaved = lines != theirs
  end
  moved = changes(b.lines, lines)
  if !isempty(moved)
    b.lines = lines
    empty!(b.undo); empty!(b.redo)
    b.version = (stamp[] += 1)
    # The caret stays on its line, wherever that line is now
    place(p) = (i = clamp(follow(moved, p[1]), 1, length(lines)); (i, clamp(p[2], 0, length(lines[i]))))
    b.caret, b.anchor = place(b.caret), place(b.anchor)
  end
  unsaved || (b.saved = b.version)
  isempty(moved) ? nothing : moved
end

kinds(b::Buffer) = begin
  if b.kinds_at != b.version && b.view != :markdown
    # Each line of a file that isn't Markdown is a line of code, in the language that the end of the file's name gives
    lang = b.view == :hex ? HEX : String(lstrip(lowercase(splitext(b.path)[2]), '.'))
    b.kinds = fill(Line(Kind.code, 0, 0, lang), length(b.lines))
    # A file that's only shown has no words to count
    b.words, b.chars = b.view == :code ? (words(b.lines), sum(length, b.lines, init=0)) : (0, 0)
    b.kinds_at = b.version
  elseif b.kinds_at != b.version
    b.kinds = classify(b.lines)
    # Front matter says things about the document, so the counts leave it out
    counted = @view b.lines[front_matter(b.lines)+1:end]
    b.words = words(counted)
    b.chars = sum(length, counted, init=0)
    b.kinds_at = b.version
  end
  b.kinds
end

dirty(b::Buffer) = b.version != b.saved
name(b::Buffer) = isempty(b.path) ? "Untitled" : basename(b.path)
selecting(b::Buffer) = b.caret != b.anchor
"""
The two ends of the selection, first end first. A selection that covers several
lines takes the whole of each row of a table or a sheet that it touches.
"""
selection(b::Buffer) = begin
  lo, hi = minmax(b.caret, b.anchor)
  (lo[1] == hi[1] || readonly(b)) && return (lo, hi)
  ks = kinds(b)
  (ks[lo[1]].kind == Kind.table || insheet(b, lo[1]) || inspread(b, lo[1])) && (lo = (lo[1], 0))
  (ks[hi[1]].kind == Kind.table || insheet(b, hi[1]) || inspread(b, hi[1])) && (hi = (hi[1], length(b.lines[hi[1]])))
  (lo, hi)
end

head(s, n) = String(first(s, n))
rest(s, n) = String(chop(s, head=n, tail=0))

"The text from `lo` to `hi`"
excerpt(b::Buffer, lo::Pos, hi::Pos) = begin
  lo[1] == hi[1] && return rest(head(b.lines[lo[1]], hi[2]), lo[2])
  join([rest(b.lines[lo[1]], lo[2]); b.lines[lo[1]+1:hi[1]-1]; head(b.lines[hi[1]], hi[2])], "\n")
end

snapshot(b::Buffer) = (copy(b.lines), b.caret, b.anchor, b.version)

restore!(b::Buffer, (lines, caret, anchor, version)) = begin
  b.lines, b.caret, b.anchor, b.version = lines, caret, anchor, version
  b.typed = 0.0
end

"Replace the text from `lo` to `hi` with `new`, and put the caret after it"
edit!(b::Buffer, lo::Pos, hi::Pos, new::AbstractString; typing=false) = begin
  readonly(b) && return b   # nothing changes a file that's only shown
  # Letters typed one after another undo together
  if !(typing && time() - b.typed < 1 && !isempty(b.undo))
    push!(b.undo, snapshot(b))
    length(b.undo) > 500 && popfirst!(b.undo)
  end
  empty!(b.redo)
  b.typed = typing ? time() : 0.0
  joined = head(b.lines[lo[1]], lo[2]) * new * rest(b.lines[hi[1]], hi[2])
  splice!(b.lines, lo[1]:hi[1], String.(split(joined, '\n')))
  parts = split(new, '\n')
  b.caret = b.anchor = (lo[1] + length(parts) - 1, length(parts) == 1 ? lo[2] + length(new) : length(last(parts)))
  b.version = (stamp[] += 1)
  b
end

undo!(b::Buffer) = isempty(b.undo) || (push!(b.redo, snapshot(b)); restore!(b, pop!(b.undo)))
redo!(b::Buffer) = isempty(b.redo) || (push!(b.undo, snapshot(b)); restore!(b, pop!(b.redo)))

save!(b::Buffer) = begin
  # The lines of a file that's only shown can be a part of the file, or its bytes, so they're never written
  (isempty(b.path) || readonly(b)) && return
  refresh!(b)   # a change that something else made to the file a moment ago is kept
  write(b.path, join(b.lines, "\n"))
  READ[b.path] = mtime(b.path)
  b.disk = copy(b.lines)
  b.saved = b.version
end

# --- the app -------------------------------------------------------------------------

"One block of the page: a line of the document, or a table drawn as a table"
struct Item
  first::Int     # the lines of the document it shows
  last::Int
  top::px        # from the top of the page's text
  tall::px
  content::Any   # a Flow, a Grid or a Live
end

"What a `ui` code block made when its code ran, and how tall that is on the page"
struct Live
  node::Any      # a SemanticUI or a GeometricUI
  tall::px
end

"A table laid out"
struct Grid
  rows::Vector{Int}            # the line of the document each row comes from
  widths::Vector{px}
  heights::Vector{px}
  cells::Vector{Vector{Cell}}  # where each cell's text is in its line
  flows::Vector{Vector{Flow}}  # one for each column, even where a row has no cell
  # A spreadsheet is laid out as a table is, with a row of letters over it and a column of numbers on its left
  head::px                     # how tall the row of letters is, with the line under it. A table has none.
  left::px                     # how wide the column of numbers is, with the line beside it
  values::Vector{Vector{Value}}   # what each cell of a spreadsheet comes to
end

Grid(rows, widths, heights, cells, flows) = Grid(rows, widths, heights, cells, flows, 0px, 0px, Vector{Value}[])

"True when `g` is a spreadsheet, not a table"
isspread(g::Grid) = g.head > 0px

@def mutable struct Editor <: SemanticUI
  buf::Buffer = Buffer()
  buffers::Dict{String,Buffer} = Dict{String,Buffer}()
  folder::String = ""
  files::Vector{String} = String[]      # the Markdown files in the folder
  listed::Vector{String} = String[]     # the folders and files in the folder, as the sidebar lists them
  panel::Bool = false                   # is the sidebar showing?
  slid::Float64 = 0.0                   # when the sidebar last started to slide in or out
  slid_from::Float64 = 0.0              # how far open it was then, from 0 to 1
  side::px = PANEL_W                    # how wide the sidebar is. Drag its right edge to change it.
  theme::Symbol = :sepia
  applied::Symbol = :none               # the theme the window was last told about
  font::String = SERIF                  # of the page's text
  zoom::Float64 = 1.0
  remember::Bool = false                # write the settings to a file when they change
  settings::Bool = false                # this window opened to show the settings page
  stat::Symbol = :words                 # what the count at the top right counts
  spelling::Bool = true                 # put a line of dots under each word that's spelt wrong
  wrap::Bool = true                     # a line of a file of code that's too long for the window goes on under itself
  numbers::Bool = true                  # a file of code shows the number of each line beside it
  shade::Bool = false                   # the line of a file of code that the caret is on is shaded
  indent::Int = 2                       # how many spaces one step of indentation is, in code
  code_scale::Float64 = CODE_SCALE      # how big code is, as a part of the size of the page's text
  code_font::String = CODE_FONT         # the font of code, by the name of its family
  guide::Int = 0                        # a faint line goes down a file of code after this many characters. 0 is no line.
  popup::Symbol = :none                # :finder while the file finder is open
  picked::Int = 1                       # the file the finder will open
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow), scrollbar_inset=0px)   # the page's scrollbar is at the window's edge
  files_scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))
  nodes::Dict{Any,Any} = Dict{Any,Any}()   # the parts of the window, kept between frames
  flows::Dict{Any,Any} = Dict{Any,Any}()
  layout::Vector{Item} = Item[]
  shown::UnitRange{Int} = 1:0           # the items that were built for the last frame
  width::px = PROSE_W                   # how wide the text is
  widest::px = PROSE_W                  # the widest the text gets, before zooming. The settings page sets it.
  reach::px = 0px                       # how far the longest line goes, in a file of code whose long lines don't wrap
  origin::Tuple{px,px} = (0px, 0px)     # where the page's text was last drawn in the window
  goal::Union{Nothing,px} = nothing     # where ↑ and ↓ try to keep the caret
  reveal::Bool = false                  # scroll to the caret before the next frame
  blink::Float64 = time()
  clicked::Tuple{Float64,Pos,Int} = (0.0, (0, 0), 0)
  size::Tuple{px,px} = (1100px, 800px)  # the window's size, until there is a window to ask
end

@def mutable struct TopBar <: SemanticUI end
@def mutable struct Sidebar <: SemanticUI end    # the list of files down the left of the window
@def mutable struct Page <: SemanticUI end       # the scrolling area around the text
@def mutable struct Document <: SemanticUI end   # the text itself
@def mutable struct Backdrop <: SemanticUI end   # catches clicks outside a popup
@def mutable struct FinderInput <: SemanticUI end
@def mutable struct ToolButton <: SemanticUI
  icon::String = ""
  action::Symbol = :none
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end
"A button of the bar that shows over the table the caret is in"
@def mutable struct TableButton <: SemanticUI
  action::Symbol = :none
  label::String = ""
end
"The file's name in the middle of the top bar. A right-click on it shows the file's menu."
@def mutable struct Title <: SemanticUI end
@def mutable struct Count <: SemanticUI       # the word count in the top bar
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end
"The button in the top bar that sends the page to the agent that's waiting for it"
@def mutable struct SendButton <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end

# The parts of the document. Each one holds the items that show its lines.
@def mutable struct Paragraph <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Heading <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct List <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Quote <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct CodeBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Table <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Rule <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"A code block in the language `ui`, showing what its code made"
@def mutable struct LiveBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"A code block in the language `sheet`, drawn as rows that work things out"
@def mutable struct SheetBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"The ! of a row of a sheet that went wrong. It says what went wrong while the mouse is over it."
@def mutable struct Trouble <: SemanticUI
  message::String = ""
  size::px = 14px
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
end
const Block = Union{Paragraph,Heading,List,Quote,CodeBlock,Table,Rule,LiveBlock,SheetBlock}
"A file in the file finder's list"
@def mutable struct FileRow <: SemanticUI
  path::String = ""
  finder::Int = 0    # its place in the list
end
"The name of a file in the sidebar's tree"
@def mutable struct FileLabel <: SemanticUI
  path::String = ""
end
"A heading or a component of a file, as the sidebar lists it"
struct Entry
  line::Int       # where it starts
  level::Int      # a heading's level. A component has level 7, so it goes in the heading above it.
  title::String
  icon::String
  caret::Int      # the line the caret goes to: the heading's own, or the line after a component
end
"""
A heading or a component of a file, under that file in the sidebar's tree
"""
@def mutable struct EntryLabel <: SemanticUI
  path::String = ""
  line::Int = 0
  level::Int = 1
  title::String = ""
  icon::String = ""
  caret::Int = 0
end

editor(node) = begin
  while !(node isa Editor)
    node = node.parent
  end
  node
end

"A node that belongs to `e` and is kept for as long as `e` is"
own!(e, node) = (node.parent === nothing && setfield!(node, :parent, e); node)
node!(make, e, key) = get!(() -> own!(e, make()), e.nodes, key)

const MARKDOWN = (".md", ".markdown", ".mdx")
ismarkdown(path) = lowercase(splitext(path)[2]) in MARKDOWN

# The files of code that the page changes, as it changes a Markdown file. The whole file is one block of code.
const CODE_FILES = (".jl",)

"""
True when the file at `path` is code that the page can change: a kind of file
in `CODE_FILES`, whose text shows whole. A file that's too long to show whole,
or that isn't text, is only shown.
"""
iscode(path) = begin
  (lowercase(splitext(path)[2]) in CODE_FILES && isfile(path)) || return false
  filesize(path) == 0 && return true
  found = try reading(path, tidy=false) catch; nothing end
  found !== nothing && !found[2]
end

"Open the editor on a file, or on the first Markdown file in a folder"
build_editor(path) = begin
  path = abspath(expanduser(path))
  e = Editor()
  load_sheet_font()
  e.nodes[:input] = own!(e, TextInput(placeholder="Find a file", font_family=SANS, font_size=15px,
                                      look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
  if isdir(path)
    e.folder = path
    e.panel = true
    list_files!(e)
    isempty(e.files) || open!(e, e.files[1])
  else
    open!(e, path)
  end
  e
end

list_files!(e) = begin
  names = isdir(e.folder) ? readdir(e.folder) : String[]
  paths = [joinpath(e.folder, n) for n in sort!(names, by=lowercase) if !startswith(n, '.')]
  # The sidebar lists the folders, then each file. The file finder lists the Markdown files.
  files = filter(isfile, paths)
  e.listed = [filter(isdir, paths); files]
  e.files = filter(ismarkdown, files)
end

"Show the file at `path`. A file that's already open keeps its changes."
open!(e, path) = begin
  # A sound that the last page was playing stops. A new window has no last page, and another window's sound plays on.
  isempty(e.buffers) || silence!()
  e.buf.offset = e.scroll.offset
  e.buf = get!(e.buffers, path) do
    isfile(path) ? load(path) : Buffer(path=path)
  end
  if e.folder != dirname(path)
    e.folder = dirname(path)
    list_files!(e)
  end
  e.scroll.offset = e.buf.offset
  e.popup = :none
  e.goal = nothing
  w = window_of(e)
  w === nothing || focus(e)
  e
end

window_size(e) = something(viewport(e), e.size)

"The folder of the document that's showing. The sidebar can show another folder."
docdir(e) = isempty(e.buf.path) ? e.folder : dirname(e.buf.path)

"Show the folders and files of `folder` in the sidebar. The document that's showing stays."
go_folder!(e, folder) = begin
  e.folder = folder
  list_files!(e)
  e.files_scroll.offset = 0px
  e
end
input(e) = e.nodes[:input]::TextInput

# --- faces -----------------------------------------------------------------------------

const TEXT_SIZE = 17px   # of the page's text, before it's zoomed
body(e) = Face(e.font, "", TEXT_SIZE * e.zoom, colours.ink, false)
const HEADINGS = (2.1, 1.75, 1.4, 1.2, 1.05, 1.0)

"The face a line's plain text is drawn in"
face(e, line::Line) = begin
  b = body(e)
  k = line.kind
  k == Kind.heading ? Face(b, style="Bold", size=b.size * HEADINGS[line.level]) :
  k == Kind.blockquote ? Face(b, style="Italic", color=colours.dim) :
  # Code is the size that the settings page chooses. The markup of a table or a rule is code's usual size.
  k in (Kind.code, Kind.fence) ? Face(b, family=codefont(), style=codestyle(), size=code_size(e)) :
  k in (Kind.table, Kind.rule) ? Face(b, family=codefont(), style=codestyle(), size=b.size * CODE_SCALE) : b
end

"The face for one span of a line whose plain text is drawn in `base`"
face(base::Face, s::Span) = begin
  s.markup && return Face(base, color=colours.faint)
  # Inline code that runs is Julia, so its parts get the colours they have in a code block
  s.code && return Face(codefont(), codestyle(), base.size * 0.86, base.color, true, s.live ? "julia" : "")
  bold = s.bold || occursin("Bold", base.style)
  italic = s.italic || occursin("Italic", base.style)
  style = bold && italic ? "Bold Italic" : bold ? "Bold" : italic ? "Italic" : ""
  Face(base, style=style, color=!isempty(s.link) ? colours.accent : s.strike ? colours.faint : base.color)
end

piece(text, col, face; atomic=false, n=length(text), link="", node=nothing) = Piece(text, col, n, face, atomic, link, node)

# --- the font of code ------------------------------------------------------------------
#
# Code is drawn in a font whose letters are all one width. The settings page
# lists each such font on the Mac, and code is drawn in the one you choose. It's
# drawn in the font's light weight when the font has one, as SF Mono has, so
# that code reads lighter than the page's text.

"The weight of the face of `family` nearest to `weight`, or 0 when the Mac has no font of that family"
installed_weight(family::AbstractString, weight::Integer) = begin
  style = Skia.sk_fontstyle_new(Int32(weight), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL), Skia.SK_FONT_STYLE_SLANT_UPRIGHT)
  typeface = Skia.sk_fontmgr_match_family_style(fontmgr[], String(family), style)
  Skia.sk_fontstyle_delete(style)
  typeface == C_NULL && return 0
  found = Skia.sk_typeface_get_fontstyle(typeface)
  w = Int(Skia.sk_fontstyle_get_weight(found))
  Skia.sk_fontstyle_delete(found)
  Skia.sk_typeface_unref(typeface)
  w
end

"The weight that code in `family` is drawn in: Light when the font has it, and its usual weight when it doesn't"
const code_styles = Dict{String,String}(CODE_FONT => CODE_STYLE)
code_style(family) = get!(() -> installed_weight(family, 300) == 300 ? "Light" : "", code_styles, family)

"Draw code in the font that `e`'s settings choose, from now until another window starts to draw"
use_code_font!(e) = (code_type[] = (e.code_font, code_style(e.code_font)); e)

"True when every letter of `family` is as wide as every other, as in a font for code"
isfixed(family) = begin
  f = Face(family, "", 20px, colours.ink, false)
  all(c -> has(f, c), "iMw0") && measure(f, "i") == measure(f, "M") == measure(f, "0")
end

# The Mac's own font for code has a hidden name, and the list calls it SF Mono
font_label(family) = family == ".SF NS Mono" ? "SF Mono" : family
font_family(label) = label == "SF Mono" && CODE_FONT == ".SF NS Mono" ? CODE_FONT : label

const fixed_fonts = String[]

"""
The names in `fonts` with each font once, where a font comes in copies whose
letters are the same. A Nerd Font comes as X Nerd Font, X Nerd Font Mono and X
Nerd Font Propo, whose icons differ. A variable font, X Var, is X with its
weights in one file. The plain X stays, or the one there is.
"""
once_each(fonts) = filter(f -> !(endswith(f, COPIES) && replace(f, COPIES => "") in fonts), fonts)
const COPIES = r"(?<= Nerd Font) (Mono|Propo)$| Var$"

# Fonts of pictures, not letters, though each picture is as wide as the next
const PICTURE_FONTS = ("Webdings", "Wingdings", "Wingdings 2", "Wingdings 3", "Symbol", "Zapf Dingbats", "Bodoni Ornaments")

"The families of the fonts on this Mac whose letters are all one width, in order, with the one that code is drawn in at first"
code_fonts() = begin
  if isempty(fixed_fonts)
    names = String[]
    name = Skia.sk_string_new_empty()
    for i in 0:Skia.sk_fontmgr_count_families(fontmgr[])-1
      Skia.sk_fontmgr_get_family_name(fontmgr[], Cint(i), name)
      push!(names, unsafe_string(Skia.sk_string_get_c_str(name)))
    end
    Skia.sk_string_delete(name)
    # A font whose name starts with a dot is the Mac's own, for its menus and windows
    found = filter(f -> !startswith(f, '.') && font_family(f) == f && !(f in PICTURE_FONTS) && isfixed(f), unique(names))
    append!(fixed_fonts, sort!(once_each(found), by=lowercase))
  end
  unique([CODE_FONT; fixed_fonts])
end

# The text that stands for the box of a to-do item. The box is drawn in its place, so only the text's width matters.
# Both hold the same characters, so an empty box and a ticked one are the same width.
const TODO_OPEN, TODO_DONE = "[ ] ", "] [ "
"True when `seg` is the box of a to-do item"
isbox(seg) = seg.atomic && (seg.text == TODO_OPEN || seg.text == TODO_DONE)

"The runs of text that line `text` is drawn as. With `raw`, the markup shows."
pieces(e, text::String, line::Line, raw::Bool, i::Int=0) = begin
  base = face(e, line)
  out = Piece[]
  k = line.kind
  if k == Kind.code && line.lang == MATTER
    # In front matter, the key is fainter than what it's set to, and a comment slants
    m = match(r"^(\s*(?:-\s+)?)([^:#\s][^:#]*:)(.*)$", text)
    if startswith(lstrip(text), '#') || m === nothing
      comment = startswith(lstrip(text), '#')
      isempty(text) || push!(out, piece(text, 0, comment ? Face(base, color=colours.comment, style=codeslant()) : base))
    else
      isempty(m[1]) || push!(out, piece(String(m[1]), 0, base))
      push!(out, piece(String(m[2]), length(m[1]), Face(base, color=colours.dim)))
      isempty(m[3]) || push!(out, piece(String(m[3]), length(m[1]) + length(m[2]), base))
    end
    return out
  elseif k == Kind.code && line.lang == TOML_MATTER
    # TOML front matter looks like YAML front matter: a key and its = are fainter, and so is a
    # [table] line that starts a group of keys. A comment slants.
    m = match(r"^(\s*)((?:\"[^\"]*\"|'[^']*'|[\w.-])+\s*=)(.*)$", text)
    if startswith(lstrip(text), '#')
      push!(out, piece(text, 0, Face(base, color=colours.comment, style=codeslant())))
    elseif startswith(lstrip(text), '[') && m === nothing
      push!(out, piece(text, 0, Face(base, color=colours.dim)))
    elseif m === nothing
      isempty(text) || push!(out, piece(text, 0, base))
    else
      isempty(m[1]) || push!(out, piece(String(m[1]), 0, base))
      push!(out, piece(String(m[2]), length(m[1]), Face(base, color=colours.dim)))
      isempty(m[3]) || push!(out, piece(String(m[3]), length(m[1]) + length(m[2]), base))
    end
    return out
  elseif k == Kind.code && line.lang == HEX
    # In a line of a file's bytes, the place in the file is faint and the bytes as characters are dim
    n = ncodeunits(text)
    for (lo, hi, colour) in ((0, HEX_BYTES, colours.faint), (HEX_BYTES, HEX_CHARS, base.color), (HEX_CHARS, n, colours.dim))
      lo < n && push!(out, piece(text[lo+1:min(hi, n)], lo, Face(base, color=colour)))
    end
    return out
  elseif k == Kind.code
    # Each part of a line of code has its own colour, and comments slant
    for t in tokens(text, line.lang)
      colour = t.kind == :plain ? base.color : getfield(colours, t.kind)
      push!(out, piece(t.text, t.col, Face(base, color=colour, style=t.kind == :comment ? codeslant() : base.style)))
    end
    return out
  elseif k in (Kind.fence, Kind.table, Kind.rule)
    k == Kind.fence && !raw && return out
    isempty(text) || push!(out, piece(text, 0, k == Kind.table ? base : Face(base, color=colours.faint)))
    return out
  end
  lead = head(text, line.prefix)
  if k in (Kind.bullet, Kind.ordered, Kind.todo)
    line.level > 0 && push!(out, piece(head(lead, line.level), 0, base))
    mark = Face(base, style="Bold", color=colours.marker)
    if k == Kind.bullet && !raw
      push!(out, piece("•  ", line.level, mark, atomic=true, n=line.prefix - line.level))
    elseif k == Kind.todo && !raw
      push!(out, piece(isdone(text) ? TODO_DONE : TODO_OPEN, line.level, base, atomic=true, n=line.prefix - line.level))
    else
      push!(out, piece(rest(lead, line.level), line.level, mark))
    end
    # A to-do item that's done reads fainter
    k == Kind.todo && isdone(text) && (base = Face(base, color=colours.dim))
  elseif k == Kind.paragraph
    isempty(lead) || push!(out, piece(lead, 0, base))
  elseif raw && !isempty(lead)
    push!(out, piece(lead, 0, Face(base, color=colours.faint)))
  end
  start = line.prefix
  note = k == Kind.paragraph && !raw ? match(NOTE, text) : nothing
  if note !== nothing
    # The line that holds a footnote's text starts with the footnote's number
    start = length(note.match)
    push!(out, piece(note_mark(e, note[1]) * ".  ", 0, Face(base, color=colours.accent), atomic=true, n=start, link="^" * note[1]))
  end
  for s in spans(rest(text, start), start)
    s.markup && !raw && continue
    if startswith(s.link, '^') && !raw
      # [^name] shows as the footnote's number, small and raised
      push!(out, piece(note_mark(e, s.text), s.col, Face(base, size=base.size * 0.7, color=colours.accent), atomic=true, n=length(s.text), link=s.link))
      continue
    end
    # Line -1 isn't one of the document's lines: it's a line of a file under a path. Its inline code shows as code.
    s.live && !raw && i >= 0 ? push!(out, inline(e, i, s, base)) : symbols!(out, s.text, s.col, face(base, s), s.link)
  end
  out
end

# --- inline code -------------------------------------------------------------------------
#
# !`code` in a line of text is inline code. The page runs the code and shows
# what it makes in place of the code: a node, like a switch or a file path, or
# any other value as text. The code shows again while the caret is on its line.

const INLINE = "!`"   # what inline code starts with

"The lines of `b` that have inline code"
inline_lines(e, b::Buffer) = get!(e.flows, (:inline, b.path, b.version)) do
  [i for (i, text) in enumerate(b.lines) if occursin(INLINE, text)]
end

"""
Which one of the document's pieces of inline code with this code the span `s`
of line `i` is: 1 for the first. Two pieces with the same code each make a
node of their own.
"""
ordinal(e, i::Int, s::Span) = begin
  b = e.buf
  marked = INLINE * s.text * "`"
  1 <= i <= length(b.lines) || return 1
  before = sum(j -> count(marked, b.lines[j]), Iterators.filter(<(i), inline_lines(e, b)), init=0)
  before + count(marked, head(b.lines[i], max(0, s.col - length(INLINE)))) + 1
end

"""
What the `n`th piece of inline code `code` of the document made. It's a Shown
when the code made a node. For any other value it's the value as text, and
true if that text says what went wrong.
"""
made(e, code::String, n::Int) = begin
  key = (:inline, e.buf.path, code, n)
  get!(e.nodes, key) do
    out = evaluate(e, code, key=key, inline=true)
    out isa Tuple && return out
    shown = Shown(value=out, inline=true)
    out isa SemanticUI && own!(shown, out)
    shown
  end
end

"Lay out what inline code made, to learn how much room it takes in its line"
fit(e, shown) = begin
  own!(node!(Document, e, :document), shown)
  concrete = describe(Row(Alignment.Start, geometry(shown)), (e.width, 9999px))
  # A node with no width of its own, like a slider, takes all the room it's given. In a line it gets this much.
  w = concrete.width < 16px ? INLINE_W * e.zoom : concrete.width
  Inline(shown, min(w, e.width), concrete.height)
end

const INLINE_W = 180px   # of a node in a line of text that has no width of its own, before the text is zoomed

"The piece that stands for the inline code of span `s`, on line `i`, in text drawn in `base`"
inline(e, i::Int, s::Span, base::Face) = begin
  out = made(e, s.text, ordinal(e, i, s))
  n = length(s.text)
  out isa Tuple || return piece(s.text, s.col, base, atomic=true, n=n, node=fit(e, out))
  text, failed = out
  piece(text, s.col, failed ? Face(base, color=colours.accent) : base, atomic=true, n=n)
end

const LONGEST_VALUE = 200   # characters of a value that inline code shows as text

"""
A value as the text that inline code shows for it. A number reads the way a
sheet shows it: 28.8 and not 28.799999999999997, with or without a unit.
"""
said(value) = begin
  text = value isa AbstractString ? String(value) : value === nothing ? "nothing" : Base.invokelatest(shown, value)
  text = replace(text, r"\s*\n\s*" => " ")
  length(text) > LONGEST_VALUE ? first(text, LONGEST_VALUE) * "…" : text
end

# The page's fonts have no ⌘ or arrows, so those characters are drawn in one that does
const SYMBOLS = r"[⌘⌥⇧⌃⏎⇥←→↑↓]+"

"Add `text` to `out`, with its keyboard symbols in a font that has them"
symbols!(out, text, col, face, link="") = begin
  at = 1
  add(part, symbol) = isempty(part) ||
    (push!(out, piece(String(part), col, symbol ? Face(face, family=SYMBOL_FONT, style="") : face; link)); col += length(part))
  for m in eachmatch(SYMBOLS, text)
    add(SubString(text, at, prevind(text, m.offset)), false)
    add(m.match, true)
    at = m.offset + ncodeunits(m.match)
  end
  add(SubString(text, at), false)
  out
end

"The first and last line of the code block that line `i` is in, with the lines that open and close it"
codeblock(b::Buffer, i::Int) = begin
  ks = kinds(b)
  s = t = i
  while s > 1 && !(ks[s].kind == Kind.fence && ks[s].level == 0); s -= 1 end
  while t < length(ks) && !(ks[t].kind == Kind.fence && ks[t].level == 1 && t > s); t += 1 end
  (s, t)
end

"""
True when the caret is in the code block that line `i` is in, and the selection
doesn't reach out of the block. A selection that goes through a block leaves it
as it reads.
"""
incode(b::Buffer, i::Int) = begin
  b.reading && return false
  s, t = codeblock(b, i)
  s <= b.caret[1] <= t && s <= b.anchor[1] <= t
end

"True when line `i` shows its markup: it has the caret, and the selection doesn't reach another line"
israw(b::Buffer, i::Int) = !b.reading && i == b.caret[1] == b.anchor[1]

"Lay out line `i` of the document"
flow(e, i::Int, raw::Bool=israw(e.buf, i)) = begin
  text, line = e.buf.lines[i], kinds(e.buf)[i]
  if e.buf.view == :code
    # A line of a file of code is laid out as a line of a file that's only shown is
    length(e.flows) > 4000 && empty!(e.flows)
    return get!(() -> file_line(e, text, line, i), e.flows, (:file, text, line))
  end
  # The lines that open and close a code block only show while the caret is in the block
  line.kind == Kind.fence && (raw = incode(e.buf, i))
  build() = laid(e, text, line, raw, i)
  # What inline code made can change its size, so its line is laid out again each time
  !raw && occursin(INLINE, text) && !(line.kind in (Kind.code, Kind.fence, Kind.rule)) && return build()
  # A footnote's number comes from the rest of the document, so its line is laid out again each time too
  !raw && occursin("[^", text) && return build()
  length(e.flows) > 4000 && empty!(e.flows)
  get!(build, e.flows, (text, line, raw))
end

"Lay out `text`, line `i` of the document, which is a line of the kind `line`, for a page that's `wide`"
laid(e, text, line::Line, raw::Bool, i::Int, wide=e.width) = begin
  base = face(e, line)
  ps = spare(pieces(e, text, line, raw, i))
  k = line.kind
  # A hidden ``` line leaves a little room at the top or bottom of its block
  lh = k == Kind.heading ? base.size * 1.35 : body(e).size * (k == Kind.fence && !raw ? 0.6 : 1.65)
  # Lines of bigger code are further apart
  k in (Kind.code, Kind.fence) && (lh *= e.code_scale / CODE_SCALE)
  left = k in (Kind.code, Kind.fence) ? BLOCK_X : k == Kind.blockquote ? QUOTE_X : 0px
  # Lines that a list item wraps onto start under its text, not under its bullet
  hang = k in (Kind.bullet, Kind.ordered, Kind.todo) ? sum(p -> measure(p.face, p.text), ps[1:min(end, line.level > 0 ? 2 : 1)], init=0px) : left
  above = k == Kind.heading ? lh * 0.3 : 0px
  below = k == Kind.heading ? lh * 0.12 : 0px
  wrap(ps, wide; lh, size=base.size, left, hang, above, below, kind=k, raw)
end

"Forget every layout, after something that changes how all the text is drawn"
restyle!(e) = (empty!(e.flows); e.reveal = true; e)

# --- tables ----------------------------------------------------------------------------
#
# A table is a line of cells, a line of dashes, then more lines of cells. It's
# drawn as a grid, and the caret moves from cell to cell. The line of dashes
# isn't drawn. If the caret gets onto it, the table shows as plain lines.

"The first and last line of the table that line `i` is part of, or nothing"
table(b::Buffer, i::Int) = begin
  ks = kinds(b)
  ks[i].kind == Kind.table || return nothing
  s = t = i
  while s > 1 && ks[s-1].kind == Kind.table; s -= 1 end
  while t < length(ks) && ks[t+1].kind == Kind.table; t += 1 end
  t > s && isdivider(b.lines[s+1]) ? (s, t) : nothing
end

"The lines of a table that are rows of cells"
tablerows((s, t)) = [s; s+2:t]

"The cells of the row that `p` is in, when that row is drawn in a grid or a sheet"
rowcells(b::Buffer, p::Pos) = begin
  insheet(b, p[1]) && return sheetcells(b.lines[p[1]])
  inspread(b, p[1]) && return spreadcells(b.lines[p[1]])
  run = table(b, p[1])
  (run === nothing || p[1] == run[1] + 1) ? Cell[] : tablecells(b.lines[p[1]])
end

within(c::Cell, col::Int) = c.lo <= col <= c.limit

"The cell that `p` is in, or nothing"
cellat(b::Buffer, p::Pos) = begin
  cs = rowcells(b, p)
  i = findfirst(c -> within(c, p[2]), cs)
  i === nothing ? nothing : cs[i]
end

"Which of `cs` column `col` is in, or is nearest to"
nearest(cs, col::Int) = argmin(i -> within(cs[i], col) ? 0 : min(abs(col - cs[i].lo), abs(col - cs[i].limit)), eachindex(cs))

"""
Where the caret goes when it's sent to `p`. In a table that's the same place
if `p` is in a cell. Otherwise it's the next cell in the direction `by`, or the
nearest cell when `by` is 0.
"""
settle(b::Buffer, p::Pos, by::Int=0) = begin
  run = sheet(b, p[1])
  run === nothing || return settle(b, run, p, by)
  run = spread(b, p[1])
  run === nothing || return settle(b, run, p, by, spreadcells)
  run = table(b, p[1])
  run === nothing && return p
  s, t = run
  i, col = p
  if i == s + 1
    # The line of dashes. Step over it, unless that's where a click put the caret.
    by == 0 && return p
    j = by < 0 ? s : s + 2
    return j > t ? (t < length(b.lines) ? (t + 1, 0) : p) : settle(b, (j, col))
  end
  cs = tablecells(b.lines[i])
  (isempty(cs) || any(c -> within(c, col), cs)) && return p
  rows = tablerows(run)
  r = findfirst(==(i), rows)
  if by < 0
    c = findlast(c -> c.limit < col, cs)
    c === nothing || return (i, cs[c].hi)
    r > 1 && return row_edge(b, rows[r-1], 1)
    s > 1 ? line_end(b, s - 1) : (i, cs[1].lo)
  elseif by > 0
    c = findfirst(c -> c.lo > col, cs)
    c === nothing || return (i, cs[c].lo)
    r < length(rows) && return row_edge(b, rows[r+1], -1)
    t < length(b.lines) ? (t + 1, 0) : (i, cs[end].hi)
  else
    c = cs[nearest(cs, col)]
    (i, clamp(col, c.lo, c.limit))
  end
end

"The start of the first cell of row `i`, or with `by` of 1 the end of its last cell"
row_edge(b::Buffer, i::Int, by::Int) = begin
  cs = tablecells(b.lines[i])
  isempty(cs) ? (i, 0) : by < 0 ? (i, cs[1].lo) : (i, cs[end].hi)
end

"The runs of text in a cell that shows columns `lo` to `hi` of `text`"
cellpieces(e, i::Int, text::String, lo::Int, hi::Int, base::Face, raw::Bool) = begin
  out = Piece[]
  for s in spans(rest(head(text, hi), lo), lo)
    s.markup && !raw && continue
    s.live && !raw ? push!(out, inline(e, i, s, base)) : symbols!(out, s.text, s.col, face(base, s), s.link)
  end
  out
end

"How wide a piece is before it's wrapped"
wide(p::Piece) = p.node === nothing ? measure(p.face, p.text) : p.node.w

"The text of each cell of a row of a table, without the spaces around it"
celltexts(line::AbstractString) = begin
  chars = collect(strip(line))
  !isempty(chars) && chars[1] == '|' && popfirst!(chars)
  !isempty(chars) && chars[end] == '|' && (length(chars) < 2 || chars[end-1] != '\\') && pop!(chars)
  out, cell = String[], Char[]
  for (i, c) in enumerate(chars)
    c == '|' && (i == 1 || chars[i-1] != '\\') ? (push!(out, strip(String(cell))); empty!(cell)) : push!(cell, c)
  end
  push!(out, strip(String(cell)))
end

tableline(cells) = "| " * join(cells, " | ") * " |"

"The side each column's text sits on, from the table's line of dashes: :left, :center or :right"
aligns(divider::AbstractString) =
  [startswith(c, ':') && endswith(c, ':') ? :center : endswith(c, ':') ? :right : :left for c in celltexts(divider)]

"Move each line of `f` across so its text sits on `side` of a space `room` wide"
align(f::Flow, room::px, side::Symbol) = begin
  side == :left && return f
  lines = map(f.lines) do vl
    dx = max(0px, room - sum(seg -> seg.w, vl.segs, init=0px)) * (side == :center ? 0.5 : 1)
    VLine([Seg(s.text, s.col, s.n, s.face, s.atomic, s.link, s.x + dx, s.w, s.node) for s in vl.segs], vl.x + dx, vl.from, vl.to, vl.top, vl.high)
  end
  Flow(lines, f.lh, f.size, f.above, f.below, f.kind, f.raw)
end

"Lay out the table in lines `from` to `to` of the document"
grid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = from <= b.caret[1] <= to ? b.caret : nothing
  build() = begin
    base = Face(body(e), size=body(e).size * 0.94)
    lh = base.size * 1.5
    rows = tablerows((from, to))
    cells = [tablecells(b.lines[i]) for i in rows]
    ncols = max(1, maximum(length, cells))
    parts = map(enumerate(rows)) do (r, i)
      map(1:ncols) do c
        c <= length(cells[r]) || return Piece[]
        cell = cells[r][c]
        # The cell with the caret shows its markup, and the spaces typed after its text
        active = caret !== nothing && caret[1] == i && within(cell, caret[2])
        cellpieces(e, i, b.lines[i], cell.lo, active ? max(cell.hi, caret[2]) : cell.hi,
                   r == 1 ? Face(base, style="Bold") : base, active)
      end
    end
    # Each column gets room in proportion to its longest cell
    natural = [maximum(row -> sum(wide, row[c], init=0px), parts, init=0px) + 2CELL_X for c in 1:ncols]
    natural = [clamp(w, 60px, e.width * 0.75) for w in natural]
    space = e.width - 1px * (ncols + 1)
    widths = natural .* (num(space) / num(sum(natural)))
    sides = aligns(b.lines[from+1])
    flows = [[align(wrap(row[c], widths[c] - 2CELL_X; lh, size=base.size, left=CELL_X), widths[c] - 2CELL_X, get(sides, c, :left))
              for c in 1:ncols] for row in parts]
    heights = [maximum(f -> tall(f), row) + 2CELL_Y for row in flows]
    Grid(rows, widths, heights, cells, flows)
  end
  # What inline code made can change its size, so a table with some in it is laid out again each time
  any(text -> occursin(INLINE, text), @view b.lines[from:to]) && return build()
  get!(build, e.flows, (:grid, from, b.lines[from:to], caret))
end

const TABLE_GAP = 8px   # above and below a table
tall(g::Grid) = g.head + sum(g.heights) + 1px * (length(g.heights) + 1) + 2TABLE_GAP

"Where the text of row `r`, column `c` starts, from the top left of the table's item"
cell_origin(g::Grid, r::Int, c::Int) =
  (g.left + 1px * c + sum(g.widths[1:c-1], init=0px),
   TABLE_GAP + g.head + 1px * r + sum(g.heights[1:r-1], init=0px) + (g.heights[r] - tall(g.flows[r][c]))/2)

"The column in `cell` nearest to `x` on line `k` of its flow"
cellcol(f::Flow, k::Int, x::px, cell::Cell) =
  isempty(f.lines[k].segs) ? cell.lo : clamp(colat(f, k, x), cell.lo, cell.limit)

"The row and column of `g` that holds the caret at `p`, or nothing"
gridcell(g::Grid, p::Pos) = begin
  r = findfirst(==(p[1]), g.rows)
  (r === nothing || isempty(g.cells[r])) && return nothing
  (r, nearest(g.cells[r], p[2]))
end

# --- spreadsheets ----------------------------------------------------------------------
#
# A code block in the language `spreadsheet` is drawn as a spreadsheet. Each
# line of the block is a row, with a | between its cells, as in a table. A row
# of letters is over the cells, one for each column. A column of numbers is on
# their left, one for each row. A cell that starts with = is a formula: a Julia
# expression that can use the other cells by name, like B2 * C2 or sum(D2:D9).
# The cell shows what its formula comes to. While the caret is in the cell, it
# shows the formula.
#
# It's laid out as a `Grid`, so the caret moves as it does in a table, and the
# bar over the grid adds and removes a row or a column. Hold ⌥ and click the
# spreadsheet to see it as lines of code.

const SPREAD_Y = 5px   # above and below the text of a cell

"""
The lines that open and close the spreadsheet that line `i` is in, or nothing.
A spreadsheet needs a row, and it shows as lines of code while the caret is on
the line that opens or closes it.
"""
spread(b::Buffer, i::Int) = drawn(b, i, SPREADSHEET)

"True when line `i` is a row of a spreadsheet"
inspread(b::Buffer, i::Int) = begin
  run = spread(b, i)
  run !== nothing && run[1] < i < run[2]
end

"The lines that are the rows of the table or the spreadsheet that line `i` is in"
gridrows(b::Buffer, i::Int) = begin
  run = spread(b, i)
  run === nothing ? tablerows(table(b, i)) : collect(run[1]+1:run[2]-1)
end

"The name of every cell of a spreadsheet that has `rows` rows and `cols` columns"
cellnames(rows::Int, cols::Int) = [letters(c) * string(r) for r in 1:rows for c in 1:cols]

"How wide the longest part of `p` is that can't go onto two lines: a word, a number or what a formula comes to"
unbroken(p::Piece) =
  p.node !== nothing ? p.node.w : p.atomic ? measure(p.face, p.text) :
  maximum(word -> measure(p.face, word), split(p.text), init=0px) + (p.face.chip ? 2(CHIP_X + 1px) : 0px)

"Lay out the spreadsheet whose code block opens on line `from` and closes on line `to`"
spreadgrid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = israw(b, b.caret[1]) && from < b.caret[1] < to ? b.caret : nothing
  build() = begin
    base = Face(body(e), size=body(e).size * 0.94)
    lh = base.size * 1.5
    rows = collect(from+1:to-1)
    cells = [spreadcells(b.lines[i]) for i in rows]
    texts = [spreadtexts(b.lines[i]) for i in rows]
    # The cells are only worked out again when the text of one changes
    values = get!(() -> answers(texts), e.flows, (:answers, texts))
    ncols = maximum(length, cells)
    typing(r, c) = caret !== nothing && caret[1] == rows[r] && c <= length(cells[r]) && within(cells[r][c], caret[2])
    # What the cell in row `r`, column `c` shows. With `on`, it's the cell with the caret.
    shows(r, c, on) = begin
      c <= length(cells[r]) || return Piece[]
      i, cell, v = rows[r], cells[r][c], values[r][c]
      # The cell with the caret shows the spaces typed after its text
      upto = on ? max(cell.hi, caret[2]) : cell.hi
      isformula(texts[r][c]) || return cellpieces(e, i, b.lines[i], cell.lo, upto, base, on)
      # A formula shows what it comes to. With the caret in its cell, it shows the formula, and each cell that it names is a chip.
      on && return exprpieces(b.lines[i], cell.lo, upto, cellnames(length(rows), ncols), base)
      [piece(v.failed ? "!" : v.text, cell.lo, base, atomic=true, n=cell.hi - cell.lo)]
    end
    # The columns are as wide as they are with no caret in a cell, so a column keeps its width
    # while you edit one of its cells. A formula that's wider than its column wraps.
    resting = [[shows(r, c, false) for c in 1:ncols] for r in eachindex(rows)]
    parts = [[typing(r, c) ? shows(r, c, true) : resting[r][c] for c in 1:ncols] for r in eachindex(rows)]
    # Each column gets room in proportion to its longest cell, as in a table
    natural = [clamp(maximum(row -> sum(wide, row[c], init=0px), resting, init=0px) + 2CELL_X, 60px, e.width * 0.75) for c in 1:ncols]
    gutter = max(measure(Face(base, family=SANS, size=base.size * 0.72), string(length(rows))) + 14px, base.size * 1.9)
    space = e.width - gutter - 1px * (ncols + 2)
    # When the columns don't all fit, text wraps before a number is cut short: each column keeps
    # the room its longest word or number needs, and the columns share what's left
    least = [min(natural[c], max(maximum(row -> maximum(unbroken, row[c], init=0px), resting, init=0px) + 2CELL_X, 36px)) for c in 1:ncols]
    widths = sum(natural) <= space ? natural .* (num(space) / num(sum(natural))) :
             sum(least) >= space ? least .* (num(space) / num(sum(least))) :
             least .+ (natural .- least) .* (num(space - sum(least)) / num(sum(natural .- least)))
    flows = [[align(wrap(row[c], widths[c] - 2CELL_X; lh, size=base.size, left=CELL_X), widths[c] - 2CELL_X,
                    # A number stays on the right while you type it. A formula is on the left while its cell shows it.
                    c <= length(cells[r]) && values[r][c].number && !(typing(r, c) && isformula(texts[r][c])) ? :right : :left)
              for c in 1:ncols] for (r, row) in enumerate(parts)]
    heights = [maximum(tall, row) + 2SPREAD_Y for row in flows]
    Grid(rows, widths, heights, cells, flows, lh + 1px, gutter + 1px, values)
  end
  # What inline code made can change its size, so a spreadsheet with some in it is laid out again each time
  any(text -> occursin(INLINE, text), @view b.lines[from:to]) && return build()
  get!(build, e.flows, (:spread, from, b.lines[from:to], caret))
end

"A spreadsheet as nodes: the grid of a table, with a row of letters over it and a column of numbers on its left"
spreadsheet(e::Editor, it::Item, g::Grid) = begin
  b = e.buf
  line = border(1px, :solid, colours.line; between=true)
  size = body(e).size * 0.94
  at = israw(b, b.caret[1]) ? gridcell(g, b.caret) : nothing
  # The letter and the number of the caret's cell are darker
  name(text, on) = Box(height(grow=grow), Alignment.Center, justify=Alignment.Center,
                       label(text, size * 0.72, color=on ? colours.ink : colours.dim, weight=on ? "Semibold" : ""))
  cell(r, c) = begin
    v = c <= length(g.values[r]) ? g.values[r][c] : nothing
    # A formula that went wrong shows a !, which says what went wrong while the mouse is over it
    (v !== nothing && v.failed && at != (r, c)) || return rows(g.flows[r][c])
    [Box(padding(CELL_X, 0px), own!(node!(Document, e, :document), Trouble(message=v.text, size=size * 0.9)))]
  end
  head = Row(width(grow=grow), height(g.head - 1px), Alignment.Start, line[:between], background(colours.head),
    Box(fixed(g.left - 1px), height(grow=grow)),
    [Box(fixed(g.widths[c]), height(grow=grow), name(letters(c), at !== nothing && at[2] == c)) for c in eachindex(g.widths)]...)
  body_rows = [Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between], background(colours.bg),
                 Box(fixed(g.left - 1px), height(grow=grow), background(colours.head), name(string(r), at !== nothing && at[1] == r)),
                 [Column(fixed(g.widths[c]), height(grow=grow), Alignment.Start, justify=Alignment.Center, cell(r, c)...)
                  for c in eachindex(g.widths)]...)
               for r in eachindex(g.rows)]
  Box(width(grow=grow), padding(0px, TABLE_GAP),
    Column(width(grow=grow), Alignment.Start, line, name="Spreadsheet", head, body_rows...))
end

"Draw a line around the cell in row `r`, column `c` of a spreadsheet whose item has its top left corner at (x, y)"
ring(ctx, g::Grid, (r, c), x, y) =
  rectangle(ctx, x + g.left + 1px * c + sum(g.widths[1:c-1], init=0px) - 0.5px,
            y + TABLE_GAP + g.head + 1px * r + sum(g.heights[1:r-1], init=0px) - 0.5px,
            g.widths[c] + 1px, g.heights[r] + 1px, stroke=colours.accent, border=1.5px)

"""
Add or remove a row or a column of the spreadsheet the caret is in, at the
caret. Each formula still names the same cells after it: a cell that moved has
a new name, so the formula is written with that name.
"""
spreadop!(e, action::Symbol) = begin
  b = e.buf
  i = b.caret[1]
  inspread(b, i) || return
  s, t = spread(b, i)
  rows = map(spreadtexts, b.lines[s+1:t-1])
  n = maximum(length, rows)
  rows = [[row; fill("", n - length(row))] for row in rows]
  r = i - s                                           # the caret's row
  c = nearest(spreadcells(b.lines[i]), b.caret[2])    # and its column
  if action == :addrow
    r += 1
    rows = [moved.(row, 1, row=r) for row in rows]
    insert!(rows, r, fill("", n))
  elseif action == :delrow
    length(rows) == 1 && return
    deleteat!(rows, r)
    rows = [moved.(row, -1, row=r + 1) for row in rows]
    r = min(r, length(rows))
  elseif action == :addcol
    c += 1
    rows = [moved.(row, 1, col=c) for row in rows]
    foreach(row -> insert!(row, c, ""), rows)
  elseif action == :delcol
    n == 1 && return
    foreach(row -> deleteat!(row, c), rows)
    rows = [moved.(row, -1, col=c + 1) for row in rows]
    c = min(c, n - 1)
  else
    return
  end
  edit!(b, (s + 1, 0), line_end(b, t - 1), join(map(tableline, rows), "\n"))
  b.caret = b.anchor = (s + r, spreadcells(b.lines[s+r])[c].hi)
  touch!(e)
end

"Backspace in an empty row of a spreadsheet removes the row, and the last row takes the spreadsheet with it"
droprow!(e) = begin
  b = e.buf
  i = b.caret[1]
  s, t = spread(b, i)
  t - s == 2 && return (edit!(b, (s, 0), line_end(b, t), ""); touch!(e))
  spreadop!(e, :delrow)
  above = max(i - 1, s + 1)
  b.caret = b.anchor = (above, spreadcells(b.lines[above])[end].hi)
  touch!(e)
end

# --- sheets ----------------------------------------------------------------------------
#
# A code block in the language `sheet` is drawn as a sheet, like the one in
# Centient's notepad. Each line of the block is a row: a name, an = and a Julia
# expression. The expression can use the names of the rows above it the way
# they're written, and those names show as chips. What each row comes to shows
# on its right. A row without a name shows its number instead.
#
# The caret moves from cell to cell, as it does in a table. Tab and shift-Tab
# go to the next and the last cell, and Return starts a row. Hold ⌥ and click
# the sheet to see it as lines of code.

const SHEET_GAP = 8px   # above and below a sheet
const SHEET_X = 10px    # beside the text of a cell
const SHEET_Y = 4px     # above the first row and below the last
const RAISE = 0.28      # of the size of the text: how far a character from the spare font goes up, twice over
const RESULT_X = 8px    # beside the text of what a row comes to

# A sheet's text is in Source Code Pro ExtraLight, a step lighter than
# Centient's Light. A Mac without that font gets the font of the code blocks.
const SHEET_FILE = something(findfirst(isfile, joinpath.((joinpath(homedir(), "Library/Fonts"), "/Library/Fonts"),
                                                         "SourceCodePro-ExtraLight.ttf")) |>
                             i -> i === nothing ? nothing : joinpath((joinpath(homedir(), "Library/Fonts"), "/Library/Fonts")[i],
                                                                     "SourceCodePro-ExtraLight.ttf"), "")
const SHEET_FONT = isempty(SHEET_FILE) ? MONO : "Source Code Pro"
const SHEET_WEIGHT = isempty(SHEET_FILE) ? "" : "ExtraLight"

"""
Read the sheet's font from its file. A request for a weight of this font by
name can come back in another weight, so the file is read itself. This runs each time an
editor is made, because a built app forgets its fonts when it starts.
"""
load_sheet_font() = isempty(SHEET_FILE) || register_font(SHEET_FILE)

"A sheet laid out"
struct Sheet
  rows::Vector{Int}             # the line of the document each row comes from
  cells::Vector{Vector{Cell}}   # each row's name and expression, or only its expression
  names::Vector{Flow}
  exprs::Vector{Flow}
  results::Vector{Result}       # what each row comes to
  heights::Vector{px}
  name_w::px                    # how wide the column of names is
  size::px                      # of the text
end

"""
The lines that open and close the sheet that line `i` is in, or nothing. A
sheet needs a row, and it shows as lines of code while the caret is on the
line that opens or closes it.
"""
sheet(b::Buffer, i::Int) = drawn(b, i, SHEET)

"The lines that open and close the code block in the language `lang` that line `i` is in, when the block is drawn as a sheet or a spreadsheet"
drawn(b::Buffer, i::Int, lang::String) = begin
  ks = kinds(b)
  (ks[i].kind == Kind.fence || (ks[i].kind == Kind.code && ks[i].lang == lang)) || return nothing
  s, t = codeblock(b, i)
  (t > s + 1 && ks[s].kind == Kind.fence && ks[s].lang == lang && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  israw(b, s) || israw(b, t) ? nothing : (s, t)
end

"True when line `i` is a row of a sheet"
insheet(b::Buffer, i::Int) = begin
  run = sheet(b, i)
  run !== nothing && run[1] < i < run[2]
end

"""
The runs of text in the expression that is columns `lo` to `hi` of `text`. Each
of `names` is a chip, and a * that multiplies shows as ×.
"""
exprpieces(text::String, lo::Int, hi::Int, names, base::Face) = begin
  expr = rest(head(text, hi), lo)
  chars = collect(expr)
  faces = fill(base, length(chars))
  times = [c == '*' for c in chars]
  for t in tokens(expr, "julia")
    t.kind == :plain && continue
    span = t.col+1:t.col+length(t.text)
    faces[span] .= Ref(Face(base, color=getfield(colours, t.kind)))
    # A * in a string or a comment is only a *
    t.kind in (:string, :comment) && (times[span] .= false)
  end
  for (a, z, _) in uses(expr, names)
    faces[a+1:z] .= Ref(Face(base, chip=true))
  end
  out = Piece[]
  i = 1
  while i <= length(chars)
    if times[i]
      push!(out, piece("×", lo + i - 1, faces[i], atomic=true, n=1))
      i += 1
      continue
    end
    j = i
    while j < length(chars) && faces[j+1] === faces[i] && !times[j+1]; j += 1 end
    push!(out, piece(String(chars[i:j]), lo + i - 1, faces[i]))
    i = j + 1
  end
  out
end

"How wide the chip that shows `r` is. A row that went wrong shows a !."
chip_w(face::Face, r::Result) =
  isempty(r.text) ? 0px : r.failed ? measure(face, "!") + 2RESULT_X : sum(measure(f, t) for (t, f) in runs(r.text, face)) + 2RESULT_X

const drawable = Dict{Tuple{String,String,Char},Bool}()

"True when the font of `face` has a letter shape for `c`"
has(face::Face, c::Char) =
  get!(drawable, (face.family, face.style, c)) do
    Skia.sk_font_unichar_to_glyph(skia_font(face.family, face.size, face.style).raw, Int32(c)) != 0
  end

"""
`text` in runs, each with the face to draw it in. A character that the font of
`face` doesn't have, like the raised minus of m⁻¹, is in Menlo, which has it.
One that Menlo lacks too, like ⋮, is in a font of symbols.
"""
runs(text::AbstractString, face::Face) = begin
  spare, symbols = Face(face, family=MONO, style=""), Face(face, family=SPARE_FONT, style="")
  out = Tuple{String,Face}[]
  for c in text
    f = isascii(c) || has(face, c) ? face : has(spare, c) ? spare : has(symbols, c) ? symbols : face
    if !isempty(out) && last(out)[2] === f
      out[end] = (last(out)[1] * c, f)
    else
      push!(out, (string(c), f))
    end
  end
  out
end

"True when the font of `face` has every character of `text`"
hasall(face::Face, text::AbstractString) = all(c -> isascii(c) || has(face, c), text)

"""
The pieces `ps` of a line, with each character that the code font lacks in a
piece of its own, in a font that has it. A `code` chip stays one piece, and
draws those characters itself.
"""
spare(ps::Vector{Piece}) = begin
  whole(p) = p.face.family != codefont() || p.face.chip || p.atomic || p.node !== nothing || hasall(p.face, p.text)
  all(whole, ps) && return ps
  out = Piece[]
  for p in ps
    whole(p) && (push!(out, p); continue)
    col = p.col
    for (part, f) in runs(p.text, p.face)
      push!(out, Piece(part, col, length(part), f, false, p.link, nothing))
      col += length(part)
    end
  end
  out
end

"`text` in the face `f`, as the parts of a row. A character that the font lacks is in a font that has it."
spared(text::AbstractString, f::Face) =
  [Box(fixed(measure(pf, part)), Alignment.Start,
     Text(part, size=pf.size, family=pf.family, subfamily=pf.style, color=pf.color, wrap=WrapMode.none)) for (part, pf) in runs(text, f)]

"Lay out the sheet whose code block opens on line `from` and closes on line `to`"
sheetgrid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = from < b.caret[1] < to && b.caret[1] == b.anchor[1] ? b.caret : nothing
  # The layout holds the number of each row's line, so it's kept for these lines only
  get!(e.flows, (:sheet, from, b.lines[from+1:to-1], caret)) do
    size = body(e).size * 0.86
    lh = size * 1.7
    ink = Face(SHEET_FONT, SHEET_WEIGHT, size, colours.ink, false)
    rows = collect(from+1:to-1)
    cells = [sheetcells(b.lines[i]) for i in rows]
    texts = [parts(b.lines[i]) for i in rows]
    # The rows are only worked out again when the text of one changes
    results = get!(() -> tally(texts), e.flows, (:sheetrun, texts))
    # The cell with the caret shows the spaces typed after its text
    upto(i, c) = caret !== nothing && caret[1] == i && within(c, caret[2]) ? max(c.hi, caret[2]) : c.hi
    names = map(zip(rows, cells)) do (i, cs)
      length(cs) == 2 || return Piece[]
      text = rest(head(b.lines[i], upto(i, cs[1])), cs[1].lo)
      isempty(text) ? Piece[] : [piece(text, cs[1].lo, ink)]
    end
    name_w = clamp(maximum(ps -> sum(p -> measure(p.face, p.text), ps, init=0px), names, init=0px) + 2px, 3size, e.width * 0.4)
    # An expression has the room that its row's name and result leave it
    room = e.width - 3px - 4SHEET_X - name_w
    exprs = map(enumerate(rows)) do (r, i)
      c = cells[r][end]
      chip = chip_w(ink, results[r])
      wrap(exprpieces(b.lines[i], c.lo, upto(i, c), known(texts, r), ink), max(80px, room - chip - (chip > 0px ? SHEET_X : 0px)); lh, size)
    end
    nameflows = [wrap(ps, name_w; lh, size) for ps in names]
    heights = [max(tall(n), tall(x)) for (n, x) in zip(nameflows, exprs)]
    Sheet(rows, cells, nameflows, exprs, results, heights, name_w, size)
  end
end

tall(s::Sheet) = sum(s.heights) + 2px + 2SHEET_Y + 2SHEET_GAP

"How far the top of row `r` is from the top of the sheet's item"
row_top(s::Sheet, r::Int) = SHEET_GAP + 1px + SHEET_Y + sum(s.heights[1:r-1], init=0px)

"How far the text of an expression starts from the left of the sheet"
expr_x(s::Sheet) = 2px + 3SHEET_X + s.name_w

"The layout of cell `k` of row `r`, and how far its text starts from the left of the sheet"
cellflow(s::Sheet, r::Int, k::Int) =
  length(s.cells[r]) == 2 && k == 1 ? (s.names[r], 1px + SHEET_X) : (s.exprs[r], expr_x(s))

"Which cell of row `r` is under a point `x` from the left of the sheet"
cellunder(s::Sheet, r::Int, x::px) = length(s.cells[r]) == 2 && x < expr_x(s) - SHEET_X ? 1 : length(s.cells[r])

"The row of the sheet under a point `y` from the top of its item"
rowunder(s::Sheet, y::px) = something(findfirst(r -> y < row_top(s, r) + s.heights[r], eachindex(s.rows)), length(s.rows))

"The place in row `r` nearest to `x`, on the first line of the row's cell, or on its last when `by` is -1"
place(s::Sheet, r::Int, by::Int, x::px) = begin
  k = cellunder(s, r, x)
  f, dx = cellflow(s, r, k)
  (s.rows[r], cellcol(f, by < 0 ? length(f.lines) : 1, x - dx, s.cells[r][k]))
end

"Where the caret goes when ↑ or ↓ brings it into a sheet from the line above or below it"
enter(e, it::Item, s::Sheet, by::Int, x::px) = place(s, by > 0 ? 1 : length(s.rows), by, x)

"""
One run of text of a sheet, in a box as tall as the line with the text in the
middle of it. A name of another row is a chip with round ends.
"""
sheetseg(seg::Seg, lh::px) = begin
  f = seg.face
  t = Text(seg.text, size=f.size, family=f.family, subfamily=f.style, color=f.color, wrap=WrapMode.none)
  f.chip || return Box(fixed(seg.w), height(lh), Alignment.Center, t)
  h = f.size * 1.45
  Box(fixed(seg.w), height(lh), Alignment.Center,
    Box(fixed(seg.w), height(h), padding(CHIP_X, 0px), radius(h / 2), background(colours.chip), border(1px, :solid, colours.chip_line), t))
end

sheetlines(f::Flow) =
  [Row(width(grow=grow), height(f.lh), Alignment.Center, padding(0px, 0px, 0px, vl.x), clip=true,
       [sheetseg(seg, f.lh) for seg in vl.segs]...) for vl in f.lines]

describe(e::Editor, it::Item, s::Sheet) = begin
  b = e.buf
  lh = s.size * 1.7
  n = length(s.rows)
  bare(f) = isempty(f.lines[1].segs)
  hint(text) = Row(height(lh), Text(text, size=s.size, family=SHEET_FONT, subfamily=SHEET_WEIGHT, color=colours.faint, wrap=WrapMode.none))
  rows = map(1:n) do r
    above, below = (r == 1 ? SHEET_Y : 0px), (r == n ? SHEET_Y : 0px)
    pad = padding(above, SHEET_X, below, SHEET_X)
    # The caret is in this row's expression
    typing = b.caret[1] == b.anchor[1] == s.rows[r] && nearest(s.cells[r], b.caret[2]) == length(s.cells[r])
    res = s.results[r]
    w = chip_w(Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false), res)
    chip = isempty(res.text) ? () :
      (Column(fixed(w + SHEET_X), height(grow=grow), Alignment.Start, padding(above + 1px, SHEET_X, 0px, 0px),
         res.failed ? own!(node!(Document, e, :document), Trouble(message=res.text, size=s.size)) :
           Row(fixed(w), height(lh - 2px), Alignment.Center, padding(RESULT_X, 0px), radius(6px), background(colours.chip),
             # Menlo's raised signs sit lower than Source Code Pro's raised digits, so they go up a little
             [Box(padding(0px, 0px, f.family == SHEET_FONT ? 0px : s.size * RAISE, 0px),
                Text(t, size=s.size, family=f.family, subfamily=f.style, color=colours.ink, wrap=WrapMode.none))
              for (t, f) in runs(res.text, Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false))]...)),)
    Row(width(grow=grow), height(s.heights[r] + above + below), Alignment.Start,
      # A row without a name shows its number
      Column(fixed(s.name_w + 2SHEET_X + 1px), height(grow=grow), Alignment.Start, pad, border(1px, :solid, colours.line)[:right],
        (bare(s.names[r]) ? (hint(string(r)),) : sheetlines(s.names[r]))...),
      Column(width(grow=grow), height(grow=grow), Alignment.Start, pad,
        (bare(s.exprs[r]) && typing ? (hint("expression"),) : sheetlines(s.exprs[r]))...),
      chip...)
  end
  Box(width(grow=grow), padding(0px, SHEET_GAP),
    Column(width(grow=grow), Alignment.Start, radius(6px), background(colours.float), border(1px, :solid, colours.line), name="Sheet",
      rows...))
end

describe(t::Trouble) = begin
  w = measure(Face(SHEET_FONT, SHEET_WEIGHT, t.size, colours.accent, false), "!") + 2RESULT_X
  Box(fixed(w), height(t.size * 1.7 - 2px), padding(RESULT_X, 0px), radius(6px), background(colours.chip),
    Text("!", size=t.size, family=MONO, subfamily="Bold", color=colours.accent, wrap=WrapMode.none))
end

draw(ctx, size, ui::ConcreteRect, t::Trouble) = (t.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(t::Trouble, ev::MouseMove) =
  show_tooltip!(ev.window, tip_label(t.message), t.rect..., placement=:bottom, gap=6px)

"""
The boxes that cover the selected part of a sheet whose top left corner is at
(x, y). A selection that covers several lines takes each row whole.
"""
marks(e, it::Item, s::Sheet, x, y) = begin
  b = e.buf
  out = Rect[]
  selecting(b) || return out
  lo, hi = selection(b)
  if b.caret[1] != b.anchor[1]
    n = length(s.rows)
    bottom = y + it.tall - SHEET_GAP
    lo[1] <= it.first && hi[1] >= it.first && push!(out, (num(x), num(y), num(x + 7px), num(y + SHEET_GAP)))
    for (r, i) in enumerate(s.rows)
      lo[1] <= i <= hi[1] || continue
      top = r == 1 ? y + SHEET_GAP : y + row_top(s, r)
      push!(out, (num(x), num(top), num(x + e.width), num(r == n ? bottom : y + row_top(s, r + 1))))
    end
    lo[1] <= it.last && hi[1] >= it.last && push!(out, (num(x), num(bottom), num(x + 7px), num(y + it.tall)))
    return out
  end
  r = findfirst(==(b.caret[1]), s.rows)
  r === nothing && return out
  sel = selected(b, s.rows[r])
  for (k, cell) in enumerate(s.cells[r])
    (sel[1] < cell.limit && sel[2] > cell.lo) || continue
    f, dx = cellflow(s, r, k)
    append!(out, marks(f, x + dx, y + row_top(s, r), (max(sel[1], cell.lo), min(sel[2], cell.limit), false), margin=false))
  end
  out
end

"Draw the caret in the cell of a sheet that it's in. The sheet's top left corner is at (x, y)."
caret(ctx, e, s::Sheet, x, y) = begin
  p = e.buf.caret
  r = findfirst(==(p[1]), s.rows)
  r === nothing && return
  f, dx = cellflow(s, r, nearest(s.cells[r], p[2]))
  caret(ctx, e, f, x + dx, y + row_top(s, r), p[2])
end

"The place in a sheet under a point that is (dx, dy) from the top left of its item"
locate(e, it::Item, s::Sheet, dx, dy) = begin
  r = rowunder(s, dy)
  k = cellunder(s, r, dx)
  f, x = cellflow(s, r, k)
  line = clamp(floor(Int, num(dy - row_top(s, r)) / num(f.lh)) + 1, 1, length(f.lines))
  (s.rows[r], cellcol(f, line, dx - x, s.cells[r][k]))
end

"""
A click on a sheet. It returns true when it has put the caret somewhere itself.
With ⌥ held, the sheet shows as lines of code. A click where a row's name goes
gives a row that has no name a place for one.
"""
press!(e, it::Item, s::Sheet, pos) = begin
  b = e.buf
  if held(e, Keys.opt)
    b.caret = b.anchor = line_end(b, it.first)
    return true
  end
  r = rowunder(s, pos[2] - e.origin[2] - it.top)
  (length(s.cells[r]) == 1 && pos[1] - e.origin[1] < expr_x(s) - SHEET_X) || return false
  name_row!(e, s.rows[r])
  true
end

"Give the row on line `i`, which has no name, a place for one, and put the caret there"
name_row!(e, i::Int) = begin
  b = e.buf
  edit!(b, (i, 0), (i, 0), " = ")
  b.caret = b.anchor = (i, 0)
  e.clicked = (time(), (i, 0), 1)
  touch!(e)
end

"""
Where the caret goes when it's sent to `p` in the sheet that runs from line `s`
to line `t`. See `settle` for a table. A spreadsheet works the same way, with
`cells` to read the cells of a row.
"""
settle(b::Buffer, (s, t)::Tuple{Int,Int}, p::Pos, by::Int, cells=sheetcells) = begin
  i, col = p
  first_cell(i) = (i, cells(b.lines[i])[1].lo)
  last_cell(i) = (i, cells(b.lines[i])[end].hi)
  # The lines that open and close the sheet don't show, so the caret steps over them
  i == s && return by < 0 && s > 1 ? line_end(b, s - 1) : first_cell(s + 1)
  i == t && return by > 0 && t < length(b.lines) ? (t + 1, 0) : last_cell(t - 1)
  cs = cells(b.lines[i])
  any(c -> within(c, col), cs) && return p
  if by < 0
    c = findlast(c -> c.limit < col, cs)
    c === nothing || return (i, cs[c].hi)
    i - 1 > s ? last_cell(i - 1) : s > 1 ? line_end(b, s - 1) : first_cell(i)
  elseif by > 0
    c = findfirst(c -> c.lo > col, cs)
    c === nothing || return (i, cs[c].lo)
    i + 1 < t ? first_cell(i + 1) : t < length(b.lines) ? (t + 1, 0) : last_cell(i)
  else
    c = cs[nearest(cs, col)]
    (i, clamp(col, c.lo, c.limit))
  end
end

"The place one line up or down from the caret, which is in a sheet"
vertical(e, it::Item, s::Sheet, by::Int) = begin
  b = e.buf
  # The caret can be on the line that opens or closes the sheet, at the end of a selection
  r = something(findfirst(==(b.caret[1]), s.rows), b.caret[1] <= it.first ? 1 : length(s.rows))
  k = nearest(s.cells[r], b.caret[2])
  f, dx = cellflow(s, r, k)
  line, x = spot(f, b.caret[2])
  x = e.goal = something(e.goal, x + dx)
  1 <= line + by <= length(f.lines) && return (b.caret[1], cellcol(f, line + by, x - dx, s.cells[r][k]))
  r += by
  1 <= r <= length(s.rows) && return place(s, r, by, x)
  if by < 0
    it.first == 1 && return b.caret
    f = flow(e, it.first - 1, true)
    return (it.first - 1, colat(f, length(f.lines), x))
  end
  # ↓ on the last row of a sheet at the end of the document starts a line below it
  it.last == length(b.lines) && edit!(b, line_end(b, it.last), line_end(b, it.last), "\n")
  (it.last + 1, colat(flow(e, it.last + 1, true), 1, x))
end

"Return in a sheet starts a row under the caret's row. In a last row that's empty, it ends the sheet instead."
next_row!(e) = begin
  b = e.buf
  i = b.caret[1]
  s, t = sheet(b, i)
  if i == t - 1 && t - s > 2 && all(isempty, parts(b.lines[i]))
    edit!(b, line_end(b, i - 1), line_end(b, t), "\n" * b.lines[t] * "\n")
    b.caret = b.anchor = (t, 0)
    return touch!(e)
  end
  edit!(b, line_end(b, i), line_end(b, i), "\n = ")
  b.caret = b.anchor = (i + 1, 0)
  touch!(e)
end

"""
Tab in a sheet goes to the next cell and selects what's in it, or with `back`
to the one before. Going on from the last cell adds a row, and going back from
an expression that has no name makes a place for one.
"""
sheet_tab!(e, back::Bool) = begin
  b = e.buf
  i, col = b.caret
  s, t = sheet(b, i)
  cs = sheetcells(b.lines[i])
  k = nearest(cs, col)
  pick(i, c) = begin
    b.anchor, b.caret = (i, c.lo), (i, c.hi)
    touch!(e)
  end
  if back
    length(cs) == 1 && return name_row!(e, i)
    k == 2 && return pick(i, cs[1])
    return i - 1 > s ? pick(i - 1, sheetcells(b.lines[i-1])[end]) : nothing
  end
  k < length(cs) && return pick(i, cs[2])
  i + 1 < t && return pick(i + 1, sheetcells(b.lines[i+1])[1])
  edit!(b, line_end(b, i), line_end(b, i), "\n = ")
  b.caret = b.anchor = (i + 1, 0)
  touch!(e)
end

"""
Backspace in a sheet, when it does more than delete a character. In a row
that's empty it takes the row away, and the last row takes the sheet with it.
At the start of an expression it goes back to the row's name. It returns true
when it did one of these.
"""
erase_row!(e, to::Pos) = begin
  b = e.buf
  i, col = b.caret
  to < b.caret || return false
  s, t = sheet(b, i)
  cs = sheetcells(b.lines[i])
  if all(isempty, parts(b.lines[i]))
    if t - s == 2
      edit!(b, (s, 0), line_end(b, t), "")
    elseif i - 1 > s
      edit!(b, line_end(b, i - 1), line_end(b, i), "")
    else
      edit!(b, (i, 0), (i + 1, 0), "")
      b.caret = b.anchor = settle(b, (i, 0), 1)
    end
    touch!(e)
    return true
  end
  (length(cs) == 2 && col == cs[2].lo && nearest(cs, col) == 2) || return false
  b.caret = b.anchor = (i, cs[1].hi)
  touch!(e)
  true
end

# --- the names a sheet offers ----------------------------------------------------------
#
# While you type a name in an expression of a sheet, a list under the caret
# shows the names of the rows above that start the same way. ↑ and ↓ choose
# one, Return or Tab types the rest of it, and esc hides the list.

isnamechar(c::Char) = isletter(c) || isdigit(c) || c == '_'

"""
The names that the text before the caret could be the start of: the line, the
column where the name starts, and the names. Nothing when the caret isn't in an
expression of a sheet, or no name fits. A name fits when it starts with what's
typed, or when one of its words does.
"""
offered(e) = begin
  b = e.buf
  i, col = b.caret
  selecting(b) && return nothing
  insheet(b, i) || return code_offered(e)   # a code block offers names too
  cs = sheetcells(b.lines[i])
  c = cs[end]
  (c.lo <= col <= c.limit && nearest(cs, col) == length(cs)) || return nothing
  s, _ = sheet(b, i)
  rows = [parts(b.lines[j]) for j in s+1:i-1]
  names = known(rows, length(rows) + 1)
  isempty(names) && return nothing
  chars = collect(b.lines[i])
  # In the middle of a word, nothing is offered
  col < length(chars) && isnamechar(chars[col+1]) && return nothing
  before = map(lowercase, chars[c.lo+1:col])
  # The longest run of words before the caret that starts a name wins, so "wall l" finds "Wall length"
  for from in max(1, length(before) - 40):length(before)
    (isletter(before[from]) || before[from] == '_') || continue
    from > 1 && isnamechar(before[from-1]) && continue
    typed = String(before[from:end])
    fits(n) = lowercase(n) != typed && (startswith(lowercase(n), typed) || any(w -> startswith(w, typed), split(lowercase(n))))
    found = filter(fits, names)
    isempty(found) || return (i, c.lo + from - 1, found)
    # A whole name is typed already, so its last words aren't the start of another
    any(n -> lowercase(n) == typed, names) && return nothing
  end
  nothing
end

"Which name of the list is chosen, and the list that esc hid. Each is kept with the place its list is for."
suggesting(e) = get!(() -> Ref{Any}((at=(0, 0), chosen=1, hidden=(0, 0))), e.nodes, :suggesting)

"The list of names to show now: the line, the column where the name starts, the names and which one is chosen. Or nothing."
suggestion(e) = begin
  e.buf.reading && return nothing
  found = offered(e)
  state = suggesting(e)[]
  # A list that esc hid stays hidden while its name is being typed, and no longer
  if state.hidden != (0, 0) && (found === nothing || state.hidden != (found[1], found[2]))
    state = suggesting(e)[] = (at=state.at, chosen=state.chosen, hidden=(0, 0))
  end
  found === nothing && return nothing
  i, start, names = found
  state.hidden == (i, start) && return nothing
  (i, start, names, state.at == (i, start) ? clamp(state.chosen, 1, length(names)) : 1)
end

"What a key does while the list of names shows. It returns true when the key was for the list."
suggest_key!(e, K) = begin
  found = suggestion(e)
  found === nothing && return false
  i, start, names, chosen = found
  state = suggesting(e)
  if K == Keys.down || K == Keys.up
    state[] = (at=(i, start), chosen=mod1(chosen + (K == Keys.down ? 1 : -1), length(names)), hidden=(0, 0))
  elseif K == Keys.enter || K == Keys.tab
    edit!(e.buf, (i, start), e.buf.caret, names[chosen])
  elseif K == Keys.escape
    state[] = (at=(0, 0), chosen=1, hidden=(i, start))
  else
    return false
  end
  touch!(e)
  true
end

"The list of names, placed in the window under the name being typed. Nothing when there's no list to show."
suggestbox(e) = begin
  found = suggestion(e)
  found === nothing && return ()
  i, start, names, chosen = found
  it = item(e, i)
  s = it.content
  # Where the name starts, from the left of the page's text and from the top of the item, and the font of the list
  if s isa Sheet
    r = findfirst(==(i), s.rows)
    r === nothing && return ()
    f, dx = cellflow(s, r, length(s.cells[r]))
    k, x = spot(f, start)
    face = Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false)
    across, down = dx + x, row_top(s, r) + f.lh * k
  elseif s isa Flow
    # In a code block, the list is under the line of the screen that the name is on
    k, x = spot(s, start)
    face = Face(codefont(), codestyle(), s.size, colours.ink, false)
    across, down = x, line_top(s, k) + s.lines[k].high
  else
    return ()
  end
  wide = max(150px, maximum(n -> measure(face, n), names) + 26px)
  list = Column(fixed(wide), Alignment.Start, padding(4px), radius(7px), background(colours.float), border(1px, :solid, colours.line), lifted,
    name="Names",
    [Row(width(grow=grow), height(face.size * 1.8), Alignment.Center, padding(8px, 0px), radius(4px),
         background(j == chosen ? colours.active : clear),
       Text(n, size=face.size, family=face.family, subfamily=face.style, color=colours.ink, wrap=WrapMode.none))
     for (j, n) in enumerate(names)]...)
  left = text_left(e) + across - 9px
  top = TOPBAR_H + PAGE_TOP + it.top - e.scroll.offset + down + 3px
  top >= TOPBAR_H || return ()
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), list),)
end

# --- the page's layout ---------------------------------------------------------------

# --- live blocks ---------------------------------------------------------------------
#
# A code block in the language `ui` holds Julia code. The page runs it once and
# shows its value where the block is: a UI node from any module, or any other
# value as text. The node is kept, so a node with state keeps it between frames.
#
# The code can use the names that pages use most with no line that loads them:
# UI.jl's components, like Slider and STLViewer, the parts of a layout, like
# Column and px, a file path as fs"notes.md" and a colour as colorant"tomato".

const LIVE = "ui"
const LIVE_GAP = 8px   # above and below what a live block shows

"The modules whose names a live block can use with no line that loads them"
const USUAL = ("github.com/jkroso/UI.jl/Interface/Semantic", "github.com/jkroso/UI.jl/Interface/Geometric")

"Give the module `m` each name that the module at `path` exports"
share!(m, path) = begin
  from = include_string(m, "@use $(repr(path))")
  # The module can be new, so its names are asked for as they are now
  for name in Base.invokelatest(names, from)
    # A menu and a tree each have an Item, so a block loads the one it means
    (name == nameof(from) || name == :Item) && continue
    Core.eval(m, :(const $name = $(Base.invokelatest(getglobal, from, name))))
  end
end

"The module that the live blocks of every document run in"
sandbox(e) = get!(e.nodes, :sandbox) do
  m = Module(:Page)
  # Kip by the module that's loaded here, not by name. A built app can't find a package by name.
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  foreach(path -> share!(m, path), USUAL)
  include_string(m, "@use \"github.com/jkroso/URI.jl/FSPath\" FSPath @fs_str")
  Core.eval(m, :(const $(Symbol("@colorant_str")) = $(var"@colorant_str")))
  # A live block can read and set the page's colours: `page_theme()` gives "Sepia", "Paper" or "Night"
  Core.eval(m, :(const page_theme = $(() -> (reads!(e, :theme); titlecase(string(e.theme))))))
  Core.eval(m, :(const page_theme! = $(name -> theme!(e, Symbol(lowercase(string(name)))))))
  # ... and the size of the page's text, in pixels
  Core.eval(m, :(const page_text_size = $(() -> (reads!(e, :zoom); TEXT_SIZE.value * e.zoom))))
  Core.eval(m, :(const page_text_size! = $(size -> text_size!(e, size))))
  # ... and the font of the page's text, by name
  Core.eval(m, :(const page_font = $(() -> (reads!(e, :font); e.font))))
  Core.eval(m, :(const page_font! = $(name -> font!(e, String(name)))))
  # ... and the width of the page, in pixels
  Core.eval(m, :(const page_width = $(() -> e.widest.value)))
  Core.eval(m, :(const page_width! = $(width -> page_width!(e, width))))
  # ... and what the count at the top right counts: `page_count()` gives "Words", "Characters" or "Reading time"
  Core.eval(m, :(const page_count = $(() -> (reads!(e, :stat); STAT_NAMES[findfirst(==(e.stat), STATS)]))))
  Core.eval(m, :(const page_count! = $(name -> stat!(e, STATS[something(findfirst(==(String(name)), STAT_NAMES), 1)]))))
  # ... and whether the page checks its spelling
  Core.eval(m, :(const page_spelling = $(() -> (reads!(e, :spelling); e.spelling))))
  Core.eval(m, :(const page_spelling! = $(on -> spelling!(e, Bool(on)))))
  # ... and whether a line of a file of code that's too long for the window goes on under itself
  Core.eval(m, :(const code_wrap = $(() -> (reads!(e, :wrap); e.wrap))))
  Core.eval(m, :(const code_wrap! = $(on -> wrap!(e, Bool(on)))))
  # ... and whether it shows the number of each line, and shades the line that the caret is on
  Core.eval(m, :(const code_numbers = $(() -> (reads!(e, :numbers); e.numbers))))
  Core.eval(m, :(const code_numbers! = $(on -> numbers!(e, Bool(on)))))
  Core.eval(m, :(const code_shade = $(() -> (reads!(e, :shade); e.shade))))
  Core.eval(m, :(const code_shade! = $(on -> shade!(e, Bool(on)))))
  # ... and how many spaces one step of indentation is in code: 2 or 4
  Core.eval(m, :(const code_indent = $(() -> (reads!(e, :indent); e.indent))))
  Core.eval(m, :(const code_indent! = $(n -> indent_width!(e, Int(n)))))
  # ... and how big code is, in pixels. It grows and shrinks with the page's text.
  Core.eval(m, :(const code_text_size = $(() -> (reads!(e, :code_scale); reads!(e, :zoom); code_size(e).value))))
  Core.eval(m, :(const code_text_size! = $(size -> code_size!(e, size))))
  # ... and the font of code, by the name in the list of `code_fonts()`. `code_family(name)` gives the font's own name, to draw the name in.
  Core.eval(m, :(const code_fonts = $(() -> font_label.(unique([code_fonts(); e.code_font])))))
  Core.eval(m, :(const code_family = $(name -> font_family(String(name)))))
  Core.eval(m, :(const code_font = $(() -> (reads!(e, :code_font); font_label(e.code_font)))))
  Core.eval(m, :(const code_font! = $(name -> code_font!(e, font_family(String(name))))))
  # ... and after how many characters a faint line goes down a file of code. 0 is no line.
  Core.eval(m, :(const code_guide = $(() -> (reads!(e, :guide); e.guide))))
  Core.eval(m, :(const code_guide! = $(n -> guide!(e, Int(n)))))
  # ... and the app that opens Markdown files: `markdown_app()` gives its name, like "Kaydown", or "" when macOS can't say.
  # `default_app!()` asks macOS to make that app Kaydown. It gives false when the Kaydown app isn't installed.
  # `app_installed()` is true when the Kaydown app is on this Mac.
  Core.eval(m, :(const markdown_app = $(() -> (reads!(e, :app); app_name(markdown_app())))))
  Core.eval(m, :(const app_installed = $(() -> (reads!(e, :app); !isempty(app_path())))))
  Core.eval(m, :(const default_app! = $(() -> default_app!(e))))
  # The units that a sheet has, from Units.jl, so that code can work with lengths, times and so on: 12m * 2.4m.
  # They come in with `using`, so a name that a block makes or loads for itself wins over a unit with that name.
  Core.eval(m, :(const SheetUnits = $(units())))
  Core.eval(m, :(using .SheetUnits))
  m
end

"""
Note that the live block that's running now asked for a setting of the page:
`:theme`, `:zoom`, `:font` or `:stat`. Such a block is run again when the setting changes, so
what it shows stays true.
"""
reads!(e, setting::Symbol) = begin
  key = get(e.nodes, :running, nothing)
  key === nothing || push!(get!(() -> Set{Any}(), e.nodes, (:readers, setting)), key)
  nothing
end

"""
Ask macOS to make Kaydown the app that opens Markdown files, for the button on
the settings page. macOS asks you to confirm, so the window then looks for
your answer. It's false when the Kaydown app isn't installed.
"""
default_app!(e) = begin
  before = markdown_app()
  make_default!() || return false
  e.nodes[:asked] = (time(), before, time())
  true
end

"Run again the live blocks that asked for `setting`"
rerun!(e, setting::Symbol) = foreach(pop!(e.nodes, (:readers, setting), ())) do key
  # What the block made before is kept until it runs again, so that what it makes then can
  # carry on from it, like a chooser whose choice was clicked sliding to it
  old = pop!(e.nodes, key, nothing)
  old === nothing || (e.nodes[(:replaced, key)] = old)
end

"""
Wrap the page's text again, for a live block that changed a setting. The block
under the mouse stays where it is in the window, so a slider that's being
dragged doesn't move up or down, away from the mouse.
"""
rewrap!(e) = begin
  save_settings!(e)
  empty!(e.flows)
  win = window_of(e)
  if win !== nothing && !isempty(e.layout)
    y = win.mouse[2] - TOPBAR_H - PAGE_TOP + e.scroll.offset
    i = findfirst(it -> it.top <= y < it.top + it.tall, e.layout)
    i === nothing || (e.nodes[:hold] = (e.layout[i].first, e.layout[i].top - e.scroll.offset))
  end
  e
end

"Make the page's text `size` pixels tall, for a live block"
text_size!(e, size) = (e.zoom = zoom_for(size); rewrap!(e))

const NARROWEST, WIDEST = 400, 1200   # the page widths that the settings page offers

"""
Make the page `width` pixels wide, to the nearest ten, for a live block. That's
its width while the text is its usual size: bigger text gets a wider page, so
a line holds as many words as before. A window that's too narrow for the page
shows it as wide as it can.
"""
page_width!(e, width) = (e.widest = px(clamp(10round(Int, width / 10), NARROWEST, WIDEST)); rewrap!(e))

"Draw the page's text in the font called `name`"
font!(e, name::String) = (e.font = name; save_settings!(e); rerun!(e, :font); restyle!(e))

"Use the colours called `name` for the page"
theme!(e, name::Symbol) = begin
  name in THEME_ORDER || error("The page's colours are Sepia, Paper and Night. $name isn't one of them.")
  e.theme = name
  save_settings!(e)
  rerun!(e, :theme)
  restyle!(e)
end

# The errors of the live blocks that failed. The app's self-test reads it, to check its own pages.
const problems = String[]

"""
Run the code of a live block and return a UI node that shows its value, or its
error. `key` is where the editor keeps what the code made. With `inline`, the
code is in a line of text: a value that isn't a node comes back as its text,
with true if the text says what went wrong.
"""
evaluate(e, code::String; key=(:live, e.buf.path, code), inline=false) = begin
  path = e.buf.path
  # The code can load the drawing methods of a node, and the frame that runs it
  # can't call them yet. So the window draws one more frame soon after.
  e.nodes[:ran] = true
  e.nodes[:running] = key
  try
    # Kip finds a path like "./widgets.jl" from the folder of the document, and so does a relative FSPath
    cd(isdir(docdir(e)) ? docdir(e) : pwd()) do
      value = include_string(sandbox(e), code, isempty(path) ? joinpath(e.folder, "untitled.md") : path)
      node = inline ? present_inline(value) : present(value)
      node !== nothing ? node : inline ? (said(value), false) : note(repr("text/plain", value), colours.ink)
    end
  catch err
    err = err isa LoadError ? err.error : err
    push!(problems, sprint(showerror, err))
    # A line of text has room for the first line of what went wrong
    inline ? (said(first(split(sprint(showerror, err), '\n'))), true) : note(sprint(showerror, err), colours.accent)
  finally
    delete!(e.nodes, :running)
  end
end

"""
The node that shows `value` in a live block, or nothing to show it as text. Add
a method to show a type of your own as a node.
"""
present(value) = nothing
present(node::Union{SemanticUI,GeometricUI}) = node
# Text on its own goes in a box as wide as the page, so that it wraps and takes the page's colours
present(text::Text) = Box(width(grow=grow), Alignment.Start, text)
present(p::FSPath) = begin
  path = abspath(string(p))
  path = ispath(path) ? realpath(path) : path
  Breadcrumb(at=length(path) > 1 ? String(rstrip(path, '/')) : path)
end

"""
The node that shows `value` in a line of text, for inline code, or nothing to
show it as text. It's what a live block shows, unless a type has a method here.
"""
present_inline(value) = present(value)
present_inline(text::Text) = Box(Alignment.Start, text)
# A file path in a line of text is as wide as its names. Its list floats under it.
present_inline(p::FSPath) = (l = present(p); l.inline = true; l)

note(text, colour) = Box(width(grow=grow), padding(BLOCK_X, 10px), background(colours.block),
  Text(String(text), size=13px, family=codefont(), subfamily=codestyle(), color=colour))

"""
What a live block shows: the node that its code made. The code can make a
layout with nodes in it, like `Column(Checkbox(), Checkbox())`. Making the
Column describes each Checkbox once, so each frame describes them again, and
a click on a checkbox shows.
"""
@def mutable struct Shown <: SemanticUI
  value::Any = nothing   # a SemanticUI or a GeometricUI
  was::Theme = light     # the theme that the text in a GeometricUI value has now
  inline::Bool = false   # made by inline code, so it's in a line of text and only as wide as what it shows
end

cursor(::Shown) = :arrow

# A drag that starts in a live block is the block's. The page's text doesn't select as the mouse moves.
onmouse(s::Shown, ::MouseMove) = held(s, Keys.mouse_left) ? handled : nothing

# The components in the block get the page's colours
describe(s::Shown) = begin
  e = editor(s)
  t = component_theme(e.zoom)
  was, s.was = s.was, t
  with_theme(t) do
    # A diagram, a model and a video have a button that makes them fill the window. One that fills it leaves its room here empty.
    what = s.inline ? nothing : fill_what(s.value)
    what !== nothing && what[1] == :node && zoomed_node(e, s.value) && return Column(width(grow=grow), Alignment.Start, held_room(e))
    inner = s.value isa SemanticUI ? Base.invokelatest(convert, GeometricUI, s.value) : redescribe!(detach!(s.value), t, was)
    what === nothing || (inner = fillable(s, what, inner, wide=fill_wide(s.value)))
    s.inline ? Row(width(grow=grow), Alignment.Center, inner) : Column(width(grow=grow), Alignment.Start, inner)
  end
end

# What inline code made can float a list over the page, as a file path does. A
# click in that list is the list's, so it stops here, before the page's text sees it.
onkey(s::Shown, ev::KeyPress{Keys.mouse_left}) = begin
  s.inline || return nothing
  r = rect(s)
  x, y = ev.window.mouse
  r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height ? nothing : handled
end

"""
Describe again each semantic node in `geo`, and put the new geometry where the
old geometry was. Text that has the colours of the theme `was` gets the colours of `t`.
"""
redescribe!(geo, t, was) = begin
  child = geo.firstchild
  while child !== nothing
    next = child.nextsibling
    if child isa GeometricUI && child.from isa SemanticUI
      new = Base.invokelatest(convert, GeometricUI, child.from)
      new === child || swap!(child, new)
    elseif child isa GeometricUI
      redescribe!(child, t, was)
    elseif child isa Text
      adopt_theme!(child, t, was)
    end
    child = next
  end
  geo
end

"Put `new` in the place of `old` among its siblings"
swap!(old, new) = begin
  parent, prev, next = old.parent, old.prevsibling, old.nextsibling
  detach!(new)
  setfield!(new, :parent, parent)
  setfield!(new, :prevsibling, prev)
  setfield!(new, :nextsibling, next)
  prev === nothing ? setfield!(parent, :firstchild, new) : setfield!(prev, :nextsibling, new)
  next === nothing || setfield!(next, :prevsibling, new)
  setfield!(old, :parent, nothing)
  setfield!(old, :prevsibling, nothing)
  setfield!(old, :nextsibling, nothing)
  new
end

# --- files in a live block ---------------------------------------------------------------
#
# An FSPath shows as a breadcrumb: the name of each folder on the way to it,
# in a row. Click the last name to list what's in that folder under the
# breadcrumb, and click an earlier name to go to that folder. A click on a
# line of the list makes that file or folder the path, so its name joins the
# breadcrumb. Under a path to a file is a preview of the file:
#
#   - a picture, of any kind that Skia or macOS reads
#   - the model in an STL or 3MF file
#   - a player for a sound or a video file
#   - the pages of a PDF file, one at a time
#   - a CSV file as a table, and the list of the files in a zip
#   - a Markdown file as it reads
#   - the text of any other text file, which the wheel scrolls through. The lines
#     of a file of code have the colours that a code block gives them.
#   - the picture that the Finder shows, for a file like a Word file or a font
#
# A sound or a video plays on while you scroll the page and type in it. It stops
# when the path goes to another file, when the preview closes and when the window
# shows another page.

"One line of the list under a Breadcrumb: a file or a folder"
@def mutable struct FileEntry <: SemanticUI
  path::String = ""
end

"One name in a Breadcrumb"
@def mutable struct Crumb <: SemanticUI
  path::String = ""
  name::String = ""
end

"The path `at`, as the names of the folders on the way to it"
@def mutable struct Breadcrumb <: SemanticUI
  at::String = ""
  open::Bool = false     # is the list of what's in the folder showing?
  # Kept so each name and each line knows when the mouse is over it
  crumbs::Dict{String,Crumb} = Dict{String,Crumb}()
  entries::Dict{String,FileEntry} = Dict{String,FileEntry}()
  # The STLViewer of the model at `at`, the player of the sound or the video there, or the Pages
  # of the PDF file there. It's kept so that the model stays as it was turned, the file plays on
  # from one frame to the next, and the page stays the one you turned to.
  viewer::Any = nothing
  text::Any = nothing    # what `kept!` keeps of the file at `at`, like its text, or false if it has none
  read::Any = nothing    # what `text` is: its kind, the path of its file and when the file last changed
  inline::Bool = false   # in a line of text, so its list floats under it and takes no room on the page
end

"The list or the preview under a breadcrumb that's in a line of text. It floats over the page."
@def mutable struct Listing <: SemanticUI
  of::Any = nothing   # the Breadcrumb
end

const LISTING_W = 340px

describe(f::Listing) =
  Column(width(grow=grow), Alignment.Start, padding(6px), radius(8px), background(colours.block), border(1px, :solid, colours.line),
         lifted, child_gap=1px, contents(f.of)...)

"Show the list of a breadcrumb that's in a line of text when it's open, and take the list away when it isn't"
list!(l::Breadcrumb, w) = begin
  w === nothing && return
  l.open || return close_popup!(w, :listing)
  e = editor(l)
  popup!(w, Listing(of=l), anchor=l, gap=4px, width=min(LISTING_W, e.width), key=:listing, onclose=() -> (l.open = false),
         theme=component_theme(e.zoom))
end

const MOST_FILES = 100

entry(l::Breadcrumb, path) = get!(() -> own!(l, FileEntry(path=path)), l.entries, path)

"The name and the path of each step on the way to `path`. The home folder is one step, named ~."
steps(path) = begin
  home = homedir()
  inside = path == home || startswith(path, home * "/")
  at = inside ? home : "/"
  out = [(inside ? "~" : "/", at)]
  for name in splitpath(relpath(path, at))
    name == "." && continue
    at = joinpath(at, name)
    push!(out, (name, at))
  end
  out
end

"The files and folders in `dir` that aren't hidden, folders first"
listing(dir) = begin
  names = try filter(n -> !startswith(n, "."), readdir(dir)) catch; String[] end
  sort!(names, by=n -> (!isdir(joinpath(dir, n)), lowercase(n)))
end

describe(l::Breadcrumb) = begin
  l.open || hush!(l)
  names = [get!(() -> own!(l, Crumb(path=path, name=name)), l.crumbs, path) for (name, path) in steps(l.at)]
  arrow() = Icon("chevron-right", size=9px, color=colours.faint)
  # The first name and as many of the last names as fit. An … stands for the names left out.
  # An open breadcrumb that isn't in a line of text is in a panel with what's under it, so it has less room
  panel = l.open && !l.inline
  n = fitting(map(wide, names), editor(l).width - (panel ? 2PANEL_PAD : 0px))
  kept = n < length(names) - 1 ? Any[names[1], Box(width(DOTS_W), label("…", color=colours.dim)), names[end-n+1:end]...] : names
  parts = Iterators.flatten(i == 1 ? (c,) : (arrow(), c) for (i, c) in enumerate(kept))
  l.inline && return Row(height(24px), child_gap=CRUMB_GAP, clip=true, parts...)
  trail = Row(width(grow=grow), height(30px), child_gap=CRUMB_GAP, clip=true, parts...)
  panel || return Column(width(grow=grow), Alignment.Start, trail)
  # One background goes round the names and what's under them, to show that they're one thing
  Column(width(grow=grow), Alignment.Start, padding(PANEL_PAD), radius(8px), background(colours.block), child_gap=1px,
    trail, contents(l)...)
end

const PANEL_PAD = 6px

"What shows under an open breadcrumb: the lines of a folder, or the preview of a file"
contents(l::Breadcrumb) = begin
  isdir(l.at) || return (preview(l, l.at),)
  hush!(l)
  l.viewer = l.text = nothing
  names = listing(l.at)
  shown = first(names, MOST_FILES)
  isempty(names) && return (Row(width(grow=grow), height(26px), padding(10px, 0px), label("This folder is empty", 12px, color=colours.dim)),)
  ((entry(l, joinpath(l.at, n)) for n in shown)...,
   (length(names) > length(shown) ? (Row(width(grow=grow), height(26px), padding(10px, 0px),
      label("and $(length(names) - length(shown)) more", 12px, color=colours.dim)),) : ())...)
end

const CRUMB_GAP = 2px
const ARROW_W = 9px
const DOTS_W = 18px
const LONGEST_NAME = 28   # characters. A longer name loses its middle.

"A name with its middle left out if it's long, like 8ebf6aee-d8a…e60dbee0e511"
short(name) = length(name) <= LONGEST_NAME ? name :
  first(name, LONGEST_NAME ÷ 2 - 1) * "…" * last(name, LONGEST_NAME ÷ 2)

"How wide a name of a breadcrumb is. The last name is bold and has an icon."
wide(c::Crumb) = begin
  last = c.path == (c.parent::Breadcrumb).at
  measure(Face(SANS, last ? "Semibold" : "", 13px, colours.ink, false), short(c.name)) + 12px + (last ? 19px : 0px)
end

"How many of the last names fit in `room` after the first name, when an … stands for the rest"
fitting(widths, room) = begin
  step = ARROW_W + 2CRUMB_GAP
  sum(widths) + step * (length(widths) - 1) <= room && return length(widths) - 1
  used = widths[1] + step + DOTS_W
  n = 0
  for w in Iterators.reverse(widths[2:end])
    used += step + w
    used > room && n > 0 && break
    n += 1
  end
  min(n, length(widths) - 2)
end

describe(c::Crumb) = begin
  l = c.parent::Breadcrumb
  last = c.path == l.at
  Row(height(24px), padding(6px, 0px), radius(5px), child_gap=6px,
      background(last && l.open ? colours.active : ishovered(c) ? colours.hover : clear),
    (last ? (Icon(isdir(c.path) ? "folder" : file_icon(c.path), size=13px, color=colours.dim),) : ())...,
    Box(label(short(c.name), color=last ? colours.ink : colours.dim, weight=last ? "Semibold" : "")))
end

cursor(::Crumb) = :hand

# The last name shows and hides the list. An earlier name goes to its folder.
onkey(c::Crumb, ev::KeyPress{Keys.mouse_left}) = begin
  l = c.parent::Breadcrumb
  # In a line of text, a click with ⌥ held shows the code and leaves the path as it is
  l.inline && held(c, Keys.opt) && return nothing
  c.path == l.at ? (l.open = !l.open) : (l.at = c.path; l.open = true)
  l.inline && list!(l, ev.window)
  nothing
end

describe(r::FileEntry) = begin
  folder = isdir(r.path)
  Row(width(grow=grow), height(26px), padding(10px, 0px), radius(5px), child_gap=8px, clip=true,
      background(ishovered(r) ? colours.hover : clear),
    Icon(folder ? "folder" : file_icon(r.path), size=13px, color=colours.dim),
    Box(width(grow=grow), Alignment.Start, label(basename(r.path))),
    (folder ? () : (Box(label(bytes(filesize(r.path)), 12px, color=colours.dim)),))...)
end

"A file's size in words, like 6.5 KB"
bytes(n) = begin
  n < 1000 && return "$n bytes"
  for unit in ("KB", "MB", "GB")
    n /= 1000
    (n < 1000 || unit == "GB") && return "$(n < 10 ? round(n, digits=1) : round(Int, n)) $unit"
  end
end

const PICTURES = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
const PREVIEW_LINES = 12
const MODELS = (".stl", ".3mf")   # the files of 3D models that the viewer reads
const MODEL_HEIGHT = 260px
# The sound and the video files that macOS plays
const SOUNDS = (".mp3", ".m4a", ".wav", ".aif", ".aiff", ".aac", ".flac", ".caf")
const VIDEOS = (".mp4", ".mov", ".m4v")

"The viewer of the model in the STL or 3MF file at `path`, or nothing if the file can't be read as a model"
model(l::Breadcrumb, path) = begin
  v = l.viewer
  (v isa STLViewer && v.path == path) || (hush!(l); v = l.viewer = own!(l, STLViewer(path=path, height=MODEL_HEIGHT)))
  load!(v) isa Mesh ? v : nothing
end

"The player of the sound or the video file at `path`. `Player` is AudioPlayer or VideoPlayer."
player(l::Breadcrumb, path, Player) = begin
  v = l.viewer
  (v isa Player && v.path == path) && return v
  hush!(l)
  l.viewer = own!(l, Player === VideoPlayer ? VideoPlayer(path=path, height=MODEL_HEIGHT) : AudioPlayer(path=path))
end

"Stop the sound or the video that the breadcrumb's player is playing"
hush!(l::Breadcrumb) = (l.viewer isa Union{AudioPlayer,VideoPlayer} && pause!(l.viewer); l)

const LINE_H = 18px          # the height of a line of a file's text
const TEXT_PAD = 8px         # above the first line and under the last
const MOST_TEXT = 400_000    # bytes. The preview of a longer file stops there.

"""
The text of the file that a breadcrumb previews. It's kept so that the file
is read once, and so that the text stays where you scrolled it to.
"""
mutable struct FileText
  lines::Vector{String}
  more::Bool        # the file is longer than what was read
  scroll::Scroll
end

FileText(lines, more) = FileText(lines, more, Scroll(width(grow=grow), height(LINE_H * min(length(lines), PREVIEW_LINES) + 2TEXT_PAD)))

"""
The lines of the file at `path` and whether it has more, or nothing if it isn't
text. With `tidy`, a tab is two spaces and a long line stops at 200 characters,
which is how the lines of a file of code are shown.
"""
reading(path; tidy=true) = begin
  bytes = open(io -> read(io, MOST_TEXT + 1), path)
  more = length(bytes) > MOST_TEXT
  more && resize!(bytes, MOST_TEXT)
  (isempty(bytes) || 0x00 in view(bytes, 1:min(length(bytes), 4000))) && return nothing
  s = String(bytes)
  # A file that was cut short can stop part way through a character
  for _ in 1:3
    (isvalid(s) || !more) && break
    s = String(codeunits(s)[1:end-1])
  end
  isvalid(s) || return nothing
  lines = [tidy ? String(first(replace(rstrip(line, '\r'), '\t' => "  "), 200)) : String(rstrip(line, '\r')) for line in split(s, '\n')]
  # The last line of a file that was cut short isn't all there, and a file that ends with a new line has no line after it
  (more || isempty(lines[end])) && length(lines) > 1 && pop!(lines)
  lines, more
end

"""
What the breadcrumb `l` keeps of the file at `path`: what `make(path)` gave, or
nothing if `make` found nothing to show. It's made again when the file changes.
`kind` names what's kept, so that two kinds of preview don't take each other's.
"""
kept!(make, l::Breadcrumb, path, kind) = begin
  key = (kind, path, mtime(path))
  l.read == key || (l.read = key; l.text = something(make(path), false))
  l.text === false ? nothing : l.text
end

"The text of the file at `path` for the breadcrumb `l`, or nothing if the file isn't text"
text!(l::Breadcrumb, path) = kept!(l, path, :text) do path
  found = reading(path)
  found === nothing ? nothing : FileText(found...)
end

"""
`n` rows that are each `high` tall, `PREVIEW_LINES` of them at a time. The
wheel scrolls through the rest. `row(i)` makes row `i`. Only the rows in view
are made, so a long file costs no more than a short one.
"""
scrolled(row, scroll::Scroll, n, high=LINE_H) = begin
  lo = clamp(floor(Int, (scroll.offset - TEXT_PAD) / high), 0, max(0, n - PREVIEW_LINES))
  hi = min(n, lo + PREVIEW_LINES + 2)
  Box(width(grow=grow), padding(10px, 0px), radius(5px), background(colours.bg), clip=true,
    reuse!(scroll, Column(width(grow=grow), Alignment.Start,
      spacer(TEXT_PAD + high * lo),
      [row(i) for i in lo+1:hi]...,
      spacer(TEXT_PAD + high * (n - hi)))))
end

"The text of a file. `lang` is the end of the file's name, like jl."
textview(t::FileText, lang) = scrolled(i -> codeline(t.lines[i], lang), t.scroll, length(t.lines))

"""
One line of a file's text. A file of code has the colours that a code block
has: `lang` is the end of the file's name, like jl, and a file that isn't code
is all one colour.
"""
codeline(line, lang) = Row(height(LINE_H),
  [part for t in tokens(line, lang)
        for part in spared(t.text, Face(codefont(), t.kind == :comment ? codeslant() : codestyle(), 12px,
                                        t.kind == :plain ? colours.ink : getfield(colours, t.kind), false))]...)

# --- the files in a zip -------------------------------------------------------------------

const ZIPS = (".zip", ".jar")
const MOST_ZIP = 300_000_000   # bytes. A bigger zip isn't read.

"The files in the zip at `path`, as lines of text: the name of each and how big it is once it's unpacked"
zipped(path) = begin
  filesize(path) > MOST_ZIP && return nothing
  found = try ThreeMF.entries(read(path)) catch; return nothing end
  names = sort!([name for name in keys(found) if !endswith(name, '/')])
  isempty(names) && return nothing
  wide = min(64, maximum(length, names))
  FileText([rpad(length(name) > 64 ? "…" * last(name, 63) : name, wide) * "   " * bytes(found[name].full) for name in names], false)
end

# --- a CSV file as a table --------------------------------------------------------------------

const TABLES = (".csv", ".tsv")
const ROW_H = 24px
const MOST_COLUMNS = 40

"The rows of a CSV file that a breadcrumb previews, and how wide each column is"
mutable struct FileTable
  rows::Vector{Vector{String}}
  widths::Vector{px}
  more::Bool
  scroll::Scroll
end

"""
The cells of one line of a CSV file. `mark` is the character between two
cells. A cell that has the mark in it is in quotes, and a quote in such a cell
is written twice.
"""
csv_cells(line, mark::Char) = begin
  out, cell, quoted = String[], IOBuffer(), false
  chars = collect(line)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if quoted && c == '"' && i < length(chars) && chars[i+1] == '"'
      write(cell, '"')
      i += 1
    elseif c == '"'
      quoted = !quoted
    elseif c == mark && !quoted
      push!(out, String(take!(cell)))
    else
      write(cell, c)
    end
    i += 1
  end
  push!(out, String(take!(cell)))
  out
end

"The rows of the CSV file at `path`. The mark between its cells is the one its first line has most of: a comma, a tab or a semicolon."
tabled(path) = begin
  found = reading(path, tidy=false)
  found === nothing && return nothing
  lines, more = found
  lines = filter(!isempty, lines)
  isempty(lines) && return nothing
  mark = argmax(c -> count(==(c), lines[1]), (',', '\t', ';'))
  rows = [first(csv_cells(line, mark), MOST_COLUMNS) for line in lines]
  columns = maximum(length, rows)
  face(r) = Face(SANS, r == 1 ? "Semibold" : "", 12px, colours.ink, false)
  # A column is as wide as the widest of its first hundred cells, and no wider than 240px
  widths = [clamp(maximum(r -> c <= length(rows[r]) ? measure(face(r), rows[r][c]) : 0px, 1:min(100, length(rows))), 24px, 240px) + 20px
            for c in 1:columns]
  FileTable(rows, widths, more, Scroll(width(grow=grow), height(ROW_H * min(length(rows), PREVIEW_LINES) + 2TEXT_PAD)))
end

"The rows of a CSV file as a table. Its first row is its headings."
tableview(t::FileTable) = scrolled(r -> tablerow(t, r), t.scroll, length(t.rows), ROW_H)

"Row `r` of a CSV file's table"
tablerow(t::FileTable, r) =
  Row(height(ROW_H), Alignment.Start, radius(3px), background(r == 1 ? colours.head : iseven(r) ? clear : colours.stripe),
    [Box(fixed(w), height(ROW_H), padding(10px, 0px), Alignment.Start, clip=true,
         label(c <= length(t.rows[r]) ? t.rows[r][c] : "", 12px, weight=r == 1 ? "Semibold" : ""))
     for (c, w) in enumerate(t.widths)]...)

# --- a Markdown file as it reads ---------------------------------------------------------------

const PAGE_ZOOM = 0.8        # the text of a page under a path is this much smaller than the text of the page itself
const PAGE_HEIGHT = 320px    # the most of the page that shows. The wheel scrolls through the rest.

"The lines of a Markdown file that a breadcrumb previews, laid out as the page lays out its own lines"
mutable struct FilePage
  flows::Vector{Flow}
  tops::Vector{px}   # how far each line is under the first
  tall::px
  more::Bool
  scroll::Scroll
end

"How wide what's under the breadcrumb `l` is"
room(l::Breadcrumb) = (e = editor(l); (l.inline ? min(LISTING_W, e.width) : e.width - 2PANEL_PAD) - 12px)

"The Markdown file at `path`, laid out for the breadcrumb `l`. It's laid out again when the page's text changes its size, font or colours."
filepage(l::Breadcrumb, path) = begin
  e = editor(l)
  wide = room(l) - 28px   # the page has 14px of room on each side
  kept!(l, path, (:page, wide, e.zoom, e.theme, e.font)) do path
    found = reading(path, tidy=false)
    found === nothing && return nothing
    lines, more = found
    kinds = classify(lines)
    zoom = e.zoom
    e.zoom = zoom * PAGE_ZOOM
    # -1 says that the line isn't one of the document's, so its inline code isn't run
    flows = try
      [laid(e, lines[i], kinds[i], false, -1, wide) for i in eachindex(lines)]
    finally
      e.zoom = zoom
    end
    tops = accumulate(+, map(tall, flows)) .- map(tall, flows)
    total = sum(tall, flows, init=0px)
    FilePage(flows, tops, total, more, Scroll(width(grow=grow), height(min(total + 2TEXT_PAD, PAGE_HEIGHT))))
  end
end

"A Markdown file as it reads. Only the lines in view are made."
pageview(e, p::FilePage) = begin
  from = p.scroll.offset - TEXT_PAD
  lo = something(findlast(<=(from), p.tops), 1)
  hi = something(findfirst(>(from + PAGE_HEIGHT), p.tops), length(p.tops) + 1) - 1
  under = p.tall - (p.tops[hi] + tall(p.flows[hi]))
  Box(width(grow=grow), padding(14px, 0px), radius(5px), background(colours.bg), clip=true,
    reuse!(p.scroll, Column(width(grow=grow), Alignment.Start,
      spacer(TEXT_PAD + p.tops[lo]),
      [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in p.flows[lo:hi]]...,
      spacer(TEXT_PAD + under))))
end

# --- the pages of a PDF file --------------------------------------------------------------------

const PAGE_W = 420px   # how wide a page of a PDF file shows

"The pages of a PDF file, one at a time. A click on the left half goes back a page, and one on the right half goes on."
@def mutable struct Pages <: SemanticUI
  path::String = ""
  page::Int = 1
  count::Int = 0
  wide::px = PAGE_W   # how wide a page shows
end

describe(p::Pages) = begin
  # Twice as many pixels as px, so that the page is sharp on a screen with 2 pixels to the px
  key = pdf_page(p.path, p.page, round(Int, 2num(p.wide)))
  key === nothing && return label("This page can't be shown", 12px, color=colours.dim)
  shape = image_aspect(key)
  arrow(name, on) = Icon(name, size=11px, color=on ? colours.dim : colours.faint)
  Column(Alignment.Start, child_gap=6px,
    fillable(p, (:pdf, p.path, p.page), Image(key, fixed(p.wide), height(p.wide / shape), radius(3px), border(1px, :solid, colours.line))),
    (p.count > 1 ? (Row(fixed(p.wide), height(22px), justify=Alignment.Center, child_gap=10px,
       arrow("chevron-left", p.page > 1), label("Page $(p.page) of $(p.count)", 12px, color=colours.dim),
       arrow("chevron-right", p.page < p.count)),) : ())...)
end

cursor(p::Pages) = p.count > 1 ? :hand : :arrow

"Go on by `by` pages, as far as the first page or the last"
turn!(p::Pages, by) = (p.page = clamp(p.page + by, 1, max(1, p.count)); handled)

onkey(p::Pages, ev::KeyPress{Keys.mouse_left}) = begin
  focus(p)
  r = rect(p)
  r === nothing ? handled : turn!(p, ev.window.mouse[1] < r.left + p.wide / 2 ? -1 : 1)
end
# The arrow keys turn the pages too, once a click has given them the keyboard
onkey(p::Pages, ::KeyPress{Keys.left}) = turn!(p, -1)
onkey(p::Pages, ::KeyPress{Keys.right}) = turn!(p, 1)

"The pages of the PDF file at `path`, or nothing if it isn't a PDF file that macOS can read"
pager(l::Breadcrumb, path) = begin
  v = l.viewer
  v isa Pages && v.path == path && return v
  hush!(l)
  n = pdf_pages(path)
  n == 0 ? nothing : (l.viewer = own!(l, Pages(path=path, count=n)))
end

# --- what shows for each kind of file --------------------------------------------------------------

# The pictures that macOS reads and Skia doesn't
const MAC_PICTURES = (".heic", ".heif", ".tif", ".tiff", ".svg", ".ico", ".icns", ".psd")
# The files whose first page the Finder can show
const DOCUMENTS = (".rtf", ".rtfd", ".doc", ".docx", ".pages", ".key", ".numbers", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".epub")
const FONTS = (".ttf", ".otf", ".ttc", ".woff", ".woff2")
const CODE = (".jl", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".py", ".rb", ".rs", ".go", ".c", ".h", ".cc", ".cpp", ".hpp", ".swift",
              ".kt", ".java", ".sh", ".zsh", ".css", ".html", ".json", ".toml", ".yml", ".yaml", ".xml", ".sql", ".lua")

"The icon for the file at `path`. It says what kind of file it is, from the end of the file's name."
file_icon(path) = begin
  ext = lowercase(splitext(path)[2])
  ext in MARKDOWN || ext == ".txt" ? "file-earmark-text" :
  ext in PICTURES || ext in MAC_PICTURES ? "file-earmark-image" :
  ext in SOUNDS ? "file-earmark-music" :
  ext in VIDEOS ? "file-earmark-play" :
  ext in MODELS ? "box" :
  ext == ".pdf" ? "file-earmark-pdf" :
  ext in ZIPS ? "file-earmark-zip" :
  ext in TABLES ? "file-earmark-spreadsheet" :
  ext in FONTS ? "file-earmark-font" :
  ext in DOCUMENTS ? "file-earmark-richtext" :
  ext in CODE ? "file-earmark-code" : "file-earmark"
end

"Every icon that `file_icon` can give, and those of a file that's only shown: of a binary file, and of the button that opens the file in its own app. The built app reads them all when it's made."
const FILE_ICONS = ("file-earmark", "file-earmark-text", "file-earmark-image", "file-earmark-music", "file-earmark-play", "box",
                    "file-earmark-pdf", "file-earmark-zip", "file-earmark-spreadsheet", "file-earmark-font", "file-earmark-richtext",
                    "file-earmark-code", "file-earmark-binary", "box-arrow-up-right", "chevron-left", "chevron-right")

"The picture kept under `key`, no taller than `most` and no wider than 420px. A picture of a page has a line round it."
framed(key, most=260px; page=false) = begin
  shape = image_aspect(key)
  w = min(420px, most * shape)
  page ? Image(key, fixed(w), height(w / shape), radius(3px), border(1px, :solid, colours.line)) :
         Image(key, fixed(w), height(w / shape), radius(4px))
end

"""
What shows for the file at `path`, or nothing if the file has no preview. `ext`
is the end of the file's name. `note(words)` adds words to the line under the
preview.
"""
peek(l::Breadcrumb, path, ext, note) = begin
  mac = Sys.isapple()
  # A picture, a model and a video have a button that makes them fill the window
  pic(key, more...; kw...) = fillable(l, (:picture, key), framed(key, more...; kw...))
  if ext in PICTURES
    return pic(path)
  elseif ext in MAC_PICTURES
    key = picture(path)
    key === nothing || return pic(key)
  elseif ext in MODELS
    viewer = model(l, path)
    viewer === nothing || return fillable(l, (:node, viewer), viewer, wide=:grow)
  elseif mac && ext in SOUNDS
    return player(l, path, AudioPlayer)
  elseif mac && ext in VIDEOS
    p = player(l, path, VideoPlayer)
    return fillable(l, (:node, p), p, wide=video_wide(p))
  elseif mac && ext == ".pdf"
    found = pager(l, path)
    found === nothing || return found
  elseif ext in ZIPS
    list = kept!(zipped, l, path, :zip)
    list === nothing && return nothing
    note("$(length(list.lines)) file$(length(list.lines) == 1 ? "" : "s")")
    return textview(list, "")
  elseif ext in TABLES
    table = kept!(tabled, l, path, :table)
    table === nothing && return nothing
    note(table.more ? "the first $(length(table.rows) - 1) rows" : "$(length(table.rows) - 1) row$(length(table.rows) == 2 ? "" : "s")")
    return tableview(table)
  elseif ismarkdown(path)
    page = filepage(l, path)
    page === nothing && return nothing
    page.more && note("the first $(bytes(MOST_TEXT)) of $(bytes(filesize(path)))")
    return pageview(editor(l), page)
  elseif ext in DOCUMENTS || ext in FONTS
    key = thumbnail(path)
    return key === nothing ? nothing : pic(key, 400px, page=ext in DOCUMENTS)
  end
  text = text!(l, path)
  if text !== nothing
    text.more && note("the first $(bytes(MOST_TEXT)) of $(bytes(filesize(path)))")
    return textview(text, lstrip(ext, '.'))
  end
  # The Finder has a picture for many kinds of file that have none here
  key = thumbnail(path)
  key === nothing ? nothing : pic(key)
end

"What shows under the path of a file: its picture, its model, its player, its pages or its text, and when it last changed"
preview(l::Breadcrumb, path) = begin
  isfile(path) || return Box(height(0px))
  ext = lowercase(splitext(path)[2])
  # A player that was made for another file stops when the path leaves that file
  l.viewer !== nothing && l.viewer.path != path && (hush!(l); l.viewer = nothing)
  about = "Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(path))
  content = try
    peek(l, path, ext, words -> (about *= "  ·  " * words))
  catch
    nothing
  end
  content === nothing && (content = label("This file has no preview", 12px, color=colours.dim))
  Column(width(grow=grow), Alignment.Start, padding(6px), child_gap=8px,
    content, label(about, 12px, color=colours.dim))
end

cursor(::FileEntry) = :hand

onkey(r::FileEntry, ::KeyPress{Keys.mouse_left}) = begin
  (r.parent::Breadcrumb).at = r.path
end

# --- a file that isn't Markdown, in the page -------------------------------------------------
#
# A click on a file in the sidebar shows the file in the page, whatever kind of
# file it is. Kaydown changes Markdown files and Julia files, so any other file
# is only shown, and the top bar says "Read only". The button beside those
# words opens the file in the app that the Mac uses for it.
#
# A Julia file is one block of code, with no lines that open and close it. You
# type in it as in a `julia` code block of a page: ⌘Return runs the expression
# that the caret is in, a list offers names, and ⌘S writes the file.
#
#   - A file of text shows its text. A file of code has the colours that a code
#     block has. You can select the text, copy it and find words in it.
#   - A picture, a model, a sound, a video, a PDF file, a CSV file, a Word file
#     and a font show as they do under a file path, as big as the page has room for.
#   - A zip shows the list of the files in it.
#   - Any other file is a binary file. The page says so, and a button there
#     shows the file's bytes in hexadecimal.

const MOST_LINE = 2000     # characters. A longer line of a file's text stops there.
const HEX = "hex"          # the language of the lines that show a file's bytes
const HEX_BYTES = 10       # the column of such a line where the bytes start, after their place in the file
const HEX_CHARS = 60       # the column where the same bytes start as characters
const MOST_HEX = 160_000   # bytes. The lines of a longer file stop there.

"True when a file whose name ends with `ext` has a viewer of its own, so it doesn't show as text"
viewed(ext) = ext in PICTURES || ext in MAC_PICTURES || ext in MODELS || ext in SOUNDS || ext in VIDEOS || ext == ".pdf" ||
              ext in TABLES || ext in DOCUMENTS || ext in FONTS

"A line of a file's text as the page shows it: a tab is two spaces, and a very long line stops with an …"
shown_line(line) = begin
  s = replace(line, '\t' => "  ")
  length(s) > MOST_LINE ? first(s, MOST_LINE) * "…" : String(s)
end

"The buffer that shows the file at `path`, which isn't Markdown"
look(path) = begin
  ext = lowercase(splitext(path)[2])
  if ext in ZIPS
    list = try zipped(path) catch; nothing end
    n = list === nothing ? 0 : length(list.lines)
    list === nothing || return Buffer(path=path, view=:text, lines=list.lines, about="$(commas(n)) file$(n == 1 ? "" : "s")")
  elseif !viewed(ext)
    found = try reading(path, tidy=false) catch; nothing end
    if found !== nothing
      lines, more = found
      return Buffer(path=path, view=:text, lines=map(shown_line, lines),
                    about=more ? "First $(bytes(MOST_TEXT)) of $(bytes(filesize(path)))" : "")
    end
  end
  Buffer(path=path, view=:file)
end

"""
The bytes of the file at `path` as lines of text. Each line has the place of
its first byte in the file, then 16 bytes in hexadecimal, then the same bytes
as characters. A byte that isn't a character of plain text shows as a dot.
"""
hexlines(path) = begin
  data = open(io -> read(io, MOST_HEX), path)
  hex(row) = join((string(x, base=16, pad=2) for x in row), ' ')
  map(0:16:max(0, length(data) - 1)) do at
    row = data[at+1:min(at + 16, end)]
    rpad(string(at, base=16, pad=8), HEX_BYTES) * rpad(hex(row[1:min(8, end)]) * "  " * hex(row[9:end]), HEX_CHARS - HEX_BYTES) *
      String([0x20 <= x < 0x7f ? Char(x) : '.' for x in row])
  end
end

"What the top bar says of the bytes of the file at `path`: how many of them show, when not all do"
hex_about(path) = filesize(path) > MOST_HEX ? "First $(bytes(MOST_HEX)) of $(bytes(filesize(path)))" : ""

"Show the bytes of the file that the page shows, in hexadecimal"
hex!(e) = begin
  b = e.buf
  (readonly(b) && isfile(b.path)) || return e
  b.lines, b.about, b.view = hexlines(b.path), hex_about(b.path), :hex
  b.caret = b.anchor = (1, 0)
  b.saved = b.version += 1
  e.scroll.offset = 0px
  focus(e)
  e
end

# A whole file of code or of text starts at the left of the page, not in the
# middle of it as a page's text is, and has the number of each line beside it.
# The number of the line that the caret is in is a little darker. The list of
# the files in a zip has no numbers.

const NUMBER_GAP = 14px   # between the numbers of the lines and the text

"True when the page shows a whole file of code or of text, which can have the number of each line beside it"
numbered(b::Buffer) = b.view == :code || (b.view == :text && !(lowercase(splitext(b.path)[2]) in ZIPS))

"The font of the numbers of the lines: a little smaller and fainter than the code"
number_face(e) = (code = face(e, Line(Kind.code, 0, 0, "")); Face(code, size=code.size * 0.9, color=colours.faint))

"True when the page shows the number of each line beside it: a file of code or of text, unless the settings page hid them"
numbers(e) = numbered(e.buf) && e.numbers

"How much room the numbers of the page's lines take beside the text, with the gap between them. A page with no numbers takes none."
gutter(e) = numbers(e) ? measure(number_face(e), "0") * max(2, ndigits(length(e.buf.lines))) + NUMBER_GAP : 0px

const capitals = Dict{Tuple{String,String,Float32},px}()

"How tall a capital letter of `face` is"
capital(face::Face) = get!(capitals, (face.family, face.style, Float32(num(face.size)))) do
  metrics = Ref{Skia.sk_font_metrics_t}()
  Skia.sk_font_get_metrics(skia_font(face.family, face.size, face.style).raw, metrics)
  px(metrics[].capHeight)
end

"Write the number of each line on screen beside the line. The page's text starts at `left`, and its first line is at `top`."
draw_numbers(ctx, e, left, top) = begin
  b = e.buf
  numbers(e) || return
  f = number_face(e)
  # A number stands on the line that its line of code stands on
  rise = capital(face(e, Line(Kind.code, 0, 0, "")))
  for it in e.layout[e.shown]
    flow = it.content
    flow isa Flow || continue
    words = string(it.first)
    here = !b.reading && !readonly(b) && it.first == b.caret[1]
    x = left - NUMBER_GAP - measure(f, words)
    y = top + it.top + line_top(flow, 1) + (flow.lines[1].high + rise) / 2
    write_ink(ctx, words, num(x), num(y), here ? Face(f, color=colours.dim) : f)
  end
end

# A line of a file of code or of text that's too long for the window goes on
# under itself, at the window's right edge. The part under it starts one step of
# indentation further in than the line does, so it doesn't look like a line of
# its own. The settings page can turn that off. Then a long line goes on past
# the edge of the window, and the page scrolls sideways to show the rest of it,
# under the numbers of the lines. The caret stays in sight as it moves.
#
# The settings page has more for code. A file of code can show the numbers of
# its lines or not, shade the line that the caret is on, and have a faint line
# down it after a number of characters, to show where a line gets too long. In
# all code, in a file or in a page, it sets how big the code is and how many
# spaces one step of indentation is.

const INDENTS = (2, 4)                  # the steps of indentation that the settings page offers
const GUIDES = (0, 80, 92, 100, 120)    # the places for the line down a file of code. 0 is no line.
const CODE_SCALES = (0.4, 2.5)          # the least and most that code can be, beside the page's text
const SIDE_ROOM = 40px   # how near the caret gets to the left or right of the window before the page scrolls sideways

"True when the long lines of the page go on under themselves. Only a file of code or of text can have them go on past the window."
wraps(e) = e.wrap || !numbered(e.buf)

"How far the page is scrolled to the right"
sideways(e) = wraps(e) ? 0px : e.buf.across

"How far the page can scroll to the right: as far as the longest line goes past the right of the window"
sideways_room(e) = max(0px, e.reach + SIDE_ROOM - e.width)

"Scroll the page `by` to the right, as far as it goes"
scroll_sideways!(e, by) = (e.buf.across = clamp(e.buf.across + by, 0px, sideways_room(e)); e)

"""
Two fingers that move sideways on the trackpad, or the wheel with ⇧ held,
scroll the page sideways. Their move up or down still scrolls the page up or down.
"""
swipe!(e, ev::MouseScroll) = begin
  (wraps(e) || ev.delta[1] == 0px) && return nothing
  scroll_sideways!(e, -30ev.delta[1])
  ev.delta[2] == 0px ? handled : nothing
end
onscroll(d::Document, ev::MouseScroll) = swipe!(editor(d), ev)
onscroll(p::Page, ev::MouseScroll) = swipe!(editor(p), ev)

"How far the lines of `f` go, from the left of the text"
extent(f::Flow) = maximum(vl -> isempty(vl.segs) ? vl.x : last(vl.segs).x + last(vl.segs).w, f.lines)

"Turn on or off the wrapping of a line of a file of code that's too long for the window"
wrap!(e, on::Bool) = (e.wrap = on; save_settings!(e); rerun!(e, :wrap); restyle!(e))

"Show or hide the numbers of the lines of a file of code"
numbers!(e, on::Bool) = (e.numbers = on; save_settings!(e); rerun!(e, :numbers); restyle!(e))

"Shade the line of a file of code that the caret is on, or don't"
shade!(e, on::Bool) = (e.shade = on; save_settings!(e); rerun!(e, :shade); e)

"Make one step of indentation in code `n` spaces: 2 or 4"
indent_width!(e, n::Int) = begin
  n in INDENTS || error("A step of indentation is 2 or 4 spaces. $n isn't one of them.")
  e.indent = n
  save_settings!(e)
  rerun!(e, :indent)
  restyle!(e)
end

"Put the faint line down a file of code after `n` characters. 0 takes the line away."
guide!(e, n::Int) = begin
  n in GUIDES || error("The line goes after 80, 92, 100 or 120 characters, or 0 for none. $n isn't one of them.")
  e.guide = n
  save_settings!(e)
  rerun!(e, :guide)
  e
end

"Draw code in the font called `family`, in its light weight if it has one"
code_font!(e, family::String) = begin
  installed_weight(family, 400) > 0 || error("This Mac has no font called $family.")
  e.code_font = family
  use_code_font!(e)
  save_settings!(e)
  rerun!(e, :code_font)
  restyle!(e)
end

"How big code is: a part of the size of the page's text, so it grows and shrinks with it"
code_size(e) = body(e).size * e.code_scale

"Make code `size` pixels tall, for a live block. The text of the page stays the size it is."
code_size!(e, size) = (e.code_scale = clamp(size / num(body(e).size), CODE_SCALES...); rewrap!(e))

"The spaces of one step of indentation, in a block of the kind `block`. In code the settings page chooses how many."
indentation(e, block) = block === CodeBlock ? " "^e.indent : STEP

"Lay out `text`, line `i` of a file that shows as text. It has no background of its own and starts at the edge of the page."
file_line(e, text, line::Line, i::Int) = begin
  ps = spare(pieces(e, text, line, false, i))
  # Lines of bigger code are further apart
  lh, size = code_size(e) * 1.5 / CODE_SCALE, face(e, line).size
  wraps(e) || return wrap(ps, px(Inf); lh, size)
  # The spaces at the start of the line, and one step more, though half the page is always left for the text
  indent = match(r"^[ \t]*", text).match
  hang = min(measure(face(e, line), indent * " "^e.indent), e.width / 2)
  wrap(ps, e.width; lh, size, hang)
end

"""
The lines of a file that shows as text, laid out. Each is a line of code. The
whole page is code, so the lines have no background of their own and start at
the edge of the page.
"""
text_items(e, b::Buffer) = begin
  ks = kinds(b)
  items = Vector{Item}(undef, length(b.lines))
  top = 0px
  for (i, text) in enumerate(b.lines)
    f = file_line(e, text, ks[i], i)
    items[i] = Item(i, i, top, tall(f), f)
    top += tall(f)
  end
  items
end

"What the page shows for a file that doesn't show as text: a viewer of its kind, or words that say it's a binary file"
@def mutable struct FileView <: SemanticUI
  path::String = ""
  viewer::Any = nothing   # the STLViewer, the player or the Pages of the file, kept from one frame to the next
  table::Any = nothing    # the rows of a CSV file, with when the file had last changed when they were read
  button::Any = nothing   # the HexButton of a binary file
end

"The button under the words that say a file is binary. A click shows the file's bytes."
@def mutable struct HexButton <: SemanticUI end

describe(b::HexButton) = Box(height(30px), padding(14px, 0px), radius(6px), background(ishovered(b) ? colours.active : colours.hover),
                             label("View as hexadecimal", 13px))
cursor(::HexButton) = :hand
onkey(b::HexButton, ::KeyPress{Keys.mouse_left}) = (hex!(editor(b)); handled)

cursor(::FileView) = :arrow

"The one item of the page of a file that shows in a viewer"
file_item(e, b::Buffer) = begin
  v = node!(() -> FileView(path=b.path), e, (:fileview, b.path))
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  high = concrete.height + 2LIVE_GAP
  Item(1, 1, 0px, high, Live(v, high))
end

"The picture kept under `key`, `wide` across, and no wider than the page's text"
fitted(e, key, wide; line=false) = begin
  source = image_source(key)
  w = min(e.width, px(wide))
  h = w * source.height / source.width
  line ? Image(key, fixed(w), height(h), radius(3px), border(1px, :solid, colours.line)) : Image(key, fixed(w), height(h), radius(4px))
end

"""
What shows the file of `v`, or nothing if Kaydown has nothing that shows it.
`note(words)` adds words to the line that says how big the file is.
"""
viewer(v::FileView, e, note) = begin
  path = v.path
  ext = lowercase(splitext(path)[2])
  mac = Sys.isapple()
  _, h = window_size(e)
  room = clamp(h - TOPBAR_H - PAGE_TOP - 150px, 240px, 800px)   # how tall a model or a video shows
  # What's made for the file is kept, so the model stays as it was turned and the file plays on
  made(make, T) = v.viewer isa T ? v.viewer : (v.viewer = own!(v, make()))
  if ext in PICTURES || ext in MAC_PICTURES
    key = picture_key(path)
    key === nothing && return nothing
    source = image_source(key)
    # A picture of pixels is a pixel to the px. One that macOS read, like an SVG, is the size that macOS says it is.
    size = something(natural(key), (source.width, source.height))
    note("$(round(Int, size[1])) × $(round(Int, size[2]))")
    return fillable(v, (:picture, key), fitted(e, key, size[1]))
  elseif ext in MODELS
    m = made(() -> STLViewer(path=path), STLViewer)
    zoomed_node(e, m) || (m.height = room)   # one that fills the window is as tall as the window
    return load!(m) isa Mesh ? fillable(v, (:node, m), m, wide=:grow) : nothing
  elseif mac && ext in SOUNDS
    return made(() -> AudioPlayer(path=path), AudioPlayer)
  elseif mac && ext in VIDEOS
    p = made(() -> VideoPlayer(path=path), VideoPlayer)
    zoomed_node(e, p) || (p.height = room)
    return fillable(v, (:node, p), p, wide=video_wide(p))
  elseif mac && ext == ".pdf"
    p = made(() -> Pages(path=path, count=pdf_pages(path)), Pages)
    p.count == 0 && return nothing
    p.wide = e.width
    return p
  elseif ext in TABLES
    at = mtime(path)
    (v.table === nothing || v.table[1] != at) && (v.table = (at, tabled(path)))
    t = v.table[2]
    t === nothing && return nothing
    n = length(t.rows)
    note(t.more ? "the first $(commas(n - 1)) rows" : "$(commas(n - 1)) row$(n == 2 ? "" : "s")")
    # Only the rows that are in the window are made, so a long table costs no more than a short one
    lo = clamp(floor(Int, (e.scroll.offset - PAGE_TOP) / ROW_H) - 4, 0, n)
    hi = min(n, lo + ceil(Int, h / ROW_H) + 8)
    return Column(width(grow=grow), Alignment.Start, clip=true,
      spacer(ROW_H * lo), [tablerow(t, r) for r in lo+1:hi]..., spacer(ROW_H * (n - hi)))
  end
  # The picture that the Finder shows: the first page of a Word file, the letters of a font,
  # and what it has for many kinds of file that have no viewer here
  key = thumbnail(path)
  key === nothing && return nothing
  fillable(v, (:picture, key), fitted(e, key, image_source(key).width / 2, line=ext in DOCUMENTS))   # the picture has two pixels to the px
end

describe(v::FileView) = begin
  e = editor(v)
  # A Text on its own would take the whole width and start at the left, so each is in a box that the column centres
  words(parts) = Column(width(grow=grow), padding(90px, 0px, 30px, 0px), child_gap=10px, [p isa Text ? Box(p) : p for p in parts]...)
  isfile(v.path) || return words((label("$(basename(v.path)) isn't there any more", 15px),))
  about = bytes(filesize(v.path)) * "  ·  Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(v.path))
  filesize(v.path) == 0 && return words((label("$(basename(v.path)) is empty", 15px), label(about, 12px, color=colours.dim)))
  # A model and a player are components, so they get the colours and the text size that a live block gives them
  with_theme(component_theme(e.zoom)) do
    content = try
      viewer(v, e, more -> (about *= "  ·  " * more))
    catch
      nothing
    end
    line = label(about, 12px, color=colours.dim)
    if content === nothing
      # Nothing shows this file, so the page says what it is, and its bytes are a click away
      v.button === nothing && (v.button = own!(v, HexButton()))
      return words((Icon("file-earmark-binary", size=34px, color=colours.faint), label("$(basename(v.path)) is a binary file", 15px),
                    line, Box(height(4px)), v.button))
    end
    # A table can be long, so the line about it is over it. Anything else has the line under it.
    lowercase(splitext(v.path)[2]) in TABLES ? Column(width(grow=grow), Alignment.Start, child_gap=10px, line, content) :
                                               Column(width(grow=grow), child_gap=10px, content, Box(line))
  end
end

"What the live block with this code shows"
live(e, code::String) = begin
  key = (:live, e.buf.path, code)
  node = get!(e.nodes, key) do
    shown = Shown(value=evaluate(e, code))
    shown.value isa SemanticUI && own!(shown, shown.value)
    old = pop!(e.nodes, (:replaced, key), nothing)
    old isa Shown && carry!(shown.value, old.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

# --- diagrams -----------------------------------------------------------------------
#
# A code block in the language `mermaid` shows the diagram that its code
# describes: a flowchart, a sequence diagram, a state diagram, a class diagram
# or a pie chart. UI.jl's Mermaid component reads the code and draws it. Put
# the caret in the block, or click it with ⌥ held, to see its code.

const DIAGRAM = "mermaid"

"True when `code` is the code of a diagram that can be drawn"
isdiagram(code::AbstractString) = problem(code) === nothing

"What the `mermaid` block with this code shows: its diagram, or nothing if the code can't be drawn as one"
diagram(e, code::String) = begin
  isdiagram(code) || return nothing
  # A Shown gives the diagram the page's colours and font, as it does for what a live block makes
  node = get!(e.nodes, (:diagram, code)) do
    shown = Shown(value=Mermaid(code))
    own!(shown, shown.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

# --- takeoffs ---------------------------------------------------------------------------
#
# A code block in the language `takeoff` shows a plan that you measure from: a
# page of a PDF file, or a picture. takeoff.jl says how the block is written.
# Put the caret in the block, or click it with ⌥ held, to see its lines.
#
#   - Drop a PDF file or a picture on the block, or click it, to choose the plan.
#   - Set the scale: type it, like 1:100, or choose the ruler, click the two ends
#     of a length that you know and type how long it is.
#   - Add a measure starts one. Choose its item from Centient's catalogue, then
#     click on the plan. The item's unit says what the measure is and chooses the
#     tool: a length for an item sold by the metre, an area for one sold by the
#     square metre, and a count for the rest. A measure with nothing drawn yet
#     and no item is what the tool you choose makes it. A click on a measure in
#     the list chooses its tool too.
#   - The table has no column for a measure's name. Its item says what it is:
#     the item's name, then the catalogue that it's from. A measure with no item
#     shows the name that it has in the block. On a Mac with no Centient, a click
#     on that name changes it.
#   - What a search of Centient finds shows in a list that floats beside the
#     text field. The search for an item looks in one catalogue at a time: the
#     business's own items, or a supplier's that ⌥ lets you choose. The headings of the table of measures sort and search it.
#   - A click on the unit after a measure's amount lists the units that it can
#     be in, as Centient's unit picker does. Type to search them. The amount
#     shows in the unit that you choose, and the quote's line is in it too. A
#     measure with nothing drawn and no item can take a unit of another kind,
#     and that changes what it measures.
#   - A count takes a mark for each click. A length and an area take a corner for
#     each click. To end one, click the Done button beside its last corner,
#     click twice, or press Return. An area also ends with a click on its
#     first corner.
#   - With the arrow, click a mark or a line to select it, drag a corner to move
#     it, and press Delete to take it away. Drag the plan to move it.
#   - ⌘ and the scroll wheel make the plan bigger and smaller. Once you've
#     clicked the plan, two fingers move it. A plan that shows whole stays put.
#   - The button with four arrows makes the block fill the window, with the list
#     of measures beside the plan or under it. Esc puts it back in the page.
#   - V, C, L, A and S choose the tools. Esc drops what's half drawn. ⌘Z takes
#     the last change back.
#   - Choose the customer, then Make quote in Centient. Centient makes a quote
#     with a line for each measure, priced from its catalogue.
#
# Every change is written into the block's lines, so the file holds the whole
# takeoff. The catalogue, the contacts and the quote come from Centient through
# its MCP server, which centient.jl starts. Centient's app needn't be open.

const TAKEOFF = Plans.TAKEOFF
const PLAN_LEAST = 220px      # how tall the plan's view is at the least
const REACH = 7.0             # px. A corner or a line that's this near the mouse is under it.
const NEAR = 24.0             # the most px to a point of the page: as big as the plan gets
const SETTLED = 0.15          # seconds after the plan last moved until a plan that's slow to draw is drawn sharp
const QUICK = 0.012           # seconds. A plan that's drawn in less is drawn sharp while it moves.
const MOST_FOUND = 8          # the lines of the list under a search
const SIDE_W = 380px          # how wide the list of measures is beside a plan that fills the window
const HUES = (colorant"rgb(222,72,58)", colorant"rgb(38,120,214)", colorant"rgb(30,150,90)", colorant"rgb(232,140,24)",
              colorant"rgb(140,84,208)", colorant"rgb(18,160,170)", colorant"rgb(214,70,150)", colorant"rgb(128,104,72)")
"The tools of a takeoff, in the order of their buttons: the icon of each, what it says of itself, and the letter that chooses it"
const PLAN_TOOLS = (:select => ("cursor", "Select and move  V", 'v'), :count => ("plus-circle", "Count  C", 'c'),
                    :length => ("vector-pen", "Measure a length  L", 'l'), :area => ("pentagon", "Measure an area  A", 'a'),
                    :scale => ("rulers", "Set the scale from a length that you know  S", 's'))
"Every icon that a takeoff can show. The built app reads them all when it's made."
const PLAN_ICONS = ["cursor", "plus-circle", "vector-pen", "pentagon", "rulers", "chevron-left", "chevron-right", "zoom-out", "zoom-in",
                    "aspect-ratio", "file-earmark-pdf", "x-lg", "plus-lg", "map", "person", "receipt", "arrows-fullscreen", "fullscreen-exit",
                    "chevron-up", "chevron-down", "check"]

"True when the page's theme is a dark one"
dark_page() = RGBA(colours.bg).r < 0.5
"""
What's behind the plan's paper, round the table of measures and at the foot of
a takeoff: the theme's colour for things that float over the page, which is a
little lighter than the page. In a dark page it's the page's own colour.
"""
takeoff_back() = dark_page() ? colours.bg : colours.float

"The colour of the measure at place `i` in the list"
hue(i) = HUES[mod1(i, length(HUES))]

"The part of a page of a PDF plan that a takeoff shows, as a picture that Skia draws. It's kept until the view moves."
mutable struct Sharp
  of::Any                         # what it's a picture of
  image::Ptr{Skia.sk_image_t}
  cost::Float64                   # seconds that the last one took to draw
end

"What a `takeoff` block shows: the plan, the tools and the list of measures"
@def mutable struct TakeoffView <: SemanticUI
  n::Int = 0                              # its place among the page's takeoffs
  first::Int = 0                          # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Plans.Takeoff = Plans.Takeoff()
  lines::Vector{String} = String[]        # the lines that `data` was read from
  tool::Symbol = :select
  current::Int = 0                        # the measure that the tools draw for: its place in the list, or 0
  picked::Any = nothing                   # what's selected on the plan: the place of its measure and its shape, and of its point if it's one corner
  draft::Vector{Plans.Point} = Plans.Point[]   # the corners so far of what's being drawn
  zoom::Float64 = 0.0                     # px to a point of the page. 0 fits the page in the view.
  at::Plans.Point = (0.0, 0.0)            # the point of the page at the view's top left
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the view was last drawn in the window: its left, top, width and height
  fitted::Any = nothing                   # the file and the page that the zoom is for
  mouse::Any = nothing                    # the point of the page under the mouse
  grab::Any = nothing                     # a drag: of the plan, or of a corner
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where the plan was last clicked
  moved::Float64 = 0.0                    # when the view last moved
  asking::Any = nothing                   # what the text field is for: (:name, i), (:item, i), (:extra, i), (:scale,), (:length, a, b) or (:customer,)
  query::String = ""                      # the words that were last searched for
  typed::Float64 = 0.0                    # when the words in the text field last changed
  search::Any = nothing                   # the search that Centient hasn't answered yet
  rows::Vector{Any} = Any[]               # what the last search found
  pick::Int = 1                           # the row of them that Return takes
  known::Dict{String,Any} = Dict{String,Any}()   # what Centient says of each item: its name, its unit, its price
  lookup::Any = nothing                   # the request for those that Centient hasn't answered yet
  quoting::Any = nothing                  # the request for a quote that Centient hasn't answered yet
  said::String = ""                       # what the foot of the block says
  wrong::Bool = false                     # it says what went wrong
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its buttons, rows and text field, kept between frames
  sharp::Sharp = Sharp(nothing, C_NULL, 1.0)
  full::Bool = false                      # it fills the window, over the page
  beside::Bool = false                    # it fills the window with its list of measures beside the plan, not under it
  tall::px = 0px                          # how tall it was in the page when it was last laid out there
  pinned::px = 0px                        # how far the page was scrolled when it filled the window
  sort::Any = nothing                     # the column that the table of measures is sorted by, and which way: (:cost, :desc)
  filters::Dict{Symbol,String} = Dict{Symbol,String}()   # the words that a column's text must have for the table to show a measure
  order::Vector{Int} = Int[]              # the measures that the table shows, in the order that it shows them
end

"The part of a takeoff that shows the plan"
@def mutable struct PlanArea <: SemanticUI
  of::Any = nothing
end
"A button of a takeoff: a tool, a page arrow, the button that makes the quote"
@def mutable struct PlanButton <: SemanticUI
  of::Any = nothing
  action::Any = :none
  icon::String = ""
  words::String = ""
  tip::String = ""
  off::Bool = false                           # it does nothing now, and shows that
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end
"A measure in a takeoff's list"
@def mutable struct MeasureRow <: SemanticUI
  of::Any = nothing
  i::Int = 0
end
"The amount of a measure in its row: the number, then the unit that it's in"
@def mutable struct AmountCell <: SemanticUI
  of::Any = nothing
  i::Int = 0
  unit::Any = nothing   # its UnitWord
end
"The unit after a measure's amount. A click on it shows the list of units that the measure can be in."
@def mutable struct UnitWord <: SemanticUI
  of::Any = nothing     # the AmountCell
end
"The list of units that floats under a measure's amount, with a field that searches it"
@def mutable struct UnitMenu <: SemanticUI
  of::Any = nothing
  i::Int = 0
  side::Symbol = :bottom   # the side of the amount that it's on
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
end
"A unit in the list of units"
@def mutable struct UnitRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end
"A part of a measure's row that a click changes: its item, or what it adds for waste"
@def mutable struct MeasureCell <: SemanticUI
  of::Any = nothing
  i::Int = 0
  what::Symbol = :item
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn: its width cuts its words short, and its tooltip goes under it
  full::String = ""                           # its words when they're cut short with …, to show in its tooltip, or "" when they fit
end
"""
The heading of a column of the table of measures. It fills the column's cell, so
the mouse can be anywhere over the column to use it. A click sorts by the
column, or opens a menu that sorts and searches it.
"""
@def mutable struct ColumnHead <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  side::Symbol = :start   # the side of the cell that its words go on: :start, or :end over numbers that line up on the right
  words::Any = nothing    # its HeadWords
end
"The words of a column's heading, and the arrow of its order. The heading's menu and tooltip point at them."
@def mutable struct HeadWords <: SemanticUI
  of::Any = nothing   # the heading
end
"The menu of a column of text: its two orders and a field to search it. It floats under the heading, as it does in Centient's lists."
@def mutable struct ColumnMenu <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  side::Symbol = :bottom   # the side of the heading that it's on
end
"One of the two orders in the menu of a column"
@def mutable struct SortRow <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  dir::Symbol = :asc
end
"A line of the list that a search shows: an item of Centient's catalogue, or a contact"
@def mutable struct FoundRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end
"The foot of the list of items: the catalogue that the list shows. A click on it shows another."
@def mutable struct CatalogueFoot <: SemanticUI
  of::Any = nothing
end
"""
The list of what a search found. It floats beside the text field with an arrow
that points at the field, the way the lists in Centient's own forms do.
"""
@def mutable struct FoundList <: SemanticUI
  of::Any = nothing
  side::Symbol = :bottom   # the side of the text field that it's on
  rows::Any = nothing      # what it showed last. A new list starts at its top.
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
  popup::Any = nothing     # what UI.jl floats it in
  settled::Bool = false    # its side of the text field is chosen, and it keeps that side while it's open
end

"A part of `v` that's kept between frames"
part!(make, v::TakeoffView, key) = begin
  node = get!(make, v.parts, key)
  node.parent === nothing && setfield!(node, :parent, v)
  node
end

"The text field of a takeoff. One field does for the name of a measure, a search, the scale and the rest."
plan_input(v::TakeoffView) = part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

# --- the plan's file ---------------------------------------------------------------------

"The file of the plan, or \"\" when the block names none that's there"
plan_path(v::TakeoffView) = begin
  isempty(v.data.plan) && return ""
  path = abspath(docdir(editor(v)), expanduser(unescaped(v.data.plan)))
  isfile(path) ? path : ""
end

ispdf(path) = lowercase(splitext(path)[2]) == ".pdf"

"How many pages the plan has"
plan_pages(v::TakeoffView) = (path = plan_path(v); isempty(path) ? 0 : ispdf(path) ? pdf_pages(path) : 1)

"""
How wide and how tall the page that shows is, in points, or nothing when there's
no plan to show. A picture has a point for each of its pixels.
"""
plan_size(v::TakeoffView) = begin
  path = plan_path(v)
  isempty(path) && return nothing
  ispdf(path) && return pdf_size(path, v.data.page)
  key = picture_key(path)
  key === nothing && return nothing
  source = image_source(key)
  (Float64(source.width), Float64(source.height))
end

"How tall the plan's view is in a block that's `w` wide: tall enough for the whole page, and no taller than leaves room for the list"
plan_h(v::TakeoffView, w::px) = begin
  s = plan_size(v)
  s === nothing && return 180px
  _, tall = window_size(editor(v))
  clamp((w - 2px(PAPER_EDGE)) * s[2] / s[1] + 2px(PAPER_EDGE), PLAN_LEAST, max(PLAN_LEAST, tall - 280px))
end

"Make the file at `path` the plan"
plan!(v::TakeoffView, path) = begin
  v.data.plan = named(editor(v), path)
  v.data.page = 1
  v.zoom = 0.0
  empty!(v.draft)
  commit!(v)
end

"Ask which file holds the plan, with macOS's own panel"
choose_plan!(v::TakeoffView, w) = begin
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  (Sys.isapple() && !isempty(w.glfw)) || return handled
  path = with_pool() do
    panel = msg(cls("NSOpenPanel"), "openPanel")
    msg(panel, "setDirectoryURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(docdir(editor(v)))))
    # 1 is the panel's Open button
    ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), panel, sel("runModal")) == 1 || return nothing
    jstring(msg(msg(panel, "URL"), "path"))
  end
  # The panel took the mouse, so the window never heard its button come up
  Keys.mouse_left in w.keys && (w.keys ⊻= Keys.mouse_left)
  path === nothing || plan!(v, path)
  handled
end

"The takeoff under the mouse, or nothing"
takeoff_at(e, w) = begin
  x, y = w.mouse
  for node in values(e.nodes)
    node isa TakeoffView || continue
    r = rect(node)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return node
  end
  nothing
end

# --- the block's lines -------------------------------------------------------------------

"The first and the last line of the `n`th takeoff block of `b`, or nothing"
takeoff_lines(b::Buffer, n::Int) = block_lines(b, TAKEOFF, n)

"The first and the last line of the `n`th code block of `b` in the language `lang`, or nothing"
block_lines(b::Buffer, lang::String, n::Int) = begin
  ks = kinds(b)
  seen = 0
  for i in eachindex(ks)
    (ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == lang) || continue
    (seen += 1) == n || continue
    t = codeblock(b, i)[2]
    return t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? (i, t) : nothing
  end
  nothing
end

"Read the takeoff again from the lines of its block, if they've changed"
reread!(v::TakeoffView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Plans.takeoff(lines)
  v.current = min(v.current, length(v.data.measures))
  v.picked = nothing
  v
end

"""
Write the takeoff into its block. The caret stays where it was in the text, and
⌘Z takes the change back. If the block's lines aren't the ones that the takeoff
was read from, something else changed them, and the takeoff is read again.
"""
commit!(v::TakeoffView) = begin
  b = editor(v).buf
  readonly(b) && return v
  span = takeoff_lines(b, v.n)
  span === nothing && return v
  i, t = span
  v.first, v.last = i, t
  b.lines[i+1:t-1] == v.lines || return reread!(v, b.lines[i+1:t-1])
  new = Plans.written(v.data)
  new == v.lines && return v
  caret, anchor = b.caret, b.anchor
  edit!(b, line_end(b, i), line_end(b, t - 1), isempty(new) ? "" : "\n" * join(new, "\n"))
  by = length(new) - length(v.lines)
  moved(p) = p[1] >= t ? (p[1] + by, p[2]) : p[1] > i ? (i, 0) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  v.last += by
  v.lines = new
  v
end

"What the `takeoff` block from line `i` to line `t` shows. `n` is its place among the page's takeoffs."
takeoff_item(e, i, t, n) = begin
  v = get!(() -> TakeoffView(n=n), e.nodes, (:takeoff, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v.first, v.last = i, t
  reread!(v, e.buf.lines[i+1:t-1])
  # A takeoff that fills the window is drawn over the page, and its room in the page stays empty
  v.full && return Live(Box(width(grow=grow), height(v.tall)), v.tall + 2LIVE_GAP)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  v.tall = concrete.height
  Live(v, v.tall + 2LIVE_GAP)
end

# --- Centient ----------------------------------------------------------------------------

"What Centient says of the item that `ref` names, or nothing if it hasn't said yet"
known(v::TakeoffView, ref) = isempty(ref) ? nothing : get(v.known, ref, nothing)

"Ask Centient for the items of the takeoff that it hasn't told of yet. The plan's view asks when it's drawn, so a takeoff that's out of sight asks nothing."
lookup!(v::TakeoffView) = begin
  v.lookup === nothing || return
  refs = unique!([m.item for m in v.data.measures if !isempty(m.item) && !haskey(v.known, m.item)])
  (isempty(refs) || !Centient.available()) && return
  # An item that Centient doesn't have is asked for once
  foreach(ref -> v.known[ref] = nothing, refs)
  v.lookup = Centient.ask("lookup_items", Dict("refs" => refs))
  nothing
end

"A sentence at the foot of the block. `wrong` shows it as something that went wrong."
say!(v::TakeoffView, words, wrong=false) = (v.said = String(words); v.wrong = wrong; handled)

"An amount of money: \$1,234.50"
dollars(x::Real) = begin
  cents = round(Int, 100x)
  (cents < 0 ? "-" : "") * "\$" * commas(abs(cents) ÷ 100) * "." * lpad(abs(cents) % 100, 2, '0')
end

"""
The price of one of measure `m`'s unit, from the catalogue's `row`. Centient's
price is for one of the item's unit, so an item sold at \$2 a foot is \$6.56 a
metre to a measure in metres. It's nothing when the item is sold by a unit
that `m` can't be in, like a price a metre for a count.
"""
unit_price(m, row) = begin
  u = string(something(get(row, "unit", nothing), ""))
  Plans.kind_for(u) == m.kind || return nothing
  # A unit that Centient doesn't name, like "lineal metre" or "each", is its kind's own
  row["price"] * get(Plans.UNIT_SIZES, Plans.unit(m), 1.0) / get(Plans.UNIT_SIZES, u, 1.0)
end

"What `amount` of its kind's own unit of measure `m` costs at the price of the catalogue's `row`"
cost_of(m, amount::Real, row) = begin
  p = unit_price(m, row)
  p === nothing ? amount * row["price"] : Plans.in_unit(amount, Plans.unit(m)) * p
end

"""
The line of a quote for measure `m`, which comes to `amount` of its kind's own
unit. The line is in the measure's unit, and Centient prices it from the item
in that unit.
"""
quote_line(m, amount::Real) = begin
  unit = Plans.unit(m)
  Dict{String,Any}("ref" => m.item, "quantity" => round(Plans.in_unit(amount, unit), sigdigits=6), "unit" => unit, "note" => m.name)
end

"Ask Centient for a quote with a line for each measure"
make_quote!(v::TakeoffView) = begin
  v.quoting === nothing || return handled
  t = v.data
  Centient.available() || return say!(v, "Centient isn't on this Mac, so Kaydown can't make the quote", true)
  isempty(t.customer) && return say!(v, "Choose the customer first", true)
  lines = Any[]
  for m in t.measures
    amount = Plans.amount(t, m)
    amount === nothing && return say!(v, "Set the scale first, so that $(isempty(m.name) ? "each length" : m.name) has a size", true)
    amount > 0 || continue
    push!(lines, quote_line(m, amount))
  end
  isempty(lines) && return say!(v, "Nothing is measured yet", true)
  plan = isempty(t.plan) ? "" : " of " * basename(t.plan)
  v.quoting = Centient.ask("create_quote", Dict{String,Any}("customer" => t.customer, "notes" => "From a takeoff$plan in Kaydown", "lines" => lines))
  say!(v, "Making the quote in Centient…")
end

"""
What happens to a takeoff in each frame, before the page is laid out: a drag
that ended is written down, the text field that lost the keyboard closes, and
Centient's answers are taken.
"""
tick!(v::TakeoffView) = begin
  w = window_of(v)
  v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v)
  # A click somewhere else took the keyboard from the text field
  v.asking !== nothing && w !== nothing && w.focus !== plan_input(v) && settle_asking!(v)
  waiting = false
  # A column shows what its search finds while you type
  v.asking !== nothing && v.asking[1] == :filter && filter!(v, v.asking[2], plan_input(v).text)
  # The list of units shows the ones that match what's typed. New words pick the unit that they name, or the first.
  if v.asking !== nothing && v.asking[1] == :unit
    words = String(strip(plan_input(v).text))
    v.rows = Any[u for u in units_for(v, v.asking[2]) if unit_matches(u, words)]
    words == v.query || (v.query = words; v.pick = something(findfirst(u -> names_unit(u, words), v.rows), 1))
    v.pick = clamp(v.pick, 1, max(1, length(v.rows)))
  end
  if v.asking !== nothing && v.asking[1] in (:item, :customer)
    words = String(strip(plan_input(v).text))
    words == v.query || (v.query = words; v.typed = time(); v.pick = 1)
    # The search waits until the typing stops for a moment
    if v.typed > 0 && time() - v.typed > 0.2
      v.typed = 0.0
      from = ITEM_FROM[]
      v.search = v.asking[1] == :customer ? Centient.ask("find_contacts", Dict("query" => words)) :
                 from[1] == :suppliers    ? Centient.ask("list_catalogues", Dict("query" => words)) :
                 Centient.ask("search_catalogue", Dict("query" => words, "catalogue" => from[1] == :own ? "own" : from[2]))
    end
    waiting = v.typed > 0
  end
  Centient.check!()
  r = v.search
  if r !== nothing && Centient.finished(r)
    v.search = nothing
    if Centient.failed(r)
      v.rows = Any[]
      say!(v, r.problem, true)
    else
      v.rows = collect(Any, get(r.value, r.tool == "find_contacts" ? "contacts" : r.tool == "list_catalogues" ? "catalogues" : "items", Any[]))
      v.pick = clamp(v.pick, 1, max(1, length(v.rows)))
    end
  end
  r = v.lookup
  if r !== nothing && Centient.finished(r)
    v.lookup = nothing
    Centient.failed(r) || foreach(row -> v.known[row["ref"]] = row, get(r.value, "items", Any[]))
  end
  r = v.quoting
  if r !== nothing && Centient.finished(r)
    v.quoting = nothing
    if Centient.failed(r)
      say!(v, r.problem, true)
    else
      v.data.made = string(get(r.value, "number", ""))
      company = Centient.server.company
      say!(v, "Centient has quote $(v.data.made) for $(dollars(get(r.value, "total", 0.0))) with GST" * (isempty(company) ? "" : ", in $company"))
      commit!(v)
    end
  end
  # While Centient works, the window looks again soon
  (waiting || v.search !== nothing || v.lookup !== nothing || v.quoting !== nothing) && redraw_in!(v, 0.1)
  v
end

"Do what each takeoff of the page that shows needs in this frame"
takeoff_tick!(e) = for (key, node) in collect(e.nodes)
  (node isa TakeoffView && key[2] == e.buf.path) || continue
  tick!(node)
  node.full || continue
  # A takeoff whose block has gone goes back to the page. Under one that fills the window, the page stays where it was.
  takeoff_lines(e.buf, node.n) === nothing ? (node.full = false) : (e.scroll.offset = node.pinned)
end

# --- the text field ----------------------------------------------------------------------

"Close the text field, if it shows. What's typed in it is kept, but nothing is chosen from a list."
settle_asking!(v::TakeoffView) = v.asking === nothing ? handled : v.asking[1] in (:item, :customer, :unit) ? stop_asking!(v) : answer!(v)

"Show the text field for `what`, with `text` in it and selected"
ask!(v::TakeoffView, what, text="", placeholder="") = begin
  settle_asking!(v)
  i = plan_input(v)
  i.color = colours.ink
  i.text, i.placeholder = String(text), String(placeholder)
  i.anchor, i.cursor = 0, length(i.text)
  v.asking = what
  v.rows, v.pick, v.search = Any[], 1, nothing
  v.query, v.typed = "\0", 0.0   # no words yet, so the first look at the field starts a search
  v.said, v.wrong = "", false
  focus(i)
  if what[1] == :item
    # The list starts on the catalogue that an item was last chosen from, and not on the list of suppliers
    ITEM_FROM[][1] == :suppliers && (ITEM_FROM[] = (:own,))
    i.placeholder = "⌥ to toggle catalogue"
  end
  what[1] in (:item, :customer) && Centient.available() && show_found!(v)
  handled
end

"Take the text field away. The keyboard goes back to the plan."
stop_asking!(v::TakeoffView) = begin
  v.asking = nothing
  v.rows, v.search = Any[], nothing
  w = window_of(v)
  w === nothing || (close_popup!(w, FOUND_KEY); close_popup!(w, HEAD_KEY); close_popup!(w, UNIT_KEY))
  w !== nothing && w.focus === plan_input(v) && focus(part!(() -> PlanArea(of=v), v, :area))
  handled
end

"The number of metres that `text` says: 3.6, 3.6m or 3600mm. It's nothing when it says none."
metres_typed(text) = begin
  m = match(r"^\s*(\d+(?:\.\d+)?)\s*(mm|cm|m)?\s*$", lowercase(text))
  m === nothing && return nothing
  n = parse(Float64, m[1]) * (m[2] == "mm" ? 0.001 : m[2] == "cm" ? 0.01 : 1.0)
  n > 0 ? n : nothing
end

"Give page `page` the scale `n`. A plan's first scale is for all its pages. After that, a page gets a scale of its own."
scale!(v::TakeoffView, n) = begin
  t = v.data
  page = t.page
  key = isempty(t.scales) || plan_pages(v) <= 1 || (length(t.scales) == 1 && haskey(t.scales, 0) && page == 1) ? 0 : page
  t.scales[key] = round(n, digits=1)
  commit!(v)
end

"Take row `k` of what a search found"
choose_row!(v::TakeoffView, k::Int) = begin
  a = v.asking
  (a === nothing || !(1 <= k <= length(v.rows))) && return stop_asking!(v)
  row = v.rows[k]
  # A supplier in the list of suppliers opens its catalogue. The search goes on there.
  a[1] == :item && haskey(row, "slug") && return browse!(v, (:catalogue, string(row["slug"]), string(row["name"])))
  if a[1] == :customer
    v.data.customer = string(row["name"])
  elseif a[2] <= length(v.data.measures)
    m = v.data.measures[a[2]]
    was = known(v, m.item)
    # A measure that still has the name it was made with, or its old item's name, takes the new item's name
    (isempty(m.name) || occursin(FIRST_NAME, m.name) || (was !== nothing && m.name == was["name"])) &&
      (m.name = replace(string(row["name"]), '|' => '/'))
    m.item = string(row["ref"])
    v.known[m.item] = row
    # The item's unit says what the measure is, and the tool for it is ready to draw
    kind = Plans.kind_for(get(row, "unit", nothing))
    isempty(m.shapes) && m.kind != kind && (m.kind = kind; m.unit = "")
    # The amount shows in the unit that the item is sold by, when the measure can be in it
    sold = string(something(get(row, "unit", nothing), ""))
    Plans.unit_kind(sold) == m.kind && Plans.unit!(m, sold)
    stop_asking!(v)
    commit!(v)
    v.current = a[2]
    tool!(v, m.kind)
    m.kind == kind || say!(v, "Centient's price for $(row["name"]) is for $(sold_by(row)), and this measure is $(KIND_WORDS[m.kind])", true)
    return handled
  end
  stop_asking!(v)
  commit!(v)
  handled
end

"Do what the text field was for with what's typed in it"
answer!(v::TakeoffView) = begin
  a = v.asking
  a === nothing && return handled
  text = String(strip(plan_input(v).text))
  t = v.data
  # A column's search changes what the table shows, and nothing in the block
  a[1] == :filter && return (filter!(v, a[2], text); stop_asking!(v))
  a[1] == :unit && return isempty(v.rows) ? stop_asking!(v) : unit!(v, a[2], v.rows[clamp(v.pick, 1, length(v.rows))])
  if a[1] in (:item, :customer)
    isempty(v.rows) || return choose_row!(v, v.pick)
    # Nothing to choose from. An empty field takes the item away, and a customer is kept as it's typed.
    a[1] == :item && isempty(text) && a[2] <= length(t.measures) && (t.measures[a[2]].item = "")
    a[1] == :customer && !isempty(text) && (t.customer = text)
  elseif a[1] == :name
    a[2] <= length(t.measures) && !isempty(text) && (t.measures[a[2]].name = replace(text, '|' => '/'))
  elseif a[1] == :extra
    n = tryparse(Float64, strip(replace(text, '%' => "", '+' => "")))
    a[2] <= length(t.measures) && (t.measures[a[2]].extra = n === nothing ? 0.0 : clamp(n, 0, 1000) / 100)
  elseif a[1] == :scale
    n = Plans.scale(text)
    n === nothing ? say!(v, "A scale is written like 1:100", true) : scale!(v, n)
  elseif a[1] == :length
    real = metres_typed(text)
    n = real === nothing ? nothing : Plans.scale(a[2], a[3], real)
    n === nothing ? say!(v, "Type the length in metres, like 3.6", true) : scale!(v, n)
    empty!(v.draft)
    v.tool = :select
  end
  stop_asking!(v)
  commit!(v)
  handled
end

# The keys of the text field that the field has no use for come here
onkey(v::TakeoffView, ::KeyPress{Keys.enter}) = v.asking === nothing ? nothing : answer!(v)
onkey(v::TakeoffView, ::KeyPress{Keys.escape}) = begin
  v.asking === nothing && return nothing
  v.asking[1] == :length && (empty!(v.draft); v.tool = :select)
  stop_asking!(v)
end
# ⌥ in an empty search for an item changes the catalogue that the list shows
onkey(v::TakeoffView, ::KeyPress{Keys.opt}) = begin
  a = v.asking
  (a !== nothing && a[1] == :item && Centient.available() && isempty(strip(plan_input(v).text))) || return nothing
  toggle_catalogue!(v)
end
onkey(v::TakeoffView, ::KeyPress{Keys.down}) = v.asking === nothing ? nothing : (v.pick = min(v.pick + 1, max(1, length(v.rows))); handled)
onkey(v::TakeoffView, ::KeyPress{Keys.up}) = v.asking === nothing ? nothing : (v.pick = max(v.pick - 1, 1); handled)

# --- the view of the plan ----------------------------------------------------------------

"The point of the page that's at a place in the window"
page_point(v::TakeoffView, x, y) = (v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom)

"The place in the window of a point of the page"
window_point(v::TakeoffView, p) = (v.box[1] + (p[1] - v.at[1]) * v.zoom, v.box[2] + (p[2] - v.at[2]) * v.zoom)

"The px of white that the view keeps round the paper, so that the paper's edge and its shadow show"
const PAPER_EDGE = 14.0

"How many px to a point fits the whole page in the view, with white round it"
fit_zoom(v::TakeoffView, s) = max(min((v.box[3] - 2PAPER_EDGE) / s[1], (v.box[4] - 2PAPER_EDGE) / s[2]), 1e-3)

"Show the whole page, in the middle of the view"
fit!(v::TakeoffView, s) = begin
  v.zoom = fit_zoom(v, s)
  v.at = ((s[1] - v.box[3] / v.zoom) / 2, (s[2] - v.box[4] / v.zoom) / 2)
  v
end

"""
Keep the page in the view. Where the page is narrower than the view, it stays
in the middle, and so it does where it's shorter. So the plan only moves once
it's bigger than the view, and then no further than its edges, with the
white that the view keeps round the paper. `s` is the page's size in points.
"""
hold!(v::TakeoffView, s) = begin
  w, h = v.box[3] / v.zoom, v.box[4] / v.zoom
  e = PAPER_EDGE / v.zoom
  v.at = (s[1] <= w ? (s[1] - w) / 2 : clamp(v.at[1], -e, s[1] - w + e),
          s[2] <= h ? (s[2] - h) / 2 : clamp(v.at[2], -e, s[2] - h + e))
  v
end

"Note that the view moved just now, and keep the page in it"
moved!(v::TakeoffView) = begin
  v.moved = time()
  s = plan_size(v)
  s === nothing ? v : hold!(v, s)
end

"Make the plan `by` times as big. The point of the page at the place `(x, y)` in the window stays there."
zoom_plan!(v::TakeoffView, by, x, y) = begin
  s = plan_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  p = page_point(v, x, y)
  v.zoom = clamp(v.zoom * by, fit_zoom(v, s), NEAR)   # never smaller than the whole page
  v.at = (p[1] - (x - v.box[1]) / v.zoom, p[2] - (y - v.box[2]) / v.zoom)
  moved!(v)
  handled
end

"Go on by `by` pages"
page!(v::TakeoffView, by) = begin
  page = clamp(v.data.page + by, 1, max(1, plan_pages(v)))
  page == v.data.page && return handled
  v.data.page = page
  v.zoom = 0.0
  v.picked = nothing
  empty!(v.draft)
  commit!(v)
  handled
end

# --- drawing -----------------------------------------------------------------------------

"How many of the screen's pixels a px is wide on the canvas `ctx`"
density(ctx) = begin
  m = Ref(Skia.sk_matrix_t(1f0, 0f0, 0f0, 0f0, 1f0, 0f0, 0f0, 0f0, 1f0))
  Skia.sk_canvas_get_total_matrix(ctx, m)
  sqrt(abs(m[].scaleX * m[].scaleY - m[].skewX * m[].skewY))
end

const plan_sampling = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0),
                                                 Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_NONE)

"Draw the part `from` of a picture of Skia's into the part `to` of the window. Each is a left, a top, a width and a height."
paint_picture(ctx, image, from, to) = begin
  a = Ref(Skia.sk_rect_t(Float32(from[1]), Float32(from[2]), Float32(from[1] + from[3]), Float32(from[2] + from[4])))
  b = Ref(Skia.sk_rect_t(Float32(to[1]), Float32(to[2]), Float32(to[1] + to[3]), Float32(to[2] + to[4])))
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_canvas_draw_image_rect(ctx, image, a, b, Ref(plan_sampling), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
  Skia.sk_paint_delete(paint)
end

"The part of a page of a PDF plan that the view shows, drawn at the screen's own pixels and kept until the view moves"
sharpen!(v::TakeoffView, path, of, k, x, y, w, h) = sharpen!(v.sharp, path, v.data.page, of, k, x, y, w, h)

"""
The part of page `page` of the PDF file at `path` that's `w` by `h` pixels and
starts `x` and `y` pixels into the page drawn `k` pixels to the point. It's kept
in `p` while `of`, what it's a picture of, stays the same.
"""
sharpen!(p::Sharp, path, page, of, k, x, y, w, h) = begin
  p.of == of && return p.image
  started = time()
  pixels = pdf_part(path, page, k, x, y, w, h)
  p.image == C_NULL || Skia.sk_image_unref(p.image)
  p.image, p.of = C_NULL, of
  pixels === nothing && return C_NULL
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_BGRA_8888, Skia.SK_ALPHA_TYPE_PREMUL, w, h))
  GC.@preserve info pixels begin
    data = Skia.sk_data_new_with_copy(pointer(pixels), UInt64(4w * h))
    p.image = Skia.sk_image_new_raster_data(info, data, Csize_t(4w))
    Skia.sk_data_unref(data)
  end
  p.cost = time() - started
  p.image
end

"How round the corners of the plan's paper are, in px"
const PAPER_ROUND = 3.0

"""
Draw the plan's paper, with what shows where it ends on the white behind it:
a soft shadow under it and a thin line round it. Its corners are a little round.
"""
paper!(ctx, (x, y, w, h)) = begin
  shape(grow, down) = begin
    path = Skia.sk_path_new()
    rect = Ref(Skia.sk_rect_t(Float32(x - grow), Float32(y - grow + down), Float32(x + w + grow), Float32(y + h + grow + down)))
    Skia.sk_path_add_rounded_rect(path, rect, Float32(PAPER_ROUND + grow), Float32(PAPER_ROUND + grow), Skia.SK_PATH_DIRECTION_CW)
    path
  end
  fill(path, paint) = (Skia.sk_canvas_draw_path(ctx, path, paint); Skia.sk_paint_delete(paint); Skia.sk_path_delete(path))
  shadow = ink(RGBA(0, 0, 0, 0.2))
  blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 6f0, true)
  Skia.sk_paint_set_maskfilter(shadow, blur)
  fill(shape(0, 2), shadow)
  Skia.sk_maskfilter_unref(blur)
  # The line is outside the paper, so the plan doesn't cover it
  fill(shape(0.5, 0), ink(RGBA(0, 0, 0, 0.16), 1))
  fill(shape(0, 0), ink(colorant"white"))
end

"Draw the page of the plan that shows. `s` is its size in points."
draw_plan(ctx, v::TakeoffView, s) = begin
  left, top, wide, tall = v.box
  path = plan_path(v)
  # Where the paper is in the window
  x, y = window_point(v, (0.0, 0.0))
  paper = (x, y, s[1] * v.zoom, s[2] * v.zoom)
  paper!(ctx, paper)
  # What's on the paper is cut off at the paper's round corners
  with_round_clip(() -> plan_ink(ctx, v, s, path, paper), ctx, px(paper[1]), px(paper[2]), px(paper[3]), px(paper[4]), px(PAPER_ROUND))
end

"Draw what's on the paper: the picture, or the part of the PDF page that's in the view"
plan_ink(ctx, v::TakeoffView, s, path, paper) = begin
  left, top, wide, tall = v.box
  if !ispdf(path)
    key = picture_key(path)
    key === nothing || paint_picture(ctx, image_source(key).raw, (0, 0, s[1], s[2]), paper)
    return
  end
  # Never fewer than 2 pixels to the px, so that the plan is sharp on paper too
  d = clamp(density(ctx), 2, 3)
  w, h = round(Int, wide * d), round(Int, tall * d)
  (w < 1 || h < 1) && return
  k = v.zoom * d   # the screen's pixels to a point of the page
  of = (path, mtime(path), v.data.page, k, v.at, w, h)
  p = v.sharp
  # A plan that takes long to draw shows a rougher picture of the whole page while it moves
  if p.of != of && p.cost > QUICK && time() - v.moved < SETTLED
    rough = pdf_page(path, v.data.page, 2000)
    rough === nothing || paint_picture(ctx, image_source(rough).raw, (0, 0, image_source(rough).width, image_source(rough).height), paper)
    redraw_in!(v, SETTLED)
    return
  end
  image = sharpen!(v, path, of, k, v.at[1] * k, v.at[2] * k, w, h)
  image == C_NULL && return
  # The picture is of the whole view, with white where the paper ends. The paper's edge cuts it off.
  paint_picture(ctx, image, (0, 0, w, h), (left, top, wide, tall))
end

"A paint for lines `wide` px wide, or for filling when `wide` is 0"
ink(colour, wide=0.0) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colour))
  Skia.sk_paint_set_style(paint, wide > 0 ? Skia.SK_PAINT_STYLE_STROKE : Skia.SK_PAINT_STYLE_FILL)
  if wide > 0
    Skia.sk_paint_set_stroke_width(paint, Float32(wide))
    Skia.sk_paint_set_stroke_join(paint, Skia.SK_STROKE_JOIN_ROUND)
    Skia.sk_paint_set_stroke_cap(paint, Skia.SK_STROKE_CAP_ROUND)
  end
  paint
end

"Draw a line through the places `ps`. `fill` colours what's inside it. `closed` joins its end to its start."
trace(ctx, ps, colour, wide; fill=nothing, closed=false) = begin
  length(ps) < 2 && return
  shape = Skia.sk_path_new()
  for (i, (x, y)) in enumerate(ps)
    i == 1 ? Skia.sk_path_move_to(shape, Float32(x), Float32(y)) : Skia.sk_path_line_to(shape, Float32(x), Float32(y))
  end
  closed && Skia.sk_path_close(shape)
  if fill !== nothing
    paint = ink(fill)
    Skia.sk_canvas_draw_path(ctx, shape, paint)
    Skia.sk_paint_delete(paint)
  end
  paint = ink(colour, wide)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
end

"Draw a dot of radius `r` at the place `(x, y)`, with a white edge"
dot(ctx, (x, y), r, colour) = begin
  for (radius, c) in ((r + 1.5, colorant"white"), (r, colour))
    paint = ink(c)
    Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(radius), paint)
    Skia.sk_paint_delete(paint)
  end
end

"Write `words` in a small dark box beside the place `(x, y)`"
tag(ctx, (x, y), words) = begin
  isempty(words) && return
  face = Face(SANS, "Semibold", 11px, colorant"white", false)
  wide = num(measure(face, words))
  rounded_rectangle(ctx, px(x + 10), px(y - 22), px(wide + 12), 18px, 4px, background=RGBA(0.12, 0.12, 0.12, 0.85))
  paint = ink(colorant"white")
  blob = Skia.sk_textblob_make_from_string(words, skia_font(face.family, face.size, face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
  Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x + 16), Float32(y - 9), paint)
  Skia.sk_textblob_unref(blob)
  Skia.sk_paint_delete(paint)
end

"What a shape of this kind comes to in the unit `unit`, as the plan shows it beside the shape, or \"\" when its page has no scale"
size_text(v::TakeoffView, kind, shape, unit=Plans.own_unit(kind)) = begin
  a = Plans.amount(v.data, kind, shape)
  a === nothing ? "" : Plans.shown(kind, a, unit)
end

"Draw what's measured on the page that shows, and what's being drawn"
draw_shapes(ctx, v::TakeoffView) = begin
  t = v.data
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == t.page || continue
    colour = hue(i)
    on = v.picked !== nothing && v.picked[1] == i && v.picked[2] == j
    ps = [window_point(v, p) for p in s.points]
    if m.kind == :count
      for (k, p) in enumerate(ps)
        dot(ctx, p, on && length(v.picked) == 3 && v.picked[3] == k ? 7.5 : 5, colour)
      end
      continue
    end
    area = m.kind == :area
    trace(ctx, ps, colour, on ? 4 : 2.5, fill=area ? RGBA(colour, 0.22) : nothing, closed=area)
    # The corners show on the measure that the tools draw for, so that you can take hold of one
    (on || v.current == i) && foreach(p -> dot(ctx, p, on ? 4 : 3, colour), ps)
    on && tag(ctx, ps[end], size_text(v, m.kind, s, Plans.unit(m)))
  end
  isempty(v.draft) && return
  # What's being drawn runs on to the mouse
  kind = v.tool
  colour = kind == :scale ? colours.accent : hue(v.current > 0 && t.measures[v.current].kind == kind ? v.current : length(t.measures) + 1)
  # With the mouse over the Done button, it shows what a click there leaves
  done = over_done(v)
  points = v.mouse === nothing || v.asking !== nothing || done ? copy(v.draft) : [v.draft; [v.mouse]]
  ps = [window_point(v, p) for p in points]
  trace(ctx, ps, colour, 2, fill=kind == :area && length(ps) > 2 ? RGBA(colour, 0.15) : nothing, closed=kind == :area && length(ps) > 2)
  foreach(p -> dot(ctx, p, 3, colour), ps[1:length(v.draft)])
  # In the unit of the measure that it's for
  unit = v.current > 0 && t.measures[v.current].kind == kind ? Plans.unit(t.measures[v.current]) : Plans.own_unit(kind)
  kind == :scale || tag(ctx, ps[end], size_text(v, kind, Plans.Shape(t.page, points), unit))
  draw_done(ctx, v, done)
end

# --- the button that ends a line or an outline -------------------------------------------
#
# While a length or an area is being drawn, a Done button shows beside its last
# corner, as soon as it has corners enough to end. A click on the button ends
# the line or the outline, as Return does, and puts no corner down. The button
# is behind the last corner and to one side of the line that led to it. The
# next corner is seldom put there, so the button is seldom in its way.

const DONE_W, DONE_H = 64.0, 24.0   # px. How wide and how tall the Done button is.
const DONE_GAP = 10.0               # px between the button and the line that led to the last corner

"""
Where the Done button is in the window: its left, its top, its width and its
height. It's nothing while there's no line or outline with corners enough to end.
"""
done_box(v::TakeoffView) = begin
  (v.tool in (:length, :area) && v.zoom > 0) || return nothing
  n = length(v.draft)
  n >= (v.tool == :length ? 2 : 3) || return nothing
  (x, y), (x0, y0) = window_point(v, v.draft[n]), window_point(v, v.draft[n-1])
  far = hypot(x - x0, y - y0)
  # The way the line went to its last corner
  ux, uy = far > 0 ? ((x - x0) / far, (y - y0) / far) : (1.0, 0.0)
  # The button's place on one side of the line. Its front is level with the corner, and its near edge is DONE_GAP from the line.
  place(nx, ny) = begin
    back = (abs(ux) * DONE_W + abs(uy) * DONE_H) / 2
    off = (abs(nx) * DONE_W + abs(ny) * DONE_H) / 2 + DONE_GAP
    (x - ux * back + nx * off - DONE_W / 2, y - uy * back + ny * off - DONE_H / 2)
  end
  left, top, wide, tall = v.box
  fits((bx, by)) = bx >= left && by >= top && bx + DONE_W <= left + wide && by + DONE_H <= top + tall
  # The side that's lower in the window, or the right one of two that are level. The other side if only that one is in the view.
  nx, ny = ux > 0 || (ux == 0 && uy < 0) ? (-uy, ux) : (uy, -ux)
  at = place(nx, ny)
  other = place(-nx, -ny)
  fits(at) || !fits(other) || (at = other)
  # A corner that's out of sight still has its button in sight
  (clamp(at[1], left, max(left, left + wide - DONE_W)), clamp(at[2], top, max(top, top + tall - DONE_H)), DONE_W, DONE_H)
end

"True when the place `(x, y)` of the window is on the Done button"
on_done(v::TakeoffView, x, y) = begin
  b = done_box(v)
  b !== nothing && b[1] <= x <= b[1] + b[3] && b[2] <= y <= b[2] + b[4]
end

"True when the mouse is over the Done button"
over_done(v::TakeoffView) = (w = window_of(v); w !== nothing && on_done(v, num(w.mouse[1]), num(w.mouse[2])))

"What the Done button's tooltip says"
done_tip(v::TakeoffView) = (v.tool == :area ? "End the outline" : "End the line") * "  Return"

"Draw the Done button. It's lighter while the mouse is over it."
draw_done(ctx, v::TakeoffView, over::Bool) = begin
  b = done_box(v)
  b === nothing && return
  size = (px(b[3]), px(b[4]))
  white = colorant"white"
  button = Box(fixed(size[1]), height(size[2]), radius(size[2] / 2), Alignment.Center, border(1.5px, :solid, white),
               background(over ? RGBA(0.3, 0.3, 0.3, 0.95) : RGBA(0.12, 0.12, 0.12, 0.9)),
               Row(Alignment.Center, child_gap=4px, Icon("check", size=12px, color=white), label("Done", 12px, color=white, weight="Semibold")))
  Skia.sk_canvas_save(ctx)
  Skia.sk_canvas_translate(ctx, Float32(b[1]), Float32(b[2]))
  draw(ctx, size, describe(button, size))
  Skia.sk_canvas_restore(ctx)
end

describe(a::PlanArea) = begin
  v = a.of
  # In the window, the plan takes all the room that the tools leave
  h = v.full ? height(grow=grow) : height(plan_h(v, editor(v).width - 2px))
  plan_size(v) === nothing || return Box(width(grow=grow), h, background(takeoff_back()))
  words = isempty(v.data.plan) ? "Drop a plan here, or click to choose one: a PDF file or a picture" :
                                 "$(v.data.plan) isn't a plan that Kaydown can show. Click to choose another."
  Column(width(grow=grow), h, justify=Alignment.Center, child_gap=10px, background(colours.stripe),
    Icon("map", size=26px, color=colours.faint), Box(label(words, 13px, color=colours.dim)))
end

draw(ctx, size, ui::ConcreteRect, a::PlanArea) = begin
  v = a.of
  was = v.box
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  s = plan_size(v)
  s === nothing && return
  # A new file or a new page is shown whole
  shown = (plan_path(v), v.data.page)
  if v.zoom <= 0 || v.fitted != shown
    fit!(v, s)
    v.fitted = shown
  elseif was[3] > 0 && (was[3] != v.box[3] || was[4] != v.box[4])
    # The view changed its size, as it does when the window does, when it fills the window and on paper.
    # A view that showed the whole page still does. A view that was bigger shows the same part of the plan.
    if v.zoom <= 1.0001min(was[3] / s[1], was[4] / s[2])
      fit!(v, s)
    else
      middle = (v.at[1] + was[3] / 2v.zoom, v.at[2] + was[4] / 2v.zoom)
      v.zoom = max(v.zoom * v.box[3] / was[3], fit_zoom(v, s))
      v.at = (middle[1] - v.box[3] / 2v.zoom, middle[2] - v.box[4] / 2v.zoom)
      hold!(v, s)
    end
  end
  lookup!(v)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    draw_plan(ctx, v, s)
    draw_shapes(ctx, v)
  end
end

"""
True when the mouse is over something on the plan that a click selects: a
mark, a line, an outline or the inside of one. The window asks for the cursor
before the plan sees the mouse move, so this reads where the window's mouse is.
"""
over_shape(v::TakeoffView) = begin
  w = window_of(v)
  (w === nothing || v.zoom <= 0) && return false
  p = page_point(v, num(w.mouse[1]), num(w.mouse[2]))
  Plans.shape(v.data, v.data.page, p, REACH / v.zoom) !== nothing
end

# With the select tool, a hand over something that a click selects, and an arrow over the paper
cursor(a::PlanArea) = begin
  v = a.of
  plan_size(v) === nothing || over_done(v) ? :hand : v.tool == :select ? (v.grab !== nothing || over_shape(v) ? :hand : :arrow) : :crosshair
end

# --- the mouse and the keys on the plan --------------------------------------------------

"The name that a new measure of this kind starts with: Count 1, Length 2"
first_name(v::TakeoffView, kind) = "$(uppercasefirst(string(kind))) $(count(m -> m.kind == kind, v.data.measures) + 1)"
const FIRST_NAME = r"^(Count|Length|Area) \d+$"
const KIND_WORDS = Dict(:count => "a count", :length => "a length", :area => "an area")

"What an item's price is for, in words: each one, each m, each m²"
sold_by(row) = begin
  unit = string(something(get(row, "unit", nothing), ""))
  unit in ("", "Piece", "each") ? "each one" : "each " * unit
end

"Make a measure that has nothing drawn yet one of `kind`. A name that it was made with follows its kind."
kind!(v::TakeoffView, m, kind::Symbol) = begin
  (m.kind == kind || !isempty(m.shapes)) && return m
  occursin(FIRST_NAME, m.name) && (m.name = first_name(v, kind))
  m.kind = kind
  m.unit = ""
  m
end

"The measure of this kind that the tools draw for. If the current measure is of another kind, a new one starts."
measure!(v::TakeoffView, kind::Symbol) = begin
  ms = v.data.measures
  1 <= v.current <= length(ms) && ms[v.current].kind == kind && return ms[v.current]
  push!(ms, Plans.Measure(kind, first_name(v, kind)))
  v.current = length(ms)
  last(ms)
end

"End the line or the outline that's being drawn. One with too few corners is dropped."
finish_shape!(v::TakeoffView) = begin
  kind = v.tool
  if kind in (:length, :area) && length(v.draft) >= (kind == :length ? 2 : 3)
    push!(measure!(v, kind).shapes, Plans.Shape(v.data.page, copy(v.draft)))
    empty!(v.draft)
    commit!(v)
  end
  empty!(v.draft)
  handled
end

"""
Choose a tool. A tool that measures draws for the measure that's chosen in the
list. If that measure is of another kind, it becomes the tool's kind when
nothing is drawn for it yet and it has no item. If not, the tool draws for the
last measure of its kind.
"""
tool!(v::TakeoffView, tool::Symbol) = begin
  v.tool = tool
  empty!(v.draft)
  v.picked = nothing
  ms = v.data.measures
  if tool in Plans.KINDS && !(1 <= v.current <= length(ms) && ms[v.current].kind == tool)
    m = 1 <= v.current <= length(ms) ? ms[v.current] : nothing
    if m !== nothing && isempty(m.shapes) && isempty(m.item)
      kind!(v, m, tool)
      commit!(v)
    else
      v.current = something(findlast(m -> m.kind == tool, ms), 0)
    end
  end
  handled
end

"A drag ended. A corner that moved is written down."
drop!(v::TakeoffView) = begin
  g = v.grab
  v.grab = nothing
  g !== nothing && g[1] == :corner && g[3] && commit!(v)
  v
end

"Take away what's selected on the plan: a mark, a corner, or a whole line or outline"
remove_picked!(v::TakeoffView) = begin
  p = v.picked
  p === nothing && return handled
  m = v.data.measures[p[1]]
  if length(p) == 3
    Plans.remove!(m, p[2], p[3])
  else
    deleteat!(m.shapes, p[2])
  end
  v.picked = nothing
  commit!(v)
  handled
end

onkey(a::PlanArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  focus(a)
  plan_size(v) === nothing && return choose_plan!(v, w)
  v.zoom > 0 || return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  # A click on the Done button ends what's being drawn, and puts no corner down
  on_done(v, x, y) && return (hide_tooltip!(w); finish_shape!(v))
  p = page_point(v, x, y)
  at, cx, cy = v.clicked
  twice = time() - at < 0.35 && hypot(x - cx, y - cy) < 4
  v.clicked = (time(), x, y)
  reach = REACH / v.zoom
  page = v.data.page
  if v.tool == :count
    Plans.mark!(measure!(v, :count), page, p)
    commit!(v)
  elseif v.tool in (:length, :area)
    closes = v.tool == :area && length(v.draft) >= 3 && hypot(v.draft[1][1] - p[1], v.draft[1][2] - p[2]) <= reach
    # The first click of two put the last corner down
    (twice && !isempty(v.draft)) || closes ? finish_shape!(v) : push!(v.draft, p)
  elseif v.tool == :scale
    length(v.draft) >= 2 && empty!(v.draft)
    push!(v.draft, p)
    length(v.draft) == 2 && ask!(v, (:length, v.draft[1], v.draft[2]), "", "metres")
  else
    corner = Plans.corner(v.data, page, p, reach)
    if corner !== nothing
      v.picked, v.current = corner, corner[1]
      v.grab = (:corner, corner, false)
    else
      v.picked = Plans.shape(v.data, page, p, reach)
      v.picked === nothing || (v.current = v.picked[1])
      v.grab = (:pan, (x, y), v.at)
    end
  end
  handled
end

# A right-click ends what's being drawn
onkey(a::PlanArea, ::KeyPress{Keys.mouse_right}) = isempty(a.of.draft) ? nothing : finish_shape!(a.of)

onmouse(a::PlanArea, ev::MouseMove) = begin
  v = a.of
  v.zoom > 0 || return nothing
  x, y = num(ev.position[1]), num(ev.position[2])
  v.mouse = page_point(v, x, y)
  # The Done button says what it does, and the key that does the same
  on_done(v, x, y) && show_tooltip!(ev.window, tip_label(done_tip(v)), px.(done_box(v))..., placement=:bottom, gap=6px)
  g = v.grab
  g === nothing && return handled
  Keys.mouse_left in ev.window.keys || (drop!(v); return handled)
  if g[1] == :pan
    (x0, y0), at = g[2], g[3]
    v.at = (at[1] - (x - x0) / v.zoom, at[2] - (y - y0) / v.zoom)
    moved!(v)
  else
    i, j, k = g[2]
    v.data.measures[i].shapes[j].points[k] = v.mouse
    v.grab = (:corner, g[2], true)
  end
  handled   # the drag is the plan's, so the page's text doesn't select
end

# Scrolling with ⌘ held makes the plan bigger or smaller, round the mouse. Once a click has given the
# plan the keyboard, scrolling without ⌘ moves the plan. Before that, it scrolls the page that the plan is on.
# A plan that fills the window has no page to scroll, so scrolling always moves it.
onscroll(a::PlanArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  v.zoom > 0 || return nothing
  Keys.cmd in w.keys && return zoom_plan!(v, exp(num(ev.delta[2]) / 10), num(w.mouse[1]), num(w.mouse[2]))
  (w.focus === a || v.full) || return nothing
  v.at = (v.at[1] - 30num(ev.delta[1]) / v.zoom, v.at[2] - 30num(ev.delta[2]) / v.zoom)
  moved!(v)
  handled
end

# Two fingers that move apart or together on the trackpad make the plan bigger or smaller, round the mouse
onpinch(a::PlanArea, ev::Pinch) = begin
  v, w = a.of, ev.window
  v.zoom > 0 || return nothing
  zoom_plan!(v, ev.scale, num(w.mouse[1]), num(w.mouse[2]))
end

onkey(a::PlanArea, ::KeyPress{Keys.enter}) = finish_shape!(a.of)
onkey(a::PlanArea, ::KeyPress{Keys.escape}) = begin
  v = a.of
  # Esc drops what's half drawn, then puts the arrow back, then puts a takeoff that fills the window
  # back in the page, then gives the keyboard back to the text
  isempty(v.draft) || return (empty!(v.draft); handled)
  v.tool == :select ? (v.full ? full!(v, false) : nothing) : tool!(v, :select)
end
onkey(a::PlanArea, ::KeyPress{K}) where K = begin
  v = a.of
  if K in (Keys.backspace, Keys.delete)
    # While something is being drawn, Delete takes its last corner back
    return isempty(v.draft) ? remove_picked!(v) : (pop!(v.draft); handled)
  elseif K == Keys.z && held(a, Keys.cmd)
    b = editor(v).buf
    held(a, Keys.shft) ? redo!(b) : undo!(b)
    return handled
  end
  nothing
end

ontype(a::PlanArea, ev::Typed) = begin
  Keys.cmd in ev.window.keys && return nothing
  i = findfirst(((_, (_, _, letter)),) -> letter == lowercase(ev.char), PLAN_TOOLS)
  i === nothing ? nothing : tool!(a.of, PLAN_TOOLS[i][1])
end

# --- the buttons -------------------------------------------------------------------------

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::TakeoffView, key, action; icon="", words="", tip="", off=false) = begin
  b = part!(() -> PlanButton(of=v), v, (:button, key))
  b.action, b.icon, b.words, b.tip, b.off = action, icon, words, tip, off
  b
end

describe(b::PlanButton) = begin
  v = b.of
  ishovered(b) || (b.quiet = false)
  on = b.action isa Tuple && b.action[1] == :tool && v.tool == b.action[2]
  colour = b.off ? colours.faint : on ? colours.accent : colours.dim
  Box(height(26px), padding(7px, 0px), radius(6px), Alignment.Center, name="Button",
      background(on ? colours.active : ishovered(b) && !b.off ? colours.hover : clear),
    Row(Alignment.Center, child_gap=5px,
      (isempty(b.icon) ? () : (Icon(b.icon, size=14px, color=colour),))...,
      (isempty(b.words) ? () : (label(b.words, 12px, color=b.off ? colours.faint : colours.ink),))...))
end

cursor(b::PlanButton) = b.off ? :arrow : :hand

draw(ctx, size, ui::ConcreteRect, b::PlanButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::PlanButton, ev::MouseMove) = begin
  (b.quiet || isempty(b.tip)) && return
  show_tooltip!(ev.window, tip_label(b.tip), b.rect..., placement=:bottom, gap=6px)
end

onkey(b::PlanButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  b.off ? handled : act!(b.of, b.action, ev.window)
end

"Make the takeoff fill the window, or put it back in the page"
full!(v::TakeoffView, on::Bool) = begin
  e = editor(v)
  # One takeoff or schedule at a time fills the window
  on && foreach(node -> node isa Union{TakeoffView,ScheduleView} && (node.full = false), values(e.nodes))
  v.full = on
  v.pinned = e.scroll.offset
  focus(part!(() -> PlanArea(of=v), v, :area))
  handled
end

"The takeoff of the page that fills the window, or nothing"
full_takeoff(e) = begin
  for (key, node) in e.nodes
    node isa TakeoffView && node.full && key[2] == e.buf.path && return node
  end
  nothing
end

"The takeoff or the schedule of the page that fills the window, or nothing"
full_block(e) = begin
  for (key, node) in e.nodes
    node isa Union{TakeoffView,ScheduleView} && node.full && key[2] == e.buf.path && return node
  end
  nothing
end

"The takeoff or the schedule that fills the window, over the page and the sidebar and under the top bar"
takeoff_over(e) = begin
  v = full_block(e)
  v === nothing ? () : (Box(width(grow=grow), height(grow=grow), padding(TOPBAR_H, 0px, 0px, 0px), background(colours.bg), geometry(v)),)
end

"Do what a button of a takeoff does"
act!(v::TakeoffView, action, w) = begin
  settle_asking!(v)
  a = action isa Tuple ? action[1] : action
  t = v.data
  if a == :tool
    tool!(v, action[2])
  elseif a == :page
    page!(v, action[2])
  elseif a == :zoom
    zoom_plan!(v, action[2], v.box[1] + v.box[3] / 2, v.box[2] + v.box[4] / 2)
  elseif a == :fit
    v.zoom = 0.0
  elseif a == :full
    full!(v, !v.full)
  elseif a == :scale
    s = Plans.scale(t, t.page)
    ask!(v, (:scale,), s === nothing ? "1:100" : Plans.scale_text(s))
  elseif a == :choose
    choose_plan!(v, w)
  elseif a == :add
    # It starts as what the tool in use measures, or as a count. Its item's unit, or the next tool, can change that.
    kind = v.tool in Plans.KINDS ? v.tool : :count
    empty!(v.filters)   # a search of the table could hide the new measure
    push!(t.measures, Plans.Measure(kind, first_name(v, kind)))
    v.current = length(t.measures)
    tool!(v, kind)
    commit!(v)
    # The item comes first. The measure takes its name, and its unit says what the measure is.
    Centient.available() && ask!(v, (:item, v.current))
  elseif a == :delete && action[2] <= length(t.measures)
    deleteat!(t.measures, action[2])
    v.current = v.current == action[2] ? 0 : v.current > action[2] ? v.current - 1 : v.current
    v.picked = nothing
    commit!(v)
  elseif a == :customer
    Centient.available() ? ask!(v, (:customer,), "", "Search Centient's contacts") :
                           ask!(v, (:customer,), t.customer, "The customer's name")
  elseif a == :quote
    make_quote!(v)
  end
  handled
end

# --- the list of measures ----------------------------------------------------------------

"The text field in a box, where the thing that it changes was"
field(v::TakeoffView, wide=width(grow=grow)) =
  Box(wide, height(24px), padding(6px, 0px), radius(5px), border(1px, :solid, colours.accent), background(colours.bg), plan_input(v))

"The mark beside a measure's name, in its colour: a dot for a count, a line for a length, a square for an area"
swatch(kind::Symbol, colour) =
  Box(width(14px), height(14px), Alignment.Center,
    kind == :count ? Box(width(10px), height(10px), radius(5px), background(colour)) :
    kind == :length ? Box(width(14px), height(3px), radius(1.5px), background(colour)) :
                      Box(width(11px), height(11px), radius(2px), background(RGBA(colour, 0.3)), border(1.5px, :solid, colour)))

"A price as a row of the list shows it: \$22.00 / m, or \$5.97 each"
price_text(row) = begin
  unit = string(something(get(row, "unit", nothing), ""))
  dollars(row["price"]) * (unit in ("", "Piece", "each") ? " each" : " / " * unit)
end

"""
`s` cut short with … so that it's no wider than `wide` at `size`. It's all of
`s` when it fits, and when there's no width to fit it to yet.
"""
elide(s::AbstractString, size, wide) = begin
  face = Face(SANS, "", size, colours.ink, false)
  (wide <= 0px || measure(face, s) <= wide) && return String(s)
  # The most letters that fit with the … after them
  cs = collect(s)
  lo, hi = 0, length(cs)
  while lo < hi
    mid = (lo + hi + 1) ÷ 2
    measure(face, rstrip(String(cs[1:mid])) * "…") <= wide ? (lo = mid) : (hi = mid - 1)
  end
  rstrip(String(cs[1:lo])) * "…"
end

"True when measure `m` waits for an item: it has none, and Centient is here to choose one from"
wants_item(m) = isempty(m.item) && Centient.available()

"""
What the table calls measure `m`. It's the name of its item. With no item, or
one that Centient hasn't told of, it's the name that the measure has in the
block. A measure that waits for an item, with the name it was made with, has
none.
"""
item_name(v::TakeoffView, m) = begin
  row = known(v, m.item)
  row === nothing || return string(row["name"])
  wants_item(m) && occursin(FIRST_NAME, m.name) ? "" : isempty(m.name) ? m.item : m.name
end

"The words `shown`, which start the words of `parts` and may end with …, as a text for each part in its colour"
runs(shown::AbstractString, parts) = begin
  cs, at, out = collect(shown), 0, Any[]
  for (s, colour) in parts
    n = min(length(s), length(cs) - at)
    n > 0 || break
    push!(out, label(String(cs[at+1:at+n]), 13px, color=colour))
    at += n
  end
  out
end

describe(c::MeasureCell) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return Box(width(0px))
  m = v.data.measures[i]
  wide = c.what == :extra ? fixed(52px) : width(grow=grow)
  c.full = ""
  # The item's cell holds the field for the item, and the field for the name on a Mac with no Centient
  a = v.asking
  a !== nothing && a[1] in (c.what == :item ? (:item, :name) : (:extra,)) && a[2] == i && return field(v, wide)
  # The words are in a row with no width of its own, so long words take no room from the cells beside them.
  # They're cut short with … to fit the width the cell had when it was last drawn. Each of `parts` is words and their colour.
  words(parts...) = begin
    s = join(first.(parts))
    shown = elide(s, 13px, c.rect[3])
    shown == s || (c.full = s)
    Row(wide, height(grow=grow), Alignment.Center, clip=true, Row(fixed(0px), runs(shown, parts)...))
  end
  c.what == :extra && return words((m.extra > 0 ? "+" * Plans.number(100m.extra) * "%" : "+0%", m.extra > 0 ? colours.ink : colours.faint))
  name, row = item_name(v, m), known(v, m.item)
  # An item that Centient knows shows where it's from after its name
  row === nothing || return words((name, colours.ink), ("  ·  " * string(row["source"]), colours.dim))
  wants_item(m) || return words((name, colours.ink))
  isempty(name) ? words(("Choose an item", colours.accent)) : words((name, colours.ink), ("  ·  ", colours.dim), ("Choose an item", colours.accent))
end

cursor(::MeasureCell) = :hand

draw(ctx, size, ui::ConcreteRect, c::MeasureCell) = begin
  # A new width cuts the words short in another place, so the cell is described again
  ui.width == c.rect[3] || redraw_in!(c.of, 0)
  c.rect = (ui.left, ui.top, ui.width, ui.height)
  nothing
end

# Words that are cut short show whole under the cell
onmouse(c::MeasureCell, ev::MouseMove) = isempty(c.full) ? nothing :
  show_tooltip!(ev.window, tip_label(c.full), c.rect..., placement=:bottom, gap=6px)

onkey(c::MeasureCell, ::KeyPress{Keys.mouse_left}) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return handled
  m = v.data.measures[i]
  # The first click on a row chooses it. A click on the row that's chosen changes the part that's clicked.
  # A measure that waits for an item is chosen and asks for its item at one click.
  chosen = v.current == i
  chosen || choose_measure!(v, i)
  (chosen || (c.what == :item && wants_item(m))) || return handled
  c.what == :extra && return ask!(v, (:extra, i), m.extra > 0 ? Plans.number(100m.extra) : "", "%")
  # With no Centient there's no catalogue to choose from, so the click changes the measure's name
  Centient.available() ? ask!(v, (:item, i)) : ask!(v, (:name, i), m.name)
end

describe(r::MeasureRow) = begin
  v, i = r.of, r.i
  i <= length(v.data.measures) || return Box(height(0px))
  m = v.data.measures[i]
  cell(what) = part!(() -> MeasureCell(of=v, i=i, what=what), v, (:cell, i, what))
  amount = Plans.amount(v.data, m)
  row = known(v, m.item)
  # A Text on its own would take all of the row, so each is in a box that the row puts at its right
  # It's as tall as the row, so that what cuts a long text off at the side doesn't cut the tail of a comma or a g
  right(wide, s, colour) = Row(fixed(wide), height(grow=grow), Alignment.Center, justify=Alignment.End, clip=true, Box(label(s, 13px, color=colour)))
  back = background(v.current == i ? colours.active : ishovered(r) ? colours.hover : clear)
  # The first row has a line that doesn't show, so that its words are where the other rows' are
  line = (border(1px, :solid, !isempty(v.order) && v.order[1] == i ? clear : colours.line)[:top],)
  size = part!(() -> AmountCell(of=v, i=i), v, (:amount, i))
  cost = right(88px, row === nothing || amount === nothing ? "" : dollars(cost_of(m, amount, row)), colours.ink)
  remove = button!(v, (:delete, i), (:delete, i), icon="x-lg", tip="Remove this measure")
  # The panel beside a plan that fills the window is narrow, so a measure has two lines there
  v.beside && return Column(width(grow=grow), Alignment.Start, padding(10px, 4px), name="Measure", back, line...,
    Row(width(grow=grow), height(26px), child_gap=8px, Alignment.Center, swatch(m.kind, hue(i)), cell(:item), size),
    Row(width(grow=grow), height(26px), child_gap=8px, Alignment.Center, Box(width(14px)), cell(:extra), Box(width(grow=grow)), cost, remove))
  Row(width(grow=grow), height(32px), padding(10px, 0px), child_gap=10px, Alignment.Center, name="Measure", back, line...,
    swatch(m.kind, hue(i)), cell(:item), cell(:extra), size,
    # A narrow block has no room for the price of one, so it shows what the measure comes to and no more
    # The price is for one of the measure's unit, so it needs no unit after it. One that the measure can't be in says its own.
    (has_price(v) ? (right(96px, row === nothing ? "" : (p = unit_price(m, row); p === nothing ? price_text(row) : dollars(p)), colours.dim),) : ())...,
    cost, remove)
end

cursor(::MeasureRow) = :hand

"Make measure `i` the one that the tools draw for, and choose the tool of its kind"
choose_measure!(v::TakeoffView, i::Int) = begin
  i <= length(v.data.measures) || return handled
  v.current = i
  tool!(v, v.data.measures[i].kind)
end

onkey(r::MeasureRow, ::KeyPress{Keys.mouse_left}) = choose_measure!(r.of, r.i)

# --- the units of a measure --------------------------------------------------------------
#
# A click on the unit after a measure's amount shows the list of units that it
# can be in, as Centient's unit picker does: each unit's name, and the short
# form that goes after an amount at the right. A field at the top of the list
# searches it. The up and down arrows pick a unit, and so does the mouse. Return or a
# click takes it. Esc, or a click somewhere else, closes the list and changes
# nothing.

const UNIT_KEY = :takeoff_units
const AMOUNT_W = 96px    # how wide the column of amounts is
const MOST_UNITS = 8     # the units that the list shows before it scrolls

"""
The units that measure `i` can be in. One with nothing drawn and no item can be
a count, a length or an area, so it can take a unit of each kind. Any other
keeps its kind.
"""
units_for(v::TakeoffView, i::Int) = begin
  i <= length(v.data.measures) || return String[]
  m = v.data.measures[i]
  isempty(m.shapes) && isempty(m.item) ? reduce(vcat, collect(Plans.KIND_UNITS)) : copy(getfield(Plans.KIND_UNITS, m.kind))
end

"Write a unit as a keyboard can: m^2 or m2 for m². What's typed is folded the other way, so that each finds the other."
fold_unit(s::AbstractString) = begin
  s = replace(lowercase(s), "^2" => "²", "^3" => "³")
  replace(s, r"([a-z]+)([23])(?!\d)" => m -> m[1:end-1] * (m[end] == '2' ? "²" : "³"))
end

"Other words that a unit is typed as"
const UNIT_EXTRAS = Dict("hectare" => ["ha", "hectares"], "ft" => ["feet"], "inch" => ["in", "inches"],
                         "ft²" => ["sq ft", "square feet"], "m" => ["meter"], "m²" => ["sqm", "square meter"], "Piece" => ["each"])

"True when `words` find `unit`: they're in its name, its short form, or the name that Centient gives it"
unit_matches(unit::AbstractString, words::AbstractString) = begin
  isempty(words) && return true
  q = fold_unit(words)
  any(h -> occursin(q, fold_unit(h)), [Plans.UNIT_WORDS[unit], Plans.unit_short(unit), unit, get(UNIT_EXTRAS, unit, String[])...])
end

"True when `words` are a name of `unit` and not only part of one: metre for m, and not for mm"
names_unit(unit::AbstractString, words::AbstractString) =
  (q = fold_unit(words); any(h -> fold_unit(h) == q, [Plans.UNIT_WORDS[unit], Plans.unit_short(unit), unit, get(UNIT_EXTRAS, unit, String[])...]))

"The unit word of the amount `c`. It belongs to the amount, so the mouse over it is over the amount too."
unit_word(c::AmountCell) = begin
  c.unit === nothing && (c.unit = UnitWord(of=c); setfield!(c.unit, :parent, c))
  c.unit
end

describe(c::AmountCell) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return Box(width(0px))
  m = v.data.measures[i]
  amount = Plans.amount(v.data, m)
  # It's as tall as the row, so that what cuts a long amount off at the side doesn't cut the tail of a comma or a g
  cell(parts...) = Row(fixed(AMOUNT_W), height(grow=grow), Alignment.Center, justify=Alignment.End, clip=true, name="Amount", parts...)
  amount === nothing && return cell(Box(label("No scale", 13px, color=colours.accent)))
  unit = Plans.unit(m)
  number = Box(label(Plans.amount_number(Plans.in_unit(amount, unit)), 13px, color=colours.ink))
  # The unit is there to click when the measure can be in another. A count that can only be in pieces is a number.
  length(units_for(v, i)) > 1 ? cell(number, unit_word(c)) : cell(Box(label(Plans.shown(m, amount), 13px, color=colours.ink)))
end

cursor(::AmountCell) = :hand
# A click on the number chooses the measure, as a click on the rest of its row does
onkey(c::AmountCell, ::KeyPress{Keys.mouse_left}) = choose_measure!(c.of, c.i)

describe(w::UnitWord) = begin
  c = w.of
  v = c.of
  c.i <= length(v.data.measures) || return Box(width(0px))
  unit = Plans.unit(v.data.measures[c.i])
  lit = ishovered(w) || v.asking == (:unit, c.i)
  # A foot and an inch are marks right after the number. Another unit has a space before it, and the space is the unit's to click.
  Row(height(grow=grow), padding(0px, 0px, 0px, unit in ("inch", "ft") ? 1px : 4px), Alignment.Center,
    label(Plans.unit_short(unit), 13px, color=lit ? colours.accent : colours.ink))
end

cursor(::UnitWord) = :hand
onkey(w::UnitWord, ev::KeyPress{Keys.mouse_left}) = open_units!(w.of, ev.window)

"Show the list of the units that the measure of the amount `c` can be in, under its unit"
open_units!(c::AmountCell, window) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return handled
  ask!(v, (:unit, i), "", "Filter…")
  v.query = ""   # so that the first frame keeps the unit that's picked
  v.rows = Any[units_for(v, i)...]
  v.pick = something(findfirst(==(Plans.unit(v.data.measures[i])), v.rows), 1)
  menu = UnitMenu(of=v, i=i)
  v.parts[:unit_menu] = menu
  popup!(window, menu, anchor=unit_word(c), placement=:bottom, gap=9px, width=230px, key=UNIT_KEY,
         onclose=() -> settle_asking!(v), theme=component_theme(editor(v).zoom))
  handled
end

"""
Put measure `i` in `unit`. A unit of another kind makes a measure with nothing
drawn and no item that kind. The tool for it is ready to draw.
"""
unit!(v::TakeoffView, i::Int, unit::AbstractString) = begin
  stop_asking!(v)
  i <= length(v.data.measures) || return handled
  m = v.data.measures[i]
  kind = Plans.unit_kind(unit)
  kind === nothing && return handled
  if kind != m.kind
    (isempty(m.shapes) && isempty(m.item)) || return handled
    kind!(v, m, kind)
  end
  Plans.unit!(m, unit)
  commit!(v)
  v.current = i
  tool!(v, m.kind)
end

describe(r::UnitRow) = begin
  v, c = r.of, found_colours()
  r.k <= length(v.rows) || return Box(height(0px))
  unit = v.rows[r.k]
  a = v.asking
  on = a !== nothing && a[1] == :unit && a[2] <= length(v.data.measures) && Plans.unit(v.data.measures[a[2]]) == unit
  short = Plans.unit_short(unit)
  name = Plans.UNIT_WORDS[unit]
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(v.pick == r.k ? c.pick : c.frame),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label(name, 13px, color=c.ink, weight=on ? "Semibold" : "")),
    # The short form shows when it isn't the name again
    (lowercase(short) == lowercase(name) ? () : (Box(label(short, 12px, color=c.dim)),))...)
end

cursor(::UnitRow) = :hand
onkey(r::UnitRow, ::KeyPress{Keys.mouse_left}) = begin
  v, a = r.of, r.of.asking
  a !== nothing && a[1] == :unit && r.k <= length(v.rows) ? unit!(v, a[2], v.rows[r.k]) : handled
end
# The mouse picks the unit that it's over, as the arrow keys do
onmouse(r::UnitRow, ::MouseMove) = begin
  v = r.of
  v.pick = r.k
  menu = get(v.parts, :unit_menu, nothing)
  menu === nothing || (menu.pick = r.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(m::UnitMenu) = begin
  v, c = m.of, found_colours()
  n, high = length(v.rows), 28px
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :unit_scroll)
  body = if n == 0
    Row(width(grow=grow), height(high), padding(8px, 0px), Alignment.Center, label("No unit has that name", 12px, color=c.dim))
  else
    # Half a row at the bottom says that the list goes on
    scroll.height = height(n <= MOST_UNITS ? n * high : MOST_UNITS * high - high / 2)
    m.pick == v.pick || (m.pick = v.pick; scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [part!(() -> UnitRow(of=v, k=k), v, (:unit_row, k)) for k in 1:n]...))
  end
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Units",
    Column(width(grow=grow), Alignment.Start, child_gap=4px,
      Box(width(grow=grow), padding(2px, 2px),
        Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), plan_input(v))),
      body))
end

placed!(m::UnitMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::UnitMenu) = caret(ctx, ui, m.side, rect(unit_word(part!(() -> AmountCell(of=m.of, i=m.i), m.of, (:amount, m.i)))))

# The list sees a key before its field does. The arrows pick a unit, Return takes it, and Esc closes the list.
onkey(m::UnitMenu, ::KeyPress{Keys.enter}) = answer!(m.of)
onkey(m::UnitMenu, ::KeyPress{Keys.escape}) = stop_asking!(m.of)
onkey(m::UnitMenu, ::KeyPress{Keys.down}) = (v = m.of; v.pick = min(v.pick + 1, max(1, length(v.rows))); handled)
onkey(m::UnitMenu, ::KeyPress{Keys.up}) = (v = m.of; v.pick = max(v.pick - 1, 1); handled)

# --- the list that a search shows --------------------------------------------------------
#
# What a search finds shows in a list that floats beside the text field. It
# looks like the lists in Centient's own forms: a cream box with an arrow that
# points at the field, and in it a card with a line for each thing found. The
# up and down arrows pick a line, and so does the mouse. Return or a click
# takes it. Esc closes the list, and so does a click somewhere else.

const FOUND_KEY = :takeoff_found
"The colours of the list: Centient's cream in a light page, and the page's own in a dark one"
found_colours() = dark_page() ?
  (frame=colours.float, pick=colours.active, ink=colours.ink, dim=colours.dim, line=colorant"rgb(86,86,94)", rule=colours.line) :
  (frame=colorant"rgb(233,224,202)", pick=colorant"rgb(224,212,185)", ink=colorant"rgb(27,23,16)", dim=colorant"rgb(110,104,88)",
   line=colorant"rgb(176,164,136)", rule=colorant"rgb(221,212,192)")

# The search for an item looks in one catalogue at a time, as Centient's own
# item field does. It starts in the business's own items. ⌥ in an empty field,
# or a click on the foot of the list, shows the suppliers whose catalogues
# Centient holds. A supplier chosen there opens its catalogue, and the search
# goes on in that. ⌥ again goes back to the suppliers, and from the suppliers
# to the business's own items. The next search starts where an item was last
# chosen from.

"""
The catalogue that the search for an item looks in: `(:own,)` for the
business's own items, `(:suppliers,)` for the list of suppliers to choose a
catalogue from, or `(:catalogue, slug, name)` for one supplier's.
"""
const ITEM_FROM = Ref{Any}((:own,))

"Look in another catalogue. The words that were typed go, and a search of the new one starts now."
browse!(v::TakeoffView, from) = begin
  ITEM_FROM[] = from
  i = plan_input(v)
  i.text = ""
  i.anchor, i.cursor = 0, 0
  v.rows, v.search, v.pick = Any[], nothing, 1
  v.query, v.typed = "", time() - 1
  handled
end

"Go from the business's own items to the list of suppliers, and from the list or a supplier's catalogue back"
toggle_catalogue!(v::TakeoffView) = browse!(v, ITEM_FROM[][1] == :catalogue ? (:suppliers,) : ITEM_FROM[][1] == :suppliers ? (:own,) : (:suppliers,))

"What the foot of the list says of the catalogue that it shows"
catalogue_words() = (from = ITEM_FROM[]; from[1] == :own ? "Our catalogue" : from[1] == :suppliers ? "Pick a catalogue" : from[3])

"True when the list shows suppliers to choose from, and false when it shows items"
lists_suppliers(v::TakeoffView) = v.asking !== nothing && v.asking[1] == :item && ITEM_FROM[][1] == :suppliers

"How tall a line of the list is. An item has a second line under its name. A contact or a supplier has its name and no more."
found_h(v::TakeoffView) = v.asking == (:customer,) || lists_suppliers(v) ? 34px : 50px

"Show the list of what the search finds, beside the text field"
show_found!(v::TakeoffView) = begin
  w = window_of(v)
  w === nothing && return
  e = editor(v)
  wide = min(v.asking == (:customer,) ? 340px : 460px, window_size(e)[1] - 16px)
  list = FoundList(of=v)
  v.parts[:found_list] = list
  # The keys stay with the text field, and a click outside the list is the app's, as it is with no list
  list.popup = popup!(w, list, anchor=plan_input(v), placement=:bottom, gap=FOUND_GAP, width=wide, key=FOUND_KEY, modal=false,
                      onclose=() -> stop_asking!(v), theme=component_theme(e.zoom))
end

const FOUND_GAP = 9px   # between the text field and the list, with the list's arrow in it

"""
Choose the side of the text field that the list is on, once for each time it
opens. The list goes under the field when the longest list fits there, and
if not, on the side with more room. A short list, like the one line that shows
while Centient searches, is then on the side that the long list will be on, so
the list doesn't jump from one side to the other.
"""
settle_side!(l::FoundList) = begin
  (l.settled || l.popup === nothing) && return
  v = l.of
  r = rect(plan_input(v))
  r === nothing && return
  item = v.asking !== nothing && v.asking[1] == :item
  # The longest list: its rows, the edges round them, and the foot that names the catalogue
  longest = MOST_FOUND * (item ? 50px : 34px) + 14px + (item ? 28px : 0px)
  over, under = r.top - FOUND_GAP, window_size(editor(v))[2] - r.top - r.height - FOUND_GAP
  l.popup.placement = under >= longest || under >= over ? :bottom : :top
  l.settled = true
end

placed!(l::FoundList, side) = (l.side = side; nothing)

describe(r::FoundRow) = begin
  v = r.of
  r.k <= length(v.rows) || return Box(height(0px))
  row = v.rows[r.k]
  c = found_colours()
  picked = v.pick == r.k
  ref = string(get(row, "ref", ""))
  # Under an item of the business is what it says of it. Under a supplier's product is the supplier's code for it.
  under = isempty(ref) ? "" : startswith(ref, "item ") ? string(something(get(row, "description", nothing), "")) : String(last(split(ref, ' ', limit=2)))
  # At the right is an item's price, and how many products a supplier's catalogue has
  right = !isempty(ref) ? price_text(row) : haskey(row, "slug") ? commas(round(Int, get(row, "products", 0))) * " products" : ""
  # A thin line parts two rows, but not the picked row from the ones beside it. A row with no line has one in its
  # own colour, so that its words don't move by the line's height when the pick comes to it or leaves it.
  back = picked ? c.pick : c.frame
  Row(width(grow=grow), height(found_h(v)), padding(12px, 0px), child_gap=10px, Alignment.Center, background(back),
      border(1px, :solid, r.k == 1 || picked || v.pick == r.k - 1 ? back : c.rule)[:top],
    # As tall as the row, so that what cuts a long name off at the side doesn't cut the tails of its g, p and y
    Column(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.Center, child_gap=6px, clip=true,
      label(string(row["name"]), 13px, color=c.ink),
      (isempty(under) ? () : (label(under, 11px, color=c.dim),))...),
    (isempty(right) ? () : (Box(label(right, 12px, color=c.dim)),))...)
end

cursor(::FoundRow) = :hand
onkey(r::FoundRow, ::KeyPress{Keys.mouse_left}) = choose_row!(r.of, r.k)
# The mouse picks the row that it's over, as the arrow keys do
onmouse(r::FoundRow, ::MouseMove) = begin
  v = r.of
  v.pick = r.k
  list = get(v.parts, :found_list, nothing)
  list === nothing || (list.pick = r.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(l::FoundList) = begin
  v = l.of
  settle_side!(l)
  c = found_colours()
  high, n = found_h(v), length(v.rows)
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :found_scroll)
  l.rows === v.rows || (l.rows = v.rows; l.pick = 0; scroll.offset = 0px)
  item = v.asking !== nothing && v.asking[1] == :item
  body = if n == 0
    words = v.search !== nothing || v.typed > 0 ? "Searching Centient…" :
            !isempty(v.query) && v.query != "\0" ? "Centient has nothing that matches" :
            lists_suppliers(v) ? "Centient holds no supplier's catalogue" : item ? "Nothing here yet" : "Type to search"
    Row(width(grow=grow), height(34px), padding(12px, 0px), Alignment.Center, background(c.frame), label(words, 12px, color=c.dim))
  else
    # Half a row at the bottom says that the list goes on
    scroll.height = height(min(n * high, MOST_FOUND * high - high / 2))
    l.pick == v.pick || (l.pick = v.pick; scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [part!(() -> FoundRow(of=v, k=k), v, (:found, k)) for k in 1:n]...))
  end
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Found",
    Column(width(grow=grow), Alignment.Start, child_gap=4px,
      Column(width(grow=grow), Alignment.Start, radius(5px), border(1px, :solid, c.line), background(c.frame), clip=true, body),
      (item ? (part!(() -> CatalogueFoot(of=v), v, :catalogue_foot),) : ())...))
end

# The foot of the list of items says which catalogue it shows. A click on it does what ⌥ does.
describe(f::CatalogueFoot) = begin
  c = found_colours()
  Row(width(grow=grow), height(24px), padding(8px, 0px), radius(5px), child_gap=8px, Alignment.Center, background(ishovered(f) ? c.pick : c.frame),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label(catalogue_words(), 12px, color=c.ink, weight="Semibold")),
    Box(label("⌥ to toggle catalogue", 11px, color=c.dim)))
end
cursor(::CatalogueFoot) = :hand
onmouse(::CatalogueFoot, ::MouseMove) = handled
onkey(f::CatalogueFoot, ::KeyPress{Keys.mouse_left}) = toggle_catalogue!(f.of)

"""
Draw the arrow of a floating box `ui`, on its edge that faces what it's for.
`side` is the side of that thing that the box is on, and `aim` is the thing's
rectangle. The arrow covers the box's border where it joins.
"""
caret(ctx, ui::ConcreteRect, side, aim) = begin
  aim === nothing && return
  c = found_colours()
  left, top, wide, high = num(ui.left), num(ui.top), num(ui.width), num(ui.height)
  x = clamp(num(aim.left + aim.width / 2), left + 16, max(left + 16, left + wide - 16))
  base, tip = side == :top ? (top + high - 1, top + high + 6) : (top + 1, top - 6)
  trace(ctx, [(x - 7, base), (x, tip), (x + 7, base)], c.line, 1; fill=c.frame)
end

draw(ctx, size, ui::ConcreteRect, l::FoundList) = caret(ctx, ui, l.side, rect(plan_input(l.of)))

# --- the columns of the table ------------------------------------------------------------
#
# The headings of the table of measures work as the headings of Centient's
# lists do. A click on a heading of numbers sorts by it: low to high, then high
# to low, then the order that the block is written in. A click on a heading of
# text opens a menu with its two orders and a field that searches the column.
# Return keeps the search, and Esc puts back the one before. A heading whose
# column is searched is in the accent colour. Sorting and searching change what
# the table shows, and nothing in the block or in the quote.

const HEAD_KEY = :takeoff_column
"The columns of the table that sort: the heading of each, and whether it holds text"
const COLUMNS = (item=("Item", true), extra=("Waste", false), amount=("Amount", false), price=("Price", false), cost=("Cost", false))
"What the two orders of a column are called"
order_words(text::Bool) = text ? ("A–Z", "Z–A") : ("Low → High", "High → Low")

"The item of a measure in words, as its column sorts and searches it: what the table calls it, and the catalogue that it's from"
item_words(v::TakeoffView, m) = (row = known(v, m.item); item_name(v, m) * (row === nothing ? "" : "  ·  " * string(row["source"])))

"What measure `i` has in the column `key`, as the thing that the column sorts by"
column_value(v::TakeoffView, i, key) = begin
  m = v.data.measures[i]
  key == :item && return lowercase(item_words(v, m))
  key == :extra && return m.extra
  amount, row = Plans.amount(v.data, m), known(v, m.item)
  key == :amount ? something(amount, -1.0) :
  key == :price  ? (row === nothing ? -1.0 : Float64(something(unit_price(m, row), row["price"]))) :
                   (row === nothing || amount === nothing ? -1.0 : cost_of(m, amount, row))
end

"Search the column `key` for `words`. No words takes its search away."
filter!(v::TakeoffView, key::Symbol, words) = begin
  words = String(strip(words))
  isempty(words) ? delete!(v.filters, key) : (v.filters[key] = words)
  v
end

"The measures that the table shows, in the order that it shows them: those that the searches keep, sorted by the column that's chosen"
shown_measures(v::TakeoffView) = begin
  ms = v.data.measures
  # The item's column is the one that holds text, so a search is of it
  keep = [i for i in eachindex(ms) if all(words -> occursin(lowercase(words), lowercase(item_words(v, ms[i]))), values(v.filters))]
  v.sort === nothing ? keep : sort!(keep, by=i -> column_value(v, i, v.sort[1]), rev=v.sort[2] == :desc)
end

"The heading of the column `key`. `side` is the side of its cell that its words go on, and nothing keeps the side that it has."
head(v::TakeoffView, key::Symbol, side=nothing) = begin
  h = part!(() -> ColumnHead(of=v, key=key), v, (:head, key))
  side === nothing || (h.side = side)
  h
end

"""
The words of the heading of the column `key`. They belong to the heading, so a
click on them goes to it, and the mouse over them is over it.
"""
head_words(v::TakeoffView, key::Symbol) = begin
  h = head(v, key)
  h.words === nothing && (h.words = HeadWords(of=h); setfield!(h.words, :parent, h))
  h.words
end

"The order that a click on a heading of numbers gives next. It's nothing for the order that the block is written in."
next_order(v::TakeoffView, key) = v.sort === nothing || v.sort[1] != key ? :asc : v.sort[2] == :asc ? :desc : nothing

describe(h::ColumnHead) =
  Row(width(grow=grow), height(grow=grow), Alignment.Center, justify=h.side == :end ? Alignment.End : Alignment.Start, name="Heading",
    head_words(h.of, h.key))

describe(w::HeadWords) = begin
  h = w.of
  v = h.of
  words, text = COLUMNS[h.key]
  dir = v.sort !== nothing && v.sort[1] == h.key ? v.sort[2] : nothing
  open = v.asking !== nothing && v.asking[1] == :filter && v.asking[2] == h.key
  lit = ishovered(h) || open
  colour = haskey(v.filters, h.key) ? colours.accent : lit || dir !== nothing ? colours.ink : colours.dim
  # The arrow of the order that it has. With none, the mouse over it shows what a click gives.
  will = text ? :desc : next_order(v, h.key)
  mark = dir !== nothing ? (Icon(dir == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.ink),) :
         lit && will !== nothing ? (Icon(will == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.faint),) : ()
  parts = (label(words, 11px, color=colour), mark...)
  # The arrow goes on the side away from the cell's edge, so that it doesn't push the words when it shows
  Row(height(20px), child_gap=4px, Alignment.Center, (h.side == :start ? parts : reverse(parts))...)
end

cursor(::ColumnHead) = :hand

# A heading of numbers says what a click on it does
onmouse(h::ColumnHead, ev::MouseMove) = begin
  COLUMNS[h.key][2] && return
  will = next_order(h.of, h.key)
  low, high = order_words(false)
  words = will == :asc ? low : will == :desc ? high : "The order they're written in"
  # The tooltip follows the words: the mouse over them shows their arrow, which makes them wider on the next frame
  show_tooltip!(ev.window, tip_label(words), head_words(h.of, h.key), placement=:bottom, gap=6px)
end

onkey(h::ColumnHead, ev::KeyPress{Keys.mouse_left}) = begin
  v = h.of
  hide_tooltip!(ev.window)
  settle_asking!(v)
  COLUMNS[h.key][2] || return (will = next_order(v, h.key); v.sort = will === nothing ? nothing : (h.key, will); handled)
  # The menu's field starts with the column's search, which Esc puts back
  was = get(v.filters, h.key, "")
  ask!(v, (:filter, h.key, was), was, "Contains…")
  menu = ColumnMenu(of=v, key=h.key)
  v.parts[:column_menu] = menu
  # A click outside the menu closes it and keeps what's typed
  popup!(ev.window, menu, anchor=head_words(v, h.key), placement=:bottom, gap=9px, width=210px, key=HEAD_KEY,
         onclose=() -> settle_asking!(v), theme=component_theme(editor(v).zoom))
  handled
end

placed!(m::ColumnMenu, side) = (m.side = side; nothing)

describe(r::SortRow) = begin
  v, c = r.of, found_colours()
  on = v.sort == (r.key, r.dir)
  words = order_words(COLUMNS[r.key][2])[r.dir == :asc ? 1 : 2]
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || ishovered(r) ? c.pick : c.frame),
    Icon(r.dir == :asc ? "chevron-up" : "chevron-down", size=10px, color=on ? c.ink : c.dim),
    label(words, 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::SortRow) = :hand
onmouse(::SortRow, ::MouseMove) = handled
# A click on the order that the table has takes it away
onkey(r::SortRow, ::KeyPress{Keys.mouse_left}) = (v = r.of; v.sort = v.sort == (r.key, r.dir) ? nothing : (r.key, r.dir); handled)

describe(m::ColumnMenu) = begin
  v, c = m.of, found_colours()
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  order(dir) = part!(() -> SortRow(of=v, key=m.key, dir=dir), v, (:sort, m.key, dir))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Column menu",
    Column(width(grow=grow), Alignment.Start,
      section("SORT"), order(:asc), order(:desc),
      Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule))),
      section("FILTER FOR"),
      Box(width(grow=grow), padding(4px, 2px),
        Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), plan_input(v)))))
end

draw(ctx, size, ui::ConcreteRect, m::ColumnMenu) = caret(ctx, ui, m.side, rect(head_words(m.of, m.key)))

# The menu sees a key before its text field does. Return keeps the search, and Esc puts back the one before.
onkey(m::ColumnMenu, ::KeyPress{Keys.enter}) = answer!(m.of)
onkey(m::ColumnMenu, ::KeyPress{Keys.escape}) = begin
  v = m.of
  a = v.asking
  a !== nothing && a[1] == :filter && filter!(v, a[2], a[3])
  stop_asking!(v)
end

# --- the whole block ---------------------------------------------------------------------

"A thin line between two groups of buttons"
rule() = Box(width(9px), height(16px), Alignment.Center, Box(width(1px), height(16px), background(colours.line)))

toolbar(v::TakeoffView) = begin
  t = v.data
  n = plan_pages(v)
  s = Plans.scale(t, t.page)
  file = isempty(t.plan) ? "Choose a plan" : basename(t.plan)
  Row(width(grow=grow), height(38px), padding(6px, 0px), child_gap=2px, Alignment.Center, background(colours.block),
    [button!(v, (:tool, tool), (:tool, tool), icon=icon, tip=tip) for (tool, (icon, tip, _)) in PLAN_TOOLS]...,
    rule(),
    button!(v, :scale, :scale, words=s === nothing ? "Set the scale" : Plans.scale_text(s), tip="Type the scale of this page, like 1:100"),
    (n > 1 ? (rule(), button!(v, :back, (:page, -1), icon="chevron-left", tip="The page before", off=t.page <= 1),
              label("Page $(t.page) of $n", 12px, color=colours.dim),
              button!(v, :next, (:page, 1), icon="chevron-right", tip="The next page", off=t.page >= n)) : ())...,
    Box(width(grow=grow)),
    button!(v, :smaller, (:zoom, 1 / 1.4), icon="zoom-out", tip="Smaller"),
    button!(v, :bigger, (:zoom, 1.4), icon="zoom-in", tip="Bigger  pinch, or ⌘ and scroll"),
    button!(v, :fit, :fit, icon="aspect-ratio", tip="Show the whole page"),
    button!(v, :full, :full, icon=v.full ? "fullscreen-exit" : "arrows-fullscreen", tip=v.full ? "Back to the page  esc" : "Fill the window"),
    rule(),
    button!(v, :plan, :choose, icon="file-earmark-pdf", words=length(file) > 28 ? first(file, 27) * "…" : file, tip="Choose the plan's file"))
end

"The line under the tools that asks for the scale, or for the length of the line that was drawn"
prompt(v::TakeoffView) = begin
  a = v.asking
  (a !== nothing && a[1] in (:scale, :length)) || return ()
  words, hint = a[1] == :scale ? ("The scale of this page", "like 1:100, then Return") :
                                 ("How long is the line that you drew?", "in metres, like 3.6, or 3600mm, then Return")
  (Row(width(grow=grow), height(36px), padding(12px, 0px), child_gap=10px, Alignment.Center, background(colours.float),
     label(words, 12px), field(v, fixed(110px)), label(hint, 12px, color=colours.dim)),)
end

"True when the table of measures has room for the price of one of each item"
has_price(v::TakeoffView) = editor(v).width >= 720px

"""
The headings of the table of measures. Each is as wide as the cells under it.
The panel beside a plan has two lines for each measure, so it has two
headings and no more: the item and its cost.
"""
table_head(v::TakeoffView) = begin
  # Each heading fills its cell, so the mouse can use it anywhere over its column
  left(key) = Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, head(v, key, :start))
  right(wide, key) = Row(wide, height(grow=grow), Alignment.Center, clip=true, (key === nothing ? () : (head(v, key, :end),))...)
  # With no Centient on the Mac there are no prices, so the columns for them have no headings
  ours(key) = Centient.available() ? key : nothing
  look = (width(grow=grow), height(26px), Alignment.Center, background(colours.head), border(1px, :solid, colours.line)[:bottom])
  v.beside && return Row(look..., padding(10px, 0px), child_gap=8px, name="Headings",
    Box(width(14px)), left(:item), right(fixed(88px), ours(:cost)), Box(width(28px)))
  Row(look..., padding(10px, 0px), child_gap=10px, name="Headings",
    Box(width(14px)), left(:item), Row(fixed(52px), height(grow=grow), Alignment.Center, clip=true, head(v, :extra, :start)),
    right(fixed(AMOUNT_W), :amount), (has_price(v) ? (right(fixed(96px), ours(:price)),) : ())..., right(fixed(88px), ours(:cost)),
    Box(width(28px)))   # over the buttons that remove a measure
end

"""
The table of measures, in a box of its own with round corners: the headings,
then `rows`, then the button that adds a measure. `tall` makes it fill the
height that it's given.
"""
table(v::TakeoffView, rows; tall=false) =
  Box(width(grow=grow), (tall ? (height(grow=grow),) : ())..., padding(10px, 8px),
    Column(width(grow=grow), (tall ? (height(grow=grow),) : ())..., Alignment.Start, radius(8px), border(1px, :solid, colours.line),
           background(colours.bg), clip=true, name="Measures",
      table_head(v), rows, adders(v)))

"The button at the foot of the table that starts a new measure"
adders(v::TakeoffView) =
  Row(width(grow=grow), height(36px), padding(6px, 0px), child_gap=2px, Alignment.Center, border(1px, :solid, colours.line)[:top],
    button!(v, :add, :add, icon="plus-lg", words="Add a measure",
            tip=Centient.available() ? "Choose an item. Its unit chooses the tool: count, length or area." :
                                       "Then choose a tool: count, length or area"))

"The rows of the table of measures: those that the columns' searches keep, in the order of the column that's sorted"
measure_rows(v::TakeoffView) = begin
  v.order = shown_measures(v)
  isempty(v.order) && !isempty(v.data.measures) &&
    return Any[Row(width(grow=grow), height(32px), padding(34px, 0px), Alignment.Center, label("No measure has that", 12px, color=colours.dim))]
  Any[part!(() -> MeasureRow(of=v, i=i), v, (:row, i)) for i in v.order]
end

"The line at the foot of the block: the customer, what the measures come to, and the button that makes the quote"
foot(v::TakeoffView) = begin
  t = v.data
  total, priced = 0.0, false
  for m in t.measures
    amount, row = Plans.amount(t, m), known(v, m.item)
    (amount === nothing || row === nothing) && continue
    total += cost_of(m, amount, row)
    priced = true
  end
  asking = v.asking == (:customer,)
  busy = v.quoting !== nothing
  said = isempty(v.said) ? (isempty(t.made) ? "" : "Quote $(t.made)") : v.said
  colour = v.wrong ? colours.accent : colours.dim
  customer = asking ? field(v, v.beside ? width(grow=grow) : fixed(220px)) :
             button!(v, :customer, :customer, words=isempty(t.customer) ? "Choose the customer" : t.customer, tip="Who the quote is for")
  maker = button!(v, :quote, :quote, icon="receipt", words=busy ? "Making the quote…" : isempty(t.made) ? "Make quote in Centient" : "Make another quote",
                  tip=Centient.available() ? "Centient makes a quote with a line for each measure" : "Centient isn't on this Mac",
                  off=busy || isempty(t.measures) || !Centient.available())
  line = border(1px, :solid, colours.line)[:top]
  # In the panel beside a plan that fills the window, each part of the foot has a line of its own
  v.beside && return Column(width(grow=grow), Alignment.Start, padding(10px, 8px), child_gap=6px, line,
    Row(width(grow=grow), height(28px), child_gap=8px, Alignment.Center, Icon("person", size=14px, color=colours.dim), customer),
    (priced ? (Row(width(grow=grow), height(22px), Alignment.Center, Box(label("At catalogue prices", 12px, color=colours.dim)),
                   Box(width(grow=grow)), Box(label(dollars(total), 13px, weight="Semibold"))),) : ())...,
    (isempty(said) ? () : (Box(width(grow=grow), Alignment.Start, Text(said, size=12px, family=SANS, color=colour, wrap=WrapMode.words)),))...,
    Row(width(grow=grow), justify=Alignment.End, maker))
  Row(width(grow=grow), height(42px), padding(10px, 0px), child_gap=8px, Alignment.Center, line,
    Icon("person", size=14px, color=colours.dim), customer,
    Row(width(grow=grow), clip=true, justify=Alignment.End, Box(label(said, 12px, color=colour))),
    # The catalogue's prices, before the GST and the margins that Centient adds to a quote
    (priced ? (label("At catalogue prices", 12px, color=colours.dim), label(dollars(total), 13px, weight="Semibold")) : ())...,
    maker)
end

"How tall the list of measures is, with what a search found under one of them"
list_h(v::TakeoffView) = 32px * max(1, length(v.order))

"The most of the window's height that the list of measures takes under a plan that fills the window"
const LIST_SHARE = 0.4

"""
True when the list of measures goes beside a plan that fills the window, and
false when it goes under it. It goes where it leaves the page bigger: beside a
wide window's plan, and under a tall window's.
"""
goes_beside(v::TakeoffView) = begin
  w, h = num.(window_size(editor(v)))
  h -= num(TOPBAR_H) + 38   # the top bar and the tools
  s = plan_size(v)
  s === nothing && return w > h
  side = min(num(SIDE_W), 0.45w)
  # Under the plan are the table, with its headings, its rows and the button that adds a measure, and the foot
  under = min(32.0 * length(v.data.measures), LIST_SHARE * h) + 26 + 36 + 18 + 42
  min((w - side) / s[1], h / s[2]) >= min(w / s[1], (h - under) / s[2])
end

describe(v::TakeoffView) = begin
  e = editor(v)
  plan_input(v).color = colours.ink
  area = part!(() -> PlanArea(of=v), v, :area)
  v.beside = v.full && goes_beside(v)
  with_theme(component_theme(e.zoom)) do
    # Only the tools have a colour of their own behind them. The rest is on white, and the plan's paper has a shadow.
    v.full || return Column(width(grow=grow), Alignment.Start, radius(8px), border(1px, :solid, colours.line), background(takeoff_back()),
                            clip=true, name="Takeoff",
      toolbar(v), prompt(v)..., area,
      table(v, Column(width(grow=grow), Alignment.Start, measure_rows(v)...)),
      foot(v))
    # In the window, the plan is as big as it can be. The wheel scrolls through a list of measures that's longer than its room.
    list = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :list)
    rows = Column(width(grow=grow), Alignment.Start, measure_rows(v)...)
    if v.beside
      list.height = height(grow=grow)
      return Row(width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back()), name="Takeoff",
        Column(width(grow=grow), height(grow=grow), Alignment.Start, toolbar(v), prompt(v)..., area),
        Column(fixed(min(SIDE_W, window_size(e)[1] * 0.45)), height(grow=grow), Alignment.Start, border(1px, :solid, colours.line)[:left],
          table(v, reuse!(list, rows), tall=true), foot(v)))
    end
    list.height = height(min(list_h(v), (window_size(e)[2] - TOPBAR_H - 38px) * LIST_SHARE))
    Column(width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back()), name="Takeoff",
      toolbar(v), prompt(v)..., area, table(v, reuse!(list, rows)), foot(v))
  end
end

cursor(::TakeoffView) = :arrow
# A click beside a button is the block's, and takes the keyboard from the text field
onkey(v::TakeoffView, ::KeyPress{Keys.mouse_left}) = (focus(part!(() -> PlanArea(of=v), v, :area)); handled)
onmouse(v::TakeoffView, ::MouseMove) = held(v, Keys.mouse_left) ? handled : nothing

# --- a schedule of the page's tasks -------------------------------------------------------
#
# A code block in the language `schedule` shows each to-do item of the page as
# a bar on a line of days. schedule.jl says how the block is written.
#
#   - Drag a bar to say the first day that its task can start.
#   - Drag the right end of a bar to say how many working days the task takes.
#   - Drag from the circle after a bar to another task. That task then waits
#     for this one, and starts when this one is finished. An arrow shows it.
#   - Click an arrow and press Delete to take it away.
#   - Click a task twice to go to its line of the page.
#   - Drag the days, or scroll sideways, to see other days. Pinch, or scroll
#     with ⌘ held, to show more days or fewer.
#   - The button at the top right makes the schedule fill the window. Esc puts
#     it back in the page.
#
# Every change is written into the block's lines, so the file holds the whole
# schedule. While the page has a schedule, the mouse over a to-do item shows
# the task's days beside the item, with buttons that make the task a day
# longer or shorter.

const SCHEDULE = Schedules.SCHEDULE
const TASK_H = 30.0        # px: how tall the row of a task is
const TASK_BAR = 20.0         # and how tall its bar is
const DATES_H = 46.0       # how tall the months and the days over the rows are
const DAY_MOST = 60.0      # the most px to a day
const DAY_LEAST = 2.5      # and the least
const DAY_USUAL = 34.0     # the most px to a day when a schedule shows all its tasks
const BAR_EDGE = 7.0       # px at the right end of a bar, where a drag makes the task longer or shorter
const KNOB = 4.5           # the radius of the circle after a bar, which a link is dragged from
const KNOB_GAP = 11.0      # from the end of a bar to the middle of that circle
const NAMES_W = 250px      # how wide the names of the tasks are at the most
const NAMES_FULL = 360px   # and at the most in a schedule that fills the window
const DETAILS_H = 24px     # how tall the days of a to-do item are beside the item
const DAY_ZERO = Date(2000, 1, 1)   # day number 0
"Every icon that a schedule can show. The built app reads them all when it's made."
const SCHEDULE_ICONS = ["bar-chart-steps", "calendar-event", "zoom-out", "zoom-in", "aspect-ratio", "dash", "plus", "check",
                        "arrows-fullscreen", "fullscreen-exit"]

"What a `schedule` block shows: the page's tasks, each as a bar on a line of days"
@def mutable struct ScheduleView <: SemanticUI
  n::Int = 0                              # its place among the page's schedules
  first::Int = 0                          # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Schedules.Schedule = Schedules.Schedule()
  lines::Vector{String} = String[]        # the lines that `data` was read from
  tasks::Vector{Schedules.Planned} = Schedules.Planned[]   # the page's tasks, with the days of each
  planned::Any = nothing                  # the version of the page, and the day, that `tasks` was worked out for
  renamed::Bool = false                   # a task has a new name that the block's lines don't have yet
  zoom::Float64 = 0.0                     # px to a day. 0 shows every task.
  at::Float64 = 0.0                       # the number of the day at the left edge of the bars
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the days and the bars were last drawn in the window
  picked::Any = nothing                   # what's selected: (:task, key), or (:link, key, key) for the link from one task to the next
  grab::Any = nothing                     # a drag: of a bar, of a bar's end, of a link or of the days
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where it was last clicked
  asking::Bool = false                    # the text field for the day that the work starts shows
  said::String = ""                       # what the top of the block says when something can't be done
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its buttons, names and text field, kept between frames
  full::Bool = false                      # it fills the window, over the page
  tall::px = 0px                          # how tall it was in the page when it was last laid out there
  pinned::px = 0px                        # how far the page was scrolled when it filled the window
end

"The part of a schedule that shows the days and the bars"
@def mutable struct ChartArea <: SemanticUI
  of::Any = nothing
end
"The name of a task, beside its bar"
@def mutable struct TaskName <: SemanticUI
  of::Any = nothing
  key::String = ""
end
"""
The days of the to-do item under the mouse. They show beside the item while
the page has a schedule: the task's first and last day, how many days it
takes, and what it waits for.
"""
@def mutable struct TaskDetails <: SemanticUI
  of::Any = nothing                # the schedule
  key::String = ""                 # the task
  floats::Bool = false             # it's under the item's first line, because that line has no room for it
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where it was last put in the window
  less::Any = nothing              # its two buttons
  more::Any = nothing
end
"A button beside a to-do item that makes its task a day longer or a day shorter"
@def mutable struct DayButton <: SemanticUI
  by::Int = 1
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
end

"A part of `v` that's kept between frames"
part!(make, v::ScheduleView, key) = begin
  node = get!(make, v.parts, key)
  node.parent === nothing && setfield!(node, :parent, v)
  node
end

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::ScheduleView, key, action; icon="", words="", tip="", off=false) = begin
  b = part!(() -> PlanButton(of=v), v, (:button, key))
  b.action, b.icon, b.words, b.tip, b.off = action, icon, words, tip, off
  b
end

"The text field of a schedule, for the day that the work starts"
schedule_input(v::ScheduleView) = part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

field(v::ScheduleView, wide=width(grow=grow)) =
  Box(wide, height(24px), padding(6px, 0px), radius(5px), border(1px, :solid, colours.accent), background(colours.bg), schedule_input(v))

chart(v::ScheduleView) = part!(() -> ChartArea(of=v), v, :area)

# --- the block's lines and the page's tasks -------------------------------------------------

"The to-do items of the page that shows"
page_todos(e) = (b = e.buf; get!(() -> Schedules.todos(b.lines, kinds(b)), e.flows, (:todos, b.path, b.version)))

"The view of the `n`th schedule of the page that shows"
schedule_view(e, n) = begin
  v = get!(() -> ScheduleView(n=n), e.nodes, (:schedule, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v
end

"Read the schedule again from the lines of its block, if they've changed"
reread!(v::ScheduleView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  start = v.data.start
  v.data = Schedules.schedule(lines)
  v.planned = nothing
  v.renamed = false
  # When the work starts on another day, as it does after ⌘Z takes a new day back, every task shows again
  v.data.start == start || (v.zoom = 0.0)
  v
end

"Work out the days of the page's tasks again. A task that was renamed in the page keeps its line of the schedule."
replan!(v::ScheduleView) = begin
  e = editor(v)
  names = [entry.name for entry in v.data.entries]
  v.tasks = Schedules.plan!(v.data, page_todos(e))
  names == [entry.name for entry in v.data.entries] || (v.renamed = true)
  v.planned = (e.buf.version, Dates.today())
  v
end

"The page's tasks with the days of each. They're worked out again when the page has changed, and on a new day."
tasks!(v::ScheduleView) = (v.planned == (editor(v).buf.version, Dates.today()) || replan!(v); v.tasks)

"The place of the task called `key` in the list of tasks, or nothing"
task_place(v::ScheduleView, key) = findfirst(t -> t.todo.key == key, v.tasks)

"""
Write the schedule into its block. The caret stays where it was in the text,
and ⌘Z takes the change back. If the block's lines aren't the ones that the
schedule was read from, something else changed them, and the schedule is read
again. The lines of tasks that the page no longer has go.
"""
commit!(v::ScheduleView) = begin
  e = editor(v)
  b = e.buf
  readonly(b) && return v
  span = block_lines(b, SCHEDULE, v.n)
  span === nothing && return v
  i, t = span
  v.first, v.last = i, t
  b.lines[i+1:t-1] == v.lines || return reread!(v, b.lines[i+1:t-1])
  # The day that the work starts is written down, so that it's the same day tomorrow
  v.data.start === nothing && (v.data.start = Schedules.workday(Dates.today(), v.data.weekends))
  Schedules.prune!(v.data, page_todos(e))
  new = Schedules.written(v.data)
  v.planned = nothing
  v.renamed = false
  new == v.lines && return v
  caret, anchor = b.caret, b.anchor
  edit!(b, line_end(b, i), line_end(b, t - 1), isempty(new) ? "" : "\n" * join(new, "\n"))
  by = length(new) - length(v.lines)
  moved(p) = p[1] >= t ? (p[1] + by, p[2]) : p[1] > i ? (i, 0) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  v.last += by
  v.lines = new
  v
end

"What the `schedule` block from line `i` to line `t` shows. `n` is its place among the page's schedules."
schedule_item(e, i, t, n) = begin
  v = schedule_view(e, n)
  v.first, v.last = i, t
  reread!(v, e.buf.lines[i+1:t-1])
  tasks!(v)
  # A schedule that fills the window is drawn over the page, and its room in the page stays empty
  v.full && return Live(Box(width(grow=grow), height(v.tall)), v.tall + 2LIVE_GAP)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  v.tall = concrete.height
  Live(v, v.tall + 2LIVE_GAP)
end

"Make the schedule fill the window, or put it back in the page. Either way it shows every task again."
full!(v::ScheduleView, on::Bool) = begin
  e = editor(v)
  # One takeoff or schedule at a time fills the window
  on && foreach(node -> node isa Union{TakeoffView,ScheduleView} && (node.full = false), values(e.nodes))
  v.full = on
  v.pinned = e.scroll.offset
  v.zoom = 0.0
  focus(chart(v))
  handled
end

"How tall the names and the bars are in a schedule that fills the window, when its tasks need less: the window, under the top bar and the schedule's buttons"
full_room(v::ScheduleView) = num(window_size(editor(v))[2] - TOPBAR_H - 38px)

"How tall the names and the bars of a schedule are"
chart_h(v::ScheduleView) = (rows = DATES_H + TASK_H * length(v.tasks); px(v.full ? max(rows, full_room(v)) : rows))

"""
Write the page to its file. A task that was renamed in the page since its
schedule was last written gets its new name in the schedule first, so that the
file's schedule names the tasks as the file's to-do items do.
"""
save_page!(e) = begin
  for (key, node) in collect(e.nodes)
    (node isa ScheduleView && key[2] == e.buf.path) || continue
    span = block_lines(e.buf, SCHEDULE, node.n)
    span === nothing && continue
    reread!(node, e.buf.lines[span[1]+1:span[2]-1])
    tasks!(node)
    node.renamed && commit!(node)
  end
  save!(e.buf)
end

# --- where things are ------------------------------------------------------------------------

"The number of the day `d`: one more for each day that passes"
daynum(d::Date) = Float64(Dates.value(d - DAY_ZERO))
"The day with the number `n`"
numday(n::Real) = DAY_ZERO + Day(floor(Int, n))

"How far across the window day number `n` starts"
day_x(v::ScheduleView, n::Real) = v.box[1] + (n - v.at) * v.zoom
"The number of the day at `x` across the window, with the part of the day that's passed"
x_day(v::ScheduleView, x::Real) = v.at + (x - v.box[1]) / v.zoom

"Where the bar of the task at place `i` is in the window: its left, top, width and height"
task_bar(v::ScheduleView, i::Int) = begin
  t = v.tasks[i]
  left, right = day_x(v, daynum(t.start)) + 1, day_x(v, daynum(t.finish) + 1) - 1
  (left, v.box[2] + DATES_H + (i - 1) * TASK_H + (TASK_H - TASK_BAR) / 2, max(right - left, 3.0), TASK_BAR)
end

"The middle of the circle after the bar of the task at place `i`"
knob(v::ScheduleView, i::Int) = (b = task_bar(v, i); (b[1] + b[3] + KNOB_GAP, b[2] + b[4] / 2))

"The place of the task whose row is `y` down the window, or nothing"
row_at(v::ScheduleView, y::Real) = begin
  i = floor(Int, (y - v.box[2] - DATES_H) / TASK_H) + 1
  1 <= i <= length(v.tasks) ? i : nothing
end

"""
The corners of the arrow from the end of task `a`'s bar to the start of task
`b`'s. Where the bars leave no room to turn between them, it goes round,
between two rows.
"""
link_points(v::ScheduleView, a::Int, b::Int) = begin
  from, to = task_bar(v, a), task_bar(v, b)
  sx, sy = from[1] + from[3], from[2] + from[4] / 2
  tx, ty = to[1], to[2] + to[4] / 2
  out = sx + 8
  tx - out >= 8 && return [(sx, sy), (out, sy), (out, ty), (tx, ty)]
  between = sy + sign(ty - sy) * TASK_H / 2
  back = tx - 9
  [(sx, sy), (out, sy), (out, between), (back, between), (back, ty), (tx, ty)]
end

"How far the place `(x, y)` is from the line through the places `ps`"
away(ps, x, y) = minimum(1:length(ps)-1) do k
  (ax, ay), (bx, by) = ps[k], ps[k+1]
  long = (bx - ax)^2 + (by - ay)^2
  along = long == 0 ? 0.0 : clamp(((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / long, 0, 1)
  hypot(x - ax - along * (bx - ax), y - ay - along * (by - ay))
end

"""
What's at the place `(x, y)` of a schedule's bars: `(:knob, i)` for the circle
after the bar of the task at place `i`, `(:edge, i)` for the right end of its
bar, `(:bar, i)` for the rest of the bar, `(:link, a, b)` for the arrow from
task `a` to task `b`, `(:row, i)` for the rest of the task's row, or nothing.
"""
under(v::ScheduleView, x::Real, y::Real) = begin
  left, top, wide, tall = v.box
  (v.zoom > 0 && left <= x < left + wide && top + DATES_H <= y < top + tall) || return nothing
  i = row_at(v, y)
  i === nothing && return nothing
  bx, by, bw, bh = task_bar(v, i)
  kx, ky = knob(v, i)
  hypot(x - kx, y - ky) <= KNOB + 3 && return (:knob, i)
  if by - 2 <= y < by + bh + 2 && bx <= x < bx + bw + 3
    return x >= bx + bw - min(BAR_EDGE, bw / 2) ? (:edge, i) : (:bar, i)
  end
  for (b, t) in enumerate(v.tasks), a in t.after
    away(link_points(v, a, b), x, y) <= 4 && return (:link, a, b)
  end
  (:row, i)
end

"The place of the task whose row the mouse is over, in its name or in its bar's row, or 0"
hot_row(v::ScheduleView) = begin
  w = window_of(v)
  (w === nothing || !ishovered(v) || v.zoom <= 0) && return 0
  something(row_at(v, num(w.mouse[2])), 0)
end

"The days of a task in words: Mon 16 Nov – Wed 18 Nov"
task_days(t) = t.start == t.finish ? Schedules.short(t.start) : Schedules.short(t.start) * " – " * Schedules.short(t.finish)
"The days of a task and how many they are: Mon 16 Nov – Wed 18 Nov  ·  3 days"
task_words(t) = task_days(t) * "  ·  " * Schedules.days_text(t.days)

"""
Show every task: the days from the day before the first task starts to the
day after the last one finishes. A short schedule's days are no wider than
`DAY_USUAL` in the page, and no wider than `DAY_MOST` when it fills the window.
"""
fit!(v::ScheduleView) = begin
  ts = v.tasks
  today = Dates.today()
  lo, hi = isempty(ts) ? (today, today + Day(13)) : (minimum(t -> t.start, ts), maximum(t -> t.finish, ts))
  days = daynum(hi) - daynum(lo) + 3.5
  v.zoom = clamp(max(v.box[3], 1.0) / days, DAY_LEAST, v.full ? DAY_MOST : DAY_USUAL)
  v.at = daynum(lo) - 1
  v
end

"Make each day `by` times as wide. The day at `x` across the window stays there."
zoom_days!(v::ScheduleView, by, x) = begin
  v.zoom > 0 || return handled
  day = x_day(v, x)
  v.zoom = clamp(v.zoom * by, DAY_LEAST, DAY_MOST)
  v.at = day - (x - v.box[1]) / v.zoom
  handled
end

# --- drawing -------------------------------------------------------------------------------

"Write `words` on the canvas, with their left end at `x` and the line that they stand on at `y`"
write_ink(ctx, words, x, y, face::Face) = begin
  paint = ink(face.color)
  blob = Skia.sk_textblob_make_from_string(words, skia_font(face.family, face.size, face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
  Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x), Float32(y), paint)
  Skia.sk_textblob_unref(blob)
  Skia.sk_paint_delete(paint)
end

"Draw a box whose corners have the radius `r`. `fill` colours it in, and `line` draws its edge, `wide` px wide."
round_box(ctx, x, y, w, h, r; fill=nothing, line=nothing, wide=1.0) = begin
  shape = Skia.sk_path_new()
  rect = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
  Skia.sk_path_add_rounded_rect(shape, rect, Float32(r), Float32(r), Skia.SK_PATH_DIRECTION_CW)
  for paint in ((fill === nothing ? () : (ink(fill),))..., (line === nothing ? () : (ink(line, wide),))...)
    Skia.sk_canvas_draw_path(ctx, shape, paint)
    Skia.sk_paint_delete(paint)
  end
  Skia.sk_path_delete(shape)
end

"Draw a line through the corners `ps`, each corner a little round, with the head of an arrow at its end"
arrow(ctx, ps, colour, wide) = begin
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, Float32(ps[1][1]), Float32(ps[1][2]))
  for k in 2:length(ps)-1
    before, corner, after = ps[k-1], ps[k], ps[k+1]
    d1, d2 = hypot((corner .- before)...), hypot((after .- corner)...)
    r = min(4.0, d1 / 2, d2 / 2)
    a = corner .+ (before .- corner) .* (r / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (r / max(d2, 1e-6))
    Skia.sk_path_line_to(shape, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(shape, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  # The line stops where the head starts
  tip, from = ps[end], ps[end-1]
  along = (tip .- from) ./ max(hypot((tip .- from)...), 1e-6)
  base = tip .- along .* 5.5
  Skia.sk_path_line_to(shape, Float32(base[1]), Float32(base[2]))
  paint = ink(colour, wide)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
  across = (-along[2], along[1]) .* 3.4
  trace(ctx, [tip, base .+ across, base .- across], colour, 0.6; fill=colour, closed=true)
end

"Draw the months and the days over the rows, the lines between them, the days when no work is done, and today"
draw_days(ctx, v::ScheduleView) = begin
  left, top, wide, tall = v.box
  z = v.zoom
  rows = top + DATES_H
  small = Face(SANS, "", 11px, colours.dim, false)
  each_day, each_week = z >= 20, 7z >= 46
  for n in floor(Int, v.at):ceil(Int, v.at + wide / z)
    d = numday(n)
    x = day_x(v, n)
    off = !Schedules.works(d, v.data.weekends)
    off && round_box(ctx, x, rows, z, tall - DATES_H, 0; fill=RGBA(colours.ink, 0.05))
    month, monday = Dates.day(d) == 1, Dates.dayofweek(d) == 1
    if month
      trace(ctx, [(x, top + 4), (x, top + tall)], RGBA(colours.ink, 0.16), 1.0)
    elseif each_day || (monday && each_week)
      trace(ctx, [(x, rows), (x, top + tall)], RGBA(colours.ink, monday ? 0.1 : 0.05), 1.0)
    end
    if each_day
      words = string(Dates.day(d))
      face = off ? Face(small, color=colours.faint) : small
      write_ink(ctx, words, x + (z - num(measure(face, words))) / 2, top + 37, face)
    elseif monday && each_week
      write_ink(ctx, "$(Dates.day(d)) $(Dates.monthabbr(d))", x + 5, top + 37, small)
    end
  end
  # Today's name goes over the middle of today, when today is in sight
  now = day_x(v, daynum(Dates.today())) + z / 2
  today = Face(SANS, "Semibold", 10.5px, colours.bg, false)
  pill = num(measure(today, "Today")) + 12
  shows = left <= now <= left + wide
  # Each month's name is at the month's first day, or at the left edge when that day is out of sight.
  # A name that today's name would cover goes after it.
  bold = Face(SANS, "Medium", 12px, colours.ink, false)
  month = Dates.firstdayofmonth(numday(v.at))
  while day_x(v, daynum(month)) < left + wide
    next = month + Dates.Month(1)
    words = "$(Dates.monthname(month)) $(Dates.year(month))"
    long = num(measure(bold, words))
    x = max(left + 8, day_x(v, daynum(month)) + 6)
    shows && x < now + pill / 2 + 6 && x + long > now - pill / 2 - 6 && (x = now + pill / 2 + 8)
    write_ink(ctx, words, min(x, day_x(v, daynum(next)) - long - 8), top + 18, bold)
    month = next
  end
  trace(ctx, [(left, rows), (left + wide, rows)], colours.line, 1.0)
  for i in 1:length(v.tasks)
    y = rows + i * TASK_H
    trace(ctx, [(left, y), (left + wide, y)], RGBA(colours.line, 0.6), 1.0)
  end
  # Today has a line down the rows, under its name
  if shows
    trace(ctx, [(now, rows), (now, top + tall)], RGBA(colours.ink, 0.6), 1.0)
    round_box(ctx, now - pill / 2, top + 6, pill, 16, 4; fill=colours.ink)
    write_ink(ctx, "Today", now - pill / 2 + 6, top + 17.5, today)
  end
end

"The colour of a task's bar: one for a task that's done, and one for a task that isn't"
task_hue(t) = t.todo.done ? colours.string : colours.accent

"Draw the bar of each task. The task under the mouse, and the one that's selected, have the circle that a link is dragged from."
draw_bars(ctx, v::ScheduleView) = begin
  left, _, wide, _ = v.box
  hot = hot_row(v)
  g = v.grab
  for (i, t) in enumerate(v.tasks)
    x, y, w, h = task_bar(v, i)
    (x + w + 2KNOB_GAP < left || x > left + wide) && continue
    hue = task_hue(t)
    on = v.picked == (:task, t.todo.key)
    round_box(ctx, x, y, w, h, 5; fill=RGBA(hue, on ? 0.32 : 0.17), line=RGBA(hue, 0.9), wide=on ? 1.8 : 1.0)
    # A task that's done has a tick, and a bar with room says how many days it is
    inset = 6.0
    if t.todo.done && w >= 18
      trace(ctx, [(x + 5.5, y + h / 2 + 0.5), (x + 8.5, y + h / 2 + 3.5), (x + 13.5, y + h / 2 - 3.5)], hue, 1.6)
      inset = 18.0
    end
    face = Face(SANS, "Medium", 10.5px, hue, false)
    words = "$(t.days)d"
    num(measure(face, words)) + inset + 5 <= w && write_ink(ctx, words, x + inset, y + h / 2 + 3.8, face)
    if (g === nothing && (i == hot || on)) || (g !== nothing && g[1] == :link && g[2] == t.todo.key)
      kx, ky = knob(v, i)
      trace(ctx, [(x + w, ky), (kx - KNOB, ky)], RGBA(hue, 0.7), 1.2)
      for (r, colour) in ((KNOB, hue), (KNOB - 1.5, takeoff_back()))
        paint = ink(colour)
        Skia.sk_canvas_draw_circle(ctx, Float32(kx), Float32(ky), Float32(r), paint)
        Skia.sk_paint_delete(paint)
      end
    end
  end
end

"Draw an arrow from each task to each task that waits for it"
draw_links(ctx, v::ScheduleView) = begin
  for (b, t) in enumerate(v.tasks), a in t.after
    on = v.picked == (:link, v.tasks[a].todo.key, t.todo.key)
    arrow(ctx, link_points(v, a, b), on ? colours.accent : RGBA(colours.dim, 0.9), on ? 2.0 : 1.2)
  end
end

"Draw what a drag is doing: the link that's being made, or the days of the bar that's being moved"
draw_drag(ctx, v::ScheduleView) = begin
  g = v.grab
  (g === nothing || g[1] == :pan) && return
  i = task_place(v, g[2])
  i === nothing && return
  x, y, w, h = task_bar(v, i)
  if g[1] == :link
    win = window_of(v)
    win === nothing && return
    mx, my = num(win.mouse[1]), num(win.mouse[2])
    trace(ctx, [knob(v, i), (mx, my)], colours.accent, 1.5)
    # The task that the link would go to has a line round its bar
    j = row_at(v, my)
    if j !== nothing && j != i
      tx, ty, tw, th = task_bar(v, j)
      round_box(ctx, tx - 2, ty - 2, tw + 4, th + 4, 7; line=colours.accent, wide=1.5)
    end
  else
    tag(ctx, (x + w - 4, y + 2), task_words(v.tasks[i]))
  end
end

describe(a::ChartArea) = Box(width(grow=grow), height(chart_h(a.of)))

draw(ctx, size, ui::ConcreteRect, a::ChartArea) = begin
  v = a.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  v.box[3] > 0 || return
  v.zoom > 0 || fit!(v)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    draw_days(ctx, v)
    draw_links(ctx, v)
    draw_bars(ctx, v)
    draw_drag(ctx, v)
  end
end

cursor(a::ChartArea) = begin
  v = a.of
  g = v.grab
  g === nothing || return g[1] == :size ? :resize_x : g[1] == :pan ? :arrow : :hand
  w = window_of(v)
  w === nothing && return :arrow
  hit = under(v, num(w.mouse[1]), num(w.mouse[2]))
  hit === nothing || hit[1] == :row ? :arrow : hit[1] == :edge ? :resize_x : :hand
end

# --- the mouse and the keys on the bars -----------------------------------------------------

"Put the caret at the end of line `i` of the page, and bring the line in sight"
show_line!(e, i::Int) = begin
  b = e.buf
  1 <= i <= length(b.lines) || return handled
  b.caret = b.anchor = line_end(b, i)
  focus(e)
  touch!(e)
  handled
end

"Note a click at `(x, y)`. True when it's the second of two clicks in one place."
click_twice!(v::ScheduleView, x, y) = begin
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  time() - at < 0.35 && hypot(x - cx, y - cy) < 4
end

onkey(a::ChartArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  focus(a)
  v.said = ""
  v.zoom > 0 || return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  twice = click_twice!(v, x, y)
  hit = under(v, x, y)
  if hit === nothing || hit[1] == :row
    # A drag of anything but a bar moves the days
    v.picked = nothing
    v.grab = (:pan, x, v.at)
  elseif hit[1] == :link
    v.picked = (:link, v.tasks[hit[2]].todo.key, v.tasks[hit[3]].todo.key)
  else
    t = v.tasks[hit[2]]
    key = t.todo.key
    v.picked = (:task, key)
    if hit[1] == :knob
      v.grab = (:link, key)
    elseif hit[1] == :edge
      v.grab = (:size, key, false)
    elseif twice
      return show_line!(editor(v), t.todo.line)
    else
      # The bar keeps the place where the mouse took hold of it
      v.grab = (:move, key, x - day_x(v, daynum(t.start)), false)
    end
  end
  handled
end

"A drag ended. A link is made, or the bar that moved is written down."
drop!(v::ScheduleView) = begin
  g = v.grab
  v.grab = nothing
  g === nothing && return v
  if g[1] == :link
    w = window_of(v)
    a = task_place(v, g[2])
    b = w === nothing ? nothing : row_at(v, num(w.mouse[2]))
    (a === nothing || b === nothing) && return v
    did = Schedules.link!(v.data, v.tasks, a, b)
    did == :ok && return commit!(v)
    did == :loop && (v.said = "“$(v.tasks[a].todo.name)” waits for “$(v.tasks[b].todo.name)”, so it can't go before it")
  elseif g[1] in (:move, :size) && g[end]
    commit!(v)
  end
  v
end

onmouse(a::ChartArea, ev::MouseMove) = begin
  v = a.of
  v.zoom > 0 || return nothing
  x, y = num(ev.position[1]), num(ev.position[2])
  g = v.grab
  if g === nothing
    # A bar says its days, and the other parts say what they're for
    hit = under(v, x, y)
    if hit !== nothing && hit[1] in (:bar, :edge)
      show_tooltip!(ev.window, tip_label(task_words(v.tasks[hit[2]])), px.(task_bar(v, hit[2]))..., placement=:top, gap=6px)
    elseif hit !== nothing && hit[1] == :knob
      kx, ky = knob(v, hit[2])
      show_tooltip!(ev.window, tip_label("Drag to the task that waits for this one"), px(kx - KNOB), px(ky - KNOB), px(2KNOB), px(2KNOB), placement=:top, gap=6px)
    elseif hit !== nothing && hit[1] == :link
      words = "“$(v.tasks[hit[3]].todo.name)” waits for “$(v.tasks[hit[2]].todo.name)”.  Click, then Delete takes the link away"
      show_tooltip!(ev.window, tip_label(words), px(x - 4), px(y - 4), 8px, 8px, placement=:top, gap=6px)
    end
    return handled
  end
  Keys.mouse_left in ev.window.keys || (drop!(v); return handled)
  # A press that became a drag isn't the first click of two
  hypot(x - v.clicked[2], y - v.clicked[3]) > 4 && (v.clicked = (0.0, 0.0, 0.0))
  if g[1] == :pan
    v.at = g[3] - (x - g[2]) / v.zoom
    return handled
  end
  i = task_place(v, g[2])
  i === nothing && return handled
  t = v.tasks[i]
  if g[1] == :move
    d = Schedules.workday(numday(round(x_day(v, x - g[3]))), v.data.weekends)
    d == t.start && return handled
    Schedules.move!(v.data, v.tasks, t, d)
    replan!(v)
    v.grab = (:move, g[2], g[3], true)
  elseif g[1] == :size
    # The bar ends at the line between two days that's nearest the mouse
    days = max(1, Schedules.span(t.start, numday(round(x_day(v, x))) - Day(1), v.data.weekends))
    days == t.days && return handled
    Schedules.days!(v.data, t, days)
    replan!(v)
    v.grab = (:size, g[2], true)
  end
  handled   # the drag is the schedule's, so the page's text doesn't select
end

# Scrolling sideways moves the days, and scrolling with ⌘ held shows more days or fewer, round the mouse.
# Scrolling up and down scrolls the page that the schedule is on.
onscroll(a::ChartArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  v.zoom > 0 || return nothing
  dx, dy = num(ev.delta[1]), num(ev.delta[2])
  Keys.cmd in w.keys && return zoom_days!(v, exp(dy / 10), num(w.mouse[1]))
  abs(dx) > abs(dy) || return nothing
  v.at -= 30dx / v.zoom
  handled
end

onpinch(a::ChartArea, ev::Pinch) = zoom_days!(a.of, ev.scale, num(ev.window.mouse[1]))

# Esc takes the selection away, then puts a schedule that fills the window back in the page, then gives the keyboard back to the text
onkey(a::ChartArea, ::KeyPress{Keys.escape}) = begin
  v = a.of
  v.picked === nothing || return (v.picked = nothing; handled)
  v.full ? full!(v, false) : nothing
end
onkey(a::ChartArea, ::KeyPress{K}) where K = begin
  v = a.of
  if K in (Keys.backspace, Keys.delete)
    # Delete takes away the link that's selected
    p = v.picked
    (p !== nothing && p[1] == :link) || return handled
    from, to = task_place(v, p[2]), task_place(v, p[3])
    v.picked = nothing
    (from === nothing || to === nothing) && return handled
    Schedules.unlink!(v.data, v.tasks, from, to)
    commit!(v)
    return handled
  elseif K == Keys.z && held(a, Keys.cmd)
    b = editor(v).buf
    held(a, Keys.shft) ? redo!(b) : undo!(b)
    return handled
  end
  nothing
end

# --- the names, the buttons and the whole block -----------------------------------------------

"How wide the names of the tasks are, beside the bars"
names_w(v::ScheduleView) = v.full ? min(NAMES_FULL, window_size(editor(v))[1] * 0.3) : min(NAMES_W, editor(v).width * 0.36)

describe(n::TaskName) = begin
  v = n.of
  i = task_place(v, n.key)
  i === nothing && return Box(width(grow=grow), height(px(TASK_H)))
  t = v.tasks[i]
  on = v.picked == (:task, n.key)
  # A task under another, further in, is further in here too
  indent = 12px + 14px * min(t.todo.level ÷ 2, 4)
  room = names_w(v) - indent - 12px - (t.todo.done ? 20px : 0px)
  Row(width(grow=grow), height(px(TASK_H)), padding(0px, 12px, 0px, indent), child_gap=6px, Alignment.Center, clip=true,
      background(on ? colours.active : hot_row(v) == i ? colours.hover : clear),
    (t.todo.done ? (Icon("check", size=14px, color=colours.string),) : ())...,
    Box(label(elide(t.todo.name, 13px, room), 13px, color=t.todo.done ? colours.dim : colours.ink)))
end

cursor(::TaskName) = :hand

onkey(n::TaskName, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = n.of, ev.window
  focus(chart(v))
  twice = click_twice!(v, num(w.mouse[1]), num(w.mouse[2]))
  v.picked = (:task, n.key)
  i = task_place(v, n.key)
  twice && i !== nothing ? show_line!(editor(v), v.tasks[i].todo.line) : handled
end

toolbar(v::ScheduleView) = begin
  s = v.data
  start = v.asking ?
    (Box(width(6px)), label("Starts on", 12px), Box(width(6px)), field(v, fixed(120px)), Box(width(8px)),
     label("like 16 Nov, then Return", 12px, color=colours.dim)) :
    (button!(v, :start, :start, icon="calendar-event", words="Starts " * Schedules.long(Schedules.origin(s)),
             tip="Change the day that the work starts"),)
  Row(width(grow=grow), height(38px), padding(6px, 0px), child_gap=2px, Alignment.Center, background(colours.block),
    start..., rule(),
    button!(v, :weekends, :weekends, words=s.weekends ? "Every day" : "Weekdays",
            tip=s.weekends ? "Work is done every day. Click to leave out Saturday and Sunday." :
                             "Work is done from Monday to Friday. Click to count Saturday and Sunday too."),
    Row(width(grow=grow), padding(8px, 0px), clip=true, justify=Alignment.End, Box(label(v.said, 12px, color=colours.accent))),
    button!(v, :smaller, (:zoom, 1 / 1.4), icon="zoom-out", tip="Show more days"),
    button!(v, :bigger, (:zoom, 1.4), icon="zoom-in", tip="Show fewer days  pinch, or ⌘ and scroll"),
    button!(v, :fit, :fit, icon="aspect-ratio", tip="Show every task"),
    button!(v, :full, :full, icon=v.full ? "fullscreen-exit" : "arrows-fullscreen", tip=v.full ? "Back to the page  esc" : "Fill the window"))
end

"Do what a button of a schedule does"
act!(v::ScheduleView, action, w) = begin
  a = action isa Tuple ? action[1] : action
  v.said = ""
  if a == :start
    i = schedule_input(v)
    i.color = colours.ink
    i.text = Schedules.long(Schedules.origin(v.data))
    i.anchor, i.cursor = 0, length(i.text)
    v.asking = true
    focus(i)
  elseif a == :weekends
    v.data.weekends = !v.data.weekends
    commit!(v)
  elseif a == :zoom
    zoom_days!(v, action[2], v.box[1] + v.box[3] / 2)
  elseif a == :fit
    fit!(v)
  elseif a == :full
    full!(v, !v.full)
  end
  handled
end

"Take the day that was typed as the day that the work starts, and show every task again"
answer!(v::ScheduleView) = begin
  v.asking || return handled
  d = Schedules.date(schedule_input(v).text)
  d === nothing && return (v.said = "Kaydown can't read that day. Type it like 16 Nov 2026."; handled)
  v.data.start = d
  stop_asking!(v)
  commit!(v)
  v.zoom = 0.0
  handled
end

"Take the text field away. The keyboard goes back to the bars."
stop_asking!(v::ScheduleView) = begin
  v.asking = false
  w = window_of(v)
  w !== nothing && w.focus === schedule_input(v) && focus(chart(v))
  handled
end

onkey(v::ScheduleView, ::KeyPress{Keys.enter}) = v.asking ? answer!(v) : nothing
onkey(v::ScheduleView, ::KeyPress{Keys.escape}) = v.asking ? stop_asking!(v) : nothing

"What happens to a schedule in each frame, before the page is laid out: a drag that ended is written down, and the text field that lost the keyboard closes"
tick!(v::ScheduleView) = begin
  w = window_of(v)
  v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v)
  # A click somewhere else took the keyboard from the text field. A day that reads is kept.
  if v.asking && w !== nothing && w.focus !== schedule_input(v)
    Schedules.date(schedule_input(v).text) === nothing ? stop_asking!(v) : answer!(v)
  end
  v
end

"Do what each schedule of the page that shows needs in this frame"
schedule_tick!(e) = for (key, node) in collect(e.nodes)
  (node isa ScheduleView && key[2] == e.buf.path) || continue
  tick!(node)
  node.full || continue
  # A schedule whose block has gone goes back to the page. Under one that fills the window, the page stays where it was.
  block_lines(e.buf, SCHEDULE, node.n) === nothing ? (node.full = false) : (e.scroll.offset = node.pinned)
end

describe(v::ScheduleView) = begin
  e = editor(v)
  schedule_input(v).color = colours.ink
  ts = tasks!(v)
  # The names of tasks that the page had once are forgotten
  length(v.parts) > 2length(ts) + 40 && filter!(p -> !(p[1] isa Tuple && p[1][1] == :name) || task_place(v, p[1][2]) !== nothing, v.parts)
  with_theme(component_theme(e.zoom)) do
    # In the page it's a box with round corners. In the window it takes all the room under the top bar.
    look = v.full ? (width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back())) :
                    (width(grow=grow), Alignment.Start, radius(8px), border(1px, :solid, colours.line), background(takeoff_back()))
    isempty(ts) && return Column(look..., clip=true, name="Schedule", toolbar(v),
      Row(width(grow=grow), height(64px), padding(16px, 0px), Alignment.Center, clip=true,
          Box(label("This page has no to-do items yet. Start a line with - [ ] to make a task.", 13px, color=colours.dim))))
    names = Column(fixed(names_w(v)), height(chart_h(v)), Alignment.Start, border(1px, :solid, colours.line)[:right],
      Row(width(grow=grow), height(px(DATES_H)), padding(12px, 0px, 9px, 12px), Alignment.End, border(1px, :solid, colours.line)[:bottom],
          Box(label("Task", 11px, color=colours.dim))),
      [part!(() -> TaskName(of=v, key=t.todo.key), v, (:name, t.todo.key)) for t in ts]...)
    rows = Row(width(grow=grow), Alignment.Start, names, chart(v))
    v.full || return Column(look..., clip=true, name="Schedule", toolbar(v), rows)
    # The wheel scrolls through more tasks than the window has room for
    list = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :list)
    Column(look..., name="Schedule", toolbar(v), reuse!(list, rows))
  end
end

cursor(::ScheduleView) = :arrow
# A click beside a button is the block's, and takes the keyboard from the text field
onkey(v::ScheduleView, ::KeyPress{Keys.mouse_left}) = (focus(chart(v)); handled)
onmouse(v::ScheduleView, ::MouseMove) = held(v, Keys.mouse_left) ? handled : nothing

# --- a to-do item of a page that has a schedule ------------------------------------------------
#
# A to-do item reads as it always does: a box and its text. While the page has
# a schedule, the item is a task, and the mouse over it shows the task's days
# at the right end of its line: its first and last day, how many working days
# it takes, with a button each side that makes it a day shorter or longer, and
# what it waits for. An item whose lines have no room for them shows them under
# the item.

"The schedule that the page's to-do items are in: the page's first, or nothing when it has none"
page_schedule(e) = begin
  b = e.buf
  readonly(b) && return nothing
  span = block_lines(b, SCHEDULE, 1)
  span === nothing && return nothing
  v = schedule_view(e, 1)
  reread!(v, b.lines[span[1]+1:span[2]-1])
  v
end

"The line of the to-do item whose row of the page is at the place `(x, y)` in the window, or nothing. An item that shows its markup isn't one."
todo_line(e, x, y) = begin
  dx, dy = px(x) - e.origin[1], px(y) - e.origin[2]
  (-30px <= dx < e.width && y >= num(TOPBAR_H)) || return nothing
  k = findlast(it -> it.top <= dy, e.layout)
  k === nothing && return nothing
  it = e.layout[k]
  f = it.content
  dy < it.top + it.tall && f isa Flow && f.kind == Kind.todo && !f.raw ? it.first : nothing
end

"""
The days of the to-do item under the mouse, beside the item. They stay while
the mouse is on them, so that their buttons can be clicked.
"""
task_over(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  (win === nothing || isempty(e.layout) || readonly(e.buf)) && return ()
  d = node!(TaskDetails, e, :task_details)
  x, y = num(win.mouse[1]), num(win.mouse[2])
  on_details = d.of !== nothing && d.box[1] <= x < d.box[1] + d.box[3] && d.box[2] <= y < d.box[2] + d.box[4]
  hide() = (d.of = nothing; ())
  line = on_details ? nothing : ishovered(node!(Document, e, :document)) && !held(e, Keys.mouse_left) ? todo_line(e, x, y) : nothing
  (on_details || line !== nothing) || return hide()
  v = page_schedule(e)
  v === nothing && return hide()
  ts = tasks!(v)
  i = on_details ? task_place(v, d.key) : findfirst(t -> t.todo.line == line, ts)
  i === nothing && return hide()
  it = item(e, ts[i].todo.line)
  f = it.content
  (f isa Flow && f.kind == Kind.todo && !f.raw) || return hide()
  d.of, d.key = v, ts[i].todo.key
  wide = describe(Row(Alignment.Start, geometry(d)), (9999px, 9999px)).width
  # They go at the right end of the first of the item's lines that has room for them, or under the item when none has
  k = findfirst(vl -> maximum(seg -> seg.x + seg.w, vl.segs, init=0px) + 24px + wide <= e.width, f.lines)
  d.floats = k === nothing
  vl = f.lines[something(k, length(f.lines))]
  left = e.origin[1] + e.width - wide
  top = e.origin[2] + it.top + f.above + vl.top
  top = d.floats ? top + vl.high - 2px : top + (vl.high - DETAILS_H) / 2
  top >= TOPBAR_H || return hide()
  d.box = (num(left), num(top), num(wide), num(DETAILS_H))
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), d),)
end

describe(d::TaskDetails) = begin
  v = d.of
  i = v === nothing ? nothing : task_place(v, d.key)
  i === nothing && return Box(width(0px), height(DETAILS_H))
  t = v.tasks[i]
  d.less === nothing && (d.less = own!(d, DayButton(by=-1)); d.more = own!(d, DayButton(by=1)))
  first_name = isempty(t.after) ? "" : v.tasks[t.after[1]].todo.name
  waits = isempty(t.after) ? "" : length(t.after) > 1 ? "after $(length(t.after)) tasks" :
          "after " * (length(first_name) > 30 ? first(first_name, 29) * "…" : first_name)
  dot() = Box(label("·", 12px, color=colours.faint))
  # Under the line, they float over the text of the next line
  look = d.floats ? (background(colours.float), border(1px, :solid, colours.line), lifted) : (background(colours.bg),)
  Row(height(DETAILS_H), padding(8px, 0px), child_gap=6px, Alignment.Center, radius(6px), look..., name="Task",
    Icon("calendar-event", size=12px, color=colours.dim), Box(label(task_days(t), 12px, color=colours.dim)), dot(),
    d.less, Box(label(Schedules.days_text(t.days), 12px)), d.more,
    (isempty(waits) ? () : (dot(), Box(label(waits, 12px, color=colours.dim))))...)
end

cursor(::TaskDetails) = :arrow
# A click beside a button does nothing, and doesn't move the caret
onkey(::TaskDetails, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::TaskDetails, ::MouseMove) = handled

"The task that the details `d` show, or nothing when the page has it no more"
task_of(d::TaskDetails) = (i = d.of === nothing ? nothing : task_place(d.of, d.key); i === nothing ? nothing : d.of.tasks[i])

describe(b::DayButton) = begin
  t = task_of(b.parent)
  off = b.by < 0 && (t === nothing || t.days <= 1)
  Box(width(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center, name="Button",
      background(ishovered(b) && !off ? colours.hover : clear),
    Icon(b.by < 0 ? "dash" : "plus", size=13px, color=off ? colours.faint : colours.dim))
end

cursor(::DayButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::DayButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::DayButton, ev::MouseMove) = begin
  show_tooltip!(ev.window, tip_label(b.by < 0 ? "A day shorter" : "A day longer"), b.rect..., placement=:top, gap=6px)
  handled
end

onkey(b::DayButton, ev::KeyPress{Keys.mouse_left}) = begin
  d = b.parent
  t = task_of(d)
  hide_tooltip!(ev.window)
  (t === nothing || t.days + b.by < 1) && return handled
  Schedules.days!(d.of.data, t, t.days + b.by)
  commit!(d.of)
  handled
end

# --- a picture, a diagram or a page that fills the window ---------------------------------
#
# While the mouse is over a picture, a diagram, a page of a PDF file, a model or
# a video, a button shows beside its top right corner, so it covers none of it.
# The button makes it fill the window, over the page and under the top bar.
# Esc, or the button with a cross, puts the page back where it was.
#
#   - A picture, a diagram and a page of a PDF file fit the window at first.
#     Pinch, or scroll with ⌘ held, to make one bigger or smaller round the
#     mouse. ⌘+, ⌘- and the buttons under it do the same, and ⌘0 fits it to
#     the window again. Drag it, or scroll, to move it.
#   - A pinch outwards on a picture, a diagram or a page in the page makes it
#     fill the window too.
#   - ← and → go to the page before and the next page of a PDF file. The page
#     that shows in the document goes on from the page you looked at.
#   - A model and a video only fill the window. A model turns and zooms there
#     as it does in the page, and a video plays on.
#
# A diagram is drawn again at each size, so it's sharp however big it is, and so
# is a page of a PDF file once it stops moving. A picture is as sharp as its pixels.

const ZOOM_EDGE = 24.0   # px of room round a picture that fits the window
const BAR_ROOM = 64px    # the bottom of the window, where the bar of buttons is
const MOST_ZOOM = 8.0    # the biggest a picture gets: this many times its own size, or the size that fits the window if that's bigger
const ZOOM_STEP = 1.25   # how much bigger the + button, and ⌘+, make a picture
"The keys with ⌘ that do what they always do while a picture fills the window. The rest would change the page under it."
const PAGE_KEYS = (Keys.s, Keys.o, Keys.p, Keys.w, Keys.comma, Keys.backslash)

"What fills the window, over the page"
@def mutable struct ZoomView <: SemanticUI
  what::Any = nothing                       # (:picture, key), (:diagram, code), (:pdf, path, page) or (:node, node). Nothing while the page shows.
  path::String = ""                         # the document it was opened from. It closes when another document shows.
  from::Any = nothing                       # the node of the page that it was opened from
  page::Int = 1                             # of a PDF file
  pages::Int = 1
  zoom::Float64 = 0.0                       # px of the window to a px of the picture at its own size. 0 fits it to the window.
  at::Tuple{Float64,Float64} = (0.0, 0.0)   # the point of the picture at the view's top left
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the view is in the window: its left, top, width and height
  fits::Bool = true                         # it shows the whole picture, so it fits the window again when the window changes size
  grab::Any = nothing                       # where a drag started, and the point of the picture that was at the view's top left then
  moved::Float64 = 0.0                      # when the view last moved
  sharp::Sharp = Sharp(nothing, C_NULL, 1.0)
  drawn::Any = nothing                      # a diagram laid out at its own size, with what it was laid out for
  home::Any = nothing                       # how tall a model or a video was in the page
  held::px = 0px                            # the room that a model or a video took in the page, which the page keeps for it
  pinned::px = 0px                          # how far the page was scrolled
  parts::Dict{Any,Any} = Dict{Any,Any}()    # its buttons and its area, kept between frames
end

"The part of a ZoomView that shows the picture. It takes the mouse and the keys."
@def mutable struct ZoomArea <: SemanticUI
  of::Any = nothing
end

"""
A picture, a diagram, a page, a model or a video in the page that can fill the
window. It's a node of its own so that the window knows where it is, to put
its button beside it.
"""
@def mutable struct Fillable <: SemanticUI
  what::Any = nothing      # what fills the window. See ZoomView.
  content::Any = nothing   # what shows in the page
  sizing::Any = ()         # how wide it is
  button::Any = nothing       # its FillButton, once it has shown
  transcript::Any = nothing   # a video's TranscriptButton, once it has shown
end

"The button beside the top right corner of a Fillable that makes it fill the window"
@def mutable struct FillButton <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end

const FILL_SIDE = 24px   # how wide and how tall the button is that makes a picture fill the window
const FILL_GAP = 4px     # between that button and the picture, and between it and the window's edge

"A part of `v` that's kept between frames"
part!(make, v::ZoomView, key) = begin
  node = get!(make, v.parts, key)
  node.parent === nothing && setfield!(node, :parent, v)
  node
end

"The ZoomView of `e` while it fills the window, or nothing"
zooming(e) = (v = get(e.nodes, :zoom, nothing); v === nothing || v.what === nothing ? nothing : v)

"True when `a` and `b` say the same thing fills the window. A node is the same node, not one like it."
same_what(a, b) = a !== nothing && b !== nothing && a[1] == b[1] && (a[1] == :node ? a[2] === b[2] : a == b)

"True when `node`, a model or a video, fills the window now"
zoomed_node(e, node) = (v = zooming(e); v !== nothing && v.what[1] == :node && v.what[2] === node)

"The empty room that the page keeps for the model or the video that fills the window"
held_room(e) = Box(width(grow=grow), height(zooming(e).held))

"What fills the window when you click the button over `x`, a node that a live block made, or nothing if it has no button"
fill_what(x) = x isa Mermaid ? (isdiagram(x.code) ? (:diagram, x.code) : nothing) : x isa Union{STLViewer,VideoPlayer} ? (:node, x) : nothing

"How wide `x` is at most in the page, for the button over its top right corner: a width, or :grow when it's as wide as the page"
fill_wide(x) = x isa VideoPlayer ? video_wide(x) : x isa Mermaid && x.made !== nothing && hasproperty(x.made[2], :w) ? px(x.made[2].w) : :grow

"How wide the picture of a video is at most: as wide as a picture of its height is, as VideoPlayer works it out"
video_wide(p::VideoPlayer) = begin
  s = p.media === nothing ? (0.0, 0.0) : picture_size(p.media)
  s[1] > 0 && s[2] > 0 ? max(240px, p.height * s[1] / s[2]) : :grow
end

"The Fillable of each node of the page that shows one, by the node"
fills(e) = get!(Dict{UInt,Fillable}, e.nodes, :fills)

"""
`content`, which `owner` shows, as a Fillable: while the mouse is over it, a
button beside it makes `what` fill the window. `wide` is how wide the content
is at most: a width, :grow for content that's as wide as the room it's given,
or nothing for content of a fixed size. A model or a video that fills the
window now leaves its room empty.
"""
fillable(owner, what, content; wide=nothing) = begin
  e = editor(owner)
  what[1] == :node && zoomed_node(e, what[2]) && return held_room(e)
  f = get!(() -> own!(owner, Fillable()), fills(e), objectid(owner))
  f.what, f.content = what, content
  f.sizing = wide === nothing ? () : wide === :grow ? (width(grow=grow),) : (width(grow=grow, max=wide),)
  f
end

describe(f::Fillable) = Box(f.sizing..., Alignment.Start, f.content isa GeometricUI ? detach!(f.content) : f.content)

"""
Where the button of a picture that's at `r` in the window goes: beside its top
right corner, so it covers none of the picture. Where the window has no room
there, it's beside the top left corner, and where there's room on neither
side, it's in the top right corner. It stays under the top bar.
"""
fill_spot(e, r) = begin
  w, _ = window_size(e)
  top = min(max(r.top, TOPBAR_H + FILL_GAP), r.top + r.height - FILL_SIDE)
  right = r.left + r.width + FILL_GAP
  right + FILL_SIDE <= w - FILL_GAP && return (right, top)
  left = r.left - FILL_GAP - FILL_SIDE
  left >= panel_w(e) * opened(e) + FILL_GAP && return (left, top)
  (right - 2FILL_GAP - FILL_SIDE, top + FILL_GAP)
end

"The video player that `f` shows, or nothing when it shows something else"
video_of(f::Fillable) = f.what !== nothing && f.what[1] == :node && f.what[2] isa VideoPlayer ? f.what[2] : nothing

"How tall the buttons beside `f` are: a video has the button that shows what was said in it under the first"
buttons_tall(f::Fillable) = video_of(f) === nothing ? FILL_SIDE : 2FILL_SIDE + FILL_GAP

"""
The button that makes the picture under the mouse fill the window, beside it.
A video has a button under that one, which shows what was said in the video.
They show while the mouse is over the picture or the buttons, or between them,
and while the drop-down of what was said is open.
"""
fill_over(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  win === nothing && return ()
  x, y = num(win.mouse[1]), num(win.mouse[2])
  # A picture under a path is in a live block that can fill the window too, so the smallest one under the mouse has the button
  best, spot, least = nothing, nothing, Inf
  for f in values(fills(e))
    r = rect(f)
    r === nothing && continue
    s = fill_spot(e, r)
    if f.transcript !== nothing && f.transcript.open
      best, spot = f, s
      break
    end
    num(min(r.left, s[1])) <= x < num(max(r.left + r.width, s[1] + FILL_SIDE)) || continue
    num(min(r.top, s[2])) <= y < num(max(r.top + r.height, s[2] + buttons_tall(f))) || continue
    area = num(r.width) * num(r.height)
    area < least && ((best, spot, least) = (f, s, area))
  end
  best === nothing && return ()
  b = best.button === nothing ? (best.button = own!(best, FillButton())) : best.button
  buttons = Any[b]
  if video_of(best) !== nothing
    best.transcript === nothing && (best.transcript = own!(best, TranscriptButton()))
    push!(buttons, best.transcript)
  end
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(spot[2], 0px, 0px, spot[1]),
     Column(Alignment.Start, child_gap=FILL_GAP, buttons...)),)
end

describe(b::FillButton) = begin
  ishovered(b) || (b.quiet = false)
  Box(width(FILL_SIDE), height(FILL_SIDE), radius(6px), Alignment.Center, justify=Alignment.Center, name="Button",
      background(ishovered(b) ? colours.hover : colours.float), border(1px, :solid, colours.line),
    Icon("arrows-fullscreen", size=12px, color=colours.dim))
end

cursor(::FillButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::FillButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::FillButton, ev::MouseMove) = begin
  b.quiet && return handled
  tip = b.parent.what[1] == :node ? "Fill the window" : "Fill the window  pinch"
  # A video's tooltip goes beside the button, so that it doesn't cover the button under it
  show_tooltip!(ev.window, tip_label(tip), b.rect...,
                placement=video_of(b.parent) === nothing ? :bottom : :right, gap=6px)
  handled
end

onkey(b::FillButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  f = b.parent
  zoom_in!(editor(b), f.what, f.parent)
end

"A pinch outwards on a picture, a diagram or a page in the page makes it fill the window"
pinch_open(owner, ev::Pinch) = begin
  ev.scale > 1 || return nothing
  e = editor(owner)
  f = get(fills(e), objectid(owner), nothing)
  (f === nothing || f.what === nothing || f.what[1] == :node) && return nothing
  # Only when the fingers are on the picture, not beside it
  r = rect(f)
  x, y = num(ev.window.mouse[1]), num(ev.window.mouse[2])
  (r !== nothing && num(r.left) <= x < num(r.left + r.width) && num(r.top) <= y < num(r.top + r.height)) || return nothing
  zoom_in!(e, f.what, owner)
end

onpinch(s::Shown, ev::Pinch) = pinch_open(s, ev)
onpinch(p::Pages, ev::Pinch) = pinch_open(p, ev)
onpinch(v::FileView, ev::Pinch) = pinch_open(v, ev)
onpinch(l::Breadcrumb, ev::Pinch) = pinch_open(l, ev)

"Make `what` fill the window. `from` is the node of the page that shows it."
zoom_in!(e, what, from=nothing) = begin
  v = node!(ZoomView, e, :zoom)
  # A pinch goes on to the page until the next frame is drawn, so it would open it again
  same_what(v.what, what) && return handled
  zoom_out!(v, false)
  v.what, v.path, v.from, v.pinned = what, e.buf.path, from, e.scroll.offset
  v.zoom, v.fits, v.grab, v.drawn = 0.0, true, nothing, nothing
  if what[1] == :pdf
    v.page, v.pages = what[3], max(1, pdf_pages(what[2]))
  elseif what[1] == :node
    r = rect(what[2])
    v.home = what[2].height
    v.held = r === nothing ? what[2].height : r.height
  end
  focus(part!(() -> ZoomArea(of=v), v, :area))
  handled
end

"Put the page back, with a model or a video back in it. `refocus` gives the keyboard back to the text."
zoom_out!(v::ZoomView, refocus=true) = begin
  what = v.what
  what === nothing && return handled
  v.what = nothing
  what[1] == :node && v.home !== nothing && (what[2].height = v.home)
  v.from isa Pages && (v.from.page = v.page)   # the page in the document goes on from the page you looked at
  v.from = nothing
  e = editor(v)
  e.scroll.offset = v.pinned
  refocus && focus(e)
  handled
end

"In each frame: the page comes back when another document shows, and until then it stays where it was"
zoom_tick!(e) = begin
  v = zooming(e)
  v === nothing && return
  v.path == e.buf.path || return zoom_out!(v, false)
  e.scroll.offset = v.pinned
  nothing
end

"What fills the window, over the page and the sidebar and under the top bar"
zoom_over(e) = zooming(e) === nothing ? () :
  (Box(width(grow=grow), height(grow=grow), padding(TOPBAR_H, 0px, 0px, 0px), background(colours.bg), geometry(e.nodes[:zoom])),)

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::ZoomView, key, action; icon="", tip="", off=false) = begin
  b = part!(() -> PlanButton(of=v), v, (:button, key))
  b.action, b.icon, b.tip, b.off = action, icon, tip, off
  b
end

"Do what a button of a ZoomView does"
act!(v::ZoomView, action, w) = begin
  a = action isa Tuple ? action[1] : action
  a == :zoom && return zoom_by!(v, action[2], view_middle(v)...)
  a == :fit && return fit_now!(v)
  a == :page && return turn!(v, action[2])
  a == :close && return zoom_out!(v)
  handled
end

describe(v::ZoomView) = begin
  e = editor(v)
  what = v.what
  bar(buttons...) = Column(width(grow=grow), height(grow=grow), Alignment.Center, justify=Alignment.End, padding(0px, 0px, 16px, 0px),
    Row(height(36px), padding(4px), child_gap=2px, radius(8px), Alignment.Center, background(colours.float),
        border(1px, :solid, colours.line), lifted, buttons...))
  close = button!(v, :close, :close, icon="x-lg", tip="Back to the page  esc")
  if what[1] == :node
    # A model or a video is as tall as the window has room for. Its own bar is under its picture.
    node = what[2]
    _, h = window_size(e)
    node.height = max(160px, h - TOPBAR_H - BAR_ROOM - px(2ZOOM_EDGE) - 44px)
    shows = with_theme(() -> geometry(node), component_theme(e.zoom))
    return Stack(width(grow=grow), height(grow=grow), Alignment.Start,
      Column(width(grow=grow), height(grow=grow), Alignment.Center, padding(px(ZOOM_EDGE)), shows),
      bar(close))
  end
  what[1] == :diagram && lay_diagram!(v)
  # The view is the whole window under the top bar, so it's fitted here, and the bar says how big the picture is in this frame
  w, h = window_size(e)
  reframe!(v, (0.0, num(TOPBAR_H), num(w), num(h) - num(TOPBAR_H)))
  buttons = Any[button!(v, :smaller, (:zoom, 1 / ZOOM_STEP), icon="zoom-out", tip="Smaller  pinch, or ⌘ and scroll"),
                Box(width(46px), Alignment.Center, justify=Alignment.Center,
                    label(v.zoom > 0 ? "$(round(Int, 100v.zoom))%" : "", 12px, color=colours.dim)),
                button!(v, :bigger, (:zoom, ZOOM_STEP), icon="zoom-in", tip="Bigger  pinch, or ⌘ and scroll"),
                button!(v, :fit, :fit, icon="aspect-ratio", tip="Fit the window  ⌘0")]
  if what[1] == :pdf && v.pages > 1
    push!(buttons, button!(v, :back, (:page, -1), icon="chevron-left", tip="The page before  ←", off=v.page <= 1),
          Box(Alignment.Center, padding(4px, 0px), label("Page $(v.page) of $(v.pages)", 12px, color=colours.dim)),
          button!(v, :on, (:page, 1), icon="chevron-right", tip="The next page  →", off=v.page >= v.pages))
  end
  push!(buttons, close)
  Stack(width(grow=grow), height(grow=grow), Alignment.Start, part!(() -> ZoomArea(of=v), v, :area), bar(buttons...))
end

describe(::ZoomArea) = Box(width(grow=grow), height(grow=grow))
cursor(::ZoomArea) = :arrow

"""
Lay the diagram of `v` out at its own size, in the page's font and colours, to
draw at any size. It's laid out again when the font or the colours change.
"""
lay_diagram!(v::ZoomView) = begin
  e = editor(v)
  code = v.what[2]
  key = (code, e.theme, e.font, e.zoom)
  v.drawn !== nothing && v.drawn[1] == key && return v.drawn[2]
  m = own!(v, Mermaid(code))
  root = with_theme(component_theme(e.zoom)) do
    inner = geometry(m)
    made = m.made === nothing ? nothing : m.made[2]
    (made === nothing || !hasproperty(made, :w) || made.w <= 0) && return nothing
    describe(Column(fixed(px(made.w)), Alignment.Start, inner), (px(made.w), 99999px))
  end
  v.drawn = (key, root)
  root
end

"How wide and how tall what `v` shows is at its own size, in px, or nothing when it can't be shown"
subject_size(v::ZoomView) = begin
  what = v.what
  what === nothing && return nothing
  if what[1] == :picture
    has_image(what[2]) || return nothing
    s = image_source(what[2])
    n = natural(what[2])
    n === nothing ? (Float64(s.width), Float64(s.height)) : (Float64(n[1]), Float64(n[2]))
  elseif what[1] == :diagram
    root = v.drawn === nothing ? nothing : v.drawn[2]
    root === nothing ? nothing : (num(root.width), num(root.height))
  elseif what[1] == :pdf
    s = pdf_size(what[2], v.page)
    s === nothing ? nothing : (Float64(s[1]), Float64(s[2]))
  end
end

"The middle of the part of the view that's above the bar of buttons"
view_middle(v::ZoomView) = (v.box[1] + v.box[3] / 2, v.box[2] + (v.box[4] - num(BAR_ROOM)) / 2)

"How many px to a px of the picture fits the whole of something `s` big in the view, above the bar and with room round it"
fit_zoom(v::ZoomView, s) = max(min((v.box[3] - 2ZOOM_EDGE) / s[1], (v.box[4] - num(BAR_ROOM) - 2ZOOM_EDGE) / s[2]), 1e-3)

"Show the whole picture, in the middle of the view"
fit!(v::ZoomView, s) = (v.zoom = fit_zoom(v, s); v.fits = true; hold!(v, s))

"""
Keep the picture in the view. Where it's narrower than the view, it stays in
the middle, and so it does where it's shorter. Otherwise it moves no further
than its edges, with room round them.
"""
hold!(v::ZoomView, s) = begin
  w, h = v.box[3] / v.zoom, (v.box[4] - num(BAR_ROOM)) / v.zoom
  edge = ZOOM_EDGE / v.zoom
  v.at = (s[1] + 2edge <= w ? (s[1] - w) / 2 : clamp(v.at[1], -edge, s[1] - w + edge),
          s[2] + 2edge <= h ? (s[2] - h) / 2 : clamp(v.at[2], -edge, s[2] - h + edge))
  v
end

"Note that the view is now `box`. A picture that fitted the old view fits the new one."
reframe!(v::ZoomView, box) = begin
  s = subject_size(v)
  changed, v.box = box != v.box, box
  s === nothing && return v
  v.zoom <= 0 || (v.fits && changed) ? fit!(v, s) : hold!(v, s)
end

"Note that the view moved just now, and keep the picture in it"
moved!(v::ZoomView, s) = begin
  v.moved = time()
  hold!(v, s)
  v.fits = v.zoom <= fit_zoom(v, s) * 1.0001
  handled
end

"Fit the picture to the window again"
fit_now!(v::ZoomView) = (s = subject_size(v); s === nothing || fit!(v, s); handled)

"Make the picture `by` times as big. The point of it at the place `(x, y)` in the window stays there."
zoom_by!(v::ZoomView, by, x, y) = begin
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  p = (v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom)
  f = fit_zoom(v, s)
  v.zoom = clamp(v.zoom * by, min(f, 1.0), max(f, 1.0) * MOST_ZOOM)
  v.at = (p[1] - (x - v.box[1]) / v.zoom, p[2] - (y - v.box[2]) / v.zoom)
  moved!(v, s)
end

"Go on by `by` pages of a PDF file, as far as the first page or the last"
turn!(v::ZoomView, by) = begin
  page = clamp(v.page + by, 1, v.pages)
  page == v.page && return handled
  v.page, v.zoom, v.fits = page, 0.0, true
  handled
end

draw(ctx, size, ui::ConcreteRect, a::ZoomArea) = begin
  v = a.of
  v.what === nothing && return
  reframe!(v, (num(ui.left), num(ui.top), num(ui.width), num(ui.height)))
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return
  with_clip(() -> zoom_ink(ctx, v, s), ctx, ui.left, ui.top, ui.width, ui.height)
end

"Draw what `v` shows, which is `s` big at its own size"
zoom_ink(ctx, v::ZoomView, s) = begin
  x, y = v.box[1] - v.at[1] * v.zoom, v.box[2] - v.at[2] * v.zoom
  w, h = s[1] * v.zoom, s[2] * v.zoom
  kind = v.what[1]
  if kind == :picture
    image = image_source(v.what[2])
    paint_picture(ctx, image.raw, (0, 0, image.width, image.height), (x, y, w, h))
  elseif kind == :diagram
    # The diagram is drawn at its own size onto a canvas that's made bigger, so its lines and its words stay sharp
    root = v.drawn[2]
    Skia.sk_canvas_save(ctx)
    Skia.sk_canvas_translate(ctx, Float32(x), Float32(y))
    Skia.sk_canvas_scale(ctx, Float32(v.zoom), Float32(v.zoom))
    Skia.sk_canvas_translate(ctx, -Float32(num(root.left)), -Float32(num(root.top)))
    try
      draw(ctx, root.size, root)
    finally
      Skia.sk_canvas_restore(ctx)
    end
  else
    paper = (x, y, w, h)
    paper!(ctx, paper)
    with_round_clip(() -> pdf_ink(ctx, v, paper), ctx, px(x), px(y), px(w), px(h), px(PAPER_ROUND))
  end
end

"Draw the part of a PDF page that's in the view, at the screen's own pixels. While it moves, a rougher picture of the whole page shows."
pdf_ink(ctx, v::ZoomView, paper) = begin
  left, top, wide, tall = v.box
  path = v.what[2]
  d = clamp(density(ctx), 2, 3)
  w, h = round(Int, wide * d), round(Int, tall * d)
  (w < 1 || h < 1) && return
  k = v.zoom * d   # the screen's pixels to a point of the page
  of = (path, mtime(path), v.page, k, v.at, w, h)
  p = v.sharp
  if p.of != of && p.cost > QUICK && time() - v.moved < SETTLED
    rough = pdf_page(path, v.page, 2000)
    if rough !== nothing
      r = image_source(rough)
      paint_picture(ctx, r.raw, (0, 0, r.width, r.height), paper)
    end
    redraw_in!(v, SETTLED)
    return
  end
  image = sharpen!(p, path, v.page, of, k, v.at[1] * k, v.at[2] * k, w, h)
  image == C_NULL || paint_picture(ctx, image, (0, 0, w, h), (left, top, wide, tall))
end

# A click starts a drag that moves the picture
onkey(a::ZoomArea, ev::KeyPress{Keys.mouse_left}) = begin
  w = ev.window
  focus(a)
  a.of.grab = ((num(w.mouse[1]), num(w.mouse[2])), a.of.at)
  handled
end

onmouse(a::ZoomArea, ev::MouseMove) = begin
  v = a.of
  g = v.grab
  g === nothing && return handled
  Keys.mouse_left in ev.window.keys || (v.grab = nothing; return handled)
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  (x0, y0), at = g
  x, y = num(ev.position[1]), num(ev.position[2])
  v.at = (at[1] - (x - x0) / v.zoom, at[2] - (y - y0) / v.zoom)
  moved!(v, s)
end

# Scrolling with ⌘ held makes the picture bigger or smaller, round the mouse. Scrolling without ⌘ moves it.
onscroll(a::ZoomArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  Keys.cmd in w.keys && return zoom_by!(v, exp(num(ev.delta[2]) / 10), num(w.mouse[1]), num(w.mouse[2]))
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  v.at = (v.at[1] - 30num(ev.delta[1]) / v.zoom, v.at[2] - 30num(ev.delta[2]) / v.zoom)
  moved!(v, s)
end

# Two fingers that move apart or together on the trackpad make the picture bigger or smaller, round the mouse
onpinch(a::ZoomArea, ev::Pinch) = zoom_by!(a.of, ev.scale, num(ev.window.mouse[1]), num(ev.window.mouse[2]))

# The keys are the view's, so none of them change the page under it. A right-click has no menu here.
onkey(a::ZoomArea, ev::KeyPress{K}) where K = ismouse(K) && K != Keys.mouse_right ? nothing : zoom_key!(a.of, K, ev.window)
ontype(::ZoomArea, ::Typed) = handled

"""
Do what the key `K` does while `v` fills the window. It's `handled`, or nothing
for a key with ⌘ that the page still takes, like ⌘S.
"""
zoom_key!(v::ZoomView, K, w) = begin
  cmd = Keys.cmd in w.keys
  K == Keys.escape && return zoom_out!(v)
  cmd && K in PAGE_KEYS && return nothing
  v.what[1] == :node && return handled
  cmd && K == Keys.equal && return zoom_by!(v, ZOOM_STEP, view_middle(v)...)
  cmd && K == Keys.minus && return zoom_by!(v, 1 / ZOOM_STEP, view_middle(v)...)
  cmd && K == getproperty(Keys, Symbol(0)) && return fit_now!(v)
  !cmd && v.what[1] == :pdf && K in (Keys.left, Keys.right) && return turn!(v, K == Keys.left ? -1 : 1)
  handled
end

# --- front matter as a card ---------------------------------------------------------
#
# While the caret isn't in it, front matter shows as a card: a small FRONTMATTER
# heading, then each key with what it's set to. A click on the card puts the
# caret in the line that was clicked, and the lines show as they're written.

"Front matter, shown as a card"
@def mutable struct MatterCard <: SemanticUI
  rows::Vector{Tuple{Int,String,String}} = Tuple{Int,String,String}[]   # the line, the key and what it's set to
  size::px = 13px                                                       # of the text
end

"A key of front matter and what it's set to, in its card"
@def mutable struct MatterRow <: SemanticUI
  line::Int = 0
  key::String = ""
  value::String = ""
  keys::px = 0px    # how wide the widest key is, so that what each is set to starts in one place
  size::px = 13px
end

"""
The keys of the front matter that ends at line `t`, each with the line it's on and
what it's set to. A line that goes on from the one above, like an item of a list,
joins what that key is set to. A comment isn't shown.
"""
matter_rows(lines, t) = begin
  toml = rstrip(lines[1]) == "+++"
  key = toml ? r"^\s*((?:\"[^\"]*\"|'[^']*'|[\w.-])+)\s*=\s*(.*)$" : r"^([^:#\s-][^:#]*):(?:\s+(.*)|$)"
  rows = Tuple{Int,String,String}[]
  for i in 2:t-1
    text = rstrip(lines[i])
    (isempty(strip(text)) || startswith(lstrip(text), '#')) && continue
    m = match(key, text)
    if m !== nothing
      push!(rows, (i, String(m[1]), something(m[2], "")))
    elseif toml && startswith(lstrip(text), '[') && !isempty(rows) && !endswith(last(rows)[3], ',') && !endswith(last(rows)[3], '[')
      push!(rows, (i, String(strip(text)), ""))   # a [table] that starts a group of keys
    elseif isempty(rows)
      push!(rows, (i, "", String(strip(text))))
    else
      # An item of a list, or the next part of a value that goes over several lines
      at, k, v = pop!(rows)
      part = strip(replace(strip(text), r"^-\s+" => ""))
      push!(rows, (at, k, isempty(v) ? String(part) : endswith(v, '[') ? v * part : v * (startswith(text, r"\s*-\s") ? ", " : " ") * part))
    end
  end
  rows
end

"The front matter that ends at line `t`, as a card"
matter_card(e, t) = begin
  card = node!(MatterCard, e, :matter)
  card.rows = matter_rows(e.buf.lines, t)
  card.size = body(e).size * 0.76
  own!(node!(Document, e, :document), card)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(card)), (e.width, 9999px))
  Live(card, concrete.height + 2LIVE_GAP)
end

describe(c::MatterCard) = begin
  s = c.size
  keyface = Face(SANS, "Semibold", s, colours.dim, false)
  keys = maximum(r -> measure(keyface, r[2]), c.rows, init=0px)
  Column(width(grow=grow), Alignment.Start, padding(s, s * 0.7), child_gap=s * 0.4, radius(6px),
         border(1px, :solid, colours.line), background(colours.block), name="Front matter",
    # The heading has a little more room under it than the rows have between them
    Box(padding(0px, 0px, s * 0.2, 0px), label("FRONTMATTER", s * 0.72, color=colours.dim, weight="Bold")),
    [MatterRow(line=at, key=k, value=v, keys=keys, size=s) for (at, k, v) in c.rows]...)
end

describe(r::MatterRow) = begin
  s, keys = r.size, r.keys
  Row(width(grow=grow), Alignment.Start, padding(0px, s * 0.15), child_gap=(keys > 0px ? s * 0.9 : 0px),
    (keys > 0px ? (Box(fixed(keys), label(r.key, s, color=colours.dim, weight="Semibold")),) : ())...,
    Box(width(grow=grow), Alignment.Start, Text(r.value, size=s, family=SANS, color=colours.ink, wrap=WrapMode.words)))
end

cursor(::Union{MatterCard,MatterRow}) = :ibeam

"Put the caret at the end of line `i` of the front matter, so it shows as it's written"
edit_matter!(node, i) = begin
  e = editor(node)
  b = e.buf
  b.caret = b.anchor = (i, length(b.lines[i]))
  focus(e)
  touch!(e)
  handled
end

onkey(r::MatterRow, ::KeyPress{Keys.mouse_left}) = edit_matter!(r, r.line)
onkey(c::MatterCard, ::KeyPress{Keys.mouse_left}) = edit_matter!(c, isempty(c.rows) ? 1 : first(c.rows)[1])

# The code of a live block can load methods that are newer than the frame that
# ran it, so the node is described with the newest methods there are
geometry(node::SemanticUI) = Base.invokelatest(convert, GeometricUI, node)
geometry(node::GeometricUI) = detach!(node)

"How wide the page's text is in the window"
text_width(e) = begin
  w, _ = window_size(e)
  # While the sidebar slides, the text keeps the width it has beside the
  # sidebar, so it doesn't wrap again on each frame
  # The numbers of a file's lines have room on the left of the text
  room = w - (e.panel || sliding(e) ? panel_w(e) : 0px) - 2PAGE_X - gutter(e)
  # A file of code or of text takes all the room that the window has. A page is no wider than the settings say.
  numbered(e.buf) ? max(room, 240px) : clamp(room, 240px, e.widest * e.zoom)
end

"""
How far the left edge of the page's text is from the left edge of the window.
A page's text is in the middle of the space beside the file panel. A file with
numbered lines starts at the left of that space, after its numbers, unless it's
scrolled to the right.
"""
text_left(e) = begin
  w, _ = window_size(e)
  side = panel_w(e) * opened(e)
  numbered(e.buf) ? side + PAGE_X + gutter(e) - sideways(e) : side + max(PAGE_X, (w - side - e.width) / 2)
end

"Work out what the page shows and how tall each part is, for text that's `width` wide"
layout!(e, width=text_width(e)) = begin
  b = e.buf
  ks = kinds(b)
  width == e.width || (e.width = width; empty!(e.flows))
  # A file that's only shown is one viewer, or lines of text that are laid out once and kept
  b.view == :file && return e.layout = [file_item(e, b)]
  readonly(b) && return e.layout = get!(() -> text_items(e, b), e.flows, (:shown, b.path, b.version))
  items = Item[]
  top = 0px
  i = 1
  n = length(b.lines)
  plans = 0   # how many takeoff blocks there have been so far
  schedules = 0   # and how many schedules
  while i <= n
    j = i
    if ks[i].kind == Kind.table
      while j < n && ks[j+1].kind == Kind.table
        j += 1
      end
    end
    # Front matter shows as a card, unless the caret is in it
    if i == 1 && ks[1].kind == Kind.fence && ks[1].lang in (MATTER, TOML_MATTER) && !incode(b, 1)
      t = front_matter(b.lines)
      if t > 1
        content = matter_card(e, t)
        push!(items, Item(1, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A `takeoff` code block shows its plan and its measures, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == TAKEOFF
      plans += 1   # each takeoff keeps its view by its place among the page's takeoffs
      t = codeblock(b, i)[2]
      if !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        content = takeoff_item(e, i, t, plans)
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A `schedule` code block shows the page's tasks on a line of days, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == SCHEDULE
      schedules += 1
      t = codeblock(b, i)[2]
      if !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        content = schedule_item(e, i, t, schedules)
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A `ui` code block shows what its code makes, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == LIVE && !incode(b, i)
      t = codeblock(b, i)[2]
      if t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        content = live(e, join(b.lines[i+1:t-1], "\n"))
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A `mermaid` code block shows its diagram, unless the caret is in it. Code that can't be drawn as a diagram shows as code.
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == DIAGRAM && !incode(b, i)
      t = codeblock(b, i)[2]
      content = t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? diagram(e, join(b.lines[i+1:t-1], "\n")) : nothing
      if content !== nothing
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A `sheet` code block is drawn as a sheet, and a `spreadsheet` one as a spreadsheet, unless the caret is on its first or last line
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang in (SHEET, SPREADSHEET)
      run = drawn(b, i, ks[i].lang)
      if run !== nothing
        content = ks[i].lang == SHEET ? sheetgrid(e, run...) : spreadgrid(e, run...)
        push!(items, Item(i, run[2], top, tall(content), content))
        top += tall(content)
        i = run[2] + 1
        continue
      end
    end
    # A line that holds only a picture shows the picture, unless the caret is on the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && occursin("![", b.lines[i])
      content = picture_item(e, i)
      if content !== nothing
        push!(items, Item(i, i, top, content.tall, content))
        top += content.tall
        i += 1
        continue
      end
    end
    # A table needs its line of dashes. It shows as plain lines while the caret is on that line.
    if j > i && isdivider(b.lines[i+1]) && !israw(b, i + 1)
      content = grid(e, i, j)
      push!(items, Item(i, j, top, tall(content), content))
      top += tall(content)
      i = j + 1
    else
      content = flow(e, i)
      push!(items, Item(i, i, top, tall(content), content))
      top += tall(content)
      i += 1
    end
  end
  e.layout = items
end

"The item that shows line `i`"
item(e, i::Int) = e.layout[something(findfirst(it -> it.first <= i <= it.last, e.layout), length(e.layout))]

"Scroll so the caret is on screen"
reveal!(e) = begin
  e.buf.view == :file && return   # a viewer has no caret
  it = item(e, e.buf.caret[1])
  top, bottom = it.top, it.top + it.tall
  if it.content isa Flow
    k, x = spot(it.content, e.buf.caret[2])
    top = it.top + line_top(it.content, k)
    bottom = top + it.content.lines[k].high
    # A long line that doesn't wrap scrolls sideways to show the caret, with a little of the line on each side of it
    if !wraps(e)
      b = e.buf
      x < b.across + SIDE_ROOM && (b.across = x - SIDE_ROOM)
      x > b.across + e.width - SIDE_ROOM && (b.across = x - e.width + SIDE_ROOM)
      scroll_sideways!(e, 0px)
    end
  elseif it.content isa Sheet
    r = clamp(e.buf.caret[1] - it.first, 1, length(it.content.rows))
    top = it.top + row_top(it.content, r)
    bottom = top + it.content.heights[r]
  end
  scroll_into_view!(e.scroll, PAGE_TOP + top - 30px, PAGE_TOP + bottom + 40px)
end

# --- drawing the text -----------------------------------------------------------------

"The box of a to-do item: empty, or filled and ticked when the item is done"
todo_box(seg::Seg) = begin
  side = px(round(num(seg.face.size) * 0.82))
  box = seg.text == TODO_DONE ?
    Box(fixed(side), height(side), radius(side * 0.22), Alignment.Center, justify=Alignment.Center, background(colours.accent),
        Icon("check", size=side * 0.9, color=colours.bg)) :
    Box(fixed(side), height(side), radius(side * 0.22), border(1.5px, :solid, colours.marker))
  Box(fixed(seg.w), Alignment.Start, box)
end

describe(seg::Seg) = begin
  # What inline code made is drawn in place of the code
  seg.node === nothing || return Box(fixed(seg.w), Alignment.Start, geometry(seg.node.node))
  isbox(seg) && return todo_box(seg)
  f = seg.face
  t = Text(seg.text, size=f.size, family=f.family, subfamily=f.style, color=f.color, wrap=WrapMode.none)
  # The number of a footnote is at the top of a box as tall as the text beside it, so it sits high in the line
  seg.atomic && startswith(seg.link, '^') && !endswith(seg.text, ' ') && return Box(fixed(seg.w), height(f.size * 1.9), Alignment.Start, t)
  # A Text on its own would take a share of the spare room in its row
  f.chip || return Box(fixed(seg.w), Alignment.Start, t)
  if !isempty(f.lang)
    t = Row(Alignment.Start, [part for tok in tokens(seg.text, f.lang) for part in coloured(tok, f)]...)
  elseif !hasall(f, seg.text)
    t = Row(Alignment.Start, spared(seg.text, f)...)
  end
  Box(fixed(seg.w), height(f.size * 1.5), padding(CHIP_X, 0px), radius(4px), background(colours.chip), border(1px, :solid, colours.chip_line), t)
end

"""
One part of a line of code in a chip, in the colour of its kind, as the parts
of a row. Each is as wide as its text measures, so the caret lines up with it.
"""
coloured(tok, f::Face) =
  spared(tok.text, Face(f, color=tok.kind == :plain ? f.color : getfield(colours, tok.kind), style=tok.kind == :comment ? codeslant() : f.style))

"The lines of a Flow, as rows of text. `edge` is the width of a border on its left."
rows(f::Flow, edge=0px) =
  [Row(width(grow=grow), height(vl.high), padding(0px, 0px, 0px, vl.x - edge), clip=true, map(describe, vl.segs)...) for vl in f.lines]

describe(e::Editor, it::Item) = describe(e, it, it.content)

describe(e::Editor, it::Item, f::Flow) = begin
  k = f.kind
  if k == Kind.rule && !f.raw
    return Box(width(grow=grow), height(tall(f)), Box(width(grow=grow), height(1px), background(colours.line)))
  end
  edge = k == Kind.blockquote ? 3px : 0px
  col = Column(width(grow=grow), Alignment.Start, padding(f.above, 0px, f.below, 0px), rows(f, edge)...)
  if k == Kind.code || k == Kind.fence
    col.background = background(colours.block)
  elseif k == Kind.blockquote
    col.border = border(edge, :solid, colours.line)[:left]
  end
  col
end

describe(e::Editor, it::Item, g::Grid) = begin
  isspread(g) && return spreadsheet(e, it, g)
  line = border(1px, :solid, colours.line; between=true)
  table = Column(width(grow=grow), Alignment.Start, line, name="Table",
    [Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between],
         background(r == 1 ? colours.head : iseven(r) ? colours.bg : colours.stripe),
       [Column(fixed(g.widths[c]), height(grow=grow), Alignment.Start, justify=Alignment.Center, rows(g.flows[r][c])...)
        for c in eachindex(g.widths)]...)
     for r in eachindex(g.rows)]...)
  Box(width(grow=grow), padding(0px, TABLE_GAP), table)
end

describe(e::Editor, it::Item, l::Live) = begin
  Box(width(grow=grow), height(l.tall), Alignment.Start, padding(0px, LIVE_GAP), geometry(l.node))
end

"The kind of block that an item is part of, or nothing for a blank line"
blocktype(it::Item) = begin
  c = it.content
  c isa Grid && return Table
  c isa Sheet && return SheetBlock
  c isa Live ? LiveBlock : blocktype(c.kind)
end

blocktype(k::Kind) =
  k == Kind.paragraph ? Paragraph : k == Kind.heading ? Heading : k in (Kind.bullet, Kind.ordered, Kind.todo) ? List :
  k == Kind.blockquote ? Quote : k in (Kind.code, Kind.fence) ? CodeBlock : k == Kind.table ? Table :
  k == Kind.rule ? Rule : nothing

"The kind of block that line `i` is in. The keys that edit the text do different things in different blocks."
block(b::Buffer, i::Int) = blocktype(kinds(b)[i].kind)

"The items as the nodes of the document: one for each paragraph, list, table and so on"
blocks(d::Document, items) = begin
  ks = kinds(editor(d).buf)
  out, group, T = Any[], Item[], nothing
  close() = begin
    isempty(group) && return
    T === nothing ? append!(out, group) : push!(out, own!(d, T(first=group[1].first, last=group[end].last, items=copy(group))))
    empty!(group)
  end
  for it in items
    U = blocktype(it)
    # A heading, a rule, a table and a live block each stand alone, and a ``` line that opens a block starts a new one
    alone = U in (Heading, Rule, LiveBlock, SheetBlock) || it.content isa Grid || (U === CodeBlock && ks[it.first].kind == Kind.fence && ks[it.first].level == 0)
    (U !== T || alone) && close()
    T = U
    push!(group, it)
  end
  close()
  out
end

describe(b::Block) = Column(width(grow=grow), Alignment.Start, [describe(editor(b), it) for it in b.items]...)

describe(d::Document) = begin
  e = editor(d)
  items = e.layout
  total = isempty(items) ? 0px : last(items).top + last(items).tall
  _, h = window_size(e)
  # Only the lines on screen, and a few either side, are built
  from, to = e.scroll.offset - PAGE_TOP - 200px, e.scroll.offset + h + 200px
  lo = something(findfirst(it -> it.top + it.tall >= from, items), length(items))
  hi = something(findlast(it -> it.top <= to, items), lo)
  e.shown = lo:hi
  # Each row of text cuts off what's past its end, so long lines that don't wrap need a page as wide as the longest
  Column(fixed(wraps(e) ? e.width : max(e.width, e.reach + SIDE_ROOM)), Alignment.Start, name="Document",
    spacer(items[lo].top),
    [x isa Item ? describe(e, x) : x for x in blocks(d, items[lo:hi])]...,
    spacer(total - items[hi].top - items[hi].tall))
end

# With ⌘ held, a click on a link opens it, so the mouse shows a hand there
cursor(d::Document) = begin
  e = editor(d)
  e.buf.view == :file && return :arrow   # a viewer has no text to select
  w = window_of(e)
  w === nothing && return :ibeam
  # A click on a to-do item's box ticks it
  todo_at(e, w.mouse) === nothing || return :hand
  Keys.cmd in w.keys && link_at(e, w.mouse) !== nothing ? :hand : :ibeam
end

"""
The room under the last line of the page. A code file scrolls on until its last
lines are at the top of the window, so a box that opens under them has room to
show.
"""
page_bottom(e) = numbered(e.buf) ? max(PAGE_BOTTOM, e.scroll.viewport - CODE_END) : PAGE_BOTTOM

describe(p::Page) = begin
  e = editor(p)
  # Long lines that don't wrap go on to the right edge of the window. The text moves left as the page
  # scrolls sideways. None of it shows past the edges of the page, and the numbers of the lines go over it.
  page = wraps(e) ?
    Row(width(grow=grow), Alignment.Start, justify=numbered(e.buf) ? Alignment.Start : Alignment.Center,
        padding(PAGE_TOP, PAGE_X, page_bottom(e), PAGE_X + gutter(e)),
      node!(Document, e, :document)) :
    Row(width(grow=grow), Alignment.Start, padding(PAGE_TOP, 0px, page_bottom(e), PAGE_X + gutter(e)), clip_x=true,
      Box(Alignment.Start, offset_x=-sideways(e), node!(Document, e, :document)))
  reuse!(e.scroll, guide_under(e, page))
end

"""
Put a faint line down a file of code, under the text of `page`, after the
number of characters that the settings page chooses. It moves with the text
when the page scrolls sideways.
"""
guide_under(e, page) = begin
  (e.guide > 0 && numbered(e.buf)) || return page
  x = PAGE_X + gutter(e) + measure(face(e, Line(Kind.code, 0, 0, "")), "0") * e.guide - sideways(e)
  Stack(width(grow=grow), Alignment.Start,
    Box(fixed(1px), height(grow=grow), background(colours.line), offset_x=x),
    page)
end

"The part of line `i` that's selected, as columns, and whether the selection goes on past it"
selected(b::Buffer, i::Int) = begin
  lo, hi = selection(b)
  (lo[1] <= i <= hi[1] && lo != hi) || return nothing
  (i == lo[1] ? lo[2] : 0, i == hi[1] ? hi[2] : length(b.lines[i]), i < hi[1])
end

const Rect = NTuple{4,Float64}   # left, top, right and bottom, in px

"""
The boxes that cover the selected part of each line of `f`, whose top left
corner is at (x, y). The first and last boxes take in the space above and below
the lines, so the boxes of one line of the document meet those of the next.
With `margin`, a box that starts at the start of its line also takes in the
space to the left of the text, like the inset of a code block. That keeps the
left edge of the selection straight from one kind of line to the next.
"""
marks(f::Flow, x, y, (from, to, more); margin=true) = begin
  out = Rect[]
  n = length(f.lines)
  for (k, vl) in enumerate(f.lines)
    (from <= vl.to && to >= vl.from) || continue
    x1 = from > vl.from ? xcol(vl, from) : margin ? 0px : vl.x
    x2 = xcol(vl, min(to, vl.to))
    # A little extra shows that the end of the line is selected too
    (to > vl.to || (more && k == n)) && (x2 += 7px)
    x2 > x1 || continue
    top = k == 1 ? 0px : line_top(f, k)
    bottom = line_top(f, k) + vl.high + (k == n ? f.below : 0px)
    push!(out, (num(x + x1), num(y + top), num(x + x2), num(y + bottom)))
  end
  out
end

const SELECTION_RADIUS = 4.0

"""
Fill the selection. Boxes that sit on top of each other are joined into one
shape, and every corner of that shape is rounded, the ones that point in as
well as the ones that point out.
"""
fill_selection(ctx, rects::Vector{Rect}) = begin
  isempty(rects) && return
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colours.select))
  from = 1
  for i in 2:length(rects)+1
    # A box joins the one above it when they touch and share some width
    joined = i <= length(rects) && abs(rects[i][2] - rects[i-1][4]) < 1 &&
             rects[i][1] < rects[i-1][3] && rects[i][3] > rects[i-1][1]
    joined && continue
    outline = rounded(corners(rects[from:i-1]), SELECTION_RADIUS)
    Skia.sk_canvas_draw_path(ctx, outline, paint)
    Skia.sk_path_delete(outline)
    from = i
  end
  Skia.sk_paint_delete(paint)
end

"The corners of the shape made by a stack of boxes: down its right side, then back up its left"
corners(rects) = begin
  points = NTuple{2,Float64}[]
  add(p) = (isempty(points) || points[end] != p) && push!(points, p)
  top = rects[1][2]
  for (l, t, r, b) in rects
    add((r, top)); add((r, b))
    top = b
  end
  for (i, (l, t, r, b)) in Iterators.reverse(enumerate(rects))
    add((l, b)); add((l, i == 1 ? t : rects[i-1][4]))
  end
  points
end

"A Skia path around `points`, with each corner rounded by up to `radius`"
rounded(points, radius) = begin
  path = Skia.sk_path_new()
  n = length(points)
  for i in 1:n
    before, corner, after = points[mod1(i - 1, n)], points[i], points[mod1(i + 1, n)]
    d1, d2 = hypot((before .- corner)...), hypot((after .- corner)...)
    # A short edge has room for less of a curve at each end
    r = min(radius, d1 / 2, d2 / 2)
    a = corner .+ (before .- corner) .* (r / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (r / max(d2, 1e-6))
    i == 1 ? Skia.sk_path_move_to(path, Float32(a[1]), Float32(a[2])) : Skia.sk_path_line_to(path, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(path, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  Skia.sk_path_close(path)
  path
end

"Draw the caret at column `col` of `f`, whose top left corner is at (x, y)"
caret(ctx, e, f::Flow, x, y, col) = begin
  w = window_of(e)
  (w !== nothing && w.focus === e) || return
  since = time() - e.blink
  (since < 0.5 || mod(since - 0.5, 1.0) >= 0.5) || return
  k, cx = spot(f, col)
  high = f.size * 1.25
  rectangle(ctx, x + cx - 0.75px, y + line_top(f, k) + (f.lines[k].high - high)/2, 1.5px, high, background=colours.ink, border=0px)
end

# The caret and the selection are drawn over the text, once it has been placed
draw(ctx, size, ui::ConcreteRect, d::Document) = begin
  e = editor(d)
  b = e.buf
  e.origin = (ui.left, ui.top)
  # The selection goes under the caret, as one shape for each run of lines that touch
  rects = Rect[]
  for it in e.layout[e.shown]
    top = ui.top + it.top
    if it.content isa Grid
      g = it.content
      if b.caret[1] != b.anchor[1]
        # A selection that covers several lines takes each row whole
        lo, hi = selection(b)
        y = top + TABLE_GAP
        lo[1] < it.first && hi[1] >= it.first && push!(rects, (num(ui.left), num(top), num(ui.left + 7px), num(y)))
        y += g.head   # a spreadsheet's row of letters isn't part of the text, so it's never selected
        for (r, i) in enumerate(g.rows)
          h = g.heights[r] + (r == length(g.rows) ? 2px : 1px)
          lo[1] <= i <= hi[1] && push!(rects, (num(ui.left), num(y), num(ui.left + e.width), num(y + h)))
          y += h
        end
        lo[1] <= it.last && hi[1] > it.last && push!(rects, (num(ui.left), num(y), num(ui.left + 7px), num(y + TABLE_GAP)))
        continue
      end
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        sel = selected(b, i)
        (sel !== nothing && sel[1] < cell.limit && sel[2] > cell.lo) || continue
        x, y = cell_origin(g, r, c)
        fill_selection(ctx, marks(g.flows[r][c], ui.left + x, top + y, (max(sel[1], cell.lo), min(sel[2], cell.limit), false), margin=false))
      end
    elseif it.content isa Sheet
      append!(rects, marks(e, it, it.content, ui.left, top))
    elseif it.content isa Live
      # A live block is selected whole
      lo, hi = selection(b)
      selecting(b) && lo[1] <= it.first && hi[1] >= it.last &&
        push!(rects, (num(ui.left), num(top), num(ui.left + e.width), num(top + it.tall)))
    else
      sel = selected(b, it.first)
      sel === nothing || append!(rects, marks(it.content, ui.left, top, sel))
    end
  end
  fill_selection(ctx, rects)
  annotate(ctx, e, ui)
  # A file that's only shown has a selection and no caret
  (b.reading || readonly(b)) || carets(ctx, e, ui)
  margin(ctx, e, ui)
end

"""
Draw the numbers of the lines, and the bars beside the lines that just changed,
in the room on the left of the text. The text of a page that's scrolled to the
right goes under that room, so the room is filled with the page's colour first.
"""
margin(ctx, e, ui) = begin
  across = sideways(e)
  left = ui.left + across   # where the text starts when it isn't scrolled
  room = PAGE_X + gutter(e)
  across > 0px && rectangle(ctx, left - room, ui.top, room, ui.height, background=colours.bg, border=0px)
  shade_line(ctx, e, left - room, ui.top)
  draw_numbers(ctx, e, left, ui.top)
  draw_fresh(ctx, e, left, ui.top)
end

const SHADE = 0.05   # how much of the colour of the text the shade of the caret's line has

"""
Shade the line that the caret is on, from `x` to the right edge of the window,
in a file of code whose settings ask for it. The shade is faint, so the text
shows through it. There's none while text is selected.
"""
shade_line(ctx, e, x, top) = begin
  b = e.buf
  (e.shade && numbered(b) && !b.reading && !readonly(b) && !selecting(b) && !isempty(e.layout)) || return
  it = item(e, b.caret[1])
  w, _ = window_size(e)
  rectangle(ctx, x, top + it.top, w - x, it.tall, background=RGBA(colours.ink, SHADE), border=0px)
end

"Draw the caret on the page, whose text is at `ui`"
carets(ctx, e, ui) = begin
  b = e.buf
  for it in e.layout[e.shown]
    top = ui.top + it.top
    if it.content isa Grid
      g = it.content
      at = gridcell(g, b.caret)
      isspread(g) && at !== nothing && b.caret[1] == b.anchor[1] && ring(ctx, g, at, ui.left, top)
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        x, y = cell_origin(g, r, c)
        at == (r, c) && caret(ctx, e, g.flows[r][c], ui.left + x, top + y, b.caret[2])
      end
      continue
    end
    it.content isa Sheet && caret(ctx, e, it.content, ui.left, top)
    it.first == b.caret[1] && it.content isa Flow && caret(ctx, e, it.content, ui.left, top, b.caret[2])
  end
end

# --- the mouse on the page --------------------------------------------------------------

"The place in the document under a point in the window"
locate(e, (x, y)) = begin
  # On a page that's scrolled sideways, a point on the numbers of the lines is on the first part of the line that shows
  dx, dy = max(x - e.origin[1], sideways(e)), y - e.origin[2]
  items = e.layout
  it = items[something(findlast(it -> it.top <= dy, items), 1)]
  if it.content isa Grid
    g = it.content
    # The row and the column under the point
    r = something(findfirst(r -> dy < it.top + cell_origin(g, r, 1)[2] + g.heights[r], eachindex(g.rows)), length(g.rows))
    c = something(findlast(c -> dx >= cell_origin(g, r, c)[1], eachindex(g.widths)), 1)
    cells = g.cells[r]
    isempty(cells) && return line_end(e.buf, g.rows[r])
    # A row can have fewer cells than the table has columns
    c = min(c, length(cells))
    f = g.flows[r][c]
    x, y = cell_origin(g, r, c)
    k = line_at(f, dy - it.top - y)
    return (g.rows[r], cellcol(f, k, dx - x, cells[c]))
  end
  it.content isa Sheet && return locate(e, it, it.content, dx, dy - it.top)
  if it.content isa Live
    # A point on a live block counts as the end of the line above it or the start of the line below
    above = dy < it.top + it.tall/2 ? it.first > 1 : it.last == length(e.buf.lines)
    return above && it.first > 1 ? line_end(e.buf, it.first - 1) : it.last < length(e.buf.lines) ? (it.last + 1, 0) : (it.first, 0)
  end
  f = it.content::Flow
  (it.first, colat(f, line_at(f, dy - it.top), dx))
end

"The link under a point in the window, or nothing"
link_at(e, pos) = begin
  line, col = locate(e, pos)
  it = item(e, line)
  it.content isa Flow || return nothing
  for vl in it.content.lines, seg in vl.segs
    seg.col <= col < seg.col + seg.n && !isempty(seg.link) && return seg.link
  end
  nothing
end

isword(c::Char) = isletter(c) || isdigit(c) || c == '_' || c == '\''

"The columns of the word around column `col` of `line`"
word_at(line::String, col::Int) = begin
  chars = collect(line)
  lo = hi = clamp(col, 0, length(chars))
  while lo > 0 && isword(chars[lo]); lo -= 1 end
  while hi < length(chars) && isword(chars[hi+1]); hi += 1 end
  (lo, hi)
end

held(node, key) = (w = window_of(node); w !== nothing && key in w.keys)

"The caret moved or the text changed, so show the caret"
touch!(e; keep_goal=false) = begin
  e.buf.reading = false
  e.blink = time()
  e.reveal = true
  keep_goal || (e.goal = nothing)
  e
end

"The line of the to-do item whose box is under a point in the window, or nothing"
todo_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[something(findlast(it -> it.top <= dy, e.layout), 1)]
  f = it.content
  (f isa Flow && f.kind == Kind.todo && !f.raw) || return nothing
  # The box is on the item's first line
  it.top + f.above <= dy < it.top + f.above + first(f.lines).high || return nothing
  for seg in first(f.lines).segs
    isbox(seg) && return seg.x <= dx < seg.x + seg.w ? it.first : nothing
  end
  nothing
end

"What inline code made that's under a point in the window: its Inline, or nothing"
inline_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[something(findlast(it -> it.top <= dy, e.layout), 1)]
  c = it.content
  if c isa Grid
    for r in eachindex(c.rows), col in eachindex(c.flows[r])
      cx, cy = cell_origin(c, r, col)
      found = inline_at(c.flows[r][col], dx - cx, dy - it.top - cy)
      found === nothing || return found
    end
    return nothing
  end
  c isa Flow ? inline_at(c, dx, dy - it.top) : nothing
end

inline_at(f::Flow, dx::px, dy::px) = begin
  (0px <= dy < tall(f)) || return nothing
  for seg in f.lines[line_at(f, dy)].segs
    seg.node !== nothing && seg.x <= dx < seg.x + seg.w && return seg.node
  end
  nothing
end

"Tick the box of the to-do item on line `i`, or take its tick away. The caret stays where it is."
tick!(e, i::Int) = begin
  b = e.buf
  text = b.lines[i]
  col = findfirst('[', text)   # the column after the [, because only spaces and a - come before it
  caret, anchor = b.caret, b.anchor
  edit!(b, (i, col), (i, col + 1), isdone(text) ? " " : "x")
  b.caret, b.anchor = caret, anchor
  e
end

press!(e, pos) = begin
  b = e.buf
  box = held(e, Keys.opt) ? nothing : todo_at(e, pos)
  if box !== nothing
    # A click on a to-do item's box ticks it, and doesn't move the caret
    focus(e)
    e.popup = :none
    e.clicked = (time(), (box, 0), 0)
    return tick!(e, box)
  end
  it = e.layout[something(findlast(it -> it.top <= pos[2] - e.origin[2], e.layout), 1)]
  if !held(e, Keys.opt) && inline_at(e, pos) !== nothing
    # What inline code made takes its own clicks, as a live block does. A click with ⌥ held shows the code.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    return
  end
  if it.content isa Live && !held(e, Keys.opt)
    # A live block takes its own clicks. A part of it that took the keyboard, like a text field, keeps it.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    return
  end
  focus(e)
  e.popup = :none
  if held(e, Keys.cmd)
    url = link_at(e, pos)
    url === nothing || return follow!(e, url)
  end
  if it.content isa Live
    # A click with ⌥ held shows the block's code
    e.clicked = (time(), (it.first, 0), 0)
    b.caret = b.anchor = (min(it.first + 1, it.last), 0)
    return touch!(e)
  end
  it.content isa Sheet && press!(e, it, it.content, pos) && return touch!(e)
  if it.content isa Grid && isspread(it.content) && held(e, Keys.opt)
    # A click on a spreadsheet with ⌥ held shows it as lines of code
    b.caret = b.anchor = line_end(b, it.first)
    return touch!(e)
  end
  at = settle(b, locate(e, pos))
  t, before, count = e.clicked
  count = time() - t < 0.4 && before == at ? count % 3 + 1 : 1
  e.clicked = (time(), at, count)
  if count == 2
    lo, hi = word_at(b.lines[at[1]], at[2])
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  elseif count == 3
    # Three clicks select the line, or in a table the cell
    cell = cellat(b, at)
    lo, hi = cell === nothing ? (0, length(b.lines[at[1]])) : (cell.lo, cell.hi)
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  else
    b.caret = at
    held(e, Keys.shft) || (b.anchor = at)
  end
  touch!(e)
end

"""
How far a key scrolls the page while it's read, or nothing for a key that doesn't
scroll it: ↑ and ↓ a little, Page Up, Page Down and Space a screen less a little, so a
line or two stays in sight, and Home, End, ⌘↑ and ⌘↓ to the top or the bottom.
"""
read_step(e, K, cmd, shift) = begin
  screen = e.scroll.viewport - 40px
  K == Keys.up ? (cmd ? px(-Inf) : -50px) :
  K == Keys.down ? (cmd ? px(Inf) : 50px) :
  cmd ? nothing :
  K == Keys.pageup ? -screen :
  K == Keys.pagedown ? screen :
  K == Keys.space ? (shift ? -screen : screen) :
  K == Keys.home ? px(-Inf) :
  K == Keys._end ? px(Inf) : nothing
end

"Scroll the page by `by`, as far as it goes"
scroll_page!(e, by) = begin
  s = e.scroll
  s.offset = clamp(s.offset + by, 0px, max(0px, s.content_height - s.viewport))
  e
end

"True when `a` is `b` or holds it"
holds(a, b) = begin
  while b !== nothing
    b === a && return true
    b = b.parent
  end
  false
end

"""
True when the node that has the keyboard is something other than the text, and
the click that is happening now is on that node, or on a part of it, or on a
node that holds it. A click on a list in a live block gives the list the
keyboard, and the click goes on to the page after the list has taken it.
"""
took(e) = begin
  w = window_of(e)
  w === nothing && return false
  f, under = w.focus, hittest(w)
  (f === nothing || f === e || f === input(e) || under === nothing) && return false
  holds(f, under) || holds(under, f)
end

"Open a link: a Markdown file in this editor, and anything else in the app the system picks for it"
follow!(e, url) = begin
  startswith(url, '^') && return follow_note!(e, url[2:end])
  path = abspath(docdir(e), unescaped(url))
  ismarkdown(path) && isfile(path) ? open!(e, path) : open_url(url)
end

drag!(e, pos) = begin
  held(e, Keys.mouse_left) && e.clicked[3] == 1 || return
  at = settle(e.buf, locate(e, pos))
  at == e.buf.caret && return
  e.buf.caret = at
  touch!(e)
end

onkey(d::Document, ev::KeyPress{Keys.mouse_left}) = press!(editor(d), ev.window.mouse)
onkey(p::Page, ev::KeyPress{Keys.mouse_left}) = press!(editor(p), ev.window.mouse)
onmouse(d::Document, ev::MouseMove) = drag!(editor(d), ev.position)
onmouse(p::Page, ev::MouseMove) = drag!(editor(p), ev.position)

# --- editing -----------------------------------------------------------------------------

"Put `new` where the selection is, or at the caret"
type!(e, new; typing=false) = begin
  b = e.buf
  cell = cellat(b, b.caret)
  if cell !== nothing && b.caret[1] == b.anchor[1]
    # In a row of a table, typing only ever changes the cell the caret is in
    lo, hi = selection(b)
    (within(cell, lo[2]) && within(cell, hi[2])) || (b.anchor = b.caret)
    new = replace(new, '\n' => ' ')
  end
  lo, hi = selection(b)
  # A third ` that opens a code block. Inside a block it would close that block instead.
  fence = new == "`" && lo == hi && kinds(b)[lo[1]].kind != Kind.code && strip(b.lines[lo[1]]) == "``" && lo[2] == length(b.lines[lo[1]])
  edit!(b, lo, hi, new; typing)
  if fence
    # The line that closes the block is typed too. Without it, the block would
    # take the line that opens the next block as its end, and turn every block
    # after it inside out.
    at = b.caret
    edit!(b, at, at, "\n```")
    b.caret = b.anchor = at
  end
  touch!(e)
end

line_end(b, i) = (i, length(b.lines[i]))

"The place one character before or after `p`"
beside(b::Buffer, (i, col)::Pos, by::Int) =
  by < 0 ? (col > 0 ? (i, col - 1) : i > 1 ? line_end(b, i - 1) : (i, col)) :
           (col < length(b.lines[i]) ? (i, col + 1) : i < length(b.lines) ? (i + 1, 0) : (i, col))

"The place one word before or after `p`"
word_step(b::Buffer, p::Pos, by::Int) = begin
  i, col = p
  chars = collect(b.lines[i])
  (by < 0 ? col == 0 : col == length(chars)) && return beside(b, p, by)
  if by < 0
    while col > 0 && !isword(chars[col]); col -= 1 end
    while col > 0 && isword(chars[col]); col -= 1 end
  else
    while col < length(chars) && !isword(chars[col+1]); col += 1 end
    while col < length(chars) && isword(chars[col+1]); col += 1 end
  end
  (i, col)
end

"The place one line up or down the screen from the caret"
vertical(e, by::Int) = begin
  b = e.buf
  i, col = b.caret
  it = item(e, i)
  at = it.content isa Grid ? gridcell(it.content, b.caret) : nothing
  at === nothing || return vertical(e, it, at, by)
  it.content isa Sheet && return vertical(e, it, it.content, by)
  f = flow(e, i)
  k, x = spot(f, col)
  x = e.goal = something(e.goal, x)
  1 <= k + by <= length(f.lines) && return (i, colat(f, k + by, x))
  j = i + by
  j < 1 && return (1, 0)
  j > length(b.lines) && return line_end(b, i)
  # Into a sheet, the caret goes to the cell that's under it or over it
  into = item(e, j)
  into.content isa Sheet && return enter(e, into, into.content, by, x)
  f = flow(e, j, true)
  (j, colat(f, by < 0 ? length(f.lines) : 1, x))
end

"The place one line up or down from the caret, which is in row `r`, column `c` of a table"
vertical(e, it::Item, (r, c), by::Int) = begin
  b = e.buf
  g = it.content::Grid
  f = g.flows[r][c]
  k, x = spot(f, b.caret[2])
  x = e.goal = something(e.goal, x)
  1 <= k + by <= length(f.lines) && return (b.caret[1], cellcol(f, k + by, x, g.cells[r][c]))
  r += by
  if r < 1
    return it.first > 1 ? line_end(b, it.first - 1) : b.caret
  elseif r > length(g.rows)
    # ↓ on the last row of a table at the end of the document starts a line below it
    it.last == length(b.lines) && edit!(b, line_end(b, it.last), line_end(b, it.last), "\n")
    return (it.last + 1, 0)
  end
  isempty(g.cells[r]) && return (g.rows[r], 0)
  c = min(c, length(g.cells[r]))
  f = g.flows[r][c]
  (g.rows[r], cellcol(f, by < 0 ? length(f.lines) : 1, x, g.cells[r][c]))
end

"The start or end of the line of the screen that the caret is on"
screen_edge(e, by::Int) = begin
  cell = cellat(e.buf, e.buf.caret)
  cell === nothing || return (e.buf.caret[1], by < 0 ? cell.lo : cell.hi)
  i, col = e.buf.caret
  f = flow(e, i)
  k, _ = spot(f, col)
  vl = f.lines[k]
  by < 0 ? (i, vl.from) : (i, k < length(f.lines) ? max(vl.from, vl.to - 1) : vl.to)
end

"""
Where a selection that grows to `p` ends. It steps over the ``` lines of a code
block that the selection didn't start in, and over the whole of a live block,
because those lines don't show.
"""
pass(b::Buffer, p::Pos, by::Int) = begin
  ks = kinds(b)
  i = p[1]
  ks[i].kind in (Kind.fence, Kind.code) || return p
  s, t = codeblock(b, i)
  s <= b.anchor[1] <= t && return p
  closed = t > s && ks[t].kind == Kind.fence && ks[t].level == 1
  if closed && (ks[s].lang == LIVE || (ks[s].lang == DIAGRAM && isdiagram(join(b.lines[s+1:t-1], "\n"))))
    i = by < 0 ? s - 1 : t + 1
  elseif ks[i].kind == Kind.fence
    i += by
  else
    return p
  end
  1 <= i <= length(b.lines) || return p
  by < 0 ? line_end(b, i) : (i, 0)
end

"Move the caret to `p`, which was reached by going in the direction `by`. With `extend`, the selection grows to it."
move!(e, p::Pos, extend::Bool; keep_goal=false, by=0) = begin
  p = settle(e.buf, p, by)
  extend && by != 0 && (p = pass(e.buf, p, by))
  e.buf.caret = p
  extend || (e.buf.anchor = p)
  touch!(e; keep_goal)
end

erase!(e, to::Pos) = begin
  b = e.buf
  insheet(b, b.caret[1]) && !selecting(b) && erase_row!(e, to) && return
  cell = cellat(b, b.caret)
  # In a table, a cell's edges can't be deleted
  cell === nothing || selecting(b) || (to[1] == b.caret[1] && within(cell, to[2])) || return
  selecting(b) || (b.anchor = to)
  type!(e, "")
end

"Return starts a new line. What else it does depends on the block the caret is in."
newline!(e) = begin
  b = e.buf
  insheet(b, b.caret[1]) && b.caret[1] == b.anchor[1] && return next_row!(e)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, false, down=true)
  selecting(b) ? type!(e, "\n") : newline!(e, block(b, b.caret[1]))
end

newline!(e, block) = type!(e, "\n")

# In a list or a quote, the new line carries it on
newline!(e, ::Type{<:Union{List,Quote,Paragraph}}) = begin
  b = e.buf
  i, col = b.caret
  text, line = b.lines[i], kinds(b)[i]
  k = line.kind
  col < line.prefix && return type!(e, "\n")
  lead = head(text, line.prefix)
  # Return on an empty list item ends the list
  if length(text) == line.prefix && k != Kind.paragraph
    b.anchor = (i, 0)
    return type!(e, "")
  end
  type!(e, "\n" * carry(lead, k))
end

"What starts the line after a list item or a quote that starts with `lead`: the next number, or a to-do box with no tick"
carry(lead, k::Kind) = begin
  k == Kind.todo && return replace(lead, r"\[[xX]\]" => "[ ]")
  m = k == Kind.ordered ? match(r"^(\s*)(\d+)(.*)$", lead) : nothing
  m === nothing ? lead : string(m[1], parse(Int, m[2]) + 1, m[3])
end

# In code, the new line starts under the text of the line before. It starts
# one step further in after a line that opens a block.
newline!(e, ::Type{CodeBlock}) = begin
  b = e.buf
  i, col = b.caret
  line = kinds(b)[i]
  if line.kind == Kind.fence && line.level == 0 && line.lang == SHEET && col == length(b.lines[i])
    # The line that opens a sheet. Its first row starts with a place for a name.
    type!(e, "\n = ")
    b.caret = b.anchor = (i + 1, 0)
    return touch!(e)
  end
  if line.kind == Kind.fence && line.level == 0 && line.lang == SPREADSHEET && col == length(b.lines[i])
    # The line that opens a spreadsheet. Its first row starts with three cells, and the caret goes to the first.
    type!(e, "\n|  |  |  |")
    b.caret = b.anchor = (i + 1, 2)
    return touch!(e)
  end
  line.kind == Kind.fence && return type!(e, "\n")
  before = head(b.lines[i], col)
  type!(e, "\n" * match(r"^ *", before).match * (opens(before, line.lang) ? indentation(e, CodeBlock) : ""))
end

const STEP = "  "   # one step of indentation
const OPENERS = r"^\s*(function|if|elseif|else|for|while|let|try|catch|finally|struct|mutable struct|module|macro|quote)\b"

"True when a line of code that ends with `text` opens a block, so the next line goes further in"
opens(text::AbstractString, lang::AbstractString) = begin
  s = rstrip(text)
  isempty(s) && return false
  last(s) in "([{" && return true
  lowercase(lang) in ("python", "py") && return last(s) == ':'
  lowercase(lang) in ("julia", "jl", LIVE) || return false
  occursin(r"\b(begin|do( [\w, ]+)?)$", s) || (occursin(OPENERS, s) && !occursin(r"\bend$", s))
end

"Where backspace deletes back to from the caret: one character, or one step of `n` of the spaces that start a line"
backstep(b::Buffer, block, n=length(STEP)) = begin
  i, col = b.caret
  indented = col > 0 && !selecting(b) && all(==(' '), head(b.lines[i], col))
  indented ? (i, col - (col - 1) % n - 1) : beside(b, b.caret, -1)
end

# In a table the spaces belong to a cell
backstep(b::Buffer, ::Type{Table}, n=0) = beside(b, b.caret, -1)

"Tab moves text in, and shift-Tab moves it back out. What they move depends on the block the caret is in."
indent!(e, out::Bool) = begin
  b = e.buf
  insheet(b, b.caret[1]) && return sheet_tab!(e, out)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, out)
  indent!(e, out, block(b, b.caret[1]))
end

indent!(e, out::Bool, block) = out ? nothing : type!(e, STEP)

# In code, Tab goes to the next step. With a selection, or with shift, it moves every line the selection touches.
indent!(e, out::Bool, ::Type{CodeBlock}) = begin
  b = e.buf
  tab = indentation(e, CodeBlock)   # as many spaces as the settings page says
  out || selecting(b) || return type!(e, " " ^ (length(tab) - b.caret[2] % length(tab)))
  ends = Dict(:caret => b.caret, :anchor => b.anchor)
  lo, hi = minmax(b.caret, b.anchor)
  for i in lo[1]:hi[1]
    kinds(b)[i].kind == Kind.code || continue
    n = out ? min(length(tab), length(match(r"^ *", b.lines[i]).match)) : length(tab)
    isempty(b.lines[i]) && continue
    edit!(b, (i, 0), (i, out ? n : 0), out ? "" : tab)
    for (name, (l, col)) in ends
      l == i && (ends[name] = (i, max(0, col + (out ? -n : n))))
    end
  end
  b.caret, b.anchor = ends[:caret], ends[:anchor]
  touch!(e)
end

# In a list, Tab moves the item in and shift-Tab moves it back out
indent!(e, out::Bool, ::Type{List}) = begin
  b = e.buf
  i, col = b.caret
  selecting(b) && return out ? nothing : type!(e, STEP)
  n = out ? min(2, kinds(b)[i].level) : 2
  edit!(b, (i, 0), (i, out ? n : 0), out ? "" : "  ")
  b.caret = b.anchor = (i, max(0, col + (out ? -n : n)))
  touch!(e)
end

"""
Go to the next cell of a table and select what's in it, or with `back` the one
before. With `down`, go to the same cell of the next row. Going on from the end
of the table adds a row.
"""
next_cell!(e, back::Bool; down=false) = begin
  b = e.buf
  i, col = b.caret
  rows = gridrows(b, i)
  r = findfirst(==(i), rows)
  cs = rowcells(b, b.caret)
  c = nearest(cs, col)
  if down
    r += 1
  elseif back
    c -= 1
    c < 1 && (r -= 1; c = 0)
  else
    c += 1
    c > length(cs) && (r += 1; c = 1)
  end
  r < 1 && return
  if r > length(rows)
    t = last(rows)
    edit!(b, line_end(b, t), line_end(b, t), "\n|" * repeat("  |", maximum(i -> length(rowcells(b, (i, 0))), rows)))
    push!(rows, t + 1)
  end
  cs = rowcells(b, (rows[r], 0))
  isempty(cs) && return move!(e, (rows[r], 0), false)
  cell = cs[c == 0 ? length(cs) : min(c, length(cs))]
  b.anchor, b.caret = (rows[r], cell.lo), (rows[r], cell.hi)
  touch!(e)
end

"Put `mark` around the selection, or take it away if it's there already"
surround!(e, mark::String) = begin
  b = e.buf
  lo, hi = selection(b)
  lo[1] == hi[1] || return
  i, n = lo[1], length(mark)
  line = b.lines[i]
  inner = rest(head(line, hi[2]), lo[2])
  if lo[2] >= n && rest(head(line, lo[2]), lo[2] - n) == mark && head(rest(line, hi[2]), n) == mark
    edit!(b, (i, lo[2] - n), (i, hi[2] + n), inner)
    b.anchor, b.caret = (i, lo[2] - n), (i, hi[2] - n)
  else
    edit!(b, lo, hi, mark * inner * mark)
    b.anchor, b.caret = (i, lo[2] + n), (i, hi[2] + n)
  end
  touch!(e)
end

copy_selection!(e) = selecting(e.buf) && clipboard(excerpt(e.buf, selection(e.buf)...))

"""
Put what the clipboard holds into the text at the caret. Files that were
copied in the Finder go in the way a dropped file does: a picture shows as a
picture, and a video, a sound, a PDF or any other file as a path that shows
what's in the file. A picture that was copied as itself, like a screenshot, is
written to a file in the document's folder first. So is a PDF, a sound or a
video that was copied as itself. Anything else is pasted as text.

A file in a folder for temporary files is copied to the document's folder,
and the copy is what goes in. An app that takes screenshots puts its picture
on the clipboard as a file like that, and macOS removes the file later.
"""
paste!(e) = begin
  b = e.buf
  paths = Pasteboard.files()
  if isempty(paths)
    text = Sys.isapple() ? Pasteboard.text() : clipboard()
    # A picture that's copied from a web page comes with its address as text, and the picture is what's wanted
    found = isempty(strip(text)) || occursin(r"^\s*\w+://\S+\s*$", text) ? Pasteboard.media() : nothing
    path = found === nothing ? nothing : keep_pasted(e, found...)
    path === nothing && return type!(e, replace(text, "\r\n" => "\n", '\r' => '\n', '\t' => "  "))
    paths = [path]
  end
  paths = [passing(e, p) ? something(keep_copy(e, p), p) : p for p in paths]
  selecting(b) && type!(e, "")
  put_files!(e, paths, settle(b, b.caret))
end

"""
Write `bytes` that were pasted to a new file in the document's folder, and
return its path. `ext` is the end of the file's name, like "png". Nothing if
the document has no folder yet.
"""
keep_pasted(e, ext, bytes) = begin
  dir = docdir(e)
  isdir(dir) || return nothing
  path = unused(dir, "pasted-" * Libc.strftime("%Y%m%d-%H%M%S", time()), ".$ext")
  write(path, bytes)
  dir == e.folder && list_files!(e)   # the sidebar lists the new file
  path
end

"A path in `dir` that no file has yet: `stem` and `ext`, with a number after the stem if that name is taken"
unused(dir, stem, ext) = begin
  path = joinpath(dir, stem * ext)
  n = 1
  while ispath(path)
    path = joinpath(dir, "$stem-$(n += 1)$ext")
  end
  path
end

# The folders that macOS keeps temporary files in, and empties by itself
const PASSING = ("/private/var/folders/", "/var/folders/", "/private/tmp/", "/tmp/")

"True when the file at `path` is a temporary one, which macOS removes later. A file in the document's own folder is never one."
passing(e, path) = isfile(path) && dirname(path) != docdir(e) && any(p -> startswith(path, p), PASSING)

"""
Copy the file at `path` to the document's folder, under its own name, and
return the copy's path. Nothing if the document has no folder yet.
"""
keep_copy(e, path) = begin
  dir = docdir(e)
  isdir(dir) || return nothing
  copy = unused(dir, splitext(basename(path))...)
  cp(path, copy)
  dir == e.folder && list_files!(e)
  copy
end

zoom!(e, z) = (e.zoom = clamp(z, 0.6, 2.5); save_settings!(e); rerun!(e, :zoom); restyle!(e))

"The size of the page's text, to the nearest pixel"
text_size(e) = round(Int, TEXT_SIZE.value * e.zoom)
# The page's text is a whole number of pixels tall, so the settings page can show its size as a number
"The zoom that makes the page's text `size` pixels tall. Sizes are whole numbers from 11 to 42."
zoom_for(size) = clamp(round(Int, size), 11, 42) / TEXT_SIZE.value

"The one after `x` in `list`, going back to the start after the last"
after(list, x) = list[mod1(findfirst(==(x), list) + 1, length(list))]

const THEME_ORDER = (:sepia, :paper, :night)

const STATS = (:words, :chars, :minutes)
const STAT_NAMES = ("Words", "Characters", "Reading time")   # what the settings page calls them

"Make the count at the top right count `stat`: one of `STATS`"
stat!(e, stat::Symbol) = (e.stat = stat; save_settings!(e); rerun!(e, :stat); e)
next_stat!(e) = stat!(e, after(STATS, e.stat))

const SLIDE_TIME = 0.25   # seconds for the sidebar to slide in or out

"Show the sidebar if it's hidden, or hide it. It slides from where it is now."
toggle_panel!(e) = (e.slid_from = opened(e); e.slid = time(); e.panel = !e.panel)

sliding(e) = time() - e.slid < SLIDE_TIME

"How far the sidebar is open, from 0 to 1"
opened(e) = begin
  to = e.panel ? 1.0 : 0.0
  sliding(e) || return to
  t = (time() - e.slid) / SLIDE_TIME
  t = t < 0.5 ? 4t^3 : 1 - (2 - 2t)^3 / 2   # slow at the start and the end
  e.slid_from + (to - e.slid_from) * t
end

"The most of the window's width that the sidebar can have, so the page keeps room beside it"
widest_panel(e) = max(PANEL_MIN, min(PANEL_MAX, px(floor(num(window_size(e)[1]) / 2))))

"How wide the sidebar is when it's open. A narrow window makes it narrower than you dragged it."
panel_w(e) = min(e.side, widest_panel(e))

"Make the sidebar `w` pixels wide, or as near to that as it can be, and keep the width in the settings"
side!(e, w) = begin
  w = px(round(num(clamp(w, PANEL_MIN, widest_panel(e)))))
  w == e.side && return e
  e.side = w
  save_settings!(e)
  e
end

ismouse(k) = k in (Keys.mouse_left, Keys.mouse_right, Keys.mouse_middle)

# The keys that do something with ⌘ while the page shows a file that's only shown: ⌘O, ⌘\ and the
# keys that change the size of the text. A file that shows as text takes ⌘A, ⌘C, ⌘F and ⌘G too.
# ⌘W and ⌘, work in every window, so they aren't here.
const READ_KEYS = (Keys.o, Keys.backslash, Keys.equal, Keys.minus, getproperty(Keys, Symbol(0)))
const TEXT_KEYS = (Keys.a, Keys.c, Keys.f, Keys.g)

onkey(e::Editor, ev::KeyPress{K}) where K = begin
  # A key that the sidebar's tree took, like Return on a heading, comes here next. It isn't for the text.
  pop!(e.nodes, :chose, false) && return
  # ⌘W closes the window and ⌘, shows the settings, whatever has the keyboard. A slider on the
  # settings page takes the keyboard when it's dragged, and ⌘, still closes that window.
  if Keys.cmd in ev.window.keys
    K == Keys.w && return (close(ev.window); nothing)
    K == Keys.comma && return (toggle_settings!(e); nothing)
  end
  # While a picture or a model fills the window, the keys are its own, and a right-click has no menu. Esc puts the page back.
  zoomed = zooming(e)
  zoomed === nothing || e.popup != :none || zoom_key!(zoomed, K, ev.window) !== handled || return
  K == Keys.mouse_right && return context_menu!(e, ev.window)
  ismouse(K) && return
  w = ev.window
  shift, cmd, opt, ctrl = Keys.shft in w.keys, Keys.cmd in w.keys, Keys.opt in w.keys, Keys.ctrl in w.keys
  b = e.buf
  # While a part of a live block has the keyboard, the keys are its own and
  # don't change the text. Escape gives the keyboard back to the text.
  if w.focus !== e && w.focus !== input(e)
    if w.focus === find_input(e)
      find_key!(e, K, shift, cmd)
    elseif w.focus === renamer(e)
      rename_key!(e, K)
    elseif K == Keys.escape
      hide_menu!(w)
      focus(e)
    elseif cmd && K == Keys.s
      save_page!(e)
    elseif cmd && K == Keys.p
      print!(e, w)
    elseif cmd && K == Keys.backslash && w.focus === file_tree(e)
      # ⌘\ hides the sidebar while it has the keyboard too, and the text gets the keyboard back
      shift || toggle_panel!(e)
      focus(e)
    end
    return
  end
  e.popup == :finder && return finder_key!(e, K)
  # The list of names under a sheet's expression takes ↑, ↓, Return, Tab and esc
  !cmd && !opt && !shift && suggest_key!(e, K) && return nothing
  # While the page is read, there's no caret to move, so the keys that would move it scroll the
  # page. A key that would change the text does nothing. Any other command with ⌘ still works,
  # and one that moves the caret, like undo, puts it back.
  if b.reading || readonly(b)
    step = read_step(e, K, cmd, shift)
    step === nothing || return (scroll_page!(e, step); nothing)
    cmd || K == Keys.escape || return nothing
  end
  # A file that's only shown takes the commands that don't change it. Its text can be selected, copied and searched.
  if readonly(b) && K != Keys.escape && !(cmd && opt && K == Keys.i)
    K in READ_KEYS || (b.view != :file && K in TEXT_KEYS) || return nothing
  end
  if K == Keys.escape && finding(e)
    close_find!(e)
  elseif K == Keys.escape
    # Escape closes a popup. With none open, it takes away what the page's code came to. With
    # none of that either, it hides the caret and every line shows as it reads.
    if e.popup != :none
      e.popup = :none
    elseif !forget_outcomes!(e)
      b.anchor = b.caret
      b.reading = true
    end
  elseif cmd && opt && K == Keys.i
    toggle_inspector!(w)
  elseif cmd && K == Keys.s
    save_page!(e)
  elseif K == Keys.enter && (cmd || shift) && !opt && run_here!(e, step=!cmd)
    # In a `julia` code block, ⌘Return and ⇧Return run the code that the caret is in
  elseif cmd && K == Keys.enter && !isempty(agents(e))
    send!(e)   # to the agent that waits for the page
  elseif cmd && K == Keys.z
    shift ? redo!(b) : undo!(b)
    touch!(e)
  elseif cmd && K == Keys.a
    select_all!(e)
  elseif cmd && K == Keys.c
    copy_selection!(e)
  elseif cmd && K == Keys.x
    cut!(e)
  elseif cmd && K == Keys.v
    paste!(e)
  elseif cmd && K == Keys.b
    b.view == :markdown && surround!(e, "**")
  elseif cmd && K == Keys.i
    b.view == :markdown && surround!(e, "*")
  elseif cmd && K == Keys.o
    open_finder!(e)
  elseif cmd && K == Keys.f
    open_find!(e)
  elseif cmd && K == Keys.g
    find_step!(e, shift ? -1 : 1)
  elseif cmd && shift && K == Keys.e
    export_html!(e, w)
  elseif cmd && K == Keys.p
    print!(e, w)
  elseif cmd && K == Keys.backslash
    shift ? focus_panel!(e) : toggle_panel!(e)
  elseif cmd && K == Keys.equal
    zoom!(e, zoom_for(text_size(e) + 1))
  elseif cmd && K == Keys.minus
    zoom!(e, zoom_for(text_size(e) - 1))
  elseif cmd && K == getproperty(Keys, Symbol(0))
    zoom!(e, 1.0)
  elseif K == Keys.left || K == Keys.right
    by = K == Keys.left ? -1 : 1
    lo, hi = selection(b)
    to = cmd ? screen_edge(e, by) : opt ? word_step(b, b.caret, by) :
         selecting(b) && !shift ? (by < 0 ? lo : hi) : beside(b, b.caret, by)
    move!(e, to, shift; by)
  elseif K == Keys.up || K == Keys.down
    by = K == Keys.up ? -1 : 1
    to = cmd ? (by < 0 ? (1, 0) : line_end(b, length(b.lines))) : vertical(e, by)
    move!(e, to, shift; keep_goal=!cmd, by)
  elseif K == Keys.pageup || K == Keys.pagedown
    for _ in 1:20
      by = K == Keys.pageup ? -1 : 1
      move!(e, vertical(e, by), shift; keep_goal=true, by)
    end
  elseif K == Keys.home || K == Keys._end
    move!(e, screen_edge(e, K == Keys.home ? -1 : 1), shift)
  elseif K == Keys.backspace && !cmd && !opt && emptyrow(b)
    backrow!(e)
  elseif K == Keys.backspace
    erase!(e, cmd ? (b.caret[1], 0) : opt ? word_step(b, b.caret, -1) : (blk = block(b, b.caret[1]); backstep(b, blk, length(indentation(e, blk)))))
  elseif K == Keys.delete
    erase!(e, opt ? word_step(b, b.caret, 1) : beside(b, b.caret, 1))
  elseif K == Keys.enter
    newline!(e)
  elseif K == Keys.tab
    indent!(e, shift)
  end
  nothing
end

# What a key types comes as a character, so each keyboard types its own letters:
# ß on a German keyboard, é from ⌥E and then E, and an emoji from the Mac's
# emoji list. A key that's held with ⌘ types nothing.
ontype(e::Editor, ev::Typed) = begin
  # A character that a part of a live block didn't take comes here next. It isn't for the text.
  ev.window.focus === e || return nothing
  zooming(e) === nothing || return handled   # the page under a picture that fills the window doesn't change
  c = ev.char
  # macOS has characters of its own for keys like the arrows, which aren't text
  (iscntrl(c) || '\uf700' <= c <= '\uf8ff') && return nothing
  # While the page is read, a key that would change the text does nothing. A file that's only shown is never changed.
  (e.buf.reading || readonly(e.buf)) && return nothing
  type!(e, string(c), typing=true)
  # A code block offers names only just after a character is typed
  e.nodes[:typed_at] = (e.buf.path, e.buf.version, e.buf.caret)
  handled
end

# --- files dropped on the page -----------------------------------------------------------
#
# A file that's dropped on the page from the Finder goes into the text. A
# picture goes on a line of its own under the line it's dropped on, written as
# ![name](path), so the page shows it. A Markdown file goes in where it's
# dropped as a link to it. Any other file, and a folder, goes in there as a
# path that shows as a breadcrumb: !`fs"path"`.

"`path` as the text names it: from the folder of the document when it's in that folder, and whole when it isn't"
named(e, path) = (dir = docdir(e); startswith(path, dir * "/") ? relpath(path, dir) : path)

"`path` as a link writes it. A space or a bracket would end the link early, so each is written as its code."
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")
"The path that a link wrote with `escaped`"
unescaped(path) = replace(path, "%20" => ' ', "%28" => '(', "%29" => ')')

ispicture(path) = (ext = lowercase(splitext(path)[2]); ext in PICTURES || ext in MAC_PICTURES)

"The Markdown that shows the file or the folder at `path`"
markdown_for(e, path) = begin
  name, at = splitext(basename(path))[1], named(e, path)
  ispicture(path) ? "![$name]($(escaped(at)))" : ismarkdown(path) ? "[$name]($(escaped(at)))" : "!`fs\"$(replace(at, '"' => "\\\""))\"`"
end

onfiledrop(e::Editor, w::Window, paths) = begin
  e.buf.view == :markdown || return nothing   # a file goes into a page as Markdown
  # A PDF file or a picture that's dropped on a takeoff is its plan
  v = takeoff_at(e, w)
  plan = v === nothing ? nothing : findfirst(p -> isfile(p) && (ispdf(p) || ispicture(p)), paths)
  plan === nothing || return plan!(v, rstrip(String(paths[plan]), '/'))
  put_files!(e, paths, settle(e.buf, locate(e, w.mouse)))
end

"Put the files and folders at `paths` into the text at `at`, the way a drop there does. ⌘V does this with files that were copied."
put_files!(e, paths, at::Pos) = begin
  paths = [rstrip(String(p), '/') for p in paths if ispath(p)]
  isempty(paths) && return
  b = e.buf
  b.view == :markdown || return   # only a page has text for the path to go into, as Markdown
  pictures = [markdown_for(e, p) for p in paths if isfile(p) && ispicture(p)]
  others = [markdown_for(e, p) for p in paths if !(isfile(p) && ispicture(p))]
  if !isempty(others)
    line = b.lines[at[1]]
    # What's dropped on a word goes after the word, not into it
    at = (at[1], word_at(line, at[2])[2])
    # A space goes between what's dropped and the words on each side of it, but not before a full stop or a comma
    before = at[2] > 0 && !isspace(line[nextind(line, 0, at[2])]) ? " " : ""
    next = at[2] < length(line) ? line[nextind(line, 0, at[2] + 1)] : ' '
    after = isspace(next) || next in ".,;:!?)]}" ? "" : " "
    new = before * join(others, " ") * after
    edit!(b, at, at, new)
    at = (at[1], at[2] + length(new))
  end
  if !isempty(pictures)
    # Under the block that it's dropped on, so that a picture doesn't go into the middle of a table
    under = block_end(b, at[1])
    empty = isempty(strip(b.lines[under]))
    edit!(b, empty ? (under, 0) : line_end(b, under), line_end(b, under), (empty ? "" : "\n\n") * join(pictures, "\n\n"))
    under += (empty ? 0 : 2) + 2(length(pictures) - 1)
    at = line_end(b, under)
  end
  b.caret = b.anchor = at
  focus(e)
  touch!(e)
end

# --- the bar over a table ----------------------------------------------------------------
#
# While the caret is in a table, a small bar floats over the table's top left
# corner. Its buttons add and remove a row or a column at the caret, and put the
# text of the caret's column on the left, in the centre or on the right.

const TABLE_ACTIONS = (:addrow => "+Row", :delrow => "−Row", :addcol => "+Col", :delcol => "−Col",
                       :left => "L", :center => "C", :right => "R")
const DASHES = (left=":---", center=":---:", right="---:")
const ALIGN_ICONS = (left="text-left", center="text-center", right="text-right")
const BAR_H = 26px

"Change the table the caret is in, then put the caret back in a cell"
tableop!(e, action::Symbol) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return spreadop!(e, action)
  run = table(b, b.caret[1])
  run === nothing && return
  s, t = run
  i = b.caret[1] == s + 1 ? s : b.caret[1]
  cs = tablecells(b.lines[i])
  c = isempty(cs) ? 1 : nearest(cs, b.caret[2])
  rows = map(celltexts, b.lines[s:t])
  n = maximum(length, rows)
  rows = [[r; fill(k == 2 ? "---" : "", n - length(r))] for (k, r) in enumerate(rows)]
  k = i - s + 1   # the caret's row in `rows`, where row 2 is the line of dashes
  if action == :addrow
    k = max(k, 2) + 1
    insert!(rows, k, fill("", n))
  elseif action == :delrow
    k == 1 && return   # the heading row stays
    deleteat!(rows, k)
    k = k > length(rows) ? (length(rows) > 2 ? length(rows) : 1) : k
  elseif action == :addcol
    c += 1
    foreach((j, r) -> insert!(r, c, j == 2 ? "---" : ""), eachindex(rows), rows)
  elseif action == :delcol
    n == 1 && return
    foreach(r -> deleteat!(r, c), rows)
    c = min(c, n - 1)
  else
    rows[2][c] = getproperty(DASHES, action)
  end
  edit!(b, (s, 0), line_end(b, t), join(map(tableline, rows), "\n"))
  line = s + k - 1
  cell = tablecells(b.lines[line])[c]
  b.caret = b.anchor = (line, cell.hi)
  touch!(e)
end

# The three buttons that move a column's text show the usual picture of lines of text on that side
"True when the caret is in a row of a table, under the heading row, that has no text in any cell"
emptyrow(b::Buffer) = begin
  inspread(b, b.caret[1]) && return !selecting(b) && all(isempty, spreadtexts(b.lines[b.caret[1]]))
  run = table(b, b.caret[1])
  run !== nothing && !selecting(b) && b.caret[1] > run[1] + 1 && all(isempty, celltexts(b.lines[b.caret[1]]))
end

"Backspace in an empty row removes the row and puts the caret at the end of the row above"
backrow!(e) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return droprow!(e)
  s, _ = table(b, b.caret[1])
  i = b.caret[1]
  tableop!(e, :delrow)
  above = i - 1 == s + 1 ? s : i - 1
  cs = tablecells(b.lines[above])
  isempty(cs) || (b.caret = b.anchor = (above, cs[end].hi))
  touch!(e)
end

describe(t::TableButton) =
  Box(height(BAR_H - 6px), padding(7px, 0px), radius(4px), background(ishovered(t) ? colours.hover : clear),
    haskey(ALIGN_ICONS, t.action) ? Icon(getproperty(ALIGN_ICONS, t.action), size=13px, color=colours.dim) :
                                    label(t.label, 11px, color=colours.dim))

cursor(::TableButton) = :hand
onkey(t::TableButton, ::KeyPress{Keys.mouse_left}) = (e = editor(t); tableop!(e, t.action); focus(e))

"The bar over the table the caret is in, placed in the window. Nothing when the caret isn't in a table."
tablebar(e) = begin
  b = e.buf
  (!b.reading && b.caret[1] == b.anchor[1] && !isempty(e.layout)) || return ()
  it = item(e, b.caret[1])
  it.content isa Grid || return ()
  top = TOPBAR_H + PAGE_TOP + it.top + TABLE_GAP - e.scroll.offset - BAR_H - 3px
  top >= TOPBAR_H || return ()
  bar = Row(height(BAR_H), padding(3px, 0px), radius(6px), background(colours.float), border(1px, :solid, colours.line), lifted,
    # A spreadsheet has no buttons that move a column's text: a number goes on the right and text on the left
    [node!(() -> TableButton(action=a, label=l), e, (:table, a)) for (a, l) in TABLE_ACTIONS[1:(isspread(it.content) ? 4 : end)]]...)
  # The page's text is in the middle of the space beside the file panel
  w, _ = window_size(e)
  side = panel_w(e) * opened(e)
  left = side + max(PAGE_X, (w - side - e.width) / 2)
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), bar),)
end

# --- the top bar ------------------------------------------------------------------------

describe(b::ToolButton) = begin
  e = editor(b)
  ishovered(b) || (b.quiet = false)
  on = (b.action == :panel && e.panel) || (b.action == :marks && marking(e))
  box = Box(width(30px), height(28px), radius(6px), Alignment.Center, name="Button",
            background(on ? colours.active : ishovered(b) && !off(b) ? colours.hover : clear),
          Icon(b.icon, size=15px, color=off(b) ? colours.faint : colours.dim))
  # While the sidebar is closed, a dot beside its button says that an agent waits for a page that isn't showing
  (b.action == :panel && !e.panel && !isempty(elsewhere(e))) || return box
  Row(child_gap=4px, box, Box(width(7px), height(7px), radius(3.5px), background(colours.accent)))
end

cursor(b::ToolButton) = off(b) ? :arrow : :hand

onkey(b::ToolButton, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  b.action == :panel && toggle_panel!(e)
  b.action == :outside && open_outside!(e)
  b.action == :marks && toggle_marks!(e)
  b.action == :job && make_job!(e)
  hush!(b)
  focus(e)
end

# Each button in the top bar says what it does while the mouse is over it. A
# click hides what it says until the mouse leaves the button.

const Tipped = Union{ToolButton,Count,SendButton}
const TIP_INK = colorant"rgb(240,240,240)"   # on the dark grey that every tooltip has

"What a tooltip shows: `words`, with room around them"
tip_label(words) = Box(padding(10px, 7px), label(words, 12px, color=TIP_INK))

"What the tooltip of a button in the top bar says"
tip(b::ToolButton) = begin
  e = editor(b)
  if b.action == :panel
    e.panel && return "Hide sidebar  ⌘\\"
    ws = elsewhere(e)
    # The dot beside the button is for the first of these
    isempty(ws) && return "Show sidebar  ⌘\\"
    return "$(uppercasefirst(first(ws).name)) waits for $(basename(first(ws).page))  ·  Show sidebar  ⌘\\"
  end
  b.action == :marks && return marking(e) ? "Hide $(whose(e)) changes" : "Show $(whose(e)) changes"
  b.action == :job && return job_tip(e)
  b.action == :outside || return ""
  app = opener(e.buf.path)
  isempty(app) ? "Show in Finder" : "Open in $(app_name(app))"
end
tip(s::SendButton) = begin
  e = editor(s)
  ws = agents(e)
  isempty(ws) ? "Nudged $(get(e.nodes, :agent, "the agent"))" : "Nudge $(first(ws).name) with what you changed  ⌘Return"
end
tip(c::Count) = begin
  s = after(STATS, editor(c).stat)
  s == :words ? "Count words" : s == :chars ? "Count characters" : "Show reading time"
end

draw(ctx, size, ui::ConcreteRect, b::Tipped) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::Tipped, ev::MouseMove) = begin
  b.quiet && return
  show_tooltip!(ev.window, tip_label(tip(b)), b.rect...,
                placement=:bottom, gap=6px)
end

hush!(b::Tipped) = (b.quiet = true; hide_tooltip!(window_of(b)))

commas(n::Int) = replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",")

describe(c::Count) = begin
  e = editor(c)
  b = e.buf
  kinds(b)
  s = e.stat == :words ? "$(commas(b.words)) $(b.words == 1 ? "word" : "words")" :
      e.stat == :chars ? "$(commas(b.chars)) characters" : "$(max(1, round(Int, b.words / 230))) min read"
  ishovered(c) || (c.quiet = false)
  Box(height(28px), padding(8px, 0px), radius(6px), background(ishovered(c) ? colours.hover : clear),
    label(s, 12px, color=colours.dim))
end

cursor(::Count) = :hand

onkey(c::Count, ::KeyPress{Keys.mouse_left}) = (next_stat!(editor(c)); hush!(c))

button(e, action, icon) = node!(() -> ToolButton(icon=icon, action=action), e, action)

# --- a page that an agent waits for -------------------------------------------------------
#
# An agent like Claude Code writes a page, shows it here and waits (see
# agent.jl). While it waits, the top bar has a button with a bell that sends the page: it
# saves the file and tells the agent which lines you changed. ⌘Return does the
# same. The agent can change the file while you type, and the page keeps both.

"Every agent that waits, for any page. The folder that lists them is read twice a second."
waiters(e) = begin
  at, found = get(e.nodes, :agents, (0.0, Agent.Waiter[]))::Tuple{Float64,Vector{Agent.Waiter}}
  time() - at < 0.5 && return found
  Agent.announce()
  found = Agent.waiters()
  e.nodes[:agents] = (time(), found)
  found
end

# An agent names its page by the path that has no links in it. Each file's path of that kind is found once.
const TRUE_PATHS = Dict{String,String}()
truepath(path) = get!(() -> ispath(path) ? realpath(path) : abspath(path), TRUE_PATHS, path)

"The agents that wait for the file at `path`"
agents(e, path) = begin
  ws = waiters(e)
  (isempty(ws) || isempty(path)) && return ws[1:0]
  at = truepath(path)
  filter(w -> w.page == at, ws)
end

"The agents that wait for the page that's showing"
agents(e) = readonly(e.buf) ? Agent.Waiter[] : agents(e, e.buf.path)

"The agents that wait for a page that isn't the one that's showing"
elsewhere(e) = begin
  ws = waiters(e)
  isempty(ws) && return ws
  at = isempty(e.buf.path) ? "" : truepath(e.buf.path)
  filter(w -> w.page != at, ws)
end

"Save the page and tell each agent that waits for it what you changed. Nothing happens if no agent waits."
send!(e) = begin
  b = e.buf
  delete!(e.nodes, :agents)
  ws = agents(e)
  isempty(ws) && return
  save!(b)
  lo, hi = selection(b)
  text = Agent.report(b.path, b.told, b.lines, lo[1], selecting(b) ? excerpt(b, lo, hi) : "")
  foreach(w -> Agent.send(w, text), ws)
  # The agent knows the page as it is now, and none of the lines are its changes any more
  b.sent = b.told = copy(b.lines)
  delete!(e.nodes, :marking)
  e.nodes[:sent] = (b.path, b.version, first(ws).name)
  delete!(e.nodes, :agents)
  nothing
end

"What the top bar shows of the agent: a button while one waits, and a few words after you sent the page"
agent_part(e) = begin
  b = e.buf
  ws = agents(e)
  sent = get(e.nodes, :sent, nothing)
  # A button shows the agent's changes again, for as long as there are some
  marks = isempty(theirs(e)) ? () : (button(e, :marks, "eye"), Box(width(4px)))
  if !isempty(ws)
    delete!(e.nodes, :sent)
    e.nodes[:agent] = first(ws).name
    (marks..., node!(SendButton, e, :send))
  elseif sent !== nothing && sent[1] == b.path && sent[2] == b.version
    # The button shows that the page was sent, until the agent waits again or the text changes
    (marks..., node!(SendButton, e, :send))
  else
    marks
  end
end

"""
The runs of lines of the page that were changed from outside, by an agent,
since you last sent the page, or since it was opened. Lines that were removed
leave nothing to show.
"""
theirs(e) = begin
  b = e.buf
  none = UnitRange{Int}[]
  (readonly(b) || b.sent === b.told) && return none
  # They're worked out again when the text changes, or what the agent knows
  key = (objectid(b.sent), objectid(b.told), b.version)
  kept = get(e.nodes, :theirs, nothing)
  kept !== nothing && kept[1] == key && return kept[2]::Vector{UnitRange{Int}}
  mine = changes(b.told, b.lines)   # your own changes since, which move the agent's lines down or up
  runs = UnitRange{Int}[]
  for (_, new) in changes(b.sent, b.told)
    isempty(new) && continue
    lo, hi = follow(mine, first(new)), follow(mine, last(new))
    push!(runs, min(lo, hi):max(lo, hi))
  end
  e.nodes[:theirs] = (key, runs)
  runs
end

"True while the bars beside the agent's changes stay on the page that's showing"
marking(e) = get(e.nodes, :marking, "") == e.buf.path

"Show the bars beside the agent's changes until this is called again. The page goes to the first change if none is on screen."
toggle_marks!(e) = begin
  marking(e) && return delete!(e.nodes, :marking)
  e.nodes[:marking] = e.buf.path
  runs = theirs(e)
  (isempty(runs) || isempty(e.layout)) && return
  touches(it) = any(r -> first(r) <= it.last && last(r) >= it.first, runs)
  _, h = window_size(e)
  seen = filter(it -> it.top + it.tall > e.scroll.offset && it.top < e.scroll.offset + h - TOPBAR_H - PAGE_TOP, e.layout)
  any(touches, seen) && return
  i = findfirst(touches, e.layout)
  i === nothing || (e.scroll.offset = max(0px, e.layout[i].top - 80px))
  nothing
end

"The name of the agent that works on the page, as the owner of something: \"Claude's\""
whose(e) = get(e.nodes, :agent, "the agent")::String * "'s"

# The button is a bell, the size of the other buttons in the top bar. It's in the
# accent colour while an agent waits. After a click it's dim, and only an outline, and does nothing.
describe(s::SendButton) = begin
  e = editor(s)
  ishovered(s) || (s.quiet = false)
  waits = !isempty(agents(e))
  Box(width(30px), height(28px), radius(6px), Alignment.Center, name="Nudge",
      background(waits && ishovered(s) ? colours.hover : clear),
    Icon(waits ? "bell-fill" : "bell", size=15px, color=waits ? colours.accent : colours.dim))
end

cursor(s::SendButton) = isempty(agents(editor(s))) ? :arrow : :hand

onkey(s::SendButton, ::KeyPress{Keys.mouse_left}) = (e = editor(s); send!(e); hush!(s); focus(e))

# --- a job in Centient from the page ------------------------------------------------------
#
# A project page is one whose front matter has a `progress` line with a web
# address. The walkthrough service keeps the page's tasks at that address. For
# a project page, the top bar has a button that makes the page's job in
# Centient: Centient reads the tasks from the address and gives each trade a
# task. Centient needn't be open, and nothing waits for it. Words under the
# button say that Centient works, and then what it made or why it couldn't.
# They stay for a few seconds, and they're the button's tooltip after that.

const JOB_SHOWS = 8   # seconds that Centient's answer stays under the button

"What Kaydown asked Centient to make from a page, and what the button says of it"
mutable struct JobAsk
  path::String      # the page's file
  request::Any      # what Centient was asked, or nothing once it has answered
  said::String      # what the button says
  wrong::Bool       # true when `said` is why Centient couldn't
  at::Float64       # when Centient was asked, and then when it answered
  shows::Bool       # true while the words are under the button
end

"What the front matter of `lines` sets `key` to, without quotes around it, or nothing if it has no such key"
matter_value(lines, key) = begin
  t = front_matter(lines)
  t == 0 && return nothing
  for (_, k, v) in matter_rows(lines, t)
    k == key && return String(strip(strip(v), ['"', '\'']))
  end
  nothing
end

"The web address of the page's tasks, from the `progress` line of its front matter, or nothing if the page isn't a project page"
progress_address(e) = begin
  url = matter_value(e.buf.lines, "progress")
  url !== nothing && startswith(url, r"https?://") ? url : nothing
end

"What Centient needs to make the page's job: the progress address, the page's first # heading, the property and the purpose from the front matter, and where the page's file is, which the job keeps as its PRD"
job_args(e) = begin
  b = e.buf
  args = Dict{String,Any}("progress" => progress_address(e))
  isempty(b.path) || (args["page"] = abspath(b.path))
  headings = outline(b)
  i = findfirst(h -> h.level == 1, headings)
  i === nothing || isempty(headings[i].title) || (args["title"] = headings[i].title)
  for key in ("property", "purpose")
    value = matter_value(b.lines, key)
    value === nothing || isempty(value) || (args[key] = value)
  end
  args
end

"What Kaydown asked Centient to make from the page that shows, or nothing"
job(e) = (j = get(e.nodes, :job_ask, nothing); j !== nothing && j.path == e.buf.path ? j : nothing)

"True while Centient makes a job"
making(e) = (j = get(e.nodes, :job_ask, nothing); j !== nothing && j.request !== nothing)

"True for a button of the top bar that does nothing now: the one that makes the job, when the Mac has no Centient or Centient makes a job"
off(b::ToolButton) = b.action == :job && (!Centient.available() || making(editor(b)))

"What the top bar shows for a project page: the button that makes the page's job in Centient"
job_part(e) = progress_address(e) === nothing ? () : (button(e, :job, "hammer"), Box(width(4px)))

"What the tooltip of the button that makes the job says: what the button does, or what happened when it did it"
job_tip(e) = begin
  Centient.available() || return "Centient isn't on this Mac"
  j = job(e)
  j === nothing ? "Make job in Centient" : j.said
end

"Ask Centient to make the page's job. Centient answers later, and `job_tick!` takes the answer."
make_job!(e) = begin
  (progress_address(e) === nothing || !Centient.available() || making(e)) && return
  e.nodes[:job_ask] = JobAsk(e.buf.path, Centient.ask("make_job_from_page", job_args(e)), "Making the job in Centient…", false, time(), false)
  nothing
end

"What to say of the job that Centient made, or that it had. `made` is Centient's answer."
job_words(made) = begin
  n(key) = (x = get(made, key, 0); x isa Real ? round(Int, x) : 0)
  some(k, thing) = "$k $thing$(k == 1 ? "" : "s")"
  title = string(something(get(made, "title", nothing), ""))
  if get(made, "existed", false) === true
    return n("added") > 0 ? "Centient added $(some(n("added"), "new task")) to the job $title." : "Centient has this job already: $title."
  end
  company = Centient.server.company
  "Centient has the job $title$(isempty(company) ? "" : " in $company"), with $(some(n("steps"), "task")) for $(some(n("tasks"), "trade"))."
end

"""
What happens to the page's job in each frame: Centient's answer is taken, and
the words about it show under the button while Centient works and for a few
seconds after it answers.
"""
job_tick!(e) = begin
  j = get(e.nodes, :job_ask, nothing)
  j === nothing && return
  r = j.request
  if r !== nothing
    Centient.check!()
    if Centient.finished(r)
      j.request, j.at = nothing, time()
      j.wrong = Centient.failed(r) || !(r.value isa AbstractDict)
      j.said = Centient.failed(r) ? r.problem : j.wrong ? "Centient gave an answer that Kaydown can't read" : job_words(r.value)
    else
      redraw_in!(e, 0.1)   # while Centient works, the window looks again soon
    end
  end
  win, b = window_of(e), get(e.nodes, :job, nothing)
  (win === nothing || b === nothing) && return
  left = j.request === nothing ? JOB_SHOWS - (time() - j.at) : Inf
  if left > 0 && j.path == e.buf.path && progress_address(e) !== nothing
    # The words look as a tooltip does. They stay while the mouse moves, which a tooltip doesn't.
    popup!(win, Bubble(content=Box(padding(8px, 5px), label(j.said, 12px, color=TIP_INK)), target=b.rect),
           anchor=b.rect, placement=:bottom, gap=6px, key=:job, input=false)
    j.shows = true
    isfinite(left) && redraw_in!(e, left)   # to take them away
  elseif j.shows
    close_popup!(win, :job)
    j.shows = false
  end
  nothing
end

describe(t::TopBar) = begin
  e = editor(t)
  b = e.buf
  side = 250px
  ended_rename!(e)
  # The top bar lies over the top of the sidebar. The file's name is in the
  # middle of the space beside the sidebar, so it moves as the sidebar slides.
  Row(width(grow=grow), height(TOPBAR_H), name="TopBar",
    # The close, minimise and zoom buttons sit over the first 84px
    Row(fixed(side + panel_w(e) * opened(e)), height(grow=grow), padding(0px, 0px, 0px, 84px),
      button(e, :panel, "layout-sidebar")),
    Box(width(grow=grow), height(grow=grow), clip=true, node!(Title, e, :title)),
    Row(fixed(side), height(grow=grow), justify=Alignment.End, padding(0px, 10px, 0px, 0px),
      # A file that's only shown has no words to count. The bar says that it's only shown.
      (readonly(b) ? (Box(height(28px), padding(8px, 0px), label(isempty(b.about) ? "Read only" : b.about * "  ·  Read only", 12px, color=colours.dim)),
                      # The app that the Mac uses for the file can change it, so a button opens the file there
                      button(e, :outside, "box-arrow-up-right")) :
                     (job_part(e)..., agent_part(e)..., node!(Count, e, :count)))...))
end

# The window has no title bar, so you move it by dragging the top bar
onkey(t::TopBar, ::KeyPress{Keys.mouse_left}) = drag_window!(window_of(t))

# A right-click on the file's name shows the same menu as a right-click on the
# file in the sidebar. While the file is renamed from there, a text field with
# its name is where the name was.

describe(t::Title) = begin
  e = editor(t)
  b = e.buf
  if !isempty(b.path) && renaming(e, :title) == b.path
    # The field grows as the name gets longer
    wide = clamp(measure(Face(SANS, "", 13px, colours.ink, false), renamer(e).text) + 24px, 160px, 420px)
    return Box(width(wide), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
               border(1px, :solid, colours.accent), renamer(e))
  end
  Row(child_gap=6px,
    label(name(b), 13px, color=colours.dim),
    (dirty(b) ? (label("— edited", 13px, color=colours.faint),) : ())...)
end

onkey(t::Title, ::KeyPress{Keys.mouse_right}) = begin
  e = editor(t)
  isempty(e.buf.path) || file_menu!(e, window_of(t), e.buf.path; at=:title)
  handled
end

# --- the sidebar --------------------------------------------------------------------------

title(path) = splitext(basename(path))[1]

describe(r::FileRow) = begin
  e = editor(r)
  picked = r.finder == e.picked
  changed = haskey(e.buffers, r.path) && dirty(e.buffers[r.path])
  Row(width(grow=grow), height(28px), padding(0px, 10px), radius(6px), child_gap=8px, clip=true, name="File",
      background(picked ? colours.active : ishovered(r) ? colours.hover : clear),
    Icon("file-earmark-text", size=13px, color=colours.dim),
    Box(width(grow=grow), Alignment.Start, label(title(r.path), weight=picked ? "Semibold" : "")),
    (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim)),) : ())...)
end

cursor(::FileRow) = :hand

onkey(r::FileRow, ::KeyPress{Keys.mouse_left}) = open!(editor(r), r.path)

# The sidebar is a tree, UI.jl's ListTree. Each file of the folder is a group.
# The items in it are the file's headings and its components: the sheets and
# what its `ui` blocks show. A heading is a group too when it has smaller
# headings or components under it. The tree keeps which groups are open and
# which item the keyboard is on.
#
# Each item starts with an icon that says what it is. The tree draws no arrows.
# While the mouse is over a group, the group's icon is an arrow that shows
# whether it's open, and a click on the icon opens or closes the group.

"The icon that a file, a heading or a component starts with in the sidebar, in the place a tree has its arrow"
mark(l, icon; size=13px) = begin
  item = l.parent
  # A file that's open and has nothing under it has no arrow, since there's nothing to open or close.
  # A closed file might have headings, so it has one.
  over = item isa Tree.ItemGroup && Tree.hovered(item) && (item.collapsed || any(c -> c isa Tree.TreeItem, item.children))
  Box(width(18px), height(grow=grow), Alignment.Center,
    (isempty(icon) ? () : (Icon(over ? (item.collapsed ? "chevron-right" : "chevron-down") : icon,
                                size=over ? 10px : size, color=colours.dim),))...)
end

describe(l::FileLabel) = begin
  e = editor(l)
  changed = haskey(e.buffers, l.path) && dirty(e.buffers[l.path])
  # While the file is renamed, a text field with its name is where the name was
  name = renaming(e, :sidebar) == l.path ?
    Box(width(grow=grow), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
        border(1px, :solid, colours.accent), renamer(e)) :
    isdir(l.path) ? Box(width(grow=grow), Alignment.Start, label(basename(l.path))) :
    ismarkdown(l.path) ?
    Box(width(grow=grow), Alignment.Start, label(title(l.path), weight=l.path == e.buf.path ? "Semibold" : "")) :
    # A file that Kaydown only shows has its whole name, and it's fainter until it's the file that shows
    Box(width(grow=grow), Alignment.Start, label(basename(l.path), color=l.path == e.buf.path ? colours.ink : colours.dim,
                                                 weight=l.path == e.buf.path ? "Semibold" : ""))
  # A page that an agent waits for has a dot in the colour of the Nudge button
  awaited = ismarkdown(l.path) && !isempty(agents(e, l.path))
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="File",
    mark(l, isdir(l.path) ? "folder" : ismarkdown(l.path) ? "file-earmark-text" : file_icon(l.path)),
    name,
    (awaited ? (Box(width(6px), height(6px), radius(3px), background(colours.accent)),) : ())...,
    (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim)),) : ())...)
end

describe(l::EntryLabel) =
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="Entry",
    mark(l, l.icon),
    Box(width(grow=grow), Alignment.Start, label(l.title, 12px, color=l.line == 0 ? colours.faint : colours.dim)))

# The name that the sidebar gives each component of UI.jl, and its icon
const COMPONENTS = Dict(
  "Checkbox" => ("Checkbox", "check2-square"), "Toggle" => ("Switch", "toggle-on"),
  "RadioGroup" => ("Radio buttons", "ui-radios"), "Dropdown" => ("Menu", "menu-button-wide"), "Select" => ("Menu", "menu-button-wide"),
  "Slider" => ("Slider", "sliders"), "ColorPicker" => ("Colour picker", "palette"),
  "TextInput" => ("Text field", "input-cursor-text"), "KeyCombo" => ("Keys", "command"),
  "Tooltip" => ("Tooltip", "chat-square-text"), "ListTree" => ("Tree", "list-nested"),
  "Inspector" => ("Inspector", "braces"), "Table" => ("Table", "table"), "Button" => ("Button", "hand-index"),
  "ProgressBar" => ("Progress bar", "hr"), "STLViewer" => ("3D model", "box"),
  "AudioPlayer" => ("Sound", "music-note-beamed"), "VideoPlayer" => ("Video", "film"), "AudioRecorder" => ("Recorder", "mic"),
  "Mermaid" => ("Diagram", "diagram-3"))
const LAYOUTS = ("Box", "Row", "Column", "Stack", "Scroll", "Text", "Image")
"Every icon that the sidebar can show. The built app reads them all when it's made."
const SIDEBAR_ICONS = unique(["file-earmark-text", "chevron-right", "chevron-down", "calculator", "grid-3x3", "puzzle", "bounding-box", "rulers", "bar-chart-steps",
                              ("type-h$n" for n in 1:6)..., (icon for (_, icon) in values(COMPONENTS))...])

"""
The name and the icon of what a block of `ui` code shows. It's read from the
code, so the block needn't have run: the first component of UI.jl that the
code names, or else the first thing it makes that isn't a layout.
"""
component(code) = begin
  made = String[]
  for line in code
    startswith(lstrip(line), "@use") && continue
    append!(made, (m[1] for m in eachmatch(r"\b([A-Z]\w*)\(", line)))
  end
  i = findfirst(name -> haskey(COMPONENTS, name), made)
  i === nothing || return COMPONENTS[made[i]]
  i = findfirst(name -> !(name in LAYOUTS) && !isdefined(Base, Symbol(name)), made)
  i === nothing ? ("Layout", "bounding-box") : (made[i], "puzzle")
end

"The headings and the components among `lines`, from the top"
outline(lines::Vector{String}, kinds::Vector{Line}) = begin
  out = Entry[]
  for (i, l) in enumerate(kinds)
    if l.kind == Kind.heading
      push!(out, Entry(i, l.level, rest(lines[i], l.prefix), "type-h$(l.level)", i))
    elseif l.kind == Kind.fence && l.level == 0 && l.lang in (LIVE, SHEET, SPREADSHEET, DIAGRAM, TAKEOFF, SCHEDULE)
      # The line that closes the block, or the last line when nothing closes it
      close = something(findnext(k -> k.kind == Kind.fence, kinds, i + 1), length(lines))
      if l.lang == SHEET
        push!(out, Entry(i, 7, "Sheet", "calculator", min(i + 1, length(lines))))
      elseif l.lang == SPREADSHEET
        push!(out, Entry(i, 7, "Spreadsheet", "grid-3x3", min(i + 1, length(lines))))
      elseif l.lang == TAKEOFF
        # The caret goes under the block. In the block, it would show the block's lines.
        push!(out, Entry(i, 7, "Takeoff", "rulers", min(close + 1, length(lines))))
      elseif l.lang == SCHEDULE
        push!(out, Entry(i, 7, "Schedule", "bar-chart-steps", min(close + 1, length(lines))))
      elseif l.lang == DIAGRAM
        # Code that can't be drawn as a diagram is a code block like any other.
        # The caret goes under the block. In the block, it would show the block's code.
        isdiagram(join(view(lines, i+1:close-1), "\n")) && push!(out, Entry(i, 7, "Diagram", "diagram-3", min(close + 1, length(lines))))
      else
        name, icon = component(view(lines, i+1:close-1))
        # The caret goes under the block. In the block, it would show the block's code.
        push!(out, Entry(i, 7, name, icon, min(close + 1, length(lines))))
      end
    end
  end
  out
end
outline(b::Buffer) = outline(b.lines, kinds(b))

"""
The headings and the components of the file at `path`. A file that has been
opened gives those of its text as it is now, with the changes that aren't
saved. Any other file is read from the disk, and read again when it changes there.
"""
outline(e::Editor, path::String) = begin
  haskey(e.buffers, path) && return outline(e.buffers[path])
  isfile(path) || return Entry[]
  at = mtime(path)
  kept = get(e.nodes, (:read, path), nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  lines = text(path)
  found = outline(lines, classify(lines))
  e.nodes[(:read, path)] = (at, found)
  found
end

const SIDEBAR_GUIDES = true   # draw the lines that join each item in the sidebar to the item it's in

"The sidebar's tree"
file_tree(e) = node!(() -> Tree.ListTree(guides=SIDEBAR_GUIDES, frame=false, arrows=false, onchoose=item -> choose!(e, item)), e, :tree)

"The items in `parent` and in the groups in it, from the top. With `hidden`, those in a closed group too."
items(parent; hidden=false, out=Tree.TreeItem[]) = begin
  for item in parent.children
    item isa Tree.TreeItem || continue
    push!(out, item)
    item isa Tree.ItemGroup && (hidden || !item.collapsed) && items(item; hidden, out)
  end
  out
end

"""
A click on the name of a file shows the file in the page. A file that isn't
Markdown is only shown: the page doesn't change it. A folder shows its own folders and files. A click on a heading or a
component goes to it, and opens its file first if another file is showing.
Return does the same for the item the keyboard is on. Each gives the keyboard
to the text.
"""
choose!(e, item) = begin
  l = item.firstchild
  l isa FileLabel && isdir(l.path) && return (go_folder!(e, l.path); e.nodes[:chose] = true; nothing)
  # A group's name shows what's in the group. Only its icon hides that.
  item isa Tree.ItemGroup && (item.collapsed = false)
  l.path == e.buf.path || open!(e, l.path)
  focus(e)
  e.nodes[:chose] = true
  (l isa EntryLabel && l.line > 0) || return
  b = e.buf
  b.reading = false
  line = clamp(l.caret, 1, length(b.lines))
  b.caret = b.anchor = settle(b, (line, length(b.lines[line])))
  # Put its first line near the top of the window rather than just on screen.
  # The next frame does it, once it has laid out the file that's showing.
  e.nodes[:hold] = (clamp(l.line, 1, length(b.lines)), 24px - PAGE_TOP)
  e.blink = time()
end

"Put the headings and the components of a file in its group, when they aren't the ones that it has"
outline!(e, group) = begin
  path = group.firstchild.path
  found = outline(e, path)
  found == get(e.nodes, (:outline, path), nothing) && return
  e.nodes[(:outline, path)] = found
  old = items(group, hidden=true)
  labels = [item.firstchild for item in old]
  if !isempty(found) && length(labels) == length(found) &&
     all(l.level == x.level && l.title == x.title && l.icon == x.icon for (l, x) in zip(labels, found))
    # The same ones on other lines, as when a line is typed above them
    foreach((l, x) -> (l.line = x.line; l.caret = x.caret), labels, found)
    return
  end
  closed = Set((item.firstchild.level, item.firstchild.title) for item in old if item isa Tree.ItemGroup && item.collapsed)
  foreach(detach!, [item for item in group.children if item isa Tree.TreeItem])
  # A file with no headings or components has nothing under it
  isempty(found) && return
  # Each one goes in the nearest heading above it that is bigger
  above = Any[(0, group)]
  for (k, x) in enumerate(found)
    while above[end][1] >= x.level
      pop!(above)
    end
    label = EntryLabel(path=path, line=x.line, level=x.level, title=x.title, icon=x.icon, caret=x.caret)
    if k < length(found) && found[k+1].level > x.level
      item = Tree.ItemGroup(label)
      item.collapsed = (x.level, x.title) in closed
      add_child!(above[end][2], item)
      push!(above, (x.level, item))
    else
      add_child!(above[end][2], Tree.Item(label))
    end
  end
end

"The item for where the caret is: the last heading or component above it that shows, or its file"
here(e, tree) = begin
  i = findfirst(group -> group.firstchild.path == e.buf.path, collect(tree.children))
  i === nothing && return nothing
  group = collect(tree.children)[i]
  (!(group isa Tree.ItemGroup) || group.collapsed) && return group
  at = findlast(item -> 0 < item.firstchild.line <= e.buf.caret[1], items(group))
  at === nothing ? group : items(group)[at]
end

"Make the sidebar's tree show the folder's files and the headings of each file that's open in it"
fill_tree!(e, tree) = begin
  tree.guides = SIDEBAR_GUIDES
  if [group.firstchild.path for group in tree.children] != e.listed
    kept = Dict(group.firstchild.path => group for group in tree.children)
    foreach(detach!, collect(tree.children))
    for p in e.listed
      add_child!(tree, get(kept, p) do
        delete!(e.nodes, (:outline, p))   # a new group has no headings in it yet
        # A file that isn't Markdown has no headings to list
        isfile(p) && ismarkdown(p) ? Tree.ItemGroup(FileLabel(path=p)) : Tree.Item(FileLabel(path=p))
      end)
    end
  end
  for group in tree.children
    group isa Tree.ItemGroup && !group.collapsed && outline!(e, group)
  end
  ended_rename!(e)
  w = window_of(e)
  shown = items(tree)
  if w === nothing || w.focus !== tree
    # While the text has the keyboard, the tree marks where the caret is
    tree.focused = here(e, tree)
  elseif !any(item -> item === tree.focused, shown)
    tree.focused = something(here(e, tree), get(shown, 1, nothing), Some(nothing))
  elseif tree.focused !== get(e.nodes, :tree_at, nothing)
    # An arrow key moved to another item. Keep it in sight.
    high = Tree.ROW_HEIGHT   # the height of a row while the theme's text has its usual size, as the sidebar's has
    row = findfirst(item -> item === tree.focused, shown)
    scroll_into_view!(e.files_scroll, high * (row - 1), high * row)
  end
  e.nodes[:tree_at] = tree.focused
  tree
end

"The colours of the sidebar's tree"
panel_theme() = Theme(size=Tree.LABEL_SIZE, surface=colours.panel, text=colours.ink, dim=colours.dim, line=colours.line,
                      hover=colours.hover, select=colours.active, family=SANS)

# --- the menu of a file ---------------------------------------------------------------------
#
# A right-click on a file in the sidebar, or on the name of the file that shows
# in the top bar, shows a menu that renames the file, copies its path, shows it
# in the Finder or moves it to the Trash. It's a menu of macOS's own, so it
# looks and works like the other menus on the Mac. A window that isn't on a
# screen, like the one a test makes, gets a menu that Kaydown draws.

const FILE_MENU = ["Rename", "Copy Path", "Show in Finder", "-", "Move to Trash"]   # "-" is a line between two groups

# A menu's text is 13/12 of its theme's size. This size makes it 13px, the size of a file's name in the sidebar.
"The colours and the text size of a menu that floats over the window"
menu_theme() = Theme(size=12px, surface=colours.float, text=colours.ink, dim=colours.dim, line=colours.line,
                     hover=colours.hover, select=colours.active, family=SANS)

"""
Show the menu of the file at `path`. `at` is where you right-clicked: the
file's name in the `:sidebar` or in the `:title` of the top bar. Rename puts
the text field there.
"""
file_menu!(e, w, path; at=:sidebar) = begin
  act(i) = file_act!(e, path, get(FILE_MENU, i, ""); at)
  # A new file that isn't saved yet isn't on the disk, so the Finder can't show it
  off = isfile(path) ? () : (findfirst(==("Show in Finder"), FILE_MENU),)
  system_menu(w, FILE_MENU, act; off) || drawn_menu!(w, FILE_MENU, act; off)
  nothing
end

"Do to the file at `path` what the item `name` of its menu says"
file_act!(e, path, name; at=:sidebar) =
  name == "Rename" ? rename!(e, path; at) :
  name == "Copy Path" ? clipboard(path) :
  name == "Show in Finder" ? show_in_finder(path) :
  name == "Move to Trash" ? trash!(e, path) : nothing

"Open a Finder window on the folder of the file at `path`, with the file selected"
show_in_finder(path) = (Sys.isapple() && ispath(path) && run(pipeline(`open -R $path`, stdout=devnull, stderr=devnull), wait=false); nothing)

"Show the menu of the file in the sidebar that the mouse is over, if it's over one"
file_menu!(e, w) = begin
  e.panel || return
  tree = file_tree(e)
  item = Tree.item_under(tree, w)
  (item === nothing || !(item.firstchild isa FileLabel)) && return
  path = item.firstchild.path
  isdir(path) && return
  # The tree takes the keyboard, so the file that the menu is for stays marked
  focus(tree)
  tree.focused = item
  file_menu!(e, w, path)
end

"The text field that a file's new name is typed in"
renamer(e) = node!(e, :renamer) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
Start to rename the file at `path`. Its name becomes a text field, in the
sidebar or in the top bar, as `at` says. The sidebar's field has the name
without its ending, all selected. The top bar shows the whole name, so its
field has the whole name, with the part before the ending selected.
"""
rename!(e, path; at=:sidebar) = begin
  i = renamer(e)
  i.color = colours.ink
  i.text = at == :title ? basename(path) : title(path)
  i.anchor, i.cursor = 0, length(title(path))
  e.nodes[:renaming] = path
  e.nodes[:renaming_at] = at
  focus(i)
end

"The path of the file that's being renamed in `at`, the `:sidebar` or the `:title`. It's \"\" when none is."
renaming(e, at) = get(e.nodes, :renaming_at, :sidebar) == at ? get(e.nodes, :renaming, "") : ""

"Take the text field away. The keyboard goes back to the sidebar, or to the text when the field was in the top bar."
stop_rename!(e) = begin
  delete!(e.nodes, :renaming)
  pop!(e.nodes, :renaming_at, :sidebar) == :title ? focus(e) : focus(file_tree(e))
end

"Return gives the file the name that's typed, and esc leaves it with the name it has"
rename_key!(e, K) = begin
  if K == Keys.escape
    stop_rename!(e)
  elseif K == Keys.enter && finish_rename!(e)
    stop_rename!(e)
  end
  nothing
end

"A click somewhere else while a file is renamed gives the file the name that's typed"
ended_rename!(e) = begin
  w = window_of(e)
  (w === nothing || !haskey(e.nodes, :renaming) || w.focus === renamer(e)) && return
  finish_rename!(e)
  delete!(e.nodes, :renaming)
  delete!(e.nodes, :renaming_at)
  nothing
end

"""
Give the file that's being renamed the name in the text field. The file keeps
its ending, like .md, unless the name is typed with one: a Markdown ending, or
the ending it has. It's false when another file has that name already, and
then nothing changes.
"""
finish_rename!(e) = begin
  old = get(e.nodes, :renaming, "")
  name = String(strip(renamer(e).text))
  (isempty(old) || isempty(name) || occursin('/', name)) && return true
  ending = splitext(old)[2]
  typed = ismarkdown(name) || lowercase(splitext(name)[2]) == lowercase(ending)
  new = joinpath(dirname(old), typed ? name : name * ending)
  new == old && return true
  # A Mac's disk takes Notes.md and notes.md to be one file, so a change of capitals isn't a clash
  ispath(new) && lowercase(new) != lowercase(old) && return false
  move!(e, old, new)
  true
end

"Give the file at `old` the path `new`: on the disk, and in everything the editor keeps by path"
move!(e, old, new) = begin
  if isfile(old)
    try
      Base.Filesystem.rename(old, new)
    catch
      return   # the disk said no, so the file keeps its name
    end
  end
  if haskey(e.buffers, old)
    b = e.buffers[new] = pop!(e.buffers, old)
    b.path = new
  end
  haskey(READ, old) && (READ[new] = pop!(READ, old))
  for kind in (:read, :outline)
    haskey(e.nodes, (kind, old)) && (e.nodes[(kind, new)] = pop!(e.nodes, (kind, old)))
  end
  for item in items(file_tree(e), hidden=true)
    item.firstchild.path == old && (item.firstchild.path = new)
  end
  list_files!(e)
end

"Move the file at `path` to the Trash. It's true when the file went there."
trash(path) = begin
  Sys.isapple() || return false
  try
    with_pool() do
      url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
      ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            msg(cls("NSFileManager"), "defaultManager"), sel("trashItemAtURL:resultingItemURL:error:"), url, C_NULL, C_NULL)
    end && !ispath(path)
  catch
    false
  end
end

# What moves a file to the Trash. A test puts a function of its own here, so it doesn't fill the Trash.
const trasher = Ref{Function}(trash)

"""
Move the file at `path` to the Trash and take it out of the sidebar. Changes
that aren't saved are written to the file first, so they are in the Trash
too. If the file was showing, the next file in the sidebar shows.
"""
trash!(e, path) = begin
  b = get(e.buffers, path, nothing)
  b !== nothing && dirty(b) && save!(b)
  isfile(path) && !trasher[](path) && return
  at = something(findfirst(==(path), e.files), 1)
  delete!(e.buffers, path)
  delete!(READ, path)
  delete!(e.nodes, (:read, path))
  delete!(e.nodes, (:outline, path))
  delete!(e.nodes, (:fileview, path))
  list_files!(e)
  if e.buf.path == path
    open!(e, isempty(e.files) ? joinpath(e.folder, "Untitled.md") : e.files[min(at, end)])
  else
    focus(e)
  end
  e
end

"Show the sidebar, if it's hidden, and give it the keyboard"
focus_panel!(e) = begin
  e.panel || toggle_panel!(e)
  focus(file_tree(e))
end

"""
The sidebar keeps its width as it slides in and out from the left edge of the
window, so only its right part shows while it's partly out. It lists the
folder's files, and under each file that's open in the list, that file's
headings and components.
"""
describe(s::Sidebar) = begin
  e = editor(s)
  wide = panel_w(e)
  shows = wide * opened(e)
  tree = with_theme(() -> describe!(fill_tree!(e, file_tree(e))), panel_theme())
  Row(fixed(shows), height(grow=grow), Alignment.Start, clip=true,
    Column(fixed(wide), height(grow=grow), Alignment.Start, background(colours.panel), name="Files",
           border(1px, :solid, colours.line)[:right], offset_x=shows - wide,
      Box(width(grow=grow), height(TOPBAR_H)),   # under the top bar
      Row(width(grow=grow), height(30px), padding(16px, 0px), Alignment.Center, clip=true, name="Folder",
        folder_trail(e, wide - 32px)...),
      reuse!(e.files_scroll,
        Column(width(grow=grow), Alignment.Start, padding(0px, 8px, 12px, 8px), tree))))
end

# --- the edge of the sidebar ----------------------------------------------------------
#
# Drag the line at the sidebar's right edge to make the sidebar wider or
# narrower. A strip a few pixels wide lies over the line, so the mouse
# catches it easily, and the cursor shows arrows that point left and right
# over it. The sidebar keeps the width you give it, in the settings file too.

const EDGE_W = 8px   # how wide the strip is. Half of it is over the sidebar and half over the page.

@def mutable struct PanelEdge <: SemanticUI
  grab::px = 0px   # how far right of the sidebar's edge the mouse was when the drag started
end

describe(::PanelEdge) = Box(width(EDGE_W), height(grow=grow), name="Edge")

cursor(::PanelEdge) = :resize_x

onkey(p::PanelEdge, ev::KeyPress{Keys.mouse_left}) = (p.grab = ev.window.mouse[1] - panel_w(editor(p)); handled)

onmouse(p::PanelEdge, ev::MouseMove) = begin
  held(p, Keys.mouse_left) || return
  side!(editor(p), ev.position[1] - p.grab)
  handled
end

"The strip over the sidebar's edge, while the sidebar is open and not sliding. It starts under the top bar."
panel_edge(e) = e.panel && !sliding(e) ?
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(TOPBAR_H, 0px, 0px, panel_w(e) - EDGE_W / 2),
       node!(PanelEdge, e, :edge)),) : ()

# --- the folder at the top of the sidebar ---------------------------------------------

const TRAIL_SIZE = 12px
const TRAIL_ARROW = 7px   # the size of the arrow between two names
const TRAIL_GAP = 2px     # on each side of an arrow
const TRAIL_PAD = 3px     # inside a name, on each side, so its hover background has room

"""
The names of the folders on the way to `folder`, each with where it is, in no
more than `room` with an arrow between each two. The sidebar is narrow, so when
the names don't fit, the ones furthest from the folder shrink to their first
letter, from the left, like `~ › D › Canon › City`. If that still doesn't fit, an
… takes the place of names after the first, and last of all the folder's own
name loses its middle. The … has no path.
"""
trail_names(folder, room) = begin
  short = steps(folder)
  face(i) = Face(SANS, i == length(short) ? "Semibold" : "", TRAIL_SIZE, colours.ink, false)
  wide() = sum(i -> measure(face(i), short[i][1]) + 2TRAIL_PAD, eachindex(short)) + (length(short) - 1) * (TRAIL_ARROW + 2TRAIL_GAP)
  # A hidden folder keeps its dot, so .config shrinks to .c
  initial(n) = startswith(n, '.') ? first(n, 2) : first(n, 1)
  for i in 2:length(short)-1
    wide() <= room && return short
    short[i] = (initial(short[i][1]), short[i][2])
  end
  while wide() > room && length(short) > 2 && short[2][1] != "…"
    # The first name stays, so the trail still shows where it starts
    deleteat!(short, 2)
    length(short) > 2 ? (short[2] = ("…", "")) : insert!(short, 2, ("…", ""))
  end
  while wide() > room && length(short) > 3
    deleteat!(short, 3)
  end
  # A folder whose own name is too long loses the middle of it
  name, at = short[end]
  k = length(name) ÷ 2
  while wide() > room && k > 2
    k -= 1
    short[end] = (first(name, k) * "…" * last(name, k), at)
  end
  short
end

"One name in the trail at the top of the sidebar. A click shows that folder in the sidebar."
@def mutable struct TrailName <: SemanticUI
  path::String = ""   # empty for the … that stands for names left out
  name::String = ""
  last::Bool = false  # the folder that the sidebar shows
end

"The folder at the top of the sidebar, as a trail of names"
folder_trail(e, room) = begin
  names = trail_names(e.folder, room)
  arrow() = Box(padding(TRAIL_GAP, 0px), Icon("chevron-right", size=TRAIL_ARROW, color=colours.faint))
  parts = Any[]
  for (i, (n, at)) in enumerate(names)
    i > 1 && push!(parts, arrow())
    # Each name is kept, so it knows when the mouse is over it
    t = node!(() -> TrailName(), e, (:trail, i))
    t.path, t.name, t.last = at, n, i == length(names)
    push!(parts, t)
  end
  parts
end

goes(t::TrailName) = !t.last && !isempty(t.path)

describe(t::TrailName) =
  Box(padding(TRAIL_PAD, 1px), radius(4px), background(goes(t) && ishovered(t) ? colours.hover : clear),
    label(t.name, TRAIL_SIZE, color=t.last ? colours.ink : colours.dim, weight=t.last ? "Semibold" : ""))

cursor(t::TrailName) = goes(t) ? :hand : :arrow

onkey(t::TrailName, ::KeyPress{Keys.mouse_left}) = goes(t) ? (go_folder!(editor(t), t.path); handled) : nothing

floating(children...; w) =
  Column(fixed(w), radius(9px), Alignment.Start, background(colours.float), border(1px, :solid, colours.line), lifted, children...)

# The backdrop dims the window behind the file finder
describe(b::Backdrop) = Box(width(grow=grow), height(grow=grow), background(colours.shade))
onkey(b::Backdrop, ::KeyPress) = (e = editor(b); e.popup = :none; focus(e))

# --- the menu of the page ------------------------------------------------------------------
#
# A right-click on the page opens a menu at the mouse: cut, copy, paste, select
# all, find, export and Insert. On a word that's spelt wrong, the menu starts
# with the words it may have been meant to be. Insert opens a menu of the kinds of block that a page can
# hold. A right-click on the selection keeps it. Anywhere else, it puts the
# caret there first.

"""
What the Insert menu adds. Each one has its name, the lines of the block, and
the line and the column of the block that the caret goes to. "-" is a line
between two groups.
"""
const INSERTS = [
  ("Paragraph",     [""],                           (1, 0)),
  ("Heading 1",     ["# "],                         (1, 2)),
  ("Heading 2",     ["## "],                        (1, 3)),
  ("Heading 3",     ["### "],                       (1, 4)),
  "-",
  ("Bulleted List", ["- "],                         (1, 2)),
  ("Numbered List", ["1. "],                        (1, 3)),
  ("To-do",         ["- [ ] "],                     (1, 6)),
  ("Quote",         ["> "],                         (1, 2)),
  "-",
  ("Table",         ["|  |  |  |", "|---|---|---|", "|  |  |  |", "|  |  |  |"], (1, 2)),
  ("Sheet",         ["```$SHEET", " = ", "```"],    (2, 0)),
  ("Spreadsheet",   ["```$SPREADSHEET", "|  |  |  |", "|  |  |  |", "|  |  |  |", "```"], (2, 2)),
  ("Code",          ["```julia", "", "```"],        (2, 0)),
  ("Live Block",    ["```$LIVE", "", "```"],        (2, 0)),
  ("Diagram",       ["```$DIAGRAM", "flowchart LR", "  A[Start] --> B[End]", "```"], (3, 2)),
  # The caret goes to an empty line under the block. In the block, it would show the block's lines.
  ("Takeoff",       ["```$TAKEOFF", "```", "", ""], (4, 0)),
  ("Schedule",      ["```$SCHEDULE", "```", "", ""], (4, 0)),
  # This one records from the microphone into a new file, and the line shows the recorder. The caret goes
  # to an empty line under it, so that you can type while it records.
  ("Recording",     ["![Recording]()", "", ""],     (3, 0)),
  "-",
  # The caret goes to an empty line under the divider
  ("Divider",       ["---", "", ""],                (3, 0)),
  "-",
  # This one goes at the top of the document, wherever the caret is
  ("Front Matter",  ["---", "title: ", "---"],      (2, 7)),
]

const PAGE_MENU = ["Cut", "Copy", "Paste", "-", "Select All", "-", "Find…", "Export as HTML…", "-",
                   "Insert" => [x isa String ? x : x[1] for x in INSERTS]]

cut!(e) = copy_selection!(e) === false || type!(e, "")
select_all!(e) = begin
  b = e.buf
  b.reading = false   # a selection shows the caret's end of it
  b.anchor, b.caret = (1, 0), line_end(b, length(b.lines))
  e
end

"The last line of the block that line `i` is in: the end of its table or of its code block, or the line itself"
block_end(b::Buffer, i::Int) = begin
  k = kinds(b)[i].kind
  k == Kind.table ? table(b, i)[2] : k in (Kind.fence, Kind.code) ? codeblock(b, i)[2] : i
end

"""
Add a block of `lines` to the document, and put the caret at `at`: a line and
a column of the block. On an empty line, the block takes that line's place.
From any other line, it goes after the block that the caret is in. An empty
line goes between the new block and the text on each side of it. A list item
that's added to a list of its own kind goes straight after the item before it.
"""
add_block!(e, lines::Vector{String}, at::Pos) = begin
  b = e.buf
  ks = kinds(b)
  i = b.caret[1]
  onblank = ks[i].kind == Kind.blank
  t = onblank ? i : block_end(b, i)
  before, after = (onblank ? i - 1 : t), t + 1   # the lines that the block will sit between
  blank(j) = !(1 <= j <= length(ks)) || ks[j].kind == Kind.blank
  kind = Line(lines[1]).kind
  item = kind in (Kind.bullet, Kind.ordered, Kind.todo)
  joins = item && !blank(before) && ks[before].kind == kind
  if joins
    # It's the next item of that list: the next number, and as far in as the item before
    lead = carry(head(b.lines[before], ks[before].prefix), kind)
    lines, at = [lead], (1, length(lead))
  end
  pre = !joins && !blank(before)
  post = !blank(after) && !(item && ks[after].kind == kind)
  new = join([pre ? [""] : String[]; lines; post ? [""] : String[]], "\n")
  onblank ? edit!(b, (i, 0), line_end(b, i), new) : edit!(b, line_end(b, t), line_end(b, t), "\n" * new)
  row = (onblank ? i : t + 1) + pre + at[1] - 1
  b.caret = b.anchor = (row, at[2])
  # In a new table, the first cell is selected, as Tab would leave it
  cells = kinds(b)[row].kind == Kind.table ? tablecells(b.lines[row]) : Cell[]
  isempty(cells) || (b.anchor = (row, cells[1].lo); b.caret = (row, cells[1].hi))
  focus(e)
  touch!(e)
end

"""
Add front matter to the top of the document, and put the caret after its first
key. A document has front matter only once, so if it's there already the caret
just goes to it.
"""
add_front_matter!(e) = begin
  b = e.buf
  if front_matter(b.lines) == 0
    _, lines, _ = last(INSERTS)
    # An empty line goes between the front matter and the text
    edit!(b, (1, 0), (1, 0), join(lines, "\n") * "\n" * (isempty(strip(b.lines[1])) ? "" : "\n"))
  end
  b.caret = b.anchor = line_end(b, 2)
  focus(e)
  touch!(e)
end

"Do what the item at `i` of the page's menu does. `j` is the item's place in the Insert menu, when it's one of those."
page_act!(e, i::Int, j::Int=0) = begin
  name = PAGE_MENU[i] isa Pair ? first(PAGE_MENU[i]) : PAGE_MENU[i]
  if name == "Cut"
    cut!(e)
  elseif name == "Copy"
    copy_selection!(e)
  elseif name == "Paste"
    paste!(e)
  elseif name == "Select All"
    select_all!(e)
  elseif name == "Find…"
    open_find!(e)
  elseif name == "Export as HTML…"
    w = window_of(e)
    w === nothing || export_html!(e, w)
  elseif name == "Insert" && j in eachindex(INSERTS) && INSERTS[j] isa Tuple
    block = INSERTS[j][1]
    block == "Front Matter" ? add_front_matter!(e) : block == "Recording" ? add_recording!(e) : add_block!(e, INSERTS[j][2], INSERTS[j][3])
  end
  nothing
end

"""
Show `items` as a menu that Kaydown draws, for a window that macOS has no menu
for. They're the items that `system_menu` takes. An item that opens a menu
shows that menu in this one's place.
"""
drawn_menu!(w, items, act; off=(), path=(), at=(w.mouse[1], w.mouse[2])) = begin
  isoff(i) = (path..., i) in off || (isempty(path) && i in off)
  shown = [(i, entry) for (i, entry) in enumerate(items) if entry != "-" && !isoff(i)]
  names = [entry isa Pair ? first(entry) * "  ›" : entry for (_, entry) in shown]
  show_menu!(w, names, at[1], at[2], 170px, theme=menu_theme(), item_height=28px, lift=3.0, onselect=k -> begin
    k in eachindex(shown) || return
    i, entry = shown[k]
    entry isa Pair ? drawn_menu!(w, last(entry), act; off, path=(path..., i), at) : act(path..., i)
  end)
end

"Show the page's menu at the mouse"
page_menu!(e, w) = begin
  b = e.buf
  b.view == :file && return nothing   # a viewer has no text to copy or to find
  e.popup = :none
  focus(e)
  at = settle(b, locate(e, w.mouse))
  lo, hi = selection(b)
  # A right-click on the selection keeps it. Anywhere else, it puts the caret there.
  if !(selecting(b) && lo <= at <= hi)
    b.caret = b.anchor = at
    touch!(e)
  end
  # A right-click on a word that's spelt wrong puts the words it may have been meant to be at the top of the menu
  wrong = misspelling_at(e, at)
  fixes = wrong === nothing ? String[] : first(guesses(rest(head(b.lines[wrong[1]], wrong[3]), wrong[2])), 5)
  spell = wrong === nothing ? Any[] : Any[(isempty(fixes) ? ["No Guesses Found"] : fixes)..., "Learn Spelling", "-"]
  n = length(spell)
  act(i, place...) = i <= n ? spell_act!(e, wrong, fixes, i) : page_act!(e, i - n, place...)
  # Cut and Copy are grey with nothing selected, and Front Matter is grey in a document that has it
  off = Any[]
  wrong !== nothing && isempty(fixes) && push!(off, 1)
  selecting(b) || push!(off, n + 1, n + 2)
  front_matter(b.lines) == 0 || push!(off, (n + length(PAGE_MENU), length(INSERTS)))
  # Each item that would change the text is grey for a file that's only shown
  readonly(b) && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Cut", "Paste", "Export as HTML…", "Insert"), PAGE_MENU))
  # A file of code is no page, and has no place for a table or a recording
  b.view == :code && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Export as HTML…", "Insert"), PAGE_MENU))
  items = Any[spell..., PAGE_MENU...]
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

"Show the menu for what the mouse is over: the page, or a file in the sidebar"
context_menu!(e, w) = begin
  # The text is the editor's own node, so the mouse can be over it and not over the area around it
  onpage = ishovered(node!(Document, e, :document)) || ishovered(node!(Page, e, :page))
  onpage ? page_menu!(e, w) : file_menu!(e, w)
end

# --- the file finder -----------------------------------------------------------------------

open_finder!(e) = begin
  e.popup = :finder
  e.picked = 1
  i = input(e)
  i.text = ""
  i.cursor = i.anchor = 0
  list_files!(e)
  focus(i)
end

"The files whose names have the letters typed, in order"
matches(e) = begin
  q = lowercase(input(e).text)
  filter(e.files) do path
    name = lowercase(title(path))
    at = firstindex(name)
    all(q) do c
      found = findnext(c, name, at)
      found === nothing ? false : (at = nextind(name, found); true)
    end
  end
end

finder_key!(e, K) = begin
  found = matches(e)
  if K == Keys.escape
    e.popup = :none
    focus(e)
  elseif K == Keys.enter
    isempty(found) ? (e.popup = :none; focus(e)) : open!(e, found[clamp(e.picked, 1, length(found))])
  elseif K == Keys.down
    e.picked = min(e.picked + 1, max(1, length(found)))
  elseif K == Keys.up
    e.picked = max(e.picked - 1, 1)
  else
    e.picked = 1
  end
  nothing
end

describe(f::FinderInput) = begin
  e = editor(f)
  Row(width(grow=grow), height(44px), padding(14px, 0px), child_gap=10px,
    Icon("search", size=14px, color=colours.dim), input(e))
end
onkey(f::FinderInput, ::KeyPress{Keys.mouse_left}) = focus(input(editor(f)))
cursor(::FinderInput) = :ibeam

finder(e) = begin
  i = input(e)
  i.color, i.placeholder_color = colours.ink, colours.faint
  found = first(matches(e), 9)
  picks = [node!(() -> FileRow(path=p, finder=n), e, (:pick, n, p)) for (n, p) in enumerate(found)]
  list = isempty(picks) ?
    Box(width(grow=grow), height(40px), label("No file has that name", color=colours.dim)) :
    Column(width(grow=grow), Alignment.Start, padding(6px), child_gap=1px, picks...)
  Row(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.Center, padding(90px, 0px, 0px, 0px),
    floating(node!(FinderInput, e, :finder_input),
             Box(width(grow=grow), height(1px), background(colours.line)),
             list, w=460px))
end

# --- the app for Markdown files ----------------------------------------------------------
#
# macOS keeps, for each kind of file, the app that opens it when you
# double-click one. The settings page has a button that makes Kaydown that app
# for Markdown files. macOS then tells Kaydown which file to open with a
# message, not with an argument, so the app keeps a list of the files it's
# been asked for and the window opens them.

const APP_ID = "com.jkroso.kaydown"                   # the Kaydown app's name for macOS, as app/build.jl gives it
const MARKDOWN_TYPE = "net.daringfireball.markdown"   # macOS's name for the kind of file that Markdown is

"macOS's object for the kind of file that Markdown is"
markdown_type() = begin
  # The class is in a framework that a window loads, but a test without a window hasn't
  ccall(:dlopen, Ptr{Cvoid}, (Cstring, Cint), "/System/Library/Frameworks/UniformTypeIdentifiers.framework/UniformTypeIdentifiers", 1)
  msg(cls("UTType"), "typeWithIdentifier:", nsstring(MARKDOWN_TYPE))
end

workspace() = msg(cls("NSWorkspace"), "sharedWorkspace")
"The file path of an NSURL, or an empty string for none"
url_path(url::Ptr{Cvoid}) = url == C_NULL ? "" : jstring(msg(url, "path"))

"Where the Kaydown app is on this Mac, or an empty string when it isn't installed"
app_path() = Sys.isapple() ? with_pool(() -> url_path(msg(workspace(), "URLForApplicationWithBundleIdentifier:", nsstring(APP_ID)))) : ""

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
markdown_app() = begin
  Sys.isapple() || return ""
  with_pool() do
    type = markdown_type()
    type == C_NULL ? "" : url_path(msg(workspace(), "URLForApplicationToOpenContentType:", type))
  end
end

"""
The app that opens the file at `path` when you double-click the file in the
Finder: where that app is, or an empty string when macOS has no app for the file.
"""
opener(path) = begin
  (Sys.isapple() && isfile(path)) || return ""
  with_pool(() -> url_path(msg(workspace(), "URLForApplicationToOpenURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(path)))))
end

"""
Open the file that the page shows in the app that the Mac uses for it. A file
that the Mac has no app for shows in the Finder.
"""
open_outside!(e) = begin
  path = e.buf.path
  isfile(path) || return e
  if isempty(opener(path)) && Sys.isapple()
    show_in_finder(path)
  else
    open_url(path)
  end
  e
end

"The name of the app at `path`, like Kaydown for /Applications/Kaydown.app"
app_name(path) = splitext(basename(path))[1]

"""
Ask macOS to make Kaydown the app that opens Markdown files. macOS shows a
dialog of its own that asks you to confirm, and changes the app when you say
yes. It's true when macOS was asked. It's false when the Kaydown app isn't
installed on this Mac, because macOS would then ask about an app with no name.
"""
make_default!() = begin
  (Sys.isapple() && !isempty(app_path())) || return false
  with_pool() do
    # 0xffffffff is every way of opening a file: to read it, to change it and so on
    ccall((:LSSetDefaultRoleHandlerForContentType, "/System/Library/Frameworks/CoreServices.framework/CoreServices"), Int32,
          (Ptr{Cvoid}, UInt32, Ptr{Cvoid}), nsstring(MARKDOWN_TYPE), 0xffffffff, nsstring(APP_ID)) == 0
  end
end

"""
Look for your answer to macOS's dialog, twice a second for two minutes after
the button on the settings page. When the app for Markdown files changes, the
blocks that show which app it is run again.
"""
await_default!(e) = begin
  asked = get(e.nodes, :asked, nothing)
  asked === nothing && return
  at, before, checked = asked
  now = time()
  if now - checked >= 0.5
    if markdown_app() != before
      delete!(e.nodes, :asked)
      return rerun!(e, :app)
    end
    now - at > 120 && return delete!(e.nodes, :asked)
    e.nodes[:asked] = (at, before, now)
  end
  # Nothing else may happen in the window while the dialog is open, so ask for the next look
  redraw_in!(e, 0.5)
end

"""
The files that macOS asked Kaydown to open, which it hasn't opened yet. macOS
asks when you double-click a Markdown file in the Finder or drop one on
Kaydown's icon. The app puts its own list here.
"""
const inbox = Ref(String[])

"""
Show the last file or folder that macOS asked for. A window shows one file, so
that's the one to show. The settings window keeps its page: another window
shows the file, and with no other window open, a new one does.
"""
receive!(e) = begin
  files = inbox[]
  isempty(files) && return
  if issettings(e)
    i = findfirst(o -> !issettings(o), editors)
    if i === nothing
      path = pop!(files)
      empty!(files)
      ispath(path) && show_window!(page_window(path, e), window_of(e))
    else
      # That window may have nothing else to draw for, so ask it to draw
      w = window_of(editors[i])
      w === nothing || stale!(w)
    end
    return
  end
  path = pop!(files)
  empty!(files)
  if isdir(path)
    e.folder = path
    e.panel = true
    list_files!(e)
    isempty(e.files) || open!(e, e.files[1])
  elseif isfile(path)
    open!(e, path)
  end
  touch!(e)
end

# --- pictures in the text ----------------------------------------------------------------
#
# A line that holds only a picture, like ![plan](plan.png), shows the picture.
# The line's own text shows again while the caret is on it. The picture can be
# a file, named from the document's folder, or an address on the web. One from
# the web is fetched once, and kept in a folder of the Mac's caches.

const PICTURE_LINE = r"^\s*(?:\[\s*)?!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)(?:\s*\]\([^)]*\))?\s*$"

"A picture that a line of the document shows"
@def mutable struct Picture <: SemanticUI
  line::Int = 0
  key::String = ""   # of the picture, for an Image
  w::px = 0px
  h::px = 0px
end

describe(p::Picture) = Box(width(grow=grow), Alignment.Start, fillable(p, (:picture, p.key), Image(p.key, fixed(p.w), height(p.h), radius(4px))))
cursor(::Picture) = :ibeam
onpinch(p::Picture, ev::Pinch) = pinch_open(p, ev)
# A click on the picture puts the caret on its line, so the line shows as it's written
onkey(p::Picture, ::KeyPress{Keys.mouse_left}) = edit_matter!(p, p.line)

# The files that turned out not to be pictures, and when each last changed, so that each is tried once
const not_pictures = Dict{String,Float64}()

"The key, for an Image, of the picture in the file at `path`, or nothing if the file isn't a picture"
picture_key(path) = begin
  isfile(path) || return nothing
  get(not_pictures, path, -1.0) == mtime(path) && return nothing
  key = lowercase(splitext(path)[2]) in PICTURES ? path : picture(path)
  ok = key !== nothing && try image_aspect(key) > 0 catch; false end
  ok ? key : (not_pictures[path] = mtime(path); nothing)
end

# What's known of each web address that a picture has: the `curl` that's fetching
# it, the file it's kept in, or nothing if it couldn't be fetched
const fetches = Dict{String,Any}()
pictures_dir() = joinpath(homedir(), "Library", "Caches", "Kaydown", "pictures")

"The file that holds the picture at the web address `url`. It's nothing while the picture is fetched, and if it can't be."
fetched(e, url) = begin
  file = joinpath(pictures_dir(), string(hash(url), base=16))
  state = get(fetches, url, :none)
  if state === :none
    # A picture that an earlier window fetched is still there
    isfile(file) && filesize(file) > 0 && return (fetches[url] = file)
    state = fetches[url] = try
      mkpath(pictures_dir())
      run(pipeline(`curl --silent --fail --location --max-time 30 --output $(file * ".part") $url`, stdout=devnull, stderr=devnull), wait=false)
    catch
      nothing
    end
  end
  state isa Base.Process || return state
  if process_exited(state)
    part = file * ".part"
    return fetches[url] = success(state) && isfile(part) ? (mv(part, file, force=true); file) : nothing
  end
  redraw_in!(e, 0.2)   # look again soon
  nothing
end

"What line `i` shows when it holds only a picture that can be shown, or nothing"
picture_item(e, i) = begin
  m = match(PICTURE_LINE, e.buf.lines[i])
  m === nothing && return nothing
  src = unescaped(String(m[2]))
  (note = media_note(e, i, src)) === nothing || return note   # a video or a sound that's on its way from the web
  # A sound file shows a player, and so does a video file
  sound = sound_file(docdir(e), e.buf.lines[i])
  sound === nothing || return sound_item(e, sound)
  video = video_item(e, src)
  video === nothing || return video
  path = startswith(src, r"https?://") ? fetched(e, src) : abspath(docdir(e), expanduser(src))
  key = path === nothing ? nothing : picture_key(path)
  key === nothing && return nothing
  source = image_source(key)
  # A picture shows at its own size, and no wider than the text. A picture of pixels is a pixel to the
  # px. One that macOS read, like an SVG, is the size that macOS says it is.
  size = natural(key)
  w = min(e.width, px(size === nothing ? source.width : size[1]))
  h = w * source.height / source.width
  node = node!(Picture, e, (:picture, i))
  node.line, node.key, node.w, node.h = i, key, w, h
  own!(node!(Document, e, :document), node)
  Live(node, h + 2LIVE_GAP)
end

# --- video and sound from the web --------------------------------------------------------
#
# A line can name a video or a sound by its address on the web, as it can a
# picture. Kaydown downloads the file once, into a folder of the Mac's caches,
# and the line's player plays that copy. The copy's name ends as the file's
# does, like .mov, because macOS goes by that. What follows a ? or a # in the
# address isn't part of the name, so each part of one video, like
# walk.mov#t=61,86, plays from the same copy.
#
# While Kaydown downloads the file, the line says so. If Kaydown can't get it,
# the line says that, and Kaydown tries again a minute later. A new try goes on
# from what the last one got.

const MEDIA_CACHE = Ref("")   # the folder a test keeps the copies in, in place of the one in the Mac's caches
const RETRY = 60              # seconds after a download fails before Kaydown tries again
# What's known of each copy that isn't whole yet: the `curl` that downloads it, or when the last one failed
const downloads = Dict{String,Any}()

"A line that says that Kaydown is downloading its video or its sound, or that it couldn't"
@def mutable struct MediaNote <: SemanticUI
  line::Int = 0
  words::String = ""
  failed::Bool = false
  size::px = 13px   # of the text
end

"The folder that keeps the copies of the videos and the sounds from the web"
media_dir() = isempty(MEDIA_CACHE[]) ? joinpath(homedir(), "Library", "Caches", "Kaydown", "media") : MEDIA_CACHE[]

"The web address `url` without what follows its ? or its #"
web_file(url) = String(first(split(url, r"[?#]", limit=2)))

"Is `src` the web address of a video or a sound file?"
web_media(src) = startswith(src, r"https?://") && (ext = lowercase(splitext(web_file(src))[2]); ext in VIDEOS || ext in SOUNDS)

"The file on the Mac that keeps the copy of the video or the sound at the web address `url`"
media_file(url) = (file = web_file(url); joinpath(media_dir(), string(hash(file), base=16) * lowercase(splitext(file)[2])))

"`src` as a file on the Mac: the copy of a video or a sound on the web, and `src` itself for anything else"
local_media(src) = web_media(src) ? media_file(src) : src

"""
Download the video or the sound at the web address `url`, unless its copy is on
the Mac or on its way. It's `:there` once the copy is whole, `:coming` while
`curl` downloads it, and `:failed` for a minute after `curl` couldn't get it.
"""
download!(e, url) = begin
  file = media_file(url)
  isfile(file) && return :there
  part = file * ".part"
  state = get(downloads, file, nothing)
  if state isa Base.Process
    if !process_exited(state)
      redraw_in!(e, 0.5)   # look again soon
      return :coming
    end
    if success(state) && isfile(part)
      delete!(downloads, file)
      mv(part, file, force=true)
      return :there
    end
    # A server that said no, or that can't send the rest of a file, leaves nothing for the next try to go on from
    state.exitcode in (22, 33) && rm(part, force=true)
    state = downloads[file] = time()
  end
  if state isa Float64 && time() - state < RETRY
    redraw_in!(e, RETRY - (time() - state))   # to try again
    return :failed
  end
  # The address is asked for as it's written, with its ? and without its #. `curl` gives up when nothing comes for a minute.
  address = replace(first(split(url, '#')), ' ' => "%20")
  state = downloads[file] = try
    mkpath(media_dir())
    run(pipeline(`curl --silent --fail --location --connect-timeout 30 --speed-limit 1 --speed-time 60 --continue-at - --output $part $address`,
                 stdout=devnull, stderr=devnull), wait=false)
  catch
    time()
  end
  redraw_in!(e, 0.5)
  state isa Base.Process ? :coming : :failed
end

"""
What line `i` shows while the video or the sound at the web address `src` isn't
on the Mac: that Kaydown is downloading it, or that it couldn't. It's nothing
once the copy is there, and when `src` is anything else.
"""
media_note(e, i, src) = begin
  (Sys.isapple() && web_media(src)) || return nothing
  state = download!(e, src)
  state == :there && return nothing
  what = lowercase(splitext(web_file(src))[2]) in VIDEOS ? "video" : "sound"
  part = media_file(src) * ".part"
  got = isfile(part) ? filesize(part) >> 20 : 0
  node = node!(MediaNote, e, (:media_note, i))
  node.line, node.failed, node.size = i, state == :failed, body(e).size * 0.76
  node.words = state == :failed ? "Kaydown couldn't get the $what. It tries again in a minute." :
               "Downloading the $what…" * (got > 0 ? " $got MB so far" : "")
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

describe(n::MediaNote) = begin
  s = n.size
  Row(width(grow=grow), Alignment.Center, padding(s, s * 0.7), child_gap=s * 0.6, radius(6px),
      border(1px, :solid, colours.line), background(colours.block), name="Media note",
    Icon(n.failed ? "exclamation-circle" : "cloud-arrow-down", size=s * 1.1, color=colours.dim),
    label(n.words, s, color=colours.dim))
end

cursor(::MediaNote) = :ibeam
# A click on the note puts the caret on its line, so the line shows as it's written
onkey(n::MediaNote, ::KeyPress{Keys.mouse_left}) = edit_matter!(n, n.line)

# --- video in the text -------------------------------------------------------------------
#
# A line that holds only a video file, written as a picture is, like
# ![The kitchen](walk.mov), shows a player for the file. A link that ends like
# walk.mov#t=61,86 names part of the file: from 61 seconds after its start to
# 86. The player starts at 61 and stops at 86, and its track is that part of the
# file. walk.mov#t=61 goes on to the end of the file. A time can be written as a
# clock shows it too, like 1:01. A browser reads the link the same way.

"""
The file that a link names, and the part of the file that the link's `#t=`
names, in seconds from the file's start. `"walk.mov#t=61,86"` gives
`("walk.mov", 61.0, 86.0)`. With no `#t=` it's all of the file: 0 to Inf.
"""
media_part(src) = begin
  file, after = occursin('#', src) ? split(src, '#', limit=2) : (src, "")
  from, to = 0.0, Inf
  for pair in split(after, '&')
    startswith(pair, "t=") || continue
    times = split(replace(pair[3:end], r"^npt:" => ""), ',', limit=2)
    start = clock_time(times[1])
    start === nothing || (from = max(start, 0.0))
    stop = length(times) == 2 ? clock_time(times[2]) : nothing
    stop === nothing || stop <= from || (to = stop)
  end
  (String(file), from, to)
end

"A time written as seconds, like 61.5, or as a clock shows it, like 1:01.5 or 0:01:01, in seconds. It's nothing if the text isn't a time."
clock_time(text) = begin
  n = map(part -> tryparse(Float64, part), split(text, ':'))
  (length(n) > 3 || any(isnothing, n)) && return nothing
  foldl((total, x) -> total * 60 + x, n)
end

"What a line shows when it holds only the video file `src`: a player of the file, or of the part of it that `src` names. It's nothing if the file isn't there."
video_item(e, src) = begin
  Sys.isapple() || return nothing
  file, from, to = media_part(src)
  file = local_media(file)   # a video on the web plays from the copy of it on the Mac
  (startswith(file, r"https?://") || !(lowercase(splitext(file)[2]) in VIDEOS)) && return nothing
  path = abspath(docdir(e), expanduser(file))
  isfile(path) || return nothing
  # A Shown gives the player the page's colours, and the button that makes it fill the window, as it does for what a live block makes
  node = get!(e.nodes, (:video, path, from, to)) do
    shown = Shown(value=VideoPlayer(path=path, from=from, to=to))
    own!(shown, shown.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

# --- what was said in a video ------------------------------------------------------------
#
# While the mouse is over a video, a button under the one that makes it fill the
# window opens a drop-down of what was said in the video. The drop-down has a
# button that copies the words to the clipboard. The first time, macOS writes
# down what's said in the file, as it does for a sound file. See transcribe.jl.
# A few minutes of video take it a second or two, and the drop-down says how far
# it has got. A line that names part of a file, like walk.mov#t=61,86, shows what
# was said in that part. Each file is transcribed once while Kaydown runs, so the
# parts of a file share it.

const TRANSCRIPT_W = 520px      # the widest the drop-down is
const TRANSCRIPT_HIGH = 320px   # the tallest that its words are before they scroll
const TRANSCRIPT_PAD = 14px     # inside its edge
const COPIED_FOR = 1.5          # how many seconds the copy button says "Copied"

"The button beside a video, under its FillButton, that opens the drop-down of what was said in the video"
@def mutable struct TranscriptButton <: SemanticUI
  open::Bool = false                          # is its drop-down open?
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip beside it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end

"The drop-down of a TranscriptButton: what was said in the video, and a button that copies it"
@def mutable struct Transcript <: SemanticUI
  player::Any = nothing   # the VideoPlayer
  wide::px = TRANSCRIPT_W # how wide it is
  copy::Any = nothing     # its CopyButton
  scroll::Scroll = Scroll(width(grow=grow))
end

"The button in a Transcript that copies the words to the clipboard"
@def mutable struct CopyButton <: SemanticUI
  text::String = ""       # what it copies
  copied::Float64 = 0.0   # when it last copied, so that it says so for a moment
end

# The transcription of each video file that has had one, by the file's path,
# with when the file last changed before it started
const video_words = Dict{String,Tuple{Float64,Transcription}}()

"""
Start to transcribe the video file at `path`, unless it has been or it's being
done. A file that has changed since, and one that couldn't be done, start again.
"""
transcribe_video!(path) = begin
  stamp = mtime(path)
  had = get(video_words, path, nothing)
  had !== nothing && had[1] == stamp && !(finished(had[2]) && had[2].text === nothing) && return had[2]
  video_words[path] = (stamp, Transcription(path, times=true))
  video_words[path][2]
end

"""
What the drop-down of the video player `p` shows: the words said in the part of
the file that it plays, or no words and a note that says why there are none,
like how far macOS has got. `busy` is true while macOS works.
"""
transcript_of(p::VideoPlayer) = begin
  had = get(video_words, p.path, nothing)
  had === nothing && return (words="", note="", busy=false)
  t = had[2]
  if !check!(t)
    note = t.downloading ? "Downloading what macOS needs to transcribe…" : "Transcribing… $(round(Int, 100t.done))%"
    return (words="", note=note, busy=true)
  end
  t.text === nothing && return (words="", note=t.problem, busy=false)
  words = words_between(phrases(t), p.from, p.to)
  whole = p.from == 0 && p.to == Inf
  (words=words, note=isempty(words) ? "No words were heard in $(whole ? "the" : "this part of the") video." : "", busy=false)
end

"How wide the drop-down of what was said in a video is in the page of `e`"
transcript_w(e) = min(e.width, TRANSCRIPT_W)

describe(b::TranscriptButton) = begin
  ishovered(b) || (b.quiet = false)
  Box(width(FILL_SIDE), height(FILL_SIDE), radius(6px), Alignment.Center, justify=Alignment.Center, name="Button",
      background(b.open || ishovered(b) ? colours.hover : colours.float), border(1px, :solid, colours.line),
    Icon("text-paragraph", size=12px, color=colours.dim))
end

cursor(::TranscriptButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::TranscriptButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::TranscriptButton, ev::MouseMove) = begin
  (b.quiet || b.open) && return handled
  show_tooltip!(ev.window, tip_label("Show transcription"), b.rect...,
                placement=:right, gap=6px)
  handled
end

# While the drop-down is open, a click on the button is outside the drop-down, so it closes it
onkey(b::TranscriptButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  e, p = editor(b), video_of(b.parent)
  p === nothing && return handled
  transcribe_video!(p.path)
  b.open = true
  t = Transcript(player=p, wide=transcript_w(e))
  t.copy = own!(t, CopyButton())
  popup!(ev.window, t, anchor=b, gap=6px, width=t.wide, key=:transcript,
         onclose=() -> (b.open = false), theme=component_theme(e.zoom))
  handled
end

"""
`text` as a Text for each of its paragraphs, `wide` wide. A Text's box ends at
the foot of its last line's letters, so room under them keeps the tails of
letters like p and y from being cut off. For the same reason, the gap between
two paragraphs is a line's height and a little more.
"""
said_text(text, wide; color=colours.ink) =
  Column(fixed(wide), Alignment.Start, padding(0px, 0px, 6px, 0px), child_gap=20px,
    [Text(String(p), size=14px, family=SANS, color=color) for p in split(text, "\n\n")]...)

describe(t::Transcript) = begin
  words, note, busy = transcript_of(t.player)
  # Look again soon, to show how far it has got
  busy && redraw_in!(t, 0.25)
  t.copy.text = words
  wide = t.wide - 2TRANSCRIPT_PAD
  body = if isempty(words)
    said_text(note, wide, color=colours.dim)
  else
    # Words that are taller than TRANSCRIPT_HIGH scroll
    t.scroll.height = height(min(describe(said_text(words, wide), (wide, 9999px)).height, TRANSCRIPT_HIGH))
    reuse!(t.scroll, said_text(words, wide))
  end
  Column(width(grow=grow), Alignment.Start, padding(TRANSCRIPT_PAD), radius(8px), background(colours.block),
         border(1px, :solid, colours.line), lifted, child_gap=10px, name="Transcript",
    Row(width(grow=grow), height(24px), Alignment.Center,
      Box(width(grow=grow), label("Transcription", 12px, color=colours.dim, weight="Semibold")),
      (isempty(words) ? () : (t.copy,))...),
    body)
end

describe(c::CopyButton) = begin
  done = time() - c.copied < COPIED_FOR
  Box(height(24px), padding(8px, 0px), radius(6px), background(ishovered(c) ? colours.active : colours.hover),
    Row(Alignment.Center, child_gap=5px,
      Icon(done ? "check" : "copy", size=12px, color=colours.dim),
      label(done ? "Copied" : "Copy to clipboard", 12px)))
end

cursor(::CopyButton) = :hand

onkey(c::CopyButton, ev::KeyPress{Keys.mouse_left}) = begin
  clipboard!(ev.window, c.text)
  c.copied = time()
  # So that it goes back to saying "Copy to clipboard"
  redraw_in!(c, COPIED_FOR + 0.05)
  handled
end

# --- sound in the text -------------------------------------------------------------------
#
# A line that holds only a sound file, written as a picture is, like
# ![Recording](recording-2026-11-14-1642.m4a), shows a player for the file. The
# line's own text shows again while the caret is on it.
#
# Insert › Recording records from the microphone into a new file beside the
# document, and adds a line for the file. The line shows a recorder until you
# click its button to stop. The recording goes on while another file shows. If
# the line goes from the document, as it does when you undo the Insert, the
# recording stops.
#
# While the mouse is over the player, a button under it writes down what's said
# in the file. The button lies over the gap under the player, so it takes no
# room in the page. macOS does the work on the Mac, and the words go into a
# paragraph under the line. You can type while it works. See transcribe.jl.

"A line of the document that holds only a sound file"
@def mutable struct SoundLine <: SemanticUI
  path::String = ""
end

"The button under a sound file's player that writes down what's said in the file"
@def mutable struct TranscribeButton <: SemanticUI
  path::String = ""
end

const TRANSCRIBE_H = 26px   # how tall the Transcribe button is
const TRANSCRIBE_GAP = 6px  # between a sound's player and the Transcribe button under it

# The recorder of each sound file that a line has shown. They're kept while
# Kaydown runs, so that a recording goes on while another file shows.
const recorders = Dict{String,AudioRecorder}()
# The transcription of each sound file that has had one, by the file's path
const transcriptions = Dict{String,Transcription}()
# The sound files whose words are in a document now
const transcribed = Set{String}()

"The recorder of the sound file at `path`. It plays the file while it isn't recording."
recorder(path) = get!(() -> AudioRecorder(path=path), recorders, path)

"The sound file on the Mac that the line `text` holds, if it holds only that, or nothing. `dir` is the document's folder."
sound_file(dir, text) = begin
  occursin("![", text) || return nothing
  m = match(PICTURE_LINE, text)
  m === nothing && return nothing
  src = local_media(unescaped(String(m[2])))   # a sound on the web plays from the copy of it on the Mac
  (startswith(src, r"https?://") || !(lowercase(splitext(src)[2]) in SOUNDS)) && return nothing
  abspath(dir, expanduser(src))
end

"The line of the page that holds only the sound file at `path`, or nothing"
sound_line(e, path) = findfirst(text -> sound_file(docdir(e), text) == path, e.buf.lines)

"What a line that holds only the sound file at `path` shows, or nothing if there's no file and no recorder for it to show"
sound_item(e, path) = begin
  Sys.isapple() || return nothing
  r = recorder(path)
  (plays(r) || recording(r) || r.waiting || !isempty(r.problem)) || return nothing
  node = node!(() -> SoundLine(path=path), e, (:sound, path))
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

describe(s::SoundLine) = begin
  e = editor(s)
  r = recorder(s.path)
  # The recorder outlasts the line's node, which can be made again
  r.parent === s || setfield!(r, :parent, s)
  # It's a component, so it gets the colours and the text size that a live block gives one
  with_theme(component_theme(e.zoom)) do
    Column(width(grow=grow), Alignment.Start, r)
  end
end

"""
The Transcribe button of a sound's player, under the player. It lies over the
page, in the gap under the player, so the line is only as tall as its player
and the text under it never moves. The button shows while the mouse is over
the player or the button, or between them, and while macOS works.
"""
sound_over(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  win === nothing && return ()
  x, y = win.mouse
  for s in values(e.nodes)
    (s isa SoundLine && plays(recorder(s.path))) || continue
    r = rect(s)
    r === nothing && continue
    top = r.top + r.height + TRANSCRIBE_GAP
    over = r.left <= x < r.left + r.width && r.top <= y < top + TRANSCRIBE_H
    (over || transcribing(s.path)) || continue
    button = node!(() -> TranscribeButton(path=s.path), e, (:transcribe, s.path))
    button.parent === s || setfield!(button, :parent, s)
    t = get(transcriptions, s.path, nothing)
    # What went wrong the last time, or that there were no words
    note = t === nothing || !finished(t) ? "" : t.text == "" ? "No words were heard in it" : t.problem
    # The page's own colour is behind them, so that they read over a line of text that's right under the player
    return (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, r.left),
              Row(Alignment.Center, child_gap=10px, radius(6px), background(colours.bg),
                button, (isempty(note) ? () : (label(note, 12px, color=colours.dim),))...)),)
  end
  ()
end

# A click beside the player puts the caret on the line, so that the line shows as it's written
onkey(s::SoundLine, ::KeyPress{Keys.mouse_left}) = begin
  i = sound_line(editor(s), s.path)
  i === nothing ? handled : edit_matter!(s, i)
end

"Is the file at `path` being transcribed now?"
transcribing(path) = (t = get(transcriptions, path, nothing); t !== nothing && !finished(t))

describe(b::TranscribeButton) = begin
  t = get(transcriptions, b.path, nothing)
  busy = transcribing(b.path)
  words = !busy ? (b.path in transcribed ? "Transcribe again" : "Transcribe") :
          t.downloading ? "Downloading what macOS needs to transcribe…" : "Transcribing… $(round(Int, 100t.done))%"
  Box(height(TRANSCRIBE_H), padding(10px, 0px), radius(6px), background(busy ? colours.hover : ishovered(b) ? colours.active : colours.hover),
    Row(Alignment.Center, child_gap=6px,
      Icon("text-paragraph", size=13px, color=colours.dim),
      label(words, 12px, color=busy ? colours.dim : colours.ink)))
end

cursor(b::TranscribeButton) = transcribing(b.path) ? :arrow : :hand

onkey(b::TranscribeButton, ::KeyPress{Keys.mouse_left}) = begin
  if !transcribing(b.path)
    transcriptions[b.path] = Transcription(b.path)
    delete!(transcribed, b.path)
  end
  handled
end

"Record from the microphone into a new file beside the document, and add a line for the file under the caret"
add_recording!(e) = begin
  dir = docdir(e)
  isempty(dir) && (dir = joinpath(homedir(), "Documents"))
  when = Libc.strftime("%Y-%m-%d-%H%M", time())
  name(n) = "recording-$when$(n == 1 ? "" : "-$n").m4a"
  n = 1
  while ispath(joinpath(dir, name(n))) || haskey(recorders, joinpath(dir, name(n)))
    n += 1
  end
  path = joinpath(dir, name(n))
  record!(recorder(path))
  # A document that has no file of its own names the recording by its whole path
  src = isempty(e.buf.path) ? replace(path, ' ' => "%20") : name(n)
  add_block!(e, ["![Recording]($src)", "", ""], (3, 0))
end

"Put `words` in a paragraph under line `i`, with an empty line on each side of it. The caret stays where it was in the text."
add_words!(e, i, words) = begin
  b = e.buf
  caret, anchor = b.caret, b.anchor
  below = i < length(b.lines) && !isempty(strip(b.lines[i+1]))
  text = "\n\n" * words * (below ? "\n" : "")
  edit!(b, line_end(b, i), line_end(b, i), text)
  n = count(==('\n'), text)
  moved(p) = p[1] > i ? (p[1] + n, p[2]) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  e
end

"""
What happens to sound in each frame. A recording whose line has gone from every
document stops. A transcription that has finished puts its words under its
file's line, once the page shows a document that has the line.
"""
sound_tick!(e) = begin
  for (path, r) in recorders
    (recording(r) || r.waiting) || continue
    docs = unique!(Buffer[e.buf; collect(values(e.buffers))])
    holds(b) = (dir = isempty(b.path) ? e.folder : dirname(b.path); any(text -> sound_file(dir, text) == path, b.lines))
    any(holds, docs) || stop!(r)
  end
  for (path, t) in transcriptions
    path in transcribed && continue
    if !check!(t)
      redraw_in!(e, 0.25)   # to show how far it has got
      continue
    end
    t.text === nothing && continue   # it failed, and the button says why
    readonly(e.buf) && continue      # a file that's only shown can't take the words
    i = sound_line(e, path)
    i === nothing && continue        # the document that shows now hasn't got the line
    isempty(t.text) || add_words!(e, i, t.text)
    push!(transcribed, path)
  end
end

# --- footnotes ---------------------------------------------------------------------------
#
# [^name] in a line points to a footnote, and a line that starts [^name]: holds
# the footnote's text. The page shows a small number in place of each: 1 for
# the first footnote that the text points to, and so on. Hold ⌘ and click a
# number to go to its footnote, and click the footnote's number to go back.

"The number of each footnote of the document, by name"
notes(e) = (b = e.buf; get!(() -> footnotes(b.lines), e.flows, (:notes, b.path, b.version)))

"The number that shows for the footnote `name`, as text"
note_mark(e, name) = (n = get(notes(e), String(name), 0); n == 0 ? String(name) : string(n))

"Go from where a footnote's number was clicked to its footnote, or from the footnote back to the first place that points to it"
follow_note!(e, name) = begin
  b = e.buf
  starts(text) = (m = match(NOTE, text); m !== nothing && m[1] == name)
  w = window_of(e)
  here = w === nothing ? b.caret[1] : locate(e, w.mouse)[1]
  to = if starts(b.lines[here])
    i = findfirst(text -> !starts(text) && occursin("[^$name]", text), b.lines)
    i === nothing ? nothing : (i, length(first(split(b.lines[i], "[^$name]"))))
  else
    i = findfirst(starts, b.lines)
    i === nothing ? nothing : line_end(b, i)
  end
  to === nothing && return
  b.caret = b.anchor = to
  touch!(e)
end

# --- find in the page ----------------------------------------------------------------------
#
# ⌘F opens a bar at the top right of the page. Each place in the document that
# has the bar's text gets a mark, and the selection goes to the first one after
# the caret. Return and ⌘G go to the next place, ⇧Return and ⌘⇧G go to the one
# before, and esc closes the bar. Capitals don't matter.

"The bar that finds text in the page"
@def mutable struct FindBar <: SemanticUI end
"A button of that bar: `:previous`, `:next` or `:close`"
@def mutable struct FindButton <: SemanticUI
  action::Symbol = :next
end

finding(e) = get(e.nodes, :finding, false)::Bool
find_input(e) = get!(e.nodes, :find_input) do
  own!(e, TextInput(placeholder="Find in the page", font_family=SANS, font_size=14px,
                    look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
end

"Open the bar and give it the keyboard. What's selected goes into it, if that's part of one line."
open_find!(e) = begin
  b = e.buf
  i = find_input(e)
  lo, hi = selection(b)
  selecting(b) && lo[1] == hi[1] && (i.text = rest(head(b.lines[lo[1]], hi[2]), lo[2]))
  i.anchor, i.cursor = 0, length(i.text)
  e.nodes[:finding] = true
  e.nodes[:find_text] = i.text
  focus(i)
  nothing
end

close_find!(e) = (e.nodes[:finding] = false; focus(e); touch!(e); nothing)

"Each place in the document that has the bar's text: its line, and the columns where it starts and ends"
found(e) = begin
  b = e.buf
  q = finding(e) ? lowercase(find_input(e).text) : ""
  key = (b.path, b.version, q)
  kept = get(e.nodes, :found, nothing)
  kept !== nothing && kept[1] == key && return kept[2]::Vector{NTuple{3,Int}}
  out = NTuple{3,Int}[]
  n = length(q)
  if n > 0
    for (i, line) in enumerate(b.lines)
      low = lowercase(line)
      for at in findall(q, low)
        lo = length(low, 1, first(at)) - 1
        push!(out, (i, lo, lo + n))
      end
    end
  end
  e.nodes[:found] = (key, out)
  out
end

"Select the place at `k` of the places found, and scroll to it"
go_found!(e, k) = begin
  i, lo, hi = found(e)[k]
  b = e.buf
  b.anchor, b.caret = (i, lo), (i, hi)
  touch!(e)
end

"Go to the next place after the selection, or with `by` of -1 to the one before it. After the last place comes the first."
find_step!(e, by=1) = begin
  places = found(e)
  isempty(places) && return
  lo, hi = selection(e.buf)
  k = by > 0 ? findfirst(p -> (p[1], p[2]) >= hi, places) : findlast(p -> (p[1], p[3]) <= lo, places)
  go_found!(e, something(k, by > 0 ? 1 : length(places)))
end

"When the bar's text changes, go to the first place at or after the start of the selection"
find_tick!(e) = begin
  finding(e) || return
  text = find_input(e).text
  text == get(e.nodes, :find_text, "") && return
  e.nodes[:find_text] = text
  places = found(e)
  isempty(places) && return
  lo, _ = selection(e.buf)
  go_found!(e, something(findfirst(p -> (p[1], p[2]) >= lo, places), 1))
end

"What a key does while the bar has the keyboard"
find_key!(e, K, shift, cmd) = begin
  if K == Keys.escape
    close_find!(e)
  elseif K == Keys.enter || (cmd && K == Keys.g)
    find_step!(e, shift ? -1 : 1)
  elseif cmd && K == Keys.f
    i = find_input(e)
    i.anchor, i.cursor = 0, length(i.text)
  elseif cmd && K == Keys.s
    save_page!(e)
  end
  nothing
end

const FIND_W = 330px

describe(f::FindBar) = begin
  e = editor(f)
  i = find_input(e)
  i.color, i.placeholder_color = colours.ink, colours.faint
  places = found(e)
  lo, hi = selection(e.buf)
  k = lo[1] == hi[1] ? something(findfirst(==((lo[1], lo[2], hi[2])), places), 0) : 0
  count = isempty(i.text) ? "" : isempty(places) ? "Not found" : k == 0 ? string(length(places)) : "$k of $(length(places))"
  Row(fixed(FIND_W), height(38px), padding(0px, 6px, 0px, 12px), child_gap=6px, radius(9px), background(colours.float),
      border(1px, :solid, colours.line), lifted,
    Icon("search", size=13px, color=colours.dim), Box(width(2px)), i,
    label(count, 12px, color=colours.dim), Box(width(2px)),
    [node!(() -> FindButton(action=a), e, (:find, a)) for a in (:previous, :next, :close)]...)
end

cursor(::FindBar) = :ibeam
onkey(f::FindBar, ::KeyPress{Keys.mouse_left}) = (focus(find_input(editor(f))); handled)

describe(b::FindButton) = Box(width(24px), height(24px), radius(5px), background(ishovered(b) ? colours.hover : clear),
  Icon(b.action == :previous ? "chevron-up" : b.action == :next ? "chevron-down" : "x-lg", size=11px, color=colours.dim))

cursor(::FindButton) = :hand
onkey(b::FindButton, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  b.action == :close ? close_find!(e) : find_step!(e, b.action == :previous ? -1 : 1)
  handled
end

"The find bar, placed at the top right of the window, under the top bar. Nothing when it's closed."
findbar(e) = finding(e) ? (Row(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.End,
                               padding(TOPBAR_H + 6px, 22px, 0px, 0px), node!(FindBar, e, :findbar)),) : ()

# --- spelling --------------------------------------------------------------------------------
#
# macOS checks the spelling of the page's text. A word that its dictionary
# doesn't have gets a line of red dots under it. A right-click on the word
# offers the words it may have been meant to be, and Learn Spelling, which
# teaches the dictionary the word. Code isn't checked, and nor is the word that
# the caret is in, which may not be finished. The settings page turns it off.

const CHECKED = (Kind.paragraph, Kind.heading, Kind.bullet, Kind.ordered, Kind.todo, Kind.blockquote)

"""
True when `text` is a word that a dictionary could have. The name of a file,
like notes.md, a name from code, like page_width, and a web address aren't,
and nor is the app's own name.
"""
spellable(text::AbstractString) = text != "Kaydown" && !any(c -> isdigit(c) || c in "._/@:\\", text)

"Every word of line `i` that's spelt wrong: the columns where it starts and ends"
misspellings(e, i) = begin
  b = e.buf
  text, line = b.lines[i], kinds(b)[i]
  (e.spelling && line.kind in CHECKED) || return Tuple{Int,Int}[]
  get!(e.flows, (:spelling, text, line.prefix)) do
    out = Tuple{Int,Int}[]
    occursin(PICTURE_LINE, text) && return out
    for s in spans(rest(text, line.prefix), line.prefix)
      # The address of a link and the name of a footnote are markup, so only the words that show are checked
      (s.markup || s.code || startswith(s.link, '^')) && continue
      for (lo, hi) in misspelt(s.text)
        spellable(rest(head(s.text, hi), lo)) && push!(out, (s.col + lo, s.col + hi))
      end
    end
    out
  end
end

"The wrong word at `at`, as its line and its columns, or nothing"
misspelling_at(e, at::Pos) = begin
  k = findfirst(((lo, hi),) -> lo <= at[2] <= hi, misspellings(e, at[1]))
  k === nothing ? nothing : (at[1], misspellings(e, at[1])[k]...)
end

"Change the spelling of every line again, after the dictionary learns a word"
respell!(e) = (filter!(kv -> !(kv.first isa Tuple && first(kv.first) === :spelling), e.flows); e)

"Turn the spelling check on or off"
spelling!(e, on::Bool) = (e.spelling = on; save_settings!(e); rerun!(e, :spelling); e)

"""
Where columns `from` to `to` of `f` are on the screen. A line of the document
can wrap, so there's one for each line of the screen that has some of them: its
left, its right, its top and its height, from the top left of `f`.
"""
stretches(f::Flow, from, to) = begin
  out = NTuple{4,px}[]
  for (k, vl) in enumerate(f.lines)
    (from < vl.to && to > vl.from) || continue
    x1, x2 = xcol(vl, max(from, vl.from)), xcol(vl, min(to, vl.to))
    x2 > x1 && push!(out, (x1, x2, line_top(f, k), vl.high))
  end
  out
end

const SPELL_RED = colorant"rgb(222,70,56)"
const FOUND = RGBA(1.0, 0.78, 0.16, 0.45)   # the colour of the mark over a place that the find bar found

"Draw a mark over each place that the find bar found, and a line of dots under each word that's spelt wrong"
annotate(ctx, e, ui) = begin
  b = e.buf
  places = found(e)
  (isempty(places) && !e.spelling) && return
  lo, hi = selection(b)
  for it in e.layout[e.shown]
    f = it.content
    f isa Flow || continue
    i, top = it.first, ui.top + it.top
    k = searchsortedfirst(places, (i, 0, 0))
    while k <= length(places) && places[k][1] == i
      _, from, to = places[k]
      k += 1
      # The place that's selected has the selection's colour already
      (lo, hi) == ((i, from), (i, to)) && continue
      for (x1, x2, y, high) in stretches(f, from, to)
        tall = f.size * 1.35
        rounded_rectangle(ctx, ui.left + x1, top + y + (high - tall) / 2, x2 - x1, tall, 3px, background=FOUND)
      end
    end
    for (from, to) in misspellings(e, i)
      # A word that's still being typed isn't wrong yet
      !b.reading && b.caret[1] == i && from <= b.caret[2] <= to && continue
      for (x1, x2, y, high) in stretches(f, from, to)
        under = top + y + high / 2 + f.size * 0.46
        for x in num(x1):3.0:num(x2)-1.5
          rectangle(ctx, ui.left + px(x), under, 1.5px, 1.5px, background=SPELL_RED, border=0px)
        end
      end
    end
  end
end

"What the item at `k` of the spelling part of the page's menu does. `fixes` are the words it offers for the wrong word at `wrong`."
spell_act!(e, wrong, fixes, k) = begin
  i, lo, hi = wrong
  b = e.buf
  if k <= length(fixes)
    edit!(b, (i, lo), (i, hi), fixes[k])
    b.caret = b.anchor = (i, lo + length(fixes[k]))
    touch!(e)
  elseif k == max(1, length(fixes)) + 1
    learn!(rest(head(b.lines[i], hi), lo))
    respell!(e)
  end
  nothing
end

# --- the page as HTML ------------------------------------------------------------------------
#
# ⌘⇧E, and Export as HTML in the page's menu, write the document as a page of
# HTML that a browser can show. A sheet goes in as a table of its names and
# what they come to. A diagram goes in as a picture in SVG, drawn as the editor
# draws it. A live block goes in as its code, and inline code goes in as the
# text it made, when it made text.

"The sheet between lines `s` and `t`, as an HTML table, or nothing while the sheet shows as code"
sheet_html(e, s, t) = begin
  k = findfirst(it -> it.first == s && it.content isa Sheet, e.layout)
  k === nothing && return nothing
  sheet, b = e.layout[k].content, e.buf
  rows = map(eachindex(sheet.rows)) do r
    line, cells = b.lines[sheet.rows[r]], sheet.cells[r]
    text(c) = escape(rest(head(line, c.hi), c.lo))
    name = length(cells) > 1 ? text(cells[1]) : ""
    "<tr><td>$name</td><td><code>$(isempty(cells) ? "" : text(cells[end]))</code></td><td>$(escape(sheet.results[r].text))</td></tr>"
  end
  "<table>\n" * join(rows, "\n") * "\n</table>"
end

"The `takeoff` code block from line `s` to line `t` as HTML: a table of what's measured and what each measure comes to"
takeoff_html(e, s, t) = begin
  data = Plans.takeoff(e.buf.lines[s+1:t-1])
  isempty(data.measures) && return nothing
  rows = map(data.measures) do m
    amount = Plans.amount(data, m)
    "<tr><td>$(escape(m.name))</td><td>$(amount === nothing ? "" : escape(Plans.shown(m, amount)))</td></tr>"
  end
  about = join(filter(!isempty, [isempty(data.plan) ? "" : "Measured from " * escape(basename(data.plan)),
                                 isempty(data.customer) ? "" : "for " * escape(data.customer),
                                 isempty(data.made) ? "" : "quote " * escape(data.made)]), ", ")
  (isempty(about) ? "" : "<p>$about</p>\n") * "<table>\n" * join(rows, "\n") * "\n</table>"
end

# Skia's SVG canvas draws text as shapes with this flag, so it needs no font where it's shown
const SVG_TEXT_AS_SHAPES = UInt32(1)

"""
The diagram that `code` describes, as a picture in SVG, or nothing if the code
can't be drawn as a diagram. It has the Sepia colours, which the page of HTML
has too, and it's as big as it is in the editor at its usual size. Its text is
drawn as shapes, so it looks the same on a computer that hasn't got the font.
"""
diagram_svg(code::AbstractString) = begin
  isdiagram(code) || return nothing
  was = deepcopy(colours)
  use!(SEPIA)
  stream = Skia.sk_dynamic_memory_wstream_new()
  try
    m = Mermaid(code)
    geo = with_theme(component_theme()) do
      convert(GeometricUI, m)
    end
    made = m.made === nothing ? nothing : m.made[2]
    (made === nothing || made isa Exception) && return nothing
    w, h = ceil(Int, made.w), ceil(Int, made.h)
    (w > 0 && h > 0) || return nothing
    size = (px(w), px(h))
    scene = describe(Column(fixed(px(w)), Alignment.Start, geo), size)
    bounds = Ref(Skia.sk_rect_t(0f0, 0f0, Float32(w), Float32(h)))
    canvas = GC.@preserve bounds Skia.sk_surface_make_canvas_svg(Base.unsafe_convert(Ptr{Skia.sk_rect_t}, bounds),
                                                                 Skia.sk_dynamic_memory_wstream_as_wstream(stream), SVG_TEXT_AS_SHAPES)
    draw(canvas, size, scene)
    # Skia writes the end of the SVG when the canvas is deleted. Its C functions can't delete
    # a canvas, so the canvas's C++ destructor does it.
    ccall((:_ZN8SkCanvasD0Ev, Skia.libskia), Cvoid, (Ptr{Cvoid},), canvas)
    bytes = Vector{UInt8}(undef, Skia.sk_dynamic_memory_wstream_bytes_written(stream))
    Skia.sk_dynamic_memory_wstream_read(stream, bytes, Csize_t(0), Csize_t(length(bytes)))
    # In a page of HTML the SVG needs no line that says it's XML. A viewBox lets a narrow window show it smaller.
    svg = replace(String(bytes), r"^<\?xml[^>]*>\s*" => "")
    replace(svg, "<svg " => "<svg viewBox=\"0 0 $w $h\" role=\"img\" ", count=1)
  finally
    Skia.sk_dynamic_memory_wstream_delete(stream)
    use!(was)
  end
end

"The `mermaid` code block from line `s` to line `t` as HTML: its diagram, or nothing to show its code, as the editor does when the block isn't closed or can't be drawn"
diagram_html(e, s, t) = begin
  ks = kinds(e.buf)
  t > s && ks[t].kind == Kind.fence && ks[t].level == 1 || return nothing
  svg = diagram_svg(join(e.buf.lines[s+1:t-1], "\n"))
  svg === nothing ? nothing : "<div class=\"diagram\">\n$svg</div>"
end

"The `schedule` code block from line `s` to line `t` as HTML: a table of the page's tasks and the days of each"
schedule_html(e, s, t) = begin
  tasks = Schedules.plan!(Schedules.schedule(e.buf.lines[s+1:t-1]), page_todos(e))
  isempty(tasks) && return nothing
  rows = map(tasks) do task
    cells = [task.todo.name, Schedules.short(task.start), Schedules.short(task.finish), Schedules.days_text(task.days),
             join((tasks[j].todo.name for j in task.after), ", ")]
    "<tr>" * join("<td>$(escape(c))</td>" for c in cells) * "</tr>"
  end
  "<table>\n<tr><th>Task</th><th>Starts</th><th>Ends</th><th>Takes</th><th>After</th></tr>\n" * join(rows, "\n") * "\n</table>"
end

"The document as a page of HTML"
page_html(e) = begin
  b = e.buf
  html(b.lines, title=title(b.path),
       block=(lang, s, t) -> lang == SHEET ? sheet_html(e, s, t) : lang == TAKEOFF ? takeoff_html(e, s, t) :
                             lang == SCHEDULE ? schedule_html(e, s, t) :
                             lang == DIAGRAM ? diagram_html(e, s, t) : nothing,
       value=code -> (made = get(e.nodes, (:inline, b.path, code, 1), nothing); made isa Tuple && !made[2] ? made[1] : nothing))
end

"Ask where to save a file, with `name` to start with, in the document's folder. It gives the path, or nothing if you cancel."
save_panel(e, name) = with_pool() do
  panel = msg(cls("NSSavePanel"), "savePanel")
  msg(panel, "setNameFieldStringValue:", nsstring(name))
  msg(panel, "setDirectoryURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(docdir(e))))
  # 1 is the panel's Save button
  ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), panel, sel("runModal")) == 1 || return nothing
  jstring(msg(msg(panel, "URL"), "path"))
end

"Write the document as a page of HTML, to the file that you choose"
export_html!(e, w) = begin
  e.buf.view == :markdown || return nothing   # only a Markdown file is a page
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  (Sys.isapple() && !isempty(w.glfw)) || return nothing
  path = save_panel(e, title(e.buf.path) * ".html")
  # The panel took the keyboard, so the window never heard the keys of ⌘⇧E come up
  for key in (Keys.cmd, Keys.shft, Keys.e)
    key in w.keys && (w.keys ⊻= key)
  end
  path === nothing && return nothing
  try
    write(path, page_html(e))
  catch
  end
  nothing
end

"""
The file changed on the disk, and `moved` is the lines that changed. Keep the
line at the top of the window where it is, so the text you're reading doesn't
jump when an agent adds lines above it.
"""
stay!(e, moved) = begin
  y = e.scroll.offset
  i = findfirst(it -> it.top + it.tall > y, e.layout)
  i === nothing && return
  it = e.layout[i]
  e.nodes[:hold] = (clamp(follow(moved, it.first), 1, length(e.buf.lines)), it.top - y)
end

# --- the lines that just changed on the disk ------------------------------------------------
#
# When something else changes the file, like an agent, a bar shows for a few
# seconds in the margin beside each line that it changed or added, and fades.
# A button with an eye in the top bar shows the bars again, beside every
# line that was changed since you last sent the page. They stay until you click
# the button again.

const FRESH = 4.0        # how many seconds a bar shows
const FRESH_FADE = 1.5   # how many of them it takes to fade

"Remember the lines that just changed. `moved` is what `refresh!` gave."
fresh!(e, moved) = (e.nodes[:fresh] = (time(), e.buf.path, UnitRange{Int}[c[2] for c in moved if !isempty(c[2])]))

"The runs of lines of the page that changed on the disk in the last few seconds"
fresh(e) = begin
  at, path, runs = get(e.nodes, :fresh, (0.0, "", UnitRange{Int}[]))::Tuple{Float64,String,Vector{UnitRange{Int}}}
  (path == e.buf.path && time() - at < FRESH) && return runs
  delete!(e.nodes, :fresh)
  runs[1:0]
end

"Draw a bar in the margin beside each item on screen that shows a line that just changed. The text starts at `left`, and its first line is at `top`."
draw_fresh(ctx, e, left, top) = begin
  # The button in the top bar keeps the bars of all the agent's changes on the page. They don't fade.
  kept = marking(e) ? theirs(e) : UnitRange{Int}[]
  runs = isempty(kept) ? fresh(e) : kept
  isempty(runs) && return
  strength = isempty(kept) ? clamp((FRESH - (time() - e.nodes[:fresh][1])) / FRESH_FADE, 0, 1) : 1.0
  ink = RGBA(colours.accent, strength * 0.7)
  for it in e.layout[e.shown]
    any(r -> first(r) <= it.last && last(r) >= it.first, runs) || continue
    rectangle(ctx, left - 16px, top + it.top, 3px, it.tall, background=ink, border=0px)
  end
end

# --- code that runs where it is ----------------------------------------------------------
#
# In a code block in the language `julia`, ⌘Return runs the expression that the
# caret is in, and shows what it comes to in a small box after the end of the
# expression's last line. ⇧Return does the same and then puts the caret at the
# next expression, so pressing it again and again goes down the block. With a
# selection, they run the code that's selected. With the caret in the line that
# opens or closes the block, they run every expression of the block.
#
# The code of a page runs in a module of the page's own, so a name that one
# block makes is there for the next, and isn't on another page. The module has
# the names that a live block has, like Slider and px, and the units of a
# sheet. Code can use any of those names for a thing of its own, like
# `width = 2.4`. That doesn't change what the name means in a live block.
#
# The box shows the first line of the value. A value that has more, like a
# matrix, has an arrow in its box: click the box to show the rest under it, and
# click again to hide it. Text that the code printed shows before the value.
# A value has the colours that a code block gives Julia code: its numbers, its
# strings and the names of its types.
# What went wrong shows in red. A value that's a UI node shows as the node. A
# check mark means that the code came to nothing and printed nothing. Code that
# ends with a semicolon shows no value, as it does at Julia's prompt.
#
# A box stays while its code is as it was when it ran. It goes when you change
# that code, and Escape takes every box off the page.

const JULIA = ("julia", "jl")   # the names of the language whose code blocks run
const OUTCOME_GAP = 14px        # between the end of a line of code and the box of what it came to
const OUTCOME_LINES = 30        # the most lines of a value that Julia writes
const OUTCOME_COLS = 100        # and the most characters of each
const OUTCOME_NODE_W = 420px    # how wide a value that's a UI node shows
const OUTCOME_EDGE = 12px       # the least space between a box and the right edge of the window

"The font of what code came to, which is the font of the code, at `size` and in the colour `ink`"
outcome_face(size, ink=colours.ink) = Face(codefont(), codestyle(), size, ink, false)

"What a piece of the code of a `julia` code block came to when it ran. It shows in a box after the code's last line."
@def mutable struct Outcome <: SemanticUI
  first::Int = 0                    # the lines of the document that ran
  last::Int = 0
  code::Vector{String} = String[]   # those lines as they were then
  total::Int = 0                    # how many lines the document had when the code was last seen on those lines
  brief::String = ""                # the first line of what it came to
  full::String = ""                 # all of it
  printed::Int = 0                  # how many lines of it, from the first, are text that the code printed
  failed::Bool = false
  node::Any = nothing               # a Shown, when the value is a UI node
  open::Bool = false                # the rest shows under the box
  body::Any = nothing               # the OutcomeBody that shows the rest
  # Each frame sets these, for the room that the window has
  shown::String = ""                # as much of `brief` as fits
  rest::String = ""                 # what shows under the box when it's open
  from::Int = 1                     # the line of `full` that `rest` starts at
  more::Bool = false                # there's more than the box shows
  size::px = 12px                   # of its text
  high::px = 20px
end

"What shows under the box of an outcome that's open: the rest of the value, or the node that the value is"
@def mutable struct OutcomeBody <: SemanticUI
  of::Any = nothing
end

"""
The first and last line of the code of the `julia` code block that line `i` is
in, or nothing when the line isn't in one. The lines that open and close the
block are in the block, and aren't code.
"""
julia_code(b::Buffer, i::Int) = begin
  ks = kinds(b)
  # A file of code is one block, with no lines that open and close it
  b.view == :code && return lowercase(ks[i].lang) in JULIA ? (1, length(b.lines)) : nothing
  ks[i].kind in (Kind.fence, Kind.code) || return nothing
  s, t = codeblock(b, i)
  (t > s && ks[s].kind == Kind.fence && ks[s].level == 0 && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  lowercase(ks[s].lang) in JULIA ? (s + 1, t - 1) : nothing
end

"""
The lines of each piece of the Julia code in `lines` that runs on its own: an
expression at the top level, with the comments above it. Expressions that
share a line are one piece.
"""
statements(lines::AbstractVector{<:AbstractString}) = begin
  out = UnitRange{Int}[]
  isempty(lines) && return out
  src = join(lines, "\n")
  starts = cumsum([1; Int[ncodeunits(l) + 1 for l in lines[1:end-1]]])   # the byte that each line starts at
  line_of(byte) = searchsortedlast(starts, byte)
  pos = 1
  while pos <= ncodeunits(src)
    ex, next = try
      Meta.parse(src, pos; raise=false)
    catch
      (Expr(:error), ncodeunits(src) + 1)
    end
    next > pos || break
    # The parser takes the blank lines above an expression with it, and the end of the expression's last line
    text = SubString(src, pos, prevind(src, next))
    if ex !== nothing && !isempty(strip(text))
      lo = line_of(pos + ncodeunits(text) - ncodeunits(lstrip(text)))
      hi = line_of(pos + ncodeunits(rstrip(text)) - 1)
      if !isempty(out) && lo <= last(out[end])
        out[end] = first(out[end]):max(hi, last(out[end]))
      else
        push!(out, lo:hi)
      end
    end
    pos = next
  end
  out
end

"""
The module that the `julia` code blocks of the page run in. It has each name
that a live block has, and each unit of a sheet that has no such name. They
come in with `using`, so the page's code can give any of them a new meaning.
"""
workspace(e) = get!(e.nodes, (:workspace, e.buf.path)) do
  from = sandbox(e)
  usual = Module(:Usual)
  # The modules can be new, so their names are asked for as they are now
  share(source, name) = begin
    hidden = startswith(string(name), '#') || name in (nameof(source), :eval, :include, :Kip, :SheetUnits)
    (hidden || isdefined(usual, name) || !Base.invokelatest(isdefined, source, name)) && return
    Core.eval(usual, :(const $name = $(Base.invokelatest(getglobal, source, name))))
    Core.eval(usual, Expr(:export, name))
  end
  foreach(name -> share(from, name), Base.invokelatest(names, from, all=true, imported=true))
  units = Base.invokelatest(getglobal, from, :SheetUnits)
  foreach(name -> share(units, name), Base.invokelatest(names, units))
  m = Module(:Page)
  # Kip by the module that's loaded here, not by name, as the live blocks' module has it
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  Core.eval(m, :(const Usual = $usual))
  Core.eval(m, :(using .Usual))
  m
end

"""
Run `code` in the module of the page's `julia` code blocks. It gives the
value that the code came to, the text that the code printed, and true when the
code failed. Then the value is the error.
"""
run_code(e, code::String) = begin
  path = isempty(e.buf.path) ? joinpath(e.folder, "untitled.md") : e.buf.path
  # Kip finds a path like "./widgets.jl" from the folder of the document, as it does for a live block
  dir = isdir(docdir(e)) ? docdir(e) : pwd()
  m = workspace(e)
  # The code can load the drawing methods of a node, so the window draws one more frame soon after
  e.nodes[:ran] = true
  screen = stdout
  rd, wr = redirect_stdout()
  printed = @async read(rd, String)
  value, failed = try
    (cd(() -> include_string(m, code, path), dir), false)
  catch err
    (err isa LoadError ? err.error : err, true)
  finally
    redirect_stdout(screen)
    close(wr)
  end
  (value, fetch(printed), failed)
end

"`value` as the text that Julia shows for it, with the middle of a long list or a big table left out"
value_text(value) = begin
  io = IOBuffer()
  Base.invokelatest(show, IOContext(io, :limit => true, :displaysize => (OUTCOME_LINES, OUTCOME_COLS)), MIME"text/plain"(), value)
  String(take!(io))
end

"No more of `text` than an outcome shows: a few more lines than Julia writes for a value, and a few more characters of each"
clipped(text) = begin
  lines = split(text, '\n')
  length(lines) > OUTCOME_LINES + 10 && (lines = [lines[1:OUTCOME_LINES+10]; "…"])
  join((length(l) > OUTCOME_COLS + 20 ? first(l, OUTCOME_COLS + 20) * "…" : l for l in lines), "\n")
end

"What the code of the page came to, for each piece of it that ran and hasn't changed since"
outcomes(e) = get!(() -> Outcome[], e.nodes, (:outcomes, e.buf.path))::Vector{Outcome}

"""
Run the code on the lines `r` of the page, and show what it comes to after the
last of them. `code` is the part of those lines that runs.
"""
outcome!(e, r::UnitRange{Int}, code::String=join(e.buf.lines[r], "\n")) = begin
  b = e.buf
  was = b.lines[r]
  value, printed, failed = run_code(e, code)
  # Code that ends with a semicolon shows no value, as it does at Julia's prompt
  !failed && endswith(rstrip(code), ';') && (value = nothing)
  node = nothing
  text = try
    if failed
      Base.invokelatest(sprint, showerror, value)
    elseif value isa Union{SemanticUI,GeometricUI}
      node = own!(e, Shown(value=value, inline=true))
      string(nameof(typeof(value)))
    else
      value === nothing ? "" : value_text(value)
    end
  catch err
    # A value whose own `show` fails
    failed = true
    sprint(showerror, err)
  end
  said = String(rstrip(printed))
  full = clipped(join(filter(!isempty, [said, text]), "\n"))
  # A node shows at once, because its name alone says little
  o = own!(e, Outcome(first=first(r), last=last(r), code=was, total=length(b.lines), brief=String(first(split(full, '\n'))),
                      full=full, printed=isempty(said) ? 0 : count('\n', said) + 1, failed=failed, node=node, open=node !== nothing))
  list = outcomes(e)
  # It takes the place of what any of those lines came to before
  Base.filter!(p -> p.last < o.first || p.first > o.last, list)
  push!(list, o)
  o
end

"""
Run the code that the caret is in, for ⌘Return and ⇧Return. It's false when
the caret isn't in a `julia` code block, so the key does what it does in other
places. With `step`, the caret goes on to the next expression.
"""
run_here!(e; step=false) = begin
  b = e.buf
  (b.reading || readonly(b)) && return false
  found = julia_code(b, b.caret[1])
  (found !== nothing && julia_code(b, b.anchor[1]) == found) || return false
  from, to = found
  lo, hi = minmax(b.caret, b.anchor)
  if lo != hi
    # The code that's selected. A selection that ends at the start of a line doesn't take that line.
    code = excerpt(b, lo, hi)
    until = hi[2] == 0 && hi[1] > lo[1] ? hi[1] - 1 : hi[1]
    lo[1] >= from && until <= to && !isempty(strip(code)) && outcome!(e, lo[1]:until, code)
    touch!(e)
    return true
  end
  runs = [r .+ (from - 1) for r in statements(b.lines[from:to])]
  i = b.caret[1]
  if i < from || i > to
    # The line that opens or closes the block runs all of it, as far as the first piece that fails
    for r in runs
      outcome!(e, r).failed && break
    end
  else
    k = findfirst(r -> i in r, runs)
    # A blank line runs the piece above it
    k === nothing && (k = findlast(r -> last(r) < i, runs))
    if k !== nothing
      outcome!(e, runs[k])
      step && (b.caret = b.anchor = k < length(runs) ? (first(runs[k+1]), 0) : line_end(b, last(runs[k])))
    end
  end
  touch!(e)
  true
end

"""
Put each outcome of the page on the lines that its code is on now, and forget
the ones whose code changed. Lines that were added or taken away above an
outcome move its code down or up by that many lines.
"""
follow_outcomes!(e) = begin
  b = e.buf
  list = get(e.nodes, (:outcomes, b.path), nothing)
  list === nothing && return Outcome[]
  n = length(b.lines)
  Base.filter!(list) do o
    at(i) = i >= 1 && i + length(o.code) - 1 <= n && all(k -> b.lines[i+k-1] == o.code[k], eachindex(o.code))
    i = at(o.first) ? o.first : o.first + n - o.total
    at(i) || return false
    o.first, o.last, o.total = i, i + length(o.code) - 1, n
    true
  end
end

"Take every outcome off the page, for Escape. It's false when the page had none."
forget_outcomes!(e) = begin
  list = get(e.nodes, (:outcomes, e.buf.path), nothing)
  (list === nothing || isempty(list)) && return false
  empty!(list)
  true
end

"""
The boxes of the page's outcomes, over the page. Each is after the end of the
last line of its code, and one that has no room there is under that line. The
rest of an outcome that's open is under its box.
"""
outcome_over(e) = begin
  list = follow_outcomes!(e)
  (isempty(list) || isempty(e.layout) || readonly(e.buf)) && return ()
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  w, h = window_size(e)
  side = panel_w(e) * opened(e)
  x0 = text_left(e)
  y0 = TOPBAR_H + PAGE_TOP - e.scroll.offset
  size = body(e).size * 0.8
  wide = measure(outcome_face(size), "0")   # every character of the font is this wide
  high = size * 1.7
  at(top, left, node) = Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), node)
  # How many characters a box that starts at `left` has room for, beside its padding, its border and its arrow
  fits(left) = floor(Int, num(w - left - OUTCOME_EDGE - 34px) / num(wide))
  boxes, bodies = Any[], Any[]
  for o in list
    it = item(e, o.last)
    f = it.content
    f isa Flow || continue
    vl = last(f.lines)
    left = x0 + xcol(vl, vl.to) + OUTCOME_GAP
    top = y0 + it.top + line_top(f, length(f.lines)) + (vl.high - high) / 2
    # A line that ends too near the edge of the window has the box under it
    fits(left) < min(length(o.brief), 16) && ((left, top) = (x0 + vl.x, top + vl.high))
    # On a page that's scrolled sideways, a box that would go over the numbers of the lines doesn't show
    (top >= TOPBAR_H && top + high <= h && left >= x0 + sideways(e)) || continue
    n = max(fits(left), 1)
    o.shown = length(o.brief) > n ? first(o.brief, n - 1) * "…" : o.brief
    # The box of an outcome that's open shows the first line, so the rest starts at the second
    o.rest = o.shown == o.brief ? String(chopprefix(chopprefix(o.full, o.brief), "\n")) : o.full
    o.from = o.shown == o.brief ? 2 : 1
    o.more = o.node !== nothing || !isempty(o.rest)
    o.size, o.high = size, high
    push!(boxes, at(top, left, o))
    (o.open && o.more) || continue
    o.body === nothing && (o.body = own!(e, OutcomeBody(of=o)))
    across = (o.node === nothing ? wide * maximum(length, split(o.rest, '\n')) : OUTCOME_NODE_W) + 22px
    push!(bodies, at(top + high + 3px, max(side + 8px, min(left, w - across - OUTCOME_EDGE)), o.body))
  end
  # The rest of an open outcome goes over the boxes of the lines under it
  (boxes..., bodies...)
end

"""
One line of what code came to, as a row of text. With `code`, its parts have
the colours that a code block gives Julia code. A character that the code font
lacks is drawn in a font that has it, in the room of one character, so the
columns of a matrix stay in line under it.
"""
value_row(text::AbstractString, o::Outcome; code=true) = begin
  face = outcome_face(o.size, o.failed ? SPELL_RED : colours.ink)
  cell = measure(face, "0")
  parts = Any[]
  for tok in tokens(text, code ? "julia" : "")
    f = tok.kind == :plain ? face : Face(face, color=getfield(colours, tok.kind), style=tok.kind == :comment ? codeslant() : face.style)
    for (part, pf) in runs(tok.text, f)
      # A character from another font gets the room of one of this font's, so the columns of a matrix stay in line
      wide = pf.family == face.family ? measure(pf, part) : cell * length(part)
      push!(parts, Box(fixed(wide), Alignment.Start,
        Text(part, size=pf.size, family=pf.family, subfamily=pf.style, color=pf.color, wrap=WrapMode.none)))
    end
  end
  Row(height(o.size * 1.45), Alignment.Center, parts...)
end

"True when line `k` of all that the outcome `o` shows is a value, not text that the code printed or what went wrong"
isvalue(o::Outcome, k::Int) = !o.failed && k > o.printed

describe(o::Outcome) = begin
  arrow = o.more ? (Icon(o.open ? "chevron-down" : "chevron-right", size=o.size * 0.8, color=colours.dim),) : ()
  what = isempty(o.full) && o.node === nothing ? Box(Icon("check", size=o.size, color=colours.dim)) :
         value_row(o.shown, o, code=isvalue(o, 1) && o.node === nothing)
  Row(height(o.high), padding(7px, 0px), child_gap=4px, Alignment.Center, radius(5px), name="Outcome",
      background(o.more && ishovered(o) ? colours.hover : colours.float),
      border(1px, :solid, o.failed ? RGBA(SPELL_RED, 0.45) : colours.line),
      arrow..., what)
end

describe(d::OutcomeBody) = begin
  o = d.of
  inner = o.node !== nothing ? Box(fixed(OUTCOME_NODE_W), Alignment.Start, o.node) :
          Column(Alignment.Start, [value_row(line, o, code=isvalue(o, o.from + k - 1)) for (k, line) in enumerate(split(o.rest, '\n'))]...)
  Box(padding(10px, 8px), radius(7px), background(colours.float), border(1px, :solid, colours.line), lifted, Alignment.Start,
      name="Outcome body", inner)
end

cursor(o::Outcome) = o.more ? :hand : :arrow
cursor(::OutcomeBody) = :arrow
# A click on a box shows the rest of what the code came to, or hides it. It doesn't move the caret.
onkey(o::Outcome, ::KeyPress{Keys.mouse_left}) = (o.more && (o.open = !o.open); handled)
onmouse(::Outcome, ::MouseMove) = handled
# A click on the rest is not a click on the text under it
onkey(::OutcomeBody, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::OutcomeBody, ::MouseMove) = handled

# --- the names a code block offers -------------------------------------------------------
#
# While you type a name in a code block, a list under the caret shows the names
# that start the same way, as a sheet does. They are the names in the page's
# other code of that language, the nearest first. Julia code also gets every
# name that's in scope: the names that the page's code made when it ran, the
# names of Julia's own functions and types, like `length`, its macros, like
# `@show`, and the names that a live block has, like Slider. ↑ and ↓ choose a
# name, Return or Tab types the rest of it, and esc hides the list.
#
# The list shows just after you type a character of a name, from the name's
# second character. It doesn't show in a string or a comment, after a dot, for
# a word of the language like `end`, or when what's typed is a whole name.

const NAMES_SHOWN = 8                         # the most names in the list
const NAME = r"[\p{L}_][\p{L}\p{N}_!]*"       # a name in code
# The blocks that aren't code, and a block with no language
const NO_NAMES = (MATTER, TOML_MATTER, HEX, SHEET, SPREADSHEET, DIAGRAM, TAKEOFF, SCHEDULE, "")

"The language that code in `lang` shares its names with. `jl` and a live block are Julia."
shared_lang(lang) = (l = lowercase(lang); l in JULIA || l == LIVE ? "julia" : l)

"Each name in the page's code of the language `lang`, with the places it's written: a line and a column"
page_names(e, lang) = get!(e.flows, (:names, e.buf.path, e.buf.version, lang)) do
  b = e.buf
  found = Dict{String,Vector{Pos}}()
  for (i, line) in enumerate(kinds(b))
    (line.kind == Kind.code && !(line.lang in NO_NAMES) && shared_lang(line.lang) == lang) || continue
    for t in tokens(b.lines[i], lang)
      t.kind in (:plain, :call, :type) || continue
      for m in eachmatch(NAME, t.text)
        # A column counts characters, and a match counts bytes
        col = t.col + length(SubString(t.text, 1, prevind(t.text, m.offset)))
        push!(get!(() -> Pos[], found, String(m.match)), (i, col))
      end
    end
  end
  found
end

"""
The names in scope in Julia code on the page, as two lists: the ones that the
page's code made when it ran, and the rest, like `length`, `@show` and Slider.
A page whose code hasn't run has Julia's own names. The lists are kept until
something makes a new name.
"""
scope_names(e) = begin
  m = something(get(e.nodes, (:workspace, e.buf.path), nothing), get(e.nodes, :sandbox, nothing), Some(nothing))
  world = Base.get_world_counter()
  kept = get(e.nodes, :scope, nothing)
  kept !== nothing && kept[1] === m && kept[2] == world && return kept[3]
  named(list) = String[s for s in (string(n) for n in list) if occursin(r"^[\p{L}_@]", s)]
  mine(n) = !(n in (nameof(m), :eval, :include, :Kip, :Usual, :SheetUnits))
  lists = m === nothing ? (String[], named([names(Base); names(Core)])) :
          (named(filter(mine, Base.invokelatest(names, m, all=true, imported=true))), named(Base.invokelatest(names, m, usings=true)))
  e.nodes[:scope] = (m, world, lists)
  lists
end

"""
The names that the text before the caret could be the start of, in a code
block: the line, the column where the name starts, and the names, the best
first. Nothing when the caret isn't in code, or no name fits. A name fits when
it starts with what's typed, or when one of its words does, like `length` in
`wall_length`. The names that start with what's typed come first, and among
them the page's own.
"""
code_offered(e) = begin
  b = e.buf
  i, col = b.caret
  # Only just after a character was typed here. The caret can move through code with no list in
  # its way, and a caret that comes back to where it was has no list either.
  get(e.nodes, :typed_at, nothing) == (b.path, b.version, b.caret) || (delete!(e.nodes, :typed_at); return nothing)
  line = kinds(b)[i]
  (line.kind == Kind.code && !(line.lang in NO_NAMES)) || return nothing
  chars = collect(b.lines[i])
  # In the middle of a word, nothing is offered
  col < length(chars) && isnamechar(chars[col+1]) && return nothing
  start = col
  while start > 0 && (isnamechar(chars[start]) || chars[start] == '!'); start -= 1 end
  # 2n is two times n, so a name starts after the digits
  while start < col && !(isletter(chars[start+1]) || chars[start+1] == '_'); start += 1 end
  # The @ of a macro is part of its name
  start > 0 && start < col && chars[start] == '@' && (start -= 1)
  col - start >= 2 || return nothing
  # What's after a dot is a part of a value, and the page doesn't know the parts of a value
  start > 0 && chars[start] == '.' && return nothing
  lang = shared_lang(line.lang)
  # Not in a string or a comment, and not for a word of the language
  for t in tokens(b.lines[i], lang)
    t.col < col <= t.col + length(t.text) && t.kind in (:string, :comment, :keyword, :number) && return nothing
  end
  typed = lowercase(String(chars[start+1:col]))
  found = Tuple{Int,Int,Int,String}[]   # how well it fits, where it's from, how far away it is, and the name
  seen = Set{String}()
  # False when the name is what's typed, so nothing is offered. A name that fits is noted.
  note!(name, from, far) = begin
    low = lowercase(name)
    low == typed && return false
    name in seen && return true
    fit = startswith(low, typed) ? 0 : any(w -> startswith(w, typed), split(low, '_', keepempty=false)) ? 1 : 2
    fit < 2 && (push!(seen, name); push!(found, (fit, from, far, name)))
    true
  end
  for (name, places) in page_names(e, lang)
    # The name that's being typed is in the page's code too, where the caret is
    others = [abs(p[1] - i) for p in places if p != (i, start)]
    isempty(others) || note!(name, 0, minimum(others)) || return nothing
  end
  if lang == "julia"
    # The shortest name first, so `len` offers `length` before `lengthof`
    for (from, list) in enumerate(scope_names(e)), name in list
      note!(name, from, length(name)) || return nothing
    end
  end
  isempty(found) && return nothing
  (i, start, [name for (_, _, _, name) in first(sort!(found), NAMES_SHOWN)])
end

# --- the whole window ---------------------------------------------------------------------

describe(e::Editor) = begin
  use!(getproperty(THEMES, e.theme))
  use_code_font!(e)
  win = window_of(e)
  if win !== nothing && e.applied != e.theme
    set_dark!(win, e.theme == :night)
    e.applied = e.theme
  end
  receive!(e)
  await_default!(e)
  moved = refresh!(e.buf)
  moved === nothing || (stay!(e, moved); fresh!(e, moved))
  # The bars beside the lines that just changed fade, so the window is drawn again while they show
  isempty(fresh(e)) || redraw_in!(e, 1/30)
  find_tick!(e)
  sound_tick!(e)
  takeoff_tick!(e)
  schedule_tick!(e)
  job_tick!(e)
  zoom_tick!(e)
  layout!(e)
  # A page whose long lines don't wrap scrolls sideways as far as its longest line goes, and no further when the window grows
  if !wraps(e)
    e.reach = maximum(it -> it.content isa Flow ? extent(it.content) : 0px, e.layout, init=0px)
    scroll_sideways!(e, 0px)
  end
  # A live block that changed the size of the text stays where it was in the window
  hold = pop!(e.nodes, :hold, nothing)
  hold === nothing || (e.scroll.offset = max(0px, item(e, hold[1]).top - hold[2]))
  e.reveal && (reveal!(e); e.reveal = false)
  # The window is drawn again as soon as a key or the mouse does something, so
  # typing shows without waiting for a frame that was already under way. Between
  # times it only wakes to blink the caret.
  if win !== nothing
    # While the sidebar slides, each frame is drawn as soon as it can be
    win.animating = sliding(e)
    # A part of a live block that has the keyboard, like a text field, blinks its own caret
    win.wake = pop!(e.nodes, :ran, false) ? 0.05 : win.focus === e ? 0.51 - mod(time() - e.blink, 0.5) :
               win.focus === nothing ? 0.0 : 0.25
  end
  # The sidebar runs from the top of the window to the bottom, and the top bar
  # lies over the top of the sidebar and the page
  body = Row(width(grow=grow), height(grow=grow), Alignment.Start, background(colours.bg),
    (opened(e) > 0 ? (node!(Sidebar, e, :sidebar),) : ())...,
    Column(width(grow=grow), height(grow=grow), Alignment.Start,
      Box(width(grow=grow), height(TOPBAR_H)),   # under the top bar
      node!(Page, e, :page)))
  popup = e.popup == :none ? () : (node!(Backdrop, e, :backdrop), finder(e))
  Stack(width(grow=grow), height(grow=grow), Alignment.Start, name="Editor",
    body, panel_edge(e)..., tablebar(e)..., outcome_over(e)..., suggestbox(e)..., findbar(e)..., sound_over(e)..., fill_over(e)..., task_over(e)..., takeoff_over(e)..., zoom_over(e)..., node!(TopBar, e, :topbar), popup...)
end

# --- windows ------------------------------------------------------------------------------
#
# Kaydown can have more than one window open, each with an editor of its own.
# The settings page opens in a window of its own, so the page you were working
# on stays as it was. ⌘W closes a window, and Kaydown quits when its last
# window closes.

const WELCOME = joinpath(@__DIR__, "pages", "welcome.md")

"The editor of each window that's open, in the order they opened"
const editors = Editor[]

"""
Make a window for the editor `e`. `show_window!` puts it on the screen. Until
it closes, `e` gets each setting that changes in another window.
"""
window!(e; kw...) = begin
  w = Window(e; kw...)
  push!(editors, e)
  focus(e)
  w
end

"""
Put the window `w` on the screen, if the window `by` that asked for it is on
the screen. A test's window isn't, so the windows that it opens aren't either.
"""
show_window!(w, by) = (by !== nothing && isopen(by) && open(w); w)

onclose(e::Editor, ::Window) = (Base.filter!(o -> o !== e, editors); nothing)

"""
A window that shows the Markdown file or the folder at `path`, with the
settings of the editor `like`. `show_window!` puts it on the screen.
"""
page_window(path, like) = begin
  e = build_editor(path)
  foreach(name -> setfield!(e, name, getfield(like, name)), SHARED)
  e.remember = like.remember
  e.size = paper_window(screen_room(), e.side)
  window!(e, title="Kaydown", size=e.size)
end

# --- settings -----------------------------------------------------------------------------
#
# The settings are the page's colours, its font, the size of its text, its width,
# what the count at the top right counts, how code shows and how wide the
# sidebar is. ⌘, opens the settings page, a
# Markdown file whose live blocks change them, in a window of its own. A
# setting that changes in one window changes in every window. They are kept in
# a file, so the next window opens with them.

"The folder of Kaydown's own pages. The built app changes it to the copies it writes out."
const pages_dir = Ref(joinpath(@__DIR__, "pages"))

"The settings that every window has the same: each is a field of the editor"
const SHARED = (:theme, :font, :zoom, :widest, :stat, :spelling, :wrap, :numbers, :shade, :indent, :code_scale, :code_font, :guide, :side)

const SETTINGS_SIZE = (720px, 820px)   # of the settings window, when the window that asked for it is big enough
const SETTINGS_DROP = 48px             # how far the settings window's top is below the top of the window that asked for it

"True when `e` is the editor of the settings window. That window can go to another page, and then it's a window like any other."
issettings(e) = e.settings && e.buf.path == joinpath(pages_dir[], "settings.md")

"The editor of the settings window, or nothing while that window isn't open"
settings_editor() = (i = findfirst(issettings, editors); i === nothing ? nothing : editors[i])

"""
Show the settings page in a window of its own. With that window open already,
bring it to the front. In the settings window itself, close it.
"""
toggle_settings!(e) = begin
  by = window_of(e)
  by === nothing && return e
  issettings(e) && return (close(by); e)
  s = settings_editor()
  s === nothing || return (front!(window_of(s)); e)
  s = build_editor(joinpath(pages_dir[], "settings.md"))
  s.settings = true
  foreach(name -> setfield!(s, name, getfield(e, name)), SHARED)
  s.remember = e.remember
  s.panel = false
  # The window goes over the middle of the one that asked for it, a little below its top
  wide, tall = SETTINGS_SIZE
  tall = min(tall, max(400px, by.size[2] - 2SETTINGS_DROP))
  at = (max(0px, by.position[1] + (by.size[1] - wide) / 2), by.position[2] + SETTINGS_DROP)
  s.size = (wide, tall)
  show_window!(window!(s, title="Settings", size=s.size, position=at), by)
  e
end

"""
Give the other windows the settings of `e`, after one of them changed. A window
that isn't in `editors`, like one a test makes, keeps its settings to itself.
"""
share_settings!(e) = begin
  any(o -> o === e, editors) || return
  for o in editors
    o === e || adopt_settings!(o, e)
  end
end

"Give `o` the settings of `e` that are different. The line at the top of `o`'s window stays there."
adopt_settings!(o, e) = begin
  changed = filter(name -> getfield(o, name) != getfield(e, name), SHARED)
  isempty(changed) && return o
  for name in changed
    setfield!(o, name, getfield(e, name))
    rerun!(o, name)   # a live block that reads the setting shows the new one
  end
  # The width of a sidebar that's hidden changes nothing that the window shows
  o.panel || changed != (:side,) || return o
  # Text of another size or width wraps again, and that moves the lines
  y = o.scroll.offset
  i = findfirst(it -> it.top + it.tall > y, o.layout)
  i === nothing || (o.nodes[:hold] = (o.layout[i].first, o.layout[i].top - y))
  empty!(o.flows)
  w = window_of(o)
  w === nothing || stale!(w)
  o
end

settings_file() = joinpath(homedir(), "Library", "Application Support", "Kaydown", "settings")

"""
Give the other windows the settings of `e`, and write them to their file if
this editor keeps them. An editor that's made for a test doesn't.
"""
save_settings!(e) = begin
  share_settings!(e)
  e.remember || return
  try
    mkpath(dirname(settings_file()))
    write(settings_file(), "theme=$(e.theme)\nfont=$(e.font)\nzoom=$(e.zoom)\nwidth=$(e.widest.value)\ncount=$(e.stat)\nspelling=$(e.spelling)\nwrap=$(e.wrap)\nnumbers=$(e.numbers)\nshade=$(e.shade)\nindent=$(e.indent)\ncode=$(e.code_scale)\ncodefont=$(e.code_font)\nguide=$(e.guide)\nsidebar=$(e.side.value)\n")
  catch
    # A file that can't be written only means the settings last as long as the window
  end
  nothing
end

"Give `e` the settings that were kept the last time one changed"
load_settings!(e) = begin
  isfile(settings_file()) || return e
  for line in eachline(settings_file())
    name, value = (split(line, '=', limit=2)..., "")[1:2]
    if name == "theme" && Symbol(value) in THEME_ORDER
      e.theme = Symbol(value)
    elseif name == "font" && !isempty(value)
      e.font = String(value)
    elseif name == "zoom"
      z = tryparse(Float64, value)
      z === nothing || (e.zoom = clamp(z, 0.6, 2.5))
    elseif name == "width"
      w = tryparse(Float64, value)
      w === nothing || (e.widest = px(clamp(w, NARROWEST, WIDEST)))
    elseif name == "count" && Symbol(value) in STATS
      e.stat = Symbol(value)
    elseif name == "spelling"
      e.spelling = value != "false"
    elseif name == "wrap"
      e.wrap = value != "false"
    elseif name == "numbers"
      e.numbers = value != "false"
    elseif name == "shade"
      e.shade = value == "true"
    elseif name == "indent"
      n = tryparse(Int, value)
      n in INDENTS && (e.indent = n)
    elseif name == "code"
      c = tryparse(Float64, value)
      c === nothing || (e.code_scale = clamp(c, CODE_SCALES...))
    elseif name == "guide"
      n = tryparse(Int, value)
      n in GUIDES && (e.guide = n)
    elseif name == "codefont"
      # A font that's no longer on the Mac leaves code in the usual one
      installed_weight(value, 400) > 0 && (e.code_font = String(value))
    elseif name == "sidebar"
      w = tryparse(Float64, value)
      w === nothing || (e.side = px(round(clamp(w, num(PANEL_MIN), num(PANEL_MAX)))))
    end
  end
  e
end

"""
Open an editor window and run it until it closes. `args` can name a Markdown
file or a folder, and `--paper` or `--night` to choose the colours for this window.
"""
open_editor(args) = begin
  # macOS can pass its own -options to an app it opens, so skip anything with a dash
  paths = filter(a -> !startswith(a, "-"), args)
  Agent.announce()   # an agent's script knows from now on that this Kaydown can send it a page
  e = build_editor(isempty(paths) ? WELCOME : paths[1])
  load_settings!(e)
  "--night" in args && (e.theme = :night)
  "--paper" in args && (e.theme = :paper)
  e.remember = true
  e.size = paper_window(screen_room(), e.side)
  # This returns when the last window has closed
  display(window!(e, title="Kaydown", size=e.size))
end

# The close, minimise and zoom buttons line up with the sidebar's button, in the middle of the top bar
onopen(::Editor, w::Window) = place_window_buttons!(hide_titlebar!(w), TOPBAR_H / 2, TOPBAR_H / 2)

const PAGE_AREA_W = 850px   # the width of the page's part of a new window: room for the page at the width it starts with, and the space beside it

"How tall the part of the main screen is that a window can use, under the menu bar and over the Dock"
screen_room() = begin
  if Sys.isapple() && Sys.ARCH == :aarch64
    # macOS gives the rectangle as four numbers: where it starts, how wide it is and how tall
    frame = with_pool() do
      screen = msg(cls("NSScreen"), "mainScreen")
      screen == C_NULL ? nothing : ccall((:objc_msgSend, libobjc), NTuple{4,Float64}, (Ptr{Cvoid}, Ptr{Cvoid}), screen, sel("visibleFrame"))
    end
    frame === nothing || return px(frame[4])
  end
  # Anywhere else, leave room for a menu bar and a Dock of the usual size
  Screen().size[2] - 110px
end

"""
The size that a new window opens at. The page's part of it, beside the
sidebar, has the shape of a sheet of A4 paper that stands up: √2 times as tall
as it's wide. So the window is that wide plus the width of the sidebar, and the
page keeps its shape while the sidebar is open. The page's part is
`PAGE_AREA_W` wide, or as big as fits on a screen that isn't tall enough for that.
`side` is how wide the sidebar is.
"""
paper_window(room::px=screen_room(), side::px=PANEL_W) = begin
  tall = min(num(PAGE_AREA_W) * √2, num(room) - 20)   # a little space under the window
  (px(round(tall / √2)) + side, px(round(tall)))
end

# --- printing ------------------------------------------------------------------------------
#
# ⌘P prints the page. The page is drawn into a PDF the way it reads, with no
# caret and no markup characters, in the Paper colours whatever colours the
# window has. The text is PRINT_TEXT points tall on paper, whatever size it
# has on screen, and the lines are as long as the paper allows. A page ends
# under a line of text or a row of a table or a sheet, never through one, and
# never right under a heading. Then the Mac's print panel slides down over the
# window with the PDF in it. The panel can save the PDF as a file too.

const PRINT_TEXT = 11.0   # the size of the page's text on paper, in points (1/72 of an inch)
const PRINT_X = 60.0      # the margin left and right of the text, in points
const PRINT_Y = 64.0      # the margin above and below it. The page's number is in the one below.
const A4 = (595.0, 842.0)

struct NSSize
  width::Float64
  height::Float64
end

"The size of the paper that the Mac prints on unless you choose another, in points"
paper_size() = begin
  Sys.isapple() || return A4
  s = with_pool() do
    ccall((:objc_msgSend, libobjc), NSSize, (Ptr{Cvoid}, Ptr{Cvoid}), msg(cls("NSPrintInfo"), "sharedPrintInfo"), sel("paperSize"))
  end
  s.width > 0 && s.height > 0 ? (s.width, s.height) : A4
end

"True when item `it` is a line with nothing on it"
blank(e, it::Item) = it.content isa Flow && isempty(strip(e.buf.lines[it.first]))

"""
The places down the page's text where a printed page can end: under each line
of text, and under each row of a table or a sheet. A page doesn't end under a
heading, or under the blank lines after one, so a heading goes onto the next
page with the text under it. For the same reason a page doesn't end under the
heading row of a table.
"""
breaks(e) = begin
  out = px[]
  held = false   # under a heading, with only blank lines since
  for it in e.layout
    c = it.content
    if c isa Flow
      for k in 1:length(c.lines)-1
        push!(out, it.top + line_top(c, k + 1))
      end
    elseif c isa Grid
      # Under the line under each row, after the second
      y = it.top + TABLE_GAP + c.head + 1px
      for (r, h) in enumerate(c.heights[1:end-1])
        y += h + 1px
        r > 1 && push!(out, y)
      end
    elseif c isa Sheet
      for r in 2:length(c.rows)
        push!(out, it.top + row_top(c, r))
      end
    end
    held = c isa Flow && (c.kind == Kind.heading || (held && blank(e, it)))
    held || push!(out, it.top + it.tall)
  end
  sort!(out)
end

"""
The part of the page's text that each printed page shows, from its top to its
bottom. A page holds `room` of text. A blank line at the top of a page, or at
the end of the text, isn't printed.
"""
pages(e, room) = begin
  items = filter(it -> !blank(e, it), e.layout)
  isempty(items) && return [(0px, 0px)]
  total = last(items).top + last(items).tall
  ends = breaks(e)
  out = Tuple{px,px}[]
  top = first(items).top
  while true
    if total - top <= room
      push!(out, (top, total))
      return out
    end
    i = findlast(y -> y <= top + room, ends)
    # A block that's taller than a page, like a big live block, is cut where the page ends
    bottom = i === nothing || ends[i] <= top ? top + room : ends[i]
    push!(out, (top, bottom))
    # The next page starts with the next thing that isn't a blank line
    next = findfirst(it -> it.top + it.tall > bottom, items)
    top = max(bottom, items[next].top)
  end
end

"Clip what `canvas` draws to a box"
clip!(canvas, left, top, right, bottom) = begin
  rect = Ref(Skia.sk_rect_t(Float32(left), Float32(top), Float32(right), Float32(bottom)))
  GC.@preserve rect Skia.sk_canvas_clip_rect_with_operation(canvas, Base.unsafe_convert(Ptr{Skia.sk_rect_t}, rect), Skia.SK_CLIP_OP_INTERSECT, true)
end

"""
Draw the page's text into a PDF for paper that's `paper` points wide and tall,
and return the bytes of the PDF. The editor is left as it was.
"""
print_pdf(e, paper=paper_size()) = begin
  pw, ph = paper
  b = e.buf
  caret, anchor, wrapped = b.caret, b.anchor, e.wrap
  stream = Skia.sk_dynamic_memory_wstream_new()
  try
    # With the caret on no line, each line hides its markup and each live block shows what it made
    b.caret = b.anchor = (0, 0)
    # Paper doesn't scroll sideways, so a long line of code goes on under itself
    e.wrap = true
    use!(PAPER)
    use_code_font!(e)
    empty!(e.flows)
    # From pixels on screen to points on paper. The text is as wide as the paper allows.
    scale = PRINT_TEXT / num(body(e).size)
    layout!(e, px((pw - 2PRINT_X) / scale))
    w = e.width
    spans = pages(e, px((ph - 2PRINT_Y) / scale))
    d = node!(Document, e, :document)
    whole = Column(fixed(w), Alignment.Start, [x isa Item ? describe(e, x) : x for x in blocks(d, e.layout)]...)
    total = isempty(e.layout) ? 0px : last(e.layout).top + last(e.layout).tall
    # A live block's code can load the drawing methods of what it shows, so the newest methods are used
    scene = Base.invokelatest(describe, whole, (w, total))
    title, creator, none = splitext(name(b))[1], "Kaydown", ""
    never = Skia.sk_date_time_t(0, 0, 0, 0, 0, 0, 0, 0)
    # Skia copies the text of the PDF's details as it makes the PDF
    doc = GC.@preserve title creator none begin
      about = Ref(Skia.sk_metadata_t(pointer(title), pointer(none), pointer(none), pointer(none), pointer(creator),
                                     pointer(creator), never, never, 72f0, 0f0, Cint(101)))
      GC.@preserve about Skia.sk_document_make_pdf(Skia.sk_dynamic_memory_wstream_as_wstream(stream),
                                                   Base.unsafe_convert(Ptr{Skia.sk_metadata_t}, about))
    end
    for (n, (top, bottom)) in enumerate(spans)
      canvas = Skia.sk_document_begin_page(doc, Float32(pw), Float32(ph))
      Skia.sk_canvas_save(canvas)
      Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(PRINT_Y))
      Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
      # Only this page's part of the text, though something wide can run into the margins
      margin = PRINT_X / scale
      clip!(canvas, -margin, 0, num(w) + margin, num(bottom - top))
      Skia.sk_canvas_translate(canvas, 0f0, Float32(-num(top)))
      Base.invokelatest(draw, canvas, (w, total), scene)
      Skia.sk_canvas_restore(canvas)
      # The page's number, under the middle of the text
      if length(spans) > 1
        Skia.sk_canvas_save(canvas)
        Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(ph - PRINT_Y / 2 - 6))
        Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
        number = describe(Row(fixed(w), height(20px),
                              Text(string(n), size=px(9 / scale), family=SANS, color=colours.dim, wrap=WrapMode.none,
                                   align=TextAlign.Center)), (w, 20px))
        draw(canvas, (w, 20px), number)
        Skia.sk_canvas_restore(canvas)
      end
      Skia.sk_document_end_page(doc)
    end
    Skia.sk_document_close(doc)
    bytes = Vector{UInt8}(undef, Skia.sk_dynamic_memory_wstream_bytes_written(stream))
    Skia.sk_dynamic_memory_wstream_read(stream, bytes, Csize_t(0), Csize_t(length(bytes)))
    bytes
  finally
    Skia.sk_dynamic_memory_wstream_delete(stream)
    b.caret, b.anchor, e.wrap = caret, anchor, wrapped
    use!(getproperty(THEMES, e.theme))
    empty!(e.flows)
    layout!(e)
  end
end

"""
Show the Mac's print panel over window `w`, with the PDF in `bytes`. It slides
down from the top of the window, and the window waits until you print or cancel.
A window that isn't on the screen, like one a test makes, shows no panel.
"""
print_panel!(e, w, bytes, title) = begin
  (Sys.isapple() && !isempty(w.glfw)) || return
  # PDFKit draws a PDF for the Mac's printing. AppKit doesn't load it by itself.
  Base.Libc.Libdl.dlopen("/System/Library/Frameworks/PDFKit.framework/PDFKit")
  with_pool() do
    data = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt),
                 cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
    pdf = msg(msg(cls("PDFDocument"), "alloc"), "initWithData:", data)
    pdf == C_NULL && return
    # The panel may still need the last PDF until it closes, so it's kept until the next one
    last = get(e.nodes, :printed, C_NULL)
    last == C_NULL || msg(last, "release")
    e.nodes[:printed] = pdf
    # The PDF has its own margins, so the panel adds none
    info = msg(msg(msg(cls("NSPrintInfo"), "sharedPrintInfo"), "copy"), "autorelease")
    foreach(side -> send(info, "set$(side)Margin:", 0.0), ("Top", "Bottom", "Left", "Right"))
    # Each page is made smaller if it's too big for the paper chosen in the panel (2 is kPDFPrintPageScaleDownToFit)
    op = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int, Bool),
               pdf, sel("printOperationForPrintInfo:scalingMode:autoRotate:"), info, 2, true)
    op == C_NULL && return
    # The name that "Save as PDF" suggests
    msg(op, "setJobTitle:", nsstring(title))
    win = nswindow(w)
    ccall((:objc_msgSend, libobjc), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          op, sel("runOperationModalForWindow:delegate:didRunSelector:contextInfo:"), win, print_listener(), sel("printed:success:window:"), win)
  end
  nothing
end

"""
AppKit calls this when the print panel closes, with the window it was over.
The window doesn't get the keyboard back by itself, so this gives it back.
"""
printed(self::Ptr{Cvoid}, cmd::Ptr{Cvoid}, op::Ptr{Cvoid}, ok::Bool, win::Ptr{Cvoid}) = (msg(win, "makeKeyWindow"); nothing)

# The object that AppKit tells when a print panel closes. It's made the first time a panel opens, and lasts as long as the app.
const listener = Ref(C_NULL)

"""
The object that AppKit tells when a print panel closes. Its class is made
here, in Objective-C's runtime, with `printed` as its one method.
"""
print_listener() = begin
  listener[] == C_NULL || return listener[]
  class = cls("KaydownPrintListener")
  if class == C_NULL
    class = ccall((:objc_allocateClassPair, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, Csize_t), cls("NSObject"), "KaydownPrintListener", 0)
    method = @cfunction(printed, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Bool, Ptr{Cvoid}))
    ccall((:class_addMethod, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cstring), class, sel("printed:success:window:"), method, "v@:@B^v")
    ccall((:objc_registerClassPair, libobjc), Cvoid, (Ptr{Cvoid},), class)
  end
  listener[] = msg(msg(class, "alloc"), "init")
end

"Print the page: show the Mac's print panel with the page drawn for paper"
print!(e, w) = e.buf.view != :markdown ? nothing : print_panel!(e, w, print_pdf(e), splitext(name(e.buf))[1])   # only a Markdown file is a page

if abspath(PROGRAM_FILE) == @__FILE__
  open_editor(ARGS)
end
