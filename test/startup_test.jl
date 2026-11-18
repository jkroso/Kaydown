# Tests for the startup page of main.jl: the page that Ladder writes the first
# time, the Julia code of the page that runs when Ladder starts, and what the
# window says when that code fails. Run them with
# `julia -O0 --project=. test/startup_test.jl`. The page is in a folder of the
# test's own, and the window isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
const px = K.px

K.HOME[] = joinpath(mktempdir(), "Home")
const page = K.startup_page()

@testset "the first time, Ladder writes the page, and then the page is yours" begin
  @test page == joinpath(K.HOME[], "startup.md") && !isfile(page)
  @test K.startup_page!() == page && isfile(page)
  lines = split(read(page, String), '\n')
  @test lines[1] == "# Home" && any(l -> occursin("```julia", l), lines)
  # Its links go to Ladder's own pages, by the way there from the page's folder
  links = [m[1] for m in eachmatch(r"\]\(([^)]+)\)", read(page, String))]
  @test length(links) == 3 && all(l -> isfile(abspath(K.HOME[], K.unescaped(l))), links)
  @test abspath(K.HOME[], K.unescaped(links[1])) == joinpath(K.pages_dir[], "welcome.md")
  # A page that's there is never written again
  write(page, "# Mine\n")
  @test K.startup_page!() == page && read(page, String) == "# Mine\n"
end

@testset "the page shows as any page does, and its code as code" begin
  rm(page)
  K.startup_page!()
  e = K.build_editor(page)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  @test e.buf.lines[1] == "# Home" && !e.buf.fixed && isempty(K.problems)
end

@testset "the code of the page runs when Ladder starts, from the top, in one module" begin
  write(page, """
    # Home

    Words between the blocks are only words.

    ```julia
    const made = [1]
    add(x) = push!(made, x)
    ```

    ```text
    this isn't Julia, so it doesn't run: error("no")
    ```

    ```julia
    add(2)
    const ladder = Ladder
    @use Dates: Date
    const day = Date(2026, 11, 18)
    ```
    """)
  m = K.run_startup!()
  @test m.made == [1, 2] && K.STARTUP[][1] == ""
  # `Ladder` is Ladder itself, so the code can call its functions and add to its tables
  @test m.ladder === K && m.Ladder.startup_page() == page
  @test string(m.day) == "2026-11-18"
  # Each start has a module of its own
  @test K.run_startup!() !== m
  # A page that's gone, and a page with no code, run nothing and fail nothing
  write(page, "# Home\n")
  K.run_startup!()
  @test K.STARTUP[][1] == ""
  @test (K.run_startup!(joinpath(K.HOME[], "none.md")); K.STARTUP[][1] == "")
end

@testset "code that fails stops what's after it, and the window says which line failed" begin
  write(page, """
    # Home

    ```julia
    const before = 1
    ```

    ```julia
    const here = 2
    nothing_called_this()
    const after = 3
    ```

    ```julia
    const later = 4
    ```
    """)
  m = K.run_startup!()
  words, since = K.STARTUP[]
  @test isdefined(m, :before) && isdefined(m, :here) && !isdefined(m, :after) && !isdefined(m, :later)
  @test startswith(words, "Line 9 of startup.md: ") && occursin("nothing_called_this", words) && time() - since < 5
  e = K.build_editor(page)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  @test any(p -> p.key == :startup, popups(w))
  # The words go after a while, and don't come back
  K.STARTUP[] = (words, since - K.STARTUP_SHOWS - 1)
  frame(w); frame(w)
  @test !any(p -> p.key == :startup, popups(w))
  # A start with nothing wrong says nothing
  write(page, "# Home\n")
  K.run_startup!()
  frame(w); frame(w)
  @test !any(p -> p.key == :startup, popups(w))
end
