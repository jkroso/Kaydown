# Tests for WebGL: web/gl.jl, which gives a <canvas> of a page's scripts a
# context of WebGL 2 or WebGL 1 with OpenGL. Run them with
# `julia -O0 --project=. test/web_gl_test.jl`. They need the graphics card of
# this Mac, and no window.

@use Test: @test, @testset
@use "../web/live" => Live

js(l, code) = Live.evaluate(l, code)
lines(l, level=:error) = [text for (lv, text) in l.scripts.log if lv == level]
page(script; width=64, height=64) = Live.live("""<!DOCTYPE html><body style="margin:0"><canvas id=c width=$width height=$height></canvas>
  <script>
    const c = document.getElementById('c')
    // A pixel of the canvas as the page draws it: the canvas drawn on a canvas of 2D, read from the top left
    function seen(x, y) {
      const two = document.createElement('canvas'); two.width = c.width; two.height = c.height
      const g = two.getContext('2d'); g.drawImage(c, 0, 0)
      return Array.from(g.getImageData(x, y, 1, 1).data)
    }
    // A pixel of what WebGL drew, read with readPixels from the bottom left
    function read(gl, x, y) { const p = new Uint8Array(4); gl.readPixels(x, y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, p); return Array.from(p) }
    function program(gl, vs, fs) {
      const p = gl.createProgram()
      for (const [kind, code] of [[gl.VERTEX_SHADER, vs], [gl.FRAGMENT_SHADER, fs]]) {
        const s = gl.createShader(kind); gl.shaderSource(s, code); gl.compileShader(s)
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s))
        gl.attachShader(p, s)
      }
      gl.linkProgram(p)
      if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p))
      return p
    }
    $script
  </script>"""; wide=200)

const QUAD = """
  const VS = `#version 300 es
    in vec2 at; out vec2 uv;
    void main() { uv = at * 0.5 + 0.5; gl_Position = vec4(at, 0.0, 1.0); }`
  function quad(gl, p, x0 = -1, y0 = -1, x1 = 1, y1 = 1) {
    const b = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, b)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([x0, y0, x1, y0, x0, y1, x0, y1, x1, y0, x1, y1]), gl.STATIC_DRAW)
    const at = gl.getAttribLocation(p, 'at'); gl.enableVertexAttribArray(at); gl.vertexAttribPointer(at, 2, gl.FLOAT, false, 0, 0)
    gl.drawArrays(gl.TRIANGLES, 0, 6)
  }"""

@testset "a context of WebGL 2" begin
  l = page("""
    const gl = c.getContext('webgl2', {antialias: false})
    window.facts = [gl instanceof WebGL2RenderingContext, gl.getParameter(gl.VERSION), c.getContext('2d') === null, c.getContext('webgl2') === gl,
                    gl.drawingBufferWidth, gl.getParameter(gl.MAX_TEXTURE_SIZE) >= 4096, Array.from(gl.getParameter(gl.VIEWPORT)),
                    gl.getExtension('EXT_color_buffer_float') !== null, gl.getExtension('WEBGL_compressed_texture_s3tc'), gl.getError()]
    gl.clearColor(1, 0.5, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT)
    window.cleared = [read(gl, 0, 0), seen(0, 0)]""")
  @test lines(l) == []
  @test js(l, "facts") == Any[true, "WebGL 2.0 (OpenGL ES 3.0 Ladder)", true, true, 64, true, Any[0, 0, 64, 64], true, nothing, 0]
  @test js(l, "cleared") == Any[Any[255, 128, 0, 255], Any[255, 128, 0, 255]]
end

@testset "a shader draws, the right way up" begin
  l = page(QUAD * """
    const gl = c.getContext('webgl2', {antialias: false})
    const p = program(gl, VS, `#version 300 es
      precision highp float; uniform vec4 colour; out vec4 o;
      void main() { o = colour; }`)
    gl.useProgram(p)
    gl.uniform4fv(gl.getUniformLocation(p, 'colour'), [0, 0, 1, 1])
    quad(gl, p, -1, -1, 1, 0)   // the bottom half
    window.drawn = [read(gl, 10, 10), read(gl, 10, 50), seen(10, 54), seen(10, 10), gl.getError()]""")
  @test lines(l) == []
  # readPixels counts from the bottom, and the page from the top
  @test js(l, "drawn") == Any[Any[0, 0, 255, 255], Any[0, 0, 0, 0], Any[0, 0, 255, 255], Any[0, 0, 0, 0], 0]
end

@testset "textures from pixels and from a canvas" begin
  l = page(QUAD * """
    const gl = c.getContext('webgl2', {antialias: false})
    const p = program(gl, VS, `#version 300 es
      precision highp float; in vec2 uv; uniform sampler2D t; out vec4 o;
      void main() { o = texture(t, uv); }`)
    gl.useProgram(p)
    gl.uniform1i(gl.getUniformLocation(p, 't'), 0)
    const t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    // Two pixels across: green on the left, red on the right, made with texStorage2D, which OpenGL 4.1 lacks
    gl.texStorage2D(gl.TEXTURE_2D, 1, gl.RGBA8, 2, 1)
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 2, 1, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 255, 0, 255, 255, 0, 0, 255]))
    quad(gl, p)
    window.pixels = [read(gl, 5, 30), read(gl, 60, 30)]
    // A canvas of 2D, blue at its top and yellow at its bottom, flipped as three.js asks, so its top is at the top
    const two = document.createElement('canvas'); two.width = 4; two.height = 4
    const g = two.getContext('2d'); g.fillStyle = 'blue'; g.fillRect(0, 0, 4, 2); g.fillStyle = 'yellow'; g.fillRect(0, 2, 4, 2)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, two)
    quad(gl, p)
    window.canvas = [seen(30, 5), seen(30, 60), gl.getError()]""")
  @test lines(l) == []
  @test js(l, "pixels") == Any[Any[0, 255, 0, 255], Any[255, 0, 0, 255]]
  @test js(l, "canvas") == Any[Any[0, 0, 255, 255], Any[255, 255, 0, 255], 0]
end

@testset "a framebuffer of its own, and antialias" begin
  l = page(QUAD * """
    const gl = c.getContext('webgl2')
    window.samples = gl.getContextAttributes().antialias
    const p = program(gl, VS, `#version 300 es
      precision highp float; out vec4 o; void main() { o = vec4(1.0, 0.0, 1.0, 1.0); }`)
    gl.useProgram(p)
    const t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, 8, 8, 0, gl.RGBA, gl.UNSIGNED_BYTE, null)
    const f = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, f)
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, t, 0)
    window.complete = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE
    gl.viewport(0, 0, 8, 8); quad(gl, p)
    window.own = read(gl, 4, 4)
    // Back to the drawing buffer, which is null to the script, and has 4 samples
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    window.bound = gl.getParameter(gl.FRAMEBUFFER_BINDING)
    gl.viewport(0, 0, 64, 64); gl.clearColor(0, 0, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT); quad(gl, p, -1, -1, 0, 1)
    window.drawn = [read(gl, 10, 10), read(gl, 50, 10), seen(10, 10), gl.getError()]""")
  @test lines(l) == []
  @test js(l, "samples") == true
  @test js(l, "complete") == true
  @test js(l, "own") == Any[255, 0, 255, 255]
  @test js(l, "bound") === nothing
  @test js(l, "drawn") == Any[Any[255, 0, 255, 255], Any[0, 0, 0, 255], Any[255, 0, 255, 255], 0]
end

@testset "a context of WebGL 1, with its own shaders" begin
  l = page("""
    const gl = c.getContext('webgl', {antialias: false})
    const p = program(gl, `attribute vec2 at; varying vec2 uv; void main() { uv = at; gl_Position = vec4(at, 0.0, 1.0); }`,
                          `precision mediump float; varying vec2 uv; void main() { gl_FragColor = vec4(0.0, 1.0, 1.0, 1.0); }`)
    gl.useProgram(p)
    const vao = gl.getExtension('OES_vertex_array_object')
    const b = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, b)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW)
    gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
    gl.drawArrays(gl.TRIANGLES, 0, 3)
    window.facts = [gl instanceof WebGLRenderingContext, gl.getParameter(gl.VERSION), typeof vao.createVertexArrayOES, read(gl, 30, 30), gl.getError()]""")
  @test lines(l) == []
  @test js(l, "facts") == Any[true, "WebGL 1.0 (OpenGL ES 2.0 Ladder)", "function", Any[0, 255, 255, 255], 0]
end

@testset "a canvas changes size" begin
  l = page("""
    const gl = c.getContext('webgl2', {antialias: false})
    c.width = 100; c.height = 20
    gl.viewport(0, 0, 100, 20); gl.clearColor(0, 1, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT)
    window.facts = [gl.drawingBufferWidth, gl.drawingBufferHeight, read(gl, 99, 19), seen(99, 19)]""")
  @test lines(l) == []
  @test js(l, "facts") == Any[100, 20, Any[0, 255, 0, 255], Any[0, 255, 0, 255]]
end
