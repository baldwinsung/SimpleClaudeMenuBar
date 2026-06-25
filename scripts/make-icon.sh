#!/usr/bin/env bash
# Render Resources/AppIcon.icns: a coral Claude-style spark on a cream squircle.
# Run when you want to (re)generate the app icon. Requires macOS (sips/iconutil).
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_SWIFT="$(mktemp -t drawicon).swift"
PNG="$(mktemp -t icon).png"
ICONSET="build/AppIcon.iconset"

cat > "$TMP_SWIFT" <<'SWIFT'
import AppKit

let size = 1024.0
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Cream squircle background.
let inset = size * 0.05
let rect = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
NSColor(calibratedRed: 0.96, green: 0.945, blue: 0.92, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: rect.width*0.22, yRadius: rect.width*0.22).fill()

// Coral spark.
NSColor(calibratedRed: 0.851, green: 0.467, blue: 0.341, alpha: 1).setFill()
let pairs = 8
let maxLen = size * 0.31
let capW = size * 0.075
for i in 0..<pairs {
    let len = (i % 2 == 0) ? maxLen : maxLen * 0.62
    ctx.saveGState()
    ctx.translateBy(x: size/2, y: size/2)
    ctx.rotate(by: CGFloat(Double(i)/Double(pairs) * .pi))
    let capRect = CGRect(x: -capW/2, y: -len, width: capW, height: 2*len)
    NSBezierPath(roundedRect: capRect, xRadius: capW/2, yRadius: capW/2).fill()
    ctx.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

echo "==> Rendering 1024px master"
swift "$TMP_SWIFT" "$PNG"

echo "==> Building iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z "$((s*2))" "$((s*2))" "$PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -f "$TMP_SWIFT" "$PNG"
echo "==> Wrote Resources/AppIcon.icns"
