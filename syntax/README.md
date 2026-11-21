# Syntax definitions

Ladder colours the languages in this folder with the syntax definitions of
KDE's editor Kate. `kate.jl` reads them. They're copies of the files in
`data/syntax/` of https://invent.kde.org/frameworks/syntax-highlighting, at its
commit 678a8b408527b7457165c3af4940303ec121429c of 21 November 2026, with no
changes. That repository has 417. These are 181 of them: about 110 common
languages, and the ones they include.

The 17 files under the GPL aren't here, because Ladder's releases are public
and Jake chose to keep the GPL out of them (21 November 2026). Without them, GNU
and NASM assembler, AVR assembler, R, Octave, sed, man pages (roff), Kconfig and
SystemVerilog have no colours, and nor do the code blocks of those languages
inside others, like Markdown. The others are abap, gap, inform, j, json, pig,
go and nesc. Ladder has readers of its own for Go and JSON.

To add a language, copy its file here, with each file that it includes: look
for `##` in its `IncludeRules` and `context` attributes. A definition that
includes one that isn't here still works, without the rules of that one. Check
the licence in the file's `<language>` element first. Then change `kate.jl`, so
that Kip compiles it again and reads the folder.

KDE asks for MIT on new contributions to the repository. Older files often
state no licence. Lua's file includes `DoxygenLua`, which KDE makes from a
script when it builds, so it isn't here.

| File | Language | Licence |
|---|---|---|
| actionscript.xml | ActionScript 2.0 | LGPL |
| ada.xml | Ada | none stated in the file |
| agda.xml | Agda | LGPL |
| ahk.xml | AutoHotKey | none stated in the file |
| alert.xml | Alerts (only for others to include) | MIT |
| ansforth94.xml | ANS-Forth94 | LGPLv2.1+ |
| apache.xml | Apache Configuration | LGPL |
| asciidoc.xml | AsciiDoc | MIT |
| asm-arm.xml | ARM Assembler | MIT |
| awk.xml | AWK | LGPL |
| bash.xml | Bash | LGPL |
| bibtex.xml | BibTeX | LGPL |
| boo.xml | Boo | LGPL |
| c.xml | C | none stated in the file |
| clojure.xml | Clojure | LGPLv2+ |
| cmake.xml | CMake | LGPLv2+ |
| coffee.xml | CoffeeScript | MIT |
| comments.xml | Comments (only for others to include) | MIT |
| commonlisp.xml | Common Lisp | MIT |
| cpp.xml | C++ | LGPL |
| crystal.xml | Crystal | LGPLv2+ |
| cs.xml | C# | none stated in the file |
| css.xml | CSS | LGPL |
| d.xml | D | LGPL |
| dart.xml | Dart | MIT |
| debiancontrol.xml | Debian Control | none stated in the file |
| desktop.xml | .desktop | none stated in the file |
| diff.xml | Diff | none stated in the file |
| djangotemplate.xml | Django HTML Template | LGPL |
| dockerfile.xml | Dockerfile | MIT |
| dosbat.xml | MS-DOS Batch | LGPL |
| dot.xml | dot | none stated in the file |
| dotenv.xml | DotEnv | MIT |
| doxygen.xml | Doxygen | MIT |
| dtd.xml | DTD | LGPL |
| dts.xml | Devicetree Source (DTS) | MIT |
| eiffel.xml | Eiffel | none stated in the file |
| elixir-eex.xml | Elixir/EEx | MIT |
| elixir-heex.xml | Elixir/HEEx | MIT |
| elixir.xml | Elixir | LGPLv2+ |
| elm.xml | Elm | MIT |
| email.xml | Email | MIT |
| erlang.xml | Erlang | LGPLv2 |
| fish.xml | Fish | LGPL |
| fortran-fixed.xml | Fortran (Fixed Format) | MIT |
| fortran-free.xml | Fortran (Free Format) | MIT |
| fsharp.xml | FSharp | LGPL |
| fstab.xml | fstab | Public Domain |
| gcc.xml | GCCExtensions (only for others to include) | LGPL |
| gcode.xml | G-Code | LGPLv2+ |
| gd-script.xml | Godot | none stated in the file |
| gettext.xml | GNU Gettext | MIT |
| git-ignore.xml | Git Ignore | LGPL |
| gleam.xml | Gleam | MIT |
| glsl.xml | GLSL | LGPL |
| gnuplot.xml | Gnuplot | none stated in the file |
| graphql.xml | GraphQL | MIT |
| groovy.xml | Groovy | LGPL |
| haml.xml | Haml | LGPL |
| hamlet.xml | Hamlet | LGPL |
| hare.xml | Hare | MIT |
| haskell.xml | Haskell | LGPL |
| haxe.xml | Haxe | MIT |
| html.xml | HTML | LGPL |
| idl.xml | IDL | none stated in the file |
| idris.xml | Idris | LGPL |
| ini.xml | INI Files | LGPL |
| isocpp.xml | ISO C++ | LGPL |
| java-properties.xml | Java Properties | MIT |
| java.xml | Java | LGPL |
| javadoc.xml | Javadoc | LGPL |
| javascript-react.xml | JavaScript React (JSX) | MIT |
| javascript.xml | JavaScript | none stated in the file |
| jcl.xml | JCL | MIT |
| jinja.xml | Jinja | MIT |
| jsonnet.xml | Jsonnet | MIT |
| julia.xml | Julia | MIT |
| just.xml | Just | MIT |
| kdl.xml | KDL | MIT |
| kotlin.xml | Kotlin | LGPLv2+ |
| latex.xml | LaTeX | LGPL |
| ld.xml | GNU Linker Script | none stated in the file |
| less.xml | LESSCSS | LGPL |
| lilypond.xml | LilyPond | LGPL |
| literate-haskell.xml | Literate Haskell | LGPL |
| llvm.xml | LLVM | LLVM Release License |
| logtalk.xml | Logtalk | Apache License 2.0 |
| lsl.xml | LSL | LGPLv3 |
| lua.xml | Lua | none stated in the file |
| m4.xml | GNU M4 | New BSD License |
| makefile.xml | Makefile | none stated in the file |
| mako.xml | Mako | LGPL |
| markdown.xml | Markdown | GPL or BSD, used here under BSD |
| mason.xml | Mason | none stated in the file |
| mathematica.xml | Mathematica | LGPL |
| matlab.xml | Matlab | none stated in the file |
| maxima.xml | Maxima | LGPLv2.1+ |
| meson.xml | Meson | LGPL |
| modelica.xml | Modelica | LGPLv2+ |
| modelines.xml | Modelines (only for others to include) | MIT |
| modula-2.xml | Modula-2 | MIT |
| mustache.xml | Mustache/Handlebars (HTML) | MIT |
| nemerle.xml | Nemerle | none stated in the file |
| nginx.xml | nginx Configuration | MIT |
| nim.xml | Nim | WTFPL |
| ninja.xml | Ninja | MIT |
| nix.xml | Nix | MIT |
| nsis.xml | NSIS | LGPLv2+ |
| objectivec.xml | Objective-C | none stated in the file |
| objectivecpp.xml | Objective-C++ | none stated in the file |
| ocaml.xml | Objective Caml | LGPL |
| odin.xml | Odin | MIT |
| opencl.xml | OpenCL | none stated in the file |
| openscad.xml | OpenSCAD | MIT |
| orgmode.xml | Org Mode | MIT |
| pascal.xml | Pascal | none stated in the file |
| perl.xml | Perl | LGPLv2 |
| php.xml | PHP/PHP (only for others to include) | none stated in the file |
| pike.xml | Pike | none stated in the file |
| pioasm.xml | PIO Assembler | MIT |
| pony.xml | Pony | MIT |
| postscript.xml | PostScript | none stated in the file |
| povray.xml | POV-Ray | LGPL |
| powershell.xml | PowerShell | MIT |
| praat.xml | Praat | LGPLv2 |
| prolog.xml | Prolog | LGPLv2+ |
| protobuf.xml | Protobuf | LGPL |
| pug.xml | Pug | LGPL |
| puppet.xml | Puppet | LGPLv2+ |
| purescript.xml | PureScript | BSD3 |
| python.xml | Python | none stated in the file |
| qmake.xml | QMake | MIT |
| qml.xml | QML | MIT |
| racket.xml | Racket | MIT |
| raku.xml | Raku | MIT |
| relaxngcompact.xml | RelaxNG-Compact | LGPL |
| rest.xml | reStructuredText | none stated in the file |
| rexx.xml | REXX | none stated in the file |
| rhtml.xml | Ruby/Rails/RHTML | LGPLv2+ |
| rpmspec.xml | RPM Spec | Public Domain |
| ruby.xml | Ruby | LGPLv2+ |
| rust.xml | Rust | MIT |
| sass.xml | SASS | MIT |
| scala.xml | Scala | LGPL |
| scheme.xml | Scheme | MIT |
| sci.xml | scilab | none stated in the file |
| scss.xml | SCSS | LGPL |
| sieve.xml | Sieve | MIT |
| smali.xml | Smali | MIT |
| sml.xml | SML | MIT |
| solidity.xml | Solidity | MIT |
| spdx-comments.xml | SPDX-Comments (only for others to include) | MIT |
| spice.xml | Spice | LGPL |
| sql-mysql.xml | SQL (MySQL) | none stated in the file |
| sql.xml | SQL | LGPL |
| stan.xml | Stan | MIT |
| starlark.xml | Starlark | none stated in the file |
| stata.xml | Stata | LGPL |
| swift.xml | Swift | MIT |
| systemd-unit.xml | systemd unit | MIT |
| tads3.xml | TADS 3 | none stated in the file |
| tcl.xml | Tcl/Tk | BSD |
| tcsh.xml | Tcsh | LGPL |
| terraform.xml | Terraform | MIT |
| texinfo.xml | Texinfo | LGPL |
| todo.xml | Todo.txt | MIT |
| toml.xml | TOML | LGPLv2+ |
| twig.xml | Twig/Twig | MIT |
| typescript.xml | TypeScript | MIT |
| typst.xml | Typst | MIT |
| vala.xml | Vala | LGPLv2+ |
| velocity.xml | Velocity | none stated in the file |
| verilog.xml | Verilog | none stated in the file |
| vhdl.xml | VHDL | none stated in the file |
| vue.xml | Vue | LGPL |
| wgsl.xml | WGSL | MIT |
| xml.xml | XML | LGPL |
| xorg.xml | x.org Configuration | LGPL |
| yaml.xml | YAML | LGPL |
| yang.xml | YANG | LGPLv2.1+ |
| zsh.xml | Zsh | MIT |
