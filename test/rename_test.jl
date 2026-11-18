# Tests that the app's folders in ~/Library move from its old name, Kaydown, to
# its new name, Ladder. Run them with `julia -O0 --project=. test/rename_test.jl`.
# They use a home folder of their own, so they don't touch the real one.

@use Test: @test, @testset
@use "../main" => K

@testset "the folders of the app's old name get its new name" begin
  home = mktempdir()
  old = joinpath(home, "Library", "Application Support", "Kaydown")
  new = joinpath(home, "Library", "Application Support", "Ladder")
  mkpath(joinpath(old, "Welcome"))
  write(joinpath(old, "settings"), "theme=night\n")
  mkpath(joinpath(home, "Library", "Caches", "Kaydown", "media"))
  K.move_old_folders!(home)
  @test read(joinpath(new, "settings"), String) == "theme=night\n"
  @test isdir(joinpath(new, "Welcome")) && !ispath(old)
  @test isdir(joinpath(home, "Library", "Caches", "Ladder", "media"))
  @test !ispath(joinpath(home, "Library", "Caches", "Kaydown"))
  # A folder that has the new name already stays as it is, and so does the old one
  mkpath(old)
  write(joinpath(old, "settings"), "theme=paper\n")
  K.move_old_folders!(home)
  @test read(joinpath(new, "settings"), String) == "theme=night\n"
  @test read(joinpath(old, "settings"), String) == "theme=paper\n"
  # A home with neither folder gets neither
  empty = mktempdir()
  K.move_old_folders!(empty)
  @test !ispath(joinpath(empty, "Library"))
end
