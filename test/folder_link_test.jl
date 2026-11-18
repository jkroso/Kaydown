# Tests for a link to a folder: it shows the folder in the sidebar. See
# `follow!` in main.jl. Run them with
# `julia -O0 --project=. test/folder_link_test.jl`. They click in a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))
mkpath(joinpath(dir, "pages"))
mkpath(joinpath(dir, "My mail", "Inbox"))
mkpath(joinpath(dir, "Thing.app", "Contents"))
write(joinpath(dir, "pages", "home.md"), "# Home\n\n[Email](../My%20mail) and [the inbox](../My%20mail/Inbox/)\n")
write(joinpath(dir, "pages", "other.md"), "# Other\n")
write(joinpath(dir, "My mail", "Inbox", "note.md"), "# A note\n")

const e = K.build_editor(joinpath(dir, "pages", "home.md"))
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()

@testset "a link to a folder shows the folder in the sidebar, and the page stays" begin
  @test !e.panel
  K.follow!(e, "../My%20mail"); frames()
  @test e.panel && e.folder == joinpath(dir, "My mail") && e.buf.path == joinpath(dir, "pages", "home.md")
  @test basename.(e.listed) == ["Inbox"]
  # A folder's path can end with a /, and the sidebar stays open
  K.follow!(e, "../My%20mail/Inbox/"); frames()
  @test e.panel && e.folder == joinpath(dir, "My mail", "Inbox") && basename.(e.listed) == ["note.md"]
  # A link to a file still shows the file
  K.follow!(e, "other.md"); frames()
  @test e.buf.path == joinpath(dir, "pages", "other.md")
end

@testset "a path can start at the home folder" begin
  # The test's own folder, written from the home folder when it's inside it, shows as any folder does
  home = homedir()
  inside = mktempdir(home, prefix=".ladder-test-")
  try
    write(joinpath(inside, "page.md"), "# In the home folder\n")
    K.follow!(e, "~/" * basename(inside)); frames()
    @test e.folder == inside
    K.follow!(e, "~/" * basename(inside) * "/page.md"); frames()
    @test e.buf.path == joinpath(inside, "page.md")
  finally
    rm(inside, recursive=true, force=true)
  end
end

@testset "a folder that the Finder shows as one file isn't listed" begin
  @test K.ispackage(joinpath(dir, "Thing.app")) && !K.ispackage(joinpath(dir, "My mail")) && !K.ispackage(joinpath(dir, "none"))
end
