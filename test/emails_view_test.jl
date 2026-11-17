# Tests for the `email` block of main.jl: the list of the emails with someone,
# in a page. Run them with `julia -O0 --project=. test/emails_view_test.jl`.
# They click in a window that isn't on the screen. The emails are pages that
# the tests write in a folder of their own, so they use no network and no real
# account. Set `KAYDOWN_SHOTS` to a folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../mail" => Mail
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

const top = mktempdir()
Mail.place[] = joinpath(top, "settings")
Mail.vault[] = Dict{String,String}("you@example.com" => "secret")
const m = Mail.Mailer(Mail.Account(address="you@example.com", name="Jake Example", incoming="127.0.0.1:9", outgoing="127.0.0.1:9", folder=joinpath(top, "mail"), safe=false))
m.next = time() + 1e9   # it never looks for new email, so nothing connects
const root = Mail.root(m.account)   # the folder that the account's emails are kept in
const NOON = 1.7948e9   # a time in November 2026

"Write a folder of emails as Kaydown keeps one: a page for each email, and the folder's index"
folder(name, role, emails...) = begin
  dir = joinpath(root, name)
  mkpath(dir)
  b = Mail.Box(dir; server=name, role=role)
  for (uid, (id, from, to, subject, hours, flags)) in enumerate(emails)
    file = "$id.md"
    names(people) = join((first(split(p, " <")) for p in split(people, ", ")), ", ")
    write(joinpath(dir, file), "---\nfrom: $from\nto: $to\nsubject: $subject\ndate: 14 Nov 2026\n---\n\nThe text of $id.\n")
    out = startswith(from, "Jake")
    Mail.add!(b, Mail.Letter(uid, 's' in flags, false, false, out, false, false, NOON + 3600hours, names(from), names(to), subject, "<$id@example.com>", file,
                             mtime(joinpath(dir, file))))
  end
  Mail.save(b)
  dir
end

const ME = "Jake Example <you@example.com>"
const SAM, KIM = "Sam Lee <sam@example.com>", "Kim Park <kim@builders.example>"
const inbox = folder("Inbox", :inbox,
  ("a", SAM, ME, "Roof quote", 1, "s"), ("b", KIM, ME, "Tiles", 2, "s"), ("c", SAM, ME, "Re: Roof quote", 5, ""),
  ("d", "S. Lee <sam@example.com>", ME, "Invoice", 6, "s"))
folder("Sent", :sent, ("e", ME, SAM, "Re: Roof quote", 3, "s"), ("f", ME, KIM, "Re: Tiles", 4, "s"))
folder("All Mail", :all, ("c", SAM, ME, "Re: Roof quote", 5, ""), ("g", SAM, ME, "An old one", -30, "s"))
folder("Trash", :trash, ("h", SAM, ME, "Thrown away", 7, "s"))

const page = joinpath(top, "job.md")
write(page, """
# The roof job

```email
Sam Lee
```

```email
with: sam@example.com
about: roof
```

```email
```

The end.
""")

const e = K.build_editor(page)
e.nodes[:mailer] = m
const w = K.window!(e, title="test", size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
list(n) = e.nodes[(:block, K.EMAIL, page, n)]
shot(name) = haskey(ENV, "KAYDOWN_SHOTS") && save_png(joinpath(ENV["KAYDOWN_SHOTS"], name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
subjects(n) = [(x.who, x.subject) for x in K.emails!(list(n)).rows]

@testset "the list has the emails with a person, newest first" begin
  # The email that's in two folders is listed once, and the one in the trash isn't listed
  @test subjects(1) == [("Sam Lee", "Re: Roof quote"), ("To Sam Lee", "Re: Roof quote"), ("Sam Lee", "Roof quote"), ("Sam Lee", "An old one")]
  @test K.emails!(list(1)).rows[1].unread && !K.emails!(list(1)).rows[2].unread
  @test dirname(K.emails!(list(1)).rows[1].path) == inbox
  # An address finds the emails whose index has another name for the person, and `about` looks at the subject
  frames(3)
  @test subjects(2) == [("Sam Lee", "Re: Roof quote"), ("To Sam Lee", "Re: Roof quote"), ("Sam Lee", "Roof quote")]
  @test K.emails!(list(2)).left == 0
  @test isempty(K.emails!(list(3)).rows) && isempty(list(3).data.with)
  @test any(en -> en.title == "Emails", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Emails", K.INSERTS)
  html = K.page_html(e)
  @test occursin("<strong>4 emails with Sam Lee</strong>", html) && occursin("<td>To Sam Lee</td><td>Re: Roof quote</td>", html)
  shot("emails.png")
end

@testset "an address alone" begin
  i = findfirst(==("about: roof"), e.buf.lines)
  K.edit!(e.buf, (i, 0), (i, length(e.buf.lines[i])), "")
  e.buf.caret = e.buf.anchor = (1, 0); frames(3)
  @test ("S. Lee", "Invoice") in subjects(2) && length(subjects(2)) == 5
end

@testset "the buttons start an email" begin
  drafts = joinpath(root, "Drafts")
  n = length(K.editors)
  click(middle(rect(list(1).parts[(:button, :reply)])))
  made = readdir(drafts)
  @test length(made) == 1 && length(K.editors) == n + 1
  text = read(joinpath(drafts, made[1]), String)
  @test occursin("to: Sam Lee <sam@example.com>", text) && occursin("subject: Re: Roof quote", text) && occursin("> The text of c.", text)
  click(middle(rect(list(2).parts[(:button, :new)])))
  @test length(readdir(drafts)) == 2 && any(f -> occursin("to: sam@example.com", read(joinpath(drafts, f), String)), readdir(drafts))
end

@testset "a click opens the email" begin
  click(middle(rect(list(1).parts[(:row, 3)])))
  @test e.buf.path == joinpath(inbox, "a.md")
end

@testset "a page with no email account" begin
  bare = K.build_editor(page)
  bare.nodes[:mailer] = nothing
  win = Window(bare, size=(900px, 700px))
  foreach(_ -> frame(win), 1:2)
  v = bare.nodes[(:block, K.EMAIL, page, 1)]
  @test occursin("no email account", K.emails!(v).problem) && haskey(v.parts, (:button, :settings))
end
foreach(o -> close(K.window_of(o)), copy(K.editors))
