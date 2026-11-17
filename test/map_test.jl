# Tests for map.jl. Run them with `julia -O0 --project=. test/map_test.jl`.
# They use neither the network nor the program that makes a picture of a map:
# map_fake.jl takes the program's place.

@use Test: @test, @testset
@use "../map" => M
@use "./map_fake" => Fake

M.HELPER[] = Fake.helper
M.OPENER[] = Fake.opener
const dir = mktempdir()
const WATTLE = "8 Wattle Street, Brunswick VIC 3056"
picture(place, zoom=15, wide=720; dark=false, centre=nothing, start=true) = M.picture!(dir, place, zoom, wide, M.TALL, dark; centre, start)

@testset "reading and writing" begin
  s = M.site([WATTLE])
  @test s.place == WATTLE && s.zoom == M.ZOOM == 15 && isempty(s.other)
  @test M.written(s) == [WATTLE, "zoom: 15"]
  # The first line that isn't a setting is the place, wherever the setting is
  s = M.site(["", "  Zoom : 17 ", "", "  $WATTLE  ", "The back gate", "colour: red"])
  @test s.place == WATTLE && s.zoom == 17 && s.other == ["The back gate", "colour: red"]
  @test M.written(s) == [WATTLE, "zoom: 17", "The back gate", "colour: red"]
  @test M.site(M.written(s)).place == WATTLE && M.written(M.site(M.written(s))) == M.written(s)
  # The middle of the map is a line of its own. Kaydown writes "centre", and reads "center" as the same word.
  s = M.site([WATTLE, "Center:  -37.7681 , 144.9426", "zoom: 16"])
  @test s.place == WATTLE && s.centre == (-37.7681, 144.9426) && s.zoom == 16 && isempty(s.other)
  @test M.written(s) == [WATTLE, "zoom: 16", "centre: -37.76810, 144.94260"]
  @test M.site(M.written(s)).centre == (-37.7681, 144.9426) && M.site(["centre: -37.7681, 144.9426", WATTLE]).place == WATTLE
  # A middle that's no latitude and longitude is left out, and the place is in the middle
  @test M.site([WATTLE, "centre: the park"]).centre === nothing && M.site([WATTLE, "centre: 95, 10"]).centre === nothing
  @test M.written(M.site([WATTLE, "centre: the park"])) == [WATTLE, "zoom: 15"]
  @test M.text((-33.8593, 151.2132)) == "-33.85930, 151.21320" && M.rounded((-33.859314, 151.213187)) == (-33.85931, 151.21319)
  @test M.coordinates(M.text((-33.8593, 151.2132))) == (-33.8593, 151.2132)
  # A zoom that's no number is the usual one, and one that's too big or too small is the nearest that a map has
  @test M.site([WATTLE, "zoom: far"]).zoom == 15 && M.site([WATTLE, "zoom:"]).zoom == 15
  @test M.site([WATTLE, "zoom: 99"]).zoom == last(M.ZOOMS) && M.site([WATTLE, "zoom: -3"]).zoom == first(M.ZOOMS)
  @test M.site([WATTLE, "zoom: 15.6"]).zoom == 16
  # An empty block has no place, and stays empty
  @test isempty(M.site(String[]).place) && isempty(M.written(M.site(["", "zoom: 12"])))
  # An address with a colon in it is still an address
  @test M.site(["Lot 4: Smith Road, Kew"]).place == "Lot 4: Smith Road, Kew"
end

@testset "the zoom" begin
  s = M.site([WATTLE])
  @test M.zoom!(s, 1) && s.zoom == 16 && M.zoom!(s, -2) && s.zoom == 14
  s.zoom = last(M.ZOOMS)
  @test !M.zoom!(s, 1) && s.zoom == last(M.ZOOMS)
  s.zoom = first(M.ZOOMS)
  @test !M.zoom!(s, -1) && s.zoom == first(M.ZOOMS)
end

@testset "a latitude and a longitude" begin
  @test M.coordinates("-37.7701, 144.9610") == (-37.7701, 144.961)
  @test M.coordinates(" -37.7701,144.9610 ") == (-37.7701, 144.961) && M.coordinates("-37.7701 144.9610") == (-37.7701, 144.961)
  @test M.coordinates("+12, 34") == (12.0, 34.0)
  @test M.coordinates(WATTLE) === nothing && M.coordinates("3056") === nothing && M.coordinates("") === nothing
  # A latitude is no more than 90, and a longitude no more than 180
  @test M.coordinates("144.9610, -37.7701") === nothing && M.coordinates("12, 181") === nothing
  @test M.query("-37.7701 ,  144.9610") == "-37.7701,144.9610" && M.query("  8  Wattle   Street ") == "8 Wattle Street"
end

@testset "the link to Apple Maps" begin
  @test M.link(WATTLE) == "https://maps.apple.com/?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056"
  @test M.app_link(WATTLE) == "maps://?q=8%20Wattle%20Street%2C%20Brunswick%20VIC%203056"
  @test M.link("-37.7701, 144.9610") == "https://maps.apple.com/?q=-37.7701%2C144.9610"
  # The characters that mean something in a web address are escaped, and so is each byte of a letter that isn't ASCII
  @test M.escaped("a&b=c?d#e/f+g\"h<i>") == "a%26b%3Dc%3Fd%23e%2Ff%2Bg%22h%3Ci%3E"
  @test M.escaped("Café 5%") == "Caf%C3%A9%205%25" && M.escaped("A-z_0.9~") == "A-z_0.9~"
  M.open_place(WATTLE)
  @test Fake.opened == [M.app_link(WATTLE)]
end

@testset "the name of a picture's file" begin
  name(place=WATTLE, zoom=15, wide=720, tall=280, dark=false) = M.name(place, zoom, wide, tall, dark)
  @test startswith(name(), "map-") && name() == name()
  # The place, the zoom, the size and dark or light each make it another picture
  others = [name("9 Wattle Street"), name(WATTLE, 16), name(WATTLE, 15, 700), name(WATTLE, 15, 720, 300), name(WATTLE, 15, 720, 280, true),
            M.name(WATTLE, 15, 720, 280, false, (-37.7681, 144.9426)), M.name(WATTLE, 15, 720, 280, false, (-37.7681, 144.9427))]
  @test allunique([name(); others])
  # A middle that the block writes the same way is the same picture
  @test M.name(WATTLE, 15, 720, 280, false, (-37.7681, 144.9426)) == M.name(WATTLE, 15, 720, 280, false, (-37.768100001, 144.9426))
  @test M.file(dir, WATTLE, 15, 720, 280, false, (-37.7681, 144.9426)) == joinpath(dir, M.name(WATTLE, 15, 720, 280, false, (-37.7681, 144.9426)) * ".png")
  # Capitals and spaces don't
  @test name("8 wattle  street, BRUNSWICK vic 3056 ") == name() && name("-37.7701,144.9610") == name("-37.7701, 144.9610")
  @test M.file(dir, WATTLE, 15, 720, 280, false) == joinpath(dir, name() * ".png")
  @test M.facts_file(joinpath(dir, "map-1.png")) == joinpath(dir, "map-1.txt")
end

@testset "a picture is made once, and kept" begin
  empty!(Fake.calls)
  # A picture that isn't kept and isn't asked for
  @test picture(WATTLE, start=false).state == :none && isempty(Fake.calls)
  p = picture(WATTLE)
  @test p.state == :there && isfile(p.file) && p.file == M.file(dir, WATTLE, 15, 720, 280, false)
  @test Fake.calls == [(place=WATTLE, zoom=15, wide=720, tall=280, dark=false, centre=nothing)]
  @test M.facts(p.file) == (lat=-37.769417, lon=144.940514, address="$WATTLE, Australia")
  @test read(p.file)[1:4] == UInt8[0x89, 0x50, 0x4e, 0x47]
  # The next time it's there at once, and nothing is asked of the program
  @test picture(WATTLE).state == :there && picture("8 wattle street, brunswick VIC 3056").state == :there && length(Fake.calls) == 1
  # Nothing is left beside it but the text file
  @test sort(readdir(dir)) == sort([basename(p.file), basename(M.facts_file(p.file))])
  # Another zoom, another size and a dark page are other pictures
  @test picture(WATTLE, 16).file != p.file && picture(WATTLE, 15, 500).file != p.file && picture(WATTLE, dark=true).file != p.file
  @test length(Fake.calls) == 4 && Fake.calls[end].dark
  # A picture with another middle is another picture, of the same place
  m = picture(WATTLE, centre=(-37.7681, 144.9426))
  @test m.state == :there && m.file != p.file && Fake.calls[end].centre == (-37.7681, 144.9426) && M.facts(m.file) == M.facts(p.file)
  @test picture(WATTLE, centre=(-37.7681, 144.9426)).state == :there && length(Fake.calls) == 5
  # A latitude and a longitude get the address that Apple has for them
  c = picture("-37.7701, 144.9610")
  @test c.state == :there && M.facts(c.file) == (lat=-37.7701, lon=144.961, address="1 Found Street, Brunswick VIC 3056, Australia")
  @test startswith(M.data_uri(p.file), "data:image/png;base64,iVBOR") && M.wide(p.file) == 720 && M.wide(M.facts_file(p.file)) === nothing
  # A picture whose text file is gone has no address
  rm(M.facts_file(c.file))
  @test M.facts(c.file) == (lat=nothing, lon=nothing, address="")
end

@testset "a picture that takes a while" begin
  p = picture("12 Slow Street, Kew")
  @test p.state == :coming && p.wait < 1 && !isfile(p.file)
  n = length(Fake.calls)
  @test picture("12 Slow Street, Kew").state == :coming && length(Fake.calls) == n   # it's asked for once
  t = time()
  while picture("12 Slow Street, Kew").state == :coming && time() - t < 10
    sleep(0.05)
  end
  p = picture("12 Slow Street, Kew")
  @test p.state == :there && isfile(p.file) && M.facts(p.file).address == "12 Slow Street, Kew, Australia"
  @test !haskey(M.jobs, p.file) && !any(f -> endswith(f, ".part") || endswith(f, ".out") || endswith(f, ".err"), readdir(dir))
  # A picture is kept though its block asks for another by the time it's made
  q = picture("14 Slow Street, Kew")
  @test q.state == :coming && !isfile(q.file)
  sleep(Fake.SLOW + 0.4)
  @test picture(WATTLE).state == :there && isfile(q.file) && !haskey(M.jobs, q.file)
  @test !any(f -> endswith(f, ".part") || endswith(f, ".out") || endswith(f, ".err"), readdir(dir))
end

@testset "a place that isn't found, and no network" begin
  n = length(Fake.calls)
  p = picture("1 Nowhere Road")
  @test p.state == :lost && p.problem == M.LOST && !isfile(p.file)
  # Kaydown doesn't ask again for a place that Apple's maps don't have
  @test picture("1 Nowhere Road").state == :lost && length(Fake.calls) == n + 1
  p = picture("1 Offline Road")
  @test p.state == :failed && p.problem == M.FAILED && 0 < p.wait <= M.RETRY && !isfile(p.file)
  @test picture("1 Offline Road").state == :failed && length(Fake.calls) == n + 2
  # After a minute it tries again
  M.jobs[p.file] = (:failed, time() - M.RETRY - 1, M.FAILED)
  @test picture("1 Offline Road", start=false).state == :failed && length(Fake.calls) == n + 2
  @test picture("1 Offline Road").state == :failed && length(Fake.calls) == n + 3
  # A function that throws, and one that says it made a picture and made none, fail too
  M.HELPER[] = (args...) -> error("no program")
  @test picture("2 Wattle Street").state == :failed
  M.HELPER[] = (args...) -> 0
  @test picture("3 Wattle Street").state == :failed
  # Without Swift, the program can't be compiled, and the shell ends with 127
  M.HELPER[] = (args...) -> 127
  @test picture("4 Wattle Street").problem == M.NO_SWIFT
  M.HELPER[] = Fake.helper
  # A picture that turned out to be no picture is taken away, and made again later
  p = picture("5 Wattle Street")
  M.spoiled!(p.file)
  @test !isfile(p.file) && !isfile(M.facts_file(p.file)) && picture("5 Wattle Street").state == :failed
  @test !any(f -> endswith(f, ".part") || endswith(f, ".out") || endswith(f, ".err"), readdir(dir))
end

@testset "where a latitude and a longitude is in a picture" begin
  sydney, quito = (-33.8593, 151.2132), (0.0, -78.5)
  for (centre, zoom, wide, tall) in ((sydney, 15, 720, 280), (quito, 15, 720, 280), (sydney, 3, 1000, 280), (sydney, 19, 400, 280), ((60.0, 10.0), 9, 1200, 280))
    # The middle of the picture is the centre
    @test all(isapprox.(M.point(centre, centre, zoom, wide, tall), (wide / 2, tall / 2), atol=1e-6))
    @test all(isapprox.(M.latlon((wide / 2, tall / 2), centre, zoom, wide, tall), centre, atol=1e-9))
    # A point and back again gives the same point, also for a point that's outside the picture
    for p in ((0.0, 0.0), (wide, tall), (123.4, 56.7), (-300.0, 900.0))
      @test all(isapprox.(M.point(M.latlon(p, centre, zoom, wide, tall), centre, zoom, wide, tall), p, atol=1e-5))
    end
    # East is to the right and has a greater longitude. North is up and has a greater latitude.
    east, north = M.latlon((wide / 2 + 100, tall / 2), centre, zoom, wide, tall), M.latlon((wide / 2, tall / 2 - 100), centre, zoom, wide, tall)
    @test east[2] > centre[2] && east[1] ≈ centre[1] && north[1] > centre[1] && north[2] ≈ centre[2]
  end
  # At zoom 15 the world is 256 × 2^15 px wide, so a px is 360 / 8388608 of a degree of longitude everywhere
  per = 360 / 8388608
  @test M.world(15) == 8388608 && M.latlon((460, 140), quito, 15, 720, 280)[2] ≈ quito[2] + 100per
  @test M.latlon((460, 140), sydney, 15, 720, 280)[2] ≈ sydney[2] + 100per
  # At the equator a px is as much latitude as longitude. Near latitude -34 it's less, by the cosine of the latitude.
  @test isapprox(M.latlon((360, 40), quito, 15, 720, 280)[1], 100per, rtol=1e-4)
  @test isapprox(M.latlon((360, 40), sydney, 15, 720, 280)[1] - sydney[1], 100per * cosd(33.8593), rtol=1e-3)
  # What MapKit gives for these: its own point for Sydney, and where it drew a place 100 px east and 50 px north of the middle
  @test all(isapprox.(M.spot(sydney, 20), (246970462.1533867, 161077506.28938088), atol=1e-4))
  @test all(isapprox.(M.point((-33.85751812, 151.21749153), sydney, 15, 720, 280), (460, 90), atol=0.001))
  # A drag moves the map with the mouse: the middle goes the other way
  moved = M.moved(sydney, 100, -50, 15)
  @test all(isapprox.(M.point(sydney, moved, 15, 720, 280), (460, 90), atol=1e-6)) && moved[2] < sydney[2] && moved[1] < sydney[1]
  @test all(isapprox.(M.moved(moved, -100, 50, 15), sydney, atol=1e-9))
  # The map of the world has a top and a bottom, and a picture stays between them
  top = M.held((89.9, 10.0), 3, 280)
  @test top[1] < 85.1 && top[2] ≈ 10.0 && M.spot(top, 3)[2] ≈ 140 && all(isapprox.(M.held(sydney, 3, 280), sydney, atol=1e-9))
  # Across the line where east meets west, the short way round is the way that the picture shows
  @test all(isapprox.(M.point((-17.0, -179.9), (-17.0, 179.9), 10, 720, 280), (360 + 0.2 / 360 * M.world(10), 140), atol=1e-6))
  @test M.latlon((360 + 0.2 / 360 * M.world(10), 140), (-17.0, 179.9), 10, 720, 280)[2] ≈ -179.9
  # A picture is made at the block's zoom, or at the lowest zoom whose map of the world is twice as wide as the picture
  @test M.fit(15, 720, 280) == 15 && M.fit(3, 1024, 280) == 3 && M.fit(3, 1025, 280) == 4 && M.fit(3, 2048, 280) == 4 && M.fit(3, 2100, 280) == 5
end

@testset "the command that runs the program" begin
  # From the source, the program is compiled first when it isn't there, and then given the place
  programs = mktempdir()
  write(joinpath(programs, "map-program-old"), "")
  cmd = M.command(["15", "720", "280", "out.png", WATTLE], dir=programs)
  @test cmd.exec[end] == WATTLE && cmd.exec[end-4:end-1] == ["15", "720", "280", "out.png"]
  @test occursin(joinpath(programs, "map-program-"), join(cmd.exec, " ")) && cmd.exec[1] == "sh"
  # A program that was compiled from older source is taken away
  @test isempty(readdir(programs))
  # A program that's there is run as it is
  program = cmd.exec[end-5]
  write(program, "")
  @test M.command(["15"], dir=programs).exec == [program, "15"]
  @test isfile(M.SOURCE) && occursin("apple-macos26.0", M.target())
end
