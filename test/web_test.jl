# Tests for web/, which draws a page of HTML with no browser: how it reads
# HTML and CSS, the style that each element gets, where layout puts each box,
# and what the page's links and words are. Run them with
# `julia -O0 --project=. test/web_test.jl`. They use the fonts of this Mac and
# no web.

@use Test: @test, @testset
@use "../web/dom" => Dom
@use "../web/css" => Css
@use "../web/style" => Styles
@use "../web/box" => Boxes
@use "../web/layout" => Layout
@use "../web" => Web

"The first element of `e`'s tree that `ok` is true of"
function element(ok, e::Dom.Element)
  ok(e) && return e
  for c in e.children
    c isa Dom.Element || continue
    found = element(ok, c)
    found === nothing || return found
  end
  nothing
end
tagged(doc, tag) = element(e -> e.tag == tag, doc.root)
named(doc, id) = element(e -> Dom.attr(e, "id") == id, doc.root)

"The box of the element `e` under `b`"
function box(b::Boxes.Box, e)
  b.element === e && return b
  for k in b.children
    found = box(k, e)
    found === nothing || return found
  end
  nothing
end

"The page that `html` writes, laid out `wide` px wide: its document, its styles and the box of its <html>"
function laid(html; wide=400)
  doc = Dom.document(html)
  look = Styles.styles(doc, wide)
  root = Boxes.boxes(doc, look)
  tall = Layout.layout!(root, wide, doc.mode)
  (doc=doc, look=look, root=root, tall=tall, box=id -> box(root, named(doc, id)))
end

"Where the border of `b` is on the page"
function place(root::Boxes.Box, b::Boxes.Box)
  walk(at, x, y) = begin
    at === b && return (x + at.x, y + at.y)
    for k in [at.children; at.over]
      found = walk(k, x + at.x, y + at.y)
      found === nothing || return found
    end
    nothing
  end
  walk(root, 0.0, 0.0)
end

tags(e::Dom.Element) = [c.tag for c in e.children if c isa Dom.Element]

@testset "reading HTML" begin
  doc = Dom.document("<p>Hi <b>there</b><div>block</div>Tom &amp; Sam&rsquo;s &#8212; <!-- gone -->")
  @test tags(doc.root) == ["body"] && tags(doc.body) == ["p", "div"]   # the <p> ends where the block starts
  @test Dom.text(doc.body) == "Hi thereblockTom & Sam’s — "
  @test doc.mode == :quirks
  @test Dom.document("<!DOCTYPE html><p>x").mode == :standards
  @test Dom.document("""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><p>x""").mode == :limited
  # A table's rows get a <tbody>, a cell ends where the next starts, and what's in no cell goes before the table
  doc = Dom.document("<table><tr><td>one<td>two</tr>stray<tr><td><table><td>in</table></table>after")
  @test tags(doc.body) == ["table"] && Dom.text(doc.body.children[1]) == "stray"
  table = tagged(doc, "table")
  @test tags(table) == ["tbody"] && tags(table.children[1]) == ["tr", "tr"] && tags(table.children[1].children[1]) == ["td", "td"]
  @test Dom.text(element(e -> e.tag == "table" && e !== table, doc.root)) == "in"
  # A list item ends where the next starts, and a part of a table that's in no table is nothing
  @test tags(tagged(Dom.document("<ul><li>a<li>b<ul><li>c</ul><li>d</ul>"), "ul")) == ["li", "li", "li"]
  @test Dom.text(Dom.document("<td>loose</td><tr>row").body) == "looserow"
  # The head's tags stay out of the body, and a style's text is kept as it's written
  doc = Dom.document("<title>T</title><style>a > b { color: red }</style><p>x")
  @test tags(doc.root) == ["head", "body"] && doc.sheets == [("a > b { color: red }", "")]
  # What a comment for Outlook hides is hidden, and what it shows to the rest is shown
  @test Dom.text(Dom.document("a<!--[if mso]>no<![endif]-->b<!--[if !mso]><!-->c<!--<![endif]-->").body) == "abc"
  @test Dom.attr(tagged(Dom.document("<a HREF='x?a=1&amp;b=2' Title=Go>x</a>"), "a"), "href") == "x?a=1&b=2"
end

@testset "reading CSS" begin
  rules = Css.sheet("""p.a > b, td { color: red; margin: 0 !important } /* note */
    @media (max-width: 600px) { .x { display: none } }
    a:hover { color: blue } @font-face { font-family: X } .bad:: { x: y } #id.k[href^="http"]:not(.q):first-child { width: calc(100% - 2px) }""")
  @test [r.selector.weight for r in rules] == [(0, 1, 2), (0, 0, 1), (0, 1, 0), (0, 1, 1), (1, 4, 0)]
  @test [(d.name, d.value, d.important) for d in rules[1].declarations] == [("color", "red", false), ("margin", "0", true)]
  @test rules[3].media == ["(max-width: 600px)"] && isempty(rules[1].media)
  doc = Dom.document("""<p class="a"><i>x</i><b id="b1">one</b><b>two</b></p><p><b id="b2">no</b></p><a id="id" class="k" href="http://x">l</a>""")
  b1, b2 = named(doc, "b1"), named(doc, "b2")
  @test Css.matches(rules[1].selector, b1) && !Css.matches(rules[1].selector, b2)
  @test !Css.matches(rules[4].selector, tagged(doc, "a"))   # nothing is under the mouse
  @test !Css.matches(rules[5].selector, named(doc, "id"))   # it isn't the first in its parent
  for (text, e, ok) in [("p b", b1, true), ("p > i + b", b1, true), ("i ~ b", b1, true), ("b:first-child", b1, false), ("b:nth-child(2)", b1, true),
                        ("b:last-child", b1, false), ("p:not(.a) b", b2, true), ("[class~=a] b", b2, false), ("*", b2, true), ("body p.a b#b1", b1, true),
                        ("a[href*='//']", named(doc, "id"), true), ("a:link", named(doc, "id"), true), ("b:only-child", b2, true)]
    @test Css.matches(Css.selector(text), e) == ok
  end
  @test Css.selector("a::") === nothing && Css.selector("") === nothing
  @test Css.media("screen and (max-width: 600px)", 500) && !Css.media("screen and (max-width: 600px)", 700)
  @test Css.media("print, (min-width: 30em)", 480) && !Css.media("print", 480) && Css.media("not print", 480)
  # A Mac's screen has two pixels to the px
  @test Css.media("(-webkit-min-device-pixel-ratio: 2)", 500) && !Css.media("only screen and (-webkit-min-device-pixel-ratio: 3)", 500)
end

@testset "the style of each element" begin
  doc = Dom.document("""<!DOCTYPE html><style>
    p { color: red; margin: 1em 2px } .a { color: green } p.a { color: blue !important } #x { color: black }
    .btn { background: #06c url(x.png) no-repeat center / cover; border: 1px solid rgba(0,0,0,.5); border-radius: 4px 8px;
           font: bold 14px/1.4 "Helvetica Neue", Arial, sans-serif; padding: 1em 20px; width: calc(100% - 2em) }
    @media (max-width: 300px) { p { display: none } }</style>
    <p id="x" class="a" style="color: orange; margin-top: 5px">Hi <b id="b">there</b></p>
    <table id="t" width="600" cellpadding="10" cellspacing="0" border="1" align="center"><tr><td id="d" bgcolor="ff0000" width="50%" align="center" valign="top">one<a id="l" class="btn" href="x">Go</a></td></tr></table>
    <h1 id="h"><font id="f" size="2" color="navy" face="Georgia">small</font></h1>""")
  look = Styles.styles(doc, 700)
  s(id) = look[named(doc, id)]
  # !important wins over the element's own style, which wins over an id
  @test s("x").color == 0xff0000ff && s("x").display == :block
  @test Styles.px(s("x").margin[1]) == 5 && Styles.px(s("x").margin[2]) == 2 && Styles.px(s("x").margin[3]) == 16
  @test s("b").color == 0xff0000ff && s("b").weight == 700 && s("b").display == :inline   # a child takes its parent's colour
  @test Styles.styles(doc, 300)[named(doc, "x")].display == :none
  # What a tag says: a table's width, its border round each cell, and its cells' padding
  t, d = s("t"), s("d")
  @test Styles.px(t.width) == 600 && all(Styles.isauto, (t.margin[2], t.margin[4])) && Styles.border(t, 1) == 1
  @test d.background == 0xffff0000 && d.width.pct == 0.5 && d.align == :wk_center && d.valign[1] == :top
  @test all(i -> Styles.px(d.padding[i]) == 10 && Styles.border(d, i) == 1, 1:4)
  # A property that stands for several
  l = s("l")
  @test l.background == 0xff0066cc && l.image == "url(x.png)" && l.repeat == :no_repeat && l.bgsize == :cover
  @test l.weight == 700 && l.size == 14 && l.lineheight == (:number, 1.4) && l.family == ["Helvetica Neue", "Arial", "sans-serif"]
  @test map(x -> Styles.px(x), l.radius) == (4, 8, 4, 8) && Styles.border(l, 3) == 1 && l.bordercolor[1] == 0x80000000
  @test Styles.px(l.padding[1]) == 14 && l.width.pct == 1 && l.width.px == -28   # an em is 14 px here
  @test l.lines == 0x01 && l.color == 0xff0000ee                                  # a link is blue, with a line under it
  @test s("h").size == 32 && s("f").size == 13 && s("f").color == 0xff000080 && s("f").family == ["Georgia"]
  # Colours and lengths
  @test Styles.colour("#abc") == 0xffaabbcc && Styles.colour("rgb(255, 0, 0)") == 0xffff0000 && Styles.colour("hsl(120, 100%, 50%)") == 0xff00ff00
  @test Styles.colour("transparent") == 0x00000000 && Styles.colour("nonsense") === nothing && Styles.colour("fff"; loose=true) == 0xffffffff
  c = Styles.Context(700.0, 16.0, false)
  @test Styles.len("12pt", c).px == 16 && Styles.len("50%", c).pct == 0.5 && Styles.len("auto", c).auto && Styles.len("12", c) === nothing
  @test Styles.len("12", Styles.Context(700.0, 16.0, true)).px == 12   # a page with no doctype takes a bare number as px
  @test (l = Styles.len("calc((100% - 40px) / 2)", c); l.pct == 0.5 && l.px == -20)
  # A table takes no centring from a tag round it, but takes `text-align: center`
  doc = Dom.document("""<!DOCTYPE html><table><td align="center"><table id="in"><td id="c">x</table></table><div style="text-align:center"><table><td id="k">y</table></div>""")
  look = Styles.styles(doc, 700)
  @test look[named(doc, "c")].align == :start && look[named(doc, "k")].align == :center
end

@testset "blocks and margins" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="a" style="height:10px;margin-bottom:20px"></div>
    <div id="b" style="margin-top:30px;padding:5px;border:2px solid;width:50%"><p id="p" style="margin:8px 0;height:4px"></p></div>
    <div id="c" style="width:100px;margin:0 auto;height:1px"></div><div id="d" style="max-width:150px;margin-left:auto;height:1px"></div></body>""")
  a, b, c, d = p.box("a"), p.box("b"), p.box("c"), p.box("d")
  @test (a.y, a.width, a.height) == (0, 400, 10)
  @test b.y == 40                                    # the bigger of the two margins, not their sum
  @test b.width == 214 && b.height == 4 + 2 * 8 + 14   # half the page, with the padding and the border round it
  @test p.box("p").y == 15 && p.box("p").x == 7      # the padding keeps the paragraph's margin inside
  @test place(p.root, c)[1] == 150 && place(p.root, d)[1] == 250
  # The margin of the first thing in a block is over the block when nothing is between them
  p = laid("""<!DOCTYPE html><body style="margin:0"><div id="o" style="background:red"><h1 id="h" style="margin:25px 0;font-size:10px;line-height:10px">x</h1></div><p id="n" style="margin:10px 0">y</p></body>""")
  @test place(p.root, p.box("o"))[2] == 25 && p.box("o").height == 10 && place(p.root, p.box("n"))[2] == 60
  @test p.tall == 60 + p.box("n").height + 10
  # In a page with no doctype, a paragraph that starts a cell has no margin over it, and one that ends it has none under it
  cell(doctype) = laid("""$doctype<table cellpadding="0" cellspacing="0"><td id="c"><p style="line-height:20px">a</p><p style="line-height:20px">b</p></table>""").box("c")
  @test cell("").height == 56 && cell("<!DOCTYPE html>").height == 88
end

@testset "lines of text" begin
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><p id="p" style="margin:0;width:120px">one two three four five six seven</p>
    <p id="c" style="margin:0;text-align:center;width:200px">mid</p><p id="n" style="margin:0;white-space:nowrap;width:50px">one two three four</p>
    <p id="b" style="margin:0">a<br>b<br><br>c</p><p id="w" style="margin:0;width:60px;overflow-wrap:break-word">aaaaaaaaaaaaaaaaaaaaaaaaaaaa</p></body>""")
  lines = p.box("p").lines
  words(line) = strip(join(String(q.chars) for q in line.pieces if q.kind == :text))
  @test length(lines) > 1 && join(words.(lines), " ") == "one two three four five six seven"
  @test all(l -> l.height == 20, lines) && p.box("p").height == 20 * length(lines)
  @test all(l -> sum(q.width for q in l.pieces) <= 120, lines)   # a space that ends a line takes no room
  mid = p.box("c").lines[1].pieces[1]
  @test isapprox(mid.x + mid.width / 2, 100; atol=0.01)
  @test length(p.box("n").lines) == 1 && length(p.box("b").lines) == 4 && p.box("b").lines[3].height == 20
  @test length(p.box("w").lines) > 2 && all(l -> sum(q.width for q in l.pieces) <= 60, p.box("w").lines)
  # A box in a line: an inline-block is as wide as its content, and stands on the line of the text
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica">a <span id="i" style="display:inline-block;padding:10px;border:1px solid">in</span> <img id="g" width="30" height="40"> z</body>""")
  i, g = p.box("i"), p.box("g")
  @test i.atomic && i.height == 42 && 22 < i.width < 60 && (g.width, g.height) == (30, 40)
  line = p.root.children[1].lines[1]
  @test line.height > 40 && isapprox(g.y + g.height, line.y + line.baseline; atol=0.01)   # a picture stands on the line
  # A cell that holds only a picture is as tall as the picture, unless the page is of today's kind
  gap(doctype) = laid("""$doctype<table cellpadding="0" cellspacing="0"><td id="c"><img width="30" height="40"></table>""").box("c").height
  @test gap("") == 40 && gap("<!DOCTYPE html>") > 40
  # A picture is as wide as its style says, and no wider than the box that it's in
  p = laid("""<!DOCTYPE html><body style="margin:0"><div style="width:100px"><img id="g" width="300" height="150" style="max-width:100%;height:auto;display:block"></div>""")
  @test (p.box("g").width, p.box("g").height) == (100, 50)
end

@testset "floats" begin
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><div id="l" style="float:left;width:100px;height:50px"></div>
    <div id="r" style="float:right;width:80px;height:30px"></div><p id="p" style="margin:0">one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen</p>
    <div id="c" style="clear:both;height:5px"></div></body>""")
  @test place(p.root, p.box("l")) == (0, 0) && place(p.root, p.box("r")) == (320, 0)
  lines = p.box("p").lines
  @test lines[1].pieces[1].x == 100 && lines[end].y >= 40      # text is beside the floats
  @test sum(q.width for q in lines[1].pieces) <= 220 && lines[1].y == 0
  @test place(p.root, p.box("c"))[2] >= 50                    # what clears them is under them
  # A table with `align` is a float, and the next one is beside it
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="a" align="left" width="150" cellspacing="0" cellpadding="0"><td height="20"></table><table id="b" align="left" width="150" cellspacing="0" cellpadding="0"><td height="20"></table></body>""")
  @test place(p.root, p.box("a")) == (0, 0) && place(p.root, p.box("b")) == (150, 0) && p.tall == 20
end

@testset "tables" begin
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="t" width="400" cellspacing="0" cellpadding="0"><tr>
    <td id="a" width="100" height="30"></td><td id="b" width="25%"></td><td id="c"></td></tr><tr><td id="d" colspan="2" height="10"></td><td id="e"></td></tr></table></body>""")
  a, b, c, d, e = (p.box(id) for id in ("a", "b", "c", "d", "e"))
  @test (a.width, b.width, c.width) == (100, 100, 200) && d.width == 200 && e.width == 200
  @test a.height == 30 && c.height == 30 && d.height == 10 && p.box("t").height == 40
  @test place(p.root, c) == (200, 0) && place(p.root, e) == (200, 30)
  # The room between cells, the padding in them, and a table that's centred
  p = laid("""<!DOCTYPE html><body style="margin:0"><table id="t" width="200" align="center" cellspacing="5" cellpadding="3"><tr><td id="a" height="10"></td><td id="b"></td></tr></table></body>""")
  @test place(p.root, p.box("t")) == (100, 0) && p.box("t").height == 26
  @test place(p.root, p.box("a")) == (105, 5) && p.box("a").width + p.box("b").width == 185
  # A table with no width is as wide as its content, and no wider than the page
  p = laid("""<!DOCTYPE html><body style="margin:0;font:16px/20px Helvetica"><table id="s" cellspacing="0" cellpadding="0"><td>short</td></table>
    <table id="w" cellspacing="0" cellpadding="0"><td>$(repeat("word ", 200))</td></table></body>""")
  @test 20 < p.box("s").width < 80 && p.box("w").width == 400
  # What's in a cell is in its middle, unless the cell says otherwise
  p = laid("""<!DOCTYPE html><body style="margin:0"><table cellspacing="0" cellpadding="0"><tr><td height="100"></td>
    <td><div id="m" style="height:20px;width:5px"></div></td><td valign="top"><div id="t" style="height:20px;width:5px"></div></td>
    <td valign="bottom"><div id="b" style="height:20px;width:5px"></div></td></tr></table></body>""")
  @test [place(p.root, p.box(id))[2] for id in ("m", "t", "b")] == [40, 0, 80]
  # A cell takes no greatest height, and a cell is at least as wide as its least width
  p = laid("""<!DOCTYPE html><body style="margin:0"><table width="300" cellspacing="0" cellpadding="0"><tr><td id="g" style="min-width:32px;width:32px"></td>
    <td id="h" height="58" style="width:100%;max-height:1px"></td></tr></table></body>""")
  @test p.box("g").width == 32 && p.box("h").width == 268 && p.box("h").height == 58
end

@testset "a page to draw" begin
  html = """<!DOCTYPE html><body style="margin:10px;font:16px/20px Helvetica;background:#eee">
    <p style="margin:0">Go to <a href="https://example.com/a">the site</a> or <a href="mailto:sam@example.com">write</a>.<br>Next line</p>
    <table cellspacing="0" cellpadding="0"><tr><td>one</td><td>two</td></tr></table>
    <a href="https://example.com/block" style="display:block;width:100px;height:30px;background:blue"></a><a href="javascript:x()">no</a></body>"""
  p = Web.page(html; wide=400)
  @test p.wide == 400 && p.tall == 10 + 40 + 20 + 30 + 20 + 10
  @test [l.url for l in p.links] == ["https://example.com/a", "mailto:sam@example.com", "https://example.com/block"]
  a = p.links[1]
  @test a.top == 11 && a.tall == 18 && a.left > 40 && Web.link(p, a.left + 1, 15) === a && Web.link(p, a.left - 2, 15) === nothing
  @test (p.links[3].left, p.links[3].top, p.links[3].wide, p.links[3].tall) == (10, 70, 100, 30)
  # The words, as they're copied: a new line between two lines of the page, and a tab between two cells of a row
  @test join(w.before * String(w.letters) for w in p.words) == "Go to the site or write.\nNext line\none\ttwo\nno"
  @test p.words[1].from == 0 && p.words[2].from == length(p.words[1].letters) && all(w -> length(w.edges) == length(w.letters) + 1, p.words)
  @test p.list.background == 0xffeeeeee
  # Twice as big: the page is as wide, and its words wrap sooner
  big = Web.page(html; wide=400, zoom=2.0)
  @test big.wide == 400 && big.tall > 2 * 150 - 60 && big.links[3].wide == 200
  # A picture of the page
  dir = mktempdir()
  @test filesize(Web.save(p, joinpath(dir, "page.png"))) > 1000
  # A picture that's written into the page is drawn at its own size. One from the web is asked for, and is an empty box without it.
  dot = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAE0lEQVR42mP8z8DAwMDAxIBMAQAUQAEFadK16wAAAABJRU5ErkJggg=="
  asked = String[]
  p = Web.page("""<!DOCTYPE html><body style="margin:0"><img src="$dot" style="display:block"><img src="https://example.com/x.png" width="20" height="10" style="display:block"></body>""";
               wide=100, load=src -> (push!(asked, src); nothing))
  @test p.tall == 13 && asked == ["https://example.com/x.png"]
  # A page that's wider than its window is made to fit, when that's asked for
  wide = """<!DOCTYPE html><body style="margin:0"><table width="900" cellspacing="0" cellpadding="0"><td><img width="900" height="300" style="display:block"></td></table></body>"""
  @test Web.page(wide; wide=300).tall == 300 && Web.page(wide; wide=300, fit=true).tall == 100 && Web.page(wide; wide=300, fit=true).wide == 300
end
