# Tests for the colours of the parts of a line of code. See highlight.jl. Run
# them with `julia -O0 --project=. test/highlight_test.jl`.

@use Test: @test, @testset
@use "../highlight" tokens left_open

"Each part of `line` in `lang` as text => kind, without the plain parts that are only spaces"
parts(line, lang="julia", open='\0') = [t.text => t.kind for t in tokens(line, lang, open) if !(t.kind == :plain && all(isspace, t.text))]

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

@testset "a string in three quotes runs over several lines" begin
  # A docstring of several lines: the line that opens it leaves it open, and the lines inside it are all string
  @test left_open("\"\"\"", "julia") == '"' && left_open("f(x) = 1", "julia") == '\0'
  @test parts("Shows it for a time, to the end", "julia", '"') == ["Shows it for a time, to the end" => :string]
  @test left_open("Shows it for a time", "julia", '"') == '"'
  @test parts("", "julia", '"') == [] && left_open("", "julia", '"') == '"'
  # The line that closes it is string up to the three quotes, and code after them
  @test parts("the end\"\"\" f(x) = 2", "julia", '"') == ["the end\"\"\"" => :string, "f" => :call, "(x) = " => :plain, "2" => :number]
  @test left_open("the end\"\"\"", "julia", '"') == '\0' && left_open("\"\"\"", "julia", '"') == '\0'
  # Three quotes that close on their line, and two quotes, leave nothing open
  @test left_open("\"\"\"Short\"\"\"", "julia") == '\0' && parts("\"\"\"Short\"\"\"") == ["\"\"\"Short\"\"\"" => :string]
  @test left_open("x = \"\"", "julia") == '\0' && left_open("x = \"\"\"", "julia") == '"'
  # Three quotes in a comment or in a string of one quote open nothing, nor does an escaped quote close one
  @test left_open("# like \"\"\"", "julia") == '\0' && left_open("s = \"a \\\"\\\"\\\" b\"", "julia") == '\0'
  @test left_open("a \\\"\"\"\" b", "julia", '"') == '\0' && left_open("a \\\"\"\" b", "julia", '"') == '"'
  # Code in a docstring has the colours of code, as in a string of one line
  @test parts("costs \$(price) now", "julia", '"') == ["costs " => :string, "\$(" => :keyword, "price" => :plain, ")" => :keyword, " now" => :string]
  # Python has ''' as well. A language with no such strings leaves nothing open.
  @test left_open("'''", "python") == '\'' && parts("it's here", "python", '\'') == ["it's here" => :string]
  @test left_open("\"\"\"", "js") == '\0' && left_open("\"\"\"", "") == '\0'
  @test whole("the end\"\"\" g(\"x\")", "julia")
end

"The parts of each of `lines`, a file in `lang`, as `parts` gives them. Each line starts in what the one above left open."
file(lines, lang) = begin
  open = '\0'
  map(lines) do line
    p = parts(line, lang, open)
    open = left_open(line, lang, open)
    p
  end
end

@testset "CSS" begin
  css(line, open='\0') = parts(line, "css", open)
  # A selector has the colour of a keyword, a property of a type, and in its value a number of a number
  @test css("a[href^=\"http\"]:not(.x) > p::before {") ==
    ["a" => :keyword, "[" => :plain, "href" => :type, "^=" => :plain, "\"http\"" => :string, "]" => :plain, ":not" => :keyword,
     "(" => :plain, ".x" => :keyword, ") > " => :plain, "p" => :keyword, "::before" => :keyword, " {" => :plain]
  @test css("  margin: -1px auto 0 !important;") ==
    ["margin" => :type, ": " => :plain, "-1px" => :number, " auto " => :plain, "0" => :number, "!important" => :keyword, ";" => :plain]
  @test css("  background: url(img/a.png) #fff;") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "img/a.png" => :string, ") " => :plain, "#fff" => :number, ";" => :plain]
  @test css("a{color:red;width:calc(100% - 2rem)}") ==
    ["a" => :keyword, "{" => :plain, "color" => :type, ":red;" => :plain, "width" => :type, ":" => :plain, "calc" => :call, "(" => :plain,
     "100%" => :number, " - " => :plain, "2rem" => :number, ")}" => :plain]
  @test css("@media screen and (min-width: 600px) {") ==
    ["@media" => :keyword, " screen " => :plain, "and" => :keyword, " (" => :plain, "min-width" => :type, ": " => :plain, "600px" => :number, ") {" => :plain]
  @test css("li:nth-child(2n+1) { display: none }") ==
    ["li" => :keyword, ":nth-child" => :keyword, "(" => :plain, "2n" => :number, "+" => :plain, "1" => :number, ") { " => :plain,
     "display" => :type, ": none }" => :plain]
  # A selector that goes on below, and a value that does
  @test file(["html,", "a:hover", "{ color: red }"], "css") ==
    [["html" => :keyword, "," => :plain], ["a" => :keyword, ":hover" => :keyword], ["{ " => :plain, "color" => :type, ": red }" => :plain]]
  @test file(["  font-family:", "    -apple-system,", "    \"Segoe UI\";", "  margin: 0;"], "css") ==
    [["font-family" => :type, ":" => :plain], ["    -apple-system," => :plain], ["\"Segoe UI\"" => :string, ";" => :plain],
     ["margin" => :type, ": " => :plain, "0" => :number, ";" => :plain]]
  # A value that lacks its ; ends where the next property starts
  @test file(["  color: red", "  margin: 0", "}"], "css")[2] == ["margin" => :type, ": " => :plain, "0" => :number]
  # A comment can run over several lines, among the rules or in a value
  @test left_open("/* a", "css") == 'C' && css("b */ p {", 'C') == ["b */" => :comment, "p" => :keyword, " {" => :plain]
  @test left_open("  color: /* a", "css") == 'V' && left_open("b */ red;", "css", 'V') == '\0'
  # Nothing is left open after a line that ends a rule or a property
  @test left_open("  color: red; }", "css") == '\0' && left_open("p {", "css") == '\0'
  @test whole("a[href^='x'] { b: url(\"q\") }", "css") && whole("p { a: b /* c", "css")
  # In CSS // doesn't start a comment
  @test css("  background: url(http://a.com/x.png);") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "http://a.com/x.png" => :string, ");" => :plain]
end

@testset "Less" begin
  less(line, open='\0') = parts(line, "less", open)
  # A variable that's set has the colour of a property, and // starts a comment
  @test less("@primary: #4a90e2; // the blue") ==
    ["@primary" => :type, ": " => :plain, "#4a90e2" => :number, "; " => :plain, "// the blue" => :comment]
  @test less("  border: @width solid darken(@primary, 10%);") ==
    ["border" => :type, ": @width solid " => :plain, "darken" => :call, "(@primary, " => :plain, "10%" => :number, ");" => :plain]
  # A mixin that's made has the colour of a selector, and one that's used the colour of a call
  @test less(".bordered(@width: 2px) {") ==
    [".bordered" => :keyword, "(" => :plain, "@width" => :type, ": " => :plain, "2px" => :number, ") {" => :plain]
  @test less("  .bordered(4px);") == [".bordered" => :call, "(" => :plain, "4px" => :number, ");" => :plain]
  @test less("  #ns > .clearfix;") == ["#ns" => :call, " > " => :plain, ".clearfix" => :call, ";" => :plain]
  @test less("  &:hover { color: red }") == ["&" => :keyword, ":hover" => :keyword, " { " => :plain, "color" => :type, ": red }" => :plain]
  # @{name} puts a variable's value in a selector or a string
  @test less(".@{name}-box { a: ~\"url(@{base})\" }") ==
    ["." => :plain, "@{" => :keyword, "name" => :plain, "}" => :keyword, "-box" => :keyword, " { " => :plain, "a" => :type, ": " => :plain,
     "~\"url(" => :string, "@{" => :keyword, "base" => :plain, "}" => :keyword, ")\"" => :string, " }" => :plain]
  # A guard, and rules like @import and @media, which a ( can follow
  @test less(".m(@a) when (iscolor(@a)) {") ==
    [".m" => :keyword, "(@a) " => :plain, "when" => :keyword, " (" => :plain, "iscolor" => :call, "(@a)) {" => :plain]
  @test less("@import (reference) \"x.less\";") == ["@import" => :keyword, " (reference) " => :plain, "\"x.less\"" => :string, ";" => :plain]
  @test less("@media(min-width: 768px) {")[1] == ("@media" => :keyword) && less("  @rules();") == ["@rules" => :call, "();" => :plain]
  # A // in a string isn't a comment, nor is a { in a comment a rule
  @test less("@url: \"http://a.com\"; // see { here }") ==
    ["@url" => :type, ": " => :plain, "\"http://a.com\"" => :string, "; " => :plain, "// see { here }" => :comment]
  @test left_open("@a: 1; // see {", "less") == '\0' && whole(".a { .m(); } // b", "less")
end

@testset "SCSS" begin
  scss(line, open='\0') = parts(line, "scss", open)
  # A variable that's set has the colour of a property, a flag like !default of a keyword, and // starts a comment
  @test scss("\$primary: #4a90e2 !default; // the blue") ==
    ["\$primary" => :type, ": " => :plain, "#4a90e2" => :number, "!default" => :keyword, "; " => :plain, "// the blue" => :comment]
  @test scss("  border: \$width solid darken(\$primary, 10%);") ==
    ["border" => :type, ": \$width solid " => :plain, "darken" => :call, "(\$primary, " => :plain, "10%" => :number, ");" => :plain]
  # The name of a mixin or a function that's made or used has the colour of a call
  @test scss("@mixin rounded(\$r: 4px) {") ==
    ["@mixin" => :keyword, "rounded" => :call, "(" => :plain, "\$r" => :type, ": " => :plain, "4px" => :number, ") {" => :plain]
  @test scss("  @include rounded;") == ["@include" => :keyword, "rounded" => :call, ";" => :plain]
  @test scss("  @include mixins.card(2px);") == ["@include" => :keyword, "mixins.card" => :call, "(" => :plain, "2px" => :number, ");" => :plain]
  # A selector like %name, which only @extend uses
  @test scss("%notice { color: red }") == ["%notice" => :keyword, " { " => :plain, "color" => :type, ": red }" => :plain]
  @test scss("  @extend %notice;") == ["@extend" => :keyword, "%notice" => :keyword, ";" => :plain]
  # #{...} puts a value in a selector or a string, and its code has the colours of a value
  @test scss(".icon-#{\$name} { content: \"#{\$i + 1}x\" }") ==
    [".icon-" => :keyword, "#{" => :keyword, "\$name" => :plain, "}" => :keyword, " { " => :plain, "content" => :type, ": " => :plain,
     "\"" => :string, "#{" => :keyword, "\$i + " => :plain, "1" => :number, "}" => :keyword, "x\"" => :string, " }" => :plain]
  @test scss("  background: url(#{\$base}/a.png);") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "#{" => :keyword, "\$base" => :plain, "}" => :keyword, "/a.png);" => :plain]
  # The words of rules that repeat or choose
  @test scss("@each \$name, \$glyph in \$icons {") == ["@each" => :keyword, " \$name, \$glyph " => :plain, "in" => :keyword, " \$icons {" => :plain]
  @test scss("@for \$i from 1 through 3 {") ==
    ["@for" => :keyword, " \$i " => :plain, "from" => :keyword, "1" => :number, "through" => :keyword, "3" => :number, " {" => :plain]
  @test scss("} @else if \$a == 2 {") == ["} " => :plain, "@else" => :keyword, "if" => :keyword, " \$a == " => :plain, "2" => :number, " {" => :plain]
  @test scss("\$x: if(\$a and \$b, 1, 2);") ==
    ["\$x" => :type, ": " => :plain, "if" => :call, "(\$a " => :plain, "and" => :keyword, " \$b, " => :plain, "1" => :number, ", " => :plain,
     "2" => :number, ");" => :plain]
  @test scss("@use \"sass:math\" as m;") == ["@use" => :keyword, "\"sass:math\"" => :string, "as" => :keyword, " m;" => :plain]
  # A map over several lines: its keys have the colour of a property
  @test file(["\$sizes: (", "  small: 576px,", "  large: 992px", ");"], "scss") ==
    [["\$sizes" => :type, ": (" => :plain], ["small" => :type, ": " => :plain, "576px" => :number, "," => :plain],
     ["large" => :type, ": " => :plain, "992px" => :number], [");" => :plain]]
  @test left_open("\$sizes: (", "scss") == 'v' && left_open(");", "scss", 'v') == '\0'
  @test whole("@use \"sass:math\" as m; .a-#{\$b} { c: m.div(1, 2) \"#{d}\" } // e", "scss")
  # In CSS, a $ is nothing special
  @test parts("a: \$b;", "css") == ["a" => :type, ": \$b;" => :plain]
end
