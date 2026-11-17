// Makes a picture of the map round a place, with a pin on the place, using
// MapKit, which is part of macOS. macOS only offers MapKit to Swift and
// Objective-C, so this is a program of its own, and Kaydown runs it. See map.jl.
//
//     map 15 720 280 site.png "8 Wattle Street, Brunswick VIC 3056"
//     map --dark 15 720 280 site.png "-37.7701, 144.9610"
//     map --centre -37.7681,144.9426 15 720 280 site.png "8 Wattle Street, Brunswick VIC 3056"
//
// The arguments are the zoom, how wide and how tall the picture is in px, the
// PNG file to write, and the place. The place is an address, or a latitude and
// a longitude. The zoom is the one that maps on the web use: each step shows
// half as much from side to side, and 15 shows a few streets. The file has two
// pixels to the px, so the picture is sharp on a Retina screen. With --dark,
// the map has the colours of a dark page. With --centre and a latitude and a
// longitude, that point is in the middle of the picture, and the pin is on the
// place wherever that is. A place that isn't in the picture has no pin there.
//
// The picture is a rectangle of the map of the world as maps on the web draw
// it, which is 256 px wide at zoom 0 and twice as wide at each step. So map.jl
// can work out which latitude and longitude is at each point of the picture.
//
// When the picture is written, the program prints one line: the latitude, the
// longitude and the address that Apple has for the place, with a tab between
// each two. If it can't make the picture, it prints "error: " and why on
// stderr. It exits with 2 when Apple finds no such place, and with 1 for
// anything else, like no network.
//
// Apple finds an address from its words, and that needs the network. The
// program never asks where the Mac is, so macOS asks the person for nothing.

import AppKit
import Foundation
import MapKit

@main
struct MapPicture {
  /// How many pixels of the file go to a px of the picture
  static let scale = 2.0
  /// How many seconds Apple gets to answer before the program gives up
  static let patience = 30.0

  static func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
  static func fail(_ why: String, code: Int32 = 1) -> Never { say("error: " + why); exit(code) }

  /// The latitude and the longitude that `place` holds, like "-37.7701, 144.9610", or nil when it's an address
  static func coordinate(_ place: String) -> CLLocationCoordinate2D? {
    let parts = place.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    // A number here has only digits, a point and a sign, as map.jl has it
    guard parts.count == 2, parts.allSatisfy({ $0.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" } }),
          let lat = Double(parts[0]), let lon = Double(parts[1]), abs(lat) <= 90, abs(lon) <= 180 else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  /// An address on one line
  static func oneLine(_ address: String?) -> String {
    (address ?? "").split(whereSeparator: { $0.isNewline || $0 == "\t" })
      .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
  }

  /// Draw a pin whose point is at `tip`. The picture's y grows upwards.
  static func drawPin(at tip: CGPoint) {
    let r = 11.0                                   // of the pin's round head
    let centre = CGPoint(x: tip.x, y: tip.y + 26)   // of the head
    let pin = NSBezierPath()
    pin.move(to: tip)
    pin.curve(to: CGPoint(x: centre.x - r, y: centre.y), controlPoint1: CGPoint(x: tip.x - 2, y: tip.y + 9),
              controlPoint2: CGPoint(x: centre.x - r, y: centre.y - 9))
    pin.appendArc(withCenter: centre, radius: r, startAngle: 180, endAngle: 0, clockwise: true)
    pin.curve(to: tip, controlPoint1: CGPoint(x: centre.x + r, y: centre.y - 9), controlPoint2: CGPoint(x: tip.x + 2, y: tip.y + 9))
    pin.close()
    // A soft shadow on the ground under the point
    NSColor.black.withAlphaComponent(0.25).setFill()
    NSBezierPath(ovalIn: CGRect(x: tip.x - 5, y: tip.y - 2, width: 10, height: 4)).fill()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = CGSize(width: 0, height: -1)
    shadow.set()
    NSColor(srgbRed: 0.92, green: 0.26, blue: 0.21, alpha: 1).setFill()
    pin.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(srgbRed: 0.70, green: 0.16, blue: 0.13, alpha: 1).setStroke()
    pin.lineWidth = 1
    pin.stroke()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8)).fill()
  }

  static func main() async {
    var args = Array(CommandLine.arguments.dropFirst())
    var dark = false
    var middle: CLLocationCoordinate2D? = nil
    while let flag = args.first, flag.hasPrefix("--") {
      args.removeFirst()
      if flag == "--dark" {
        dark = true
      } else if flag == "--centre", let given = args.first, let point = coordinate(given) {
        middle = point
        args.removeFirst()
      } else {
        fail("map takes --dark, and --centre with a latitude and a longitude, like this: --centre -37.7681,144.9426")
      }
    }
    guard args.count == 5, let zoom = Double(args[0]), let wide = Double(args[1]), let tall = Double(args[2]),
          wide >= 1, tall >= 1 else {
      fail("Say the zoom, the size, the file and the place, like this: map 15 720 280 site.png \"8 Wattle Street, Brunswick\"")
    }
    let out = URL(fileURLWithPath: args[3])
    let place = args[4].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !place.isEmpty else { fail("The place is empty", code: 2) }

    // Apple gets so long to answer. A Mac with no network can wait much longer than that.
    Task.detached {
      try? await Task.sleep(nanoseconds: UInt64(patience * 1e9))
      fail("Apple's maps didn't answer in \(Int(patience)) seconds")
    }

    // Where the place is, and the address that Apple has for it
    var pin: CLLocationCoordinate2D
    var address = ""
    if let given = coordinate(place) {
      pin = given
      // The address is only to show under the map, so the map is made without it when Apple has none
      let here = CLLocation(latitude: given.latitude, longitude: given.longitude)
      if let request = MKReverseGeocodingRequest(location: here), let items = try? await request.mapItems, let item = items.first {
        address = oneLine(item.address?.fullAddress)
      }
    } else {
      guard let request = MKGeocodingRequest(addressString: place) else { fail("Apple's maps can't read this address", code: 2) }
      let items: [MKMapItem]
      do { items = try await request.mapItems } catch {
        // MapKit says that it found nothing with an error of its own. Any other error is the network.
        let e = error as NSError
        let none = e.domain == MKError.errorDomain && e.code == Int(MKError.placemarkNotFound.rawValue)
        fail(none ? "Apple's maps found no such place" : error.localizedDescription, code: none ? 2 : 1)
      }
      guard let item = items.first else { fail("Apple's maps found no such place", code: 2) }
      pin = item.location.coordinate
      address = oneLine(item.address?.fullAddress)
    }

    // MapKit's own map of the world is the one that maps on the web draw, 2^28 of its points wide. A map on the web
    // is 256 px wide at zoom 0 and twice as wide at each step, so a px is 2^(20 - zoom) of MapKit's points.
    let world = MKMapSize.world
    var per = pow(2, 20 - min(max(zoom, 1), 20))
    // MapKit shows no more than half the width of the world, so a picture that asks for more shows a little less
    per = min(per, world.width / 2 / wide, world.height / 2 / tall)
    let at = MKMapPoint(middle ?? pin)
    // The map of the world has a top and a bottom, and the picture stays between them
    let top = min(max(at.y - tall * per / 2, 0), world.height - tall * per)
    let options = MKMapSnapshotter.Options()
    options.mapRect = MKMapRect(x: at.x - wide * per / 2, y: top, width: wide * per, height: tall * per)
    options.size = NSSize(width: wide, height: tall)
    options.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
    let shot: MKMapSnapshotter.Snapshot
    do { shot = try await MKMapSnapshotter(options: options).start() } catch { fail(error.localizedDescription) }

    // The map and the pin are drawn into a picture of our own, so the file has `scale` pixels to the px on any Mac
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(wide * scale), pixelsHigh: Int(tall * scale),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fail("The Mac couldn't make the picture") }
    // The picture's size in px is set before its context is made, so what's drawn is `scale` times as big in pixels
    bitmap.size = NSSize(width: wide, height: tall)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fail("The Mac couldn't make the picture") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    shot.image.draw(in: NSRect(x: 0, y: 0, width: wide, height: tall))
    // On the Mac, MapKit counts a point's y from the bottom of the picture, as AppKit draws.
    // A pin whose place is outside the picture is outside it too, and doesn't show.
    drawPin(at: shot.point(for: pin))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fail("The Mac couldn't make the picture") }
    do { try png.write(to: out, options: .atomic) } catch { fail("The Mac couldn't write \(out.lastPathComponent)") }
    print(String(format: "%.6f\t%.6f\t", pin.latitude, pin.longitude) + address)
    exit(0)
  }
}
