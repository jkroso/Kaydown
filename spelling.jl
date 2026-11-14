# The spelling of words, checked by macOS. It has a dictionary for each of the
# Mac's languages, and it keeps the words that you teach it.
#
#     misspelt("A sentance.")   # [(2, 10)]: the columns where each wrong word starts and ends
#     guesses("sentance")       # ["sentence", ...]
#     learn!("Kaydown")         # the dictionary has the word from now on
#
# Columns count characters from 0, as in markdown.jl. This file only works on macOS.

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const Object = Ptr{Cvoid}

"macOS's spelling checker"
checker() = begin
  Base.Libc.Libdl.dlopen(AppKit)
  msg(cls("NSSpellChecker"), "sharedSpellChecker")
end

# What `misspelt` found in each piece of text, so that a line is only checked when it changes
const checked = Dict{String,Vector{Tuple{Int,Int}}}()

"""
The words of `text` that macOS's dictionary doesn't have: the columns where
each one starts and ends.
"""
misspelt(text::AbstractString) = begin
  Sys.isapple() || return Tuple{Int,Int}[]
  length(checked) > 20_000 && empty!(checked)
  get!(checked, text) do
    try
      with_pool(() -> columns(text, ranges(nsstring(text))))
    catch
      Tuple{Int,Int}[]
    end
  end
end

"Where each wrong word of `text` is, as macOS counts: in the 16-bit units of its strings"
ranges(text::Object) = begin
  out = Tuple{Int,Int}[]
  spell = checker()
  n = Int(ccall((:objc_msgSend, libobjc), UInt, (Object, Object), text, sel("length")))
  at = 0
  while at < n
    start, len = ccall((:objc_msgSend, libobjc), NTuple{2,UInt}, (Object, Object, Object, Int, Object, Bool, Int, Ptr{Int}),
                       spell, sel("checkSpellingOfString:startingAt:language:wrap:inSpellDocumentWithTag:wordCount:"),
                       text, at, C_NULL, false, 0, C_NULL)
    # With no more wrong words, macOS gives a length of 0
    (len == 0 || start >= n) && break
    push!(out, (Int(start), Int(start + len)))
    at = Int(start + len)
  end
  out
end

"`found`, which counts in 16-bit units, as columns of `text`. A character like an emoji is two units and one column."
columns(text::AbstractString, found) = begin
  isempty(found) && return found
  units = cumsum([c > '￿' ? 2 : 1 for c in text])   # how many units there are up to the end of each character
  column(unit) = searchsortedlast(units, unit)
  [(column(lo), column(hi)) for (lo, hi) in found]
end

"The words that macOS thinks `word` was meant to be, the likeliest first"
guesses(word::AbstractString) = begin
  Sys.isapple() || return String[]
  try
    with_pool() do
      text = nsstring(word)
      n = ccall((:objc_msgSend, libobjc), UInt, (Object, Object), text, sel("length"))
      list = ccall((:objc_msgSend, libobjc), Object, (Object, Object, NTuple{2,UInt}, Object, Object, Int), checker(),
                   sel("guessesForWordRange:inString:language:inSpellDocumentWithTag:"), (UInt(0), n), text, C_NULL, 0)
      list == C_NULL && return String[]
      count = Int(ccall((:objc_msgSend, libobjc), UInt, (Object, Object), list, sel("count")))
      [jstring(ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), list, sel("objectAtIndex:"), i)) for i in 0:count-1]
    end
  catch
    String[]
  end
end

"Teach macOS's dictionary `word`. Every app on the Mac then takes it as a word."
learn!(word::AbstractString) = begin
  Sys.isapple() || return
  with_pool(() -> msg(checker(), "learnWord:", nsstring(word)))
  empty!(checked)
  nothing
end

export misspelt, guesses, learn!
