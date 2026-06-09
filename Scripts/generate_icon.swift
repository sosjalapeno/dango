import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

let R: CGFloat = 155
let s: CGFloat = 250
let handleLen: CGFloat = 380
let stickHalf: CGFloat = 30
let fillFraction: CGFloat = 0.84

let dx: CGFloat = cos(.pi / 4)
let dy: CGFloat = sin(.pi / 4)

var centers: [CGPoint] = []
for i in 0..<4 {
    centers.append(CGPoint(x: CGFloat(i) * s * dx, y: CGFloat(i) * s * dy))
}

let p0 = centers[0]
let handleEnd = CGPoint(x: p0.x - handleLen * dx, y: p0.y - handleLen * dy)

var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
for c in centers {
    minX = min(minX, c.x - R); maxX = max(maxX, c.x + R)
    minY = min(minY, c.y - R); maxY = max(maxY, c.y + R)
}
for pt in [handleEnd, p0] {
    minX = min(minX, pt.x - stickHalf); maxX = max(maxX, pt.x + stickHalf)
    minY = min(minY, pt.y - stickHalf); maxY = max(maxY, pt.y + stickHalf)
}
let bboxCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
let bboxW = maxX - minX
let bboxH = maxY - minY
let scale = (size * fillFraction) / max(bboxW, bboxH)

ctx.translateBy(x: size / 2, y: size / 2)
ctx.scaleBy(x: scale, y: scale)
ctx.translateBy(x: -bboxCenter.x, y: -bboxCenter.y)
ctx.setFillColor(NSColor.white.cgColor)

ctx.setLineCap(.round)
ctx.setLineWidth(stickHalf * 2)
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.move(to: handleEnd)
ctx.addLine(to: p0)
ctx.strokePath()

for c in centers {
    ctx.fillEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2))
}

NSGraphicsContext.restoreGraphicsState()

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Dango/Assets.xcassets/AppIcon.appiconset/AppIcon_1024.png"
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
