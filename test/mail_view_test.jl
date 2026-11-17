# Tests for what the window shows of the email: the list of emails in the
# sidebar, the buttons at the top of an email and of a draft, and the Email
# page of the settings. See "email" in main.jl. Run them with
# `julia -O0 --project=. test/mail_view_test.jl`.
#
# They click and type in windows that aren't on the screen. The email comes
# from test/mail_fake.jl, a pretend email server that runs in this program, so
# they use no network and no real account. Set MAIL_SHOTS to a folder to get a
# picture of each step.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "../mail" => Mail
@use "./mail_fake" => Fake
@use "../main" => K
const px = K.px

const top = mktempdir()
Mail.place[] = joinpath(top, "settings")
Mail.LINGER[] = 0.0   # each look closes its connection at once, so a test never waits for one
Mail.resolver[] = domain -> `/usr/bin/true`   # no test asks the internet who takes a domain's email
Mail.vault[] = Dict{String,String}("you@example.com" => "secret")

email(i; from="Sam Lee <sam@example.com>", subject="Email $i", text="The text of email $i.") =
  "From: $from\nTo: you@example.com\nSubject: $subject\nMessage-ID: <$i@example.com>\n" *
  "Date: Sat, 14 Nov 2026 $(lpad(8 + i ÷ 60, 2, '0')):$(lpad(i % 60, 2, '0')):00 +1100\nContent-Type: text/plain; charset=utf-8\n\n$text\n"

const server = Fake.serve()
const inbox = Fake.folder!(server, "INBOX")
foreach(i -> put!(inbox, email(i), flags=i <= 57 ? ["\\Seen"] : String[]), 1:60)
const sent = Fake.folder!(server, "Sent", flags="\\Sent")
Fake.folder!(server, "Drafts", flags="\\Drafts")
const archive = Fake.folder!(server, "Archive", flags="\\Archive")
const bin = Fake.folder!(server, "Trash", flags="\\Trash")
put!(Fake.folder!(server, "INBOX/Jobs"), email(99, subject="A job"))

const m = Mail.Mailer(Mail.Account(address="you@example.com", name="Jake Example", incoming="127.0.0.1:$(server.port)",
                                   outgoing="127.0.0.1:$(server.smtp)", folder=joinpath(top, "mail"), safe=false, back=0))
const dir = joinpath(top, "mail", "you@example.com", "Inbox")
"Give the mailer its turns, and draw each window, until the mailer has nothing left to do"
settle() = begin
  started = time()
  while true
    Mail.tick!(m)
    foreach(o -> frame(K.window_of(o)), K.editors)
    (Mail.busy(m) || (!isempty(m.jobs) && m.kind === :none)) || break
    time() - started > 30 && error("The mailer was still busy: $(Mail.says(m))")
    sleep(0.001)
  end
end
settle()

"A window on `path` whose email comes from the pretend server"
window(path; size=(1100px, 760px)) = begin
  e = K.build_editor(path)
  e.nodes[:mailer] = m
  w = K.window!(e, title="test", size=size)
  foreach(_ -> frame(w), 1:2)
  e, w
end
const e, w = window(dir)
frames(win=w, n=2) = foreach(_ -> frame(win), 1:n)
at(win, (x, y)) = (win.mouse = typeof(win.mouse)(px(x), px(y)); onmouse(win, MouseMove(Vec2{px}(px(x), px(y)), win)); frames(win))
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
# The frames come first, so that the node is where the last change to the page put it
click(node, win=w) = (frames(win); at(win, middle(rect(node))); at(win, middle(rect(node))); win.keys |= Keys.mouse_left; onkey(win, KeyPress{Keys.mouse_left}(0, win)); win.keys ⊻= Keys.mouse_left; frames(win))
press(win, key, mods...) = begin
  foreach(k -> (win.keys |= k), mods)
  onkey(win, KeyPress{key}(0, win)); onkey(win, KeyRelease{key}(0, win))
  foreach(k -> (win.keys ⊻= k), mods)
  frames(win)
end
typed(win, s) = (foreach(c -> ontype(win, Typed(c, win)), s); frames(win))
rows(o=e) = [o.nodes[(:mail_row, k)].row for k in 1:60 if haskey(o.nodes, (:mail_row, k)) && rect(o.nodes[(:mail_row, k)]) !== nothing]

const shots = get(ENV, "MAIL_SHOTS", "")
"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
"The words that the top bar of the window itself writes"
bar(o=e) = texts(K.describe(o.nodes[:topbar]))
shot(name, win=w) = isempty(shots) || (mkpath(shots); save_png(joinpath(shots, name * ".png"), win))

@testset "the list of emails in the sidebar" begin
  @test e.panel && e.folder == dir && isempty(e.buf.path)   # a folder of emails opens on no email, so that none is marked as read
  list = Mail.rows(dir)
  @test length(list) == 60 && list[1].subject == "Email 60" && list[1].unread && !list[4].unread
  # Only the rows that are in the window are built
  @test haskey(e.nodes, (:mail_row, 1)) && e.nodes[(:mail_row, 1)].row.subject == "Email 60"
  @test !haskey(e.nodes, (:mail_row, 30))
  # A folder that's in the folder is over the emails, with how many of its emails aren't read
  @test haskey(e.nodes, (:mail_folder, joinpath(dir, "Jobs"))) && !haskey(e.nodes, (:mail_folder, joinpath(dir, "files")))
  @test K.mail_brief(e)[1] == "3 not read"
  shot("1-list")
  # A click shows the email, and marks it as read here and on the server
  click(e.nodes[(:mail_row, 2)])
  @test endswith(e.buf.path, "Email 59.eml") && "The text of email 59." in e.buf.lines
  @test !Mail.rows(dir)[2].unread && K.mail_brief(e)[1] == "2 not read"
  # An email is read, and not changed. Nothing that the window does writes to its file, which is the email as the server sent it.
  raw, lines = read(e.buf.path), copy(e.buf.lines)
  @test e.buf.fixed && raw == inbox.notes[59].raw
  K.edit!(e.buf, e.buf.caret, e.buf.caret, "typed")
  K.save!(e.buf)
  @test e.buf.lines == lines && read(e.buf.path) == raw
  # The Mac marks the file as read-only, and the top bar says so. A key that's typed changes nothing.
  @test !iswritable(e.buf.path) && "Read only" in bar()
  # With a wide sidebar, the right end of the top bar stays where it was, in the window
  from_edge() = K.num(K.window_size(e)[1]) - K.num(rect(e.nodes[:mail_delete]).left)
  was, there = e.side, from_edge()
  e.side = 420px
  frames()
  @test K.panel_w(e) > was && from_edge() == there
  e.side = was
  frames()
  typed(w, "abc")
  @test e.buf.lines == lines && K.caretless(e.buf)
  settle()
  @test "\\Seen" in inbox.notes[59].flags && !("\\Seen" in inbox.notes[60].flags)
  # An email has the buttons that answer it and move it. A page that isn't an email has none.
  @test all(haskey(e.nodes, k) for k in (:mail_reply, :mail_reply_all, :mail_forward, :mail_archive, :mail_delete))
  @test !isempty(K.mail_part(e))
  shot("2-email")
  # ⌘] and ⌘[ go down and up the list
  press(w, Keys.right_bracket, Keys.cmd)
  @test endswith(e.buf.path, "Email 58.eml")
  press(w, Keys.left_bracket, Keys.cmd)
  @test endswith(e.buf.path, "Email 59.eml")
  # The list scrolls, and the rows show the emails that are in the window then
  e.files_scroll.offset = 30 * K.MAIL_ROW_H
  frames()
  @test e.nodes[(:mail_row, 1)].row.subject in ("Email 31", "Email 32") && !haskey(e.nodes, (:mail_row, 40))
  e.files_scroll.offset = 0px
  frames()
end

@testset "archive and delete" begin
  click(e.nodes[(:mail_row, 2)])
  click(e.nodes[:mail_archive])
  # The next email shows, and the page is in the archive at once
  @test endswith(e.buf.path, "Email 58.eml") && length(Mail.rows(dir)) == 59
  @test isfile(joinpath(top, "mail", "you@example.com", "Archive", "2026-11-14 0859 Sam Lee - Email 59.eml"))
  press(w, Keys.backspace, Keys.ctrl, Keys.cmd)
  @test endswith(e.buf.path, "Email 57.eml") && length(Mail.rows(dir)) == 58
  settle()
  @test length(inbox.notes) == 58 && length(archive.notes) == 1 && length(bin.notes) == 1
  @test isfile(joinpath(top, "mail", "you@example.com", "Trash", "2026-11-14 0858 Sam Lee - Email 58.eml"))
  # ⌘⇧U marks the email that shows as not read
  press(w, Keys.u, Keys.cmd, Keys.shft)
  @test Mail.rows(dir)[2].unread
  settle()
  @test !("\\Seen" in inbox.notes[57].flags)
end

@testset "an answer, in a window of its own" begin
  click(e.nodes[(:mail_row, 1)])
  @test endswith(e.buf.path, "Email 60.eml")
  press(w, Keys.r, Keys.cmd)
  @test length(K.editors) == 2 && endswith(e.buf.path, "Email 60.eml")   # the email stays in its window
  d = K.editors[2]
  dw = K.window_of(d)
  frames(dw)
  @test dirname(d.buf.path) == joinpath(top, "mail", "you@example.com", "Drafts") && !d.panel && Mail.isdraft(d.buf.lines)
  @test d.buf.lines[2] == "to: Sam Lee <sam@example.com>" && d.buf.lines[4] == "subject: Re: Email 60"
  @test "> The text of email 60." in d.buf.lines
  # The caret is in the empty line over the quote, and the draft has a button that sends it
  @test d.buf.caret == (K.front_matter(d.buf.lines) + 2, 0)
  @test haskey(d.nodes, :mail_send) && !haskey(d.nodes, :mail_reply)
  typed(dw, "Yes please.")
  @test "Yes please." in d.buf.lines
  shot("3-answer", dw)
  press(dw, Keys.enter, Keys.cmd, Keys.shft)
  @test d.nodes[:mail_going] == d.buf.path && Mail.sending(m, d.buf.path)
  @test K.off(d.nodes[:mail_send])   # it can't be sent twice
  settle()
  @test length(server.posted) == 1 && occursin("Yes please.", server.posted[1].raw) && server.posted[1].to == ["sam@example.com"]
  # The window shows the email that was sent, which is in the folder of sent email
  @test dirname(d.buf.path) == joinpath(top, "mail", "you@example.com", "Sent") && !Mail.isdraft(d.buf.lines) && "Yes please." in d.buf.lines
  @test get(d.nodes, :mail_words, ("",))[1] == "Sent"
  shot("4-sent", dw)
  @test length(sent.notes) == 1 && "\\Answered" in inbox.notes[end].flags
  @test Mail.rows(dir)[1].answered
  close(dw)
  @test K.editors == [e]
end

@testset "a new email" begin
  press(w, Keys.n, Keys.cmd, Keys.shft)
  d = K.editors[end]
  dw = K.window_of(d)
  frames(dw)
  @test d !== e && Mail.isdraft(d.buf.lines) && d.buf.caret == (2, 4)
  @test !d.buf.fixed && iswritable(d.buf.path) && !("Read only" in bar(d))   # a draft is a page that you write
  # A draft with no address says so, and isn't sent
  click(d.nodes[:mail_send], dw)
  @test occursin("Write who the email is to", get(d.nodes, :mail_words, ("",))[1]) && !haskey(d.nodes, :mail_going)
  shot("5-no-address", dw)
  typed(dw, "kim@example.com")
  @test d.buf.lines[2] == "to: kim@example.com"
  d.buf.caret = d.buf.anchor = (4, length(d.buf.lines[4]))
  typed(dw, "Hello")
  click(d.nodes[:mail_send], dw)
  settle()
  @test length(server.posted) == 2 && server.posted[2].to == ["kim@example.com"] && occursin("Subject: Hello", server.posted[2].raw)
  # The Drafts folder lists a draft that isn't sent, and its Delete button moves it to the Mac's Trash
  close(dw)
  press(w, Keys.n, Keys.cmd, Keys.shft)
  d = K.editors[end]
  draft = d.buf.path
  close(K.window_of(d))
  K.go_folder!(e, dirname(draft))
  frames()
  @test e.nodes[(:mail_row, 1)].row.draft && e.nodes[(:mail_row, 1)].row.path == draft
  shot("6-drafts")
  K.go_folder!(e, dir)
  frames()
end

@testset "the Email page of the settings" begin
  s, sw = window(joinpath(K.pages_dir[], "email.md"), size=(720px, 1100px))
  empty!(K.problems)
  frames(sw, 3)
  @test isempty(K.problems)
  @test s.nodes[(:mail_field, :address)].text == "you@example.com"
  # Kaydown doesn't know who holds the email of example.com, so the servers show without a click
  @test s.nodes[(:mail_field, :incoming)].text == "127.0.0.1:$(server.port)" && !s.nodes[:mail_form].more && !haskey(s.nodes, :mail_page)
  @test s.nodes[(:mail_field, :password)].hidden && s.nodes[(:mail_field, :password)].placeholder == "Kept in your Keychain"
  @test occursin("Kaydown has", K.mail_news(s))
  shot("7-settings", sw)
  # While emails come, the form has a bar that fills, and says how many have come and how long the rest take.
  # The task here never starts, so the mailer looks busy and does nothing.
  @test K.mail_progress(s, s.nodes[:mail_form], "you@example.com") == () && K.mail_status(s, s.nodes[:mail_form], "you@example.com") == "Connected."
  m.task, m.total, m.left, m.began, m.doing = Task(() -> nothing), 22314, 21114, time() - 600, "Kaydown is getting your email from Inbox."
  frames(sw, 2)
  @test length(K.mail_progress(s, s.nodes[:mail_form], "you@example.com")) == 2 && K.mail_progress(s, s.nodes[:mail_form], "jo@other.example") == ()
  @test K.mail_status(s, s.nodes[:mail_form], "you@example.com") == m.doing && K.mail_brief(s)[1] == "1,200 of 22,314 emails have come"
  @test occursin("1,200 of 22,314 emails have come. The rest take about 3 hours.", K.mail_news(s))
  shot("7-progress", sw)
  # Emails that wait for the next day, because the account got all that its company allows in a day
  m.task, m.total, m.left, m.began, m.doing, m.held = nothing, 0, 0, 0.0, "", 14200
  frames(sw, 2)
  @test occursin("with 14,200 emails still to come. It goes on ", K.mail_status(s, s.nodes[:mail_form], "you@example.com")) && K.mail_brief(s)[1] == "14,200 emails come later"
  m.held = 0
  frames(sw, 2)
  # What Kaydown gets: how far back the emails go, and whether the other folders come. A change is kept with the account.
  @test K.mail_back(s) == 0 && K.mail_rest(s)
  K.mail_back!(s, 12)
  K.mail_rest!(s, false)
  @test (Mail.account().back, Mail.account().rest) == (12, false) && K.mail_back(s) == 12 && !K.mail_rest(s)
  settle()
  K.mail_back!(s, 0)
  K.mail_rest!(s, true)
  settle()
  @test (Mail.account().back, Mail.account().rest) == (0, true) && isempty(m.problem)
  # The page's own settings are under the form. A high window shows them, for a picture.
  if !isempty(shots)
    t, tw = window(joinpath(K.pages_dir[], "email.md"), size=(720px, 2300px))
    frames(tw, 3)
    shot("7-what-it-gets", tw)
    close(tw)
  end
  # The folder that keeps the email is a path whose names you click, with a word beside it that asks for a folder
  place = s.nodes[:mail_place]
  @test place isa K.Breadcrumb && place.folders && place.at == joinpath(top, "mail") && rect(s.nodes[:mail_choose]) !== nothing
  # The email is in a folder of its own in that folder, named for the address
  @test Mail.root(m.account) == joinpath(top, "mail", "you@example.com") && isdir(joinpath(Mail.root(m.account), "Inbox"))
  # A click on an earlier name goes to that folder, and the list under the path has folders only
  write(joinpath(top, "a file.txt"), "x")
  click(place.crumbs[top], sw)
  @test place.at == top && place.open
  @test all(isdir, [r.path for r in values(place.entries)]) && joinpath(top, "mail") in keys(place.entries)
  click(place.entries[joinpath(top, "mail")], sw)
  @test place.at == joinpath(top, "mail")
  place.open = false
  K.list!(place, sw)
  # A folder that the Mac's panel gives becomes the path
  K.mail_folder!(s, "~/Documents/Email/")
  @test place.at == joinpath(homedir(), "Documents", "Email") && K.mail_short(place.at) == "~/Documents/Email" && K.mail_short("/tmp/x") == "/tmp/x"
  K.mail_folder!(s, joinpath(top, "mail"))
  click(s.nodes[:mail_choose], sw)   # a window that isn't on the screen asks nothing
  @test place.at == joinpath(top, "mail")
  # Tab goes from one field of the form to the next, and ⇧Tab back
  click(s.nodes[(:mail_field, :address)], sw)
  @test sw.focus === s.nodes[(:mail_field, :address)]
  press(sw, Keys.tab)
  @test sw.focus === s.nodes[(:mail_field, :name)]
  press(sw, Keys.tab)
  @test sw.focus === s.nodes[(:mail_field, :password)]
  press(sw, Keys.tab, Keys.shft)
  @test sw.focus === s.nodes[(:mail_field, :name)]
  # The button keeps what the fields hold. The password goes to the Keychain, and out of the field.
  s.nodes[(:mail_field, :name)].text = "J. Example"
  s.nodes[(:mail_field, :password)].text = "new secret"
  # Return in a field does what the Connect button does
  click(s.nodes[(:mail_field, :password)], sw)
  press(sw, Keys.enter)
  @test m.account.name == "J. Example" && Mail.secret("you@example.com") == "new secret" && isempty(s.nodes[(:mail_field, :password)].text)
  @test Mail.account().name == "J. Example" && !occursin("new secret", read(Mail.account_file(), String))
  @test isempty(s.nodes[:mail_form].note)
  settle()
  # The server has another password, so the page says that the password is wrong
  frames(sw, 40)
  @test m.kind === :login && occursin("didn't take the password", K.mail_news(s)) && K.mail_status(s, s.nodes[:mail_form], "you@example.com") == m.problem && K.mail_status(s, s.nodes[:mail_form], "jo@other.example") == ""
  shot("8-wrong-password", sw)
  # An address with no account yet: the servers that it most likely has fill the empty fields. The account
  # is one that encrypts, with no password, so that Kaydown asks for the password and connects to nothing.
  m.account.safe = true
  s.nodes[(:mail_field, :address)].text = "jo@gmail.com"
  s.nodes[(:mail_field, :incoming)].text = s.nodes[(:mail_field, :outgoing)].text = ""
  K.mail_folder!(s, joinpath(top, "other"))
  frames(sw)
  # Gmail is known by its address: the form says which password it takes, and has a button for the page that makes one
  @test s.nodes[:mail_page] isa K.Link && s.nodes[:mail_page].url == "https://myaccount.google.com/apppasswords" && rect(s.nodes[:mail_page]) !== nothing
  @test s.nodes[(:mail_field, :password)].placeholder == "An app password from Gmail"
  shot("9-gmail", sw)
  @test s.nodes[:mail_keep] isa K.MailConnect
  click(s.nodes[:mail_keep], sw)
  @test m.account.incoming == "imap.gmail.com:993" && s.nodes[(:mail_field, :outgoing)].text == "smtp.gmail.com:465"
  # The folder that the path names gets a folder for this address
  @test Mail.root(m.account) == joinpath(top, "other", "jo@gmail.com")
  @test occursin("Type the password", s.nodes[:mail_form].note)
  # An app password is typed as Google shows it, in groups of four letters. The spaces don't go to the Keychain.
  s.nodes[(:mail_field, :password)].text = "abcd efgh ijkl mnop"
  # No frame is drawn between this call and the next line but one, so the mailer gets no turn, and nothing connects to Gmail
  K.mail_keep!(s, s.nodes[:mail_form])
  Mail.account!(m, Mail.Account())
  @test Mail.secret("jo@gmail.com") == "abcdefghijklmnop"
  # Kaydown can't sign in to Outlook.com yet, and says so in place of trying
  s.nodes[(:mail_field, :address)].text = "jo@hotmail.com"
  frames(sw)
  @test rect(s.nodes[:mail_keep]) === nothing   # the form has no Connect button for it
  K.mail_keep!(s, s.nodes[:mail_form])
  @test occursin("Microsoft's own sign-in page", s.nodes[:mail_form].note) && !Mail.ready(m.account)
  # The servers follow the address
  @test s.nodes[(:mail_field, :incoming)].text == "outlook.office365.com:993"
  s.nodes[(:mail_field, :address)].text = "jo@yahoo.com"
  frames(sw)
  @test s.nodes[(:mail_field, :incoming)].text == "imap.mail.yahoo.com:993" && s.nodes[:mail_page].url == "https://login.yahoo.com/account/security"
  # The line under the button shows and hides the servers
  click(s.nodes[:mail_more], sw)
  @test s.nodes[:mail_form].more
  shot("10-outlook", sw)
  # An address at a domain of its own, whose email Google takes: Connect waits for the answer, then goes on by itself
  answer = joinpath(top, "answer")
  write(answer, "smithbuilders.example mail is handled by 1 aspmx.l.google.com.\n")
  Mail.resolver[] = domain -> `/bin/cat $answer`
  m.account.safe = true
  s.nodes[(:mail_field, :address)].text = "jo@smithbuilders.example"
  s.nodes[(:mail_field, :incoming)].text = s.nodes[(:mail_field, :outgoing)].text = ""
  click(s.nodes[:mail_keep], sw)
  @test s.nodes[:mail_form].waits && occursin("finding the servers", s.nodes[:mail_form].note)
  waited = time()
  while s.nodes[:mail_form].waits && time() - waited < 5
    frames(sw); sleep(0.01)
  end
  @test m.account.address == "jo@smithbuilders.example" && m.account.incoming == "imap.gmail.com:993"
  @test s.nodes[:mail_page].url == "https://myaccount.google.com/apppasswords" && occursin("Type the password", s.nodes[:mail_form].note)
  Mail.resolver[] = domain -> `/usr/bin/true`
  # Nothing goes to a real server from a test
  Mail.account!(m, Mail.Account())
  close(sw)
end

foreach(o -> close(K.window_of(o)), copy(K.editors))
Fake.stop(server)
