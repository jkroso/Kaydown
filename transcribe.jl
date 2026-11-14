# Writes down what's said in a sound file. transcribe.swift does the work, as a
# program of its own, because macOS only offers its speech recognition to Swift.
# It runs on the Mac, so the sound stays there.
#
#     t = Transcription("memo.m4a")   # starts it
#     check!(t)                       # call it now and then. It's true once it has finished.
#     t.done, t.downloading           # how far it has got
#     t.text, t.problem               # once it has finished
#
# The Kaydown app has the program in it, beside its own program. When Kaydown
# runs from its source, it compiles transcribe.swift the first time it's needed,
# which takes a few seconds, and keeps the program in a folder of the Mac's
# caches. That needs Swift, which comes with Xcode and its command line tools.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool

const SOURCE = joinpath(@__DIR__, "transcribe.swift")

"The program in the Kaydown app, or nothing when Kaydown runs from its source"
bundled() = begin
  Sys.isapple() || return nothing
  path = with_pool() do
    jstring(msg(msg(cls("NSBundle"), "mainBundle"), "pathForAuxiliaryExecutable:", nsstring("transcribe")))
  end
  isfile(path) ? path : nothing
end

"What the program is compiled for: this Mac's kind of processor, and macOS 26, the first that has SpeechAnalyzer"
target() = "$(Sys.ARCH == :aarch64 ? "arm64" : "x86_64")-apple-macos26.0"

"Compile transcribe.swift into the program at `out`. The app's build runs it."
compile(out) = run(`swiftc -O -parse-as-library -target $(target()) $SOURCE -o $out`)

"""
The command that transcribes `file`: the program in the app, or the one compiled
from the source. If that isn't compiled yet, the command compiles it first.
"""
command(file) = begin
  app = bundled()
  app === nothing || return `$app $file`
  dir = joinpath(homedir(), "Library", "Caches", "Kaydown")
  # A change to the source makes a program of a new name
  program = joinpath(dir, "transcribe-" * string(hash(read(SOURCE)), base=16))
  isfile(program) && return `$program $file`
  mkpath(dir)
  # A program compiled from older source isn't needed
  foreach(f -> startswith(f, "transcribe-") && rm(joinpath(dir, f), force=true), readdir(dir))
  # It's compiled to another name and renamed once it's whole, so a program that's there is always whole
  script = """swiftc -O -parse-as-library -target $(target()) "\$1" -o "\$2.part" && mv "\$2.part" "\$2" && exec "\$2" "\$3" """
  `sh -c $script sh $SOURCE $program $file`
end

mutable struct Transcription
  file::String
  process::Any                   # the program, while it runs
  out::String                    # the file the program writes the text into
  err::String                    # the file it writes how far it has got into
  done::Float64                  # how much of the sound it has gone through, from 0 to 1
  downloading::Bool              # macOS is fetching what it needs for the language
  text::Union{Nothing,String}    # what's said in the file, once it has finished
  problem::String                # why it couldn't, if it couldn't
end

Transcription(file::AbstractString) = begin
  dir = mktempdir()
  t = Transcription(abspath(file), nothing, joinpath(dir, "text"), joinpath(dir, "progress"), 0.0, false, nothing, "")
  try
    t.process = run(pipeline(command(t.file), stdout=t.out, stderr=t.err), wait=false)
  catch
    t.problem = "Kaydown couldn't start to transcribe the file"
  end
  t
end

"Has it finished, with the text or with a problem?"
finished(t::Transcription) = t.text !== nothing || !isempty(t.problem)

"Read how far it has got. It's true once it has finished."
check!(t::Transcription) = begin
  finished(t) && return true
  lines = isfile(t.err) ? readlines(t.err) : String[]
  for line in lines
    line == "downloading" && (t.downloading = true)
    startswith(line, "done ") && (t.done = something(tryparse(Float64, line[6:end]), t.done); t.downloading = false)
  end
  process_exited(t.process) || return false
  if success(t.process)
    t.text = strip(read(t.out, String))
  else
    why = findlast(l -> startswith(l, "error: "), lines)
    t.problem = why !== nothing ? lines[why][8:end] :
                t.process.exitcode == 127 ? "Kaydown needs Swift to transcribe. It comes with Xcode's command line tools." :
                "The program that transcribes stopped before it finished"
  end
  rm(dirname(t.out), recursive=true, force=true)
  true
end

"Stop it before it finishes"
cancel!(t::Transcription) = (finished(t) || (kill(t.process); t.problem = "Stopped"); t)
