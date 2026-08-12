#!/usr/bin/env swift

// Regenerates the VPN status icons next to this script.
//
// The icons are the real ones WireGuard and NordVPN put in the macOS menu bar,
// lifted out of each app's Assets.car — there is no file on disk to point
// sketchybar at, so they have to be baked into PNGs once. Both ship as black
// template images that AppKit tints at draw time; sketchybar draws
// background.image as-is, so the tint is applied here instead.
//
// Re-run after an app update if either vendor changes its icon:
//   ./assets/extract-vpn-icons.swift

import Cocoa

// height is only a hint for the raster fallback (draw the biggest bitmap
// Apple shipped, at its own native size — asking for more than that just
// upscales and blurs it). NordVPN's asset also carries a PDF representation;
// that one is rasterised at generousSize regardless of final display size,
// because vector source rasterised small looks exactly as soft as the small
// raster does — anti-aliasing eats fine detail at ~30px either way. Render
// big and let sketchybar's own minification do the downscale.
let generousSize = NSSize(width: 240, height: 240)

let jobs = [
    ("/Applications/WireGuard.app", "StatusBarIcon", "wireguard-on.png"),
    ("/Applications/WireGuard.app", "StatusBarIconDimmed", "wireguard-off.png"),
    ("/Applications/NordVPN.app", "statusBarConnectedBlack", "nordvpn-on.png"),
    ("/Applications/NordVPN.app", "statusBarDisconnectedBlack", "nordvpn-off.png"),
]

let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
var failed = false

for (app, asset, name) in jobs {
    guard let bundle = Bundle(path: app), let src = bundle.image(forResource: asset) else {
        FileHandle.standardError.write("skip \(name): \(asset) not found in \(app)\n".data(using: .utf8)!)
        failed = true
        continue
    }

    // Pick a specific representation rather than calling src.draw(in:) on the
    // composite NSImage: that leaves AppKit to guess which of several
    // same-named representations to use for a size that matches none of them
    // exactly, and it was guessing the smallest one — the earlier version of
    // this script rendered NordVPN's icon from an 18x15px raster blown up 2x,
    // which is the "low-quality" look this rewrite fixes.
    let size: NSSize
    let rep: NSImageRep
    if let pdf = src.representations.first(where: { $0 is NSPDFImageRep }) {
        rep = pdf
        size = NSSize(width: (generousSize.height * pdf.size.width / pdf.size.height).rounded(), height: generousSize.height)
    } else if let raster = src.representations.max(by: { $0.pixelsWide < $1.pixelsWide }) {
        rep = raster
        size = NSSize(width: raster.pixelsWide, height: raster.pixelsHigh)
    } else {
        FileHandle.standardError.write("skip \(name): no usable representation\n".data(using: .utf8)!)
        failed = true
        continue
    }

    // Draw into a bitmap of an explicit pixel size rather than via lockFocus():
    // that picks up the current screen's backing scale, so on a Retina display
    // it would quietly emit twice the pixels asked for — and sketchybar reads
    // image pixels as points, which makes icon.background.image.scale render
    // everything at double size.
    guard let out = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else {
        FileHandle.standardError.write("skip \(name): could not allocate bitmap\n".data(using: .utf8)!)
        failed = true
        continue
    }
    out.size = size // one point per pixel

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current!.cgContext.interpolationQuality = .high
    rep.draw(in: NSRect(origin: .zero, size: size))
    // sourceAtop over the drawn glyph keeps its alpha (including the softer
    // alpha of the "dimmed" variants) and replaces only the colour.
    NSColor.white.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = out.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("skip \(name): could not encode PNG\n".data(using: .utf8)!)
        failed = true
        continue
    }
    try png.write(to: dir.appendingPathComponent(name))
    print("\(name) \(Int(size.width))x\(Int(size.height)) (\(rep is NSPDFImageRep ? "vector" : "raster"))")
}

exit(failed ? 1 : 0)
