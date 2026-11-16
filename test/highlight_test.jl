# Tests for the colours of the parts of a line of code. See highlight.jl. Run
# them with `julia -O0 --project=. test/highlight_test.jl`.

@use Test: @test, @testset
@use "../highlight" tokens

"Each part of `line` in `lang` as text => kind, without the plain parts that are only spaces"
parts(line, lang="julia") = [t.text => t.kind for t in tokens(line, lang) if !(t.kind == :plain && all(isspace, t.text))]

"True when the tokens of `line` hold all of its characters, in order, at the right columns"
whole(line, lang="julia") = begin
  ts = tokens(line, lang)
  join(t.text for t in ts) == line && all(t.col == sum(length(u.text) for u in ts[1:k-1]; init=0) for (k, t) in enumerate(ts))
end

@testset "a string with no code in it is one part" begin
  @test parts("x = \"plain text\"") == ["x = " => :plain, "\"plain text\"" => :string]
  @test parts("\"costs \\\$5\"") == ["\"costs \\\$5\"" => :string]
  @test parts("\"a \$ b\"") == ["\"a \$ b\"" => :string]
end

@testset "code in a Julia string has the colours of code" begin
  @test parts("\"Clicked \$(c.count) times\"") ==
    ["\"Clicked " => :string, "\$(" => :keyword, "c.count" => :plain, ")" => :keyword, " times\"" => :string]
  @test parts("\"\$(round(Int, 100m.done))%\"") ==
    ["\"" => :string, "\$(" => :keyword, "round" => :call, "(" => :plain, "Int" => :type, ", " => :plain,
     "100" => :number, "m.done)" => :plain, ")" => :keyword, "%\"" => :string]
  @test parts("\"hello \$name!\"") == ["\"hello " => :string, "\$" => :keyword, "name!" => :plain, "\"" => :string]
  @test parts("\"\$x.y\"") == ["\"" => :string, "\$" => :keyword, "x" => :plain, ".y\"" => :string]
  @test parts("`ls \$dir`") == ["`ls " => :string, "\$" => :keyword, "dir" => :plain, "`" => :string]
end

@testset "a string in the code of a string" begin
  @test parts("\"a \$(join(xs, \", \")) b\"") ==
    ["\"a " => :string, "\$(" => :keyword, "join" => :call, "(xs, " => :plain, "\", \"" => :string,
     ")" => :plain, ")" => :keyword, " b\"" => :string]
  @test parts("\"\$(f(\"\$y\"))\"") ==
    ["\"" => :string, "\$(" => :keyword, "f" => :call, "(" => :plain, "\"" => :string, "\$" => :keyword,
     "y" => :plain, "\"" => :string, ")" => :plain, ")" => :keyword, "\"" => :string]
end

@testset "a Julia string with a name in front has no code" begin
  @test parts("colorant\"rgb(150,84,40)\"") == ["colorant" => :plain, "\"rgb(150,84,40)\"" => :string]
  @test parts("raw\"\$x\"") == ["raw" => :plain, "\"\$x\"" => :string]
  @test parts("r\"^\$\"") == ["r" => :plain, "\"^\$\"" => :string]
end

@testset "a string that doesn't close" begin
  @test parts("\"a \$(x") == ["\"a " => :string, "\$(" => :keyword, "x" => :plain]
  @test parts("\"a \$(x) b") == ["\"a " => :string, "\$(" => :keyword, "x" => :plain, ")" => :keyword, " b" => :string]
  @test parts("\"a \$") == ["\"a \$" => :string]
end

@testset "code in strings of other languages" begin
  @test parts("`Hi \${user.name}!`", "js") ==
    ["`Hi " => :string, "\${" => :keyword, "user.name" => :plain, "}" => :keyword, "!`" => :string]
  @test parts("\"Hi \${user.name}!\"", "js") == ["\"Hi \${user.name}!\"" => :string]
  @test parts("f\"{n + 1} {{x}}\"", "python") ==
    ["f" => :plain, "\"" => :string, "{" => :keyword, "n + " => :plain, "1" => :number, "}" => :keyword,
     " {{x}}\"" => :string]
  @test parts("f\"{(a + b)}\"", "python") ==
    ["f" => :plain, "\"" => :string, "{" => :keyword, "(a + b)" => :plain, "}" => :keyword, "\"" => :string]
  @test parts("\"{n}\"", "python") == ["\"{n}\"" => :string]
  @test parts("echo \"\$HOME/\${dir} \$(ls) \$1\"", "sh") ==
    ["echo " => :plain, "\"" => :string, "\$" => :keyword, "HOME" => :plain, "/" => :string, "\${" => :keyword,
     "dir" => :plain, "}" => :keyword, " " => :string, "\$(" => :keyword, "ls" => :plain, ")" => :keyword,
     " " => :string, "\$" => :keyword, "1" => :plain, "\"" => :string]
  @test parts("echo '\$HOME'", "sh") == ["echo " => :plain, "'\$HOME'" => :string]
  @test parts("\"\$x\"", "rust") == ["\"\$x\"" => :string]
end

@testset "the tokens hold every character at its column" begin
  for (line, lang) in [("\"Clicked \$(c.count) times\"", "julia"), ("\"a \$(join(xs, \", \")) b\" # note", "julia"),
                       ("\"a \$(x", "julia"), ("\"α \$β γ\"", "julia"), ("`a \${`b \${c}`} d`", "js"),
                       ("f'{d[\"k\"]:>10}'", "python"), ("echo \"\${#arr[@]} \$?\"", "sh")]
    @test whole(line, lang)
  end
end

@testset "what was right before is still right" begin
  @test parts("x = 'a' # note") == ["x = " => :plain, "'a'" => :string, "# note" => :comment]
  @test parts("@def mutable struct Counter <: SemanticUI") ==
    ["@def" => :call, "mutable" => :keyword, "struct" => :keyword, "Counter" => :type, " <: " => :plain,
     "SemanticUI" => :type]
  @test parts("push!(xs, 0x1f)") == ["push!" => :call, "(xs, " => :plain, "0x1f" => :number, ")" => :plain]
end
