# Finds the fonts that a page asks for, and measures text in them.
#
#     f = font(["Helvetica Neue", "Arial", "sans-serif"], 14, 700, false)
#     f.ascent, f.descent      # how far its letters go over and under the line they stand on, in px
#     normal(f)                # how tall a line of it is when the page says no line height
#     d = drawn(f, 'é')        # the font that has the letter, which glyph of it, and how wide it is
#     widths(f, "Hi there")    # how wide each letter is
#
# The font is the first of the page's families that this computer has. A
# letter that the font doesn't have is drawn in a font that has it, which the
# system picks: an emoji, or a letter of another script. `serif`, `sans-serif`
# and `monospace` are the fonts that Safari uses for them.
#
#     advances(f, collect("AV"))   # how wide each letter is in a run of text, where the font moves some pairs together
#
# On a Mac, `advances` asks Core Text, the Mac's own text system, so a run of
# text is as wide as Safari draws it: with the font's kerning, and with the
# system font's own spacing at each size. Anywhere else, each letter is as
# wide as it is alone.

@use Skia
@use Libdl: dlopen, dlsym

struct Font
  raw::Ptr{Skia.sk_font_t}
  face::Ptr{Skia.sk_typeface_t}
  family::String
  size::Float64
  ascent::Float64
  descent::Float64
  gap::Float64          # the room that the font asks for between two lines
  xheight::Float64
  under::Float64        # how far under the line an underline is, and how thick
  thick::Float64
  core::Ptr{Cvoid}      # Core Text's font for it, or C_NULL
end

"How tall a line of the font is when nothing says a line height"
normal(f::Font) = f.ascent + f.descent + f.gap

const manager = Ref{Ptr{Skia.sk_font_mgr_t}}(C_NULL)
const fonts = Dict{Tuple{String,Float64,Int,Bool},Font}()
const faces = Dict{Tuple{String,Int,Bool},Ptr{Skia.sk_typeface_t}}()
const sized = Dict{Tuple{Ptr{Skia.sk_typeface_t},Float64},Font}()
const glyphs = Dict{Tuple{Ptr{Skia.sk_font_t},Char},Tuple{Font,UInt16,Float64}}()
const stand_ins = Dict{Tuple{Char,Int,Bool},Ptr{Skia.sk_typeface_t}}()
const installed = Dict{String,Bool}()
const spaces = Dict{Ptr{Skia.sk_font_t},Float64}()

# What Skia made is gone when the process ends, so a compiled app starts with none of it
__init__() = (manager[] = C_NULL; foreach(empty!, (fonts, faces, sized, glyphs, stand_ins, installed, spaces)))

"Skia's font manager. The faces of the system font are found when it's first asked for, while Skia is sure to find them."
mgr() = begin
  manager[] == C_NULL || return manager[]
  manager[] = Skia.sk_fontmgr_ref_default()
  for weight in 100:100:900, italic in (false, true)
    face(SYSTEM, weight, italic)
  end
  manager[]
end

const SYSTEM = ".AppleSystemUIFont"
# The fonts that Safari draws these names with
const GENERIC = Dict("serif" => "Times", "sans-serif" => "Helvetica", "monospace" => "Courier", "cursive" => "Apple Chancery", "fantasy" => "Papyrus",
                     "system-ui" => SYSTEM, "-apple-system" => SYSTEM, "blinkmacsystemfont" => SYSTEM,
                     "ui-sans-serif" => SYSTEM, "ui-rounded" => SYSTEM, "ui-serif" => "Times", "ui-monospace" => "Menlo")
const STANDARD = "Times"

"True when this computer has a font of the family `name`"
has(name::AbstractString) = get!(installed, name) do
  set = Skia.sk_fontmgr_match_family(mgr(), name)
  set == C_NULL && return false
  n = Skia.sk_fontstyleset_get_count(set)
  Skia.sk_fontstyleset_unref(set)
  n > 0
end

"The first of `families` that this computer has, or the font that a page with no font gets"
family(families) = begin
  for name in families
    name = get(GENERIC, lowercase(name), name)
    has(name) && return name
  end
  STANDARD
end

style(weight, italic) = Skia.sk_fontstyle_new(Int32(weight), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL),
                                               italic ? Skia.SK_FONT_STYLE_SLANT_ITALIC : Skia.SK_FONT_STYLE_SLANT_UPRIGHT)

"""
The typeface of `name` that's nearest the weight and the slant. The weight is
one of the nine from 100 to 900: Skia finds no system font for a weight
between two of them, like 550, and after it's asked for one it finds no system
font at all.
"""
face(name::String, weight::Int, italic::Bool) = begin
  weight = 100clamp(round(Int, weight / 100), 1, 9)
  get!(faces, (name, weight, italic)) do
    st = style(weight, italic)
    found = Skia.sk_fontmgr_match_family_style(mgr(), name, st)
    # A family that has no such face, which shouldn't happen, is drawn in the font that every Mac has
    found == C_NULL && name != STANDARD && (found = Skia.sk_fontmgr_match_family_style(mgr(), STANDARD, st))
    Skia.sk_fontstyle_delete(st)
    found
  end
end

"The name of the family of a typeface"
family_name(face) = begin
  str = Skia.sk_typeface_get_family_name(face)
  name = unsafe_string(Skia.sk_string_get_c_str(str))
  Skia.sk_string_delete(str)
  name
end

"The typeface `face` at `size` px"
at(face::Ptr{Skia.sk_typeface_t}, size::Float64, name=family_name(face)) = get!(sized, (face, size)) do
  raw = Skia.sk_font_new_with_values(face, Float32(size), 1f0, 0f0)
  Skia.sk_font_set_subpixel(raw, true)
  Skia.sk_font_set_hinting(raw, Skia.SK_FONT_HINTING_NONE)
  m = Ref{Skia.sk_font_metrics_t}()
  Skia.sk_font_get_metrics(raw, m)
  near(x) = round(x, RoundNearestTiesAway)
  ascent, descent, gap = near(-m[].ascent), near(m[].descent), near(m[].leading)
  # Safari makes these three taller, to match the fonts that Windows has of the same names
  name in ("Times", "Helvetica", "Courier") && (ascent += floor((ascent + descent) * 0.15 + 0.5))
  thick = m[].underlineThickness > 0 ? Float64(m[].underlineThickness) : size / 16
  under = m[].underlinePosition > 0 ? Float64(m[].underlinePosition) : size / 10
  st = Skia.sk_typeface_get_fontstyle(face)
  weight, italic = Int(Skia.sk_fontstyle_get_weight(st)), Skia.sk_fontstyle_get_slant(st) != Skia.SK_FONT_STYLE_SLANT_UPRIGHT
  Skia.sk_fontstyle_delete(st)
  Font(raw, face, name, size, ascent, descent, gap, m[].xHeight > 0 ? Float64(m[].xHeight) : size / 2, under, thick, core_font(name, weight, italic, size))
end

"The font for text that asks for `families` in turn, `size` px tall, of a weight from 100 to 900"
font(families, size::Real, weight::Integer=400, italic::Bool=false) = begin
  size = round(Float64(size), digits=2)
  get!(fonts, (join(families, ','), size, weight, italic)) do
    name = family(families)
    at(face(name, Int(weight), italic), size, name)
  end
end

# These take no room and draw nothing: spaces of no width, marks that say how letters join, and the soft hyphen
invisible(c::Char) = c == '­' || c == '͏' || '​' <= c <= '‏' || c == '⁠' || c == '﻿' || '︀' <= c <= '️' ||
                     '‪' <= c <= '‮' || '⁦' <= c <= '⁩' || c == '؜'

"""
How the letter `c` is drawn in text of the font `f`: the font that has it,
which is `f` when `f` has it, the glyph, and how wide it is in px. The glyph
is 0 for a letter that draws nothing.
"""
drawn(f::Font, c::Char) = get!(glyphs, (f.raw, c)) do
  invisible(c) && return (f, 0x0000, 0.0)
  c in ('\n', '\r', '\t', '\f') && (c = ' ')
  g = Skia.sk_font_unichar_to_glyph(f.raw, Int32(c))
  use = f
  if g == 0
    other = stand_in(f, c)
    if other !== nothing
      use = other
      g = Skia.sk_font_unichar_to_glyph(use.raw, Int32(c))
    end
  end
  wide = Ref{Cfloat}(0)
  id = Ref{UInt16}(g)
  Skia.sk_font_glyph_widths(use.raw, id, Cint(1), wide)
  (use, g, Float64(wide[]))
end

"A font of the size of `f` that has the letter `c`, which the system picks, or nothing"
stand_in(f::Font, c::Char) = begin
  found = get!(stand_ins, (c, 400, false)) do
    st = style(400, false)
    face = Skia.sk_fontmgr_match_family_style_character(mgr(), f.family, st, C_NULL, Int32(0), Int32(c))
    Skia.sk_fontstyle_delete(st)
    face
  end
  found == C_NULL ? nothing : at(found, f.size)
end

"How wide each letter of `text` is in the font `f`, in px"
widths(f::Font, text) = Float64[drawn(f, c)[3] for c in text]
width(f::Font, text) = sum(c -> drawn(f, c)[3], text; init=0.0)

# --- Core Text ----------------------------------------------------------------------------

const CT = "/System/Library/Frameworks/CoreText.framework/CoreText"
const CF = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

release(p) = p == C_NULL || ccall((:CFRelease, CF), Cvoid, (Ptr{Cvoid},), p)
"One of Core Text's named values"
named(lib, name::Symbol) = unsafe_load(Ptr{Ptr{Cvoid}}(dlsym(dlopen(lib), name)))
cf_string(s::AbstractString) = (b = codeunits(String(s)); ccall((:CFStringCreateWithBytes, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Clong, UInt32, Bool), C_NULL, b, length(b), 0x08000100, false))
cf_number(x::Float64) = ccall((:CFNumberCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Clong, Ref{Float64}), C_NULL, 13, x)
cf_number(x::Int32) = ccall((:CFNumberCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Clong, Ref{Int32}), C_NULL, 3, x)
cf_dict(pairs...) = begin
  keys, values = Ptr{Cvoid}[first(p) for p in pairs], Ptr{Cvoid}[last(p) for p in pairs]
  ccall((:CFDictionaryCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}}, Clong, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, keys, values, length(keys),
        cglobal((:kCFTypeDictionaryKeyCallBacks, CF)), cglobal((:kCFTypeDictionaryValueCallBacks, CF)))
end

# How heavy Core Text says each of the nine weights is
const HEAVY = Dict(100 => -0.8, 200 => -0.6, 300 => -0.4, 400 => 0.0, 500 => 0.23, 600 => 0.3, 700 => 0.4, 800 => 0.56, 900 => 0.62)

"Core Text's font of a family, a weight and a size, or C_NULL where there's no Core Text"
core_font(name::AbstractString, weight::Integer, italic::Bool, size::Real) = begin
  # Core Text takes a size of nothing to mean its usual size, so text of no size is left to Skia
  (Sys.isapple() && size > 0) || return C_NULL
  try
    heavy = cf_number(get(HEAVY, 100clamp(round(Int, weight / 100), 1, 9), 0.0))
    slant = cf_number(Int32(italic ? 1 : 0))
    traits = cf_dict(named(CT, :kCTFontWeightTrait) => heavy, named(CT, :kCTFontSymbolicTrait) => slant)
    desc = if name == SYSTEM
      # The system font has no name that Core Text takes. It's asked for as the font of the Mac's own text.
      base = ccall((:CTFontCreateUIFontForLanguage, CT), Ptr{Cvoid}, (UInt32, Float64, Ptr{Cvoid}), 2, size, C_NULL)
      own = ccall((:CTFontCopyFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid},), base)
      attrs = cf_dict(named(CT, :kCTFontTraitsAttribute) => traits)
      d = ccall((:CTFontDescriptorCreateCopyWithAttributes, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), own, attrs)
      foreach(release, (base, own, attrs))
      d
    else
      family = cf_string(name)
      attrs = cf_dict(named(CT, :kCTFontFamilyNameAttribute) => family, named(CT, :kCTFontTraitsAttribute) => traits)
      d = ccall((:CTFontDescriptorCreateWithAttributes, CT), Ptr{Cvoid}, (Ptr{Cvoid},), attrs)
      foreach(release, (family, attrs))
      d
    end
    font = ccall((:CTFontCreateWithFontDescriptor, CT), Ptr{Cvoid}, (Ptr{Cvoid}, Float64, Ptr{Cvoid}), desc, size, C_NULL)
    foreach(release, (heavy, slant, traits, desc))
    font
  catch
    C_NULL
  end
end

"How wide a space is in text of the font `f`"
space(f::Font) = get!(() -> advances(f, [' '])[1], spaces, f.raw)

"""
How wide each letter of `chars` is in a run of text of the font `f`, in px. Two
letters that the font moves together, like AV, are that much narrower. A new
line or a tab is as wide as a space.
"""
advances(f::Font, chars::Vector{Char}) = begin
  (f.core == C_NULL || isempty(chars)) && return Float64[drawn(f, c)[3] for c in chars]
  text = cf_string(String([c in ('\n', '\r', '\t', '\f') ? ' ' : c for c in chars]))
  none = cf_number(Int32(0))
  attrs = cf_dict(named(CT, :kCTFontAttributeName) => f.core, named(CT, :kCTLigatureAttributeName) => none)
  styled = ccall((:CFAttributedStringCreate, CF), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, text, attrs)
  line = ccall((:CTLineCreateWithAttributedString, CT), Ptr{Cvoid}, (Ptr{Cvoid},), styled)
  out = Vector{Float64}(undef, length(chars))
  at, before = 0, 0.0
  for (i, c) in enumerate(chars)
    # Core Text counts in the units of UTF-16, where a letter outside the first 65536 is two
    at += c > '￿' ? 2 : 1
    x = ccall((:CTLineGetOffsetForStringIndex, CT), Float64, (Ptr{Cvoid}, Clong, Ptr{Cvoid}), line, at, C_NULL)
    out[i] = invisible(c) ? 0.0 : max(0.0, x - before)
    before = max(before, x)
  end
  foreach(release, (line, styled, attrs, none, text))
  out
end
