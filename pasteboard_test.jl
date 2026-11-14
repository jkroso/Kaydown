# Tests for pasteboard.jl. Run them with `julia --project=. pasteboard_test.jl`.
# They use a clipboard of their own, so the Mac's clipboard stays as it is.

@use Test: @test, @testset
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring
@use "./pasteboard" => P

const Object = Ptr{Cvoid}
const pb = P.private_board()
clear() = msg(pb, "clearContents")
put_text(kind, s) = ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object, Object), pb, sel("setString:forType:"), nsstring(s), nsstring(kind))
put_data(kind, bytes) = begin
  data = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
  ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object, Object), pb, sel("setData:forType:"), data, nsstring(kind))
end

const PNG = read(joinpath(@__DIR__, "app", "icon.png"))
const PDF = Vector{UInt8}("%PDF-1.4")

@testset "what the clipboard holds" begin
  clear()
  @test P.text(pb) == "" && isempty(P.files(pb)) && P.media(pb) === nothing
  clear(); put_text("public.utf8-plain-text", "héllo\nworld")
  @test P.text(pb) == "héllo\nworld"
  @test P.media(pb) === nothing
  clear(); put_data("public.png", PNG)
  @test P.media(pb) == ("png", PNG)
  @test P.text(pb) == ""
  # A picture that's there as a PDF too is taken as a PNG
  clear(); put_data("com.adobe.pdf", PDF); put_data("public.png", PNG)
  @test P.media(pb)[1] == "png"
  clear(); put_data("com.adobe.pdf", PDF)
  @test P.media(pb) == ("pdf", PDF)
end

@testset "a TIFF picture comes out as a PNG" begin
  dir = mktempdir()
  tiff = joinpath(dir, "icon.tiff")
  run(pipeline(`sips -s format tiff $(joinpath(@__DIR__, "app", "icon.png")) --out $tiff`, stdout=devnull, stderr=devnull))
  clear(); put_data("public.tiff", read(tiff))
  ext, bytes = P.media(pb)
  @test ext == "png"
  @test bytes[1:8] == PNG[1:8]
  rm(dir, recursive=true)
end

@testset "files that were copied in the Finder" begin
  dir = mktempdir()
  file = joinpath(dir, "clip one.mp4")
  write(file, "x")
  clear(); put_text("public.file-url", "file://" * replace(file, " " => "%20")); put_text("public.utf8-plain-text", "clip one.mp4")
  @test P.files(pb) == [realpath(file)] || P.files(pb) == [file]
  # A file that's gone isn't listed
  rm(dir, recursive=true)
  @test isempty(P.files(pb))
end
