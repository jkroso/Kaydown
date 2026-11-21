# WebGL for a page's <canvas>: `canvas.getContext('webgl2')`, and 'webgl'.
#
#     start!(js; node, picture, board)    # once for each page: context.jl calls it
#
# Each context of a script is an OpenGL context of macOS, which draws off the
# screen into a framebuffer of its own: the drawing buffer. macOS has OpenGL
# 4.1, which it runs on Metal. That's close to OpenGL ES 3.0, which WebGL 2
# is, so most calls of a script are the same call of OpenGL. What differs:
#
# - A shader of WebGL is written for OpenGL ES (`#version 300 es`, or no
#   version for WebGL 1). `glsl` writes it for OpenGL 4.1.
# - The drawing buffer is a framebuffer here, and a script knows it as null.
#   With `antialias` it has 4 samples, and is resolved into one that's read.
# - OpenGL 4.1 has no `texStorage2D`: a texture gets each of its levels with
#   `glTexImage2D`. LUMINANCE and ALPHA are a red texture with its colours
#   swapped round. `lineWidth` does nothing, as in most browsers.
# - A picture, a canvas or a video that a script gives `texImage2D` is read
#   into pixels here, with UNPACK_FLIP_Y_WEBGL and UNPACK_PREMULTIPLY_ALPHA_WEBGL.
#
# The canvas's surface (canvas.jl's Board) gets the picture of the drawing
# buffer just before paint.jl draws it, when the script has drawn since.
#
# The OpenGL context of a script is made current when the script first calls
# it, and the one that was current before, like the window's, comes back when
# Julia's call into the scripts ends: see `giveback!`.

@use Skia
@use "./jsc" Context evaluate Raw
@use "./jsc" => JS
@use "./dom" Element

const GL = "/System/Library/Frameworks/OpenGL.framework/OpenGL"

# --- the OpenGL context of each WebGL context ---------------------------------------------

"A WebGL context: its OpenGL context, and its drawing buffer"
mutable struct Surface
  cgl::Ptr{Cvoid}
  board::Any                   # the surface of the canvas, which gets the picture
  wide::Int                    # of the drawing buffer
  high::Int
  alpha::Bool
  depth::Bool
  stencil::Bool
  samples::Int                 # 4 with antialias, else 0
  premultiplied::Bool
  fbo::UInt32                  # the drawing buffer that's read: with antialias, what it's resolved into
  colour::UInt32
  buffer::UInt32               # its depth and stencil, with no antialias
  msfbo::UInt32                # with antialias: what's drawn into
  mscolour::UInt32
  msbuffer::UInt32
  vao::UInt32                  # the vertex array that stands for WebGL's own
  draw::UInt32                 # the framebuffers that the script has bound, as it knows them: 0 is the drawing buffer
  read::UInt32
  renderbuffer::UInt32         # the renderbuffer that it has bound
  flip::Bool                   # UNPACK_FLIP_Y_WEBGL
  multiply::Bool               # UNPACK_PREMULTIPLY_ALPHA_WEBGL
  unpack::Dict{UInt32,Int32}   # what the script set of OpenGL's unpacking, like UNPACK_ALIGNMENT
  drawn::Bool                  # drawn on since the board last got the picture
  error::UInt32                # an error of WebGL's own, which getError gives before OpenGL's
end

# The OpenGL contexts that a page made, and the one that was current before a script first made one of them current
const OURS = Set{Ptr{Cvoid}}()
const BEFORE = Ref{Ptr{Cvoid}}(C_NULL)
# Each WebGL context by its number, which its script holds
const SURFACES = Dict{Int,WeakRef}()
const LAST = Ref(0)
# The OpenGL contexts whose WebGL context Julia has freed. They're destroyed when none of them is current.
const GONE = Ptr{Cvoid}[]
const GOING = Threads.SpinLock()

current() = ccall((:CGLGetCurrentContext, GL), Ptr{Cvoid}, ())
setcurrent(c) = ccall((:CGLSetCurrentContext, GL), Int32, (Ptr{Cvoid},), c)

"Make the OpenGL context of `s` the current one"
use(s::Surface) = begin
  now = current()
  now == s.cgl && return
  now in OURS || (BEFORE[] = now)
  setcurrent(s.cgl)
  nothing
end

"Make current again the context that was current before a script's OpenGL context was, and destroy what's freed"
giveback!() = begin
  current() in OURS && (setcurrent(BEFORE[]); BEFORE[] = C_NULL)
  if !isempty(GONE)
    lock(GOING)
    gone = copy(GONE)
    empty!(GONE)
    unlock(GOING)
    for c in gone
      delete!(OURS, c)
      ccall((:CGLDestroyContext, GL), Int32, (Ptr{Cvoid},), c)
    end
  end
  filter!(p -> p.second.value !== nothing, SURFACES)
  nothing
end

"A new name of an OpenGL object, from `glGen...`"
made(f::Symbol) = (n = Ref{UInt32}(0); ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), f), Cvoid, (Int32, Ref{UInt32}), 1, n); n[])

"Bind a framebuffer, as OpenGL knows it, to `target`"
bindfb(target, fb) = ccall((:glBindFramebuffer, GL), Cvoid, (UInt32, UInt32), target, fb)
"The framebuffer that the script's `fb` is: the drawing buffer for 0"
actual(s::Surface, fb) = fb == 0 ? (s.samples > 0 ? s.msfbo : s.fbo) : UInt32(fb)
geti(pname) = (v = Ref{Int32}(0); ccall((:glGetIntegerv, GL), Cvoid, (UInt32, Ref{Int32}), pname, v); v[])
enabled(cap) = ccall((:glIsEnabled, GL), UInt8, (UInt32,), cap) != 0

const FRAMEBUFFER, DRAW_FRAMEBUFFER, READ_FRAMEBUFFER, RENDERBUFFER = 0x8D40, 0x8CA9, 0x8CA8, 0x8D41
const SCISSOR_TEST, RASTERIZER_DISCARD = 0x0C11, 0x8C89

"""
Do `f` with the state that a clear depends on as a new context has it: no
scissor, and every colour, the depth and the stencil written. What the script
set comes back after.
"""
plainly(f) = begin
  scissor, discard = enabled(SCISSOR_TEST), enabled(RASTERIZER_DISCARD)
  mask = zeros(UInt8, 4)
  ccall((:glGetBooleanv, GL), Cvoid, (UInt32, Ptr{UInt8}), 0x0C23, mask)
  depth = Ref{UInt8}(0)
  ccall((:glGetBooleanv, GL), Cvoid, (UInt32, Ref{UInt8}), 0x0B72, depth)
  front, back = geti(0x0B98), geti(0x8CA5)
  scissor && ccall((:glDisable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
  discard && ccall((:glDisable, GL), Cvoid, (UInt32,), RASTERIZER_DISCARD)
  ccall((:glColorMask, GL), Cvoid, (UInt8, UInt8, UInt8, UInt8), 1, 1, 1, 1)
  ccall((:glDepthMask, GL), Cvoid, (UInt8,), 1)
  ccall((:glStencilMask, GL), Cvoid, (UInt32,), 0xffffffff)
  try
    f()
  finally
    scissor && ccall((:glEnable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
    discard && ccall((:glEnable, GL), Cvoid, (UInt32,), RASTERIZER_DISCARD)
    ccall((:glColorMask, GL), Cvoid, (UInt8, UInt8, UInt8, UInt8), mask[1], mask[2], mask[3], mask[4])
    ccall((:glDepthMask, GL), Cvoid, (UInt8,), depth[])
    ccall((:glStencilMaskSeparate, GL), Cvoid, (UInt32, UInt32), 0x0404, UInt32(reinterpret(UInt32, front)))
    ccall((:glStencilMaskSeparate, GL), Cvoid, (UInt32, UInt32), 0x0405, UInt32(reinterpret(UInt32, back)))
  end
end

"Give the drawing buffer of `s` the size `wide` by `high`, with nothing drawn in it"
size!(s::Surface, wide, high) = begin
  use(s)
  s.wide, s.high = max(1, wide), max(1, high)
  colour = s.alpha ? 0x8058 : 0x8051        # RGBA8 or RGB8
  holds = s.depth || s.stencil
  rb(name, format, samples) = begin
    ccall((:glBindRenderbuffer, GL), Cvoid, (UInt32, UInt32), RENDERBUFFER, name)
    samples > 0 ? ccall((:glRenderbufferStorageMultisample, GL), Cvoid, (UInt32, Int32, UInt32, Int32, Int32), RENDERBUFFER, samples, format, s.wide, s.high) :
                  ccall((:glRenderbufferStorage, GL), Cvoid, (UInt32, UInt32, Int32, Int32), RENDERBUFFER, format, s.wide, s.high)
  end
  attach(fb, name, point) = (bindfb(FRAMEBUFFER, fb); ccall((:glFramebufferRenderbuffer, GL), Cvoid, (UInt32, UInt32, UInt32, UInt32), FRAMEBUFFER, point, RENDERBUFFER, name))
  s.fbo == 0 && (s.fbo = made(:glGenFramebuffers); s.colour = made(:glGenRenderbuffers))
  rb(s.colour, colour, 0)
  attach(s.fbo, s.colour, 0x8CE0)
  if s.samples > 0
    s.msfbo == 0 && (s.msfbo = made(:glGenFramebuffers); s.mscolour = made(:glGenRenderbuffers); holds && (s.msbuffer = made(:glGenRenderbuffers)))
    rb(s.mscolour, colour, s.samples)
    attach(s.msfbo, s.mscolour, 0x8CE0)
    holds && (rb(s.msbuffer, 0x88F0, s.samples); attach(s.msfbo, s.msbuffer, 0x821A))
  elseif holds
    s.buffer == 0 && (s.buffer = made(:glGenRenderbuffers))
    rb(s.buffer, 0x88F0, 0)                  # DEPTH24_STENCIL8
    attach(s.fbo, s.buffer, 0x821A)          # DEPTH_STENCIL_ATTACHMENT
  end
  # A new drawing buffer is clear
  plainly() do
    for fb in (s.fbo, s.msfbo)
      fb == 0 && continue
      bindfb(FRAMEBUFFER, fb)
      ccall((:glClearBufferfv, GL), Cvoid, (UInt32, Int32, Ptr{Float32}), 0x1800, 0, Float32[0, 0, 0, 0])
      holds && ccall((:glClearBufferfi, GL), Cvoid, (UInt32, Int32, Float32, Int32), 0x84F9, 0, 1f0, 0)
    end
  end
  ccall((:glBindRenderbuffer, GL), Cvoid, (UInt32, UInt32), RENDERBUFFER, s.renderbuffer)
  bindfb(DRAW_FRAMEBUFFER, actual(s, s.draw))
  bindfb(READ_FRAMEBUFFER, actual(s, s.read))
  s.drawn = true
  s
end

"""
A WebGL context for the canvas whose surface is `board`, or nothing when
macOS can't make one.
"""
surface(board; alpha=true, depth=true, stencil=false, antialias=true, premultiplied=true) = begin
  attrs = Int32[99, 0x4100, 73, 96, 0]   # OpenGL 4.1, on the graphics card, which can be one that shows no screen
  pix, n = Ref{Ptr{Cvoid}}(C_NULL), Ref{Int32}(0)
  ccall((:CGLChoosePixelFormat, GL), Int32, (Ptr{Int32}, Ref{Ptr{Cvoid}}, Ref{Int32}), attrs, pix, n) == 0 && pix[] != C_NULL || return nothing
  ctx = Ref{Ptr{Cvoid}}(C_NULL)
  failed = ccall((:CGLCreateContext, GL), Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}), pix[], C_NULL, ctx)
  ccall((:CGLReleasePixelFormat, GL), Cvoid, (Ptr{Cvoid},), pix[])
  (failed == 0 && ctx[] != C_NULL) || return nothing
  push!(OURS, ctx[])
  s = Surface(ctx[], board, 0, 0, alpha, depth, stencil, antialias ? 4 : 0, premultiplied, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false, false,
              Dict{UInt32,Int32}(), false, 0)
  use(s)
  s.vao = made(:glGenVertexArrays)
  ccall((:glBindVertexArray, GL), Cvoid, (UInt32,), s.vao)
  size!(s, board.wide, board.high)
  ccall((:glViewport, GL), Cvoid, (Int32, Int32, Int32, Int32), 0, 0, s.wide, s.high)
  ccall((:glScissor, GL), Cvoid, (Int32, Int32, Int32, Int32), 0, 0, s.wide, s.high)
  # A shader of WebGL sets gl_PointSize with nothing turned on, and the sides of a cube's texture join
  ccall((:glEnable, GL), Cvoid, (UInt32,), 0x8642)   # PROGRAM_POINT_SIZE
  ccall((:glEnable, GL), Cvoid, (UInt32,), 0x884F)   # TEXTURE_CUBE_MAP_SEAMLESS
  finalizer(s) do s
    lock(GOING)
    push!(GONE, s.cgl)
    unlock(GOING)
  end
end

"""
Put the picture of the drawing buffer of `s` in the canvas's surface, if the
script has drawn since it was last put there. paint.jl draws the surface in
the middle of drawing the window, so the context that's current comes back
at once.
"""
present!(s::Surface) = begin
  s.drawn || return
  b = s.board
  (b.wide, b.high) == (s.wide, s.high) && length(b.pixels) >= 4 * s.wide * s.high || return
  was = current()
  setcurrent(s.cgl)
  try
    w, h = s.wide, s.high
    if s.samples > 0
      scissor = enabled(SCISSOR_TEST)
      scissor && ccall((:glDisable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
      bindfb(READ_FRAMEBUFFER, s.msfbo)
      bindfb(DRAW_FRAMEBUFFER, s.fbo)
      ccall((:glBlitFramebuffer, GL), Cvoid, (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32), 0, 0, w, h, 0, 0, w, h, 0x4000, 0x2600)
      scissor && ccall((:glEnable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
    end
    bindfb(READ_FRAMEBUFFER, s.fbo)
    # What the script set of packing is put aside, so the pixels come in rows of their own
    packs = (0x88ED, 0x0D05, 0x0D02, 0x0D03, 0x0D04)   # PIXEL_PACK_BUFFER binding, PACK_ALIGNMENT, PACK_ROW_LENGTH, PACK_SKIP_ROWS, PACK_SKIP_PIXELS
    kept = map(geti, packs)
    ccall((:glBindBuffer, GL), Cvoid, (UInt32, UInt32), 0x88EB, 0)
    ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), 0x0D05, 4)
    foreach(p -> ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), p, 0), packs[3:5])
    GC.@preserve b ccall((:glReadPixels, GL), Cvoid, (Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), 0, 0, w, h, 0x1908, 0x1401, b.pixels)
    ccall((:glBindBuffer, GL), Cvoid, (UInt32, UInt32), 0x88EB, kept[1])
    for (p, v) in zip(packs[2:5], kept[2:5])
      ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), p, v)
    end
    bindfb(DRAW_FRAMEBUFFER, actual(s, s.draw))
    bindfb(READ_FRAMEBUFFER, actual(s, s.read))
    # OpenGL's rows start at the bottom
    px = b.pixels
    row = 4w
    spare = Vector{UInt8}(undef, row)
    for y in 0:h÷2-1
      top, bottom = y * row, (h - 1 - y) * row
      copyto!(spare, 1, px, top + 1, row)
      copyto!(px, top + 1, px, bottom + 1, row)
      copyto!(px, bottom + 1, spare, 1, row)
    end
    # The surface's colours are made fainter by how solid each pixel is. A drawing buffer whose alpha the page didn't
    # premultiply is made so.
    if !s.premultiplied && s.alpha
      @inbounds for i in 1:4:4w*h
        a = px[i+3]
        a == 0xff && continue
        for k in 0:2
          px[i+k] = UInt8((UInt16(px[i+k]) * a + 127) ÷ 255)
        end
      end
    end
    b.changes += 1
    s.drawn = false
  finally
    setcurrent(was)
  end
  nothing
end

# --- reading what a script gives ------------------------------------------------------------

arg(c, a, i) = i <= length(a) ? JS.number(c, a[i]) : 0.0
u32(x::Float64) = isfinite(x) ? (x < 0 ? UInt32(mod(trunc(Int64, x), 2^32)) : UInt32(min(trunc(Int64, x), 0xffffffff))) : UInt32(0)
i32(x::Float64) = isfinite(x) ? Int32(clamp(trunc(Int64, x), typemin(Int32), typemax(Int32))) : Int32(0)
"The WebGL context that the first value names"
surface(c, a) = begin
  s = get(SURFACES, Int(arg(c, a, 1)), nothing)
  s === nothing || s.value === nothing ? error("The WebGL context is lost") : s.value::Surface
end
"The memory of the typed array or the ArrayBuffer that value `i` is, or nothing"
memory(c, a, i) = i <= length(a) ? JS.bytes(c, a[i]) : nothing

# The calls that only take numbers, and that go straight to OpenGL. `u` is a GLenum or a GLuint, `i` a GLint, `f` a
# GLfloat, `d` a GLdouble, `b` a GLboolean, `p` a place in a buffer, and `z` a size or a place as a GLintptr. The
# calls that draw say so with a `!` at the end.
const PLAIN = """
  activeTexture glActiveTexture u;  attachShader glAttachShader uu;  bindBuffer glBindBuffer uu;  bindBufferBase glBindBufferBase uuu
  bindBufferRange glBindBufferRange uuuzz;  bindSampler glBindSampler uu;  bindTexture glBindTexture uu
  blendColor glBlendColor ffff;  blendEquation glBlendEquation u;  blendEquationSeparate glBlendEquationSeparate uu;  blendFunc glBlendFunc uu
  blendFuncSeparate glBlendFuncSeparate uuuu;  blitFramebuffer glBlitFramebuffer iiiiiiiiuu!;  clear glClear u!
  clearColor glClearColor ffff;  clearDepth glClearDepth d;  clearStencil glClearStencil i;  colorMask glColorMask bbbb
  compileShader glCompileShader u;  copyBufferSubData glCopyBufferSubData uuzzz;  copyTexImage2D glCopyTexImage2D uiuiiiii
  copyTexSubImage2D glCopyTexSubImage2D uiiiiiii;  copyTexSubImage3D glCopyTexSubImage3D uiiiiiiii;  cullFace glCullFace u
  depthFunc glDepthFunc u;  depthMask glDepthMask b;  depthRange glDepthRange dd;  detachShader glDetachShader uu;  disable glDisable u
  disableVertexAttribArray glDisableVertexAttribArray u;  drawArrays glDrawArrays uii!;  drawArraysInstanced glDrawArraysInstanced uiii!
  drawElements glDrawElements uiup!;  drawElementsInstanced glDrawElementsInstanced uiupi!;  drawRangeElements glDrawRangeElements uuuiup!
  enable glEnable u;  enableVertexAttribArray glEnableVertexAttribArray u;  finish glFinish ;  flush glFlush
  framebufferRenderbuffer glFramebufferRenderbuffer uuuu;  framebufferTexture2D glFramebufferTexture2D uuuui
  framebufferTextureLayer glFramebufferTextureLayer uuuii;  frontFace glFrontFace u;  generateMipmap glGenerateMipmap u;  hint glHint uu
  linkProgram glLinkProgram u;  polygonOffset glPolygonOffset ff;  sampleCoverage glSampleCoverage fb
  samplerParameteri glSamplerParameteri uui;  samplerParameterf glSamplerParameterf uuf;  scissor glScissor iiii
  stencilFunc glStencilFunc uiu;  stencilFuncSeparate glStencilFuncSeparate uuiu;  stencilMask glStencilMask u
  stencilMaskSeparate glStencilMaskSeparate uu;  stencilOp glStencilOp uuu;  stencilOpSeparate glStencilOpSeparate uuuu
  texParameteri glTexParameteri uui;  texParameterf glTexParameterf uuf;  uniform1f glUniform1f if;  uniform2f glUniform2f iff
  uniform3f glUniform3f ifff;  uniform4f glUniform4f iffff;  uniform1i glUniform1i ii;  uniform2i glUniform2i iii;  uniform3i glUniform3i iiii
  uniform4i glUniform4i iiiii;  uniform1ui glUniform1ui iu;  uniform2ui glUniform2ui iuu;  uniform3ui glUniform3ui iuuu
  uniform4ui glUniform4ui iuuuu;  uniformBlockBinding glUniformBlockBinding uuu;  useProgram glUseProgram u
  validateProgram glValidateProgram u;  vertexAttrib1f glVertexAttrib1f uf;  vertexAttrib2f glVertexAttrib2f uff
  vertexAttrib3f glVertexAttrib3f ufff;  vertexAttrib4f glVertexAttrib4f uffff;  vertexAttribI4i glVertexAttribI4i uiiii
  vertexAttribI4ui glVertexAttribI4ui uuuuu;  vertexAttribDivisor glVertexAttribDivisor uu;  vertexAttribPointer glVertexAttribPointer uiubip
  vertexAttribIPointer glVertexAttribIPointer uiuip;  viewport glViewport iiii
"""

const NATIVES = Dict{String,Function}()

let types = Dict('u' => :UInt32, 'i' => :Int32, 'f' => :Float32, 'd' => :Float64, 'b' => :UInt8, 'p' => :(Ptr{Cvoid}), 'z' => :Int)
  reader(k, i) = k == 'u' ? :(u32(arg(c, a, $i))) : k == 'i' ? :(i32(arg(c, a, $i))) : k == 'f' ? :(Float32(arg(c, a, $i))) :
               k == 'd' ? :(arg(c, a, $i)) : k == 'b' ? :(UInt8(JS.flag(c, a[$i]))) : k == 'p' ? :(Ptr{Cvoid}(trunc(Int, arg(c, a, $i)))) :
               :(trunc(Int, arg(c, a, $i)))
  for entry in split(PLAIN, r"[;\n]")
    parts = split(strip(entry))
    isempty(parts) && continue
    name, fn = parts[1], Symbol(parts[2])
    kinds = length(parts) > 2 ? parts[3] : ""
    draws = endswith(kinds, '!')
    kinds = rstrip(kinds, '!')
    args = [reader(k, i + 1) for (i, k) in enumerate(kinds)]
    sig = Expr(:tuple, [types[k] for k in kinds]...)
    NATIVES[name] = @eval (c, a) -> begin
      s = surface(c, a)
      use(s)
      ccall(($(QuoteNode(fn)), GL), Cvoid, $sig, $(args...))
      $(draws ? :(s.drawn = true) : nothing)
      nothing
    end
  end
end

# The calls that set a uniform from an array: the name, OpenGL's function, how many numbers each has, and whether it's a matrix
for (name, fn, each, matrix) in (("uniform1fv", :glUniform1fv, 1, false), ("uniform2fv", :glUniform2fv, 2, false), ("uniform3fv", :glUniform3fv, 3, false),
                                 ("uniform4fv", :glUniform4fv, 4, false), ("uniform1iv", :glUniform1iv, 1, false), ("uniform2iv", :glUniform2iv, 2, false),
                                 ("uniform3iv", :glUniform3iv, 3, false), ("uniform4iv", :glUniform4iv, 4, false), ("uniform1uiv", :glUniform1uiv, 1, false),
                                 ("uniform2uiv", :glUniform2uiv, 2, false), ("uniform3uiv", :glUniform3uiv, 3, false), ("uniform4uiv", :glUniform4uiv, 4, false),
                                 ("uniformMatrix2fv", :glUniformMatrix2fv, 4, true), ("uniformMatrix3fv", :glUniformMatrix3fv, 9, true),
                                 ("uniformMatrix4fv", :glUniformMatrix4fv, 16, true), ("uniformMatrix2x3fv", :glUniformMatrix2x3fv, 6, true),
                                 ("uniformMatrix3x2fv", :glUniformMatrix3x2fv, 6, true), ("uniformMatrix2x4fv", :glUniformMatrix2x4fv, 8, true),
                                 ("uniformMatrix4x2fv", :glUniformMatrix4x2fv, 8, true), ("uniformMatrix3x4fv", :glUniformMatrix3x4fv, 12, true),
                                 ("uniformMatrix4x3fv", :glUniformMatrix4x3fv, 12, true))
  # The script gives (surface, location, data), or (surface, location, transpose, data) for a matrix
  NATIVES[name] = @eval (c, a) -> begin
    s = surface(c, a)
    use(s)
    m = memory(c, a, $(matrix ? 4 : 3))
    m === nothing && return nothing
    count = m[2] ÷ (4 * $each)
    count == 0 && return nothing
    $(matrix ? :(ccall(($(QuoteNode(fn)), GL), Cvoid, (Int32, Int32, UInt8, Ptr{UInt8}), i32(arg(c, a, 2)), count, UInt8(JS.flag(c, a[3])), m[1])) :
               :(ccall(($(QuoteNode(fn)), GL), Cvoid, (Int32, Int32, Ptr{UInt8}), i32(arg(c, a, 2)), count, m[1])))
    nothing
  end
end

# --- shaders ------------------------------------------------------------------------------

"""
The shader `code` of WebGL, of the kind `kind` (VERTEX_SHADER or
FRAGMENT_SHADER), as OpenGL 4.1 takes it. A shader of WebGL 2 says
`#version 300 es`, which becomes `#version 410`. One of WebGL 1 says no
version, and gets the words that OpenGL 4.1 has in place of its own.
"""
glsl(code::AbstractString, kind) = begin
  m = match(r"^(\s*(?://[^\n]*\n\s*)*)#version\s+300\s+es[^\n]*"s, code)
  m !== nothing && return m[1] * "#version 410" * code[ncodeunits(m.match)+1:end]
  # WebGL 1: its extensions are part of OpenGL 4.1
  body = replace(code, r"^[ \t]*#version[^\n]*"m => "", r"^[ \t]*#extension[^\n]*"m => "")
  body = replace(body, r"\bgl_FragDepthEXT\b" => "gl_FragDepth", r"\btexture2DLodEXT\b" => "textureLod", r"\btextureCubeLodEXT\b" => "textureLod",
                 r"\btexture2DGradEXT\b" => "textureGrad", r"\btextureCubeGradEXT\b" => "textureGrad")
  head = "#version 410\n#define texture2D texture\n#define textureCube texture\n#define texture2DProj textureProj\n#define texture2DLod textureLod\n#define textureCubeLod textureLod\n"
  if kind == 0x8B31   # VERTEX_SHADER
    head *= "#define attribute in\n#define varying out\n"
  else
    head *= "#define varying in\n"
    occursin("gl_FragData", body) ? (head *= "out vec4 lm_FragData[8];\n#define gl_FragData lm_FragData\n") :
                                    (head *= "out vec4 lm_FragColor;\n#define gl_FragColor lm_FragColor\n")
  end
  head * body
end

"The log of a shader or a program: `getiv` and `log` are OpenGL's functions for it"
infolog(getiv, log, name) = begin
  n = Ref{Int32}(0)
  ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), getiv), Cvoid, (UInt32, UInt32, Ref{Int32}), name, 0x8B84, n)   # INFO_LOG_LENGTH
  n[] <= 1 && return ""
  buf = zeros(UInt8, n[])
  len = Ref{Int32}(0)
  ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), log), Cvoid, (UInt32, Int32, Ref{Int32}, Ptr{UInt8}), name, n[], len, buf)
  String(buf[1:len[]])
end

# --- textures -----------------------------------------------------------------------------

# For each sized format of a texture, the format and the type of the pixels that make it. OpenGL 4.1 has no
# texStorage2D, so a texture's levels are made with glTexImage2D, which needs these.
const SIZED = Dict{UInt32,Tuple{UInt32,UInt32}}(
  0x8229 => (0x1903, 0x1401), 0x8F94 => (0x1903, 0x1400), 0x822D => (0x1903, 0x140B), 0x822E => (0x1903, 0x1406),
  0x8232 => (0x8D94, 0x1401), 0x8231 => (0x8D94, 0x1400), 0x8234 => (0x8D94, 0x1403), 0x8233 => (0x8D94, 0x1402), 0x8236 => (0x8D94, 0x1405), 0x8235 => (0x8D94, 0x1404),
  0x822B => (0x8227, 0x1401), 0x8F95 => (0x8227, 0x1400), 0x822F => (0x8227, 0x140B), 0x8230 => (0x8227, 0x1406),
  0x8238 => (0x8228, 0x1401), 0x8237 => (0x8228, 0x1400), 0x823A => (0x8228, 0x1403), 0x8239 => (0x8228, 0x1402), 0x823C => (0x8228, 0x1405), 0x823B => (0x8228, 0x1404),
  0x8051 => (0x1907, 0x1401), 0x8C41 => (0x1907, 0x1401), 0x8D62 => (0x1907, 0x1401), 0x8C3A => (0x1907, 0x1406), 0x8C3D => (0x1907, 0x1406),
  0x881B => (0x1907, 0x140B), 0x8815 => (0x1907, 0x1406), 0x8F96 => (0x1907, 0x1400),
  0x8D7D => (0x8D98, 0x1401), 0x8D8F => (0x8D98, 0x1400), 0x8D77 => (0x8D98, 0x1403), 0x8D89 => (0x8D98, 0x1402), 0x8D71 => (0x8D98, 0x1405), 0x8D83 => (0x8D98, 0x1404),
  0x8058 => (0x1908, 0x1401), 0x8C43 => (0x1908, 0x1401), 0x8F97 => (0x1908, 0x1400), 0x8057 => (0x1908, 0x1401), 0x8056 => (0x1908, 0x1401),
  0x8059 => (0x1908, 0x8368), 0x881A => (0x1908, 0x140B), 0x8814 => (0x1908, 0x1406),
  0x8D7C => (0x8D99, 0x1401), 0x8D8E => (0x8D99, 0x1400), 0x906F => (0x8D99, 0x8368), 0x8D76 => (0x8D99, 0x1403), 0x8D88 => (0x8D99, 0x1402),
  0x8D70 => (0x8D99, 0x1405), 0x8D82 => (0x8D99, 0x1404),
  0x81A5 => (0x1902, 0x1403), 0x81A6 => (0x1902, 0x1405), 0x8CAC => (0x1902, 0x1406), 0x88F0 => (0x84F9, 0x84FA), 0x8CAD => (0x84F9, 0x8DAD))

const LUMINANCE, ALPHA, LUMINANCE_ALPHA, RED, RG, RGB, RGBA = 0x1909, 0x1906, 0x190A, 0x1903, 0x8227, 0x1907, 0x1908
const UNSIGNED_BYTE, FLOAT, HALF_FLOAT, HALF_FLOAT_OES = 0x1401, 0x1406, 0x140B, 0x8D61

"""
The internal format, the format and the type that OpenGL 4.1 takes for what
WebGL calls `internal`, `format` and `type`, and the order to read a red or a
red and green texture's colours in, for LUMINANCE and ALPHA, or nothing.
"""
formats(internal, format, type) = begin
  type == HALF_FLOAT_OES && (type = HALF_FLOAT)
  swizzle = nothing
  if format in (LUMINANCE, ALPHA, LUMINANCE_ALPHA)
    swizzle = format == LUMINANCE ? (RED, RED, RED, 0x1) : format == ALPHA ? (0x0, 0x0, 0x0, RED) : (RED, RED, RED, 0x1904)   # 0 and 1 are ZERO and ONE, 0x1904 GREEN
    two = format == LUMINANCE_ALPHA
    format = two ? RG : RED
    internal = type == FLOAT ? (two ? 0x8230 : 0x822E) : type == HALF_FLOAT ? (two ? 0x822F : 0x822D) : (two ? 0x822B : 0x8229)
  elseif internal in (RGB, RGBA) && type in (FLOAT, HALF_FLOAT)
    # WebGL 1's float textures have no size in their name
    internal = internal == RGBA ? (type == FLOAT ? 0x8814 : 0x881A) : (type == FLOAT ? 0x8815 : 0x881B)
  end
  (internal, format, type, swizzle)
end

"Read a texture's colours in the order `swizzle`, as LUMINANCE and ALPHA need"
swizzle!(target, swizzle) = swizzle === nothing ||
  ccall((:glTexParameteriv, GL), Cvoid, (UInt32, UInt32, Ptr{Int32}), target, 0x8E46, Int32[swizzle...])   # TEXTURE_SWIZZLE_RGBA

"How many bytes one pixel of `format` and `type` takes"
pixel_bytes(format, type) = begin
  type in (0x8033, 0x8034, 0x8363) && return 2        # 4444, 5551, 565
  type in (0x8368, 0x84FA, 0x8C3B, 0x8C3E) && return 4
  type == 0x8DAD && return 8
  n = format in (RED, 0x8D94, 0x1902, LUMINANCE, ALPHA) ? 1 : format in (RG, 0x8228, LUMINANCE_ALPHA, 0x84F9) ? 2 : format in (RGB, 0x8D98) ? 3 : 4
  n * (type in (0x1400, 0x1401) ? 1 : type in (0x1402, 0x1403, HALF_FLOAT) ? 2 : 4)
end

"A copy of the `high` rows of `data`, each `row` bytes, in the other order, for UNPACK_FLIP_Y_WEBGL"
flipped(data::Ptr{UInt8}, row, high, layers=1) = begin
  out = Vector{UInt8}(undef, row * high * layers)
  src = unsafe_wrap(Array, data, row * high * layers)
  for l in 0:layers-1, y in 0:high-1
    copyto!(out, (l * high + y) * row + 1, src, (l * high + high - 1 - y) * row + 1, row)
  end
  out
end

"The rows of a texture's pixels are this many bytes apart, for pixels `wide` across of `format` and `type`"
row_bytes(s::Surface, wide, format, type) = begin
  align = get(s.unpack, 0x0CF5, Int32(4))
  len = get(s.unpack, 0x0CF2, Int32(0))
  n = (len > 0 ? len : wide) * pixel_bytes(format, type)
  cld(n, align) * align
end

"""
The pixels of `image`, a picture of Skia, as RGBA bytes from the top row
down, with the colours made fainter by how solid each pixel is when
`multiply`, and in the other order of rows when `flip`.
"""
picture_pixels(image::Ptr{Cvoid}, multiply, flip) = begin
  w, h = Int(Skia.sk_image_get_width(image)), Int(Skia.sk_image_get_height(image))
  out = Vector{UInt8}(undef, 4 * max(w, 1) * max(h, 1))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, multiply ? Skia.SK_ALPHA_TYPE_PREMUL : Skia.SK_ALPHA_TYPE_UNPREMUL, w, h))
  ok = GC.@preserve info out Skia.sk_image_read_pixels(image, pointer_from_objref(info), out, Csize_t(4w), Cint(0), Cint(0), Skia.SK_IMAGE_CACHING_HINT_ALLOW)
  ok || return nothing
  flip && (out = GC.@preserve out flipped(pointer(out), 4w, h))
  (out, w, h)
end

"""
Do `f` with OpenGL's unpacking as a new context has it, so that pixels made
here are read as they are. What the script set comes back after.
"""
unpacked(f, s::Surface) = begin
  pbo = geti(0x88EF)   # PIXEL_UNPACK_BUFFER_BINDING
  pbo == 0 || ccall((:glBindBuffer, GL), Cvoid, (UInt32, UInt32), 0x88EC, 0)
  plain = (0x0CF5 => 4, 0x0CF2 => 0, 0x0CF3 => 0, 0x0CF4 => 0, 0x806E => 0, 0x806D => 0)
  for (p, v) in plain
    get(s.unpack, p, Int32(v)) == v || ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), p, v)
  end
  try
    f()
  finally
    for (p, v) in plain
      get(s.unpack, p, Int32(v)) == v || ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), p, s.unpack[p])
    end
    pbo == 0 || ccall((:glBindBuffer, GL), Cvoid, (UInt32, UInt32), 0x88EC, pbo)
  end
end

# --- the calls that need more than OpenGL's own ----------------------------------------------

const GENS = Dict("buffer" => :glGenBuffers, "texture" => :glGenTextures, "framebuffer" => :glGenFramebuffers, "renderbuffer" => :glGenRenderbuffers,
                  "vertexArray" => :glGenVertexArrays, "sampler" => :glGenSamplers, "transformFeedback" => :glGenTransformFeedbacks)
const DELETES = Dict("buffer" => :glDeleteBuffers, "texture" => :glDeleteTextures, "framebuffer" => :glDeleteFramebuffers, "renderbuffer" => :glDeleteRenderbuffers,
                     "vertexArray" => :glDeleteVertexArrays, "sampler" => :glDeleteSamplers, "transformFeedback" => :glDeleteTransformFeedbacks)

# What getParameter gives for each name that isn't one number: :ints, :floats or :flags, and how many
const SHAPES = Dict{UInt32,Tuple{Symbol,Int}}(0x0BA2 => (:ints, 4), 0x0C10 => (:ints, 4), 0x0D3A => (:ints, 2), 0x0C22 => (:floats, 4), 0x8005 => (:floats, 4),
                                             0x0B70 => (:floats, 2), 0x846E => (:floats, 2), 0x846D => (:floats, 2), 0x0C23 => (:flags, 4))
const FLAGS = Set{UInt32}([0x0BE2, 0x0B44, 0x0B71, 0x0BD0, 0x8037, 0x809E, 0x80A0, 0x0C11, 0x0B90, 0x0B72, 0x8C89, 0x80AB, 0x8E24])
const FLOATS = Set{UInt32}([0x0B73, 0x0B21, 0x8038, 0x2A00, 0x80AA, 0x84FD, 0x84FF])

"The natives of the WebGL contexts of a page: see `start!`"
natives(js::Context; node, picture, board) = begin
  out = Dict{String,Any}(name => Raw(f) for (name, f) in NATIVES)
  raw(name, f) = (out[name] = Raw(f))
  # A context for the canvas with the number `id`, with its attributes. Gives its number, or 0 when macOS can't make one.
  raw("make", (c, a) -> begin
    e = node(Int(arg(c, a, 1)))::Element
    b = board(e)
    s = surface(b; alpha=JS.flag(c, a[2]), depth=JS.flag(c, a[3]), stencil=JS.flag(c, a[4]), antialias=JS.flag(c, a[5]), premultiplied=JS.flag(c, a[6]))
    s === nothing && return 0
    b.ready = _ -> present!(s)
    SURFACES[LAST[] += 1] = WeakRef(s)
    LAST[]
  end)
  # The canvas's size changed, so the drawing buffer's does
  raw("resize", (c, a) -> begin
    s = surface(c, a)
    b = s.board
    (b.wide, b.high) == (s.wide, s.high) || size!(s, b.wide, b.high)
    nothing
  end)
  raw("create", (c, a) -> begin
    s = surface(c, a)
    use(s)
    kind = JS.text(c, a[2])
    kind == "program" && return Int(ccall((:glCreateProgram, GL), UInt32, ()))
    kind == "shader" && return Int(ccall((:glCreateShader, GL), UInt32, (UInt32,), u32(arg(c, a, 3))))
    Int(made(GENS[kind]))
  end)
  raw("delete", (c, a) -> begin
    s = surface(c, a)
    use(s)
    kind, name = JS.text(c, a[2]), u32(arg(c, a, 3))
    name == 0 && return nothing
    if kind == "program"
      ccall((:glDeleteProgram, GL), Cvoid, (UInt32,), name)
    elseif kind == "shader"
      ccall((:glDeleteShader, GL), Cvoid, (UInt32,), name)
    else
      ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), DELETES[kind]), Cvoid, (Int32, Ref{UInt32}), 1, Ref(name))
    end
    # What was bound and is gone is the script's null, which is the drawing buffer and the vertex array that stands for its own
    if kind == "framebuffer"
      s.draw == name && (s.draw = 0; bindfb(DRAW_FRAMEBUFFER, actual(s, 0)))
      s.read == name && (s.read = 0; bindfb(READ_FRAMEBUFFER, actual(s, 0)))
    elseif kind == "vertexArray"
      geti(0x85B5) == 0 && ccall((:glBindVertexArray, GL), Cvoid, (UInt32,), s.vao)
    elseif kind == "renderbuffer"
      s.renderbuffer == name && (s.renderbuffer = 0)
    end
    nothing
  end)
  raw("bindFramebuffer", (c, a) -> begin
    s = surface(c, a)
    use(s)
    target, fb = u32(arg(c, a, 2)), u32(arg(c, a, 3))
    target in (FRAMEBUFFER, DRAW_FRAMEBUFFER) && (s.draw = fb)
    target in (FRAMEBUFFER, READ_FRAMEBUFFER) && (s.read = fb)
    bindfb(target, actual(s, fb))
    nothing
  end)
  raw("bindRenderbuffer", (c, a) -> begin
    s = surface(c, a)
    use(s)
    s.renderbuffer = u32(arg(c, a, 3))
    ccall((:glBindRenderbuffer, GL), Cvoid, (UInt32, UInt32), RENDERBUFFER, s.renderbuffer)
    nothing
  end)
  raw("bindVertexArray", (c, a) -> begin
    s = surface(c, a)
    use(s)
    v = u32(arg(c, a, 2))
    ccall((:glBindVertexArray, GL), Cvoid, (UInt32,), v == 0 ? s.vao : v)
    nothing
  end)
  renderbuffer(f) = (c, a) -> begin
    s = surface(c, a)
    use(s)
    internal = u32(arg(c, a, f == :plain ? 3 : 4))
    internal == 0x84F9 && (internal = 0x88F0)   # WebGL's DEPTH_STENCIL is DEPTH24_STENCIL8
    f == :plain ? ccall((:glRenderbufferStorage, GL), Cvoid, (UInt32, UInt32, Int32, Int32), u32(arg(c, a, 2)), internal, i32(arg(c, a, 4)), i32(arg(c, a, 5))) :
                  ccall((:glRenderbufferStorageMultisample, GL), Cvoid, (UInt32, Int32, UInt32, Int32, Int32), u32(arg(c, a, 2)), i32(arg(c, a, 3)), internal,
                        i32(arg(c, a, 5)), i32(arg(c, a, 6)))
    nothing
  end
  raw("renderbufferStorage", renderbuffer(:plain))
  raw("renderbufferStorageMultisample", renderbuffer(:samples))
  raw("readBuffer", (c, a) -> begin
    s = surface(c, a)
    use(s)
    src = u32(arg(c, a, 2))
    ccall((:glReadBuffer, GL), Cvoid, (UInt32,), src == 0x0405 ? 0x8CE0 : src)   # BACK is the drawing buffer's colour
    nothing
  end)
  raw("drawBuffers", (c, a) -> begin
    s = surface(c, a)
    use(s)
    list = UInt32[(b = u32(arg(c, a, i)); b == 0x0405 ? 0x8CE0 : b) for i in 2:length(a)]
    ccall((:glDrawBuffers, GL), Cvoid, (Int32, Ptr{UInt32}), length(list), list)
    nothing
  end)
  # clearBufferfv, iv and uiv: the buffer, which of them, and up to 4 numbers
  for (name, fn, T) in (("clearBufferfv", :glClearBufferfv, Float32), ("clearBufferiv", :glClearBufferiv, Int32), ("clearBufferuiv", :glClearBufferuiv, UInt32))
    raw(name, (c, a) -> begin
      s = surface(c, a)
      use(s)
      values = zeros(T, 4)
      for i in 4:min(length(a), 7)
        x = arg(c, a, i)
        values[i-3] = T === Float32 ? Float32(x) : T === Int32 ? i32(x) : u32(x)
      end
      ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), fn), Cvoid, (UInt32, Int32, Ptr{Cvoid}), u32(arg(c, a, 2)), i32(arg(c, a, 3)), values)
      s.drawn = true
      nothing
    end)
  end
  raw("clearBufferfi", (c, a) -> begin
    s = surface(c, a)
    use(s)
    ccall((:glClearBufferfi, GL), Cvoid, (UInt32, Int32, Float32, Int32), u32(arg(c, a, 2)), i32(arg(c, a, 3)), Float32(arg(c, a, 4)), i32(arg(c, a, 5)))
    s.drawn = true
    nothing
  end)
  raw("lineWidth", (c, a) -> nothing)   # OpenGL 4.1 draws lines one pixel wide, as most browsers do
  raw("pixelStorei", (c, a) -> begin
    s = surface(c, a)
    use(s)
    pname, v = u32(arg(c, a, 2)), arg(c, a, 3)
    if pname == 0x9240
      s.flip = v != 0
    elseif pname == 0x9241
      s.multiply = v != 0
    elseif pname == 0x9243
      # How colours are changed, which they aren't here
    else
      s.unpack[pname] = i32(v)
      ccall((:glPixelStorei, GL), Cvoid, (UInt32, Int32), pname, i32(v))
    end
    nothing
  end)
  raw("getError", (c, a) -> begin
    s = surface(c, a)
    use(s)
    e = s.error
    s.error = 0
    e != 0 ? Int(e) : Int(ccall((:glGetError, GL), UInt32, ()))
  end)
  raw("isEnabled", (c, a) -> (s = surface(c, a); use(s); enabled(u32(arg(c, a, 2)))))
  raw("checkFramebufferStatus", (c, a) -> (s = surface(c, a); use(s); Int(ccall((:glCheckFramebufferStatus, GL), UInt32, (UInt32,), u32(arg(c, a, 2))))))
  # A number, a list of numbers or of flags, or a string, for getParameter. The script answers for what it binds.
  raw("getParameter", (c, a) -> begin
    s = surface(c, a)
    use(s)
    p = u32(arg(c, a, 2))
    p == 0x9240 && return s.flip
    p == 0x9241 && return s.multiply
    p == 0x9243 && return 0x9244
    p in (0x1F00, 0x1F01, 0x1F02, 0x8B8C) && return unsafe_string(ccall((:glGetString, GL), Ptr{UInt8}, (UInt32,), p))
    shape = get(SHAPES, p, nothing)
    if shape !== nothing
      kind, n = shape
      if kind == :ints
        v = zeros(Int32, n); ccall((:glGetIntegerv, GL), Cvoid, (UInt32, Ptr{Int32}), p, v)
        return Any["ints", Float64.(v)...]
      elseif kind == :floats
        v = zeros(Float32, n); ccall((:glGetFloatv, GL), Cvoid, (UInt32, Ptr{Float32}), p, v)
        return Any["floats", Float64.(v)...]
      else
        v = zeros(UInt8, n); ccall((:glGetBooleanv, GL), Cvoid, (UInt32, Ptr{UInt8}), p, v)
        return Any["flags", (v .!= 0)...]
      end
    end
    p in FLAGS && return enabled(p) || (v = Ref{UInt8}(0); ccall((:glGetBooleanv, GL), Cvoid, (UInt32, Ref{UInt8}), p, v); v[] != 0)
    p in FLOATS && return (v = Ref{Float32}(0); ccall((:glGetFloatv, GL), Cvoid, (UInt32, Ref{Float32}), p, v); Float64(v[]))
    Float64(geti(p))
  end)
  raw("getShaderPrecisionFormat", (c, a) -> begin
    s = surface(c, a)
    use(s)
    range, precision = zeros(Int32, 2), Ref{Int32}(0)
    ccall((:glGetShaderPrecisionFormat, GL), Cvoid, (UInt32, UInt32, Ptr{Int32}, Ref{Int32}), u32(arg(c, a, 2)), u32(arg(c, a, 3)), range, precision)
    Float64[range[1], range[2], precision[]]
  end)
  raw("shaderSource", (c, a) -> begin
    s = surface(c, a)
    use(s)
    shader = u32(arg(c, a, 2))
    kind = Ref{Int32}(0)
    ccall((:glGetShaderiv, GL), Cvoid, (UInt32, UInt32, Ref{Int32}), shader, 0x8B4F, kind)   # SHADER_TYPE
    code = glsl(JS.text(c, a[3]), UInt32(kind[]))
    GC.@preserve code ccall((:glShaderSource, GL), Cvoid, (UInt32, Int32, Ref{Ptr{UInt8}}, Ptr{Int32}), shader, 1, Ref(pointer(code)), C_NULL)
    nothing
  end)
  status(getiv) = (c, a) -> begin
    s = surface(c, a)
    use(s)
    p = u32(arg(c, a, 3))
    v = Ref{Int32}(0)
    ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), getiv), Cvoid, (UInt32, UInt32, Ref{Int32}), u32(arg(c, a, 2)), p, v)
    # COMPILE_STATUS, LINK_STATUS, VALIDATE_STATUS and DELETE_STATUS are true or false, and the rest are numbers
    p in (0x8B81, 0x8B82, 0x8B83, 0x8B80) ? v[] != 0 : Float64(v[])
  end
  raw("getShaderParameter", status(:glGetShaderiv))
  raw("getProgramParameter", status(:glGetProgramiv))
  raw("getShaderInfoLog", (c, a) -> (s = surface(c, a); use(s); infolog(:glGetShaderiv, :glGetShaderInfoLog, u32(arg(c, a, 2)))))
  raw("getProgramInfoLog", (c, a) -> (s = surface(c, a); use(s); infolog(:glGetProgramiv, :glGetProgramInfoLog, u32(arg(c, a, 2)))))
  # A location or an index that a program has for a name. An index of a block that isn't there is INVALID_INDEX, 0xffffffff.
  named(fn; unsigned=false) = (c, a) -> begin
    s = surface(c, a)
    use(s)
    name = JS.text(c, a[3])
    at = ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), fn), Int32, (UInt32, Cstring), u32(arg(c, a, 2)), name)
    Float64(unsigned ? reinterpret(UInt32, at) : at)
  end
  raw("getAttribLocation", named(:glGetAttribLocation))
  raw("getUniformLocation", named(:glGetUniformLocation))
  raw("getUniformBlockIndex", named(:glGetUniformBlockIndex; unsigned=true))
  raw("bindAttribLocation", (c, a) -> begin
    s = surface(c, a)
    use(s)
    ccall((:glBindAttribLocation, GL), Cvoid, (UInt32, UInt32, Cstring), u32(arg(c, a, 2)), u32(arg(c, a, 3)), JS.text(c, a[4]))
    nothing
  end)
  active(fn, count) = (c, a) -> begin
    s = surface(c, a)
    use(s)
    program, i = u32(arg(c, a, 2)), u32(arg(c, a, 3))
    n = Ref{Int32}(0)
    ccall((:glGetProgramiv, GL), Cvoid, (UInt32, UInt32, Ref{Int32}), program, count, n)
    i < n[] || return nothing
    buf, len, size, type = zeros(UInt8, 512), Ref{Int32}(0), Ref{Int32}(0), Ref{UInt32}(0)
    ccall(Libc.Libdl.dlsym(Libc.Libdl.dlopen(GL), fn), Cvoid, (UInt32, UInt32, Int32, Ref{Int32}, Ref{Int32}, Ref{UInt32}, Ptr{UInt8}), program, i, 512, len, size, type, buf)
    Any[Float64(size[]), Float64(type[]), String(buf[1:len[]])]
  end
  raw("getActiveUniform", active(:glGetActiveUniform, 0x8B86))
  raw("getActiveAttrib", active(:glGetActiveAttrib, 0x8B89))
  raw("getActiveUniformBlockParameter", (c, a) -> begin
    s = surface(c, a)
    use(s)
    program, block, p = u32(arg(c, a, 2)), u32(arg(c, a, 3)), u32(arg(c, a, 4))
    if p == 0x8A43   # UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES
      n = Ref{Int32}(0)
      ccall((:glGetActiveUniformBlockiv, GL), Cvoid, (UInt32, UInt32, UInt32, Ref{Int32}), program, block, 0x8A42, n)
      v = zeros(Int32, max(n[], 1))
      ccall((:glGetActiveUniformBlockiv, GL), Cvoid, (UInt32, UInt32, UInt32, Ptr{Int32}), program, block, p, v)
      return Float64.(v[1:n[]])
    end
    v = Ref{Int32}(0)
    ccall((:glGetActiveUniformBlockiv, GL), Cvoid, (UInt32, UInt32, UInt32, Ref{Int32}), program, block, p, v)
    p in (0x8A44, 0x8A46) ? v[] != 0 : Float64(v[])
  end)
  # Buffers: (target, size, usage), (target, data, usage), (target, place, data) and (target, place, data to fill)
  raw("bufferSize", (c, a) -> begin
    s = surface(c, a)
    use(s)
    ccall((:glBufferData, GL), Cvoid, (UInt32, Int, Ptr{Cvoid}, UInt32), u32(arg(c, a, 2)), trunc(Int, arg(c, a, 3)), C_NULL, u32(arg(c, a, 4)))
    nothing
  end)
  raw("bufferData", (c, a) -> begin
    s = surface(c, a)
    use(s)
    m = memory(c, a, 3)
    p, n = m === nothing ? (Ptr{UInt8}(0), 0) : (m[1], m[2])
    ccall((:glBufferData, GL), Cvoid, (UInt32, Int, Ptr{UInt8}, UInt32), u32(arg(c, a, 2)), n, p, u32(arg(c, a, 4)))
    nothing
  end)
  raw("bufferSubData", (c, a) -> begin
    s = surface(c, a)
    use(s)
    m = memory(c, a, 4)
    m === nothing && return nothing
    ccall((:glBufferSubData, GL), Cvoid, (UInt32, Int, Int, Ptr{UInt8}), u32(arg(c, a, 2)), trunc(Int, arg(c, a, 3)), m[2], m[1])
    nothing
  end)
  raw("getBufferSubData", (c, a) -> begin
    s = surface(c, a)
    use(s)
    m = memory(c, a, 4)
    m === nothing && return nothing
    ccall((:glGetBufferSubData, GL), Cvoid, (UInt32, Int, Int, Ptr{UInt8}), u32(arg(c, a, 2)), trunc(Int, arg(c, a, 3)), m[2], m[1])
    nothing
  end)
  # readPixels(x, y, w, h, format, type, data), or with a place in the PIXEL_PACK_BUFFER in place of data
  raw("readPixels", (c, a) -> begin
    s = surface(c, a)
    use(s)
    x, y, w, h = (i32(arg(c, a, i)) for i in 2:5)
    format, type = u32(arg(c, a, 6)), u32(arg(c, a, 7))
    m = memory(c, a, 8)
    p = m === nothing ? Ptr{UInt8}(trunc(Int, arg(c, a, 8))) : m[1]
    # The drawing buffer with antialias is resolved first: OpenGL reads no framebuffer with samples
    resolve = s.read == 0 && s.samples > 0
    if resolve
      scissor = enabled(SCISSOR_TEST)
      scissor && ccall((:glDisable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
      bindfb(DRAW_FRAMEBUFFER, s.fbo)
      ccall((:glBlitFramebuffer, GL), Cvoid, (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32), 0, 0, s.wide, s.high, 0, 0, s.wide, s.high, 0x4000, 0x2600)
      scissor && ccall((:glEnable, GL), Cvoid, (UInt32,), SCISSOR_TEST)
      bindfb(READ_FRAMEBUFFER, s.fbo)
    end
    ccall((:glReadPixels, GL), Cvoid, (Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), x, y, w, h, format, type, p)
    resolve && (bindfb(READ_FRAMEBUFFER, actual(s, s.read)); bindfb(DRAW_FRAMEBUFFER, actual(s, s.draw)))
    nothing
  end)
  # texStorage2D(target, levels, internal, w, h) and texStorage3D(target, levels, internal, w, h, d): each level, made with texImage
  raw("texStorage2D", (c, a) -> begin
    s = surface(c, a)
    use(s)
    target, levels, internal, w, h = u32(arg(c, a, 2)), i32(arg(c, a, 3)), u32(arg(c, a, 4)), i32(arg(c, a, 5)), i32(arg(c, a, 6))
    format, type = get(SIZED, internal, (RGBA, UNSIGNED_BYTE))
    targets = target == 0x8513 ? (0x8515:0x851A) : (target,)   # each side of a cube
    unpacked(s) do
      for l in 0:levels-1, t in targets
        ccall((:glTexImage2D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{Cvoid}), t, l, internal, max(1, w >> l), max(1, h >> l), 0, format, type, C_NULL)
      end
    end
    ccall((:glTexParameteri, GL), Cvoid, (UInt32, UInt32, Int32), target, 0x813D, levels - 1)   # TEXTURE_MAX_LEVEL
    nothing
  end)
  raw("texStorage3D", (c, a) -> begin
    s = surface(c, a)
    use(s)
    target, levels, internal, w, h, d = u32(arg(c, a, 2)), i32(arg(c, a, 3)), u32(arg(c, a, 4)), i32(arg(c, a, 5)), i32(arg(c, a, 6)), i32(arg(c, a, 7))
    format, type = get(SIZED, internal, (RGBA, UNSIGNED_BYTE))
    unpacked(s) do
      for l in 0:levels-1
        depth = target == 0x806F ? max(1, d >> l) : d   # a 3D texture's depth halves with each level, and an array's layers stay
        ccall((:glTexImage3D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{Cvoid}), target, l, internal, max(1, w >> l), max(1, h >> l), depth, 0, format, type, C_NULL)
      end
    end
    ccall((:glTexParameteri, GL), Cvoid, (UInt32, UInt32, Int32), target, 0x813D, levels - 1)
    nothing
  end)
  # texImage2D(target, level, internal, w, h, border, format, type, data): data is a typed array, a place in the PIXEL_UNPACK_BUFFER, or null
  # texSubImage2D(target, level, x, y, w, h, format, type, data)
  # texImage3D(target, level, internal, w, h, d, border, format, type, data), texSubImage3D(target, level, x, y, z, w, h, d, format, type, data)
  upload(dims, sub) = (c, a) -> begin
    s = surface(c, a)
    use(s)
    target, level = u32(arg(c, a, 2)), i32(arg(c, a, 3))
    if dims == 2
      internal_at, size_at = sub ? (0, 6) : (4, 5)
    else
      internal_at, size_at = sub ? (0, 7) : (4, 5)
    end
    w, h = i32(arg(c, a, size_at)), i32(arg(c, a, size_at + 1))
    d = dims == 3 ? i32(arg(c, a, size_at + 2)) : Int32(1)
    at = size_at + dims + (sub ? 0 : 1)   # the format, after the size and a border
    format, type = u32(arg(c, a, at)), u32(arg(c, a, at + 1))
    internal = sub ? UInt32(0) : u32(arg(c, a, internal_at))
    internal, format, type, swizzle = formats(internal, format, type)
    m = memory(c, a, at + 2)
    data = m === nothing ? (at + 2 <= length(a) && !JS.none(c, a[at+2]) ? Ptr{UInt8}(trunc(Int, arg(c, a, at + 2))) : Ptr{UInt8}(0)) : m[1]
    flipped_copy = nothing
    if s.flip && m !== nothing && h > 1
      flipped_copy = flipped(m[1], row_bytes(s, w, format, type), h, d)
      data = pointer(flipped_copy)
    end
    GC.@preserve flipped_copy begin
      if dims == 2 && sub
        ccall((:glTexSubImage2D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, i32(arg(c, a, 4)), i32(arg(c, a, 5)), w, h, format, type, data)
      elseif dims == 2
        ccall((:glTexImage2D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, internal, w, h, 0, format, type, data)
      elseif sub
        ccall((:glTexSubImage3D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, i32(arg(c, a, 4)), i32(arg(c, a, 5)), i32(arg(c, a, 6)), w, h, d, format, type, data)
      else
        ccall((:glTexImage3D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, internal, w, h, d, 0, format, type, data)
      end
    end
    sub || swizzle!(target, swizzle)
    nothing
  end
  raw("texImage2D", upload(2, false))
  raw("texSubImage2D", upload(2, true))
  raw("texImage3D", upload(3, false))
  raw("texSubImage3D", upload(3, true))
  # A picture, a canvas or a video as a texture: texImage2D(target, level, internal, format, type, element) and
  # texSubImage2D(target, level, x, y, format, type, element). Gives false when the element has no picture.
  picture_upload(sub) = (c, a) -> begin
    s = surface(c, a)
    target, level = u32(arg(c, a, 2)), i32(arg(c, a, 3))
    e = node(Int(arg(c, a, sub ? 8 : 7)))::Element
    got = picture(e)
    got === nothing && return false
    use(s)   # the picture of a canvas of WebGL can make another context current
    px = picture_pixels(got[1], s.multiply, s.flip)
    px === nothing && return false
    bytes, w, h = px
    if sub
      unpacked(() -> ccall((:glTexSubImage2D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, i32(arg(c, a, 4)), i32(arg(c, a, 5)), w, h, RGBA, UNSIGNED_BYTE, bytes), s)
    else
      internal, _, _, swizzle = formats(u32(arg(c, a, 4)), u32(arg(c, a, 5)), u32(arg(c, a, 6)))
      unpacked(() -> ccall((:glTexImage2D, GL), Cvoid, (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, Ptr{UInt8}), target, level, internal, w, h, 0, RGBA, UNSIGNED_BYTE, bytes), s)
      swizzle!(target, swizzle)
    end
    true
  end
  raw("texImageElement", picture_upload(false))
  raw("texSubImageElement", picture_upload(true))
  # How big the picture of an element is, for a script that asks before it uploads it
  raw("pictureSize", (c, a) -> begin
    got = picture(node(Int(arg(c, a, 1)))::Element)
    got === nothing ? nothing : Float64[Skia.sk_image_get_width(got[1]), Skia.sk_image_get_height(got[1])]
  end)
  out
end

"""
Give the scripts of the world `js` WebGL. Call it once, after context.jl has
given them a canvas. `node(number)` gives the element that a script holds as
that number, `picture(element)` gives Skia's picture of an <img>, a <canvas>
or a <video> with its width and height, or nothing, and `board(element)` gives
the surface of a <canvas>.
"""
start!(js::Context; node, picture, board) = begin
  words = split(CONSTANTS)
  evaluate(js, WEBGL; name="webgl.js")(natives(js; node, picture, board), [[String(words[i]), String(words[i+1])] for i in 1:2:length(words)-1])
  nothing
end

# Each constant of WebGL with its number in hexadecimal, from OpenGL's own header, with WebGL's own and those of
# OpenGL ES that OpenGL 4.1 lacks
const CONSTANTS = """
ACTIVE_ATTRIBUTES 8b89 ACTIVE_ATTRIBUTE_MAX_LENGTH 8b8a ACTIVE_PROGRAM 8259 ACTIVE_SUBROUTINES 8de5
ACTIVE_SUBROUTINE_MAX_LENGTH 8e48 ACTIVE_SUBROUTINE_UNIFORMS 8de6 ACTIVE_SUBROUTINE_UNIFORM_LOCATIONS 8e47
ACTIVE_SUBROUTINE_UNIFORM_MAX_LENGTH 8e49 ACTIVE_TEXTURE 84e0 ACTIVE_UNIFORMS 8b86 ACTIVE_UNIFORM_BLOCKS 8a36
ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH 8a35 ACTIVE_UNIFORM_MAX_LENGTH 8b87 ALIASED_LINE_WIDTH_RANGE 846e
ALL_SHADER_BITS ffffffff ALPHA 1906 ALREADY_SIGNALED 911a ALWAYS 207 AND 1501 AND_INVERTED 1504
AND_REVERSE 1502 ANY_SAMPLES_PASSED 8c2f ARRAY_BUFFER 8892 ARRAY_BUFFER_BINDING 8894 ATTACHED_SHADERS 8b85
BACK 405 BACK_LEFT 402 BACK_RIGHT 403 BGR 80e0 BGRA 80e1 BGRA_INTEGER 8d9b BGR_INTEGER 8d9a BLEND be2
BLEND_COLOR 8005 BLEND_DST be0 BLEND_DST_ALPHA 80ca BLEND_DST_RGB 80c8 BLEND_EQUATION 8009
BLEND_EQUATION_ALPHA 883d BLEND_EQUATION_RGB 8009 BLEND_SRC be1 BLEND_SRC_ALPHA 80cb BLEND_SRC_RGB 80c9
BLUE 1905 BLUE_INTEGER 8d96 BOOL 8b56 BOOL_VEC2 8b57 BOOL_VEC3 8b58 BOOL_VEC4 8b59 BROWSER_DEFAULT_WEBGL 9244
BUFFER_ACCESS 88bb BUFFER_ACCESS_FLAGS 911f BUFFER_MAPPED 88bc BUFFER_MAP_LENGTH 9120 BUFFER_MAP_OFFSET 9121
BUFFER_MAP_POINTER 88bd BUFFER_SIZE 8764 BUFFER_USAGE 8765 BYTE 1400 CCW 901 CLAMP_READ_COLOR 891c
CLAMP_TO_BORDER 812d CLAMP_TO_EDGE 812f CLEAR 1500 CLIP_DISTANCE0 3000 CLIP_DISTANCE1 3001 CLIP_DISTANCE2 3002
CLIP_DISTANCE3 3003 CLIP_DISTANCE4 3004 CLIP_DISTANCE5 3005 CLIP_DISTANCE6 3006 CLIP_DISTANCE7 3007 COLOR 1800
COLOR_ATTACHMENT0 8ce0 COLOR_ATTACHMENT1 8ce1 COLOR_ATTACHMENT10 8cea COLOR_ATTACHMENT11 8ceb
COLOR_ATTACHMENT12 8cec COLOR_ATTACHMENT13 8ced COLOR_ATTACHMENT14 8cee COLOR_ATTACHMENT15 8cef
COLOR_ATTACHMENT2 8ce2 COLOR_ATTACHMENT3 8ce3 COLOR_ATTACHMENT4 8ce4 COLOR_ATTACHMENT5 8ce5
COLOR_ATTACHMENT6 8ce6 COLOR_ATTACHMENT7 8ce7 COLOR_ATTACHMENT8 8ce8 COLOR_ATTACHMENT9 8ce9
COLOR_BUFFER_BIT 4000 COLOR_CLEAR_VALUE c22 COLOR_LOGIC_OP bf2 COLOR_WRITEMASK c23 COMPARE_REF_TO_TEXTURE 884e
COMPATIBLE_SUBROUTINES 8e4b COMPILE_STATUS 8b81 COMPRESSED_RED 8225 COMPRESSED_RED_RGTC1 8dbb
COMPRESSED_RG 8226 COMPRESSED_RGB 84ed COMPRESSED_RGBA 84ee COMPRESSED_RG_RGTC2 8dbd
COMPRESSED_SIGNED_RED_RGTC1 8dbc COMPRESSED_SIGNED_RG_RGTC2 8dbe COMPRESSED_SRGB 8c48
COMPRESSED_SRGB_ALPHA 8c49 COMPRESSED_TEXTURE_FORMATS 86a3 CONDITION_SATISFIED 911c CONSTANT_ALPHA 8003
CONSTANT_COLOR 8001 CONTEXT_COMPATIBILITY_PROFILE_BIT 2 CONTEXT_CORE_PROFILE_BIT 1 CONTEXT_FLAGS 821e
CONTEXT_FLAG_FORWARD_COMPATIBLE_BIT 1 CONTEXT_LOST_WEBGL 9242 CONTEXT_PROFILE_MASK 9126 COPY 1503
COPY_INVERTED 150c COPY_READ_BUFFER 8f36 COPY_WRITE_BUFFER 8f37 CULL_FACE b44 CULL_FACE_MODE b45
CURRENT_PROGRAM 8b8d CURRENT_QUERY 8865 CURRENT_VERTEX_ATTRIB 8626 CW 900 DECR 1e03 DECR_WRAP 8508
DELETE_STATUS 8b80 DEPTH 1801 DEPTH24_STENCIL8 88f0 DEPTH32F_STENCIL8 8cad DEPTH_ATTACHMENT 8d00
DEPTH_BUFFER_BIT 100 DEPTH_CLAMP 864f DEPTH_CLEAR_VALUE b73 DEPTH_COMPONENT 1902 DEPTH_COMPONENT16 81a5
DEPTH_COMPONENT24 81a6 DEPTH_COMPONENT32 81a7 DEPTH_COMPONENT32F 8cac DEPTH_FUNC b74 DEPTH_RANGE b70
DEPTH_STENCIL 84f9 DEPTH_STENCIL_ATTACHMENT 821a DEPTH_TEST b71 DEPTH_WRITEMASK b72 DITHER bd0 DONT_CARE 1100
DOUBLE 140a DOUBLEBUFFER c32 DOUBLE_MAT2 8f46 DOUBLE_MAT3 8f47 DOUBLE_MAT4 8f48 DOUBLE_VEC2 8ffc
DOUBLE_VEC3 8ffd DOUBLE_VEC4 8ffe DRAW_BUFFER c01 DRAW_BUFFER0 8825 DRAW_BUFFER1 8826 DRAW_BUFFER10 882f
DRAW_BUFFER11 8830 DRAW_BUFFER12 8831 DRAW_BUFFER13 8832 DRAW_BUFFER14 8833 DRAW_BUFFER15 8834
DRAW_BUFFER2 8827 DRAW_BUFFER3 8828 DRAW_BUFFER4 8829 DRAW_BUFFER5 882a DRAW_BUFFER6 882b DRAW_BUFFER7 882c
DRAW_BUFFER8 882d DRAW_BUFFER9 882e DRAW_FRAMEBUFFER 8ca9 DRAW_INDIRECT_BUFFER 8f3f
DRAW_INDIRECT_BUFFER_BINDING 8f43 DST_ALPHA 304 DST_COLOR 306 DYNAMIC_COPY 88ea DYNAMIC_DRAW 88e8
DYNAMIC_READ 88e9 ELEMENT_ARRAY_BUFFER 8893 ELEMENT_ARRAY_BUFFER_BINDING 8895 EQUAL 202 EQUIV 1509
EXTENSIONS 1f03 FALSE 0 FASTEST 1101 FILL 1b02 FIRST_VERTEX_CONVENTION 8e4d FIXED 140c FIXED_ONLY 891d
FLOAT 1406 FLOAT_32_UNSIGNED_INT_24_8_REV 8dad FLOAT_MAT2 8b5a FLOAT_MAT3 8b5b FLOAT_MAT4 8b5c FLOAT_VEC2 8b50
FLOAT_VEC3 8b51 FLOAT_VEC4 8b52 FRACTIONAL_EVEN 8e7c FRACTIONAL_ODD 8e7b
FRAGMENT_INTERPOLATION_OFFSET_BITS 8e5d FRAGMENT_SHADER 8b30 FRAGMENT_SHADER_BIT 2
FRAGMENT_SHADER_DERIVATIVE_HINT 8b8b FRAMEBUFFER 8d40 FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE 8215
FRAMEBUFFER_ATTACHMENT_BLUE_SIZE 8214 FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING 8210
FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE 8211 FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE 8216
FRAMEBUFFER_ATTACHMENT_GREEN_SIZE 8213 FRAMEBUFFER_ATTACHMENT_LAYERED 8da7
FRAMEBUFFER_ATTACHMENT_OBJECT_NAME 8cd1 FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE 8cd0
FRAMEBUFFER_ATTACHMENT_RED_SIZE 8212 FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE 8217
FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE 8cd3 FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER 8cd4
FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL 8cd2 FRAMEBUFFER_BINDING 8ca6 FRAMEBUFFER_COMPLETE 8cd5
FRAMEBUFFER_DEFAULT 8218 FRAMEBUFFER_INCOMPLETE_ATTACHMENT 8cd6 FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER 8cdb
FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS 8da8 FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT 8cd7
FRAMEBUFFER_INCOMPLETE_MULTISAMPLE 8d56 FRAMEBUFFER_INCOMPLETE_READ_BUFFER 8cdc FRAMEBUFFER_SRGB 8db9
FRAMEBUFFER_UNDEFINED 8219 FRAMEBUFFER_UNSUPPORTED 8cdd FRONT 404 FRONT_AND_BACK 408 FRONT_FACE b46
FRONT_LEFT 400 FRONT_RIGHT 401 FUNC_ADD 8006 FUNC_REVERSE_SUBTRACT 800b FUNC_SUBTRACT 800a
GEOMETRY_INPUT_TYPE 8917 GEOMETRY_OUTPUT_TYPE 8918 GEOMETRY_SHADER 8dd9 GEOMETRY_SHADER_BIT 4
GEOMETRY_SHADER_INVOCATIONS 887f GEOMETRY_VERTICES_OUT 8916 GEQUAL 206 GREATER 204 GREEN 1904
GREEN_INTEGER 8d95 HALF_FLOAT 140b HIGH_FLOAT 8df2 HIGH_INT 8df5 IMPLEMENTATION_COLOR_READ_FORMAT 8b9b
IMPLEMENTATION_COLOR_READ_TYPE 8b9a INCR 1e02 INCR_WRAP 8507 INFO_LOG_LENGTH 8b84 INT 1404
INTERLEAVED_ATTRIBS 8c8c INT_2_10_10_10_REV 8d9f INT_SAMPLER_1D 8dc9 INT_SAMPLER_1D_ARRAY 8dce
INT_SAMPLER_2D 8dca INT_SAMPLER_2D_ARRAY 8dcf INT_SAMPLER_2D_MULTISAMPLE 9109
INT_SAMPLER_2D_MULTISAMPLE_ARRAY 910c INT_SAMPLER_2D_RECT 8dcd INT_SAMPLER_3D 8dcb INT_SAMPLER_BUFFER 8dd0
INT_SAMPLER_CUBE 8dcc INT_SAMPLER_CUBE_MAP_ARRAY 900e INT_VEC2 8b53 INT_VEC3 8b54 INT_VEC4 8b55
INVALID_ENUM 500 INVALID_FRAMEBUFFER_OPERATION 506 INVALID_OPERATION 502 INVALID_VALUE 501 INVERT 150a
ISOLINES 8e7a KEEP 1e00 LAST_VERTEX_CONVENTION 8e4e LAYER_PROVOKING_VERTEX 825e LEFT 406 LEQUAL 203 LESS 201
LINE 1b01 LINEAR 2601 LINEAR_MIPMAP_LINEAR 2703 LINEAR_MIPMAP_NEAREST 2701 LINES 1 LINES_ADJACENCY a
LINE_LOOP 2 LINE_SMOOTH b20 LINE_SMOOTH_HINT c52 LINE_STRIP 3 LINE_STRIP_ADJACENCY b LINE_WIDTH b21
LINE_WIDTH_GRANULARITY b23 LINE_WIDTH_RANGE b22 LINK_STATUS 8b82 LOGIC_OP_MODE bf0 LOWER_LEFT 8ca1
LOW_FLOAT 8df0 LOW_INT 8df3 LUMINANCE 1909 LUMINANCE_ALPHA 190a MAJOR_VERSION 821b MAP_FLUSH_EXPLICIT_BIT 10
MAP_INVALIDATE_BUFFER_BIT 8 MAP_INVALIDATE_RANGE_BIT 4 MAP_READ_BIT 1 MAP_UNSYNCHRONIZED_BIT 20 MAP_WRITE_BIT 2
MAX 8008 MAX_3D_TEXTURE_SIZE 8073 MAX_ARRAY_TEXTURE_LAYERS 88ff MAX_CLIENT_WAIT_TIMEOUT_WEBGL 9247
MAX_CLIP_DISTANCES d32 MAX_COLOR_ATTACHMENTS 8cdf MAX_COLOR_TEXTURE_SAMPLES 910e
MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS 8a33 MAX_COMBINED_GEOMETRY_UNIFORM_COMPONENTS 8a32
MAX_COMBINED_TESS_CONTROL_UNIFORM_COMPONENTS 8e1e MAX_COMBINED_TESS_EVALUATION_UNIFORM_COMPONENTS 8e1f
MAX_COMBINED_TEXTURE_IMAGE_UNITS 8b4d MAX_COMBINED_UNIFORM_BLOCKS 8a2e
MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS 8a31 MAX_CUBE_MAP_TEXTURE_SIZE 851c MAX_DEPTH_TEXTURE_SAMPLES 910f
MAX_DRAW_BUFFERS 8824 MAX_DUAL_SOURCE_DRAW_BUFFERS 88fc MAX_ELEMENTS_INDICES 80e9 MAX_ELEMENTS_VERTICES 80e8
MAX_FRAGMENT_INPUT_COMPONENTS 9125 MAX_FRAGMENT_INTERPOLATION_OFFSET 8e5c MAX_FRAGMENT_UNIFORM_BLOCKS 8a2d
MAX_FRAGMENT_UNIFORM_COMPONENTS 8b49 MAX_FRAGMENT_UNIFORM_VECTORS 8dfd MAX_GEOMETRY_INPUT_COMPONENTS 9123
MAX_GEOMETRY_OUTPUT_COMPONENTS 9124 MAX_GEOMETRY_OUTPUT_VERTICES 8de0 MAX_GEOMETRY_SHADER_INVOCATIONS 8e5a
MAX_GEOMETRY_TEXTURE_IMAGE_UNITS 8c29 MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS 8de1
MAX_GEOMETRY_UNIFORM_BLOCKS 8a2c MAX_GEOMETRY_UNIFORM_COMPONENTS 8ddf MAX_INTEGER_SAMPLES 9110
MAX_PATCH_VERTICES 8e7d MAX_PROGRAM_TEXEL_OFFSET 8905 MAX_PROGRAM_TEXTURE_GATHER_OFFSET 8e5f
MAX_RECTANGLE_TEXTURE_SIZE 84f8 MAX_RENDERBUFFER_SIZE 84e8 MAX_SAMPLES 8d57 MAX_SAMPLE_MASK_WORDS 8e59
MAX_SERVER_WAIT_TIMEOUT 9111 MAX_SUBROUTINES 8de7 MAX_SUBROUTINE_UNIFORM_LOCATIONS 8de8
MAX_TESS_CONTROL_INPUT_COMPONENTS 886c MAX_TESS_CONTROL_OUTPUT_COMPONENTS 8e83
MAX_TESS_CONTROL_TEXTURE_IMAGE_UNITS 8e81 MAX_TESS_CONTROL_TOTAL_OUTPUT_COMPONENTS 8e85
MAX_TESS_CONTROL_UNIFORM_BLOCKS 8e89 MAX_TESS_CONTROL_UNIFORM_COMPONENTS 8e7f
MAX_TESS_EVALUATION_INPUT_COMPONENTS 886d MAX_TESS_EVALUATION_OUTPUT_COMPONENTS 8e86
MAX_TESS_EVALUATION_TEXTURE_IMAGE_UNITS 8e82 MAX_TESS_EVALUATION_UNIFORM_BLOCKS 8e8a
MAX_TESS_EVALUATION_UNIFORM_COMPONENTS 8e80 MAX_TESS_GEN_LEVEL 8e7e MAX_TESS_PATCH_COMPONENTS 8e84
MAX_TEXTURE_BUFFER_SIZE 8c2b MAX_TEXTURE_IMAGE_UNITS 8872 MAX_TEXTURE_LOD_BIAS 84fd MAX_TEXTURE_SIZE d33
MAX_TRANSFORM_FEEDBACK_BUFFERS 8e70 MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS 8c8a
MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS 8c8b MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS 8c80
MAX_UNIFORM_BLOCK_SIZE 8a30 MAX_UNIFORM_BUFFER_BINDINGS 8a2f MAX_VARYING_COMPONENTS 8b4b
MAX_VARYING_FLOATS 8b4b MAX_VARYING_VECTORS 8dfc MAX_VERTEX_ATTRIBS 8869 MAX_VERTEX_OUTPUT_COMPONENTS 9122
MAX_VERTEX_STREAMS 8e71 MAX_VERTEX_TEXTURE_IMAGE_UNITS 8b4c MAX_VERTEX_UNIFORM_BLOCKS 8a2b
MAX_VERTEX_UNIFORM_COMPONENTS 8b4a MAX_VERTEX_UNIFORM_VECTORS 8dfb MAX_VIEWPORTS 825b MAX_VIEWPORT_DIMS d3a
MEDIUM_FLOAT 8df1 MEDIUM_INT 8df4 MIN 8007 MINOR_VERSION 821c MIN_FRAGMENT_INTERPOLATION_OFFSET 8e5b
MIN_PROGRAM_TEXEL_OFFSET 8904 MIN_PROGRAM_TEXTURE_GATHER_OFFSET 8e5e MIN_SAMPLE_SHADING_VALUE 8c37
MIRRORED_REPEAT 8370 MULTISAMPLE 809d NAND 150e NEAREST 2600 NEAREST_MIPMAP_LINEAR 2702
NEAREST_MIPMAP_NEAREST 2700 NEVER 200 NICEST 1102 NONE 0 NOOP 1505 NOR 1508 NOTEQUAL 205 NO_ERROR 0
NUM_COMPATIBLE_SUBROUTINES 8e4a NUM_COMPRESSED_TEXTURE_FORMATS 86a2 NUM_EXTENSIONS 821d
NUM_PROGRAM_BINARY_FORMATS 87fe NUM_SHADER_BINARY_FORMATS 8df9 OBJECT_TYPE 9112 ONE 1
ONE_MINUS_CONSTANT_ALPHA 8004 ONE_MINUS_CONSTANT_COLOR 8002 ONE_MINUS_DST_ALPHA 305 ONE_MINUS_DST_COLOR 307
ONE_MINUS_SRC1_ALPHA 88fb ONE_MINUS_SRC1_COLOR 88fa ONE_MINUS_SRC_ALPHA 303 ONE_MINUS_SRC_COLOR 301 OR 1507
OR_INVERTED 150d OR_REVERSE 150b OUT_OF_MEMORY 505 PACK_ALIGNMENT d05 PACK_IMAGE_HEIGHT 806c PACK_LSB_FIRST d01
PACK_ROW_LENGTH d02 PACK_SKIP_IMAGES 806b PACK_SKIP_PIXELS d04 PACK_SKIP_ROWS d03 PACK_SWAP_BYTES d00 PATCHES e
PATCH_DEFAULT_INNER_LEVEL 8e73 PATCH_DEFAULT_OUTER_LEVEL 8e74 PATCH_VERTICES 8e72 PIXEL_PACK_BUFFER 88eb
PIXEL_PACK_BUFFER_BINDING 88ed PIXEL_UNPACK_BUFFER 88ec PIXEL_UNPACK_BUFFER_BINDING 88ef POINT 1b00 POINTS 0
POINT_FADE_THRESHOLD_SIZE 8128 POINT_SIZE b11 POINT_SIZE_GRANULARITY b13 POINT_SIZE_RANGE b12
POINT_SPRITE_COORD_ORIGIN 8ca0 POLYGON_MODE b40 POLYGON_OFFSET_FACTOR 8038 POLYGON_OFFSET_FILL 8037
POLYGON_OFFSET_LINE 2a02 POLYGON_OFFSET_POINT 2a01 POLYGON_OFFSET_UNITS 2a00 POLYGON_SMOOTH b41
POLYGON_SMOOTH_HINT c53 PRIMITIVES_GENERATED 8c87 PRIMITIVE_RESTART 8f9d PRIMITIVE_RESTART_INDEX 8f9e
PROGRAM_BINARY_FORMATS 87ff PROGRAM_BINARY_LENGTH 8741 PROGRAM_BINARY_RETRIEVABLE_HINT 8257
PROGRAM_PIPELINE_BINDING 825a PROGRAM_POINT_SIZE 8642 PROGRAM_SEPARABLE 8258 PROVOKING_VERTEX 8e4f
PROXY_TEXTURE_1D 8063 PROXY_TEXTURE_1D_ARRAY 8c19 PROXY_TEXTURE_2D 8064 PROXY_TEXTURE_2D_ARRAY 8c1b
PROXY_TEXTURE_2D_MULTISAMPLE 9101 PROXY_TEXTURE_2D_MULTISAMPLE_ARRAY 9103 PROXY_TEXTURE_3D 8070
PROXY_TEXTURE_CUBE_MAP 851b PROXY_TEXTURE_CUBE_MAP_ARRAY 900b PROXY_TEXTURE_RECTANGLE 84f7 QUADS 7
QUERY_BY_REGION_NO_WAIT 8e16 QUERY_BY_REGION_WAIT 8e15 QUERY_COUNTER_BITS 8864 QUERY_NO_WAIT 8e14
QUERY_RESULT 8866 QUERY_RESULT_AVAILABLE 8867 QUERY_WAIT 8e13 R11F_G11F_B10F 8c3a R16 822a R16F 822d R16I 8233
R16UI 8234 R16_SNORM 8f98 R32F 822e R32I 8235 R32UI 8236 R3_G3_B2 2a10 R8 8229 R8I 8231 R8UI 8232 R8_SNORM 8f94
RASTERIZER_DISCARD 8c89 READ_BUFFER c02 READ_FRAMEBUFFER 8ca8 READ_FRAMEBUFFER_BINDING 8caa READ_ONLY 88b8
READ_WRITE 88ba RED 1903 RED_INTEGER 8d94 RENDERBUFFER 8d41 RENDERBUFFER_ALPHA_SIZE 8d53
RENDERBUFFER_BINDING 8ca7 RENDERBUFFER_BLUE_SIZE 8d52 RENDERBUFFER_DEPTH_SIZE 8d54 RENDERBUFFER_GREEN_SIZE 8d51
RENDERBUFFER_HEIGHT 8d43 RENDERBUFFER_INTERNAL_FORMAT 8d44 RENDERBUFFER_RED_SIZE 8d50 RENDERBUFFER_SAMPLES 8cab
RENDERBUFFER_STENCIL_SIZE 8d55 RENDERBUFFER_WIDTH 8d42 RENDERER 1f01 REPEAT 2901 REPLACE 1e01 RG 8227 RG16 822c
RG16F 822f RG16I 8239 RG16UI 823a RG16_SNORM 8f99 RG32F 8230 RG32I 823b RG32UI 823c RG8 822b RG8I 8237
RG8UI 8238 RG8_SNORM 8f95 RGB 1907 RGB10 8052 RGB10_A2 8059 RGB10_A2UI 906f RGB12 8053 RGB16 8054 RGB16F 881b
RGB16I 8d89 RGB16UI 8d77 RGB16_SNORM 8f9a RGB32F 8815 RGB32I 8d83 RGB32UI 8d71 RGB4 804f RGB5 8050 RGB565 8d62
RGB5_A1 8057 RGB8 8051 RGB8I 8d8f RGB8UI 8d7d RGB8_SNORM 8f96 RGB9_E5 8c3d RGBA 1908 RGBA12 805a RGBA16 805b
RGBA16F 881a RGBA16I 8d88 RGBA16UI 8d76 RGBA16_SNORM 8f9b RGBA2 8055 RGBA32F 8814 RGBA32I 8d82 RGBA32UI 8d70
RGBA4 8056 RGBA8 8058 RGBA8I 8d8e RGBA8UI 8d7c RGBA8_SNORM 8f97 RGBA_INTEGER 8d99 RGB_INTEGER 8d98
RG_INTEGER 8228 RIGHT 407 SAMPLER_1D 8b5d SAMPLER_1D_ARRAY 8dc0 SAMPLER_1D_ARRAY_SHADOW 8dc3
SAMPLER_1D_SHADOW 8b61 SAMPLER_2D 8b5e SAMPLER_2D_ARRAY 8dc1 SAMPLER_2D_ARRAY_SHADOW 8dc4
SAMPLER_2D_MULTISAMPLE 9108 SAMPLER_2D_MULTISAMPLE_ARRAY 910b SAMPLER_2D_RECT 8b63 SAMPLER_2D_RECT_SHADOW 8b64
SAMPLER_2D_SHADOW 8b62 SAMPLER_3D 8b5f SAMPLER_BINDING 8919 SAMPLER_BUFFER 8dc2 SAMPLER_CUBE 8b60
SAMPLER_CUBE_MAP_ARRAY 900c SAMPLER_CUBE_MAP_ARRAY_SHADOW 900d SAMPLER_CUBE_SHADOW 8dc5 SAMPLES 80a9
SAMPLES_PASSED 8914 SAMPLE_ALPHA_TO_COVERAGE 809e SAMPLE_ALPHA_TO_ONE 809f SAMPLE_BUFFERS 80a8
SAMPLE_COVERAGE 80a0 SAMPLE_COVERAGE_INVERT 80ab SAMPLE_COVERAGE_VALUE 80aa SAMPLE_MASK 8e51
SAMPLE_MASK_VALUE 8e52 SAMPLE_POSITION 8e50 SAMPLE_SHADING 8c36 SCISSOR_BOX c10 SCISSOR_TEST c11
SEPARATE_ATTRIBS 8c8d SET 150f SHADER_BINARY_FORMATS 8df8 SHADER_COMPILER 8dfa SHADER_SOURCE_LENGTH 8b88
SHADER_TYPE 8b4f SHADING_LANGUAGE_VERSION 8b8c SHORT 1402 SIGNALED 9119 SIGNED_NORMALIZED 8f9c
SMOOTH_LINE_WIDTH_GRANULARITY b23 SMOOTH_LINE_WIDTH_RANGE b22 SMOOTH_POINT_SIZE_GRANULARITY b13
SMOOTH_POINT_SIZE_RANGE b12 SRC1_ALPHA 8589 SRC1_COLOR 88f9 SRC_ALPHA 302 SRC_ALPHA_SATURATE 308 SRC_COLOR 300
SRGB 8c40 SRGB8 8c41 SRGB8_ALPHA8 8c43 SRGB_ALPHA 8c42 STATIC_COPY 88e6 STATIC_DRAW 88e4 STATIC_READ 88e5
STENCIL 1802 STENCIL_ATTACHMENT 8d20 STENCIL_BACK_FAIL 8801 STENCIL_BACK_FUNC 8800
STENCIL_BACK_PASS_DEPTH_FAIL 8802 STENCIL_BACK_PASS_DEPTH_PASS 8803 STENCIL_BACK_REF 8ca3
STENCIL_BACK_VALUE_MASK 8ca4 STENCIL_BACK_WRITEMASK 8ca5 STENCIL_BUFFER_BIT 400 STENCIL_CLEAR_VALUE b91
STENCIL_FAIL b94 STENCIL_FUNC b92 STENCIL_INDEX 1901 STENCIL_INDEX1 8d46 STENCIL_INDEX16 8d49
STENCIL_INDEX4 8d47 STENCIL_INDEX8 8d48 STENCIL_PASS_DEPTH_FAIL b95 STENCIL_PASS_DEPTH_PASS b96 STENCIL_REF b97
STENCIL_TEST b90 STENCIL_VALUE_MASK b93 STENCIL_WRITEMASK b98 STEREO c33 STREAM_COPY 88e2 STREAM_DRAW 88e0
STREAM_READ 88e1 SUBPIXEL_BITS d50 SYNC_CONDITION 9113 SYNC_FENCE 9116 SYNC_FLAGS 9115
SYNC_FLUSH_COMMANDS_BIT 1 SYNC_GPU_COMMANDS_COMPLETE 9117 SYNC_STATUS 9114 TESS_CONTROL_OUTPUT_VERTICES 8e75
TESS_CONTROL_SHADER 8e88 TESS_CONTROL_SHADER_BIT 8 TESS_EVALUATION_SHADER 8e87 TESS_EVALUATION_SHADER_BIT 10
TESS_GEN_MODE 8e76 TESS_GEN_POINT_MODE 8e79 TESS_GEN_SPACING 8e77 TESS_GEN_VERTEX_ORDER 8e78 TEXTURE 1702
TEXTURE0 84c0 TEXTURE1 84c1 TEXTURE10 84ca TEXTURE11 84cb TEXTURE12 84cc TEXTURE13 84cd TEXTURE14 84ce
TEXTURE15 84cf TEXTURE16 84d0 TEXTURE17 84d1 TEXTURE18 84d2 TEXTURE19 84d3 TEXTURE2 84c2 TEXTURE20 84d4
TEXTURE21 84d5 TEXTURE22 84d6 TEXTURE23 84d7 TEXTURE24 84d8 TEXTURE25 84d9 TEXTURE26 84da TEXTURE27 84db
TEXTURE28 84dc TEXTURE29 84dd TEXTURE3 84c3 TEXTURE30 84de TEXTURE31 84df TEXTURE4 84c4 TEXTURE5 84c5
TEXTURE6 84c6 TEXTURE7 84c7 TEXTURE8 84c8 TEXTURE9 84c9 TEXTURE_1D de0 TEXTURE_1D_ARRAY 8c18 TEXTURE_2D de1
TEXTURE_2D_ARRAY 8c1a TEXTURE_2D_MULTISAMPLE 9100 TEXTURE_2D_MULTISAMPLE_ARRAY 9102 TEXTURE_3D 806f
TEXTURE_ALPHA_SIZE 805f TEXTURE_ALPHA_TYPE 8c13 TEXTURE_BASE_LEVEL 813c TEXTURE_BINDING_1D 8068
TEXTURE_BINDING_1D_ARRAY 8c1c TEXTURE_BINDING_2D 8069 TEXTURE_BINDING_2D_ARRAY 8c1d
TEXTURE_BINDING_2D_MULTISAMPLE 9104 TEXTURE_BINDING_2D_MULTISAMPLE_ARRAY 9105 TEXTURE_BINDING_3D 806a
TEXTURE_BINDING_BUFFER 8c2c TEXTURE_BINDING_CUBE_MAP 8514 TEXTURE_BINDING_CUBE_MAP_ARRAY 900a
TEXTURE_BINDING_RECTANGLE 84f6 TEXTURE_BLUE_SIZE 805e TEXTURE_BLUE_TYPE 8c12 TEXTURE_BORDER_COLOR 1004
TEXTURE_BUFFER 8c2a TEXTURE_BUFFER_DATA_STORE_BINDING 8c2d TEXTURE_COMPARE_FUNC 884d TEXTURE_COMPARE_MODE 884c
TEXTURE_COMPRESSED 86a1 TEXTURE_COMPRESSED_IMAGE_SIZE 86a0 TEXTURE_COMPRESSION_HINT 84ef TEXTURE_CUBE_MAP 8513
TEXTURE_CUBE_MAP_ARRAY 9009 TEXTURE_CUBE_MAP_NEGATIVE_X 8516 TEXTURE_CUBE_MAP_NEGATIVE_Y 8518
TEXTURE_CUBE_MAP_NEGATIVE_Z 851a TEXTURE_CUBE_MAP_POSITIVE_X 8515 TEXTURE_CUBE_MAP_POSITIVE_Y 8517
TEXTURE_CUBE_MAP_POSITIVE_Z 8519 TEXTURE_CUBE_MAP_SEAMLESS 884f TEXTURE_DEPTH 8071 TEXTURE_DEPTH_SIZE 884a
TEXTURE_DEPTH_TYPE 8c16 TEXTURE_FIXED_SAMPLE_LOCATIONS 9107 TEXTURE_GREEN_SIZE 805d TEXTURE_GREEN_TYPE 8c11
TEXTURE_HEIGHT 1001 TEXTURE_INTERNAL_FORMAT 1003 TEXTURE_LOD_BIAS 8501 TEXTURE_MAG_FILTER 2800
TEXTURE_MAX_LEVEL 813d TEXTURE_MAX_LOD 813b TEXTURE_MIN_FILTER 2801 TEXTURE_MIN_LOD 813a TEXTURE_RECTANGLE 84f5
TEXTURE_RED_SIZE 805c TEXTURE_RED_TYPE 8c10 TEXTURE_SAMPLES 9106 TEXTURE_SHARED_SIZE 8c3f
TEXTURE_STENCIL_SIZE 88f1 TEXTURE_SWIZZLE_A 8e45 TEXTURE_SWIZZLE_B 8e44 TEXTURE_SWIZZLE_G 8e43
TEXTURE_SWIZZLE_R 8e42 TEXTURE_SWIZZLE_RGBA 8e46 TEXTURE_WIDTH 1000 TEXTURE_WRAP_R 8072 TEXTURE_WRAP_S 2802
TEXTURE_WRAP_T 2803 TIMEOUT_EXPIRED 911b TIMESTAMP 8e28 TIME_ELAPSED 88bf TRANSFORM_FEEDBACK 8e22
TRANSFORM_FEEDBACK_BINDING 8e25 TRANSFORM_FEEDBACK_BUFFER 8c8e TRANSFORM_FEEDBACK_BUFFER_ACTIVE 8e24
TRANSFORM_FEEDBACK_BUFFER_BINDING 8c8f TRANSFORM_FEEDBACK_BUFFER_MODE 8c7f
TRANSFORM_FEEDBACK_BUFFER_PAUSED 8e23 TRANSFORM_FEEDBACK_BUFFER_SIZE 8c85 TRANSFORM_FEEDBACK_BUFFER_START 8c84
TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN 8c88 TRANSFORM_FEEDBACK_VARYINGS 8c83
TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH 8c76 TRIANGLES 4 TRIANGLES_ADJACENCY c TRIANGLE_FAN 6 TRIANGLE_STRIP 5
TRIANGLE_STRIP_ADJACENCY d TRUE 1 UNDEFINED_VERTEX 8260 UNIFORM_ARRAY_STRIDE 8a3c
UNIFORM_BLOCK_ACTIVE_UNIFORMS 8a42 UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES 8a43 UNIFORM_BLOCK_BINDING 8a3f
UNIFORM_BLOCK_DATA_SIZE 8a40 UNIFORM_BLOCK_INDEX 8a3a UNIFORM_BLOCK_NAME_LENGTH 8a41
UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER 8a46 UNIFORM_BLOCK_REFERENCED_BY_GEOMETRY_SHADER 8a45
UNIFORM_BLOCK_REFERENCED_BY_TESS_CONTROL_SHADER 84f0 UNIFORM_BLOCK_REFERENCED_BY_TESS_EVALUATION_SHADER 84f1
UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER 8a44 UNIFORM_BUFFER 8a11 UNIFORM_BUFFER_BINDING 8a28
UNIFORM_BUFFER_OFFSET_ALIGNMENT 8a34 UNIFORM_BUFFER_SIZE 8a2a UNIFORM_BUFFER_START 8a29
UNIFORM_IS_ROW_MAJOR 8a3e UNIFORM_MATRIX_STRIDE 8a3d UNIFORM_NAME_LENGTH 8a39 UNIFORM_OFFSET 8a3b
UNIFORM_SIZE 8a38 UNIFORM_TYPE 8a37 UNPACK_ALIGNMENT cf5 UNPACK_COLORSPACE_CONVERSION_WEBGL 9243
UNPACK_FLIP_Y_WEBGL 9240 UNPACK_IMAGE_HEIGHT 806e UNPACK_LSB_FIRST cf1 UNPACK_PREMULTIPLY_ALPHA_WEBGL 9241
UNPACK_ROW_LENGTH cf2 UNPACK_SKIP_IMAGES 806d UNPACK_SKIP_PIXELS cf4 UNPACK_SKIP_ROWS cf3 UNPACK_SWAP_BYTES cf0
UNSIGNALED 9118 UNSIGNED_BYTE 1401 UNSIGNED_BYTE_2_3_3_REV 8362 UNSIGNED_BYTE_3_3_2 8032 UNSIGNED_INT 1405
UNSIGNED_INT_10F_11F_11F_REV 8c3b UNSIGNED_INT_10_10_10_2 8036 UNSIGNED_INT_24_8 84fa
UNSIGNED_INT_2_10_10_10_REV 8368 UNSIGNED_INT_5_9_9_9_REV 8c3e UNSIGNED_INT_8_8_8_8 8035
UNSIGNED_INT_8_8_8_8_REV 8367 UNSIGNED_INT_SAMPLER_1D 8dd1 UNSIGNED_INT_SAMPLER_1D_ARRAY 8dd6
UNSIGNED_INT_SAMPLER_2D 8dd2 UNSIGNED_INT_SAMPLER_2D_ARRAY 8dd7 UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE 910a
UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY 910d UNSIGNED_INT_SAMPLER_2D_RECT 8dd5 UNSIGNED_INT_SAMPLER_3D 8dd3
UNSIGNED_INT_SAMPLER_BUFFER 8dd8 UNSIGNED_INT_SAMPLER_CUBE 8dd4 UNSIGNED_INT_SAMPLER_CUBE_MAP_ARRAY 900f
UNSIGNED_INT_VEC2 8dc6 UNSIGNED_INT_VEC3 8dc7 UNSIGNED_INT_VEC4 8dc8 UNSIGNED_NORMALIZED 8c17
UNSIGNED_SHORT 1403 UNSIGNED_SHORT_1_5_5_5_REV 8366 UNSIGNED_SHORT_4_4_4_4 8033 UNSIGNED_SHORT_4_4_4_4_REV 8365
UNSIGNED_SHORT_5_5_5_1 8034 UNSIGNED_SHORT_5_6_5 8363 UNSIGNED_SHORT_5_6_5_REV 8364 UPPER_LEFT 8ca2
VALIDATE_STATUS 8b83 VENDOR 1f00 VERSION 1f02 VERTEX_ARRAY_BINDING 85b5 VERTEX_ATTRIB_ARRAY_BUFFER_BINDING 889f
VERTEX_ATTRIB_ARRAY_DIVISOR 88fe VERTEX_ATTRIB_ARRAY_ENABLED 8622 VERTEX_ATTRIB_ARRAY_INTEGER 88fd
VERTEX_ATTRIB_ARRAY_NORMALIZED 886a VERTEX_ATTRIB_ARRAY_POINTER 8645 VERTEX_ATTRIB_ARRAY_SIZE 8623
VERTEX_ATTRIB_ARRAY_STRIDE 8624 VERTEX_ATTRIB_ARRAY_TYPE 8625 VERTEX_PROGRAM_POINT_SIZE 8642 VERTEX_SHADER 8b31
VERTEX_SHADER_BIT 1 VIEWPORT ba2 VIEWPORT_BOUNDS_RANGE 825d VIEWPORT_INDEX_PROVOKING_VERTEX 825f
VIEWPORT_SUBPIXEL_BITS 825c WAIT_FAILED 911d WRITE_ONLY 88b9 XOR 1506 ZERO 0
"""

const WEBGL = raw"""
(function (native, list) {
'use strict'
const global = globalThis
// window.jl keeps the number of an element's node under a symbol of its own
const ID = Object.getOwnPropertySymbols(document.documentElement).find(s => s.description === 'id')
const KEY = Symbol('key'), S = Symbol('surface'), NAME = Symbol('name'), CANVAS = Symbol('canvas'), ATTRS = Symbol('attributes'), BOUND = Symbol('bound')
const SOURCE = Symbol('source'), GONE = Symbol('deleted'), TWO = Symbol('webgl2'), EXTENSIONS = Symbol('extensions'), KIND = Symbol('kind')
const CONTEXT = Symbol.for('ladder.webgl.context'), RESIZE = Symbol.for('ladder.webgl.resize')
const C = {}
for (const [name, hex] of list) C[name] = parseInt(hex, 16)
C.INVALID_INDEX = 0xFFFFFFFF
C.TIMEOUT_IGNORED = -1
C.DRAW_FRAMEBUFFER_BINDING = C.FRAMEBUFFER_BINDING   // OpenGL's header names it by the other name

// --- the objects of a context -------------------------------------------------------------

class WebGLObject {
  constructor(key, name) {
    if (key !== KEY) throw new TypeError('Illegal constructor')
    this[NAME] = name
  }
}
const kinds = {}
for (const k of ['Buffer', 'Texture', 'Framebuffer', 'Renderbuffer', 'Program', 'Shader', 'VertexArrayObject', 'Query', 'Sampler', 'Sync', 'TransformFeedback'])
  kinds[k] = global['WebGL' + k] = ({['WebGL' + k]: class extends WebGLObject {}})['WebGL' + k]
class WebGLUniformLocation {
  constructor(key, at) { if (key !== KEY) throw new TypeError('Illegal constructor'); this[NAME] = at }
}
class WebGLActiveInfo {
  constructor(key, size, type, name) { if (key !== KEY) throw new TypeError('Illegal constructor'); this.size = size; this.type = type; this.name = name }
}
class WebGLShaderPrecisionFormat {
  constructor(key, min, max, precision) { if (key !== KEY) throw new TypeError('Illegal constructor'); this.rangeMin = min; this.rangeMax = max; this.precision = precision }
}
class WebGLContextEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.statusMessage = init.statusMessage || '' }
}
Object.assign(global, {WebGLUniformLocation, WebGLActiveInfo, WebGLShaderPrecisionFormat, WebGLContextEvent})

const name = o => o && !o[GONE] ? o[NAME] || 0 : 0

// `data` as a typed array of the kind `Kind`, from element `offset`, `length` elements long: what a uniform takes
const typed = (data, Kind, offset, length) => {
  let a = data instanceof Kind ? data : ArrayBuffer.isView(data) ? new Kind(data.buffer, data.byteOffset, Math.floor(data.byteLength / Kind.BYTES_PER_ELEMENT)) : Kind.from(data)
  if (offset || length) a = a.subarray(offset || 0, length ? (offset || 0) + length : undefined)
  return a
}
// The bytes of a typed array, a DataView or an ArrayBuffer, from element `offset`, `length` elements long
const view = (data, offset, length) => {
  if (data === null || data === undefined) return null
  if (data instanceof DataView) data = new Uint8Array(data.buffer, data.byteOffset, data.byteLength)
  if ((offset || length) && ArrayBuffer.isView(data)) data = data.subarray(offset || 0, length ? (offset || 0) + length : undefined)
  return data
}
// The number of the element whose picture `x` is, or undefined for pixels in a typed array or in ImageData
const picture = x => {
  if (!x || typeof x !== 'object' || ArrayBuffer.isView(x) || x instanceof ArrayBuffer) return undefined
  if (typeof ImageData === 'function' && x instanceof ImageData) return undefined
  const source = global[Symbol.for('ladder.source')]
  try { return source ? source(x) : x[ID] } catch (e) { return x[ID] }
}

// What each binding is of, for getParameter: the parameter that names it, by the target
const BUFFERS = {[C.ARRAY_BUFFER]: C.ARRAY_BUFFER_BINDING, [C.ELEMENT_ARRAY_BUFFER]: C.ELEMENT_ARRAY_BUFFER_BINDING, [C.UNIFORM_BUFFER]: C.UNIFORM_BUFFER_BINDING,
  [C.COPY_READ_BUFFER]: C.COPY_READ_BUFFER_BINDING, [C.COPY_WRITE_BUFFER]: C.COPY_WRITE_BUFFER_BINDING, [C.PIXEL_PACK_BUFFER]: C.PIXEL_PACK_BUFFER_BINDING,
  [C.PIXEL_UNPACK_BUFFER]: C.PIXEL_UNPACK_BUFFER_BINDING, [C.TRANSFORM_FEEDBACK_BUFFER]: C.TRANSFORM_FEEDBACK_BUFFER_BINDING}
const TEXTURES = {[C.TEXTURE_2D]: C.TEXTURE_BINDING_2D, [C.TEXTURE_CUBE_MAP]: C.TEXTURE_BINDING_CUBE_MAP, [C.TEXTURE_3D]: C.TEXTURE_BINDING_3D,
  [C.TEXTURE_2D_ARRAY]: C.TEXTURE_BINDING_2D_ARRAY}
const TEXTURE_BINDINGS = new Set(Object.values(TEXTURES))
const BINDINGS = new Set([...Object.values(BUFFERS), C.CURRENT_PROGRAM, C.DRAW_FRAMEBUFFER_BINDING, C.READ_FRAMEBUFFER_BINDING, C.RENDERBUFFER_BINDING,
  C.VERTEX_ARRAY_BINDING, C.TRANSFORM_FEEDBACK_BINDING])

const DEFAULTS = {alpha: true, depth: true, stencil: false, antialias: true, premultipliedAlpha: true, preserveDrawingBuffer: false,
  powerPreference: 'default', failIfMajorPerformanceCaveat: false, desynchronized: false, xrCompatible: false}

function start(gl, key, canvas, attrs, two) {
  if (key !== KEY) throw new TypeError('Illegal constructor')
  const a = {...DEFAULTS}
  if (attrs && typeof attrs === 'object') for (const k in DEFAULTS) if (attrs[k] !== undefined) a[k] = typeof DEFAULTS[k] === 'boolean' ? !!attrs[k] : attrs[k]
  gl[TWO] = two
  gl[CANVAS] = canvas
  gl[ATTRS] = a
  gl[S] = native.make(canvas[ID], a.alpha, a.depth, a.stencil, a.antialias, a.premultipliedAlpha)
  gl[BOUND] = new Map()
  gl[BOUND].unit = C.TEXTURE0
  gl.drawingBufferColorSpace = 'srgb'
  gl.unpackColorSpace = 'srgb'
}
class WebGL2RenderingContext { constructor(key, canvas, attrs) { start(this, key, canvas, attrs, true) } }
class WebGLRenderingContext { constructor(key, canvas, attrs) { start(this, key, canvas, attrs, false) } }
Object.assign(global, {WebGL2RenderingContext, WebGLRenderingContext})

// The methods of both kinds of context
const P = {
  get canvas() { return this[CANVAS] },
  get drawingBufferWidth() { return this[CANVAS].width },
  get drawingBufferHeight() { return this[CANVAS].height },
  [RESIZE]() { native.resize(this[S]) },
  getContextAttributes() { return {...this[ATTRS]} },
  isContextLost() { return false },
  makeXRCompatible() { return Promise.resolve() },
  getSupportedExtensions() { return supported(this[TWO]).slice() },
  getExtension(n) {
    n = String(n)
    const made = this[EXTENSIONS] || (this[EXTENSIONS] = {})
    return n in made ? made[n] : (made[n] = extension(this, n))
  },
  getParameter(p) {
    const two = this[TWO]
    switch (p) {
      case C.VERSION: return two ? 'WebGL 2.0 (OpenGL ES 3.0 Ladder)' : 'WebGL 1.0 (OpenGL ES 2.0 Ladder)'
      case C.SHADING_LANGUAGE_VERSION: return two ? 'WebGL GLSL ES 3.00 (OpenGL ES GLSL ES 3.0 Ladder)' : 'WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Ladder)'
      case C.VENDOR: return 'WebKit'
      case C.RENDERER: return 'WebKit WebGL'
      case 0x9245: return native.getParameter(this[S], C.VENDOR)
      case 0x9246: return native.getParameter(this[S], C.RENDERER)
      case C.ACTIVE_TEXTURE: return this[BOUND].unit
      case C.COMPRESSED_TEXTURE_FORMATS: return new Uint32Array(0)
    }
    if (TEXTURE_BINDINGS.has(p)) return this[BOUND].get(this[BOUND].unit + ':' + p) || null
    if (BINDINGS.has(p)) return this[BOUND].get(p) || null
    const v = native.getParameter(this[S], p)
    if (Array.isArray(v)) return v[0] === 'ints' ? new Int32Array(v.slice(1)) : v[0] === 'floats' ? new Float32Array(v.slice(1)) : v.slice(1)
    return v
  },
  getError() { return native.getError(this[S]) },
  isEnabled(cap) { return native.isEnabled(this[S], cap) },
  getShaderPrecisionFormat(shader, precision) {
    const v = native.getShaderPrecisionFormat(this[S], shader, precision)
    return new WebGLShaderPrecisionFormat(KEY, v[0], v[1], v[2])
  },
  getInternalformatParameter(target, format, p) { return p === C.SAMPLES ? new Int32Array([4]) : null },

  // Objects
  createBuffer() { return new kinds.Buffer(KEY, native.create(this[S], 'buffer')) },
  createTexture() { return new kinds.Texture(KEY, native.create(this[S], 'texture')) },
  createFramebuffer() { return new kinds.Framebuffer(KEY, native.create(this[S], 'framebuffer')) },
  createRenderbuffer() { return new kinds.Renderbuffer(KEY, native.create(this[S], 'renderbuffer')) },
  createVertexArray() { return new kinds.VertexArrayObject(KEY, native.create(this[S], 'vertexArray')) },
  createSampler() { return new kinds.Sampler(KEY, native.create(this[S], 'sampler')) },
  createProgram() { return new kinds.Program(KEY, native.create(this[S], 'program')) },
  createShader(type) { const s = new kinds.Shader(KEY, native.create(this[S], 'shader', type)); s[KIND] = type; return s },
  createQuery() { return new kinds.Query(KEY, 1) },
  createTransformFeedback() { return new kinds.TransformFeedback(KEY, 1) },
  deleteBuffer(o) { gone(this, o, 'buffer') },
  deleteTexture(o) { gone(this, o, 'texture') },
  deleteFramebuffer(o) { gone(this, o, 'framebuffer') },
  deleteRenderbuffer(o) { gone(this, o, 'renderbuffer') },
  deleteVertexArray(o) { gone(this, o, 'vertexArray') },
  deleteSampler(o) { gone(this, o, 'sampler') },
  deleteProgram(o) { gone(this, o, 'program') },
  deleteShader(o) { gone(this, o, 'shader') },
  deleteQuery(o) {},
  deleteTransformFeedback(o) {},
  isBuffer(o) { return o instanceof kinds.Buffer && !o[GONE] },
  isTexture(o) { return o instanceof kinds.Texture && !o[GONE] },
  isFramebuffer(o) { return o instanceof kinds.Framebuffer && !o[GONE] },
  isRenderbuffer(o) { return o instanceof kinds.Renderbuffer && !o[GONE] },
  isVertexArray(o) { return o instanceof kinds.VertexArrayObject && !o[GONE] },
  isSampler(o) { return o instanceof kinds.Sampler && !o[GONE] },
  isProgram(o) { return o instanceof kinds.Program && !o[GONE] },
  isShader(o) { return o instanceof kinds.Shader && !o[GONE] },
  isQuery(o) { return o instanceof kinds.Query },
  isSync(o) { return o instanceof kinds.Sync },
  isTransformFeedback(o) { return o instanceof kinds.TransformFeedback },

  // What's bound
  activeTexture(t) { this[BOUND].unit = t; native.activeTexture(this[S], t) },
  bindBuffer(target, b) { bind(this, BUFFERS[target], b); native.bindBuffer(this[S], target, name(b)) },
  bindBufferBase(target, i, b) { bind(this, BUFFERS[target], b); native.bindBufferBase(this[S], target, i, name(b)) },
  bindBufferRange(target, i, b, offset, size) { bind(this, BUFFERS[target], b); native.bindBufferRange(this[S], target, i, name(b), offset, size) },
  bindTexture(target, t) { this[BOUND].set(this[BOUND].unit + ':' + TEXTURES[target], t || null); native.bindTexture(this[S], target, name(t)) },
  bindFramebuffer(target, f) {
    if (target !== C.READ_FRAMEBUFFER) bind(this, C.DRAW_FRAMEBUFFER_BINDING, f)
    if (target !== C.DRAW_FRAMEBUFFER) bind(this, C.READ_FRAMEBUFFER_BINDING, f)
    native.bindFramebuffer(this[S], target, name(f))
  },
  bindRenderbuffer(target, r) { bind(this, C.RENDERBUFFER_BINDING, r); native.bindRenderbuffer(this[S], target, name(r)) },
  bindVertexArray(v) { bind(this, C.VERTEX_ARRAY_BINDING, v); native.bindVertexArray(this[S], name(v)) },
  bindSampler(unit, s) { native.bindSampler(this[S], unit, name(s)) },
  bindTransformFeedback(target, t) { bind(this, C.TRANSFORM_FEEDBACK_BINDING, t) },
  useProgram(p) { bind(this, C.CURRENT_PROGRAM, p); native.useProgram(this[S], name(p)) },

  // Shaders and programs
  shaderSource(s, code) { s[SOURCE] = String(code); native.shaderSource(this[S], name(s), String(code)) },
  getShaderSource(s) { return s && s[SOURCE] !== undefined ? s[SOURCE] : null },
  compileShader(s) { native.compileShader(this[S], name(s)) },
  attachShader(p, s) { native.attachShader(this[S], name(p), name(s)) },
  detachShader(p, s) { native.detachShader(this[S], name(p), name(s)) },
  linkProgram(p) { native.linkProgram(this[S], name(p)) },
  validateProgram(p) { native.validateProgram(this[S], name(p)) },
  getShaderParameter(s, p) { return p === C.SHADER_TYPE && s ? s[KIND] : native.getShaderParameter(this[S], name(s), p) },
  getProgramParameter(p, pname) { return native.getProgramParameter(this[S], name(p), pname) },
  getShaderInfoLog(s) { return native.getShaderInfoLog(this[S], name(s)) },
  getProgramInfoLog(p) { return native.getProgramInfoLog(this[S], name(p)) },
  getAttachedShaders(p) { return [] },
  bindAttribLocation(p, i, n) { native.bindAttribLocation(this[S], name(p), i, String(n)) },
  getAttribLocation(p, n) { return native.getAttribLocation(this[S], name(p), String(n)) },
  getUniformLocation(p, n) { const at = native.getUniformLocation(this[S], name(p), String(n)); return at < 0 ? null : new WebGLUniformLocation(KEY, at) },
  getActiveUniform(p, i) { const v = native.getActiveUniform(this[S], name(p), i); return v ? new WebGLActiveInfo(KEY, v[0], v[1], v[2]) : null },
  getActiveAttrib(p, i) { const v = native.getActiveAttrib(this[S], name(p), i); return v ? new WebGLActiveInfo(KEY, v[0], v[1], v[2]) : null },
  getUniformBlockIndex(p, n) { return native.getUniformBlockIndex(this[S], name(p), String(n)) },
  uniformBlockBinding(p, i, binding) { native.uniformBlockBinding(this[S], name(p), i, binding) },
  getActiveUniformBlockParameter(p, i, pname) { const v = native.getActiveUniformBlockParameter(this[S], name(p), i, pname); return Array.isArray(v) ? new Uint32Array(v) : v },
  getActiveUniformBlockName(p, i) { return null },
  getUniform(p, at) { return null },
  getVertexAttrib(i, p) { return null },
  getVertexAttribOffset(i, p) { return 0 },
  getTexParameter(target, p) { return null },
  getBufferParameter(target, p) { return null },
  getRenderbufferParameter(target, p) { return null },
  getFramebufferAttachmentParameter(target, attachment, p) { return null },
  getIndexedParameter(target, i) { return null },

  // Buffers
  bufferData(target, data, usage, offset, length) {
    typeof data === 'number' ? native.bufferSize(this[S], target, data, usage) : native.bufferData(this[S], target, view(data, offset, length), usage)
  },
  bufferSubData(target, at, data, offset, length) { native.bufferSubData(this[S], target, at, view(data, offset, length)) },
  getBufferSubData(target, at, into, offset, length) { native.getBufferSubData(this[S], target, at, view(into, offset, length)) },

  // Textures
  texImage2D(...a) {
    if (a.length === 6) return element(this, 'texImageElement', a[0], a[1], [a[2], a[3], a[4]], a[5])
    const [target, level, internal, w, h, border, format, type, data, offset] = a
    if (picture(data) !== undefined || isImageData(data)) return element(this, 'texImageElement', target, level, [internal, format, type], data)
    native.texImage2D(this[S], target, level, internal, w, h, border, format, type, typeof data === 'number' ? data : view(data, offset))
  },
  texSubImage2D(...a) {
    if (a.length === 7) return element(this, 'texSubImageElement', a[0], a[1], [a[2], a[3], a[4], a[5]], a[6])
    const [target, level, x, y, w, h, format, type, data, offset] = a
    if (picture(data) !== undefined || isImageData(data)) return element(this, 'texSubImageElement', target, level, [x, y, format, type], data)
    native.texSubImage2D(this[S], target, level, x, y, w, h, format, type, typeof data === 'number' ? data : view(data, offset))
  },
  texImage3D(target, level, internal, w, h, d, border, format, type, data, offset) {
    native.texImage3D(this[S], target, level, internal, w, h, d, border, format, type, typeof data === 'number' ? data : view(data, offset))
  },
  texSubImage3D(target, level, x, y, z, w, h, d, format, type, data, offset) {
    native.texSubImage3D(this[S], target, level, x, y, z, w, h, d, format, type, typeof data === 'number' ? data : view(data, offset))
  },
  compressedTexImage2D() {}, compressedTexSubImage2D() {}, compressedTexImage3D() {}, compressedTexSubImage3D() {},
  samplerParameteri(s, p, v) { native.samplerParameteri(this[S], name(s), p, v) },
  samplerParameterf(s, p, v) { native.samplerParameterf(this[S], name(s), p, v) },
  getSamplerParameter(s, p) { return null },

  // Framebuffers
  framebufferTexture2D(target, attachment, textarget, t, level) { native.framebufferTexture2D(this[S], target, attachment, textarget, name(t), level) },
  framebufferTextureLayer(target, attachment, t, level, layer) { native.framebufferTextureLayer(this[S], target, attachment, name(t), level, layer) },
  framebufferRenderbuffer(target, attachment, rtarget, r) { native.framebufferRenderbuffer(this[S], target, attachment, rtarget, name(r)) },
  readPixels(x, y, w, h, format, type, into, offset) { native.readPixels(this[S], x, y, w, h, format, type, typeof into === 'number' ? into : view(into, offset)) },
  drawBuffers(list) { native.drawBuffers(this[S], ...list) },
  invalidateFramebuffer() {}, invalidateSubFramebuffer() {},
  clearBufferfv(buffer, i, values, offset = 0) { native.clearBufferfv(this[S], buffer, i, ...Array.prototype.slice.call(values, offset, offset + 4)) },
  clearBufferiv(buffer, i, values, offset = 0) { native.clearBufferiv(this[S], buffer, i, ...Array.prototype.slice.call(values, offset, offset + 4)) },
  clearBufferuiv(buffer, i, values, offset = 0) { native.clearBufferuiv(this[S], buffer, i, ...Array.prototype.slice.call(values, offset, offset + 4)) },

  // Attributes with a value of their own
  vertexAttrib1fv(i, v) { this.vertexAttrib4f(i, v[0], 0, 0, 1) },
  vertexAttrib2fv(i, v) { this.vertexAttrib4f(i, v[0], v[1], 0, 1) },
  vertexAttrib3fv(i, v) { this.vertexAttrib4f(i, v[0], v[1], v[2], 1) },
  vertexAttrib4fv(i, v) { this.vertexAttrib4f(i, v[0], v[1], v[2], v[3]) },
  vertexAttribI4iv(i, v) { this.vertexAttribI4i(i, v[0], v[1], v[2], v[3]) },
  vertexAttribI4uiv(i, v) { this.vertexAttribI4ui(i, v[0], v[1], v[2], v[3]) },

  // Queries, syncs and transform feedback, which here are always done at once
  beginQuery() {}, endQuery() {}, getQuery() { return null },
  getQueryParameter(q, p) { return p === C.QUERY_RESULT_AVAILABLE ? true : 0 },
  fenceSync() { return new kinds.Sync(KEY, 1) },
  clientWaitSync() { return C.ALREADY_SIGNALED },
  waitSync() {},
  deleteSync() {},
  getSyncParameter(s, p) { return p === C.SYNC_STATUS ? C.SIGNALED : p === C.OBJECT_TYPE ? C.SYNC_FENCE : p === C.SYNC_CONDITION ? C.SYNC_GPU_COMMANDS_COMPLETE : 0 },
  beginTransformFeedback() {}, endTransformFeedback() {}, pauseTransformFeedback() {}, resumeTransformFeedback() {}, transformFeedbackVaryings() {},
  getTransformFeedbackVarying() { return null },
}
// The calls that only take numbers go straight to Julia
for (const m of `blendColor blendEquation blendEquationSeparate blendFunc blendFuncSeparate blitFramebuffer clear clearColor clearDepth clearStencil colorMask
    copyBufferSubData copyTexImage2D copyTexSubImage2D copyTexSubImage3D cullFace depthFunc depthMask depthRange disable disableVertexAttribArray drawArrays
    drawArraysInstanced drawElements drawElementsInstanced drawRangeElements enable enableVertexAttribArray finish flush frontFace generateMipmap hint
    lineWidth pixelStorei polygonOffset readBuffer renderbufferStorage renderbufferStorageMultisample sampleCoverage scissor stencilFunc
    stencilFuncSeparate stencilMask stencilMaskSeparate stencilOp stencilOpSeparate texParameteri texParameterf texStorage2D texStorage3D vertexAttrib1f
    vertexAttrib2f vertexAttrib3f vertexAttrib4f vertexAttribI4i vertexAttribI4ui vertexAttribDivisor vertexAttribPointer vertexAttribIPointer viewport
    checkFramebufferStatus clearBufferfi`.trim().split(/\s+/))
  P[m] = function (...a) { return native[m](this[S], ...a) }
// A uniform's location is an object, and a uniform with none is left alone
for (const m of 'uniform1f uniform2f uniform3f uniform4f uniform1i uniform2i uniform3i uniform4i uniform1ui uniform2ui uniform3ui uniform4ui'.split(' '))
  P[m] = function (at, ...a) { if (at) native[m](this[S], at[NAME], ...a) }
for (const [m, Kind] of [['f', Float32Array], ['i', Int32Array], ['ui', Uint32Array]])
  for (const n of [1, 2, 3, 4])
    P[`uniform${n}${m}v`] = function (at, data, offset, length) { if (at) native[`uniform${n}${m}v`](this[S], at[NAME], typed(data, Kind, offset, length)) }
for (const m of 'uniformMatrix2fv uniformMatrix3fv uniformMatrix4fv uniformMatrix2x3fv uniformMatrix3x2fv uniformMatrix2x4fv uniformMatrix4x2fv uniformMatrix3x4fv uniformMatrix4x3fv'.split(' '))
  P[m] = function (at, transpose, data, offset, length) { if (at) native[m](this[S], at[NAME], !!transpose, typed(data, Float32Array, offset, length)) }

for (const target of [WebGL2RenderingContext, WebGLRenderingContext]) {
  Object.defineProperties(target.prototype, Object.getOwnPropertyDescriptors(P))
  Object.assign(target.prototype, C)
  Object.assign(target, C)
}

function isImageData(x) { return typeof ImageData === 'function' && x instanceof ImageData }
function bind(gl, p, o) { if (p !== undefined) gl[BOUND].set(p, o || null) }
function gone(gl, o, kind) {
  if (!o || o[GONE]) return
  native.delete(gl[S], kind, o[NAME])
  o[GONE] = true
  for (const [k, v] of gl[BOUND]) if (v === o) gl[BOUND].set(k, null)
}
// Give the texture that's bound the picture of an element, or the pixels of ImageData: `rest` is what comes between the level and it
function element(gl, call, target, level, rest, from) {
  if (isImageData(from)) {
    const [a, b, c, d] = rest
    return call === 'texImageElement' ? native.texImage2D(gl[S], target, level, a, from.width, from.height, 0, b, c, from.data)
                                      : native.texSubImage2D(gl[S], target, level, a, b, from.width, from.height, c, d, from.data)
  }
  const id = picture(from)
  if (id === undefined) throw new TypeError('A texture is made from pixels, an <img>, a <canvas>, a <video>, an ImageBitmap or ImageData')
  native[call](gl[S], target, level, ...rest, id)
}

// --- extensions ---------------------------------------------------------------------------

const BOTH = ['EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'EXT_float_blend', 'EXT_texture_filter_anisotropic', 'OES_texture_float_linear',
  'WEBGL_debug_renderer_info', 'WEBGL_lose_context']
const ONE = ['ANGLE_instanced_arrays', 'EXT_blend_minmax', 'EXT_frag_depth', 'EXT_shader_texture_lod', 'OES_element_index_uint', 'OES_standard_derivatives',
  'OES_texture_float', 'OES_texture_half_float', 'OES_texture_half_float_linear', 'OES_vertex_array_object', 'WEBGL_depth_texture', 'WEBGL_draw_buffers']
const supported = two => two ? BOTH : [...BOTH, ...ONE]

function extension(gl, n) {
  const plain = n.replace(/^(WEBKIT_|MOZ_)/, '')
  if (!supported(gl[TWO]).includes(plain)) return null
  switch (plain) {
    case 'EXT_texture_filter_anisotropic': return {TEXTURE_MAX_ANISOTROPY_EXT: 0x84FE, MAX_TEXTURE_MAX_ANISOTROPY_EXT: 0x84FF}
    case 'WEBGL_debug_renderer_info': return {UNMASKED_VENDOR_WEBGL: 0x9245, UNMASKED_RENDERER_WEBGL: 0x9246}
    case 'WEBGL_lose_context': return {loseContext() {}, restoreContext() {}}
    case 'OES_vertex_array_object': return {VERTEX_ARRAY_BINDING_OES: C.VERTEX_ARRAY_BINDING, createVertexArrayOES: () => gl.createVertexArray(),
      deleteVertexArrayOES: v => gl.deleteVertexArray(v), isVertexArrayOES: v => gl.isVertexArray(v), bindVertexArrayOES: v => gl.bindVertexArray(v)}
    case 'ANGLE_instanced_arrays': return {VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE: 0x88FE, drawArraysInstancedANGLE: (...a) => gl.drawArraysInstanced(...a),
      drawElementsInstancedANGLE: (...a) => gl.drawElementsInstanced(...a), vertexAttribDivisorANGLE: (...a) => gl.vertexAttribDivisor(...a)}
    case 'OES_standard_derivatives': return {FRAGMENT_SHADER_DERIVATIVE_HINT_OES: 0x8B8B}
    case 'OES_texture_half_float': return {HALF_FLOAT_OES: 0x8D61}
    case 'WEBGL_depth_texture': return {UNSIGNED_INT_24_8_WEBGL: 0x84FA}
    case 'EXT_blend_minmax': return {MIN_EXT: 0x8007, MAX_EXT: 0x8008}
    case 'WEBGL_draw_buffers': {
      const ext = {drawBuffersWEBGL: list => gl.drawBuffers(list), MAX_COLOR_ATTACHMENTS_WEBGL: C.MAX_COLOR_ATTACHMENTS, MAX_DRAW_BUFFERS_WEBGL: C.MAX_DRAW_BUFFERS}
      for (let i = 0; i < 16; i++) { ext[`COLOR_ATTACHMENT${i}_WEBGL`] = C.COLOR_ATTACHMENT0 + i; ext[`DRAW_BUFFER${i}_WEBGL`] = C.DRAW_BUFFER0 + i }
      return ext
    }
    default: return {}
  }
}

// What canvas.getContext('webgl2'), 'webgl' and 'experimental-webgl' give: the canvas's one context, or null when it has another kind
global[Symbol.for('ladder.webgl')] = (canvas, kind, attrs) => {
  const two = kind === 'webgl2'
  const had = canvas[CONTEXT]
  if (had) return had[TWO] === two ? had : null
  const gl = two ? new WebGL2RenderingContext(KEY, canvas, attrs) : new WebGLRenderingContext(KEY, canvas, attrs)
  if (!gl[S]) return null
  canvas[CONTEXT] = gl
  return gl
}
})
"""

export start!, giveback!
