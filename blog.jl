# A blog is a folder of pages that puts itself on the web. Each Markdown file
# in the folder is a post. main.jl shows the folder's own page, with a list of
# the posts and a Publish button, and makes each post a page of HTML. This
# file knows what a post is and where the site goes. It draws nothing.
#
#     posts("/Users/sam/blog")              # [Post("…/2026-11-20-hello.md", "2026-11-20-hello", "Hello", Date(2026, 11, 20), false), …]
#     standing("/Users/sam/blog", post)     # :new, :changed, :published or :draft
#     address("git@github.com:sam/blog.git")   # "https://sam.github.io/blog/"
#
# A post says things about itself in its front matter:
#
#     ---
#     title: Hello
#     date: 2026-11-20
#     draft: true
#     ---
#
# Without a title, a post has the words of its first heading, or else its
# file's name. Without a date, it has the day that its file's name starts
# with, like `2026-11-20-hello.md`, or else the day that the file was last
# saved. A draft stays out of the site. The page `index.md`, when the folder
# has one, is no post: its text goes over the list of the posts on the site's
# first page.
#
# The site is written into the folder `docs` in the blog's folder: a page for
# each post, with the same name and `.html`, a first page called `index.html`,
# and a copy of each picture that a post shows. GitHub Pages serves that
# folder when the repository's settings say so.

@use Dates: Dates, Date

"The folder in a blog's folder that the site is written into"
const SITE = "docs"
"The page of a blog whose text goes over the list of the posts"
const INDEX = "index.md"

struct Post
  path::String    # its Markdown file
  name::String    # the file's name without its ending. The page of the site has this name, and .html.
  title::String
  day::Date
  draft::Bool
end

const DAY = r"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"

"The first day that's written in `text` like 2026-11-25, or nothing"
day(text::AbstractString) = begin
  for m in eachmatch(DAY, text)
    y, mo, d = parse.(Int, m.captures)
    Dates.validargs(Date, y, mo, d) === nothing && return Date(y, mo, d)
  end
  nothing
end

"What the front matter at the top of `lines` sets each of its keys to, by the key in lower case. Lines with no front matter have none."
matter(lines) = begin
  out = Dict{String,String}()
  (!isempty(lines) && rstrip(lines[1]) == "---") || return out
  for line in @view lines[2:end]
    rstrip(line) == "---" && break
    m = match(r"^([^:#\s-][^:#]*):\s*(.*?)\s*$", line)
    m === nothing || (out[lowercase(strip(m[1]))] = String(strip(m[2], ['"', '\''])))
  end
  out
end

"The post in the file at `path`, whose lines are `lines`"
post(path::AbstractString, lines=readlines(path)) = begin
  said = matter(lines)
  name = splitext(basename(path))[1]
  k = findfirst(l -> startswith(l, "# "), lines)
  title = get(said, "title", "")
  isempty(title) && (title = k === nothing ? name : String(strip(lines[k][3:end])))
  d = something(day(get(said, "date", "")), startswith(name, r"\d{4}-\d") ? day(name) : nothing, Date(Libc.strftime("%Y-%m-%d", mtime(path))))
  Post(String(path), name, title, d, lowercase(get(said, "draft", "")) in ("true", "yes"))
end

"The posts of the blog in `folder`, the newest first: each Markdown file in the folder. A file whose name starts with a dot or an underscore is left out, and so is the page `index.md`."
posts(folder::AbstractString) = begin
  out = Post[]
  for name in readdir(folder)
    (endswith(lowercase(name), ".md") && !startswith(name, '.') && !startswith(name, '_') && lowercase(name) != INDEX) || continue
    path = joinpath(folder, name)
    isfile(path) || continue
    p = try post(path) catch; nothing end   # a file that can't be read is no post
    p === nothing || push!(out, p)
  end
  sort!(out, by=p -> (p.day, p.name), rev=true)
end

"The folder that the site of the blog in `folder` is written into"
site(folder::AbstractString) = joinpath(folder, SITE)

"The page of the site that the post `p` of the blog in `folder` has"
page(folder::AbstractString, p::Post) = joinpath(site(folder), p.name * ".html")

"""
How the post `p` of the blog in `folder` stands: `:draft` for one that stays
out of the site, `:new` for one that the site hasn't got, `:changed` for one
that was saved since the site got it, and `:published`.
"""
standing(folder::AbstractString, p::Post) = begin
  p.draft && return :draft
  made = page(folder, p)
  isfile(made) || return :new
  mtime(p.path) > mtime(made) ? :changed : :published
end

"What a list says of a post that stands as `s`, or \"\" for one that the site has as it is"
words(s::Symbol) = s == :draft ? "a draft" : s == :new ? "not on the site yet" : s == :changed ? "changed since the site got it" : ""

"The day `d` as a post shows it, like 20 November 2026"
long(d::Date) = "$(Dates.day(d)) $(Dates.monthname(d)) $(Dates.year(d))"

"""
The address of the site that GitHub Pages serves for the repository whose
remote is `url`, like `git@github.com:sam/blog.git`. A repository called
`sam.github.io` is served at that name. It's "" for a remote that isn't on GitHub.
"""
address(url::AbstractString) = begin
  m = match(r"github\.com[:/]([\w\-.]+)/([\w\-.]+?)(?:\.git)?/?\s*$", url)
  m === nothing && return ""
  user, repo = m[1], m[2]
  lowercase(repo) == lowercase(user) * ".github.io" ? "https://$repo/" : "https://$(lowercase(user)).github.io/$repo/"
end

"`html` with each link to a Markdown page beside it made a link to that page of the site"
linked(html::AbstractString) = replace(html, r"(href=\"(?![a-zA-Z][a-zA-Z0-9+.-]*:|#|/)[^\"#?]*?)\.md((?:#[^\"]*)?\")" => s"\1.html\2")

"The files of the blog's folder that the page `html` shows or links to, by their paths from that folder: pictures, sounds, videos and the like. A page of the site is none of them."
assets(html::AbstractString) = begin
  out = String[]
  for m in eachmatch(r"(?:src|href)=\"((?![a-zA-Z][a-zA-Z0-9+.-]*:|#|/)[^\"#?]+)\"", html)
    path = replace(String(m[1]), "%20" => " ")
    endswith(lowercase(path), ".html") || path in out || push!(out, path)
  end
  out
end

"The lines of the Markdown that the site's first page is made from: `top`, the lines of the blog's own `index.md` or a heading with the blog's name, and a list of the posts that are no drafts"
index(top, list) = begin
  out = String[String(l) for l in top]
  isempty(out) || isempty(strip(out[end])) || push!(out, "")
  for p in list
    p.draft || push!(out, "- [$(p.title)]($(replace(p.name, " " => "%20")).md), $(long(p.day))")
  end
  out
end

"""
`html`, the page of the post `p`, with a line at its top that leads back to
the first page of the blog called `blog`, and says the post's day. `blog` and
`title` are HTML. `title` is what the browser's tab says. With `heading`, the
title is the page's first heading too, for a post whose text has none.
"""
framed(html::AbstractString, blog::AbstractString, title::AbstractString, p::Post; heading::Bool=false) = begin
  top = "<p style=\"color: #8a7d6b; font-size: 0.85em\"><a href=\"index.html\">← $blog</a> &nbsp;·&nbsp; $(long(p.day))</p>\n" * (heading ? "<h1>$title</h1>\n" : "")
  # The title goes in as it is: it can have a backslash or a dollar sign in it, which a pattern's replacement would read as its own
  a, b = findfirst("<title>", html), findfirst("</title>", html)
  a === nothing || b === nothing || (html = html[1:last(a)] * title * html[first(b):end])
  replace(html, "<body>\n" => "<body>\n" * top, count=1)
end
