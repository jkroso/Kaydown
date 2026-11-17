# Email. Kaydown keeps a folder on the Mac that holds every email of an
# account, and has the same folders in it as the email server has. Each email
# is one file:
#
#     ~/Mail/you@example.com/
#       Inbox/
#         2026-11-14 0932 Sam Lee - Roof quote.eml
#       Sent/
#       Drafts/
#         Re Roof quote.md
#
# An .eml file holds the email exactly as the server sent it, with what was
# attached to it inside. So nothing of the email is lost, the file's kind says
# that it's an email, and Mail, Quick Look and Spotlight can read it too.
# `render` makes the lines of a page from the file, for a window to show: the
# file itself is never changed.
#
# A draft is a Markdown page: one whose front matter has `to` and no `date`.
# You write it as you write any page. When Kaydown sends it, the email that
# went is kept as an .eml file in the folder of sent email, and the draft goes.
#
#     m = own()                # the mailer of the app that's running
#     tick!(m)                 # call it in each frame. It gives the seconds until it wants the next call.
#     check!(m)                # look for new email now
#     says(m)                  # a sentence on how far it has got
#     rows(dir)                # what a folder of emails holds, newest first, for a list
#     render(path)             # the email in the file at `path`, as the lines of a page
#     draft!(m)                # a new page to write an email in. `reply!` and `forward!` start one from an email.
#     send!(m, path)           # send the draft at `path`
#     seen!(m, path)           # mark an email as read
#     archive!(m, path)        # move an email to the archive. `trash!` and `move!` move it elsewhere.
#
# The server is the one that's right. An email that's gone from the server
# goes from the folder, and one that the Finder moved or deleted comes back.
# Only the calls above change what the server has.
#
# How it talks to the server. Kaydown reads email with IMAP and sends it with
# SMTP, the two ways that every email server has. libcurl, which comes with
# Julia, makes the connection: it checks the server's certificate, encrypts
# what's sent and signs in. Then this file speaks IMAP over that connection
# itself. Each email is read with BODY.PEEK, which leaves it unread on the
# server. To send an email, libcurl speaks SMTP itself. It waits for the
# server's answer at the end, so that call runs in another thread.
#
# The work is done in a task that runs a little in each frame, when `tick!`
# gives it a turn. It never waits for the server: when nothing has come, it
# gives its turn back. So the window keeps drawing while email comes in.
#
# Each folder has a hidden file, `.email-index`, that lists its emails: the
# server's number for each (its UID), whether it's read, who it's from, its
# subject and the name of its file. The list of a folder is drawn from that
# file, so no email is read to draw it. The index is only a copy of what the
# files and the server say. When it's lost, or a file is put in the folder by
# hand, the next look makes it again: the server says the Message-ID of each
# email, and the file with that Message-ID is that email. See `adopt!`.
#
# The password is in the Mac's Keychain, under "Kaydown email". The rest of
# the account is in the file `email` in Kaydown's folder in
# ~/Library/Application Support.

@use LibCURL...
@use NetworkOptions: ca_roots_path
@use Dates: Dates, DateTime, datetime2unix
@use Libdl
@use "./mime" Part message header addresses sent page compose
@use "./markdown" front_matter
@use "./html" html

"The library that the curl functions are in"
const libcurl = parentmodule(curl_easy_init).libcurl
const INDEX = ".email-index"   # the file of a folder that lists its emails
const FILES = "files"          # the folder in a folder of emails that holds what was attached to them
const TURN = 0.03              # seconds between two turns of the work, while there is some
const SLICE = 0.008            # seconds that one turn can take before the window would stutter
const RETRY = 60.0             # seconds until it tries again after the server couldn't be reached
const QUIET = 90.0             # seconds without a word from the server until the connection counts as broken
const BATCH = 8                # the emails that one request asks for
const SHARE = 200              # the emails of one folder that come before the next folder has its turn
const SERVICE = "Kaydown email"   # what the Keychain calls the password
"Seconds that the connection stays open after the work is done, so that the next thing you do goes to the server at once. A test makes it 0."
const LINGER = Ref(20.0)
const IDLE = 0.25              # seconds between two turns of the work while it only waits for something to do

"A test names a folder of its own here, to keep out of the real one"
const place = Ref("")
"Kaydown's folder for its settings"
home() = isempty(place[]) ? joinpath(homedir(), "Library", "Application Support", "Kaydown") : place[]
account_file() = joinpath(home(), "email")

# --- how much comes in a day -----------------------------------------------------------
#
# Gmail lets one app get 2,500 MB of email in a day. When an app gets more,
# Google stops every email app of the account for up to a day. So Kaydown
# counts the bytes that come, hour by hour, and a look stops getting emails
# when the last 24 hours hold most of what the company allows. It goes on when
# the oldest of those hours is a day old.

"The MB of email that a company lets one app get in a day, by the company's name"
const DAILY = Dict("Gmail" => 2500)
const DAY_SHARE = 0.8   # the part of that which Kaydown uses
"A test puts a number of bytes here, to be what any account can get in a day"
const allowance = Ref{Union{Nothing,Int}}(nothing)
"The bytes that came in each hour, by the hour's number since 1970. Nothing until the file is read."
const hours = Ref{Union{Nothing,Dict{Int,Int}}}(nothing)
hours_file() = joinpath(home(), "email-bytes")

"The bytes of each hour of the last 24. The file is read once, and older hours go."
tally() = begin
  if hours[] === nothing
    hours[] = Dict{Int,Int}()
    for text in (isfile(hours_file()) ? eachline(hours_file()) : ())
      parts = tryparse.(Int, split(text, '\t'))
      length(parts) == 2 && !any(isnothing, parts) && (hours[][parts[1]] = parts[2])
    end
  end
  now = floor(Int, time() / 3600)
  filter!(p -> p[1] > now - 24, hours[])
end

"The bytes that came since the count was last kept"
const unkept = Ref(0)

"Count `n` bytes that came from the server now. The count is kept after every few MB, so that little is lost if Kaydown stops at once."
tally!(n) = begin
  t = tally()
  h = floor(Int, time() / 3600)
  t[h] = get(t, h, 0) + n
  (unkept[] += n) >= 4 << 20 && keep_tally()
  nothing
end

"Keep the count of the bytes, so that it holds when Kaydown opens again"
keep_tally() = try
  unkept[] = 0
  mkpath(home())
  write(hours_file(), join(("$h\t$n\n" for (h, n) in sort!(collect(tally()))), ""))
  nothing
catch
end

"The bytes that the account `a` can get in a day, or nothing when its company sets no limit that Kaydown knows"
allowed(a) = begin
  allowance[] === nothing || return allowance[]
  p = provider(a.address)
  p === nothing || !haskey(DAILY, p.name) ? nothing : round(Int, DAILY[p.name] * DAY_SHARE) << 20
end

"True when the account `a` has got as much email in the last 24 hours as Kaydown lets it"
capped(a) = (most = allowed(a); most !== nothing && sum(values(tally()), init=0) >= most)

"The time when the oldest hour that's counted is a day old, so that the account can get more"
resumes() = (t = tally(); isempty(t) ? time() : (minimum(keys(t)) + 25) * 3600.0)

# --- the account ---------------------------------------------------------------------

"An email account"
Base.@kwdef mutable struct Account
  address::String = ""    # like you@example.com
  name::String = ""       # your name, as the people you write to see it
  user::String = ""       # the name to sign in with, when it isn't the address
  incoming::String = ""   # the server that holds the email and its port, like imap.example.com:993
  outgoing::String = ""   # the server that sends email and its port, like smtp.example.com:465
  folder::String = ""     # where the emails are kept. Empty for a folder named for the address, in ~/Mail.
  every::Int = 5          # minutes from one look for new email to the next
  back::Int = 12          # how many months back the emails that Kaydown gets go. 0 for every email.
  rest::Bool = true       # get the other folders too, once the inbox has come
  safe::Bool = true       # encrypt what's sent. Only a test, with a server on this Mac, turns it off.
end

"""
An email company, and how an account with it connects. `secret` says which
password it takes: `:usual` is the one you sign in to its website with, `:app`
is a password that you make for one app, and `:none` means that Kaydown can't
sign in to it yet.
"""
struct Provider
  name::String                # what people call it, like Gmail
  incoming::String            # the server that holds the email, and its port
  outgoing::String            # the server that sends email, and its port
  secret::Symbol
  page::String                # the web page where you make an app password, or ""
  how::String                 # a sentence or two for the settings page, on the password that it takes
  domains::Vector{String}     # the part after the @ of an address of its own
  exchanges::Vector{String}   # the end of the name of each server that takes the email of a domain that it hosts
end

"The email companies that Kaydown knows"
const PROVIDERS = [
  Provider("Gmail", "imap.gmail.com:993", "smtp.gmail.com:465", :app, "https://myaccount.google.com/apppasswords",
           "Gmail takes an app password, not your usual password: 16 letters that Google makes for one app. " *
           "Your Google account needs 2-Step Verification turned on first. A work or school account may not have app passwords.",
           ["gmail.com", "googlemail.com"], ["google.com", "googlemail.com"]),
  Provider("iCloud", "imap.mail.me.com:993", "smtp.mail.me.com:587", :app, "https://account.apple.com/account/manage",
           "iCloud takes an app-specific password, not your Apple Account password. Make one under Sign-In and Security on Apple's account page.",
           ["icloud.com", "me.com", "mac.com"], ["icloud.com"]),
  Provider("Yahoo", "imap.mail.yahoo.com:993", "smtp.mail.yahoo.com:465", :app, "https://login.yahoo.com/account/security",
           "Yahoo takes an app password, not your usual password. Choose Generate app password on Yahoo's security page.",
           ["yahoo.com", "yahoo.com.au", "yahoo.co.uk", "ymail.com", "rocketmail.com"], ["yahoodns.net"]),
  Provider("AOL", "imap.aol.com:993", "smtp.aol.com:465", :app, "https://login.aol.com/account/security",
           "AOL takes an app password, not your usual password. Choose Generate app password on AOL's security page.",
           ["aol.com"], String[]),
  Provider("Fastmail", "imap.fastmail.com:993", "smtp.fastmail.com:465", :app, "",
           "Fastmail takes an app password, not your usual password. Make one in Fastmail's settings, under Privacy & Security.",
           ["fastmail.com", "fastmail.fm"], ["messagingengine.com"]),
  Provider("Telstra", "imap.telstra.com:993", "smtp.telstra.com:465", :usual, "",
           "Telstra takes the password that you sign in to Telstra Mail with.",
           ["telstra.com", "bigpond.com", "bigpond.net.au"], String[]),
  Provider("Outlook", "outlook.office365.com:993", "smtp-mail.outlook.com:587", :none, "",
           "Outlook.com and Microsoft 365 only let an app sign in through Microsoft's own sign-in page. Kaydown can't do that yet.",
           ["outlook.com", "outlook.com.au", "hotmail.com", "live.com", "live.com.au", "msn.com"], ["outlook.com"]),
  Provider("Proton Mail", "", "", :none, "",
           "Proton Mail only works with other apps through its Bridge app. Kaydown doesn't work with the Bridge yet.",
           ["proton.me", "protonmail.com", "pm.me"], ["protonmail.ch"])]

"The part of an email address after the @, in lower case"
domain(address) = lowercase(String(last(split(strip(address), '@'))))

# --- who takes the email of a domain ---------------------------------------------------------
#
# An address like jo@smithbuilders.com.au doesn't say which company holds its
# email. The internet's list of names does: it gives the servers that take the
# email of each domain (its MX records). A domain whose email goes to
# Google's servers is a Gmail account, so it has Gmail's servers and Gmail's
# kind of password. The Mac's own `host` program asks, in the background.

"The command that asks which servers take the email of a domain. A test puts its own here."
const resolver = Ref{Function}(domain -> `/usr/bin/host -W 3 -t mx $domain`)
"The servers that take the email of each domain that's been asked about"
const exchanges = Dict{String,Vector{String}}()
"The command that's running for each domain that's being asked about, and the file that its answer goes to"
const lookups = Dict{String,Tuple{Base.Process,String}}()

"""
Ask which servers take the email of `domain`, without waiting. It's true once
the answer is in, and `provider` uses it then. Call it again to see whether it is.
"""
lookup!(domain) = begin
  haskey(exchanges, domain) && return true
  occursin(r"^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$", domain) || return true
  if haskey(lookups, domain)
    process, file = lookups[domain]
    process_exited(process) || return false
    text = isfile(file) ? read(file, String) : ""
    rm(file, force=true)
    delete!(lookups, domain)
    exchanges[domain] = [lowercase(String(rstrip(found[1], '.'))) for found in eachmatch(r"mail is handled by \d+ (\S+)", text)]
    return true
  end
  file = tempname()
  try
    lookups[domain] = (run(pipeline(ignorestatus(resolver[](domain)), stdout=file, stderr=devnull), wait=false), file)
    false
  catch
    exchanges[domain] = String[]
    true
  end
end

"""
The company that holds the email of `address`, or nothing when Kaydown doesn't
know it. It's known from the part after the @, or from the servers that take
the email of that domain, once `lookup!` has asked for them.
"""
provider(address) = begin
  d = domain(address)
  i = findfirst(p -> d in p.domains, PROVIDERS)
  i === nothing || return PROVIDERS[i]
  hosts = get(exchanges, d, String[])
  i = findfirst(p -> any(h -> any(x -> h == x || endswith(h, "." * x), p.exchanges), hosts), PROVIDERS)
  i === nothing ? nothing : PROVIDERS[i]
end

"The two servers that an address most likely has: the one that holds its email and the one that sends it"
servers(address) = begin
  d = domain(address)
  occursin('.', d) || return ("", "")
  p = provider(address)
  p === nothing || isempty(p.incoming) ? ("imap.$d:993", "smtp.$d:465") : (p.incoming, p.outgoing)
end

"True when `a` says enough to look for email"
ready(a::Account) = occursin(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", a.address) && !isempty(a.incoming)

"The folder that the account's own folder is in: the one that you chose, or Mail in your home folder"
base(a::Account) = isempty(strip(a.folder)) ? joinpath(homedir(), "Mail") : abspath(expanduser(strip(a.folder)))

"""
The folder that holds the account's emails. It's named for the address, and
it's in `base(a)`. So the folder that you choose can have other things in it,
like your home folder has, and Kaydown only looks in a folder of its own.
"""
root(a::Account) = joinpath(base(a), a.address)

"The server's name and its port, from text like imap.example.com:993"
endpoint(text, usual) = begin
  parts = split(strip(text), ':')
  (String(parts[1]), length(parts) > 1 ? something(tryparse(Int, parts[2]), usual) : usual)
end

"The account that the settings file holds, or one with nothing in it"
account() = begin
  a = Account()
  isfile(account_file()) || return a
  for text in eachline(account_file())
    name, value = (split(text, '=', limit=2)..., "")[1:2]
    name == "address" ? (a.address = value) : name == "name" ? (a.name = value) : name == "user" ? (a.user = value) :
    name == "incoming" ? (a.incoming = value) : name == "outgoing" ? (a.outgoing = value) : name == "folder" ? (a.folder = value) :
    name == "every" ? (a.every = clamp(something(tryparse(Int, value), 5), 1, 1440)) :
    name == "back" ? (a.back = max(0, something(tryparse(Int, value), 12))) : name == "rest" ? (a.rest = value != "false") : nothing
  end
  a
end

"Keep the account in the settings file. The password isn't in it."
keep(a::Account) = begin
  mkpath(home())
  write(account_file(), "address=$(a.address)\nname=$(a.name)\nuser=$(a.user)\nincoming=$(a.incoming)\noutgoing=$(a.outgoing)\n" *
                        "folder=$(a.folder)\nevery=$(a.every)\nback=$(a.back)\nrest=$(a.rest)\n")
  a
end

# --- the password, in the Mac's Keychain ---------------------------------------------------

"A test puts a Dict here, and the passwords go in it. The Keychain is left alone."
const vault = Ref{Union{Nothing,Dict{String,String}}}(nothing)

const SECURITY = "/System/Library/Frameworks/Security.framework/Security"
const CORE = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

"A named value of the Mac's Security or CoreFoundation library, like kSecClass"
named(lib, name) = unsafe_load(Ptr{Ptr{Cvoid}}(Libdl.dlsym(Libdl.dlopen(lib), name)))
cfstring(s) = ccall((:CFStringCreateWithCString, CORE), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, UInt32), C_NULL, s, 0x08000100)
cfdata(bytes) = ccall((:CFDataCreate, CORE), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Clong), C_NULL, bytes, length(bytes))
release(x) = x == C_NULL || ccall((:CFRelease, CORE), Cvoid, (Ptr{Cvoid},), x)

"Call `use` with what the Keychain is asked for: the password of `address`, with `more` keys and values"
asking(use, address, more...) = begin
  made = Ptr{Cvoid}[]
  d = ccall((:CFDictionaryCreateMutable, CORE), Ptr{Cvoid}, (Ptr{Cvoid}, Clong, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, 0,
            Libdl.dlsym(Libdl.dlopen(CORE), :kCFTypeDictionaryKeyCallBacks), Libdl.dlsym(Libdl.dlopen(CORE), :kCFTypeDictionaryValueCallBacks))
  put(key, value) = ccall((:CFDictionarySetValue, CORE), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), d, named(SECURITY, key), value)
  hold(x) = (push!(made, x); x)
  put(:kSecClass, named(SECURITY, :kSecClassGenericPassword))
  put(:kSecAttrService, hold(cfstring(SERVICE)))
  put(:kSecAttrAccount, hold(cfstring(address)))
  foreach(((key, value),) -> put(key, value isa Ptr ? value : hold(value isa String ? cfstring(value) : cfdata(value))), more)
  try
    use(d)
  finally
    foreach(release, made)
    release(d)
  end
end

"The password of `address`, or an empty string when the Keychain has none"
secret(address) = begin
  vault[] === nothing || return get(vault[], address, "")
  (Sys.isapple() && !isempty(address)) || return ""
  asking(address, :kSecReturnData => named(CORE, :kCFBooleanTrue), :kSecMatchLimit => named(SECURITY, :kSecMatchLimitOne)) do query
    found = Ref{Ptr{Cvoid}}(C_NULL)
    ccall((:SecItemCopyMatching, SECURITY), Int32, (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}), query, found) == 0 || return ""
    n = ccall((:CFDataGetLength, CORE), Clong, (Ptr{Cvoid},), found[])
    text = unsafe_string(ccall((:CFDataGetBytePtr, CORE), Ptr{UInt8}, (Ptr{Cvoid},), found[]), n)
    release(found[])
    text
  end
end

"Keep `password` as the password of `address`. An empty one takes the password away. True when the Keychain took it."
secret!(address, password) = begin
  if vault[] !== nothing
    isempty(password) ? delete!(vault[], address) : (vault[][address] = password)
    return true
  end
  (Sys.isapple() && !isempty(address)) || return false
  asking(query -> ccall((:SecItemDelete, SECURITY), Int32, (Ptr{Cvoid},), query), address)
  isempty(password) && return true
  asking(address, :kSecValueData => Vector{UInt8}(password)) do item
    ccall((:SecItemAdd, SECURITY), Int32, (Ptr{Cvoid}, Ptr{Cvoid}), item, C_NULL) == 0
  end
end

# --- a folder of emails and its index ---------------------------------------------------------

"What a folder's index says of one email"
mutable struct Letter
  uid::Int          # the server's number for it in its folder. 0 for a page that the server's folder doesn't have yet.
  seen::Bool        # it's been read
  flagged::Bool
  answered::Bool
  out::Bool         # you sent it
  mine::Bool        # Kaydown sent it, and wrote its page from the draft. It stays even if the server never has a copy.
  waits::Bool       # Kaydown moved it here, and the server's copy hasn't come yet
  at::Float64       # when it was sent, in Unix seconds
  from::String      # who sent it, as a list shows them
  to::String        # who it was sent to
  subject::String
  id::String        # its Message-ID
  file::String      # the name of its page in the folder
  written::Float64  # when Kaydown wrote the file, as the disk tells it. A later time means something changed the file.
end

"A folder of emails"
mutable struct Box
  path::String                    # the folder on the Mac
  server::String                  # its name on the server, as the server writes it
  delimiter::String               # what the server puts between a folder's name and the name of a folder in it
  role::Symbol                    # :inbox, :sent, :drafts, :trash, :junk, :archive, :all, or :none
  validity::Int                   # the server's number for this run of UIDs. When it changes, every UID is new.
  state::String                   # what the server said of the folder when it was last read: how many emails, the next UID and so on
  letters::Vector{Letter}
  byuid::Dict{Int,Letter}
  byfile::Dict{String,Letter}
  dirty::Bool                     # the index file doesn't say what `letters` says
  version::Int                    # goes up with each change, so that a list knows to draw again
  renew::Set{Int}                 # the UIDs of the emails that the look that's running gets again, to keep as .eml files
end

Box(path; server="", delimiter="/", role=:none) =
  Box(path, server, delimiter, role, 0, "", Letter[], Dict{Int,Letter}(), Dict{String,Letter}(), false, 0, Set{Int}())

"Every folder of emails that's been read from the disk, by its path"
const boxes = Dict{String,Box}()

flat(s) = replace(s, r"[\t\r\n]+" => " ")
marks(l::Letter) = join((l.seen ? "s" : "", l.flagged ? "f" : "", l.answered ? "a" : "", l.out ? "o" : "", l.mine ? "l" : "", l.waits ? "w" : ""))
line(l::Letter) = join((l.uid, marks(l), repr(l.at), flat(l.from), flat(l.to), flat(l.subject), flat(l.id), flat(l.file), repr(l.written)), '\t')

"The letter that a line of an index holds, or nothing"
letter(text) = begin
  f = split(text, '\t')
  length(f) == 9 || return nothing
  uid, at, kept = tryparse(Int, f[1]), tryparse(Float64, f[3]), tryparse(Float64, f[9])
  (uid === nothing || at === nothing || kept === nothing) && return nothing
  Letter(uid, 's' in f[2], 'f' in f[2], 'a' in f[2], 'o' in f[2], 'l' in f[2], 'w' in f[2], at, f[4], f[5], f[6], f[7], f[8], kept)
end

"Put `l` in the lists of `b`"
add!(b::Box, l::Letter) = begin
  old = get(b.byfile, l.file, nothing)
  old === nothing || drop!(b, old)
  push!(b.letters, l)
  l.uid > 0 && (b.byuid[l.uid] = l)
  b.byfile[l.file] = l
  b.version += 1
  l
end

"Take `l` out of the lists of `b`. Its page stays."
drop!(b::Box, l::Letter) = begin
  filter!(x -> x !== l, b.letters)
  get(b.byuid, l.uid, nothing) === l && delete!(b.byuid, l.uid)
  get(b.byfile, l.file, nothing) === l && delete!(b.byfile, l.file)
  b.dirty = true
  b.version += 1
  b
end

"""
The folder of emails at `dir`, or nothing when `dir` has no index. The index
is read once. Its last line for an email is the one that counts, since a new
email is added as a line at the end.
"""
box(dir) = begin
  dir = String(rstrip(dir, '/'))
  haskey(boxes, dir) && return boxes[dir]
  file = joinpath(dir, INDEX)
  isfile(file) || return nothing
  b = Box(dir)
  for text in eachline(file)
    if startswith(text, '#')
      name, value = (split(chopprefix(text, "#"), '=', limit=2)..., "")[1:2]
      name == "server" ? (b.server = value) : name == "delimiter" ? (b.delimiter = value) : name == "role" ? (b.role = Symbol(value)) :
      name == "validity" ? (b.validity = something(tryparse(Int, value), 0)) : name == "state" ? (b.state = value) : nothing
    else
      l = letter(text)
      l === nothing && continue
      # A line with a UID that an earlier line has is that email again, as it is now
      old = l.uid > 0 ? get(b.byuid, l.uid, nothing) : nothing
      old === nothing || drop!(b, old)
      add!(b, l)
    end
  end
  b.dirty = false
  # An email file that an older Kaydown wrote, or that came here some other way, is marked now
  foreach(l -> isemail(l.file) && protect!(joinpath(dir, l.file)), b.letters)
  boxes[dir] = b
end

"Write the whole index of `b`"
save(b::Box) = begin
  mkpath(b.path)
  io = IOBuffer()
  println(io, "#server=", b.server, "\n#delimiter=", b.delimiter, "\n#role=", b.role, "\n#validity=", b.validity, "\n#state=", b.state)
  foreach(l -> println(io, line(l)), b.letters)
  # The new file takes the old one's place in one step, so a crash leaves one of the two whole
  write(joinpath(b.path, INDEX * ".new"), take!(io))
  mv(joinpath(b.path, INDEX * ".new"), joinpath(b.path, INDEX), force=true)
  b.dirty = false
  b
end

"Add a line for `l` to the end of the index of `b`, so that it's kept at once"
note(b::Box, l::Letter) = open(io -> println(io, line(l)), joinpath(b.path, INDEX), append=true)

"The folders of emails in `dir` and in the folders in it. A folder of attached files isn't looked in."
nested(dir, out=Box[]) = begin
  # A folder that this Mac won't let Kaydown read has no emails that Kaydown put there
  names = try readdir(dir) catch; return out end
  b = try box(dir) catch; nothing end
  b === nothing || push!(out, b)
  for name in names
    (name == FILES || startswith(name, '.')) && continue
    path = joinpath(dir, name)
    # A link to a folder isn't followed: it can lead back to a folder above this one
    (try !islink(path) && isdir(path) catch; false end) && nested(path, out)
  end
  out
end

"True when the Mac shows `l` as not read: an email that came, not one you wrote"
unread(l::Letter) = !l.seen && !l.out

# --- names -------------------------------------------------------------------------------------

"`s` as part of a file's name: no more than `most` characters and `room` bytes, with nothing that a name can't hold"
clean(s, most, room) = begin
  s = strip(replace(replace(s, r"[/:\\\x00-\x1f\x7f]" => " "), r"\s+" => " "))
  s = String(lstrip(first(s, most), '.'))
  while sizeof(s) > room
    s = String(chop(s))
  end
  String(strip(s))
end

"How a list shows the person `name => address`: their name, or the address when they give none"
shown(person::Pair) = isempty(strip(person.first)) ? String(person.second) : String(strip(person.first))
shown(people::Vector) = isempty(people) ? "" : length(people) == 1 ? shown(people[1]) : "$(shown(people[1])) and $(length(people) - 1) more"

"The time `at` as the start of a file's name, like 2026-11-14 0932"
stamp(at) = Libc.strftime("%Y-%m-%d %H%M", at)

"The time `at` as front matter and lists write it, like 14 Nov 2026, 9:32 am"
longdate(at) = begin
  t = Libc.TmStruct(at)
  hour = t.hour % 12 == 0 ? 12 : t.hour % 12
  Libc.strftime("%-d %b %Y, ", at) * "$hour:$(lpad(t.min, 2, '0')) $(t.hour < 12 ? "am" : "pm")"
end

"A name in `dir` that nothing has yet: `stem` and `ext`, with a number after the stem if that's taken"
spare(dir, stem, ext; taken=name -> false) = begin
  name, n = stem * ext, 1
  while ispath(joinpath(dir, name)) || taken(name)
    name = "$stem $(n += 1)$ext"
  end
  name
end

"The name of a server's folder as people read it. A server writes a letter that isn't ASCII in its own way: modified UTF-7."
plain(name) = replace(name, r"&([^-]*)-" => s -> begin
  code = s[2:end-1]
  isempty(code) && return "&"
  try
    bytes = base64decode_loose(replace(code, ',' => '/'))
    units = [UInt16(bytes[i]) << 8 | bytes[i+1] for i in 1:2:length(bytes)-1]
    transcode(String, units)
  catch
    s
  end
end)

"The bytes of base64 text that has no = at its end"
base64decode_loose(s) = begin
  value(c) = 'A' <= c <= 'Z' ? c - 'A' : 'a' <= c <= 'z' ? c - 'a' + 26 : '0' <= c <= '9' ? c - '0' + 52 : c == '+' ? 62 : c == '/' ? 63 : error("not base64")
  out, bits, held = UInt8[], 0, 0
  for c in s
    held = held << 6 | value(c)
    bits += 6
    bits >= 8 && (bits -= 8; push!(out, UInt8(held >> bits & 0xff)))
  end
  out
end

"What a server's folder is for, from what the server says of it and from its name"
role(flags, name) = begin
  name == "INBOX" && return :inbox
  for (flag, r) in ("\\sent" => :sent, "\\drafts" => :drafts, "\\trash" => :trash, "\\junk" => :junk, "\\archive" => :archive, "\\all" => :all)
    flag in flags && return r
  end
  last = lowercase(name)
  last in ("sent", "sent items", "sent messages", "sent mail") ? :sent : last in ("drafts", "draft") ? :drafts :
  last in ("trash", "deleted items", "deleted messages", "bin") ? :trash : last in ("junk", "spam", "junk e-mail", "junk email") ? :junk :
  last in ("archive", "archives") ? :archive : :none
end

"Where the server's folder `name` is on the Mac, under `top`. `delimiter` is what the server puts between the names of two folders."
local_path(top, name, delimiter) = begin
  parts = isempty(delimiter) ? [name] : split(name, delimiter, keepempty=false)
  names = map(enumerate(parts)) do (i, part)
    part = plain(String(part))
    i == 1 && uppercase(part) == "INBOX" && return "Inbox"
    part = replace(part, r"[/:\\\x00-\x1f]" => "-")
    startswith(part, '.') && (part = "_" * part[2:end])
    # `files` is where a folder keeps what was attached to its emails
    part == FILES ? "$FILES (folder)" : String(part)
  end
  joinpath(top, names...)
end

# --- the connection ------------------------------------------------------------------------

"""
Something went wrong that the settings page says in a sentence. `kind` is
:network when the server couldn't be reached, :login when it didn't take the
password, and :server when it said no to one thing.
"""
struct Trouble <: Exception
  kind::Symbol
  says::String
end

"The work was told to stop: the account changed, or the app is closing"
struct Stopped <: Exception end

"What does the email's work in the background, and what the window asks about it"
mutable struct Mailer
  account::Account
  task::Union{Nothing,Task}
  stop::Bool               # the task stops at its next rest
  jobs::Vector{Any}        # what you did that the server hasn't been told yet
  problem::String          # why the last look failed, or ""
  kind::Symbol             # the kind of that failure, or :none
  next::Float64            # the time of the next look
  checked::Float64         # when a look last finished, or 0
  doing::String            # what the work is doing now, or ""
  left::Int                # the emails that are still to come
  total::Int               # the emails that this look found to get: those that have come and those still to come
  began::Float64           # when this look asked for the first of them, or 0
  held::Int                # the emails that wait, because the account got all that its company allows in a day. 0 when none does.
  changed::Int             # goes up whenever what a window shows of the email may have changed
  turn::Float64            # when the work's turn started
  all::Vector{Box}         # the account's folders
  sent::Vector{String}     # the Message-ID of each email that was sent since the app opened
  again::Bool              # look once more as soon as this look ends: the server said no to something you did
  follows::Bool            # the look that's running, or the next one, is that second look. It leaves the problem to read.
  moved::Dict{String,String}   # where the page of each draft that was sent is now, by the draft's path
  idle::Bool               # the work is done, and the connection waits a while for the next thing you do
end

Mailer(a::Account=account()) = Mailer(a, nothing, false, Any[], "", :none, 0.0, 0.0, "", 0, 0, 0.0, 0, 0.0, 0, Box[], String[], false, false, Dict{String,String}(), false)

"The mailer of the app that's running"
const mine = Ref{Union{Nothing,Mailer}}(nothing)
own() = begin
  mine[] === nothing || return mine[]
  m = Mailer()
  ready(m.account) && (m.all = nested(root(m.account)))
  # While the app is built, this code runs in Julia's own program. The app must read the account again when it opens.
  ccall(:jl_generating_output, Cint, ()) == 1 || (mine[] = m)
  m
end

changed!(m::Mailer) = (m.changed += 1; m)

"Give the turn back to the window. The work goes on in the next frame."
rest(m::Mailer) = begin
  yield()
  m.stop && throw(Stopped())
  m.turn = time()
  nothing
end

"Rest, if this turn has gone on for as long as a frame can spare"
breathe(m::Mailer) = time() - m.turn > SLICE && rest(m)

"A connection to the server that holds the email"
mutable struct Wire
  multi::Ptr{Cvoid}
  easy::Ptr{Cvoid}
  inbox::Vector{UInt8}   # what has come from the server and isn't read yet
  at::Int                # the first byte of it that isn't read
  tag::Int               # the number of the last command
  can::Set{String}       # what the server says it can do
  chosen::String         # the folder that's open, or ""
  writes::Bool           # that folder is open to be changed, not only read
  scratch::Vector{UInt8}
end

set(easy, option, value) = curl_easy_setopt(easy, option, value)

"Tell libcurl where the certificates are that it trusts"
certificates(easy) = begin
  path = ca_roots_path()
  (path === nothing || !ispath(path)) && (path = "/etc/ssl/cert.pem")   # the Mac's own list
  set(easy, isdir(path) ? CURLOPT_CAPATH : CURLOPT_CAINFO, path)
end

"A sentence for libcurl's code `code`, about the server `host`"
why(code, host) =
  code == 67 ? Trouble(:login, "$host didn't take the password. Check the address and the password.") :
  code == 6 ? Trouble(:network, "Kaydown couldn't find the server $host.") :
  code in (7, 28) ? Trouble(:network, "Kaydown couldn't reach $host.") :
  code in (35, 51, 53, 54, 58, 59, 60, 64, 66, 77, 80, 83, 90, 91) ? Trouble(:network, "Kaydown couldn't make a safe connection to $host.") :
  code == 8 ? Trouble(:server, "$host doesn't answer as an email server does. Check the server's name and port.") :
  Trouble(:network, "The connection to $host stopped: $(unsafe_string(curl_easy_strerror(code))).")

"Run libcurl's work on `easy` to its end, a little in each turn. It gives libcurl's code for how it ended."
finish(m::Mailer, multi, easy) = begin
  running, left = Ref{Cint}(0), Ref{Cint}(0)
  while true
    curl_multi_perform(multi, running)
    while (p = Ptr{Cvoid}(curl_multi_info_read(multi, left))) != C_NULL
      # A CURLMsg holds what the message is, the handle it's about, and how that handle's work ended
      unsafe_load(Ptr{Cint}(p)) == 1 && unsafe_load(Ptr{Ptr{Cvoid}}(p + 8)) == Ptr{Cvoid}(easy) && return Int(unsafe_load(Ptr{Cint}(p + 16)))
    end
    rest(m)
  end
end

"The names to sign in with, in the order to try them: the address, and for iCloud the part of it before the @ too"
logins(a::Account) = begin
  isempty(a.user) || return [a.user]
  p = provider(a.address)
  p !== nothing && p.name == "iCloud" ? [a.address, String(first(split(a.address, '@')))] : [a.address]
end

"Connect to the server that holds the email of `a`, and sign in"
connect(m::Mailer, a::Account, password) = begin
  names = logins(a)
  for (i, name) in enumerate(names)
    try
      return connect(m, a, name, password)
    catch e
      (e isa Trouble && e.kind === :login && i < length(names)) || rethrow()
    end
  end
end

connect(m::Mailer, a::Account, name, password) = begin
  host, port = endpoint(a.incoming, 993)
  easy = curl_easy_init()
  # Port 143 starts plain and must turn encrypted before the password goes
  set(easy, CURLOPT_URL, (a.safe && port != 143 ? "imaps" : "imap") * "://$host:$port")
  a.safe && port == 143 && set(easy, CURLOPT_USE_SSL, CURLUSESSL_ALL)
  set(easy, CURLOPT_USERNAME, name)
  set(easy, CURLOPT_PASSWORD, password)
  set(easy, CURLOPT_CONNECT_ONLY, 1)
  set(easy, CURLOPT_NOSIGNAL, 1)
  set(easy, CURLOPT_CONNECTTIMEOUT, 20)
  certificates(easy)
  w = Wire(curl_multi_init(), easy, UInt8[], 1, 0, Set{String}(), "", false, Vector{UInt8}(undef, 1 << 16))
  curl_multi_add_handle(w.multi, easy)
  try
    code = finish(m, w.multi, easy)
    p = provider(a.address)
    # A company that wants a password made for one app says no to your usual one, which is the mistake most people make
    code == 67 && p !== nothing && p.secret === :app &&
      throw(Trouble(:login, "$(p.name) didn't take the password. It takes an app password, not your usual one."))
    code == 0 || throw(why(code, host))
    ask(m, w, "CAPABILITY") do reply
      startswith(reply.text, "* CAPABILITY") && union!(w.can, uppercase.(split(reply.text)[3:end]))
    end
  catch
    close(w)
    rethrow()
  end
  w
end

"""
Close the connection. libcurl can wait for the server as it closes one, so
these calls run in another thread, and the window keeps drawing.
"""
Base.close(w::Wire) = begin
  w.easy == C_NULL && return
  multi, easy = w.multi, w.easy
  w.easy = w.multi = C_NULL
  @threadcall((:curl_multi_remove_handle, libcurl), UInt32, (Ptr{Cvoid}, Ptr{Cvoid}), multi, easy)
  @threadcall((:curl_easy_cleanup, libcurl), Cvoid, (Ptr{Cvoid},), easy)
  @threadcall((:curl_multi_cleanup, libcurl), UInt32, (Ptr{Cvoid},), multi)
  nothing
end

"Read what has come from the server into the inbox. True when something had."
receive!(w::Wire) = begin
  got = 0
  n = Ref{Csize_t}(0)
  while got < 1 << 23
    code = curl_easy_recv(w.easy, w.scratch, length(w.scratch), n)
    code == CURLE_AGAIN && break
    code == 0 || throw(Trouble(:network, "The connection to the email server broke."))
    n[] == 0 && throw(Trouble(:network, "The email server closed the connection."))
    append!(w.inbox, view(w.scratch, 1:Int(n[])))
    got += Int(n[])
  end
  got > 0 && tally!(got)
  got > 0
end

"Send `bytes` to the server"
transmit(m::Mailer, w::Wire, bytes) = begin
  bytes = Vector{UInt8}(bytes)
  at, n, started = 0, Ref{Csize_t}(0), time()
  while at < length(bytes)
    code = GC.@preserve bytes curl_easy_send(w.easy, pointer(bytes, at + 1), length(bytes) - at, n)
    if code == CURLE_AGAIN
      time() - started > QUIET && throw(Trouble(:network, "The email server stopped taking what Kaydown sent."))
      rest(m)
    elseif code != 0
      throw(Trouble(:network, "The connection to the email server broke."))
    else
      at += Int(n[])
      started = time()
    end
  end
end

"""
One thing that the server said: a line of text, with the bytes of each literal
in it. A literal is a run of bytes that the server sends by its length, like
the text of an email. The line has `{n}` where each one was.
"""
struct Reply
  text::String
  data::Vector{Vector{UInt8}}
end

"What the server says next, once all of it has come"
reply(m::Mailer, w::Wire) = begin
  text, data = IOBuffer(), Vector{UInt8}[]
  want, scan, heard = -1, w.at, time()
  while true
    if want >= 0
      if length(w.inbox) - w.at + 1 >= want
        push!(data, w.inbox[w.at:w.at+want-1])
        w.at += want
        want, scan = -1, w.at
        continue
      end
    else
      stop = findnext(==(0x0a), w.inbox, scan)
      if stop !== nothing
        piece = String(w.inbox[w.at:stop-1])
        w.at = stop + 1
        piece = String(rstrip(piece, '\r'))
        write(text, piece)
        size = match(r"\{(\d+)\+?\}$", piece)
        if size === nothing
          # What's read goes, once it's most of what's held
          w.at > 1 << 16 && w.at > length(w.inbox) ÷ 2 && (deleteat!(w.inbox, 1:w.at-1); w.at = 1)
          return Reply(String(take!(text)), data)
        end
        want, scan = parse(Int, size[1]), w.at
        continue
      end
      scan = length(w.inbox) + 1
    end
    if receive!(w)
      heard = time()
      breathe(m)
    else
      time() - heard > QUIET && throw(Trouble(:network, "The email server stopped answering."))
      rest(m)
    end
  end
end

"`s` as IMAP writes a string"
quoted(s) = "\"" * replace(s, "\\" => "\\\\", "\"" => "\\\"") * "\""

"""
Send the command `text` and read what the server says to it. `each` gets every
line that isn't the last one. It returns whether the server said OK, and the
words it said with that. `literal` is sent after the command, once the server
asks for it: the command must end with `{n}`, its length.
"""
command(each, m::Mailer, w::Wire, text; literal=nothing) = begin
  tag = "K$(w.tag += 1)"
  transmit(m, w, "$tag $text\r\n")
  while true
    r = reply(m, w)
    if startswith(r.text, "+") && literal !== nothing
      transmit(m, w, literal)
      transmit(m, w, "\r\n")
      literal = nothing
    elseif startswith(r.text, tag * " ")
      words = split(r.text, ' ', limit=3)
      return (uppercase(get(words, 2, "")) == "OK", String(get(words, 3, "")))
    elseif startswith(r.text, "* BYE")
      throw(Trouble(:network, "The email server closed the connection."))
    else
      each(r)
    end
  end
end

"`command`, and trouble when the server doesn't say OK"
ask(each, m::Mailer, w::Wire, text; kw...) = begin
  ok, said = command(each, m, w, text; kw...)
  ok || throw(Trouble(:server, "The email server said no to $(first(split(text))): $said"))
  said
end
ask(m::Mailer, w::Wire, text; kw...) = ask(_ -> nothing, m, w, text; kw...)

"Open the folder `name` on the server, to read it, or with `writes` to change it. It gives the folder's validity and how many emails it holds."
choose!(m::Mailer, w::Wire, name; writes=false) = begin
  validity, count = 0, 0
  w.chosen = ""
  ask(m, w, (writes ? "SELECT " : "EXAMINE ") * quoted(name)) do r
    v = match(r"\[UIDVALIDITY (\d+)\]", r.text)
    v === nothing || (validity = parse(Int, v[1]))
    c = match(r"^\* (\d+) EXISTS", r.text)
    c === nothing || (count = parse(Int, c[1]))
  end
  w.chosen, w.writes = name, writes
  (validity, count)
end

"The words of an IMAP list like `(\\Seen \\Answered)`, or of a quoted string, at the start of `s`, and the rest of `s`"
token(s) = begin
  s = lstrip(s)
  isempty(s) && return ("", s)
  if s[1] == '('
    stop = something(findfirst(')', s), lastindex(s))
    return (String(s[2:prevind(s, stop)]), s[nextind(s, stop):end])
  elseif s[1] == '"'
    out, i = IOBuffer(), 2
    while i <= lastindex(s) && s[i] != '"'
      s[i] == '\\' && (i = nextind(s, i))
      i <= lastindex(s) && print(out, s[i])
      i = nextind(s, i)
    end
    return (String(take!(out)), i < lastindex(s) ? s[nextind(s, i):end] : "")
  end
  stop = something(findfirst(' ', s), lastindex(s) + 1)
  (String(s[1:prevind(s, stop)]), stop > lastindex(s) ? "" : s[stop:end])
end

"The server's folders: for each, what the server says of it, its delimiter and its name"
folders(m::Mailer, w::Wire) = begin
  out = Tuple{Set{String},String,String}[]
  ask(m, w, "LIST \"\" \"*\"") do r
    startswith(r.text, "* LIST ") || return
    flags, more = token(chopprefix(r.text, "* LIST "))
    delimiter, more = token(more)
    name, _ = token(more)
    # A name with odd characters comes as a literal
    occursin(r"^\{\d+\+?\}$", name) && !isempty(r.data) && (name = String(copy(r.data[1])))
    flags = Set(lowercase.(split(flags)))
    # Gmail's Starred and Important hold no email of their own: each email in them is in another folder too
    any(in(flags), ("\\noselect", "\\nonexistent", "\\flagged", "\\important")) ||
      push!(out, (flags, uppercase(delimiter) == "NIL" ? "" : delimiter, name))
  end
  out
end

"The time that IMAP writes like 14-Nov-2026 09:32:00 +1100, in Unix seconds, or nothing"
internal(text) = begin
  f = match(r"(\d{1,2})-(\w{3})-(\d{4}) (\d\d):(\d\d):(\d\d) ([+-])(\d\d)(\d\d)", text)
  f === nothing && return nothing
  month = findfirst(==(lowercase(f[2])), ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"])
  month === nothing && return nothing
  try
    there = datetime2unix(DateTime(parse(Int, f[3]), month, parse(Int, f[1]), parse(Int, f[4]), parse(Int, f[5]), parse(Int, f[6])))
    there - (f[7] == "-" ? -1 : 1) * (parse(Int, f[8]) * 3600 + parse(Int, f[9]) * 60)
  catch
    nothing
  end
end

# --- pages -------------------------------------------------------------------------------------

"Take the page of `l` away, and what was attached to it. A page that you changed stays, as a page of your own."
unpage!(b::Box, l::Letter) = begin
  path = joinpath(b.path, l.file)
  if isfile(path) && mtime(path) == l.written
    rm(path, force=true)
    # A Markdown page of the Kaydown before this one had its attached files in a folder beside it
    rm(joinpath(b.path, FILES, splitext(l.file)[1]), recursive=true, force=true)
    try rm(joinpath(b.path, FILES)) catch end   # the folder of those folders goes with the last of them
  end
  drop!(b, l)
end

"Keep the bytes of a file that came with the email whose page is `stem`, and give the link to it from the page"
attach!(b::Box, stem, name, bytes) = begin
  dir = joinpath(b.path, FILES, stem)
  mkpath(dir)
  base, ext = splitext(clean(name, 80, 150))
  name = spare(dir, isempty(base) ? "file" : base, ext)
  write(joinpath(dir, name), bytes)
  "$FILES/$stem/$name"
end

"True for the name of a file that holds an email as a server sends one"
isemail(name) = endswith(lowercase(name), ".eml")
"True for the name of a Markdown page: a draft, or an email as the Kaydown before this one kept it"
ispage(name) = endswith(lowercase(name), ".md")

"""
Mark the email file at `path` as a file to read and not to write. An email is
what somebody sent, so no app should change it: Kaydown doesn't, and with the
mark the Mac lets no other app do it by mistake. The file can still be moved
and deleted. A draft is a page that you write, and never gets the mark.
"""
protect!(path) = try iswritable(path) && chmod(path, 0o444) catch end

"""
Keep the email `raw`, which is number `uid` of the folder `b`, as a file, and
put it in the folder's index. The file holds the email as the server sent it,
with what was attached to it, so nothing of the email is lost and any app that
reads email can open it. `flags` are the server's marks on it, and `came` is
when the server got it.
"""
store!(m::Mailer, b::Box, uid, flags, came, raw) = begin
  part = message(raw)
  id = String(strip(header(part, "message-id")))
  seen, flagged, answered = "\\seen" in flags, "\\flagged" in flags, "\\answered" in flags
  # A file that Kaydown moved here, or wrote when it sent the email, is the file of this email already
  if !isempty(id)
    i = findfirst(l -> l.uid == 0 && l.id == id && isfile(joinpath(b.path, l.file)), b.letters)
    if i !== nothing
      l = b.letters[i]
      l.uid, l.seen, l.flagged, l.answered, l.waits = uid, seen, flagged, answered, false
      b.byuid[uid] = l
      b.dirty = true
      b.version += 1
      return l
    end
  end
  at = something(sent(part), came, time())
  from, to = addresses(part, "from"), addresses(part, "to")
  outgoing = !isempty(from) && lowercase(from[1].second) == lowercase(m.account.address)
  who = outgoing ? "to " * shown(to) : shown(from)
  subject = String(strip(header(part, "subject")))
  stem = "$(stamp(at)) $(clean(isempty(who) ? "Nobody" : who, 30, 60)) - $(clean(isempty(subject) ? "No subject" : subject, 70, 120))"
  file = spare(b.path, stem, ".eml", taken=name -> haskey(b.byfile, name))
  path = joinpath(b.path, file)
  write(path, raw)
  protect!(path)
  l = Letter(uid, seen, flagged, answered, outgoing, false, false, at, shown(from), shown(to), subject, id, file, mtime(path))
  add!(b, l)
  note(b, l)
  l
end

# --- an email file, read ---------------------------------------------------------------------
#
# An .eml file is the email. The index of its folder only repeats what the
# file's head says, with the server's number for the email and its marks. So
# Kaydown can make the index again from the files and the server: see `adopt!`.

"""
What the head of the email file at `path` says: who it's from, to and copied
to, its subject, its Message-ID and when it was sent. It's nothing for a file
that can't be read. Only the start of the file is read, so a long email costs
no more than a short one.
"""
heading(path) = try
  bytes = open(io -> read(io, 1 << 17), path)
  # The head ends at the first empty line
  stop = something(findfirst(i -> bytes[i] == 0x0a && (bytes[i+1] == 0x0a || (bytes[i+1] == 0x0d && get(bytes, i + 2, 0x00) == 0x0a)),
                             1:length(bytes)-1), length(bytes))
  part = message(bytes[1:stop])
  (from=addresses(part, "from"), to=addresses(part, "to"), cc=addresses(part, "cc"), answer=addresses(part, "reply-to"),
   subject=String(strip(header(part, "subject"))), id=String(strip(header(part, "message-id"))), at=sent(part))
catch
  nothing
end

"The head of the email file at `path` as the front matter of a page writes it, or no lines for a file that can't be read"
headlines(path) = begin
  h = heading(path)
  h === nothing && return String[]
  lines = ["---", "from: $(flat(written(h.from)))"]
  isempty(h.answer) || h.answer == h.from || push!(lines, "reply-to: $(flat(written(h.answer)))")
  isempty(h.to) || push!(lines, "to: $(flat(written(h.to)))")
  isempty(h.cc) || push!(lines, "cc: $(flat(written(h.cc)))")
  push!(lines, "date: $(longdate(something(h.at, mtime(path))))", "subject: $(flat(h.subject))", "---")
  lines
end

"The folder that holds the files of the emails that were opened, like a PDF that came with one"
cache() = isempty(place[]) ? joinpath(homedir(), "Library", "Caches", "Kaydown", "email") : joinpath(place[], "cache")

"""
The email in the file at `path` as the lines of a page, for a window to show:
front matter that says who it's from and so on, then its text as Markdown,
then a link to each file that came with it. Those files are inside the email,
so a copy of each goes in Kaydown's cache for the links to open. The email's
file isn't changed.
"""
render(path) = begin
  part = message(read(path))
  dir = joinpath(cache(), string(hash(abspath(path)), base=16))
  keep(name, bytes, picture) = begin
    mkpath(dir)
    base, ext = splitext(clean(name, 80, 150))
    file = joinpath(dir, (isempty(base) ? "file" : base) * ext)
    # The same file of the same email is written once
    (isfile(file) && filesize(file) == length(bytes)) || write(file, bytes)
    file
  end
  lines = page(part, keep=keep, at=mtime(path))
  # The address that an answer goes to, when it isn't the sender's
  from, answer = addresses(part, "from"), addresses(part, "reply-to")
  at = findfirst(startswith("from:"), lines)
  !isempty(answer) && at !== nothing && answer != from && insert!(lines, at + 1, "reply-to: " * flat(written(answer)))
  lines
end

"The lines of the file at `path`: of a page as it's written, and of an email as `render` gives them"
content(path) = isemail(path) ? render(path) : String.(split(replace(read(path, String), "\r\n" => "\n"), '\n'))

"""
Give each email file that the index of `b` doesn't know its place in the
index, when it's one of the emails `new` that the server has in the folder.
The server says the Message-ID of each of those, and a file with that
Message-ID is that email. So an index that's lost, or a file that's put back
in its folder, costs no new download. `there` is the server's marks by UID. A
file that Kaydown moved here, or wrote when it sent an email, is matched in
the same way. Each UID that finds its file is taken out of `new`.
"""
adopt!(m::Mailer, w::Wire, b::Box, new, there) = begin
  byid = Dict{String,Any}()   # a letter with no UID yet, or the name of a file and what its head says
  foreach(l -> l.uid == 0 && !isempty(l.id) && isfile(joinpath(b.path, l.file)) && (byid[l.id] = l), b.letters)
  for name in readdir(b.path)
    (isemail(name) && !haskey(b.byfile, name) && !startswith(name, '.')) || continue
    h = heading(joinpath(b.path, name))
    (h === nothing || isempty(h.id) || haskey(byid, h.id)) || (byid[h.id] = (name, h))
    breathe(m)
  end
  isempty(byid) && return
  me = lowercase(m.account.address)
  for some in Iterators.partition(copy(new), 400)
    isempty(byid) && break
    ask(m, w, "UID FETCH $(join(some, ',')) (UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])") do r
      uid = match(r"\bUID (\d+)", r.text)
      (uid === nothing || isempty(r.data)) && return
      uid = parse(Int, uid[1])
      id = match(r"(?i)^message-id:\s*(\S.*?)\s*$"m, replace(String(copy(last(r.data))), r"\r?\n[ \t]+" => " "))
      found = id === nothing ? nothing : get(byid, String(id[1]), nothing)
      (found === nothing || !haskey(there, uid) || haskey(b.byuid, uid)) && return
      flags = there[uid]
      seen, flagged, answered = "\\seen" in flags, "\\flagged" in flags, "\\answered" in flags
      if found isa Letter
        found.uid, found.seen, found.flagged, found.answered, found.waits = uid, seen, flagged, answered, false
        b.byuid[uid] = found
        b.version += 1
      else
        name, h = found
        path = joinpath(b.path, name)
        protect!(path)
        out = !isempty(h.from) && lowercase(h.from[1].second) == me
        add!(b, Letter(uid, seen, flagged, answered, out, false, false, something(h.at, mtime(path)), shown(h.from), shown(h.to),
                       h.subject, h.id, name, mtime(path)))
      end
      delete!(byid, String(id[1]))
      filter!(!=(uid), new)
      b.dirty = true
      breathe(m)
    end
  end
  nothing
end

# --- the look for new email ------------------------------------------------------------------

"The folders that the server has, as folders on the Mac. A folder that the server no longer has loses its emails."
folders!(m::Mailer, w::Wire) = begin
  top = root(m.account)
  mkpath(top)
  now = Box[]
  for (flags, delimiter, name) in folders(m, w)
    path = local_path(top, name, delimiter)
    b = something(box(path), Some(nothing))
    if b === nothing
      b = boxes[path] = Box(path)
      b.dirty = true
    end
    part = isempty(delimiter) ? name : String(last(split(name, delimiter)))
    r = role(flags, uppercase(name) == "INBOX" ? "INBOX" : plain(part))
    (b.server, b.delimiter, b.role) == (name, delimiter, r) || (b.dirty = true)
    b.server, b.delimiter, b.role = name, delimiter, r
    b.dirty && save(b)
    push!(now, b)
  end
  for b in nested(top)
    any(x -> x === b, now) && continue
    # The server has no such folder now. Its emails go, and what else is in it stays.
    foreach(l -> l.uid > 0 && unpage!(b, l), copy(b.letters))
    rm(joinpath(b.path, INDEX), force=true)
    delete!(boxes, b.path)
    isempty(readdir(b.path)) && rm(b.path)
  end
  m.all = now
  changed!(m)
  now
end

"What the server says of the folder `b` now, as one line of text. While it says the same, nothing in the folder has changed."
state(m::Mailer, w::Wire, b::Box) = begin
  said = ""
  items = "MESSAGES UIDNEXT UIDVALIDITY UNSEEN" * ("CONDSTORE" in w.can ? " HIGHESTMODSEQ" : "")
  ok, _ = command(m, w, "STATUS $(quoted(b.server)) ($items)") do r
    counts = match(r"\(([^)]*)\)\s*$", r.text)
    startswith(r.text, "* STATUS") && counts !== nothing && (said = String(counts[1]))
  end
  ok ? said : ""
end

"""
Read the folder `b` on the server: which emails it has, and how each is
marked. An email that's gone from the server goes from the Mac. It returns
the UIDs of the emails that the Mac doesn't have yet, newest first.
"""
survey!(m::Mailer, w::Wire, b::Box) = begin
  validity, count = choose!(m, w, b.server)
  if b.validity != validity
    # The server numbered the folder's emails again, so none of the pages is known to be any of them
    foreach(l -> l.uid > 0 && unpage!(b, l), copy(b.letters))
    b.validity, b.dirty = validity, true
  end
  there = Dict{Int,Set{String}}()
  count > 0 && ask(m, w, "UID FETCH 1:* (UID FLAGS)") do r
    uid = match(r"\bUID (\d+)", r.text)
    flags = match(r"FLAGS \(([^)]*)\)", r.text)
    (uid === nothing || flags === nothing) || (there[parse(Int, uid[1])] = Set(lowercase.(split(flags[1]))))
    breathe(m)
  end
  for l in copy(b.letters)
    if l.uid > 0 && !haskey(there, l.uid)
      unpage!(b, l)
    elseif l.uid > 0
      flags = there[l.uid]
      marks = ("\\seen" in flags, "\\flagged" in flags, "\\answered" in flags)
      # A mark that you just made, and that the server hasn't been told of yet, stays
      if marks != (l.seen, l.flagged, l.answered) && !any(j -> j[1] === :mark && j[2] === b && j[3] == l.uid, m.jobs)
        l.seen, l.flagged, l.answered = marks
        b.dirty = true
        b.version += 1
      end
    end
  end
  new = sort!([uid for uid in keys(there) if !haskey(b.byuid, uid)], rev=true)
  # A file of an email that the index doesn't know takes its place in the index, with no new download
  isempty(new) || adopt!(m, w, b, new, there)
  # Only the emails that came in the months that the account goes back. An older email that's here already stays.
  if m.account.back > 0 && !isempty(new)
    recent = Set{Int}()
    ask(m, w, "UID SEARCH SINCE $(imapday(time() - m.account.back * MONTH))") do r
      startswith(r.text, "* SEARCH") && foreach(x -> (n = tryparse(Int, x)) === nothing || push!(recent, n), split(r.text)[3:end])
      breathe(m)
    end
    filter!(in(recent), new)
  end
  # The Kaydown before this one kept each email as a Markdown page. Each of those emails comes again, to be
  # kept as the email itself, however old it is. The new emails come first.
  b.renew = Set(l.uid for l in b.letters if l.uid > 0 && ispage(l.file) && haskey(there, l.uid))
  append!(new, sort!(collect(b.renew), rev=true))
  # A page that Kaydown moved here waits for the server's copy. When the server knows of the move
  # and has nothing new here, no copy is coming: the move failed. The page goes, and the email is
  # still in the folder that it was in.
  if isempty(new) && !any(j -> j[1] === :move && j[4] === b, m.jobs)
    foreach(l -> l.uid == 0 && l.waits && (l.written = mtime(joinpath(b.path, l.file)); unpage!(b, l)), copy(b.letters))
  end
  new
end

const MONTH = 30.44 * 86400   # seconds
const MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
"The day of the time `at` as IMAP writes it, like 17-Nov-2025"
imapday(at) = (t = Libc.TmStruct(at); "$(t.mday)-$(MONTHS[t.month + 1])-$(t.year + 1900)")

"Get the emails `uids` of the folder `b`, and keep each as a file"
fetch!(m::Mailer, w::Wire, b::Box, uids) = begin
  w.chosen == b.server || choose!(m, w, b.server)
  ask(m, w, "UID FETCH $(join(uids, ',')) (UID FLAGS INTERNALDATE BODY.PEEK[])") do r
    uid = match(r"\bUID (\d+)", r.text)
    (uid === nothing || isempty(r.data)) && return
    uid = parse(Int, uid[1])
    uid in uids || return
    had = get(b.byuid, uid, nothing)
    if had !== nothing
      # An email that's here already only comes again to take the place of its Markdown page. The page
      # goes, with the files that were beside it, unless you changed it: then it stays, as a page of yours.
      uid in b.renew || return
      unpage!(b, had)
    end
    delete!(b.renew, uid)
    flags = match(r"FLAGS \(([^)]*)\)", r.text)
    came = match(r"INTERNALDATE \"([^\"]+)\"", r.text)
    try
      store!(m, b, uid, flags === nothing ? Set{String}() : Set(lowercase.(split(flags[1]))),
             came === nothing ? nothing : internal(came[1]), last(r.data))
    catch e
      e isa Union{Stopped,Trouble} && rethrow()
      # One email that can't be written doesn't stop the rest. It's asked for again at the next look.
      @warn "Kaydown couldn't write the page of an email" folder=b.path uid exception=e
    end
    m.left = max(0, m.left - 1)
    changed!(m)
    breathe(m)
  end
end

"""
See which emails of the folders `some` the Mac doesn't have. It returns one
entry for each folder that has some: the folder, the UIDs of those emails with
the newest first, and what the folder said of itself.
"""
gather!(m::Mailer, w::Wire, some) = begin
  due = Tuple{Box,Vector{Int},String}[]
  for b in some
    serve!(m, w)
    # The folder's name, since a folder with many emails takes a while
    m.doing = "Kaydown is looking for new email in $(basename(b.path))."
    changed!(m)
    said = state(m, w, b)
    # A change to how far back the account goes makes every folder say something new
    isempty(said) || (said = "$said back=$(m.account.back)")
    # A page that the Finder took away comes back: its email is asked for again
    lost = [l for l in b.letters if l.uid > 0 && !isfile(joinpath(b.path, l.file))]
    foreach(l -> drop!(b, l), lost)
    breathe(m)
    # A folder that says what it said last time has nothing new, unless it still has emails that didn't come
    fresh = isempty(lost) && !isempty(said) && said == b.state && b.validity != 0 && !any(l -> l.uid > 0 && ispage(l.file), b.letters)
    fresh && continue
    new = survey!(m, w, b)
    b.dirty && save(b)
    isempty(new) ? (b.state = said; save(b)) : push!(due, (b, new, said))
    m.left += length(new)
    m.total += length(new)
    changed!(m)
  end
  due
end

"""
Get the emails that `due` lists. Each folder has its turn before any gets the
rest of its emails. While they come, the folders `often` have a look of their
own as often as the account looks for new email, so that a new email in the
inbox doesn't wait for the other folders. It returns true when it stopped
because the account got all that its company allows in a day.
"""
bring!(m::Mailer, w::Wire, due; often=Box[]) = begin
  m.began == 0 && (m.began = time())
  looked = time()
  full = false
  while !isempty(due) && !full
    for (b, new, said) in copy(due)
      m.doing = "Kaydown is getting your email from $(basename(b.path))."
      for _ in 1:cld(SHARE, BATCH)
        (isempty(new) || (full = capped(m.account))) && break
        serve!(m, w)
        fetch!(m, w, b, splice!(new, 1:min(BATCH, length(new))))
      end
      keep_tally()
      full && break
      if isempty(new)
        b.state = said
        save(b)
        filter!(d -> d[1] !== b, due)
      end
      if !isempty(often) && time() - looked >= 60 * m.account.every
        filter!(d -> !any(o -> o === d[1], often), due)
        prepend!(due, gather!(m, w, often))
        looked = m.checked = time()
        break   # what's new in those folders comes before the rest goes on
      end
    end
  end
  full
end

"""
Look at the folders of the account, and bring the Mac's folders in step with
them. The inbox comes first, whole. Then the other folders come, if the
account gets them, with the newest emails of each folder first.
"""
look!(m::Mailer, w::Wire) = begin
  m.doing = "Kaydown is looking for new email."
  m.left, m.total, m.began = 0, 0, 0.0
  changed!(m)
  all = folders!(m, w)
  # The folder that holds a copy of every email comes last
  order = Dict(:inbox => 1, :drafts => 2, :sent => 3, :none => 4, :archive => 5, :junk => 6, :trash => 7, :all => 8)
  sort!(all, by=b -> (order[b.role], b.server))
  inbox = filter(b -> b.role === :inbox, all)
  full = bring!(m, w, gather!(m, w, inbox))
  others = m.account.rest ? filter(b -> b.role !== :inbox, all) : Box[]
  if !full && !isempty(others)
    # The inbox is here, so Kaydown has looked. The count starts again for the other folders.
    m.checked = time()
    m.left, m.total, m.began = 0, 0, 0.0
    full = bring!(m, w, gather!(m, w, others), often=inbox)
  end
  # The emails that didn't come wait. Their folders say nothing of this look, so the next look asks for them again.
  m.held = full ? m.left : 0
  m.left = m.total = 0
end

# --- what you do to an email -------------------------------------------------------------------

"The folder and the letter of the page at `path`, or nothing when the page isn't an email that the index knows"
locate(path) = begin
  b = box(dirname(path))
  b === nothing && return nothing
  l = get(b.byfile, basename(path), nothing)
  l === nothing ? nothing : (b, l)
end

"The account's folder for `role`, like :trash, or nothing"
folder(m::Mailer, role::Symbol) = begin
  i = findfirst(b -> b.role == role, m.all)
  i === nothing ? nothing : m.all[i]
end

"Tell the server about `job` soon"
job!(m::Mailer, job...) = (push!(m.jobs, job); changed!(m))

"Mark the email at `path` as read, or with `on` false as not read. `mark` is :seen or :flagged."
mark!(m::Mailer, path, mark::Symbol=:seen, on::Bool=true) = begin
  at = locate(path)
  at === nothing && return false
  b, l = at
  getfield(l, mark) == on && return false
  setfield!(l, mark, on)
  b.dirty = true
  b.version += 1
  l.uid > 0 && job!(m, :mark, b, l.uid, mark == :seen ? "\\Seen" : "\\Flagged", on)
  changed!(m)
  true
end
seen!(m::Mailer, path, on::Bool=true) = mark!(m, path, :seen, on)

"""
Move the email at `path` to the folder `to`, on the Mac at once and on the
server soon. It returns the page's new path, or nothing when the page isn't an
email.
"""
move!(m::Mailer, path, to::Box) = begin
  at = locate(path)
  at === nothing && return nothing
  b, l = at
  b === to && return path
  stem = splitext(l.file)[1]
  # Gmail's All Mail has a page of every email already. Then this page goes, and the email leaves this folder on the server.
  there = isempty(l.id) ? nothing : findfirst(x -> x.id == l.id && x.uid > 0, to.letters)
  if there !== nothing && l.uid > 0 && mtime(path) == l.written
    uid = l.uid
    unpage!(b, l)
    save(b)
    job!(m, :move, b, uid, to)
    changed!(m)
    return joinpath(to.path, to.letters[there].file)
  end
  file = spare(to.path, stem, splitext(l.file)[2], taken=name -> haskey(to.byfile, name))
  mkpath(to.path)
  changed = mtime(path) != l.written   # something changed the file
  mv(path, joinpath(to.path, file))
  # A Markdown page of the Kaydown before this one has its attached files in a folder beside it
  kept = joinpath(b.path, FILES, stem)
  if isdir(kept)
    mkpath(joinpath(to.path, FILES))
    mv(kept, joinpath(to.path, FILES, splitext(file)[1]), force=true)
    # The page's links to those files name the folder by the page's name
    file == l.file || relink!(joinpath(to.path, file), stem, splitext(file)[1])
  end
  uid = l.uid
  drop!(b, l)
  moved = Letter(0, l.seen, l.flagged, l.answered, l.out, l.mine, uid > 0, l.at, l.from, l.to, l.subject, l.id, file,
                 changed ? 0.0 : mtime(joinpath(to.path, file)))
  add!(to, moved)
  save(b); save(to)
  uid > 0 && job!(m, :move, b, uid, to)
  changed!(m)
  joinpath(to.path, file)
end

"`path` as a link writes it: a space, and a bracket that would end the link, are written as codes"
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")
"The path that a link wrote with `escaped`"
unescaped(path) = replace(path, "%20" => ' ', "%28" => '(', "%29" => ')')

"Make the links of the page at `path` to its attached files name the folder `new`, not `old`"
relink!(path, old, new) = write(path, replace(read(path, String), escaped("$FILES/$old/") => escaped("$FILES/$new/")))

"Move the email at `path` out of the inbox, to the folder that keeps old email. It returns the page's new path."
archive!(m::Mailer, path) = begin
  to = something(folder(m, :archive), folder(m, :all), Some(nothing))
  if to === nothing
    # The server gets a folder named Archive when the job runs
    to = Box(joinpath(root(m.account), "Archive"), server="Archive", role=:archive)
    boxes[to.path] = to
    save(to)
    push!(m.all, to)
    job!(m, :create, to)
  end
  move!(m, path, to)
end

"""
Move the email at `path` to the server's Trash. An email that's in the Trash
already is deleted for good, and so is one on a server that has no Trash. It
returns false, and does nothing, when the page isn't an email that the server
has: a draft, or a page of your own.
"""
trash!(m::Mailer, path) = begin
  at = locate(path)
  at === nothing && return false
  b, l = at
  if l.uid == 0 && !l.waits
    # Kaydown wrote this page, and the server has no copy of it. The index forgets it, and the page is yours.
    drop!(b, l)
    save(b)
    changed!(m)
    return false
  end
  bin = folder(m, :trash)
  (bin === nothing || b === bin) || return (move!(m, path, bin); true)
  uid = l.uid
  drop!(b, l)
  rm(path, force=true)
  rm(joinpath(b.path, FILES, splitext(l.file)[1]), recursive=true, force=true)
  save(b)
  uid > 0 && job!(m, :delete, b, uid)
  changed!(m)
  true
end

"Tell the server everything that you did and that it hasn't been told"
serve!(m::Mailer, w::Wire) = begin
  isempty(m.jobs) && return
  was = (w.chosen, w.writes)
  while !isempty(m.jobs)
    job = m.jobs[1]
    try
      run!(m, w, job)
    catch e
      # When the server can't be reached, the job waits for the next connection. Any other failure ends the job:
      # doing it again would fail again, and a job is never done twice.
      (e isa Stopped || (e isa Trouble && e.kind !== :server)) && rethrow()
      e isa Trouble || @warn "Kaydown couldn't tell the email server what you did" job=job[1] exception=(e, catch_backtrace())
      # Another look, straight after this one, puts the Mac's folders back in step with the server
      m.problem, m.kind, m.again = e isa Trouble ? e.says : "Kaydown couldn't tell the email server what you did: $(sprint(showerror, e))", :server, true
      foreach(x -> x isa Box && (x.state = ""), job)
    end
    popfirst!(m.jobs)
    changed!(m)
  end
  # The look for new email goes on in the folder that it was reading
  isempty(was[1]) || was == (w.chosen, w.writes) || choose!(m, w, was[1], writes=was[2])
  nothing
end

"Open `b` on the server so that it can be changed"
edit!(m::Mailer, w::Wire, b::Box) = (w.chosen == b.server && w.writes) || choose!(m, w, b.server, writes=true)

"Take the email `uid` out of the folder that's open, for good"
expunge!(m::Mailer, w::Wire, uid) = begin
  ask(m, w, "UID STORE $uid +FLAGS.SILENT (\\Deleted)")
  "UIDPLUS" in w.can ? ask(m, w, "UID EXPUNGE $uid") : ask(m, w, "EXPUNGE")
end

run!(m::Mailer, w::Wire, job) = begin
  kind = job[1]
  if kind === :mark
    _, b, uid, flag, on = job
    edit!(m, w, b)
    ask(m, w, "UID STORE $uid $(on ? '+' : '-')FLAGS.SILENT ($flag)")
  elseif kind === :move
    _, b, uid, to = job
    edit!(m, w, b)
    if "MOVE" in w.can
      ask(m, w, "UID MOVE $uid $(quoted(to.server))")
    else
      ask(m, w, "UID COPY $uid $(quoted(to.server))")
      expunge!(m, w, uid)
    end
    b.state = to.state = ""   # both folders are read again at the next look
  elseif kind === :delete
    _, b, uid = job
    edit!(m, w, b)
    expunge!(m, w, uid)
    b.state = ""
  elseif kind === :create
    command(_ -> nothing, m, w, "CREATE $(quoted(job[2].server))")
  elseif kind === :send
    post!(m, w, job[2])
  elseif kind === :copy
    # Gmail keeps a copy of what it sends by itself. Any other server gets one from Kaydown.
    _, b, raw = job
    "X-GM-EXT-1" in w.can || ask(m, w, "APPEND $(quoted(b.server)) (\\Seen) {$(length(raw))}", literal=raw)
    b.state = ""
  end
  nothing
end

# --- drafts ----------------------------------------------------------------------------------

"What the front matter of the page `lines` says, by its keys in lower case, and the line that the page's text starts on"
fields(lines) = begin
  out = Dict{String,String}()
  stop = front_matter(lines)
  key = ""
  for i in 2:stop-1
    f = match(r"^([\w][\w .-]*):\s*(.*)$", lines[i])
    if f !== nothing
      key = lowercase(strip(f[1]))
      out[key] = String(strip(f[2]))
    elseif !isempty(key) && startswith(lines[i], r"\s") && !isempty(strip(lines[i]))
      # A long list of people can go on in the next line
      out[key] = String(strip(out[key] * " " * strip(lines[i])))
    end
  end
  (out, stop + 1)
end

"True when the page `lines` is an email that isn't sent yet: its front matter names who it's to, and has no date"
isdraft(lines) = begin
  front_matter(lines) > 0 || return false
  said, _ = fields(lines)
  haskey(said, "to") && haskey(said, "subject") && !haskey(said, "date") && !haskey(said, "from")
end

"The folder that drafts are written in"
drafts(m::Mailer) = begin
  b = folder(m, :drafts)
  dir = b === nothing ? joinpath(root(m.account), "Drafts") : b.path
  mkpath(dir)
  dir
end

"""
Write a new draft, and give its path. `text` is the lines under the front
matter. `reply` is the Message-ID of the email that it answers.
"""
draft!(m::Mailer; to="", cc="", subject="", text=["", ""], reply="") = begin
  dir = drafts(m)
  file = spare(dir, clean(isempty(strip(subject)) ? "New email" : subject, 70, 120), ".md")
  lines = ["---", "to: $(flat(to))", "cc: $(flat(cc))", "subject: $(flat(subject))"]
  isempty(reply) || push!(lines, "in-reply-to: $reply")
  append!(lines, ["---", ""])
  append!(lines, text)
  write(joinpath(dir, file), join(lines, "\n"))
  changed!(m)
  joinpath(dir, file)
end

"`people` as the front matter writes them: Sam Lee <sam@example.com>, with a comma between two"
written(people) = join((isempty(strip(name)) ? address : occursin(r"[,<>\"]", name) ? "\"$(replace(name, '"' => "'"))\" <$address>" : "$name <$address>"
                        for (name, address) in people), ", ")

"`subject` with `mark` before it, like Re:, unless it has that already"
marked(subject, mark) = startswith(lowercase(strip(subject)), lowercase(mark)) ? String(strip(subject)) : "$mark $(strip(subject))"

"""
Write a draft that answers the email at `path`, and give the draft's path.
With `all`, it goes to everyone that the email went to as well. The email's
text is under your own, as a quote.
"""
reply!(m::Mailer, path; all=false) = begin
  lines = content(path)
  said, start = fields(lines)
  at = locate(path)
  # The Message-ID of the email, from the index, or from the email itself when the index doesn't know it
  id = at !== nothing ? at[2].id : isemail(path) ? (h = heading(path); h === nothing ? "" : h.id) : ""
  me = lowercase(m.account.address)
  from = addresses(get(said, "from", ""))
  # An answer to an email of your own goes to the people that the email went to
  ownmail = !isempty(from) && lowercase(from[1].second) == me
  to = ownmail ? addresses(get(said, "to", "")) : addresses(get(said, "reply-to", get(said, "from", "")))
  others = all ? filter(p -> lowercase(p.second) != me && !any(t -> lowercase(t.second) == lowercase(p.second), to),
                        [(ownmail ? [] : addresses(get(said, "to", "")))..., addresses(get(said, "cc", ""))...]) : []
  who = isempty(from) ? "they" : shown(from[1])
  text = ["", "", "On $(get(said, "date", "an earlier day")), $who wrote:", ""]
  theirs = lines[min(start, end + 1):end]
  while !isempty(theirs) && isempty(strip(first(theirs)))
    popfirst!(theirs)
  end
  append!(text, [isempty(l) ? ">" : "> " * l for l in theirs])
  draft!(m, to=written(to), cc=written(others), subject=marked(get(said, "subject", ""), "Re:"), text=text,
         reply=id)
end

"Write a draft that sends the email at `path` on to someone else, with what was attached to it, and give the draft's path"
forward!(m::Mailer, path) = begin
  lines = content(path)
  said, start = fields(lines)
  text = ["", "", "Forwarded email:", "", "> From: $(get(said, "from", ""))", "> Date: $(get(said, "date", ""))",
          "> Subject: $(get(said, "subject", ""))", "> To: $(get(said, "to", ""))", ">"]
  rest = lines[min(start, end + 1):end]
  # A link to a file that came with the email stays a link of its own line, to that same file, so the file is sent on
  for l in rest
    file = linked(l, dirname(path))
    push!(text, file === nothing ? (isempty(l) ? ">" : "> " * l) : replace(l, r"\([^)]*\)\s*$" => "($(escaped(file)))"))
  end
  draft!(m, subject=marked(get(said, "subject", ""), "Fwd:"), text=text)
end

const LINK = r"^\s*!?\[[^\]]*\]\(\s*<?([^)>]+?)>?\s*\)\s*$"

"The file on the Mac that the line `text` links to, when the line holds only that link. `dir` is the page's folder."
linked(text, dir) = begin
  f = match(LINK, text)
  (f === nothing || occursin(r"^\w+://|^mailto:", f[1])) && return nothing
  path = unescaped(String(f[1]))
  path = startswith(path, "~") ? expanduser(path) : isabspath(path) ? path : joinpath(dir, path)
  isfile(path) ? abspath(path) : nothing
end

"Why the draft `lines` can't be sent yet, or an empty string when it can"
unready(m::Mailer, lines) = begin
  ready(m.account) || return "Set up your email account on the Email page of the settings first."
  isempty(m.account.outgoing) && return "The Email page of the settings doesn't name a server to send with."
  front_matter(lines) > 0 || return "This page has no front matter that says who the email is to."
  said, _ = fields(lines)
  people = [addresses(get(said, "to", ""))..., addresses(get(said, "cc", ""))..., addresses(get(said, "bcc", ""))...]
  isempty(addresses(get(said, "to", ""))) && return "Write who the email is to, after `to:` at the top of the page."
  bad = findfirst(p -> !occursin(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", p.second), people)
  bad === nothing || return "“$(people[bad].second)” isn't an email address."
  ""
end

"""
Send the draft at `path` soon. The page's file must hold what you see: save it
first. It returns why the draft can't be sent, or an empty string.
"""
send!(m::Mailer, path) = begin
  why = unready(m, String.(split(read(path, String), '\n')))
  isempty(why) || return why
  any(j -> j[1] === :send && j[2] == path, m.jobs) || job!(m, :send, path)
  ""
end

"True while the draft at `path` waits to be sent"
sending(m::Mailer, path) = any(j -> j[1] === :send && j[2] == path, m.jobs)

"Send `raw` from `from` to each address of `to`, through the account's sending server"
deliver(m::Mailer, raw, from, to) = begin
  a = m.account
  host, port = endpoint(a.outgoing, 465)
  file = tempname()
  write(file, raw)
  easy, list = curl_easy_init(), C_NULL
  source = ccall(:fopen, Ptr{Cvoid}, (Cstring, Cstring), file, "rb")
  try
    foreach(address -> (list = curl_slist_append(list, "<$address>")), to)
    # Port 465 is encrypted from the start. Any other port starts plain and must turn encrypted before the password goes.
    set(easy, CURLOPT_URL, (a.safe && port == 465 ? "smtps" : "smtp") * "://$host:$port")
    a.safe && port != 465 && set(easy, CURLOPT_USE_SSL, CURLUSESSL_ALL)
    password = secret(a.address)
    if !isempty(password)
      set(easy, CURLOPT_USERNAME, isempty(a.user) ? a.address : a.user)
      set(easy, CURLOPT_PASSWORD, password)
    end
    set(easy, CURLOPT_MAIL_FROM, "<$from>")
    set(easy, CURLOPT_MAIL_RCPT, list)
    set(easy, CURLOPT_UPLOAD, 1)
    set(easy, CURLOPT_READDATA, source)
    set(easy, CURLOPT_INFILESIZE, length(raw))
    set(easy, CURLOPT_NOSIGNAL, 1)
    set(easy, CURLOPT_CONNECTTIMEOUT, 20)
    set(easy, CURLOPT_TIMEOUT, 600)
    certificates(easy)
    # libcurl waits for the server to say that it took the email, so it does all of this in another thread
    code = @threadcall((:curl_easy_perform, libcurl), UInt32, (Ptr{Cvoid},), easy)
    m.turn = time()
    code == 0 || throw(code == 55 || code == 56 ? Trouble(:server, "$host didn't take the email. Check the addresses that it's to.") : why(code, host))
  finally
    @threadcall((:curl_easy_cleanup, libcurl), Cvoid, (Ptr{Cvoid},), easy)
    list == C_NULL || curl_slist_free_all(list)
    source == C_NULL || ccall(:fclose, Cint, (Ptr{Cvoid},), source)
    rm(file, force=true)
  end
  nothing
end

"""
Send the draft at `path`. Then the email that went is kept as a file in the
folder of sent email, the draft goes, and the server's folder gets a copy.

An email goes once. Whatever goes wrong after the server took it, the draft
isn't sent again: this returns, and the job is done.
"""
post!(m::Mailer, w::Wire, path) = begin
  isfile(path) || return
  a = m.account
  lines = String.(split(replace(read(path, String), "\r\n" => "\n"), '\n'))
  why = unready(m, lines)
  isempty(why) || throw(Trouble(:server, why))
  said, start = fields(lines)
  text = lines[min(start, end + 1):end]
  # A line that holds only a link to a file on the Mac sends that file with the email
  files = filter(!isnothing, [linked(l, dirname(path)) for l in text])
  words = [l for l in text if linked(l, dirname(path)) === nothing]
  while !isempty(words) && isempty(strip(first(words)))
    popfirst!(words)
  end
  to, cc, bcc = (addresses(get(said, key, "")) for key in ("to", "cc", "bcc"))
  subject = get(said, "subject", "")
  id = "<$(string(rand(UInt128), base=16)).kaydown@$(domain(a.address))>"
  at = time()
  from = written([a.name => a.address])
  raw = compose(from=from, to=written(to), cc=written(cc), subject=subject, text=join(words, "\n"), html=html(words, title=subject),
                files=files, reply=get(said, "in-reply-to", ""), references=get(said, "in-reply-to", ""), id=id, at=at)
  m.doing = "Kaydown is sending your email."
  changed!(m)
  deliver(m, raw, a.address, unique(String[p.second for p in [to..., cc..., bcc...]]))
  push!(m.sent, id)
  try
    filed!(m, path, said, text, from, to, cc, subject, id, at, raw)
  catch e
    m.problem, m.kind = "Kaydown sent your email, but couldn't keep it in the folder of sent email: $(sprint(showerror, e))", :server
    # The draft is still where it was. A date in its front matter says that it went, so it can't be sent a second time.
    try
      isfile(path) && write(path, join([lines[1]; "from: $(flat(from))"; "date: $(longdate(at))"; lines[2:end]], "\n"))
    catch
    end
    @warn "Kaydown sent an email, but couldn't file its page" exception=(e, catch_backtrace())
  end
  nothing
end

"""
The email that the draft at `path` held has gone. Keep the email `raw`, as it
went, as a file in the folder of sent email, take the draft away, and note
what the server must still be told.
"""
filed!(m::Mailer, path, said, text, from, to, cc, subject, id, at, raw) = begin
  a = m.account
  out = something(folder(m, :sent), box(joinpath(root(a), "Sent")), Box(joinpath(root(a), "Sent"), server="Sent", role=:sent))
  boxes[out.path] = out
  mkpath(out.path)
  stem = "$(stamp(at)) $(clean("to " * shown(to), 30, 60)) - $(clean(isempty(subject) ? "No subject" : subject, 70, 120))"
  name = spare(out.path, stem, ".eml", taken=n -> haskey(out.byfile, n))
  draft = locate(path)
  copy = joinpath(out.path, name)
  write(copy, raw)
  protect!(copy)
  # The draft goes at once, so that it can't be sent again
  rm(path)
  m.moved[path] = copy
  add!(out, Letter(0, true, false, false, true, true, false, at, shown([a.name => a.address]), shown(to), subject, id, name, mtime(copy)))
  save(out)
  changed!(m)
  # The server's folder of sent email gets a copy, unless the server keeps one by itself
  isempty(out.server) || job!(m, :copy, out, raw)
  # A draft that the server had too goes from there
  if draft !== nothing
    b, old = draft
    drop!(b, old)
    save(b)
    old.uid > 0 && job!(m, :delete, b, old.uid)
  end
  # The email that this one answers gets the mark of an answered email
  answered = get(said, "in-reply-to", "")
  for b in m.all, l in b.letters
    (!isempty(answered) && l.id == answered && !l.answered) || continue
    l.answered, b.dirty = true, true
    b.version += 1
    l.uid > 0 && job!(m, :mark, b, l.uid, "\\Answered", true)
  end
  nothing
end

# --- the work, a little in each frame ----------------------------------------------------------

"Look for new email now, and tell the server what you did"
check!(m::Mailer) = (m.next = 0.0; m.kind === :login || (m.problem = ""; m.kind = :none); changed!(m))

"Use the account `a` from now on. The work that's running for the old account stops."
account!(m::Mailer, a::Account) = begin
  m.stop = m.task !== nothing
  m.account = a
  m.all = ready(a) ? nested(root(a)) : Box[]
  m.problem, m.kind, m.next, m.checked, m.again, m.follows, m.held = "", :none, 0.0, 0.0, false, false, 0
  empty!(m.jobs)
  changed!(m)
end

"Start the task that looks for new email and tells the server what you did"
start!(m::Mailer) = begin
  m.stop = false
  password = secret(m.account.address)
  if isempty(password) && m.account.safe
    m.problem, m.kind, m.next = "Kaydown has no password for $(m.account.address). Type it on the Email page of the settings.", :login, Inf
    return changed!(m)
  end
  only = time() < m.next   # just the jobs: the next look isn't due
  follows = m.follows
  m.task = @async begin
    wire = nothing
    try
      m.turn = time()
      wire = connect(m, m.account, password)
      serve!(m, wire)
      if !only
        look!(m, wire)
        m.checked = time()
        # A look that puts things back after the server said no leaves what the server said, for you to read
        follows || ((m.problem, m.kind) = ("", :none))
        m.follows = false
      end
      only || (m.next = m.checked + 60 * m.account.every)
      # An account that got its day's worth looks again when it can get more
      !only && m.held > 0 && (m.next = max(m.next, resumes()))
      # The connection stays open for a while, and what you do in that time goes to the server at once
      waited = time()
      while true
        m.again && ((m.next, m.follows, m.again) = (time(), true, false))
        (time() - waited < LINGER[] && time() < m.next) || break
        if !isempty(m.jobs)
          m.idle = false
          try
            serve!(m, wire)
          catch e
            # The server closed the connection while it waited. The next connection does the job.
            e isa Trouble && e.kind === :network ? break : rethrow()
          end
          waited = time()
        end
        m.idle = true
        m.doing = ""
        rest(m)
      end
      m.idle = false
      try command(_ -> nothing, m, wire, "LOGOUT") catch end
    catch e
      if e isa Trouble
        m.problem, m.kind = e.says, e.kind
        # A wrong password stays wrong, so the next look waits until the account changes
        m.next = e.kind === :login ? Inf : time() + RETRY
      elseif !(e isa Stopped)
        m.problem, m.kind = "Kaydown's look for email stopped: $(sprint(showerror, e))", :stopped
        m.next = time() + 5RETRY
        @warn "Kaydown's look for email stopped" exception=(e, catch_backtrace())
      end
    finally
      wire === nothing || close(wire)
      keep_tally()
      foreach(b -> b.dirty && isdir(b.path) && save(b), m.all)
      m.doing = ""
      m.idle = false
      m.left = m.total = 0
      changed!(m)
    end
  end
  changed!(m)
end

"True while the work is running. It isn't while the connection only waits for the next thing you do."
busy(m::Mailer) = m.task !== nothing && !m.idle

"""
Do what's due now: give the work its turn, or start it when it's time to look
for new email or you did something that the server must know. Each window
calls this in each frame. It returns the seconds until it wants the next call.
"""
tick!(m::Mailer) = begin
  ready(m.account) || return Inf
  if m.task !== nothing
    if istaskdone(m.task)
      m.task = nothing
      changed!(m)
    else
      yield()
      return m.idle ? IDLE : TURN
    end
  end
  m.stop = false
  # What you did goes to the server at once, unless the server couldn't be reached: then it waits for the next look
  if time() >= m.next || (!isempty(m.jobs) && m.kind in (:none, :server))
    start!(m)
    return m.task === nothing ? Inf : TURN
  end
  max(0.0, m.next - time())
end

"The app is closing: stop the work, and keep each index"
quit!(m::Mailer) = begin
  m.stop = true
  for _ in 1:200
    (m.task === nothing || istaskdone(m.task)) && break
    yield()
  end
  foreach(b -> b.dirty && isdir(b.path) && save(b), values(boxes))
  nothing
end

"The time `at` as a list shows it: the time of day for today, or the day"
shortdate(at; now=time()) = begin
  day(t) = Libc.strftime("%Y-%m-%d", t)
  hour = Libc.TmStruct(at).hour
  day(at) == day(now) ? "$(hour % 12 == 0 ? 12 : hour % 12):$(Libc.strftime("%M", at)) $(hour < 12 ? "am" : "pm")" :
  Libc.strftime("%Y", at) == Libc.strftime("%Y", now) ? Libc.strftime("%-d %b", at) : Libc.strftime("%-d %b %Y", at)
end

commas(n) = replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",")

"""
How far the look has come with the emails that it found to get: how many have
come, how many there are, and the seconds that the rest most likely take. The
seconds are nothing while it's too soon to tell. It returns nothing when no
emails are coming.
"""
progress(m::Mailer) = begin
  (busy(m) && m.total > 0 && m.left > 0 && m.began > 0) || return nothing
  come = m.total - m.left
  spent = m.began > 0 ? time() - m.began : 0.0
  (come=come, total=m.total, left=come >= 16 && spent >= 5 ? m.left * spent / come : nothing)
end

"The time `seconds` in words, like about 20 minutes"
lasting(seconds) = begin
  seconds < 90 && return "about a minute"
  seconds < 3300 && return "about $(round(Int, seconds / 60)) minutes"
  hours = round(Int, seconds / 3600)
  hours == 1 ? "about an hour" : "about $hours hours"
end

"How many emails of the look have come, in words, and how long the rest take once Kaydown can tell"
counted(p) = "$(commas(p.come)) of $(commas(p.total)) email$(p.total == 1 ? " has" : "s have") come." *
  (p.left === nothing ? "" : " The rest take $(lasting(p.left)).")

"When the time `at` is, in words like at 9:40 pm or at 9:40 am tomorrow"
resuming(at; now=time()) = begin
  t = Libc.TmStruct(at)
  clock = "$(t.hour % 12 == 0 ? 12 : t.hour % 12):$(lpad(t.min, 2, '0')) $(t.hour < 12 ? "am" : "pm")"
  day(x) = Libc.strftime("%Y-%m-%d", x)
  day(at) == day(now) ? "at $clock" : day(at) == day(now + 86400) ? "at $clock tomorrow" : "on $(shortdate(at, now=now))"
end

"Why some emails wait, when the account got all that its company allows in a day, and when Kaydown goes on"
waiting(m::Mailer) = begin
  p = provider(m.account.address)
  who = p === nothing ? "Your email company" : p.name
  most = p !== nothing && haskey(DAILY, p.name) ? " $(commas(DAILY[p.name])) MB of" : " only so much"
  "$who lets an app get$most email in a day. Kaydown stopped before that, with $(commas(m.held)) email$(m.held == 1 ? "" : "s") still to come. " *
  "It goes on $(resuming(max(m.next, resumes())))."
end

"A sentence or two on the email: what the work is doing, what went wrong, or when it last looked"
says(m::Mailer) = begin
  a = m.account
  ready(a) || return "Kaydown has no email account yet. Type your address and your password above."
  isempty(m.problem) || return m.problem
  p = progress(m)
  p === nothing || return "$(m.doing) $(counted(p))"
  busy(m) && !isempty(m.doing) && return m.doing
  m.held > 0 && return waiting(m)
  have = sum(b -> count(l -> l.uid > 0, b.letters), m.all, init=0)
  m.checked == 0 && return "Kaydown hasn't looked for email since it opened."
  "Kaydown has $(commas(have)) email$(have == 1 ? "" : "s") in $(root(a)). It last looked at $(shortdate(m.checked))."
end

# --- what a list of a folder shows ---------------------------------------------------------------

"A row of the list of a folder of emails"
struct Row
  path::String      # the page
  who::String       # who it's from, or who it's to for an email of your own
  subject::String
  at::Float64       # when it was sent, or when a draft was last changed
  unread::Bool
  flagged::Bool
  answered::Bool
  draft::Bool       # a page that isn't sent yet
end

"What was last worked out for each folder's list, and what it was worked out from"
const listed = Dict{String,Tuple{Any,Vector{Row}}}()

"""
The rows of the folder `dir`, newest first: its emails, from its index, and
each Markdown page that's in it, like a draft. It's nothing when `dir` isn't
a folder of emails.
"""
rows(dir) = begin
  b = box(dir)
  b === nothing && return nothing
  key = (b.version, mtime(dir))
  kept = get(listed, dir, nothing)
  kept !== nothing && kept[1] == key && return kept[2]
  out = Row[]
  outgoing = b.role in (:sent, :drafts)
  for l in b.letters
    push!(out, Row(joinpath(dir, l.file), outgoing || l.out ? "To " * l.to : l.from, l.subject, l.at, unread(l), l.flagged, l.answered, false))
  end
  for name in readdir(dir)
    (endswith(lowercase(name), ".md") && !haskey(b.byfile, name) && !startswith(name, '.')) || continue
    path = joinpath(dir, name)
    said, _ = fields(first_lines(path))
    to = addresses(get(said, "to", ""))
    push!(out, Row(path, isempty(to) ? "No one yet" : "To " * shown(to), get(said, "subject", splitext(name)[1]), mtime(path), false, false, false,
                   !haskey(said, "date")))
  end
  sort!(out, by=r -> r.at, rev=true)
  listed[dir] = (key, out)
  out
end

"The first lines of the file at `path`: enough to hold its front matter. For an email, they say what its head says."
first_lines(path) = begin
  isemail(path) && return headlines(path)   # an email's head, as the front matter of a page writes it
  out = String[]
  try
    for l in eachline(path)
      push!(out, l)
      ((length(out) > 1 && rstrip(l) == "---") || length(out) >= 40) && break
    end
  catch
  end
  out
end

"How many emails of the folder `dir` aren't read"
unread(dir::AbstractString) = (b = box(dir); b === nothing ? 0 : count(unread, b.letters))
