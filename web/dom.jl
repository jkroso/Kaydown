# Reads a page of HTML into a tree, as a browser does.
#
#     doc = document("<p>Hi <b>there</b></p>")
#     doc.root            # the <html> element
#     doc.body            # the <body> element
#     doc.mode            # :standards, :limited or :quirks, from the page's doctype
#     doc.sheets          # the text of each <style> element, in the page's order
#
# An `Element` has a `tag` in lower case, its `attrs`, its `children` and its
# `parent`. A `Text` has its `text`, with each name like &amp; as its
# character.
#
# HTML that's written wrong is read as a browser reads it, as far as pages of
# email need: a <p> ends where a block starts, a <td> ends where the next
# starts, a row with no <tbody> gets one, and what's in a table but not in a
# cell goes before the table. Comments are left out. No script runs, so what's
# in a <noscript> is part of the page.

@use "./entities" entities

abstract type Node end

mutable struct Element <: Node
  tag::String
  attrs::Dict{String,String}
  children::Vector{Node}
  parent::Union{Element,Nothing}
end

mutable struct Text <: Node
  text::String
  parent::Union{Element,Nothing}
end

Element(tag, attrs=Dict{String,String}()) = Element(tag, attrs, Node[], nothing)

struct Document
  root::Element
  body::Element
  mode::Symbol
  sheets::Vector{Tuple{String,String}}   # the text of each <style>, with what its `media` says
end

"What `name` says in the tag of `e`, or `default`"
attr(e::Element, name, default="") = get(e.attrs, name, default)

push_child!(parent::Element, child::Node) = (child.parent = parent; push!(parent.children, child); child)

"Put `child` in `parent`, before its child `before`"
insert_child!(parent::Element, before::Node, child::Node) = begin
  i = something(findfirst(c -> c === before, parent.children), length(parent.children) + 1)
  child.parent = parent
  insert!(parent.children, i, child)
  child
end

"All the text in `n`"
text(n::Text) = n.text
text(e::Element) = join(text(c) for c in e.children)

# --- the tags and the text ----------------------------------------------------------------

struct Token
  kind::Symbol                 # :text, :open, :close or :doctype
  name::String                 # of a tag, in lower case
  attrs::Dict{String,String}
  text::String
end

const NO_ATTRS = Dict{String,String}()
iswhite(b::UInt8) = b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d || b == 0x0c

"""
What a tag says after its name, from byte `i` of `html`: each `name=value`,
with the names in lower case, and where the tag ends.
"""
attributes(html, i) = begin
  attrs = Dict{String,String}()
  b = codeunits(html)
  n = length(b)
  while i <= n
    if iswhite(b[i]) || b[i] == UInt8('/')
      i += 1
    elseif b[i] == UInt8('>')
      return (attrs, i + 1)
    else
      j = i
      while j <= n && !iswhite(b[j]) && b[j] != UInt8('=') && b[j] != UInt8('>') && (b[j] != UInt8('/') || j == i)
        j += 1
      end
      if j == i   # an = with no name
        i += 1
        continue
      end
      name = lowercase(String(b[i:j-1]))
      i = j
      while i <= n && iswhite(b[i])
        i += 1
      end
      value = ""
      if i <= n && b[i] == UInt8('=')
        i += 1
        while i <= n && iswhite(b[i])
          i += 1
        end
        if i <= n && (b[i] == UInt8('"') || b[i] == UInt8('\''))
          j = something(findnext(==(b[i]), b, i + 1), n + 1)
          value = String(b[i+1:j-1])
          i = j + 1
        else
          j = i
          while j <= n && !iswhite(b[j]) && b[j] != UInt8('>')
            j += 1
          end
          value = String(b[i:j-1])
          i = j
        end
      end
      haskey(attrs, name) || (attrs[name] = entities(value))
    end
  end
  (attrs, n + 1)
end

# What's in these is text as it's written: a < in it starts no tag
const RAW = ("script", "style", "title", "textarea", "xmp", "noembed", "noframes", "iframe")

"The tags and the runs of text of a page of HTML. Comments are left out."
tokens(html::String) = begin
  out = Token[]
  i, n = 1, ncodeunits(html)
  say(a, b) = a <= b && push!(out, Token(:text, "", NO_ATTRS, entities(SubString(html, a, thisind(html, b)))))
  while i <= n
    lt = findnext('<', html, i)
    lt === nothing && (say(i, n); break)
    say(i, lt - 1)
    rest = SubString(html, lt)
    if startswith(rest, "<!--")
      # `<!-->` and `<!--->` are whole comments
      close = startswith(rest, "<!-->") ? (lt+4:lt+4) : startswith(rest, "<!--->") ? (lt+5:lt+5) : findnext("-->", html, lt + 4)
      i = close === nothing ? n + 1 : last(close) + 1
    elseif startswith(rest, "<!") || startswith(rest, "<?")
      gt = findnext('>', html, lt)
      stop = gt === nothing ? n : gt
      occursin(r"^<!doctype"i, rest) && push!(out, Token(:doctype, "", NO_ATTRS, html[lt:stop]))
      i = stop + 1
    elseif (m = match(r"^</([A-Za-z][^\s/>]*)[^>]*>?", rest)) !== nothing
      push!(out, Token(:close, lowercase(m[1]), NO_ATTRS, ""))
      i = lt + ncodeunits(m.match)
    elseif (m = match(r"^<([A-Za-z][^\s/>]*)", rest)) !== nothing
      name = lowercase(m[1])
      attrs, i = attributes(html, lt + ncodeunits(m.match))
      push!(out, Token(:open, name, attrs, ""))
      if name in RAW
        close = findnext(Regex("</$name\\b[^>]*>?", "i"), html, min(i, n + 1))
        stop = close === nothing ? n + 1 : first(close)
        i <= stop - 1 && push!(out, Token(:text, "", NO_ATTRS, html[i:prevind(html, stop)]))
        push!(out, Token(:close, name, NO_ATTRS, ""))
        i = close === nothing ? n + 1 : last(close) + 1
      end
    else
      push!(out, Token(:text, "", NO_ATTRS, "<"))
      i = lt + 1
    end
  end
  out
end

# --- the tree -----------------------------------------------------------------------------

const VOID = Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"])
const HEAD = Set(["meta", "title", "style", "link", "base", "script"])
# A <p> that's open ends where one of these starts
const ENDS_P = Set(["address", "article", "aside", "blockquote", "center", "details", "dialog", "dir", "div", "dl", "fieldset", "figcaption",
                    "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr", "main", "menu", "nav", "ol",
                    "p", "pre", "section", "summary", "table", "ul", "li", "dd", "dt"])
const HEADINGS = Set(["h1", "h2", "h3", "h4", "h5", "h6"])
const TABLE_PARTS = Set(["caption", "colgroup", "col", "tbody", "thead", "tfoot", "tr", "td", "th"])
const GROUPS = Set(["tbody", "thead", "tfoot"])
# An end tag doesn't end an element outside one of these
const SCOPE = Set(["table", "td", "th", "caption", "html"])

"""
How a browser lays the page out, which its doctype says: `:standards` for a
page of today, `:quirks` for a page with no doctype or a very old one, and
`:limited` for one that says it's Transitional, where a cell that holds only a
picture is as tall as the picture.
"""
mode(doctype::AbstractString) = begin
  d = lowercase(doctype)
  occursin("public", d) || return occursin(r"^<!doctype\s+html\s*>?$", d) || occursin("system", d) ? :standards : :quirks
  occursin(r"xhtml 1\.0 (transitional|frameset)", d) && return :limited
  occursin(r"html 4\.01 (transitional|frameset)", d) && return occursin(r"\"[^\"]*\"\s+\"[^\"]*\"|'[^']*'\s+'[^']*'", d) ? :limited : :quirks
  occursin(r"html 4\.0 (transitional|frameset)|html 3\.2|html 2\.0|//dtd html//", d) && return :quirks
  :standards
end

"The tree of a page of HTML"
document(html::AbstractString) = begin
  root = Element("html")
  head = body = nothing
  stack = Element[root]
  sheets = Tuple{String,String}[]
  doctype = nothing
  top() = stack[end]
  open_in(tag) = findlast(e -> e.tag == tag, stack)
  # The innermost open element with one of `tags`, that an end tag or a new element can end: none outside the table or the cell that it's in
  scoped(tags; stop=SCOPE) = begin
    for i in length(stack):-1:1
      stack[i].tag in tags && return i
      stack[i].tag in stop && return nothing
    end
    nothing
  end
  close_to!(i) = resize!(stack, i - 1)
  in_table() = begin   # true when what comes next would be right inside a table, a group of rows or a row
    t = top().tag
    t == "table" || t in GROUPS || t == "tr"
  end
  ensure_body!() = begin
    body === nothing || return body
    head !== nothing && (i = open_in("head")) !== nothing && close_to!(i)
    body = push_child!(root, Element("body"))
    push!(stack, body)
    body
  end
  # Put `node` where the page has got to. In a table but not in a cell, it goes before the table.
  place!(node) = begin
    if in_table()
      i = open_in("table")
      table = stack[i]
      table.parent === nothing ? push_child!(top(), node) : insert_child!(table.parent, table, node)
    else
      push_child!(top(), node)
    end
  end
  for t in tokens(String(html))
    if t.kind == :doctype
      doctype === nothing && body === nothing && head === nothing && (doctype = t.text)
    elseif t.kind == :text
      blank = all(isspace, t.text)
      if body === nothing
        blank && continue
        top().tag in RAW || ensure_body!()
      end
      # Spaces between the parts of a table mean nothing
      in_table() && blank && continue
      place!(Text(t.text, nothing))
    elseif t.kind == :open
      name = t.name
      if name == "html"
        foreach(((k, v),) -> get!(root.attrs, k, v), t.attrs)
        continue
      elseif name == "head"
        if head === nothing && body === nothing
          head = push_child!(root, Element("head", t.attrs))
          push!(stack, head)
        end
        continue
      elseif name == "body"
        if body === nothing
          ensure_body!()
          merge!(body.attrs, t.attrs)
        else
          foreach(((k, v),) -> get!(body.attrs, k, v), t.attrs)
        end
        continue
      end
      if body === nothing
        if name in HEAD
          if head === nothing
            head = push_child!(root, Element("head"))
            push!(stack, head)
          end
        else
          ensure_body!()
        end
      end
      # What an element ends by starting
      if name in ENDS_P && (i = scoped(("p",))) !== nothing && !(name == "table" && doctype === nothing)
        close_to!(i)
      end
      if name == "li"
        (i = scoped(("li",); stop=union(SCOPE, ("ul", "ol")))) !== nothing && close_to!(i)
      elseif name in ("dd", "dt")
        (i = scoped(("dd", "dt"); stop=union(SCOPE, ("dl",)))) !== nothing && close_to!(i)
      elseif name in HEADINGS && top().tag in HEADINGS
        pop!(stack)
      elseif name == "option"
        top().tag == "option" && pop!(stack)
      elseif name == "a"
        (i = scoped(("a",))) !== nothing && close_to!(i)
      elseif name in TABLE_PARTS
        table = open_in("table")
        # A part of a table that's in no table is nothing: its content stays
        table === nothing && continue
        inner = findlast(e -> e.tag in ("td", "th", "caption"), stack)
        cell = inner !== nothing && inner > table
        if name in ("td", "th")
          if cell
            close_to!(inner)
          else
            while !(top().tag in ("tr", "table") || top().tag in GROUPS) pop!(stack) end
          end
          top().tag == "table" && push!(stack, push_child!(top(), Element("tbody")))
          top().tag in GROUPS && push!(stack, push_child!(top(), Element("tr")))
        elseif name == "tr"
          cell && close_to!(inner)
          while !(top().tag == "table" || top().tag in GROUPS) pop!(stack) end
          top().tag == "table" && push!(stack, push_child!(top(), Element("tbody")))
        elseif !(name == "col" && top().tag == "colgroup")
          close_to!(table + 1)
        end
      end
      e = Element(name, t.attrs)
      # A part of a table goes where the table has got to. Anything else that's not in a cell goes before the table.
      name in TABLE_PARTS ? push_child!(top(), e) : place!(e)
      name in VOID || push!(stack, e)
    else # :close
      name = t.name
      name in ("html", "body") && continue
      if name == "head"
        (i = open_in("head")) !== nothing && close_to!(i)
      elseif name == "br"
        body === nothing && ensure_body!()
        place!(Element("br"))
      elseif name == "p" && scoped(("p",)) === nothing
        body === nothing && ensure_body!()
        place!(Element("p"))
      elseif name in HEADINGS
        (i = scoped(HEADINGS)) !== nothing && close_to!(i)
      elseif name in TABLE_PARTS || name == "table"
        # The end of a part of a table ends what's open in it, and nothing outside the table
        table = open_in("table")
        i = findlast(e -> e.tag == name, stack)
        i !== nothing && table !== nothing && i >= table && close_to!(i)
      else
        i = scoped((name,))
        # The end of an element that isn't open is nothing. It never ends the page's body.
        i !== nothing && stack[i] !== body && stack[i] !== root && close_to!(i)
      end
    end
  end
  body === nothing && (body = push_child!(root, Element("body")))
  walk(root) do e
    e.tag == "style" && push!(sheets, (text(e), attr(e, "media")))
  end
  Document(root, body, doctype === nothing ? :quirks : mode(doctype), sheets)
end

"Call `f` with each element of the tree under `e`, and with `e`, in the page's order"
walk(f, e::Element) = begin
  f(e)
  for c in e.children
    c isa Element && walk(f, c)
  end
end
