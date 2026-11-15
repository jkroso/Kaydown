# Tests for a line that holds only a video file. See "video in the text" in
# main.jl. Run them with `julia --project=. video_test.jl`. They need ffmpeg to
# make the video, and macOS to play it.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/media" span ready

@use "./main" => K
const px = K.px

@testset "a link names part of a file" begin
  @test K.media_part("walk.mov") == ("walk.mov", 0.0, Inf)
  @test K.media_part("walk.mov#t=61,86") == ("walk.mov", 61.0, 86.0)
  @test K.media_part("walk.mov#t=104,135.9") == ("walk.mov", 104.0, 135.9)
  # With no end, the part goes on to the end of the file. With no start, it starts at the start.
  @test K.media_part("walk.mov#t=61") == ("walk.mov", 61.0, Inf)
  @test K.media_part("walk.mov#t=,20") == ("walk.mov", 0.0, 20.0)
  # A time can be written as a clock shows it
  @test K.media_part("walk.mov#t=npt:1:01,0:01:26.5") == ("walk.mov", 61.0, 86.5)
  # An end before the start, and words that aren't times, are left out
  @test K.media_part("walk.mov#t=30,10") == ("walk.mov", 30.0, Inf)
  @test K.media_part("walk.mov#t=soon,later") == ("walk.mov", 0.0, Inf)
end

if Sys.isapple() && Sys.which("ffmpeg") !== nothing
  const dir = mktempdir()
  run(pipeline(`ffmpeg -loglevel error -y -f lavfi -i testsrc=duration=2:size=90x160:rate=10 -pix_fmt yuv420p $(joinpath(dir, "walk.mp4"))`, devnull))
  const page = joinpath(dir, "walk.md")
  write(page, """
  # A walk through

  ![The lounge](walk.mp4#t=0.5,1.2)

  ![The rest](walk.mp4#t=1.2)

  ![Not there](gone.mp4#t=0,1)

  The end.
  """)
  const e = K.build_editor(page)
  const w = Window(e, size=(1000px, 1200px))
  frames(n=2) = foreach(_ -> frame(w), 1:n)
  frames()

  # macOS reads a file while the app's event loop runs. A test has no window
  # open, so it runs the loop itself for a moment at a time.
  const CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
  loop(seconds) = ccall((:CFRunLoopRunInMode, CoreFoundation), Int32, (Ptr{Cvoid}, Float64, UInt8),
                        unsafe_load(cglobal((:kCFRunLoopDefaultMode, CoreFoundation), Ptr{Cvoid})), seconds, 0)

  "The video player that line `i` shows, or nothing"
  player(i) = begin
    it = K.item(e, i)
    it.first == i && it.content isa K.Live && it.content.node isa K.Shown && it.content.node.value isa K.VideoPlayer ? it.content.node.value : nothing
  end

  @testset "a line that holds only a video shows a player of the part that it names" begin
    lounge, rest = player(3), player(5)
    @test lounge !== nothing && rest !== nothing
    @test (lounge.from, lounge.to) == (0.5, 1.2) && (rest.from, rest.to) == (1.2, Inf)
    # Once macOS has read the file, each player is at the start of its part
    stop = time() + 5
    while time() < stop && !(ready(lounge.media) && abs(position(lounge.media) - 0.5) < 0.05)
      frames(1); loop(0.02)
    end
    @test span(lounge.media) == (0.5, 1.2)
    @test abs(position(lounge.media) - 0.5) < 0.05
    # A file that isn't there shows the line's text
    @test player(7) === nothing && K.item(e, 7).content isa K.Flow
  end

  @testset "the page of HTML has a player for each video" begin
    out = K.page_html(e)
    @test occursin("<video controls preload=\"metadata\" src=\"walk.mp4#t=0.5,1.2\" title=\"The lounge\"></video>", out)
    @test !occursin("<img src=\"walk.mp4", out)
  end
end
