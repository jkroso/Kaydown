# A pretend email server, for the tests of mail.jl. It runs in the test's own
# program, on two ports of this Mac: one speaks IMAP, to hold email, and one
# speaks SMTP, to send it. Nothing leaves the Mac.
#
#     s = serve()                               # start it
#     f = folder!(s, "INBOX")                   # give it a folder
#     put!(f, raw, flags=["\\Seen"])            # and an email in the folder
#     s.posted                                  # the emails that were sent through it
#     s.said                                    # each command that came
#     stop(s)
#
# It knows the commands that mail.jl sends, and answers BAD to any other.

@use Sockets: Sockets, listenany, accept, @ip_str, TCPSocket
@use Base64: base64decode

"An email that the server holds"
mutable struct Note
  uid::Int
  flags::Set{String}
  raw::Vector{UInt8}
  came::String   # when it came, as IMAP writes it
end

mutable struct Folder
  name::String
  flags::String     # what LIST says of it, like \Sent
  validity::Int
  next::Int         # the UID of the next email
  notes::Vector{Note}
end

"An email that was sent through the server"
struct Posted
  from::String
  to::Vector{String}
  raw::String
end

mutable struct Server
  folders::Vector{Folder}
  user::String
  password::String
  can::String                  # what it says it can do
  port::Int                    # of IMAP
  smtp::Int                    # of SMTP
  said::Vector{String}         # each IMAP command that came
  posted::Vector{Posted}
  refuse::Vector{String}       # an IMAP command that starts with one of these gets NO
  logins::Int                  # how many times someone signed in
  listeners::Vector{Any}
end

"Start a server. `can` is what it says it can do, like MOVE."
serve(; user="you@example.com", password="secret", can="MOVE UIDPLUS SPECIAL-USE") = begin
  s = Server(Folder[], user, password, can, 0, 0, String[], Posted[], String[], 0, Any[])
  for (field, talk) in ((:port, imap), (:smtp, smtp))
    port, listener = listenany(ip"127.0.0.1", 20000 + rand(1:20000))
    setfield!(s, field, Int(port))
    push!(s.listeners, listener)
    @async while isopen(listener)
      sock = try accept(listener) catch; break end
      @async try
        talk(s, sock)
      catch e
        e isa Base.IOError || e isa EOFError || @warn "The pretend server stopped a connection" exception=(e, catch_backtrace())
      finally
        close(sock)
      end
    end
  end
  s
end

stop(s::Server) = foreach(close, s.listeners)

folder!(s::Server, name; flags="") = begin
  f = Folder(name, flags, 1000 + length(s.folders), 1, Note[])
  push!(s.folders, f)
  f
end

"Put the email `raw` in `f`, and give its UID"
Base.put!(f::Folder, raw; flags=String[], came="14-Nov-2026 09:32:00 +1100") = begin
  push!(f.notes, Note(f.next, Set(String.(flags)), Vector{UInt8}(replace(String(raw), r"\r?\n" => "\r\n")), came))
  (f.next += 1) - 1
end

find(s::Server, name) = (i = findfirst(f -> f.name == name || (uppercase(name) == "INBOX" && f.name == "INBOX"), s.folders); i === nothing ? nothing : s.folders[i])

"The words of a command. A word in quotes can hold spaces, and a list in brackets is one word."
words(text) = begin
  out, i, n = String[], 1, lastindex(text)
  while i <= n
    c = text[i]
    if c == ' '
      i += 1
    elseif c == '"'
      buf = IOBuffer()
      i += 1
      while i <= n && text[i] != '"'
        text[i] == '\\' && (i += 1)
        print(buf, text[i])
        i = nextind(text, i)
      end
      push!(out, String(take!(buf)))
      i += 1
    elseif c == '('
      stop = something(findnext(')', text, i), n)
      push!(out, text[i:stop])
      i = stop + 1
    else
      stop = something(findnext(' ', text, i), n + 1)
      push!(out, text[i:stop-1])
      i = stop
    end
  end
  out
end

"The emails of `f` that the set `text` names by UID, like 3,5:7 or 1:*"
chosen(f::Folder, text) = begin
  top = isempty(f.notes) ? 0 : maximum(n -> n.uid, f.notes)
  number(x) = x == "*" ? top : parse(Int, x)
  ranges = map(split(text, ',')) do part
    ends = number.(split(part, ':'))
    minimum(ends):maximum(ends)
  end
  [n for n in f.notes if any(r -> n.uid in r, ranges)]
end

flagtext(n::Note) = join(sort!(collect(n.flags)), ' ')

const MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
"The year, the month and the day of a date as IMAP writes it, like 14-Nov-2026, with or without a time after it"
day(text) = begin
  d, m, y = split(first(split(text, ' ')), '-')
  (parse(Int, y), findfirst(==(m), MONTHS), parse(Int, d))
end

"Speak IMAP on `sock`"
imap(s::Server, sock) = begin
  say(text) = write(sock, text, "\r\n")
  say("* OK the pretend server is ready")
  open, writes, signed = nothing, false, false
  while true
    text = String(rstrip(readline(sock, keep=true), ['\r', '\n']))
    isempty(text) && eof(sock) && return
    literal = UInt8[]
    size = match(r"\{(\d+)\+?\}$", text)
    if size !== nothing
      endswith(text, "+}") || say("+ go on")
      literal = read(sock, parse(Int, size[1]))
      readline(sock)
    end
    push!(s.said, text)
    w = words(text)
    length(w) >= 2 || (say("* BAD what?"); continue)
    tag, name = w[1], uppercase(w[2])
    name == "UID" && length(w) >= 3 && (name = "UID " * uppercase(w[3]))
    arg(i) = get(w, (startswith(name, "UID ") ? 3 : 2) + i, "")
    ok(more="done") = say("$tag OK $more")
    no(more="no") = say("$tag NO $more")
    if any(r -> startswith(chopprefix(text, tag * " "), r), s.refuse)
      no("the test said to refuse this")
    elseif name == "CAPABILITY"
      say("* CAPABILITY IMAP4rev1 $(s.can)")
      ok()
    elseif name == "LOGIN"
      if arg(1) == s.user && arg(2) == s.password
        signed = true
        s.logins += 1
        ok()
      else
        no("[AUTHENTICATIONFAILED] wrong name or password")
      end
    elseif name == "LOGOUT"
      say("* BYE bye")
      ok()
      return
    elseif name == "NOOP"
      ok()
    elseif !signed
      no("sign in first")
    elseif name == "LIST"
      foreach(f -> say("* LIST ($(isempty(f.flags) ? "\\HasNoChildren" : f.flags)) \"/\" \"$(f.name)\""), s.folders)
      ok()
    elseif name == "CREATE"
      find(s, arg(1)) === nothing ? (folder!(s, arg(1)); ok()) : no("it's there already")
    elseif name == "STATUS"
      f = find(s, arg(1))
      f === nothing && (no("no such folder"); continue)
      unseen = count(n -> !("\\Seen" in n.flags), f.notes)
      say("* STATUS \"$(f.name)\" (MESSAGES $(length(f.notes)) UIDNEXT $(f.next) UIDVALIDITY $(f.validity) UNSEEN $unseen)")
      ok()
    elseif name in ("SELECT", "EXAMINE")
      f = find(s, arg(1))
      f === nothing && (open = nothing; no("no such folder"); continue)
      open, writes = f, name == "SELECT"
      say("* $(length(f.notes)) EXISTS")
      say("* OK [UIDVALIDITY $(f.validity)] the folder's number")
      say("* OK [UIDNEXT $(f.next)] the next email's number")
      ok(writes ? "[READ-WRITE] open" : "[READ-ONLY] open")
    elseif name == "APPEND"
      f = find(s, arg(1))
      f === nothing && (no("[TRYCREATE] no such folder"); continue)
      flags = length(w) >= 5 ? split(strip(w[4], ['(', ')'])) : String[]
      put!(f, literal, flags=flags)
      ok()
    elseif open === nothing
      no("open a folder first")
    elseif name == "UID FETCH"
      items = uppercase(arg(2))
      for n in chosen(open, arg(1))
        seq = findfirst(x -> x === n, open.notes)
        # Only BODY.PEEK leaves an email unread
        occursin("BODY[]", items) && writes && push!(n.flags, "\\Seen")
        parts = ["UID $(n.uid)", "FLAGS ($(flagtext(n)))"]
        occursin("INTERNALDATE", items) && push!(parts, "INTERNALDATE \"$(n.came)\"")
        if occursin("BODY", items)
          write(sock, "* $seq FETCH ($(join(parts, ' ')) BODY[] {$(length(n.raw))}\r\n", n.raw, ")\r\n")
        else
          say("* $seq FETCH ($(join(parts, ' ')))")
        end
      end
      ok()
    elseif name == "UID SEARCH"
      # The one search that mail.jl makes: the emails that came on a day or after it
      uppercase(arg(1)) == "SINCE" || (say("$tag BAD the pretend server only searches by SINCE"); continue)
      say("* SEARCH" * join((" $(n.uid)" for n in open.notes if day(n.came) >= day(arg(2)))))
      ok()
    elseif !writes && name in ("UID STORE", "UID MOVE", "EXPUNGE", "UID EXPUNGE")
      no("the folder is open to read only")
    elseif name == "UID STORE"
      flags = split(strip(arg(3), ['(', ')']))
      for n in chosen(open, arg(1))
        startswith(arg(2), '+') ? union!(n.flags, flags) : startswith(arg(2), '-') ? setdiff!(n.flags, flags) : (n.flags = Set(String.(flags)))
      end
      ok()
    elseif name in ("UID COPY", "UID MOVE")
      to = find(s, arg(2))
      to === nothing && (no("[TRYCREATE] no such folder"); continue)
      (name == "UID MOVE" && !occursin("MOVE", s.can)) && (say("$tag BAD what is MOVE?"); continue)
      for n in chosen(open, arg(1))
        push!(to.notes, Note(to.next, copy(n.flags), n.raw, n.came))
        to.next += 1
        name == "UID MOVE" && filter!(x -> x !== n, open.notes)
      end
      ok()
    elseif name == "EXPUNGE"
      filter!(n -> !("\\Deleted" in n.flags), open.notes)
      ok()
    elseif name == "UID EXPUNGE"
      gone = chosen(open, arg(1))
      filter!(n -> !("\\Deleted" in n.flags && any(x -> x === n, gone)), open.notes)
      ok()
    else
      say("$tag BAD the pretend server doesn't know $name")
    end
  end
end

"Speak SMTP on `sock`"
smtp(s::Server, sock) = begin
  say(text) = write(sock, text, "\r\n")
  say("220 the pretend server is ready")
  from, to = "", String[]
  while true
    text = String(rstrip(readline(sock, keep=true), ['\r', '\n']))
    isempty(text) && eof(sock) && return
    verb = uppercase(first(split(text, ' ')))
    if verb in ("EHLO", "HELO")
      say("250-hello")
      say("250-AUTH PLAIN")
      say("250 8BITMIME")
    elseif verb == "AUTH"
      # The name and the password come with the command, or in the next line when the server asks for them
      parts = split(text, ' ')
      code = length(parts) >= 3 ? parts[3] : (say("334 "); String(rstrip(readline(sock), ['\r', '\n'])))
      given = split(String(base64decode(code)), '\0')
      given[end-1:end] == [s.user, s.password] ? say("235 welcome") : say("535 wrong name or password")
    elseif verb == "MAIL"
      from = String(match(r"<([^>]*)>", text)[1])
      say("250 ok")
    elseif verb == "RCPT"
      address = String(match(r"<([^>]*)>", text)[1])
      endswith(address, "@nowhere.invalid") ? say("550 no such person") : (push!(to, address); say("250 ok"))
    elseif verb == "DATA"
      say("354 go on")
      lines = String[]
      while (l = String(rstrip(readline(sock, keep=true), ['\r', '\n']))) != "."
        push!(lines, startswith(l, "..") ? l[2:end] : l)
      end
      push!(s.posted, Posted(from, copy(to), join(lines, "\r\n") * "\r\n"))
      from, to = "", String[]
      say("250 sent")
    elseif verb == "RSET"
      from, to = "", String[]
      say("250 ok")
    elseif verb == "QUIT"
      say("221 bye")
      return
    else
      say("500 what?")
    end
  end
end
