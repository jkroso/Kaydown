# A map shows the place that its block names, with a pin on the place. In a
# document it's a code block in the language `map`:
#
#     ```map
#     8 Wattle Street, Brunswick VIC 3056
#     zoom: 15
#     centre: -37.76810, 144.94260
#     ```
#
# The first line that isn't a setting is the place: an address, or a latitude
# and a longitude like `-37.7701, 144.9610`. The pin is on the place. `zoom`
# says how much the map shows, as maps on the web count it: each step up shows
# half as much from side to side. Without it, the zoom is 15, which shows a
# few streets. `centre` is the latitude and the longitude in the middle of the
# map. Without it, the place is in the middle. `center` is read as the same
# word.
#
# This file reads and writes those lines, writes the place as a link to Apple
# Maps, and gets the picture of the map. It also works out which latitude and
# longitude is at each point of the picture, so that a drag can move the map
# and a click can move the place. It draws nothing.
#
# map.swift makes the picture, as a program of its own, because macOS only
# offers its maps to Swift. Apple finds the address and sends the map, so the
# first picture of a place needs the network. Each picture is kept in a folder
# as a PNG file, named by the place, the middle, the zoom, the size and whether
# the page is dark. A text file beside it holds the latitude, the longitude and the
# address that Apple has for the place. So a map shows at once the next time,
# with no network.
#
#     p = picture!(folder, "8 Wattle Street, Brunswick", 15, 720, 280, false)
#     p.state   # :there, :coming, :failed, :lost or :none. Ask again while it's :coming.
#     p.file    # the PNG file, once the state is :there
#
# The Kaydown app has the program in it, beside its own program. When Kaydown
# runs from its source, it compiles map.swift the first time it's needed,
# which takes a few seconds, and keeps the program in a folder of the Mac's
# caches. That needs Swift, which comes with Xcode and its command line tools.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use Base64: base64encode
@use Printf: @sprintf

"The language of a code block that is a map"
const MAP = "map"
const ZOOM = 15       # the zoom of a block that names none
const ZOOMS = 3:19    # the least and the most that a block can ask for: a continent, and one building
const TALL = 280      # how tall the picture of a map is, in px
const SCALE = 2       # how many pixels of the picture's file go to a px, as map.swift has it
const RETRY = 60      # seconds after a picture can't be made before Kaydown tries again

"A latitude and a longitude, in degrees"
const LatLon = NTuple{2,Float64}

mutable struct Site
  place::String                   # the address, or the latitude and the longitude, as the block has it
  zoom::Int
  centre::Union{Nothing,LatLon}   # what's in the middle of the map, or nothing when the place is
  other::Vector{String}           # the lines after the place that this file doesn't know, kept as they are
end

Site() = Site("", ZOOM, nothing, String[])

"Read a map from the lines of its block"
site(lines) = begin
  s = Site()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = match(r"^zoom\s*:\s*(.*)$"i, text)
    if m !== nothing
      z = tryparse(Float64, strip(m[1]))
      z === nothing || !isfinite(z) || (s.zoom = clamp(round(Int, z), ZOOMS))
    elseif (m = match(r"^cent(?:re|er)\s*:\s*(.*)$"i, text)) !== nothing
      # A middle that's no latitude and longitude is left out, and the place is in the middle
      c = coordinates(m[1])
      c === nothing || (s.centre = c)
    elseif isempty(s.place)
      s.place = String(text)
    else
      push!(s.other, String(text))
    end
  end
  s
end

"The lines of a map's block. A map with no place has no lines."
written(s::Site) = isempty(s.place) ? copy(s.other) :
  String[s.place, "zoom: $(s.zoom)", (s.centre === nothing ? () : ("centre: " * text(s.centre),))..., s.other...]

"A latitude and a longitude as a block has them, with five decimal places, which is to the nearest metre: -33.85930, 151.21320"
text(at::LatLon) = @sprintf("%.5f, %.5f", at[1], at[2])

"`at` to the five decimal places that a block keeps"
rounded(at::LatLon) = (round(at[1], digits=5), round(at[2], digits=5))

"Show `by` steps more of the place, or less with a `by` under 0. It's true when the zoom changed."
zoom!(s::Site, by::Int) = (z = clamp(s.zoom + by, ZOOMS); z == s.zoom ? false : (s.zoom = z; true))

const COORDINATES = r"^([-+]?\d+(?:\.\d+)?)\s*(?:,|\s)\s*([-+]?\d+(?:\.\d+)?)$"

"The latitude and the longitude that `place` holds, like \"-37.7701, 144.9610\", or nothing when it's an address"
coordinates(place::AbstractString) = begin
  m = match(COORDINATES, strip(place))
  m === nothing && return nothing
  lat, lon = parse(Float64, m[1]), parse(Float64, m[2])
  abs(lat) <= 90 && abs(lon) <= 180 ? (lat, lon) : nothing
end

"""
`place` as Apple's maps are asked for it: an address with one space between
its words, and a latitude and a longitude with a comma between them.
"""
query(place::AbstractString) = begin
  m = coordinates(place) === nothing ? nothing : match(COORDINATES, strip(place))
  m === nothing ? replace(strip(place), r"\s+" => " ") : "$(m[1]),$(m[2])"
end

"`text` as part of a web address: each byte that isn't a letter, a digit or one of -._~ is written as % and its number"
escaped(text::AbstractString) = join(b in UInt8('a'):UInt8('z') || b in UInt8('A'):UInt8('Z') || b in UInt8('0'):UInt8('9') || b in b"-._~" ?
                                     string(Char(b)) : "%" * uppercase(string(b, base=16, pad=2)) for b in codeunits(text))

"The web address that shows `place` in Apple Maps. A browser opens it on any computer."
link(place::AbstractString) = "https://maps.apple.com/?q=" * escaped(query(place))

"The address that opens the Maps app of the Mac at `place`"
app_link(place::AbstractString) = "maps://?q=" * escaped(query(place))

"""
The name of the files that keep the picture of `place`, without what they end
in. `centre` is the middle of the picture, or nothing when the place is. Two
blocks that name one place with other capitals or other spaces have the same
picture. The name starts with how map.swift frames a picture, so a picture
that an older map.swift framed another way isn't taken for this one.
"""
name(place, zoom, wide, tall, dark, centre=nothing) =
  "map-" * string(hash(join(("rect", lowercase(query(place)), zoom, wide, tall, dark ? "dark" : "light",
                             centre === nothing ? "" : text(centre)), '|')), base=16)

"The PNG file in `folder` that keeps the picture of `place`"
file(folder, place, zoom, wide, tall, dark, centre=nothing) = joinpath(folder, name(place, zoom, wide, tall, dark, centre) * ".png")

"The text file beside the picture at `png`, which holds the latitude, the longitude and the address of its place"
facts_file(png) = splitext(png)[1] * ".txt"

"""
What Apple has for the place of the picture at `png`: its latitude, its
longitude and its address. The address is "" when Apple has none. When the
text file beside the picture is gone, the address is "" too, and the latitude
and the longitude are nothing.
"""
facts(png) = begin
  none = (lat=nothing, lon=nothing, address="")
  path = facts_file(png)
  isfile(path) || return none
  parts = split(strip(read(path, String), ['\n', '\r']), '\t', limit=3)
  length(parts) == 3 || return none
  lat, lon = tryparse(Float64, parts[1]), tryparse(Float64, parts[2])
  (lat === nothing || lon === nothing) ? none : (lat=lat, lon=lon, address=String(strip(parts[3])))
end

"How wide the picture in the file `png` is, in px, or nothing when the file is no PNG file"
wide(png) = begin
  bytes = open(io -> read(io, 24), png)
  length(bytes) == 24 && bytes[13:16] == b"IHDR" ? Int(ntoh(reinterpret(UInt32, bytes[17:20])[1])) ÷ SCALE : nothing
end

"A picture as an address that holds the picture itself, for a page of HTML that needs no other file"
data_uri(png) = "data:image/png;base64," * base64encode(read(png))

# --- where each point of the picture is in the world ------------------------------------
#
# A map on the web is the world as Mercator drew it: a square, 256 px wide at
# zoom 0 and twice as wide at each step. A picture of a map is a rectangle of
# that square, with the map's `centre` in its middle. map.swift asks MapKit
# for that same rectangle, so these sums say exactly where a latitude and a
# longitude is in the picture. A point of the picture is in px from its top
# left corner, across and then down.

"How many px wide the map of the whole world is at `zoom`"
world(zoom) = 256.0 * 2.0^zoom

"Where a latitude and a longitude is on the map of the whole world at `zoom`, in px from its top left corner"
spot(at, zoom) = (w = world(zoom); ((at[2] + 180) / 360 * w, (1 - asinh(tan(deg2rad(at[1]))) / π) / 2 * w))

"The latitude and the longitude at a point of the map of the whole world at `zoom`. A point past the map's side edge is on its other side."
unspot(p, zoom) = (w = world(zoom); (rad2deg(atan(sinh(π * (1 - 2p[2] / w)))), mod(p[1], w) / w * 360 - 180))

"""
The zoom that a picture `wide` px by `tall` px is made at for a block that
asks for `zoom`. MapKit frames a picture exactly only when the picture is no
more than half as wide as the map of the world. So a picture that's too wide
for a low zoom is made at the lowest zoom that it fits.
"""
fit(zoom, wide, tall) = max(zoom, ceil(Int, log2(max(wide, tall, 1) / 128)))

"""
The point of a picture where the latitude and the longitude `at` is. The
picture is `wide` px by `tall` px, and `centre` is in its middle. The point
is outside the picture when `at` isn't in it.
"""
point(at, centre, zoom, wide, tall) = begin
  w = world(zoom)
  a, c = spot(at, zoom), spot(centre, zoom)
  # Across the line where east meets west, the short way round is the way that the picture shows
  (wide / 2 + mod(a[1] - c[1] + w / 2, w) - w / 2, tall / 2 + a[2] - c[2])
end

"The latitude and the longitude at the point `p` of a picture. What `point` gives for them is `p` again."
latlon(p, centre, zoom, wide, tall) = (c = spot(centre, zoom); unspot((c[1] + p[1] - wide / 2, c[2] + p[2] - tall / 2), zoom))

"The middle of a picture whose middle was `centre`, after a drag moved the map `dx` px across and `dy` px down"
moved(centre, dx, dy, zoom) = (c = spot(centre, zoom); unspot((c[1] - dx, c[2] - dy), zoom))

"`centre`, or the nearest middle that keeps a picture `tall` px tall on the map of the world, which has a top and a bottom"
held(centre, zoom, tall) = begin
  w = world(zoom)
  c = spot(centre, zoom)
  unspot((c[1], clamp(c[2], tall / 2, w - tall / 2)), zoom)
end

# --- the program that makes the picture -------------------------------------------------

const SOURCE = joinpath(@__DIR__, "map.swift")

"The program in the Kaydown app, or nothing when Kaydown runs from its source"
bundled() = begin
  Sys.isapple() || return nothing
  path = with_pool() do
    jstring(msg(msg(cls("NSBundle"), "mainBundle"), "pathForAuxiliaryExecutable:", nsstring("map")))
  end
  isfile(path) ? path : nothing
end

"What the program is compiled for: this Mac's kind of processor, and macOS 26, the first whose MapKit finds an address"
target() = "$(Sys.ARCH == :aarch64 ? "arm64" : "x86_64")-apple-macos26.0"

"Compile map.swift into the program at `out`. The app's build runs it."
compile(out) = run(`swiftc -O -parse-as-library -target $(target()) $SOURCE -o $out`)

"The folder of the Mac's caches that keeps the program that's compiled from the source"
programs() = joinpath(homedir(), "Library", "Caches", "Kaydown")

"""
The command that runs the program with `args`: the program in the app, or the
one compiled from the source, which is kept in the folder `dir`. If that isn't
compiled yet, the command compiles it first.
"""
command(args; dir=programs()) = begin
  app = bundled()
  app === nothing || return `$app $args`
  # A change to the source makes a program of a new name
  program = joinpath(dir, "map-program-" * string(hash(read(SOURCE)), base=16))
  isfile(program) && return `$program $args`
  mkpath(dir)
  # A program compiled from older source isn't needed
  foreach(f -> startswith(f, "map-program-") && rm(joinpath(dir, f), force=true), readdir(dir))
  # It's compiled to another name and renamed once it's whole, so a program that's there is always whole
  script = """swiftc -O -parse-as-library -target $(target()) "\$1" -o "\$2.part" && mv "\$2.part" "\$2" && p="\$2" && shift 2 && exec "\$p" "\$@" """
  `sh -c $script sh $SOURCE $program $args`
end

"""
Start the program that makes the picture of `place`, with `centre` in its
middle, or the place when `centre` is nothing. It writes the picture to the
file `png`, one line with the latitude, the longitude and the address of the
place to the file `out`, and why it failed to the file `err`. This gives the
program as it runs.
"""
run_program(place, zoom, wide, tall, dark, centre, png, out, err) =
  run(pipeline(command([(dark ? ["--dark"] : String[])..., (centre === nothing ? String[] : ["--centre", query(text(centre))])...,
                        string(zoom), string(wide), string(tall), png, query(place)]),
               stdout=out, stderr=err), wait=false)

"""
The function that makes a picture. It takes what `run_program` takes. It gives
a program that runs, or the number that a program which has finished already
ended with: 0 when the picture is written, 2 when there's no such place, and
1 for anything else. A test puts a function of its own here, so that it uses
neither the program nor the network.
"""
const HELPER = Ref{Any}(run_program)

"Open the address `url` with the app that the Mac uses for it. An address that starts with maps: opens the Maps app."
open_app(url) = (run(pipeline(`open $url`, stdout=devnull, stderr=devnull), wait=false); nothing)

"The function that opens the Maps app at a place, given the place's `app_link`. A test puts a function of its own here."
const OPENER = Ref{Any}(open_app)

"Open the Maps app of the Mac at `place`"
open_place(place::AbstractString) = try OPENER[](app_link(place)) catch; nothing end

# What's known of each picture that isn't kept yet, by its PNG file: the program that makes it, the number
# that the program ended with, or the state that it ended in with when that was and what to say
const jobs = Dict{String,Any}()

"What to say when Apple's maps have no such place"
const LOST = "Kaydown can't find this place. Check the address."
"What to say when the picture can't be made for now"
const FAILED = "Kaydown can't get this map now."
const NO_SWIFT = "Kaydown needs Swift to make a map. It comes with Xcode's command line tools."

"What `picture!` gives: the state of a picture, its file, what to say when it can't be made, and in how many seconds to ask again"
const Picture = @NamedTuple{state::Symbol, file::String, problem::String, wait::Float64}

"""
The picture of the map with the pin on `place`, `wide` px by `tall` px, kept
in `folder`. `centre` is the latitude and the longitude in its middle, or
nothing for the place. Its `state` is:

- `:there` when its file is kept. `facts(p.file)` has the address.
- `:coming` while the program makes it. Ask again in `wait` seconds.
- `:failed` for a minute after the program couldn't make it, as with no
  network. Kaydown tries again after that minute.
- `:lost` when Apple's maps have no such place. Kaydown doesn't try again.
- `:none` when it isn't kept and, with `start=false`, it wasn't asked for.

`problem` is what to tell the person when the state is `:failed` or `:lost`.
"""
picture!(folder, place, zoom, wide, tall, dark; centre=nothing, start=true) = begin
  png = file(folder, place, zoom, wide, tall, dark, centre)
  got(state, problem="", wait=Inf) = (state=state, file=png, problem=problem, wait=Float64(wait))
  settle!()
  isfile(png) && return got(:there)
  job = get(jobs, png, nothing)
  job isa Base.Process && return got(:coming, "", 0.2)
  if job isa Integer
    job = jobs[png] = finish!(png, job)
    isfile(png) && (delete!(jobs, png); return got(:there))
  end
  if job isa Tuple
    state, when, problem = job
    state == :lost && return got(:lost, problem)
    left = RETRY - (time() - when)
    (left > 0 || !start) && return got(:failed, problem, left > 0 ? left : Inf)
  end
  start || return got(:none)
  part, out, err = png * ".part", png * ".out", png * ".err"
  jobs[png] = try
    mkpath(folder)
    foreach(f -> rm(f, force=true), (part, out, err))
    HELPER[](place, zoom, wide, tall, dark, centre, part, out, err)
  catch
    1
  end
  # A function that has made the picture already has it kept in the same call
  jobs[png] isa Base.Process ? got(:coming, "", 0.2) : picture!(folder, place, zoom, wide, tall, dark; centre, start=false)
end

"""
Keep the picture of each program that has finished, whichever picture is asked
for now. So a picture is kept though its block asks for another by then, as
when the + is clicked twice.
"""
settle!() = for (png, job) in collect(jobs)
  (job isa Base.Process && process_exited(job)) || continue
  # A program that was stopped didn't make the picture, whatever number it ended with
  done = finish!(png, success(job) ? 0 : max(1, job.exitcode))
  done[1] == :there ? delete!(jobs, png) : (jobs[png] = done)
end

"""
The program that makes the picture at `png` ended with `code`. Keep the
picture and what Apple has for its place, or note why there's no picture. It
gives the state, when that was, and what to say.
"""
finish!(png, code) = begin
  part, out, err = png * ".part", png * ".out", png * ".err"
  state = try
    if code == 0 && isfile(part) && filesize(part) > 0
      # The text file is written first, so a picture that's kept always has it
      write(facts_file(png), isfile(out) && filesize(out) > 0 ? readline(out) : "", "\n")
      mv(part, png, force=true)
      (:there, time(), "")
    elseif code == 2
      (:lost, time(), LOST)
    else
      (:failed, time(), code == 127 ? NO_SWIFT : FAILED)
    end
  catch
    (:failed, time(), FAILED)
  end
  foreach(f -> rm(f, force=true), (part, out, err))
  state
end

"""
The picture at `png` turned out to be no picture, as a file that was cut short
is. Take it away, so that Kaydown makes it again in a minute.
"""
spoiled!(png) = begin
  rm(png, force=true)
  rm(facts_file(png), force=true)
  jobs[png] = (:failed, time(), FAILED)
  nothing
end
