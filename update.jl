# Ladder updates itself. The app asks GitHub which version of Ladder is the
# newest. It gets a newer version while you work, checks that Ladder's
# developer signed it, and puts it in the app's place when you quit. The
# settings page has a box that turns this off, and says how far an update has
# got.
#
#     u = own()               # the updater of the app that's running
#     tick!(u)                # call it in each frame. It gives the seconds until it wants the next call.
#     says(u), action(u)      # what the settings page shows, and what its button does
#     act!(u)                 # what happens when you click that button
#     quit!(u)                # call it when the last window has closed
#
# A release has two files. latest.txt names the newest version:
#
#     version=0.2.0
#     file=Ladder-0.2.0.zip
#     sha256=<the SHA-256 sum of the zip file>
#     macos=12.0
#
# `macos` is the oldest macOS that the version runs on. The zip file holds
# Ladder.app. release.jl makes both files, and publishes them in `REPO`.
#
# Only the Ladder app updates itself, and only a copy that was signed with a
# Developer ID certificate, as release.jl signs it. Ladder run from its
# source doesn't, and nor does an app that app/build.jl signed for one Mac.
#
# A new version must pass the designated requirement of the app that's
# running. That is the rule that macOS reads from an app's signature, and it
# says who signed the app. So an app that someone else made can't take
# Ladder's place, wherever it came from.
#
# The new version waits in Ladder's folder in ~/Library/Application Support,
# in `update`. It takes the app's place after Ladder has quit, because a
# program that's running reads its own files as it goes.
#
# LADDER_UPDATE_FEED gives the app another address for latest.txt, to try an
# update without a release. The new version must still pass the rule above.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool

"The GitHub repo whose releases the app looks at. release.jl publishes to it."
const REPO = "jkroso/Ladder"
"The file of a release that names the newest version"
const LATEST = "latest.txt"
"The Ladder app's name for macOS, as app/build.jl gives it"
const ID = "com.jkroso.ladder"
const EVERY = 24 * 60 * 60.0   # seconds from one look for a newer version to the next
const RETRY = 60 * 60.0        # seconds until it looks again after it couldn't
const POLL = 1.0               # seconds between two looks at a download that's running
const LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"The address of latest.txt"
feed() = get(ENV, "LADDER_UPDATE_FEED", "https://github.com/$REPO/releases/latest/download/$LATEST")

mutable struct Updater
  app::String                             # the app that's running, or "" when Ladder runs from its source
  version::VersionNumber                  # the version that's running
  feed::String                            # the address of latest.txt
  dir::String                             # the folder where a new version waits
  rule::Union{Nothing,String}             # what a new version's signature must pass. "" when the app has no such rule. Nothing until it's asked for.
  register::String                        # the program that tells macOS about the new app
  auto::Bool                              # look for a newer version, and get it, without being asked
  stage::Symbol                           # :idle, :checking while it asks which version is the newest, or :fetching while it gets one
  process::Any                            # the program that's checking or fetching
  newest::Union{Nothing,VersionNumber}    # the newest version there is, once it has asked
  file::String                            # the name of that version's zip file
  sum::String                             # the SHA-256 sum of the zip file
  needs::VersionNumber                    # the oldest macOS that the newest version runs on
  staged::Union{Nothing,VersionNumber}    # the version that waits in `dir` to take the app's place
  looked::Bool                            # `dir` has been read for a version that waited there from the last run
  problem::String                         # why the last check or download failed, or ""
  next::Float64                           # the time of the next look, for `auto`
  again::Bool                             # open the app again once the new version is in its place
  changed::Int                            # goes up whenever what `says` and `action` give may have changed
end

"""
The updater of the app at `app`, which is version `version`. `rule` is the
requirement that a new version's signature must pass. Without one, it's the
designated requirement of `app`.
"""
Updater(app, version; feed=feed(), dir=waiting_room(), rule=nothing, register=LSREGISTER) =
  Updater(app, version, feed, dir, rule, register, true, :idle, nothing, nothing, "", "", v"0", nothing, false, "", 0.0, false, 0)

"The folder where a new version waits"
waiting_room() = joinpath(homedir(), "Library", "Application Support", "Ladder", "update")

"The updater of the app that's running"
const mine = Ref{Union{Nothing,Updater}}(nothing)
own() = begin
  mine[] === nothing || return mine[]
  u = Updater(running()...)
  # While the app is built, this code runs in Julia's own program. The app must look again when it opens.
  ccall(:jl_generating_output, Cint, ()) == 1 || (mine[] = u)
  u
end

"Where the Ladder app that's running is, and its version. The place is an empty string when Ladder runs from its source."
running() = begin
  Sys.isapple() || return ("", v"0")
  with_pool() do
    bundle = msg(cls("NSBundle"), "mainBundle")
    jstring(msg(bundle, "bundleIdentifier")) == ID || return ("", v"0")
    version = jstring(msg(bundle, "objectForInfoDictionaryKey:", nsstring("CFBundleShortVersionString")))
    (jstring(msg(bundle, "bundlePath")), something(tryparse(VersionNumber, version), v"0"))
  end
end

"""
The rule that a new version's signature must pass: the designated requirement
of the app that's running. It's an empty string for an app that's signed for
one Mac. The rule of such an app names that one build, so no other build
passes it.
"""
rule(u::Updater) = begin
  u.rule === nothing || return u.rule
  u.rule = try
    m = match(r"^designated => (.+)$"m, read(pipeline(`/usr/bin/codesign -d -r- $(u.app)`, stderr=devnull), String))
    (m === nothing || startswith(m[1], "cdhash")) ? "" : String(m[1])
  catch
    ""
  end
end

"True when Ladder can change the file or folder at `path`"
writable(path) = ccall(:access, Cint, (Cstring, Cint), path, 2) == 0

"Why the app can't update itself, or an empty string when it can"
blocked(u::Updater) = begin
  isempty(u.app) && return "Ladder runs from its source here. Only the Ladder app updates itself."
  isempty(rule(u)) && return "This copy of Ladder was built on this Mac. Only a copy from Ladder's releases updates itself."
  # macOS runs an app that's still in the folder it was downloaded to from a place that nothing can change
  (writable(u.app) && writable(dirname(u.app))) ||
    return "Ladder can't change its own files where it is. Move it to your Applications folder, then open it again."
  ""
end

"The version of macOS on this Mac, or nothing when Ladder can't tell"
macos() = try
  m = match(r"<key>ProductVersion</key>\s*<string>([\d.]+)</string>", read("/System/Library/CoreServices/SystemVersion.plist", String))
  m === nothing ? nothing : tryparse(VersionNumber, m[1])
catch
  nothing
end

"True when this Mac has the macOS that the newest version needs"
fits(u::Updater) = (has = macos(); has === nothing || has >= u.needs)

"""
What the text of latest.txt names: the version, its zip file, the file's
SHA-256 sum and the oldest macOS the version runs on. It's nothing when the
text doesn't name the first three. The file is a name beside latest.txt, never
a path or an address.
"""
parse_feed(text) = begin
  named = Dict{String,String}()
  for line in split(text, '\n')
    parts = split(strip(line), '=', limit=2)
    length(parts) == 2 && (named[parts[1]] = parts[2])
  end
  version = tryparse(VersionNumber, get(named, "version", ""))
  file, sum = get(named, "file", ""), lowercase(get(named, "sha256", ""))
  # The version is written the way Julia writes it, since the new app's own version is compared with these words
  (version === nothing || string(version) != named["version"]) && return nothing
  (occursin(r"^[\w\-][\w.\-]*$", file) && occursin(r"^[0-9a-f]{64}$", sum)) || return nothing
  (version, String(file), String(sum), something(tryparse(VersionNumber, get(named, "macos", "")), v"0"))
end

changed!(u::Updater) = (u.changed += 1; u)
feed_file(u::Updater) = joinpath(u.dir, LATEST)
problem_file(u::Updater) = joinpath(u.dir, "problem")
"Where the new version waits"
staged_app(u::Updater) = joinpath(u.dir, "staged.app")
ready_file(u::Updater) = joinpath(u.dir, "ready")

"""
Read `dir` for a new version that has waited there since the last run. What's
left of an update that stopped half way, or of one that's now the app, goes.
"""
look!(u::Updater) = begin
  u.looked = true
  version = isfile(ready_file(u)) ? tryparse(VersionNumber, strip(read(ready_file(u), String))) : nothing
  if version !== nothing && version > u.version && isdir(staged_app(u))
    u.staged = version
    return changed!(u)
  end
  rm(u.dir, recursive=true, force=true)
  u
end

"Ask which version is the newest. `tick!` takes the answer."
check!(u::Updater) = begin
  u.stage == :idle || return u
  u.looked || look!(u)   # before anything new goes into the folder
  u.problem = ""
  try
    mkpath(u.dir)
    rm(feed_file(u), force=true)
    u.process = run(pipeline(`/usr/bin/curl -fsSL --max-time 30 -o $(feed_file(u)) $(u.feed)`, stdout=devnull, stderr=devnull), wait=false)
    u.stage = :checking
  catch
    failed!(u, "Ladder couldn't look for a newer version.")
  end
  changed!(u)
end

"Note that a check or a download failed, and why. Ladder tries again in an hour."
failed!(u::Updater, why) = (u.stage = :idle; u.problem = why; u.next = time() + RETRY; changed!(u))

"Take the answer to `check!`. With `auto`, start to get the version it names if that one is newer."
checked!(u::Updater) = begin
  named = success(u.process) && isfile(feed_file(u)) ? parse_feed(read(feed_file(u), String)) : nothing
  rm(feed_file(u), force=true)
  named === nothing && return failed!(u, "Ladder couldn't look for a newer version.")
  u.stage = :idle
  u.newest, u.file, u.sum, u.needs = named
  u.next = time() + EVERY
  u.auto && wanted(u) && fetch!(u)
  changed!(u)
end

"""
Write latest.txt into `dir` for the release of `version`, whose zip file is
`zip`. `macos` is the oldest macOS that the version runs on. It returns the
path of latest.txt. release.jl calls this.
"""
announce(dir, version, zip; macos="12.0") = begin
  sum = first(split(readchomp(`/usr/bin/shasum -a 256 $zip`)))
  text = "version=$version\nfile=$(basename(zip))\nsha256=$sum\nmacos=$macos\n"
  parse_feed(text) === nothing && error("Ladder can't read a latest.txt for version $version and the file $(basename(zip)). ",
                                        "Write the version like 1.2.0, and give the file a name of letters, digits, dots and dashes.")
  file = joinpath(dir, LATEST)
  write(file, text)
  file
end

"True when the newest version is newer than the app, runs on this Mac and doesn't wait in `dir` already"
wanted(u::Updater) = u.newest !== nothing && u.newest > u.version && u.staged != u.newest && fits(u)

# Gets the zip file, and leaves the app that's in it in `dir` as staged.app, with its version in the file
# `ready`. The app stays only if it's the version that latest.txt named, and its signature passes the rule.
# The last line it prints says what went wrong.
const FETCH = raw"""
url="$1"; sum="$2"; dir="$3"; version="$4"; rule="$5"
new="$dir/new"
fail() { echo "$1" >&2; rm -rf "$new"; exit 1; }
rm -rf "$new" "$dir/ready" "$dir/staged.app"
mkdir -p "$new" || fail "Ladder couldn't make a folder for version $version."
/usr/bin/curl -fsSL --retry 2 -o "$new/app.zip" "$url" || fail "The download of Ladder $version stopped."
[ "$(/usr/bin/shasum -a 256 "$new/app.zip" | /usr/bin/cut -d' ' -f1)" = "$sum" ] || fail "The file that came isn't the one that was released."
/usr/bin/ditto -x -k "$new/app.zip" "$new/open" || fail "Ladder couldn't open the file of version $version."
set -- "$new/open"/*.app
{ [ $# = 1 ] && [ -d "$1" ]; } || fail "The file of version $version doesn't hold an app."
[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$1/Contents/Info.plist" 2>/dev/null)" = "$version" ] || fail "The app that came isn't version $version."
/usr/bin/codesign --verify --deep --strict -R="$rule" "$1" 2>/dev/null || fail "Ladder's developer didn't sign the app that came, so Ladder left it alone."
/bin/mv "$1" "$dir/staged.app" || fail "Ladder couldn't keep version $version."
echo "$version" > "$dir/ready"
rm -rf "$new"
"""

"Start to get the newest version. `tick!` sees when it has come."
fetch!(u::Updater) = begin
  (u.stage == :idle && u.newest !== nothing) || return u
  u.looked || look!(u)
  u.problem = ""
  u.staged = nothing   # the download takes the place of a version that waits
  try
    mkpath(u.dir)
    url = u.feed[1:findlast('/', u.feed)] * u.file
    cmd = `/bin/sh -c $FETCH sh $url $(u.sum) $(u.dir) $(string(u.newest)) $(rule(u))`
    u.process = run(pipeline(cmd, stdout=devnull, stderr=problem_file(u)), wait=false)
    u.stage = :fetching
  catch
    failed!(u, "Ladder couldn't get version $(u.newest).")
  end
  changed!(u)
end

"Note how the download ended"
fetched!(u::Updater) = begin
  said = isfile(problem_file(u)) ? split(strip(read(problem_file(u), String)), '\n', keepempty=false) : SubString{String}[]
  rm(problem_file(u), force=true)
  success(u.process) || return failed!(u, isempty(said) ? "Ladder couldn't get version $(u.newest)." : String(last(said)))
  u.stage = :idle
  u.staged = u.newest
  changed!(u)
end

"""
Do what's due now: take the answer of a check or the end of a download, and
with `auto`, look for a newer version when it's time. Each window calls this in
each frame. It returns the seconds until it wants the next call. That is
`Inf` when it only needs one after something else happens.
"""
tick!(u::Updater) = begin
  isempty(blocked(u)) || return Inf
  u.looked || look!(u)
  if u.stage == :checking
    process_exited(u.process) && checked!(u)
  elseif u.stage == :fetching
    process_exited(u.process) && fetched!(u)
  elseif u.auto && time() >= u.next
    check!(u)
  end
  u.stage == :idle ? Inf : POLL
end

"""
Take the end of a download that no frame has seen yet. A quit can come in the
second after the download ends, and the new version is ready then.
"""
settle!(u::Updater) = (u.stage == :fetching && process_exited(u.process) && fetched!(u); u)

"Wait until the check or the download that's running has ended, and take its answer. For a script or a test."
finish!(u::Updater) = begin
  while u.stage != :idle
    wait(u.process)
    tick!(u)
  end
  u
end

"One or two sentences on where the update has got to, for the settings page"
says(u::Updater) = begin
  no = blocked(u)
  isempty(no) || return no
  u.stage == :checking && return "Ladder is looking for a newer version…"
  u.stage == :fetching && return "Ladder is getting version $(u.newest)…"
  u.staged !== nothing &&
    return "Ladder $(u.staged) is ready." * (u.auto ? " It takes the place of version $(u.version) when you quit Ladder." : "")
  isempty(u.problem) || return u.problem * (u.auto ? " Ladder tries again in an hour." : "")
  u.newest === nothing && return "This is Ladder $(u.version)."
  u.newest <= u.version && return "This is Ladder $(u.version), the newest version."
  fits(u) || return "Ladder $(u.newest) needs macOS $(u.needs.major).$(u.needs.minor) or later. This is Ladder $(u.version)."
  "Ladder $(u.newest) is out. This is Ladder $(u.version)."
end

"""
What the button on the settings page does now: `:check` looks for a newer
version, `:get` gets the one that's out, and `:restart` puts the one that's
ready in the app's place and opens it. It's `:none` when there's nothing to do.
"""
action(u::Updater) = begin
  (isempty(blocked(u)) && u.stage == :idle) || return :none
  u.staged !== nothing && return :restart
  wanted(u) ? :get : :check
end

"What the button says for each `action`"
label(u::Updater) = begin
  a = action(u)
  a === :restart ? "Restart to update" : a === :get ? "Get Ladder $(u.newest)" : a === :check ? "Check now" : ""
end

"""
Do the `action`. After `:restart`, `u.again` is true: close every window, and
`quit!` then opens the new version.
"""
act!(u::Updater) = begin
  a = action(u)
  a === :check && check!(u)
  a === :get && fetch!(u)
  a === :restart && (u.again = true)
  u
end

# Puts staged.app in the app's place, once the Ladder that asked has quit. It leaves the app alone while
# another Ladder from the same app is open, since that one still reads the app's files. The new app must
# pass the rule again, in case a file of it was lost while it waited. `again` opens the app at the end,
# whichever version is there then.
const INSTALL = raw"""
pid="$1"; dir="$2"; app="$3"; rule="$4"; again="$5"; register="$6"
new="$dir/staged.app"
finish() { [ -n "$again" ] && /usr/bin/open "$app"; exit "$1"; }
n=0
while kill -0 "$pid" 2>/dev/null && [ $n -lt 300 ]; do sleep 0.1; n=$((n+1)); done
{ [ -d "$app" ] && [ -f "$dir/ready" ] && [ -d "$new" ]; } || finish 1
if /bin/ps -axo comm= | /usr/bin/grep -qF "$app/Contents/MacOS/"; then finish 1; fi
rm -f "$dir/ready"
/usr/bin/codesign --verify --deep --strict -R="$rule" "$new" 2>/dev/null || { rm -rf "$new"; finish 1; }
place="$(/usr/bin/dirname "$app")"
beside="$place/.ladder-new-$$.app"
old="$place/.ladder-old-$$.app"
# First onto the app's disk, which can be another one. Then the two swap places, so the app is never half there.
/bin/mv "$new" "$beside" || { rm -rf "$beside" "$new"; finish 1; }
/bin/mv "$app" "$old" || { rm -rf "$beside"; finish 1; }
/bin/mv "$beside" "$app" || { /bin/mv "$old" "$app"; rm -rf "$beside"; finish 1; }
rm -rf "$old"
/usr/bin/touch "$app"
"$register" -f "$app" >/dev/null 2>&1
finish 0
"""

"""
The command that puts the new version in the app's place once the process
`pid` has ended
"""
install(u::Updater, pid) =
  `/bin/sh -c $INSTALL sh $pid $(u.dir) $(u.app) $(rule(u)) $(u.again ? "again" : "") $(u.register)`

"""
Call this when the last window has closed. It starts a program that outlives
Ladder, and puts the new version in the app's place once Ladder has quit. It
does that when a version is ready, and `auto` is on or you clicked Restart to
update. It's true when it started the program.
"""
quit!(u::Updater) = begin
  settle!(u)
  (u.staged !== nothing && (u.auto || u.again) && isempty(blocked(u))) || return false
  try
    run(pipeline(detach(install(u, getpid())), stdin=devnull, stdout=devnull, stderr=devnull), wait=false)
    true
  catch
    false
  end
end
