import AppKit

// Renders the Pingky app icon (a cute mascot emitting colored "ping" waves)
// at every size needed for a macOS .icns, in a 1024x1024 reference space (y-up).

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

let navy = color(38, 31, 74)

func drawIcon(_ cg: CGContext) {
    let cs = CGColorSpaceCreateDeviceRGB()

    // --- Background squircle with pink -> purple gradient ---
    let bgRect = CGRect(x: 96, y: 96, width: 832, height: 832)
    let squircle = CGPath(roundedRect: bgRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()
    let bg = CGGradient(colorsSpace: cs,
                        colors: [color(255, 122, 196), color(146, 80, 255)] as CFArray,
                        locations: [0, 1])!
    cg.drawLinearGradient(bg, start: CGPoint(x: 512, y: 928), end: CGPoint(x: 512, y: 96), options: [])

    // soft glow behind the mascot
    let glow = CGGradient(colorsSpace: cs,
                          colors: [color(255, 255, 255, 0.35), color(255, 255, 255, 0)] as CFArray,
                          locations: [0, 1])!
    cg.drawRadialGradient(glow,
                          startCenter: CGPoint(x: 512, y: 430), startRadius: 0,
                          endCenter: CGPoint(x: 512, y: 430), endRadius: 360, options: [])
    cg.restoreGState()

    // --- Ping waves fanning up from the antenna knob ---
    let knob = CGPoint(x: 512, y: 760)
    let waves: [(CGFloat, CGColor)] = [
        (55, color(78, 209, 94)),    // green (low latency)
        (92, color(244, 208, 63)),   // yellow
        (129, color(240, 96, 58)),   // red (high latency)
    ]
    cg.setLineCap(.round)
    for (radius, c) in waves {
        cg.setStrokeColor(c)
        cg.setLineWidth(20)
        cg.addArc(center: knob, radius: radius,
                  startAngle: 35 * .pi/180, endAngle: 145 * .pi/180, clockwise: false)
        cg.strokePath()
    }

    // --- Antenna stalk + knob ---
    cg.setStrokeColor(navy)
    cg.setLineWidth(14)
    cg.setLineCap(.round)
    cg.move(to: CGPoint(x: 512, y: 668))
    cg.addLine(to: CGPoint(x: 512, y: 748))
    cg.strokePath()
    cg.setFillColor(color(240, 96, 58))
    cg.fillEllipse(in: CGRect(x: knob.x - 24, y: knob.y - 24, width: 48, height: 48))

    // --- Body blob (white with subtle gradient) ---
    let bodyCenter = CGPoint(x: 512, y: 430)
    let bodyR: CGFloat = 240
    let bodyRect = CGRect(x: bodyCenter.x - bodyR, y: bodyCenter.y - bodyR, width: bodyR*2, height: bodyR*2)
    cg.saveGState()
    cg.addEllipse(in: bodyRect)
    cg.clip()
    let body = CGGradient(colorsSpace: cs,
                          colors: [color(255, 255, 255), color(255, 224, 240)] as CFArray,
                          locations: [0, 1])!
    cg.drawLinearGradient(body, start: CGPoint(x: 512, y: 670), end: CGPoint(x: 512, y: 190), options: [])
    cg.restoreGState()

    // --- Cheeks ---
    cg.setFillColor(color(255, 150, 190, 0.65))
    cg.fillEllipse(in: CGRect(x: 372 - 32, y: 440 - 32, width: 64, height: 64))
    cg.fillEllipse(in: CGRect(x: 652 - 32, y: 440 - 32, width: 64, height: 64))

    // --- Eyes ---
    for ex: CGFloat in [432, 592] {
        cg.setFillColor(navy)
        cg.fillEllipse(in: CGRect(x: ex - 38, y: 500 - 38, width: 76, height: 76))
        cg.setFillColor(color(255, 255, 255))
        cg.fillEllipse(in: CGRect(x: ex - 38 + 14, y: 500 + 6, width: 26, height: 26))
    }

    // --- Smile (U-shaped lower arc) ---
    cg.setStrokeColor(navy)
    cg.setLineWidth(22)
    cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: 512, y: 500), radius: 90,
              startAngle: 200 * .pi/180, endAngle: 340 * .pi/180, clockwise: false)
    cg.strokePath()
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let scale = CGFloat(px) / 1024
    cg.scaleBy(x: scale, y: scale)
    drawIcon(cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Generate the iconset.
let fm = FileManager.default
let dir = "Pingky.iconset"
try? fm.removeItem(atPath: dir)
try! fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
}
print("Wrote \(dir) with \(entries.count) images")
