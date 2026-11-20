# Tests for film.jl, which makes a short film of Ladder from a window that
# isn't on the screen. Run them with `julia -O0 --project=. test/film_test.jl`.
# They make a film of one short scene, which takes a few seconds, and need
# ffmpeg, as the film does. Without ffmpeg they check nothing.

@use Test: @test, @testset
@use "../film" => F

if Sys.which("ffmpeg") === nothing
  @info "ffmpeg isn't on this Mac, so the film isn't tested"
else
  @testset "a film of one scene" begin
    out = joinpath(mktempdir(), "short.mp4")
    ticked = Ref(false)
    # The scene says some words, and ticks a to-do item with the film's mouse
    short(f) = begin
      F.say!(f, "A test")
      F.hold!(f, 0.3)
      F.click!(f, F.box(f, "Lay the new pipe"); seconds=0.3)
      ticked[] = startswith(f.e.buf.lines[F.line(f, "Lay the new pipe")], "- [x]")
    end
    made, frames = F.make(out; scenes=[short], keep=true)
    pictures = sort(readdir(frames))
    @test made == out && isfile(out) && filesize(out) > 5_000
    @test ticked[]
    # A picture for each frame, in their order, each as big as the window at the film's scale
    @test length(pictures) >= 15 && pictures[1] == "00001.png" && pictures[end] == lpad(length(pictures), 5, '0') * ".png"
    header = read(joinpath(frames, pictures[1]))[17:24]
    @test (ntoh(reinterpret(UInt32, header[1:4])[1]), ntoh(reinterpret(UInt32, header[5:8])[1])) == (F.WIDE * F.SCALE, F.TALL * F.SCALE)
    # The film is as long as its pictures are many
    seconds = parse(Float64, strip(read(`ffprobe -v error -show_entries format=duration -of csv=p=0 $out`, String)))
    @test isapprox(seconds, length(pictures) / F.FPS, atol=0.2)
    rm(dirname(frames), recursive=true, force=true)
  end
end
