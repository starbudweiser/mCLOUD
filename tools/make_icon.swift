// Dessine le motif de mCLOUD (nuage blanc monochrome sur fond transparent) en PNG 1024, à passer dans MiCONE pour obtenir l'icône :
//   swift make_icon.swift assets/mCLOUD_motif.png
//   MiCONE --cli assets/mCLOUD_motif.png --sortie assets/out --fond sombre
import AppKit
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let c = NSBezierPath()
c.appendOval(in: NSRect(x: 150, y: 330, width: 330, height: 330))
c.appendOval(in: NSRect(x: 310, y: 400, width: 410, height: 410))
c.appendOval(in: NSRect(x: 540, y: 330, width: 290, height: 290))
c.appendRoundedRect(NSRect(x: 240, y: 290, width: 500, height: 190), xRadius: 95, yRadius: 95)
NSColor.white.setFill(); c.fill()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
