// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka
//
// Regenerates the UnTangle brand assets: the "uT" monogram under a magnifier
// lens (after the UnTangle v2 icon), teal-to-blue lens on deep navy. Letters
// invert where they leave the lens.
//
//   swift Tools/MakeBrand.swift /tmp/untangle-brand
//
// Then copy:
//   AppIcon-Default.png, logo.png   -> Resources/Brand/
//   untangle-icon.svg               -> Resources/Brand/AppIcon.icon/Assets/
//   logo-light-bg.svg, logo-dark-bg.svg -> docs/assets/untangle/
// The monogram must stay under ~1.9:1 or the menu bar glyph is clipped
// (build/UnTangleDeveloper --selftest checks it).
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// MARK: Palette

let navyTopHex: UInt32 = 0x1E2B3D, navyBottomHex: UInt32 = 0x121A26
let lensStartHex: UInt32 = 0x2FD3C0, lensEndHex: UInt32 = 0x2A7FE0
let paperHex: UInt32 = 0xF4F7FA, inkHex: UInt32 = 0x1B2636

// MARK: Geometry, drawn in a 1024 design space (y down), then fitted

let lensCenter = CGPoint(x: 404, y: 372)
let lensRadius: CGFloat = 404
let letterWeight: CGFloat = 74

func lens() -> CGPath {
    CGPath(ellipseIn: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                             width: lensRadius * 2, height: lensRadius * 2), transform: nil)
}

/// A collar at the rim and a rounded grip running out along the radius at
/// 132° (down-left), the classic magnifier angle, clear of the T.
func handle() -> CGPath {
    let t: CGFloat = 132 * .pi / 180, d = CGVector(dx: cos(t), dy: sin(t))
    func at(_ r: CGFloat) -> CGPoint { CGPoint(x: lensCenter.x + d.dx * r, y: lensCenter.y + d.dy * r) }
    let width: CGFloat = 112
    let grip = CGMutablePath(); grip.move(to: at(lensRadius - 30)); grip.addLine(to: at(lensRadius + 290))
    let collar = CGMutablePath(); collar.move(to: at(lensRadius - 30)); collar.addLine(to: at(lensRadius + 64))
    return grip.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4)
        .union(collar.copy(strokingWithWidth: width * 1.42, lineCap: .butt, lineJoin: .miter, miterLimit: 4))
}

func letters() -> CGPath {
    let half = letterWeight / 2, baseline: CGFloat = 706
    let uLeft: CGFloat = 196, xTop: CGFloat = 438, bowl: CGFloat = 108 + (66 - letterWeight) / 2
    let u = CGMutablePath()
    u.move(to: CGPoint(x: uLeft + half, y: xTop))
    u.addLine(to: CGPoint(x: uLeft + half, y: baseline - half - bowl))
    u.addArc(center: CGPoint(x: uLeft + half + bowl, y: baseline - half - bowl), radius: bowl,
             startAngle: .pi, endAngle: 0, clockwise: true)
    u.addLine(to: CGPoint(x: uLeft + half + 2 * bowl, y: xTop))
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: uLeft + half + 2 * bowl, y: xTop))
    stem.addLine(to: CGPoint(x: uLeft + half + 2 * bowl, y: baseline))
    let tx: CGFloat = 724, cap: CGFloat = 250
    let t = CGMutablePath()
    t.move(to: CGPoint(x: tx - 176, y: cap + half)); t.addLine(to: CGPoint(x: tx + 164, y: cap + half))
    t.move(to: CGPoint(x: tx, y: cap + half)); t.addLine(to: CGPoint(x: tx, y: baseline))
    func s(_ p: CGPath) -> CGPath {
        p.copy(strokingWithWidth: letterWeight, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
    }
    return s(u).union(s(stem)).union(s(t))
}

/// Fits the whole mark into `size` (its longer side) centred at `center`.
func fitted(_ paths: [CGPath], size: CGFloat, center: CGPoint) -> [CGPath] {
    let box = paths.dropFirst().reduce(paths[0]) { $0.union($1) }.boundingBoxOfPath
    let k = size / max(box.width, box.height)
    var m = CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: center.x - box.midX * k, ty: center.y - box.midY * k)
    return paths.map { $0.copy(using: &m)! }
}

let rawGlass = lens().union(handle())
let rawLetters = letters()

// Icon artwork in the full 1024 tile (Icon Composer's canvas is the tile).
// 870 pt on the tile is the 700 px the PNG uses inside its 824 px body.
let iconParts = fitted([rawGlass, rawLetters], size: 870, center: CGPoint(x: 512, y: 512))
let glass = iconParts[0], iconLetters = iconParts[1]
let glassBody = glass.subtracting(iconLetters)      // gradient: lens and handle, letters knocked out
let lettersOut = iconLetters.subtracting(glass)     // paper: letters beyond the lens

// MARK: SVG

func svgPathData(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    path.applyWithBlock { el in
        let e = el.pointee, pts = e.points
        switch e.type {
        case .moveToPoint: d += "M\(f(pts[0].x)) \(f(pts[0].y))"
        case .addLineToPoint: d += "L\(f(pts[0].x)) \(f(pts[0].y))"
        case .addQuadCurveToPoint: d += "Q\(f(pts[0].x)) \(f(pts[0].y)) \(f(pts[1].x)) \(f(pts[1].y))"
        case .addCurveToPoint:
            d += "C\(f(pts[0].x)) \(f(pts[0].y)) \(f(pts[1].x)) \(f(pts[1].y)) \(f(pts[2].x)) \(f(pts[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

func hex(_ v: UInt32) -> String { String(format: "#%06X", v) }

func writeSVG(name: String, size: CGSize, glass: CGPath, letters: CGPath, lettersFill: UInt32) {
    let b = glass.boundingBoxOfPath
    let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- UnTangle mark. SPDX-License-Identifier: GPL-3.0-or-later -->
    <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(size.width))" height="\(Int(size.height))" viewBox="0 0 \(Int(size.width)) \(Int(size.height))">
      <defs>
        <linearGradient id="lens" gradientUnits="userSpaceOnUse" x1="\(Int(b.minX))" y1="\(Int(b.minY))" x2="\(Int(b.maxX))" y2="\(Int(b.maxY))">
          <stop offset="0" stop-color="\(hex(lensStartHex))"/>
          <stop offset="1" stop-color="\(hex(lensEndHex))"/>
        </linearGradient>
      </defs>
      <path fill="url(#lens)" fill-rule="evenodd" d="\(svgPathData(glass))"/>
      <path fill="\(hex(lettersFill))" fill-rule="evenodd" d="\(svgPathData(letters))"/>
    </svg>

    """
    try! svg.write(toFile: "\(out)/\(name)", atomically: true, encoding: .utf8)
}

writeSVG(name: "untangle-icon.svg", size: CGSize(width: 1024, height: 1024),
         glass: glassBody, letters: lettersOut, lettersFill: paperHex)

// MARK: Raster

func render(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = g
    let ctx = g.cgContext
    // y-down drawing space in pixels
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func png(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}

func gradient(_ a: UInt32, _ b: UInt32) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(a), rgb(b)] as CFArray,
               locations: [0, 1])!
}

func fillGradient(_ path: CGPath, _ g: CGGradient, from: CGPoint, to: CGPoint, in ctx: CGContext) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// App icon: 824 px body inside 1024, the macOS grid, corner radius 22.37 %.
let icon = render(1024, 1024) { ctx in
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tile = CGPath(roundedRect: body, cornerWidth: 184, cornerHeight: 184, transform: nil)
    var toBody = CGAffineTransform(a: 824 / 1024, b: 0, c: 0, d: 824 / 1024, tx: 100, ty: 100)
    let g = glassBody.copy(using: &toBody)!, l = lettersOut.copy(using: &toBody)!

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 30, color: rgb(0x000000, 0.30))
    ctx.addPath(tile); ctx.setFillColor(rgb(navyBottomHex)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    fillGradient(tile, gradient(navyTopHex, navyBottomHex),
                 from: CGPoint(x: body.midX, y: body.minY), to: CGPoint(x: body.midX, y: body.maxY), in: ctx)
    let gb = g.boundingBoxOfPath
    fillGradient(g, gradient(lensStartHex, lensEndHex),
                 from: CGPoint(x: gb.minX, y: gb.minY), to: CGPoint(x: gb.maxX, y: gb.maxY), in: ctx)
    ctx.addPath(l); ctx.setFillColor(rgb(paperHex)); ctx.fillPath(using: .evenOdd)
    ctx.addPath(tile); ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(4); ctx.strokePath()
    ctx.restoreGState()
}
png(icon, "AppIcon-Default.png")

// Monogram for the menu bar, panel header and About: one colour, letters
// knocked out of the glass and kept where they leave it.
let monoRaw = rawGlass.symmetricDifference(rawLetters)
let mb = monoRaw.boundingBoxOfPath
var toOrigin = CGAffineTransform(translationX: -mb.minX, y: -mb.minY)
let mono = monoRaw.copy(using: &toOrigin)!
let logoH = 1024, logoW = Int((CGFloat(logoH) * mb.width / mb.height).rounded())
png(render(logoW, logoH) { ctx in
    let k = CGFloat(logoH) / mb.height
    ctx.scaleBy(x: k, y: k)
    ctx.addPath(mono); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath(using: .evenOdd)
}, "logo.png")

// README logos: the coloured glass, letters in ink or paper beyond the lens.
let readme = fitted([rawGlass, rawLetters], size: 512, center: CGPoint(x: 256, y: 256))
let readmeGlass = readme[0].subtracting(readme[1]), readmeLetters = readme[1].subtracting(readme[0])
writeSVG(name: "logo-light-bg.svg", size: CGSize(width: 512, height: 512),
         glass: readmeGlass, letters: readmeLetters, lettersFill: inkHex)
writeSVG(name: "logo-dark-bg.svg", size: CGSize(width: 512, height: 512),
         glass: readmeGlass, letters: readmeLetters, lettersFill: paperHex)

print("brand written to \(out); monogram aspect \(mb.width / mb.height)")
