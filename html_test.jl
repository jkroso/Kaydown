# Tests for the page of HTML that ⌘⇧E saves. Run them with
# `julia --project=. html_test.jl`.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window

@use "./main" => K
const px = K.px

const page = joinpath(mktempdir(), "diagrams.md")
write(page, """
# Diagrams

```mermaid
flowchart LR
  A[Write] --> B{Is it clear?}
  B -- Yes --> C([Send])
  B -- No --> A
```

```mermaid
nonsense here
```

```mermaid
flowchart LR
  X --> Y
""")
const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1300px))

@testset "a mermaid block is a picture in the page of HTML" begin
  before = deepcopy(K.colours)
  out = K.page_html(e)
  # The diagram is drawn, at its size, with no line that says it's XML
  @test count("<div class=\"diagram\">", out) == 1
  @test occursin(r"<svg viewBox=\"0 0 \d+ \d+\"", out)
  @test !occursin("<?xml", out)
  # Code that can't be drawn, and a block that isn't closed, show as code, as they do in the editor
  @test occursin("<pre><code class=\"language-mermaid\">nonsense here</code></pre>", out)
  @test occursin("<pre><code class=\"language-mermaid\">flowchart LR\n  X --&gt; Y", out)
  # The window keeps its colours
  @test all(n -> getfield(K.colours, n) == getfield(before, n), fieldnames(typeof(before)))
end

exit()
