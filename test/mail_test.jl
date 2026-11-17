# Tests for mail.jl: the folder of emails that Kaydown keeps in step with an
# email server. Run them with `julia -O0 --project=. test/mail_test.jl`.
#
# They use no network and no real account. test/mail_fake.jl is a pretend
# email server that runs in this program, and the emails go in a temporary
# folder. The password goes in a Dict, not in the Mac's Keychain.

@use Test: @test, @testset
@use "../mail" => Mail
@use "./mail_fake" => Fake

const top = mktempdir()
Mail.place[] = joinpath(top, "settings")
Mail.LINGER[] = 0.0   # each look closes its connection at once, so a test never waits for one
Mail.resolver[] = domain -> `/usr/bin/true`   # no test asks the internet who takes a domain's email
Mail.vault[] = Dict{String,String}()

email(; from="Sam Lee <sam@example.com>", to="you@example.com", subject="Roof quote", id="<1@example.com>",
      date="Sat, 14 Nov 2026 09:32:00 +1100", text="Hi Jake,\n\nThe quote is attached.", more="") =
  "From: $from\nTo: $to\nSubject: $subject\nMessage-ID: $id\nDate: $date\n$(more)Content-Type: text/plain; charset=utf-8\n\n$text\n"

const ATTACHED = """
From: Kim Wu <kim@example.com>
To: you@example.com
Subject: Plans
Message-ID: <plans@example.com>
Date: Mon, 16 Nov 2026 14:05:00 +1100
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="b1"

--b1
Content-Type: text/plain; charset=utf-8

The plans are attached.
--b1
Content-Type: application/pdf; name="Floor plan.pdf"
Content-Disposition: attachment; filename="Floor plan.pdf"
Content-Transfer-Encoding: base64

JVBERi0xLjQK
--b1--
"""

"Give the mailer its turns until it has nothing left to do"
settle(m; most=30.0) = begin
  started = time()
  while true
    Mail.tick!(m)
    (Mail.busy(m) || (!isempty(m.jobs) && m.kind === :none)) || break
    time() - started > most && error("The mailer was still busy after $most seconds: $(Mail.says(m))")
    sleep(0.001)
  end
  m
end
"Look for new email now, and wait until the look is over"
look(m) = (Mail.check!(m); settle(m))

const made = Ref(0)
"A mailer for the account on the pretend server `s`, with an empty folder of its own"
# The account gets every email, however old, unless a test says how far back it goes. So no test fails as its emails get old.
mailer(s; folder=joinpath(top, "mail-$(made[] += 1)"), back=0, rest=true) = begin
  a = Mail.Account(address="you@example.com", name="Jake Example", incoming="127.0.0.1:$(s.port)", outgoing="127.0.0.1:$(s.smtp)",
                   folder=folder, safe=false, back=back, rest=rest)
  Mail.secret!(a.address, "secret")
  Mail.Mailer(a)
end

# The names of the email files of a folder, and the lines that a window shows for an email or for a draft
names(dir) = sort!(filter(n -> endswith(n, ".eml"), readdir(dir)))
page(path) = Mail.content(path)

@testset "names and servers" begin
  @test Mail.servers("jo@gmail.com") == ("imap.gmail.com:993", "smtp.gmail.com:465")
  @test Mail.servers("jo@icloud.com")[2] == "smtp.mail.me.com:587"
  @test Mail.servers("jo@smith.example") == ("imap.smith.example:993", "smtp.smith.example:465")
  @test Mail.servers("jo") == ("", "")
  @test Mail.endpoint("imap.example.com:143", 993) == ("imap.example.com", 143) && Mail.endpoint("imap.example.com", 993) == ("imap.example.com", 993)
  @test Mail.ready(Mail.Account(address="jo@example.com", incoming="imap.example.com:993"))
  @test !Mail.ready(Mail.Account(address="jo", incoming="imap.example.com:993")) && !Mail.ready(Mail.Account(address="jo@example.com"))
  # A server writes a letter that isn't ASCII in its own way
  @test Mail.plain("Entw&APw-rfe") == "Entwürfe" && Mail.plain("R&AEA-D") == "R@D" && Mail.plain("Tom &- Jerry") == "Tom & Jerry"
  @test Mail.role(Set(["\\sent"]), "Outbox") == :sent && Mail.role(Set{String}(), "Deleted Items") == :trash
  @test Mail.role(Set{String}(), "INBOX") == :inbox && Mail.role(Set{String}(), "Receipts") == :none
  @test Mail.local_path("/m", "INBOX", "/") == "/m/Inbox" && Mail.local_path("/m", "INBOX.Jobs.Roof", ".") == "/m/Inbox/Jobs/Roof"
  @test Mail.local_path("/m", "[Gmail]/All Mail", "/") == "/m/[Gmail]/All Mail" && Mail.local_path("/m", "files", "/") == "/m/files (folder)"
  @test Mail.local_path("/m", "a/b:c", ".") == "/m/a-b-c"
  @test Mail.clean("  Re: what/when?\t", 70, 120) == "Re what when?" && Mail.clean("..hidden", 70, 120) == "hidden"
  @test sizeof(Mail.clean("屋" ^ 100, 70, 120)) <= 120 && length(Mail.clean("a" ^ 100, 30, 60)) == 30
  @test Mail.internal("14-Nov-2026 09:32:00 +1100") == Mail.internal("13-Nov-2026 22:32:00 +0000") && Mail.internal("soon") === nothing
  @test Mail.token("(\\HasNoChildren \\Sent) \"/\" \"Sent Items\"") == ("\\HasNoChildren \\Sent", " \"/\" \"Sent Items\"")
  @test Mail.token(" \"a \\\"b\\\"\" x")[1] == "a \"b\"" && Mail.token(" NIL x") == ("NIL", " x")
  @test Mail.quoted("a \"b\" \\c") == "\"a \\\"b\\\" \\\\c\""
  l = Mail.Letter(7, true, false, true, true, false, false, 1.5e9, "Sam", "you", "A\tB", "<1@x>", "a.md", 1.7e9)
  @test Mail.line(Mail.letter(Mail.line(l))) == Mail.line(l) && Mail.letter(Mail.line(l)).subject == "A B"
  @test Mail.letter("nonsense") === nothing
  @test Mail.marked("Roof", "Re:") == "Re: Roof" && Mail.marked("RE: Roof", "Re:") == "RE: Roof"
  @test Mail.written(["Sam Lee" => "sam@x.com", "" => "b@y.com", "Lee, Sam" => "s@z.com"]) == "Sam Lee <sam@x.com>, b@y.com, \"Lee, Sam\" <s@z.com>"
end

@testset "the email companies" begin
  gmail = Mail.provider("jo@gmail.com")
  @test gmail.name == "Gmail" && gmail.secret === :app && startswith(gmail.page, "https://myaccount.google.com")
  @test Mail.provider("JO@ICloud.com").name == "iCloud" && Mail.provider("jo@bigpond.net.au").secret === :usual
  @test Mail.provider("jo@hotmail.com").secret === :none && Mail.provider("jo@smith.example") === nothing
  @test Mail.logins(Mail.Account(address="jo@icloud.com")) == ["jo@icloud.com", "jo"]
  @test Mail.logins(Mail.Account(address="jo@gmail.com")) == ["jo@gmail.com"] && Mail.logins(Mail.Account(address="jo@icloud.com", user="x")) == ["x"]
  # An address at a domain of its own is known by the servers that take the domain's email
  answer = joinpath(top, "answer")
  write(answer, "smithbuilders.example mail is handled by 1 aspmx.l.google.com.\nsmithbuilders.example mail is handled by 5 alt1.aspmx.l.google.com.\n")
  Mail.resolver[] = domain -> `/bin/cat $answer`
  @test Mail.provider("jo@smithbuilders.example") === nothing
  @test !Mail.lookup!("smithbuilders.example")   # it asks, and doesn't wait
  waited = time()
  while !Mail.lookup!("smithbuilders.example") && time() - waited < 5
    sleep(0.01)
  end
  @test Mail.exchanges["smithbuilders.example"] == ["aspmx.l.google.com", "alt1.aspmx.l.google.com"]
  @test Mail.provider("jo@smithbuilders.example").name == "Gmail" && Mail.servers("jo@smithbuilders.example")[1] == "imap.gmail.com:993"
  # A domain that no company Kaydown knows takes the email of, and one that has no answer
  write(answer, "other.example mail is handled by 10 mx.other.example.\n")
  while !Mail.lookup!("other.example") sleep(0.01) end
  @test Mail.provider("jo@other.example") === nothing && Mail.servers("jo@other.example") == ("imap.other.example:993", "smtp.other.example:465")
  Mail.resolver[] = domain -> `/usr/bin/false`
  while !Mail.lookup!("none.example") sleep(0.01) end
  @test isempty(Mail.exchanges["none.example"]) && Mail.lookup!("not a domain")
  Mail.resolver[] = domain -> `/usr/bin/true`
end

@testset "the account and the password" begin
  a = Mail.Account(address="jo@example.com", name="Jo", incoming="imap.example.com:993", outgoing="smtp.example.com:465", every=10)
  Mail.keep(a)
  b = Mail.account()
  @test (b.address, b.name, b.incoming, b.outgoing, b.every) == ("jo@example.com", "Jo", "imap.example.com:993", "smtp.example.com:465", 10)
  # The password isn't in the settings file
  Mail.secret!("jo@example.com", "hunter2")
  @test Mail.secret("jo@example.com") == "hunter2" && !occursin("hunter2", read(Mail.account_file(), String))
  Mail.secret!("jo@example.com", "")
  @test Mail.secret("jo@example.com") == ""
  # The email goes in a folder that's named for the address: in Mail in your home folder, or in the folder that you chose
  @test Mail.root(a) == joinpath(homedir(), "Mail", "jo@example.com")
  a.folder = "~/Documents"
  @test Mail.base(a) == joinpath(homedir(), "Documents") && Mail.root(a) == joinpath(homedir(), "Documents", "jo@example.com")
end

@testset "the first look" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  put!(inbox, email(), flags=["\\Seen"])
  put!(inbox, ATTACHED)
  put!(inbox, email(from="you@example.com", to="Sam Lee <sam@example.com>", subject="Re: Roof quote", id="<2@example.com>",
                    date="Sat, 14 Nov 2026 10:00:00 +1100", text="Thanks."), flags=["\\Seen", "\\Answered"])
  Fake.folder!(s, "Sent", flags="\\HasNoChildren \\Sent")
  roof = Fake.folder!(s, "Jobs/Roof")
  put!(roof, email(subject="Tiles", id="<3@example.com>"))
  Fake.folder!(s, "Entw&APw-rfe", flags="\\Drafts")
  m = mailer(s)
  settle(m)
  @test isempty(m.problem)
  dir = Mail.root(m.account)
  @test sort(readdir(dir)) == ["Entwürfe", "Inbox", "Jobs", "Sent"] && isdir(joinpath(dir, "Jobs", "Roof"))
  @test names(joinpath(dir, "Inbox")) == ["2026-11-14 0932 Sam Lee - Roof quote.eml", "2026-11-14 1000 to Sam Lee - Re Roof quote.eml",
                                          "2026-11-16 1405 Kim Wu - Plans.eml"]
  # An email is what somebody sent, so the Mac marks its file as read-only. The folder's hidden list isn't marked.
  @test !any(n -> iswritable(joinpath(dir, "Inbox", n)), names(joinpath(dir, "Inbox"))) && iswritable(joinpath(dir, "Inbox", ".email-index"))
  first = page(joinpath(dir, "Inbox", "2026-11-14 0932 Sam Lee - Roof quote.eml"))
  @test first[1:6] == ["---", "from: Sam Lee <sam@example.com>", "to: you@example.com", "date: 14 Nov 2026, 9:32 am", "subject: Roof quote", "---"]
  @test "Hi Jake," in first && "The quote is attached." in first
  # The file is the email as the server sent it, with what was attached inside it
  plans = joinpath(dir, "Inbox", "2026-11-16 1405 Kim Wu - Plans.eml")
  @test read(plans) == inbox.notes[2].raw && !isdir(joinpath(dir, "Inbox", "files"))
  # What a window shows of it links to a copy of the attached file, in Kaydown's cache
  kept = Mail.linked(last(filter(!isempty, page(plans))), dirname(plans))
  @test kept !== nothing && startswith(kept, Mail.cache()) && basename(kept) == "Floor plan.pdf" && read(kept, String) == "%PDF-1.4\n"
  @test read(plans) == inbox.notes[2].raw   # showing it changed nothing
  # The head of the file says what the index says, for a list that reads the files
  @test Mail.fields(Mail.first_lines(plans))[1]["from"] == "Kim Wu <kim@example.com>" && Mail.heading(plans).id == "<plans@example.com>"
  @test Mail.isemail("A.EML") && !Mail.isemail("a.md") && Mail.heading(joinpath(dir, "nothing.eml")) === nothing
  # The index knows each email, and the server's marks. Reading an email left it unread on the server.
  b = Mail.box(joinpath(dir, "Inbox"))
  @test b.role == :inbox && length(b.letters) == 3 && Mail.unread(joinpath(dir, "Inbox")) == 1
  @test [n.flags for n in inbox.notes] == [Set(["\\Seen"]), Set{String}(), Set(["\\Seen", "\\Answered"])]
  @test Mail.box(joinpath(dir, "Sent")).role == :sent && Mail.box(joinpath(dir, "Entwürfe")).role == :drafts
  @test Mail.folder(m, :sent).path == joinpath(dir, "Sent")
  # The list of a folder is newest first, and an email of your own names who it's to
  list = Mail.rows(joinpath(dir, "Inbox"))
  @test [r.subject for r in list] == ["Plans", "Re: Roof quote", "Roof quote"]
  @test [r.who for r in list] == ["Kim Wu", "To Sam Lee", "Sam Lee"] && [r.unread for r in list] == [true, false, false]
  @test list[2].answered && !list[1].draft
  @test occursin("Kaydown has 4 emails", Mail.says(m))

  @testset "the next look" begin
    said = length(s.said)
    look(m)
    # Nothing changed, so no folder was read again
    @test !any(c -> occursin("FETCH", c), s.said[said+1:end])
    put!(inbox, email(subject="Invoice", id="<4@example.com>", date="Tue, 17 Nov 2026 08:00:00 +1100"))
    deleteat!(inbox.notes, 1)                 # another app deleted the first email
    push!(inbox.notes[1].flags, "\\Seen")     # and read the second
    look(m)
    @test names(joinpath(dir, "Inbox")) == ["2026-11-14 1000 to Sam Lee - Re Roof quote.eml", "2026-11-16 1405 Kim Wu - Plans.eml",
                                            "2026-11-17 0800 Sam Lee - Invoice.eml"]
    @test Mail.unread(joinpath(dir, "Inbox")) == 1 && Mail.rows(joinpath(dir, "Inbox"))[1].subject == "Invoice"
    # A file that the Finder deleted comes back
    rm(plans)
    look(m)
    @test isfile(plans) && length(Mail.box(joinpath(dir, "Inbox")).letters) == 3
    # A file that something changed stays when its email goes from the server
    tiles = joinpath(dir, "Jobs", "Roof", "2026-11-14 0932 Sam Lee - Tiles.eml")
    sleep(0.02)
    chmod(tiles, 0o644)   # you took off the mark that makes the file read-only
    write(tiles, read(tiles, String) * "\nMy note.\n")
    empty!(roof.notes)
    look(m)
    @test isfile(tiles) && isempty(Mail.box(dirname(tiles)).letters)
    # The index is read from the disk as it was written
    delete!(Mail.boxes, joinpath(dir, "Inbox"))
    again = Mail.box(joinpath(dir, "Inbox"))
    @test sort([l.file for l in again.letters]) == names(joinpath(dir, "Inbox")) && again.role == :inbox && again.validity == inbox.validity
    # A folder that the server no longer has loses its emails
    filter!(f -> f.name != "Entw&APw-rfe", s.folders)
    look(m)
    @test !isdir(joinpath(dir, "Entwürfe"))
    # When the server numbers a folder's emails again, each one comes again, once
    inbox.validity += 1
    look(m)
    @test length(names(joinpath(dir, "Inbox"))) == 3 && length(Mail.box(joinpath(dir, "Inbox")).letters) == 3
  end
  Fake.stop(s)
end

@testset "what you do to an email" begin
  for can in ("MOVE UIDPLUS SPECIAL-USE", "")
    s = Fake.serve(can=can)
    inbox = Fake.folder!(s, "INBOX")
    foreach(i -> put!(inbox, email(subject="Email $i", id="<$i@example.com>", date="Sat, 14 Nov 2026 09:0$i:00 +1100")), 1:4)
    archive = Fake.folder!(s, "Archive", flags="\\Archive")
    bin = Fake.folder!(s, "Trash", flags="\\Trash")
    m = settle(mailer(s))
    dir = Mail.root(m.account)
    path(i, folder="Inbox") = joinpath(dir, folder, "2026-11-14 090$i Sam Lee - Email $i.eml")
    # Reading
    @test Mail.seen!(m, path(1)) && !Mail.seen!(m, path(1))
    @test Mail.unread(joinpath(dir, "Inbox")) == 3   # at once, before the server knows
    settle(m)
    @test "\\Seen" in inbox.notes[1].flags && !("\\Seen" in inbox.notes[2].flags)
    Mail.seen!(m, path(1), false)
    Mail.mark!(m, path(2), :flagged)
    settle(m)
    @test !("\\Seen" in inbox.notes[1].flags) && "\\Flagged" in inbox.notes[2].flags
    # Archiving moves the page at once, and the email on the server soon
    @test Mail.archive!(m, path(2)) == path(2, "Archive")
    @test isfile(path(2, "Archive")) && !isfile(path(2)) && [r.subject for r in Mail.rows(joinpath(dir, "Archive"))] == ["Email 2"]
    @test !iswritable(path(2, "Archive"))   # a file that's read-only can still be moved, and it's read-only where it goes
    settle(m)
    @test [n.uid for n in inbox.notes] == [1, 3, 4] && length(archive.notes) == 1 && "\\Flagged" in archive.notes[1].flags
    # The next look sees that the page is the page of the server's copy, and gets no second one
    look(m)
    @test names(joinpath(dir, "Archive")) == ["2026-11-14 0902 Sam Lee - Email 2.eml"]
    @test Mail.box(joinpath(dir, "Archive")).letters[1].uid == archive.notes[1].uid && !Mail.box(joinpath(dir, "Archive")).letters[1].waits
    # Deleting moves an email to the Trash, and deletes one that's in the Trash for good
    @test Mail.trash!(m, path(3))
    settle(m)
    look(m)
    @test [n.uid for n in inbox.notes] == [1, 4] && length(bin.notes) == 1 && isfile(path(3, "Trash"))
    @test Mail.trash!(m, path(3, "Trash"))
    @test !isfile(path(3, "Trash"))
    settle(m)
    @test isempty(bin.notes)
    look(m)
    @test isempty(names(joinpath(dir, "Trash"))) && names(joinpath(dir, "Inbox")) == basename.([path(1), path(4)])
    # While the connection stays open, what you do next goes to the server over it, with no new sign-in
    Mail.LINGER[] = 5.0
    look(m)
    logins = s.logins
    Mail.seen!(m, path(1))
    foreach(_ -> (Mail.tick!(m); sleep(0.002)), 1:60)
    @test "\\Seen" in inbox.notes[1].flags && s.logins == logins && !Mail.busy(m) && m.task !== nothing
    Mail.LINGER[] = 0.0
    settle(m)
    foreach(_ -> (Mail.tick!(m); sleep(0.002)), 1:20)
    @test m.task === nothing
    Mail.seen!(m, path(1), false)
    settle(m)
    # A page that isn't an email is left alone
    write(joinpath(dir, "Inbox", "note.md"), "A note of my own")
    @test !Mail.trash!(m, joinpath(dir, "Inbox", "note.md")) && Mail.archive!(m, joinpath(dir, "Inbox", "note.md")) === nothing
    @test isfile(joinpath(dir, "Inbox", "note.md"))
    # When the server says no to a move, the email comes back to where it was
    push!(s.refuse, can == "" ? "UID COPY" : "UID MOVE")
    Mail.archive!(m, path(4))
    settle(m)
    @test occursin("said no", m.problem) && Mail.says(m) == m.problem
    @test isfile(path(4)) && names(joinpath(dir, "Archive")) == ["2026-11-14 0902 Sam Lee - Email 2.eml"]
    look(m)
    @test isempty(m.problem) && isfile(path(4))
    Fake.stop(s)
  end
end

@testset "drafts and sending" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  put!(inbox, email(to="you@example.com, Kim Wu <kim@example.com>", more="Cc: Bo <bo@example.com>\nReply-To: Sam's office <office@example.com>\n"))
  sent = Fake.folder!(s, "Sent", flags="\\Sent")
  Fake.folder!(s, "Drafts", flags="\\Drafts")
  m = settle(mailer(s))
  dir = Mail.root(m.account)
  original = joinpath(dir, "Inbox", "2026-11-14 0932 Sam Lee - Roof quote.eml")
  @test "reply-to: Sam's office <office@example.com>" in page(original)

  # A new draft is a page with front matter that names who it's to
  new = Mail.draft!(m)
  @test dirname(new) == joinpath(dir, "Drafts") && page(new)[1:5] == ["---", "to: ", "cc: ", "subject: ", "---"]
  @test iswritable(new) && !iswritable(original)   # a draft is a page that you write, and an email isn't
  @test Mail.isdraft(page(new)) && !Mail.isdraft(page(original)) && !Mail.isdraft(["# A page"])
  @test Mail.rows(joinpath(dir, "Drafts"))[1].draft && Mail.rows(joinpath(dir, "Drafts"))[1].who == "No one yet"
  @test occursin("Write who the email is to", Mail.send!(m, new))
  write(new, "---\nto: sam@nowhere\nsubject: Hi\n---\n\nHello")
  @test occursin("“sam@nowhere” isn't an email address", Mail.send!(m, new))

  # An answer goes to the address that the email asks for, and quotes the email
  answer = Mail.reply!(m, original)
  lines = page(answer)
  @test lines[1:6] == ["---", "to: Sam's office <office@example.com>", "cc: ", "subject: Re: Roof quote", "in-reply-to: <1@example.com>", "---"]
  @test "On 14 Nov 2026, 9:32 am, Sam Lee wrote:" in lines && "> Hi Jake," in lines && ">" in lines
  everyone = page(Mail.reply!(m, original, all=true))
  @test everyone[2] == "to: Sam's office <office@example.com>" && everyone[3] == "cc: Kim Wu <kim@example.com>, Bo <bo@example.com>"
  onward = page(Mail.forward!(m, original))
  @test onward[2:4] == ["to: ", "cc: ", "subject: Fwd: Roof quote"] && "> From: Sam Lee <sam@example.com>" in onward

  # Sending: the text, a file with it, and someone who gets a copy that the others don't see
  plan = joinpath(top, "Site plan.txt")
  write(plan, "the plan")
  write(answer, join(["---", "to: Sam's office <office@example.com>", "cc: Kim Wu <kim@example.com>", "bcc: quiet@example.com",
                      "subject: Re: Roof quote", "in-reply-to: <1@example.com>", "---", "", "Yes, **go ahead**. Ça va.", "",
                      "[Site plan]($(Mail.escaped(plan)))", "", "> Hi Jake,"], "\n"))
  @test Mail.send!(m, answer) == "" && Mail.sending(m, answer)
  settle(m)
  @test isempty(m.problem) && !isfile(answer) && !Mail.sending(m, answer)
  @test length(s.posted) == 1
  post = s.posted[1]
  @test post.from == "you@example.com" && post.to == ["office@example.com", "kim@example.com", "quiet@example.com"]
  @test occursin("In-Reply-To: <1@example.com>", post.raw) && occursin("Subject: Re: Roof quote", post.raw) && !occursin("quiet@example.com", post.raw)
  @test occursin("From: Jake Example <you@example.com>", post.raw) && occursin("<strong>go ahead</strong>", post.raw)
  @test occursin("Site plan.txt", post.raw) && !occursin(plan, post.raw)
  # The email that went is a file in the folder of sent email, with the file that went with it inside. The
  # draft is gone, and the server's Sent folder got the email.
  out = names(joinpath(dir, "Sent"))
  @test length(out) == 1 && endswith(out[1], "to Sam's office - Re Roof quote.eml")
  @test !iswritable(joinpath(dir, "Sent", out[1]))   # what went can't be changed any more
  copy = page(joinpath(dir, "Sent", out[1]))
  @test copy[2] == "from: Jake Example <you@example.com>" && startswith(copy[5], "date: ") && "Yes, **go ahead**. Ça va." in copy
  went = filter(!isnothing, [Mail.linked(l, joinpath(dir, "Sent")) for l in copy])
  @test length(went) == 1 && basename(went[1]) == "Site plan.txt" && read(went[1], String) == "the plan"
  @test occursin("In-Reply-To: <1@example.com>", read(joinpath(dir, "Sent", out[1]), String)) && !isdir(joinpath(dir, "Sent", "files"))
  @test length(sent.notes) == 1 && "\\Seen" in sent.notes[1].flags
  @test "\\Answered" in inbox.notes[1].flags
  # The next look takes the server's copy as the file that's there, and gets no second one
  look(m)
  @test names(joinpath(dir, "Sent")) == out && Mail.box(joinpath(dir, "Sent")).letters[1].uid == sent.notes[1].uid
  @test Mail.rows(joinpath(dir, "Sent"))[1].who == "To Sam's office" && !Mail.rows(joinpath(dir, "Sent"))[1].unread

  # An address that the server refuses leaves the draft where it is
  bad = Mail.draft!(m, to="ghost@nowhere.invalid", subject="Hello")
  @test Mail.send!(m, bad) == ""
  settle(m)
  @test isfile(bad) && occursin("didn't take the email", m.problem) && length(s.posted) == 1 && isempty(m.jobs)

  # An email goes once, even when Kaydown can't file its page after: here the folder of sent email can't be written to
  once = Mail.draft!(m, to="sam@example.com", subject="Once")
  chmod(joinpath(dir, "Sent"), 0o555)
  @test Mail.send!(m, once) == ""
  settle(m)
  chmod(joinpath(dir, "Sent"), 0o755)
  @test length(s.posted) == 2 && isempty(m.jobs) && occursin("sent your email, but couldn't", m.problem)
  @test !Mail.isdraft(page(once)) && any(startswith("date: "), page(once))
  foreach(_ -> (Mail.tick!(m); sleep(0.001)), 1:50)
  look(m)
  @test length(s.posted) == 2
  Fake.stop(s)
end

@testset "the folders of Gmail" begin
  # Gmail has a folder that holds a copy of every email, and two that only show emails of other folders.
  # It keeps a copy of each email that it sends by itself.
  s = Fake.serve(can="MOVE UIDPLUS SPECIAL-USE X-GM-EXT-1")
  inbox = Fake.folder!(s, "INBOX")
  put!(inbox, email())
  Fake.folder!(s, "[Gmail]", flags="\\Noselect \\HasChildren")
  all = Fake.folder!(s, "[Gmail]/All Mail", flags="\\All")
  put!(all, email(), flags=["\\Seen"])
  put!(all, email(subject="Old", id="<old@example.com>", date="Mon, 2 Nov 2026 10:00:00 +1100"), flags=["\\Seen"])
  put!(Fake.folder!(s, "[Gmail]/Starred", flags="\\Flagged"), email())
  put!(Fake.folder!(s, "[Gmail]/Important", flags="\\Important"), email())
  sent = Fake.folder!(s, "[Gmail]/Sent Mail", flags="\\Sent")
  m = settle(mailer(s))
  dir = Mail.root(m.account)
  @test sort(readdir(joinpath(dir, "[Gmail]"))) == ["All Mail", "Sent Mail"] && Mail.folder(m, :all).path == joinpath(dir, "[Gmail]", "All Mail")
  @test length(names(joinpath(dir, "[Gmail]", "All Mail"))) == 2
  # Archiving takes the email out of the inbox. The folder of every email has its page already.
  page_in = joinpath(dir, "Inbox", "2026-11-14 0932 Sam Lee - Roof quote.eml")
  @test Mail.archive!(m, page_in) == joinpath(dir, "[Gmail]", "All Mail", "2026-11-14 0932 Sam Lee - Roof quote.eml")
  @test !isfile(page_in) && length(names(joinpath(dir, "[Gmail]", "All Mail"))) == 2
  settle(m)
  @test isempty(inbox.notes) && any(c -> occursin("UID MOVE 1 \"[Gmail]/All Mail\"", c), s.said)
  # Kaydown gives Gmail's folder of sent email no copy of what it sends
  draft = Mail.draft!(m, to="sam@example.com", subject="Hi")
  @test dirname(draft) == joinpath(dir, "Drafts")   # Gmail's own folder of drafts isn't in this test
  Mail.send!(m, draft)
  settle(m)
  @test length(s.posted) == 1 && isempty(sent.notes) && !any(c -> occursin("APPEND", c), s.said)
  @test length(names(joinpath(dir, "[Gmail]", "Sent Mail"))) == 1 && isempty(m.problem)
  Fake.stop(s)
end

@testset "how far a look has come" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  foreach(i -> put!(inbox, email(subject="Email $i", id="<far$i@example.com>")), 1:40)
  m = mailer(s)
  @test Mail.progress(m) === nothing
  # Turns go to the mailer until some of the emails have come, and not all of them
  started = time()
  while (p = Mail.progress(m); p === nothing || p.come == 0) && time() - started < 30
    Mail.tick!(m)
    sleep(0.001)
  end
  p = Mail.progress(m)
  @test p !== nothing && p.total == 40 && 0 < p.come < 40 && p.come + m.left == 40
  @test Mail.says(m) == "Kaydown is getting your email from Inbox. $(p.come) of 40 emails have come."
  settle(m)
  @test Mail.progress(m) === nothing && m.total == 0 && occursin("Kaydown has 40 emails", Mail.says(m))
  # How long the rest take, once enough emails have come to tell
  @test Mail.counted((come=1200, total=48300, left=7000.0)) == "1,200 of 48,300 emails have come. The rest take about 2 hours."
  @test Mail.counted((come=0, total=1, left=nothing)) == "0 of 1 email has come."
  @test [Mail.lasting(t) for t in (20, 600, 3500, 9000)] == ["about a minute", "about 10 minutes", "about an hour", "about 2 hours"]
  Fake.stop(s)
end

@testset "the inbox first, and how far back" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  sent = Fake.folder!(s, "Sent", flags="\\Sent")
  jobs = Fake.folder!(s, "Jobs")
  old = "3-Feb-2019 10:00:00 +1100"
  put!(inbox, email(subject="Old", id="<old1@example.com>"), came=old)
  foreach(i -> put!(inbox, email(subject="New $i", id="<new$i@example.com>"), came=Mail.imapday(time() - 86400i) * " 10:00:00 +1100"), 1:3)
  put!(sent, email(subject="Old sent", id="<old2@example.com>"), came=old)
  put!(sent, email(subject="New sent", id="<new4@example.com>"), came=Mail.imapday(time()) * " 10:00:00 +1100")
  foreach(i -> put!(jobs, email(subject="Job $i", id="<job$i@example.com>"), came=Mail.imapday(time()) * " 10:00:00 +1100"), 1:12)
  have(folder) = length(names(joinpath(Mail.root(m.account), folder)))
  # An account that goes back a year, and gets the inbox only
  m = mailer(s, back=12, rest=false)
  settle(m)
  @test (have("Inbox"), have("Sent"), have("Jobs")) == (3, 0, 0) && occursin("Kaydown has 3 emails", Mail.says(m))
  @test any(c -> occursin("UID SEARCH SINCE $(Mail.imapday(time() - 12 * Mail.MONTH))", c), s.said)
  # A look that finds nothing new asks for nothing
  asked = length(s.said)
  look(m)
  @test !any(c -> occursin("SEARCH", c) || occursin("BODY", c), s.said[asked+1:end])
  # With the other folders too: the whole inbox was asked for before any other folder's emails
  m.account.rest = true
  empty!(s.said)
  Mail.account!(m, m.account)
  settle(m)
  @test (have("Inbox"), have("Sent"), have("Jobs")) == (3, 1, 12)
  # An account that goes back further gets the older emails, and one that goes back less keeps them
  m.account.back = 0
  Mail.account!(m, m.account)
  settle(m)
  @test (have("Inbox"), have("Sent")) == (4, 2)
  m.account.back = 1
  Mail.account!(m, m.account)
  settle(m)
  @test (have("Inbox"), have("Sent")) == (4, 2)
  # The settings are kept with the account
  Mail.keep(m.account)
  @test (Mail.account().back, Mail.account().rest) == (1, true) && Mail.Account().back == 12 && Mail.Account().rest
  Fake.stop(s)

  # In a new folder, the order: every email of the inbox comes before the first email of another folder
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  jobs = Fake.folder!(s, "Jobs")
  foreach(i -> put!(inbox, email(subject="In $i", id="<in$i@example.com>")), 1:20)
  foreach(i -> put!(jobs, email(subject="Job $i", id="<jb$i@example.com>")), 1:20)
  m = mailer(s)
  settle(m)
  at, bodies = "", String[]
  for c in s.said
    chosen = match(r"(?:SELECT|EXAMINE) \"?([^\"]+)\"?", c)
    chosen === nothing || (at = chosen[1])
    occursin("BODY.PEEK", c) && push!(bodies, at)
  end
  @test unique(bodies) == ["INBOX", "Jobs"] && issorted(bodies) && length(names(joinpath(Mail.root(m.account), "Jobs"))) == 20
  # While the other folders come, the inbox has its look as often as the account looks for new email
  big = Fake.folder!(s, "Plans")
  foreach(i -> put!(big, email(subject="Plan $i", id="<pl$i@example.com>")), 1:450)
  m.account.every = 0
  Mail.check!(m)
  started = time()
  while !(occursin("Plans", m.doing) && Mail.progress(m) !== nothing) && time() - started < 30
    Mail.tick!(m)
    sleep(0.001)
  end
  put!(inbox, email(subject="Just in", id="<justin@example.com>"))
  dir = joinpath(Mail.root(m.account), "Inbox")
  while length(names(dir)) < 21 && Mail.busy(m) && time() - started < 30
    Mail.tick!(m)
    sleep(0.001)
  end
  @test length(names(dir)) == 21 && Mail.busy(m) && m.left > 0   # it came, and the other folder isn't done
  m.account.every = 5
  settle(m)
  @test length(names(joinpath(Mail.root(m.account), "Plans"))) == 450 && isempty(m.problem)
  Fake.stop(s)
end

@testset "the index is made again from the files" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  foreach(i -> put!(inbox, email(subject="Email $i", id="<again$i@example.com>", date="Sat, 14 Nov 2026 09:0$i:00 +1100"),
                    flags=i == 2 ? ["\\Seen"] : String[]), 1:3)
  m = settle(mailer(s))
  dir = joinpath(Mail.root(m.account), "Inbox")
  had = names(dir)
  # The index is lost. A file that isn't one of the folder's emails is in the folder too.
  rm(joinpath(dir, ".email-index"))
  delete!(Mail.boxes, dir)
  write(joinpath(dir, "A stray.eml"), email(subject="Stray", id="<stray@example.com>"))
  chmod(joinpath(dir, had[2]), 0o644)   # one of the files has lost the mark that makes it read-only
  empty!(s.said)
  Mail.account!(m, m.account)
  settle(m)
  b = Mail.box(dir)
  # Each file has its place in the index again, with the server's number and marks, and nothing was got again
  @test [(l.uid, l.seen, l.subject) for l in sort(b.letters, by=l -> l.uid)] == [(1, false, "Email 1"), (2, true, "Email 2"), (3, false, "Email 3")]
  @test sort([l.file for l in b.letters]) == had && names(dir) == sort([had; "A stray.eml"])
  @test !any(n -> iswritable(joinpath(dir, n)), had)   # each file that's an email of the folder is read-only again
  @test !any(c -> occursin("BODY.PEEK[]", c), s.said) && any(c -> occursin("HEADER.FIELDS (MESSAGE-ID)", c), s.said)
  @test [r.subject for r in Mail.rows(dir)] == ["Email 3", "Email 2", "Email 1"] && Mail.unread(dir) == 2
  # A file that's moved out with the Finder comes back, and one that's put back takes its place with no download
  aside = joinpath(top, "aside.eml")
  mv(joinpath(dir, had[1]), aside)
  look(m)
  @test names(dir) == sort([had; "A stray.eml"])
  rm(joinpath(dir, had[1]))
  delete!(Mail.boxes, dir)
  rm(joinpath(dir, ".email-index"))
  mv(aside, joinpath(dir, "Put back.eml"))
  empty!(s.said)
  Mail.account!(m, m.account)
  settle(m)
  @test length(Mail.box(dir).letters) == 3 && "Put back.eml" in [l.file for l in Mail.box(dir).letters] && !any(c -> occursin("BODY.PEEK[]", c), s.said)
  Fake.stop(s)
end

@testset "the Markdown pages of the Kaydown before" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  foreach(i -> put!(inbox, email(subject="Email $i", id="<older$i@example.com>", date="Sat, 14 Nov 2026 09:0$i:00 +1100")), 1:3)
  m = settle(mailer(s))
  dir = joinpath(Mail.root(m.account), "Inbox")
  b = Mail.box(dir)
  # Make the folder what that Kaydown left: a Markdown page for each email, with a folder of its attached files
  for l in b.letters
    rm(joinpath(dir, l.file))
    delete!(b.byfile, l.file)
    l.file = splitext(l.file)[1] * ".md"
    write(joinpath(dir, l.file), "---\nfrom: Sam Lee <sam@example.com>\ndate: 14 Nov 2026, 9:0$(l.uid) am\nsubject: $(l.subject)\n---\n\nAs a page.\n")
    mkpath(joinpath(dir, "files", splitext(l.file)[1]))
    write(joinpath(dir, "files", splitext(l.file)[1], "a.txt"), "attached")
    l.written = mtime(joinpath(dir, l.file))
    b.byfile[l.file] = l
  end
  Mail.save(b)
  # You changed one of the pages
  mine = joinpath(dir, b.byuid[2].file)
  sleep(1.1)   # so that the disk gives the page a later time
  write(mine, read(mine, String) * "\nMy own note.\n")
  empty!(s.said)
  look(m)
  # Each email came again, and is kept as the email itself. The pages are gone, with their folders of files.
  @test length(names(dir)) == 3 && all(l -> Mail.isemail(l.file) && l.uid > 0, b.letters) && length(b.letters) == 3
  @test read(joinpath(dir, b.byuid[1].file)) == inbox.notes[1].raw
  @test filter(n -> endswith(n, ".md"), readdir(dir)) == [basename(mine)] && occursin("My own note.", read(mine, String))   # yours stays, as a page of yours
  @test readdir(joinpath(dir, "files")) == [splitext(basename(mine))[1]]
  # The next look gets nothing again
  empty!(s.said)
  look(m)
  @test !any(c -> occursin("BODY.PEEK", c), s.said)
  Fake.stop(s)
end

@testset "what a company allows in a day" begin
  s = Fake.serve()
  inbox = Fake.folder!(s, "INBOX")
  foreach(i -> put!(inbox, email(subject="Email $i", id="<day$i@example.com>")), 1:40)
  # Gmail's limit is known by the address. The test's account has none, until the test gives it one.
  @test Mail.allowed(Mail.Account(address="jo@gmail.com")) == 2000 << 20 && Mail.allowed(Mail.Account(address="jo@example.com")) === nothing
  Mail.allowance[] = sum(values(Mail.tally()), init=0) + 6000   # room for some of the 40 emails, and not for all
  m = mailer(s)
  settle(m)
  dir = joinpath(Mail.root(m.account), "Inbox")
  have = length(names(dir))
  # The look stopped before the limit. The emails that didn't come wait, and Kaydown says when it goes on.
  @test 0 < have < 40 && m.held == 40 - have && isempty(m.problem)
  @test occursin("Kaydown stopped before that, with $(m.held) emails still to come. It goes on ", Mail.says(m))
  @test m.next >= Mail.resumes() > time() + 23 * 3600
  # The count of the bytes is kept, for when Kaydown opens again
  @test sum(n -> parse(Int, split(n, '\t')[2]), readlines(Mail.hours_file())) == sum(values(Mail.tally()))
  # A look that you ask for gets nothing more while the limit holds
  look(m)
  @test length(names(dir)) == have && m.held == 40 - have
  # When the account can get more, the rest come
  Mail.allowance[] = nothing
  look(m)
  @test length(names(dir)) == 40 && m.held == 0 && occursin("Kaydown has 40 emails", Mail.says(m))
  @test Mail.resuming(time() + 60, now=time())[1:3] == "at " && endswith(Mail.resuming(time() + 86400, now=time()), " tomorrow")
  Fake.stop(s)
end

@testset "when it goes wrong" begin
  s = Fake.serve()
  put!(Fake.folder!(s, "INBOX"), email())
  m = mailer(s)
  Mail.secret!("you@example.com", "wrong")
  settle(m)
  @test m.kind === :login && occursin("didn't take the password", m.problem) && Mail.says(m) == m.problem
  # It doesn't ask again until the account changes
  logins = length(s.said)
  @test Mail.tick!(m) == Inf && length(s.said) == logins
  Mail.secret!("you@example.com", "secret")
  Mail.account!(m, m.account)
  settle(m)
  @test isempty(m.problem) && length(names(joinpath(Mail.root(m.account), "Inbox"))) == 1
  # A folder that this Mac won't let Kaydown read, and a link back to a folder above, don't stop the account
  locked = mkpath(joinpath(Mail.root(m.account), "Locked", "In it"))
  chmod(dirname(locked), 0o000)
  symlink(Mail.base(m.account), joinpath(Mail.root(m.account), "Round"))
  Mail.account!(m, m.account)
  @test sort([basename(b.path) for b in m.all]) == ["Inbox"]
  chmod(dirname(locked), 0o755)
  rm(dirname(locked), recursive=true)
  rm(joinpath(Mail.root(m.account), "Round"))
  # A server that isn't there
  Fake.stop(s)
  sleep(0.05)
  look(m)
  @test m.kind === :network && occursin("couldn't reach 127.0.0.1", m.problem)
  # No password at all
  n = Mail.Mailer(Mail.Account(address="new@example.com", incoming="127.0.0.1:1"))
  Mail.tick!(n)
  @test n.kind === :login && occursin("no password", n.problem)
  @test occursin("no email account yet", Mail.says(Mail.Mailer(Mail.Account())))
  @test Mail.tick!(Mail.Mailer(Mail.Account())) == Inf
end
