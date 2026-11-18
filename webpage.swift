// Makes pictures of a page of HTML, as WebKit draws it. WebKit is the part of
// macOS that draws web pages, and macOS only offers it to Swift and
// Objective-C, so this is a program of its own, and Ladder runs it. Ladder
// shows an email as it was sent with it. See webpage.jl.
//
//     webpage 700 email.html shots/ab12 shots/ab12.txt
//     webpage --pictures --zoom 1.25 700 email.html shots/ab12 shots/ab12.txt
//
// The arguments are how wide the page is in px, the file of HTML, the start of
// the name of each picture, and the text file to write last. The page is as
// tall as its content. A page whose content can't be as narrow as that is as
// wide as its content, up to 2000 px.
//
// A tall page makes a picture that's too big to draw in one piece, so the
// program writes it as strips, each 1024 px tall or less, from the top down:
// shots/ab12-1.png, shots/ab12-2.png and so on. Each file has two pixels to
// the px, so the picture is sharp on a Retina screen.
//
// The text file says what was made, with a tab between each two things of a
// line:
//
//     page   700  1310                       how wide and how tall the whole page is, in px
//     strip  1024 ab12-1.png                 how tall each strip is, and its file
//     strip  286  ab12-2.png
//     link   158  493  384  33  https://…    a rectangle of the page that's a link: left, top, wide, tall, and where it goes
//
// The page runs no JavaScript, and it goes nowhere: a page that asks to show
// another page in its place is refused. Without --pictures, the program asks
// the web for nothing at all, so a picture that the page has from a web site
// is an empty box, and the sender of an email can't tell that it was opened.
// With --pictures, it asks the web for the page's pictures, fonts and style
// sheets, and for nothing else.
//
// --zoom makes everything in the page that much bigger, as a browser's zoom
// does. The page is still as wide as it was asked to be.
//
// If it can't make the pictures, it prints "error: " and why on stderr, and
// exits with 1.

import AppKit
import Foundation
import WebKit

/// How many px tall a strip is at most
let stripTall = 1024.0
/// How many px wide and tall a page is at most
let widest = 2000.0, tallest = 60000.0
/// How many pixels of a file go to a px of the page
let scale = 2.0
/// How many seconds the page gets to load before the pictures are made of what's there
let patience = 15.0

func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
func fail(_ why: String) -> Never { say("error: " + why); exit(1) }

/// What the page asks the web for is stopped here: everything, or with pictures everything but pictures, fonts and style sheets
func rules(pictures: Bool) -> String {
  let kinds = ["document", "script", "raw", "svg-document", "media", "popup", "ping", "fetch", "websocket", "other"]
  let only = pictures ? ", \"resource-type\": [" + kinds.map { "\"\($0)\"" }.joined(separator: ", ") + "]" : ""
  return ["^https?:", "^wss?:", "^ftp:"].map { "{\"trigger\": {\"url-filter\": \"\($0)\"\(only)}, \"action\": {\"type\": \"block\"}}" }
    .joined(separator: ", ").withBrackets
}
extension String { var withBrackets: String { "[" + self + "]" } }

/// The size of the page's content, and each rectangle of each link, in the px of the page before it's zoomed
let measure = """
(() => {
  const d = document.documentElement, b = document.body || d
  const links = []
  for (const a of document.links) {
    if (!/^(https?|mailto|tel):/i.test(a.href)) continue
    for (const r of a.getClientRects()) if (r.width > 0 && r.height > 0) links.push([r.left + scrollX, r.top + scrollY, r.width, r.height, a.href])
  }
  return JSON.stringify({wide: Math.max(d.scrollWidth, b.scrollWidth), tall: Math.max(d.scrollHeight, b.scrollHeight), links: links})
})()
"""

final class Painter: NSObject, WKNavigationDelegate {
  let web: WKWebView
  let wide: Double, zoom: Double
  let stem: String, out: String
  var started = false, shooting = false
  var lines: [String] = []   // what the text file says, as far as it's known

  init(web: WKWebView, wide: Double, zoom: Double, stem: String, out: String) {
    self.web = web; self.wide = wide; self.zoom = zoom; self.stem = stem; self.out = out
  }

  // The page that the program loads is the only one. A link, a form or a page that asks for another goes nowhere.
  func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let first = !started && action.targetFrame?.isMainFrame == true
    if first { started = true }
    decisionHandler(first ? .allow : .cancel)
  }

  func webView(_ w: WKWebView, didFinish n: WKNavigation!) { shoot() }
  func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { fail(e.localizedDescription) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { fail(e.localizedDescription) }
  func webViewWebContentProcessDidTerminate(_ w: WKWebView) { fail("WebKit stopped.") }

  /// Ask the page a question in JavaScript, and get its answer as JSON
  func ask(_ then: @escaping ([String: Any]) -> Void) {
    web.evaluateJavaScript(measure) { value, error in
      guard let text = value as? String, let data = text.data(using: .utf8),
            let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fail(error?.localizedDescription ?? "The page can't be measured.")
      }
      then(found)
    }
  }

  /// Make the pictures: give the page the room that its content needs, then take a picture of each strip of it
  func shoot() {
    guard !shooting else { return }
    shooting = true
    ask { first in
      // Content that can't be as narrow as the page makes the page wider, and then it's measured again
      let needs = min(widest, ((first["wide"] as? Double) ?? self.wide) * self.zoom)
      let across = needs > self.wide + 1 ? needs.rounded(.up) : self.wide
      self.web.frame = NSRect(x: 0, y: 0, width: across, height: 600)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.ask { found in
          let tall = min(tallest, max(1, (((found["tall"] as? Double) ?? 600) * self.zoom).rounded(.up)))
          self.web.frame = NSRect(x: 0, y: 0, width: across, height: tall)
          self.lines = ["page\t\(Int(across))\t\(Int(tall))"]
          let links = (found["links"] as? [[Any]] ?? []).compactMap { link -> String? in
            guard link.count == 5, let url = link[4] as? String, !url.contains("\t"), !url.contains("\n") else { return nil }
            let box = link[0..<4].compactMap { ($0 as? Double).map { String(format: "%.1f", $0 * self.zoom) } }
            return box.count == 4 ? "link\t" + box.joined(separator: "\t") + "\t" + url : nil
          }
          // The page gets a moment to lay itself out in its new room
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.strip(1, from: 0, across: across, tall: tall, links: links) }
        }
      }
    }
  }

  /// Take the picture of the strip that starts `from` px down the page, then of the ones under it, then write the text file
  func strip(_ n: Int, from: Double, across: Double, tall: Double, links: [String]) {
    if from >= tall {
      let text = (lines + links).joined(separator: "\n") + "\n"
      do { try text.write(toFile: out, atomically: true, encoding: .utf8) } catch { fail(error.localizedDescription) }
      exit(0)
    }
    let high = min(stripTall, tall - from)
    let config = WKSnapshotConfiguration()
    config.rect = CGRect(x: 0, y: from, width: across, height: high)
    // The picture has `scale` pixels to the px, whatever screen the Mac has
    config.snapshotWidth = NSNumber(value: across * scale / (NSScreen.main?.backingScaleFactor ?? 1))
    web.takeSnapshot(with: config) { image, error in
      guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        fail(error?.localizedDescription ?? "The picture can't be made.")
      }
      let file = "\(self.stem)-\(n).png"
      do { try png.write(to: URL(fileURLWithPath: file)) } catch { fail(error.localizedDescription) }
      self.lines.append("strip\t\(Int(high))\t\((file as NSString).lastPathComponent)")
      self.strip(n + 1, from: from + high, across: across, tall: tall, links: links)
    }
  }
}

@main
struct Webpage {
  static func main() {
    var args = Array(CommandLine.arguments.dropFirst())
    var pictures = false, zoom = 1.0
    while let flag = args.first, flag.hasPrefix("--") {
      args.removeFirst()
      if flag == "--pictures" { pictures = true }
      else if flag == "--zoom", let z = args.first.flatMap(Double.init), z > 0 { zoom = z; args.removeFirst() }
      else { fail("The program doesn't know \(flag).") }
    }
    guard args.count == 4, let wide = Double(args[0]), wide >= 1, wide <= widest else {
      fail("usage: webpage [--pictures] [--zoom 1.25] <wide> <html file> <start of each picture's name> <text file>")
    }
    guard let html = try? String(contentsOfFile: args[1], encoding: .utf8) else { fail("\(args[1]) can't be read.") }

    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)   // no icon in the Dock, and no window
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()   // no cookie is kept, and none is sent
    config.defaultWebpagePreferences.allowsContentJavaScript = false
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: wide, height: 600), configuration: config)
    web.appearance = NSAppearance(named: .aqua)   // an email is written for a white page, so it's drawn on one
    web.pageZoom = zoom
    let painter = Painter(web: web, wide: wide, zoom: zoom, stem: args[2], out: args[3])
    web.navigationDelegate = painter
    WKContentRuleListStore.default().compileContentRuleList(forIdentifier: pictures ? "pictures" : "nothing",
                                                             encodedContentRuleList: rules(pictures: pictures)) { list, error in
      // Without the list, the page could ask the web for anything, so there's no picture then
      guard let list else { fail(error?.localizedDescription ?? "The web can't be shut out.") }
      config.userContentController.add(list)
      web.configuration.userContentController.add(list)
      web.loadHTMLString(html, baseURL: nil)
    }
    // A picture that a web site is slow to send doesn't hold the page up for ever
    DispatchQueue.main.asyncAfter(deadline: .now() + patience) { web.stopLoading(); painter.shoot() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2 * patience) { fail("The page took too long.") }
    withExtendedLifetime(painter) { app.run() }
  }
}
