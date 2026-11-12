// Dessine l'icône de mCLOUD (nuage blanc sur carré arrondi bleu) en PNG 1024 : swift make_icon.swift sortie.png
import AppKit
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1), ending: NSColor(srgbRed: 0.01, green: 0.41, blue: 0.63, alpha: 1))!.draw(in: bg, angle: -90)
let c = NSBezierPath()
c.appendOval(in: NSRect(x: 245, y: 395, width: 270, height: 270))
c.appendOval(in: NSRect(x: 375, y: 450, width: 330, height: 330))
c.appendOval(in: NSRect(x: 560, y: 395, width: 230, height: 230))
c.appendRoundedRect(NSRect(x: 320, y: 360, width: 400, height: 150), xRadius: 75, yRadius: 75)
NSColor.white.setFill(); c.fill()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
