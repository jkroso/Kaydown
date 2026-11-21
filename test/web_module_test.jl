# Tests for modules: web/module.jl, which makes a module of JavaScript a plain
# script, and "modules" in web/script.jl, which gets each module's file and
# runs it. Run them with `julia -O0 --project=. test/web_module_test.jl`. They
# use no web: a dictionary of files stands in for it.

@use Test: @test, @testset
@use "../web/module" => Mod
@use "../web/live" => Live

js(l, code) = Live.evaluate(l, code)
lines(l, level=:log) = [text for (lv, text) in l.scripts.log if lv == level]

@testset "a module as a function" begin
  m = Mod.script_of("""
    import * as THREE from 'three';
    import { a, b as c } from "./x.js"
    import d from './d.js'
    import './side.js';
    const pattern = /['"`{]/g, words = `a \${ {b: 1}.b } c`;
    x.import(1); obj.export = 3
    export const A = 1, B = { k: [1, 2] }, C = 3;
    export function f() { return import('./lazy.js') }
    export class K extends THREE.Mesh {}
    export default function main() {}
    export { A as AA };
    export * from './all.js';
    export { q as Q } from './q.js'
    console.log(import.meta.url)
    """)
  @test m.imports == ["three", "./x.js", "./d.js", "./side.js", "./all.js", "./q.js"]
  lines_of = split(m.code, '\n')
  # Each line keeps its place, so an error names the right line
  @test length(lines_of) == 15
  @test occursin("const THREE = __lm_i(0);", lines_of[1]) && occursin("const {a: a, b: c} = __lm_i(1);", lines_of[1]) && occursin("const d = __lm_i(2).default;", lines_of[1])
  @test occursin("\"A\": () => A", lines_of[1]) && occursin("\"default\": () => main", lines_of[1]) && occursin("\"Q\": () => __lm_i(5)[\"q\"]", lines_of[1]) &&
        occursin("__lm_x.star(__lm_i(4))", lines_of[1])
  @test strip(lines_of[5]) == "const pattern = /['\"`{]/g, words = `a \${ {b: 1}.b } c`;" && strip(lines_of[6]) == "x.import(1); obj.export = 3"
  @test strip(lines_of[7]) == "const A = 1, B = { k: [1, 2] }, C = 3;" && strip(lines_of[8]) == "function f() { return __lm_import('./lazy.js') }"
  @test strip(lines_of[10]) == "function main() {}" && isempty(strip(lines_of[11])) && strip(lines_of[14]) == "console.log(__lm_meta.url)"
end

const files = Dict{String,Any}(
  "https://cdn.example.com/lib/three.js" => """
    import { helper } from './helper.js';
    export const REVISION = '169';
    export class Mesh { constructor() { this.kind = helper('mesh') } }
    export * from './more.js';
    export default 'three';
    """,
  "https://cdn.example.com/lib/helper.js" => "export function helper(x) { return x.toUpperCase() }",
  "https://cdn.example.com/lib/more.js" => "export const MORE = 'more'; export let counter = 0; export function bump() { counter++ }",
  "https://cdn.example.com/addons/extra.js" => "import * as THREE from 'three'; export const extra = THREE.REVISION + '!';",
  "https://example.com/local.js" => "export const local = document.title; window.order.push('local')",
  "https://example.com/lazy.js" => "export const lazy = 'lazy'",
  "https://example.com/waits.js" => "await Promise.resolve(); export const waited = 'yes'; window.order.push('waits')",
)

page(body) = """<!DOCTYPE html><title>Modules</title>
  <script type="importmap">{ "imports": { "three": "https://cdn.example.com/lib/three.js", "three/addons/": "https://cdn.example.com/addons/" } }</script>
  <script>window.order = ['classic']; document.addEventListener('DOMContentLoaded', () => window.order.push('ready'))</script>
  $body"""

@testset "a page's modules run, with what they import" begin
  l = Live.live(page("""
    <script type="module">
      import * as THREE from 'three';
      import three, { MORE, bump, counter } from 'three';
      import { extra } from 'three/addons/extra.js';
      import { local } from './local.js';
      window.got = [THREE.REVISION, new THREE.Mesh().kind, three, MORE, extra, local, typeof bump, import.meta.url]
      bump(); bump()
      window.counted = THREE.counter
      window.order.push('inline')
    </script>
    <script>window.order.push('after')</script>
    <script nomodule>window.order.push('nomodule')</script>"""); wide=400, load=address -> get(files, address, nothing), base="https://example.com/index.html")
  @test lines(l, :error) == []
  @test js(l, "got") == Any["169", "MESH", "three", "more", "169!", "Modules", "function", "https://example.com/index.html"]
  # A name that a module exports is seen as it changes
  @test js(l, "counted") == 2
  # A module runs after the page's other scripts, and before the page is ready. A script for browsers with no modules doesn't run.
  @test js(l, "order") == Any["classic", "after", "local", "inline", "ready"]
end

@testset "a module waits for its files" begin
  coming = Dict{String,Any}(files)
  coming["https://cdn.example.com/lib/helper.js"] = :waiting
  l = Live.live(page("""<script type="module">import { Mesh } from 'three'; window.made = new Mesh().kind</script>
                        <script type="module" src="waits.js"></script>"""); wide=400, load=address -> get(coming, address, nothing), base="https://example.com/index.html")
  @test js(l, "typeof made") == "undefined" && js(l, "order") == Any["classic"]
  coming["https://cdn.example.com/lib/helper.js"] = files["https://cdn.example.com/lib/helper.js"]
  for _ in 1:5
    Live.step!(l)
  end
  # The modules run in the page's order, the second waits for its own await, and then the page is ready
  @test js(l, "made") == "MESH" && js(l, "order") == Any["classic", "waits", "ready"]
end

@testset "import() and what goes wrong" begin
  l = Live.live(page("""<script type="module">
      import('./lazy.js').then(m => { window.lazy = m.lazy })
      import('nowhere').catch(e => { window.missed = e.message })
    </script>
    <script type="module">import { nothing } from 'unknown'</script>
    <script type="module">this.oops(</script>"""); wide=400, load=address -> get(files, address, nothing), base="https://example.com/index.html")
  for _ in 1:5
    Live.step!(l)
  end
  @test js(l, "lazy") == "lazy" && js(l, "missed") == "No module is named nowhere"
  errors = lines(l, :error)
  @test any(e -> occursin("\"unknown\"", e), errors) && any(e -> occursin("SyntaxError", e), errors)
  # The page is ready, though two of its modules failed
  @test js(l, "order") == Any["classic", "ready"]
end
