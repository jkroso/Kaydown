# Gives a page's scripts a <canvas> to draw on: `canvas.getContext('2d')`, with
# what goes with it: Path2D, ImageData, OffscreenCanvas, createImageBitmap,
# DOMMatrix, and `toDataURL` of the canvas.
#
#     start!(js; node, load, now, changed)    # once for each page, after window.jl has made `window` and `document`
#
# `node(number)` gives the element that a script holds as that number,
# `load(address)` gives the bytes of a picture or a video that the page names,
# and `now()` gives how many seconds ago the page was first shown.
#
# A script can start, stop and move a <video> too (`play()`, `pause()`,
# `currentTime`): video.jl keeps how far each has got. A video makes no sound.
#
# What `start!` gives back is for live.jl, which tells the scripts when an
# animation or a transition has ended (`animationend`, `transitionend`): the
# event then names what ended.
#
# The drawing itself is canvas.jl, in Julia: the context of a script is a thin
# object, and each of its functions calls one of the functions under "what a
# script can ask". So a script that draws ten thousand shapes makes ten
# thousand calls from JavaScript to Julia, which takes some ms.
#
# A script can draw a picture of the page (an <img>), another canvas and a
# <video> on a canvas. An <img> tells its scripts when its picture is read
# (`onload`) or can't be (`onerror`), since most scripts wait for that before
# they draw it. Here that's said a moment after the `src` is set.
#
# `getContext('webgl2')` and `getContext('webgl')` give WebGL: see gl.jl. A
# canvas has one kind of context, and asking for another gives null. See the
# top of canvas.jl for what a 2D context leaves out.

@use "./jsc" Context evaluate
@use "./dom" Element attr
@use "./canvas" Board Shape Gradient Pattern board clear! add! paint! clip! inside rect! write! measure lettering stamp! pixels pixels! address ink written
@use "./canvas" save! restore! matrix! turn! image! times BLENDS SAME
@use "./video" frame play spot play! pause! seek!
@use "./main" Pictures film
@use "./gl" => Webgl

const CONTEXT = raw"""
(function (native) {
'use strict'

// window.jl keeps the number of an element's node under a symbol of its own
const ID = Object.getOwnPropertySymbols(document.documentElement).find(s => s.description === 'id')
const STATE = Symbol('state'), STACK = Symbol('stack'), NODE = Symbol('node'), CANVAS = Symbol('canvas'), CTX = Symbol('context')
const STEPS = Symbol('steps'), STEP = Symbol('step'), SPEC = Symbol('spec'), VERSION = Symbol('version'), KEY = Symbol('key')
const global = globalThis

const fail = (message, name) => { throw new DOMException(message, name) }
const finite = (...numbers) => numbers.every(Number.isFinite)

// --- DOMMatrix: how a drawing is moved, turned and stretched ---------------------------------

class DOMMatrix {
  constructor(init) {
    const m = Array.isArray(init) && init.length === 6 ? init : [1, 0, 0, 1, 0, 0]
    ;[this.a, this.b, this.c, this.d, this.e, this.f] = m.map(Number)
  }
  get m11() { return this.a } get m12() { return this.b } get m21() { return this.c } get m22() { return this.d } get m41() { return this.e } get m42() { return this.f }
  get is2D() { return true }
  get isIdentity() { return this.a === 1 && this.b === 0 && this.c === 0 && this.d === 1 && this.e === 0 && this.f === 0 }
  multiply(o) {
    return new DOMMatrix([this.a * o.a + this.c * o.b, this.b * o.a + this.d * o.b, this.a * o.c + this.c * o.d, this.b * o.c + this.d * o.d,
                          this.a * o.e + this.c * o.f + this.e, this.b * o.e + this.d * o.f + this.f])
  }
  translate(x = 0, y = 0) { return this.multiply(new DOMMatrix([1, 0, 0, 1, x, y])) }
  scale(x = 1, y = x) { return this.multiply(new DOMMatrix([x, 0, 0, y, 0, 0])) }
  rotate(degrees = 0) { const r = degrees * Math.PI / 180; return this.multiply(new DOMMatrix([Math.cos(r), Math.sin(r), -Math.sin(r), Math.cos(r), 0, 0])) }
  inverse() {
    const det = this.a * this.d - this.b * this.c
    if (!det) return new DOMMatrix([NaN, NaN, NaN, NaN, NaN, NaN])
    return new DOMMatrix([this.d / det, -this.b / det, -this.c / det, this.a / det, (this.c * this.f - this.d * this.e) / det, (this.b * this.e - this.a * this.f) / det])
  }
  transformPoint(p = {}) { const x = p.x || 0, y = p.y || 0; return {x: this.a * x + this.c * y + this.e, y: this.b * x + this.d * y + this.f, z: 0, w: 1} }
  toString() { return `matrix(${this.a}, ${this.b}, ${this.c}, ${this.d}, ${this.e}, ${this.f})` }
}
const six = m => m && typeof m === 'object' ? [m.a ?? m.m11 ?? 1, m.b ?? m.m12 ?? 0, m.c ?? m.m21 ?? 0, m.d ?? m.m22 ?? 1, m.e ?? m.m41 ?? 0, m.f ?? m.m42 ?? 0].map(Number) : [1, 0, 0, 1, 0, 0]

// --- paths --------------------------------------------------------------------------------

// The corners of a rounded rectangle, as Julia takes them: a number, or how far across and how far down, for each
const corners = radii => (Array.isArray(radii) ? radii : [radii]).map(r => {
  const one = r && typeof r === 'object' ? [Number(r.x ?? 0), Number(r.y ?? 0)] : Number(r)
  if ([one].flat().some(n => n < 0)) throw new RangeError('The radius of a corner can\'t be less than nothing')
  return one
})

// What a context and a Path2D share. Each adds a step with its own STEP.
const path = {
  closePath() { this[STEP]('Z') },
  moveTo(x, y) { this[STEP]('M', +x, +y) },
  lineTo(x, y) { this[STEP]('L', +x, +y) },
  quadraticCurveTo(cx, cy, x, y) { this[STEP]('Q', +cx, +cy, +x, +y) },
  bezierCurveTo(ax, ay, bx, by, x, y) { this[STEP]('C', +ax, +ay, +bx, +by, +x, +y) },
  arcTo(x1, y1, x2, y2, r) {
    if (!finite(+x1, +y1, +x2, +y2, +r)) return
    if (r < 0) fail('The radius of an arc can\'t be less than nothing', 'IndexSizeError')
    this[STEP]('T', +x1, +y1, +x2, +y2, +r)
  },
  rect(x, y, w, h) { this[STEP]('R', +x, +y, +w, +h) },
  roundRect(x, y, w, h, radii = 0) { if (finite(+x, +y, +w, +h)) this[STEP]('U', +x, +y, +w, +h, corners(radii)) },
  arc(x, y, r, from, to, back = false) {
    if (!finite(+x, +y, +r, +from, +to)) return
    if (r < 0) fail('The radius of an arc can\'t be less than nothing', 'IndexSizeError')
    this[STEP]('A', +x, +y, +r, +from, +to, back ? 1 : 0)
  },
  ellipse(x, y, rx, ry, turned, from, to, back = false) {
    if (!finite(+x, +y, +rx, +ry, +turned, +from, +to)) return
    if (rx < 0 || ry < 0) fail('The radius of an oval can\'t be less than nothing', 'IndexSizeError')
    this[STEP]('E', +x, +y, +rx, +ry, +turned, +from, +to, back ? 1 : 0)
  },
}

class Path2D {
  constructor(from) {
    this[STEPS] = from instanceof Path2D ? from[STEPS].slice() : typeof from === 'string' ? [['S', from]] : []
  }
  [STEP](...step) { this[STEPS].push(step) }
  addPath(other, matrix) { if (other instanceof Path2D) this[STEPS].push(['P', other[STEPS].slice(), six(matrix)]) }
}
Object.defineProperties(Path2D.prototype, Object.getOwnPropertyDescriptors(path))

// --- what fills and strokes, when it isn't one colour -------------------------------------

class CanvasGradient {
  constructor(key, kind, at) {
    if (key !== KEY) throw new TypeError('Illegal constructor')
    this.kind = kind
    this.at = at
    this.stops = []
    this[VERSION] = 0
  }
  addColorStop(offset, color) {
    offset = Number(offset)
    if (!(offset >= 0 && offset <= 1)) fail('A stop of a gradient is from 0 to 1 of the way along', 'IndexSizeError')
    if (native.colour(String(color)) == null) fail(`'${color}' is not a colour`, 'SyntaxError')
    // The stops stay in their order along the gradient. Of two at one place, the one that was added first comes first.
    let i = this.stops.length
    while (i > 0 && this.stops[i - 1][0] > offset) i--
    this.stops.splice(i, 0, [offset, String(color)])
    this[VERSION]++
  }
  [SPEC]() { return [this.kind, ...this.at, ...this.stops.flat()] }
}

class CanvasPattern {
  constructor(key, source, again) {
    if (key !== KEY) throw new TypeError('Illegal constructor')
    this.source = source
    this.again = again
    this[VERSION] = 0
  }
  setTransform() {}
  [SPEC]() { return ['pattern', this.source, this.again] }
}

// --- pixels -------------------------------------------------------------------------------

class ImageData {
  constructor(a, b, c) {
    if (a instanceof Uint8ClampedArray) {
      this.width = b >>> 0
      this.height = c === undefined ? a.length / 4 / this.width : c >>> 0
      if (!this.width || a.length !== 4 * this.width * this.height) fail('The pixels don\'t fit the size', 'InvalidStateError')
      this.data = a
    } else {
      this.width = a >>> 0
      this.height = b >>> 0
      if (!this.width || !this.height) fail('A picture has at least one pixel across and one down', 'IndexSizeError')
      this.data = new Uint8ClampedArray(4 * this.width * this.height)
    }
    this.colorSpace = 'srgb'
  }
}

// Bytes cross to Julia and back as a string with one character for each byte
const fromBytes = bytes => {
  let text = ''
  for (let i = 0; i < bytes.length; i += 8192) text += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192))
  return text
}
const toBytes = text => {
  const bytes = new Uint8ClampedArray(text.length)
  for (let i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i)
  return bytes
}

// The number of the node whose picture a script wants drawn: an <img>, a <canvas>, a <video>, or a canvas that's in no page
const source = from => {
  const el = from && from[CANVAS] ? from[CANVAS] : from
  if (el instanceof HTMLImageElement || el instanceof HTMLCanvasElement || el instanceof HTMLVideoElement || (el instanceof SVGElement && el.localName === 'image')) return el[ID]
  throw new TypeError('A canvas draws an <img>, a <canvas>, a <video>, an ImageBitmap or an OffscreenCanvas')
}
// WebGL makes a texture of the same pictures
global[Symbol.for('ladder.source')] = source

// --- the context --------------------------------------------------------------------------

// What a new context has for each property that Julia keeps too
const STARTS = {
  fillStyle: '#000000', strokeStyle: '#000000', lineWidth: 1, lineCap: 'butt', lineJoin: 'miter', miterLimit: 10, lineDashOffset: 0, globalAlpha: 1,
  globalCompositeOperation: 'source-over', font: '10px sans-serif', textAlign: 'start', textBaseline: 'alphabetic', shadowColor: 'rgba(0, 0, 0, 0)',
  shadowBlur: 0, shadowOffsetX: 0, shadowOffsetY: 0, imageSmoothingEnabled: true,
}
// And for each that only the script keeps: nothing here draws differently for them
const KEPT = {direction: 'ltr', filter: 'none', imageSmoothingQuality: 'low', letterSpacing: '0px', wordSpacing: '0px', fontKerning: 'auto', fontStretch: 'normal',
              fontVariantCaps: 'normal', textRendering: 'auto'}
const fresh = () => ({...STARTS, ...KEPT, dash: [], raw: {}, versions: {}})

class CanvasRenderingContext2D {
  constructor(key, canvas) {
    if (key !== KEY) throw new TypeError('Illegal constructor')
    this[CANVAS] = canvas
    this[NODE] = canvas[ID]
    this[STATE] = fresh()
    this[STACK] = []
    native.make(this[NODE])
  }
  get canvas() { return this[CANVAS] }
  getContextAttributes() { return {alpha: true, colorSpace: 'srgb', desynchronized: false, willReadFrequently: false} }
  isContextLost() { return false }

  save() { const s = this[STATE]; this[STACK].push({...s, dash: s.dash.slice(), raw: {...s.raw}, versions: {...s.versions}}); native.save(this[NODE]) }
  restore() { if (this[STACK].length) { this[STATE] = this[STACK].pop(); native.restore(this[NODE]) } }
  reset() { this[STATE] = fresh(); this[STACK] = []; native.reset(this[NODE]) }

  scale(x, y) { if (finite(+x, +y)) native.turn(this[NODE], +x, 0, 0, +y, 0, 0) }
  rotate(r) { if (finite(+r)) native.turn(this[NODE], Math.cos(r), Math.sin(r), -Math.sin(r), Math.cos(r), 0, 0) }
  translate(x, y) { if (finite(+x, +y)) native.turn(this[NODE], 1, 0, 0, 1, +x, +y) }
  transform(a, b, c, d, e, f) { if (finite(+a, +b, +c, +d, +e, +f)) native.turn(this[NODE], +a, +b, +c, +d, +e, +f) }
  setTransform(a, b, c, d, e, f) {
    const m = arguments.length <= 1 ? six(a) : [+a, +b, +c, +d, +e, +f]
    if (finite(...m)) native.matrix(this[NODE], ...m)
  }
  resetTransform() { native.matrix(this[NODE], 1, 0, 0, 1, 0, 0) }
  getTransform() { return new DOMMatrix(native.moved(this[NODE])) }

  createLinearGradient(x0, y0, x1, y1) { return new CanvasGradient(KEY, 'linear', [+x0, +y0, +x1, +y1]) }
  createRadialGradient(x0, y0, r0, x1, y1, r1) {
    if (r0 < 0 || r1 < 0) fail('The radius of a gradient can\'t be less than nothing', 'IndexSizeError')
    return new CanvasGradient(KEY, 'radial', [+x0, +y0, +r0, +x1, +y1, +r1])
  }
  createConicGradient(angle, x, y) { return new CanvasGradient(KEY, 'conic', [+angle, +x, +y]) }
  createPattern(image, repetition) {
    const again = repetition == null || repetition === '' ? 'repeat' : String(repetition)
    if (!['repeat', 'repeat-x', 'repeat-y', 'no-repeat'].includes(again)) fail(`'${again}' is not a way to lay a pattern`, 'SyntaxError')
    const id = source(image)
    return native.size(id) == null ? null : new CanvasPattern(KEY, id, again)
  }

  clearRect(x, y, w, h) { native.rect(this[NODE], 'clear', +x, +y, +w, +h) }
  fillRect(x, y, w, h) { sync(this); native.rect(this[NODE], 'fill', +x, +y, +w, +h) }
  strokeRect(x, y, w, h) { sync(this); native.rect(this[NODE], 'stroke', +x, +y, +w, +h) }

  beginPath() { native.begin(this[NODE]) }
  [STEP](...step) { native.step(this[NODE], ...step) }
  fill(a, b) { sync(this); const shape = a instanceof Path2D; native.draw(this[NODE], 'fill', (shape ? b : a) ?? 'nonzero', shape ? a[STEPS] : null) }
  stroke(a) { sync(this); native.draw(this[NODE], 'stroke', 'nonzero', a instanceof Path2D ? a[STEPS] : null) }
  clip(a, b) { const shape = a instanceof Path2D; native.draw(this[NODE], 'clip', (shape ? b : a) ?? 'nonzero', shape ? a[STEPS] : null) }
  isPointInPath(a, b, c, d) {
    const shape = a instanceof Path2D
    const [x, y, rule] = shape ? [b, c, d] : [a, b, c]
    return finite(+x, +y) && native.hit(this[NODE], shape ? a[STEPS] : null, +x, +y, rule ?? 'nonzero')
  }
  isPointInStroke() { return false }
  drawFocusIfNeeded() {}

  fillText(text, x, y, most) { sync(this); if (most === undefined || finite(+most)) native.text(this[NODE], 'fill', String(text), +x, +y, most === undefined ? null : +most) }
  strokeText(text, x, y, most) { sync(this); if (most === undefined || finite(+most)) native.text(this[NODE], 'stroke', String(text), +x, +y, most === undefined ? null : +most) }
  measureText(text) {
    const [width, ascent, descent] = native.measure(this[NODE], String(text))
    return {width, actualBoundingBoxLeft: 0, actualBoundingBoxRight: width, actualBoundingBoxAscent: ascent, actualBoundingBoxDescent: descent,
            fontBoundingBoxAscent: ascent, fontBoundingBoxDescent: descent, emHeightAscent: ascent, emHeightDescent: descent,
            hangingBaseline: 0.8 * ascent, alphabeticBaseline: 0, ideographicBaseline: -descent}
  }

  drawImage(image, ...at) {
    const id = source(image)
    const size = native.size(id)
    if (size == null) return   // a picture that isn't read yet draws nothing
    const [w, h] = size
    const n = at.map(Number)
    const all = n.length === 2 ? [0, 0, w, h, n[0], n[1], w, h] : n.length === 4 ? [0, 0, w, h, ...n] : n.length === 8 ? n : null
    if (!all) throw new TypeError('drawImage takes a picture and 2, 4 or 8 numbers')
    native.image(this[NODE], id, ...all)
  }

  createImageData(a, b) { return a instanceof ImageData ? new ImageData(a.width, a.height) : new ImageData(Math.abs(a), Math.abs(b)) }
  getImageData(x, y, w, h) {
    if (!w || !h) fail('A picture has at least one pixel across and one down', 'IndexSizeError')
    if (w < 0) { x += w; w = -w }
    if (h < 0) { y += h; h = -h }
    return new ImageData(toBytes(native.pixels(this[NODE], Math.trunc(x), Math.trunc(y), Math.trunc(w), Math.trunc(h))), Math.trunc(w), Math.trunc(h))
  }
  putImageData(image, x, y, cutX, cutY, cutW, cutH) {
    if (!(image instanceof ImageData)) throw new TypeError('putImageData takes an ImageData')
    x = Math.trunc(x); y = Math.trunc(y)
    if (cutX === undefined) return native.setPixels(this[NODE], fromBytes(image.data), x, y, image.width, image.height)
    // Only a part of the picture: its rows are copied out
    const left = Math.max(0, Math.trunc(cutX)), top = Math.max(0, Math.trunc(cutY))
    const w = Math.min(image.width, Math.trunc(cutX + cutW)) - left, h = Math.min(image.height, Math.trunc(cutY + cutH)) - top
    if (w <= 0 || h <= 0) return
    const part = new Uint8ClampedArray(4 * w * h)
    for (let row = 0; row < h; row++) part.set(image.data.subarray(4 * ((top + row) * image.width + left), 4 * ((top + row) * image.width + left + w)), 4 * row * w)
    native.setPixels(this[NODE], fromBytes(part), x + left, y + top, w, h)
  }

  setLineDash(list) {
    const dash = Array.from(list, Number)
    if (!dash.every(n => Number.isFinite(n) && n >= 0)) return
    this[STATE].dash = dash.length % 2 ? dash.concat(dash) : dash
    native.set(this[NODE], 'lineDash', this[STATE].dash)
  }
  getLineDash() { return this[STATE].dash.slice() }
}
Object.defineProperties(CanvasRenderingContext2D.prototype, Object.getOwnPropertyDescriptors(path))

// A gradient that got another colour since it was made the fill or the stroke is sent again before anything is drawn
function sync(ctx) {
  const s = ctx[STATE]
  for (const name of ['fillStyle', 'strokeStyle']) {
    const v = s[name]
    if (typeof v === 'object' && v[VERSION] !== s.versions[name]) {
      native.set(ctx[NODE], name, v[SPEC]())
      s.versions[name] = v[VERSION]
    }
  }
}

for (const name of Object.keys(STARTS)) {
  Object.defineProperty(CanvasRenderingContext2D.prototype, name, {
    configurable: true, enumerable: true,
    get() { return this[STATE][name] },
    set(v) {
      const s = this[STATE]
      if (v === s.raw[name]) return
      if (v instanceof CanvasGradient || v instanceof CanvasPattern) {
        native.set(this[NODE], name, v[SPEC]())
        s[name] = s.raw[name] = v
        s.versions[name] = v[VERSION]
        return
      }
      // Julia says how the value is written once it's taken, or null for one that the property can't take: then nothing changes
      const got = native.set(this[NODE], name, typeof v === 'number' || typeof v === 'boolean' ? v : String(v))
      if (got == null) return
      s[name] = got
      s.raw[name] = v
    },
  })
}
for (const name of Object.keys(KEPT)) {
  Object.defineProperty(CanvasRenderingContext2D.prototype, name, {
    configurable: true, enumerable: true,
    get() { return this[STATE][name] },
    set(v) { this[STATE][name] = String(v) },
  })
}

// --- the <canvas> element -----------------------------------------------------------------

const side = (name, start) => ({
  configurable: true, enumerable: true,
  get() { const n = parseInt(this.getAttribute(name), 10); return n >= 0 ? n : start },
  // A canvas whose size is set starts again with nothing drawn, even when the size is the one that it had
  set(v) {
    this.setAttribute(name, String(Math.max(0, Math.trunc(Number(v)) || 0)))
    if (this[CTX]) { this[CTX][STATE] = fresh(); this[CTX][STACK] = [] }
    native.resize(this[ID])
    const gl = this[Symbol.for('ladder.webgl.context')]
    if (gl) gl[Symbol.for('ladder.webgl.resize')]()
  },
})
Object.defineProperties(HTMLCanvasElement.prototype, {
  width: side('width', 300),
  height: side('height', 150),
  getContext: {configurable: true, writable: true, value: function getContext(kind, attrs) {
    const gl = this[Symbol.for('ladder.webgl.context')]
    if (kind === '2d') return gl ? null : this[CTX] || (this[CTX] = new CanvasRenderingContext2D(KEY, this))
    if (kind !== 'webgl2' && kind !== 'webgl' && kind !== 'experimental-webgl') return null
    const make = global[Symbol.for('ladder.webgl')]
    return this[CTX] || !make ? null : make(this, kind, attrs)
  }},
  toDataURL: {configurable: true, writable: true, value: function toDataURL(kind, quality) { return native.url(this[ID], String(kind ?? 'image/png'), quality ?? null) }},
  toBlob: {configurable: true, writable: true, value: function toBlob(done, kind, quality) {
    const url = this.toDataURL(kind, quality)
    setTimeout(() => {
      if (typeof global.Blob !== 'function') return done(null)
      const text = atob(url.slice(url.indexOf(',') + 1))
      done(new global.Blob([Uint8Array.from(text, c => c.charCodeAt(0))], {type: url.slice(5, url.indexOf(';'))}))
    }, 0)
  }},
})

// A canvas that's in no page
class OffscreenCanvas {
  constructor(width, height) {
    this[CANVAS] = document.createElement('canvas')
    this.width = width
    this.height = height
  }
  get width() { return this[CANVAS].width } set width(v) { this[CANVAS].width = v }
  get height() { return this[CANVAS].height } set height(v) { this[CANVAS].height = v }
  getContext(kind) { return this[CANVAS].getContext(kind) }
  transferToImageBitmap() { const copy = bitmap(this[CANVAS]); this[CANVAS].width = this.width; return copy }
}

// A picture that's ready to draw: here it's a canvas that the picture was drawn on
class ImageBitmap {
  constructor(key, canvas) {
    if (key !== KEY) throw new TypeError('Illegal constructor')
    this[CANVAS] = canvas
  }
  get width() { return this[CANVAS].width }
  get height() { return this[CANVAS].height }
  close() { this[CANVAS].width = 0 }
}
function bitmap(from, x, y, w, h) {
  const id = source(from)
  const size = native.size(id)
  if (size == null) fail('The picture can\'t be read', 'InvalidStateError')
  if (x === undefined) [x, y, w, h] = [0, 0, size[0], size[1]]
  const canvas = document.createElement('canvas')
  canvas.width = Math.abs(w)
  canvas.height = Math.abs(h)
  canvas.getContext('2d').drawImage(from, x, y, w, h, 0, 0, Math.abs(w), Math.abs(h))
  return new ImageBitmap(KEY, canvas)
}
function createImageBitmap(from, x, y, w, h) {
  return new Promise((ok, no) => {
    try {
      if (from instanceof ImageData) {
        const canvas = document.createElement('canvas')
        canvas.width = from.width
        canvas.height = from.height
        canvas.getContext('2d').putImageData(from, 0, 0)
        return ok(new ImageBitmap(KEY, canvas))
      }
      ok(typeof x === 'number' ? bitmap(from, x, y, w, h) : bitmap(from))
    } catch (e) { no(e) }
  })
}

// --- pictures that a script waits for -----------------------------------------------------

// An <img> says when its picture is read, a moment after its `src` is set, and how big the picture itself is
const said = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src')
if (said && said.set) {
  Object.defineProperty(HTMLImageElement.prototype, 'src', {...said, set(v) {
    said.set.call(this, v)
    setTimeout(() => this.dispatchEvent(new Event(native.size(this[ID]) == null ? 'error' : 'load')), 0)
  }})
}
Object.defineProperties(HTMLImageElement.prototype, {
  naturalWidth: {configurable: true, get() { return (native.size(this[ID]) || [0, 0])[0] }},
  naturalHeight: {configurable: true, get() { return (native.size(this[ID]) || [0, 0])[1] }},
  complete: {configurable: true, get() { return !this.getAttribute('src') || native.size(this[ID]) != null }},
})
// A <video> that a script starts, stops and moves. It shows its pictures and makes no sound.
const flag = name => ({configurable: true, enumerable: true, get() { return this.hasAttribute(name) }, set(v) { v ? this.setAttribute(name, '') : this.removeAttribute(name) }})
Object.defineProperties(HTMLVideoElement.prototype, {
  videoWidth: {configurable: true, get() { return (native.size(this[ID]) || [0, 0])[0] }},
  videoHeight: {configurable: true, get() { return (native.size(this[ID]) || [0, 0])[1] }},
  autoplay: flag('autoplay'), loop: flag('loop'), controls: flag('controls'), muted: flag('muted'), playsInline: flag('playsinline'),
  currentTime: {configurable: true, get() { return native.media(this[ID])[0] }, set(v) { if (Number.isFinite(+v)) native.seek(this[ID], +v) }},
  paused: {configurable: true, get() { return !native.media(this[ID])[1] }},
  duration: {configurable: true, get() { return native.media(this[ID])[2] ?? NaN }},
  ended: {configurable: true, get() { const [t, going, long] = native.media(this[ID]); return !going && long != null && t >= long }},
  readyState: {configurable: true, get() { return native.media(this[ID])[2] == null ? 0 : 4 }},
  src: {configurable: true, enumerable: true, get() { const v = this.getAttribute('src'); return v == null ? '' : new URL(v, document.baseURI).href },
        set(v) { this.setAttribute('src', String(v)) }},
  poster: {configurable: true, enumerable: true, get() { return this.getAttribute('poster') ?? '' }, set(v) { this.setAttribute('poster', String(v)) }},
  volume: {configurable: true, writable: true, value: 1},
  playbackRate: {configurable: true, writable: true, value: 1},
  play: {configurable: true, writable: true, value: function play() {
    if (native.media(this[ID])[2] == null) return Promise.reject(new DOMException('The video can\'t be read', 'NotSupportedError'))
    native.play(this[ID])
    this.dispatchEvent(new Event('play'))
    this.dispatchEvent(new Event('playing'))
    return Promise.resolve()
  }},
  pause: {configurable: true, writable: true, value: function pause() { if (!this.paused) { native.pause(this[ID]); this.dispatchEvent(new Event('pause')) } }},
  load: {configurable: true, writable: true, value: function load() {}},
  canPlayType: {configurable: true, writable: true, value: function canPlayType(kind) { return /mp4|quicktime|m4v/i.test(String(kind)) ? 'maybe' : '' }},
})

// --- what ended ---------------------------------------------------------------------------

// An animation or a change that takes time has ended: the event that says so names it, and says how long it took
class AnimationEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.animationName = String(init.animationName ?? ''); this.elapsedTime = Number(init.elapsedTime ?? 0); this.pseudoElement = '' }
}
class TransitionEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.propertyName = String(init.propertyName ?? ''); this.elapsedTime = Number(init.elapsedTime ?? 0); this.pseudoElement = '' }
}
// Julia tells an event through window.jl, which makes a plain Event. What Julia says of it just before is put on the
// event here, by a listener that hears it before any of the page's own.
let ending = null
for (const type of ['animationend', 'transitionend']) {
  global.addEventListener(type, event => {
    if (!ending || ending.type !== event.type || 'elapsedTime' in event) return
    event[type === 'animationend' ? 'animationName' : 'propertyName'] = ending.name
    event.elapsedTime = ending.elapsed
    event.pseudoElement = ''
    ending = null
  }, true)
}

Object.assign(global, {CanvasRenderingContext2D, CanvasGradient, CanvasPattern, Path2D, ImageData, ImageBitmap, OffscreenCanvas, createImageBitmap, AnimationEvent, TransitionEvent})
if (typeof global.DOMMatrix !== 'function') global.DOMMatrix = global.DOMMatrixReadOnly = DOMMatrix

// What Julia calls just before it tells the page that an animation or a change has ended
return (type, name, elapsed) => { ending = {type, name, elapsed} }
})
"""

"Add the steps `steps` of a script's Path2D to the path `s`, where the context is moved by `m`"
trace!(s::Shape, m, steps) = begin
  for step in steps
    # A path that was added to this one, with a move of its own
    step[1] == "P" ? trace!(s, times(m, Tuple(Float64.(step[3]))), step[2]) : add!(s, m, String(step[1]), step[2:end])
  end
  s
end

"What a script made the fill or the stroke, when it isn't a colour: a `Gradient` or a `Pattern`, or nothing"
style(spec::AbstractVector, node) = begin
  kind = spec[1]
  if kind == "pattern"
    again = String(spec[3])
    return Pattern(node(spec[2]), again in ("repeat", "repeat-x"), again in ("repeat", "repeat-y"))
  end
  n = kind == "linear" ? 4 : kind == "radial" ? 6 : 3
  at = Float64.(spec[2:n+1])
  all(isfinite, at) || return nothing
  stops = Tuple{Float64,UInt32}[(Float64(spec[i]), something(ink(String(spec[i+1])), 0x00000000)) for i in n+2:2:length(spec)-1]
  Gradient(Symbol(kind), Tuple(vcat(at, zeros(6 - n))), stops)
end

const ALIGNS = ("start", "end", "left", "right", "center")
const BASES = ("alphabetic", "top", "hanging", "middle", "ideographic", "bottom")

"""
Set the property `name` of the context of `b` to `v`. Gives the value as the
context gives it back, or nothing for a value that the property can't take,
which changes nothing.
"""
set!(b::Board, name::AbstractString, v, node) = begin
  s = b.state
  number(ok) = v isa Real && isfinite(v) && ok(v) ? Float64(v) : nothing
  if name in ("fillStyle", "strokeStyle")
    with = v isa AbstractString ? ink(v) : v isa AbstractVector ? style(v, node) : nothing
    with === nothing && return nothing
    name == "fillStyle" ? (s.fill = with) : (s.stroke = with)
    with isa UInt32 ? written(with) : true
  elseif name == "lineWidth"
    (x = number(>(0))) === nothing ? nothing : (s.wide = x)
  elseif name == "miterLimit"
    (x = number(>(0))) === nothing ? nothing : (s.miter = x)
  elseif name == "lineDashOffset"
    (x = number(_ -> true)) === nothing ? nothing : (s.phase = x)
  elseif name == "globalAlpha"
    (x = number(x -> 0 <= x <= 1)) === nothing ? nothing : (s.alpha = x)
  elseif name == "shadowBlur"
    (x = number(>=(0))) === nothing ? nothing : (s.blur = x)
  elseif name == "shadowOffsetX"
    (x = number(_ -> true)) === nothing ? nothing : (s.dx = x)
  elseif name == "shadowOffsetY"
    (x = number(_ -> true)) === nothing ? nothing : (s.dy = x)
  elseif name == "lineDash"
    s.dash = Float32[Float32(x) for x in v]
    true
  elseif name == "lineCap"
    v in ("butt", "round", "square") ? (s.cap = Symbol(v); v) : nothing
  elseif name == "lineJoin"
    v in ("miter", "round", "bevel") ? (s.join = Symbol(v); v) : nothing
  elseif name == "globalCompositeOperation"
    haskey(BLENDS, v) ? (s.blend = BLENDS[v]; v) : nothing
  elseif name == "textAlign"
    v in ALIGNS ? (s.align = Symbol(v); v) : nothing
  elseif name == "textBaseline"
    v in BASES ? (s.base = Symbol(v); v) : nothing
  elseif name == "shadowColor"
    (c = v isa AbstractString ? ink(v) : nothing) === nothing ? nothing : (s.shadow = c; written(c))
  elseif name == "font"
    (f = v isa AbstractString ? lettering(v) : nothing) === nothing ? nothing : (s.font = f; String(strip(v)))
  elseif name == "imageSmoothingEnabled"
    s.smooth = v === true || (v isa AbstractString && v == "true")
  else
    nothing
  end
end

"""
Give the scripts of the world `js` a canvas to draw on. Call it once, after
window.jl has made `window` and `document` there. `node(number)` gives the
element that a script holds as that number. `load(address)` gives the bytes of
a picture or a video that the page names, or nothing. `now()` gives how many
seconds ago the page was first shown. `changed()` is called when a script
starts, stops or moves a video, so that the page is laid out again.

Gives a function of the script. Call it with "animationend" or
"transitionend", the name of the animation or of the property, and how many
seconds it took, just before that event is told to the page: the event then
says those.
"""
start!(js::Context; node, load=address -> nothing, now=() -> 0.0, changed=() -> nothing) = begin
  pictures = Pictures(load)
  # Skia's picture of an element that a canvas can draw, with how wide and how high it is, or nothing
  picture(e::Element) = begin
    if e.tag == "canvas"
      b = at(e)
      image = image!(b)
      image == C_NULL ? nothing : (image, Float64(b.wide), Float64(b.high))
    elseif e.tag == "video"
      # Its picture of this moment
      v = reel(e)
      shown = v === nothing ? nothing : frame(v, spot(play(e), now(), haskey(e.attrs, "loop"))[1])
      shown === nothing ? nothing : (shown.image, Float64(shown.wide), Float64(shown.high))
    else
      src = attr(e, e.tag == "image" ? "href" : "src")
      got = isempty(strip(src)) ? nothing : pictures(src)
      got === nothing ? nothing : (got[3], Float64(got[1]), Float64(got[2]))
    end
  end
  # The video of a <video> element: the first that macOS can read, of its `src` and of the <source> elements in it
  reel(e::Element) = begin
    for src in (attr(e, "src"), (attr(k, "src") for k in e.children if k isa Element && k.tag == "source")...)
      v = isempty(strip(src)) ? nothing : film(pictures, replace(strip(src), r"#t=[0-9.]+$" => ""))
      v === nothing && continue
      p = play(e)
      isfinite(p.long) || (p.long = v.long)
      return v
    end
    nothing
  end
  at(e::Element) = board(e; picture)
  at(id::Real) = at(node(id)::Element)
  natives = Dict{String,Any}(
    "make" => id -> (at(id); nothing),
    "resize" => id -> (clear!(at(id)); nothing),
    "reset" => id -> (clear!(at(id)); nothing),
    "save" => id -> save!(at(id)),
    "restore" => id -> restore!(at(id)),
    "turn" => (id, m...) -> turn!(at(id), m),
    "matrix" => (id, m...) -> matrix!(at(id), m),
    "moved" => id -> collect(at(id).state.m),
    "set" => (id, name, v) -> set!(at(id), name, v, node),
    "colour" => text -> (c = ink(text); c === nothing ? nothing : written(c)),
    "rect" => (id, how, x, y, w, h) -> rect!(at(id), x, y, w, h; how=Symbol(how)),
    "begin" => id -> (empty!(at(id).shape); nothing),
    "step" => (id, op, a...) -> (b = at(id); add!(b.shape, b.state.m, op, a); nothing),
    "draw" => (id, how, rule, steps) -> begin
      b = at(id)
      s = steps === nothing ? b.shape : trace!(Shape(), b.state.m, steps)
      how == "clip" ? clip!(b, s; rule) : paint!(b, Symbol(how), s; rule)
      nothing
    end,
    "hit" => (id, steps, x, y, rule) -> begin
      b = at(id)
      inside(steps === nothing ? b.shape : trace!(Shape(), b.state.m, steps), x, y; rule)
    end,
    "text" => (id, how, text, x, y, most) -> (write!(at(id), text, x, y; how=Symbol(how), most=something(most, Inf)); nothing),
    "measure" => (id, text) -> (b = at(id); [measure(b, text), b.state.font.ascent, b.state.font.descent]),
    "size" => id -> (got = picture(node(id)::Element); got === nothing ? nothing : [got[2], got[3]]),
    "image" => (id, from, a...) -> begin
      got = picture(node(from)::Element)
      got === nothing || stamp!(at(id), got[1], got[2], got[3], a[1:4], a[5:8])
      nothing
    end,
    # A string with one character for each byte: see `fromBytes` in the script
    "pixels" => (id, x, y, w, h) -> transcode(String, UInt16.(pixels(at(id), Int(x), Int(y), Int(w), Int(h)))),
    "setPixels" => (id, text, x, y, w, h) -> (pixels!(at(id), UInt8[UInt8(UInt32(c) & 0xff) for c in text], Int(x), Int(y), Int(w), Int(h)); nothing),
    "url" => (id, kind, quality) -> address(at(id), kind, something(quality, 0.92)),
    # A <video>: how far it has got, whether it plays, and how long it is. Then what starts it, stops it and moves it.
    "media" => id -> begin
      e = node(id)::Element
      v = reel(e)
      t, going = spot(play(e), now(), haskey(e.attrs, "loop"))
      [t, going, v === nothing ? nothing : v.long]
    end,
    "play" => id -> (e = node(id)::Element; reel(e); play!(play(e), now(), haskey(e.attrs, "loop")); changed(); nothing),
    "pause" => id -> (e = node(id)::Element; pause!(play(e), now(), haskey(e.attrs, "loop")); changed(); nothing),
    "seek" => (id, t) -> (e = node(id)::Element; reel(e); seek!(play(e), now(), t, haskey(e.attrs, "loop")); changed(); nothing),
  )
  ending = evaluate(js, CONTEXT; name="canvas.js")(natives)
  Webgl.start!(js; node, picture, board=at)
  ending
end

export start!
