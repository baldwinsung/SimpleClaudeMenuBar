import SwiftUI

extension Color {
    /// Claude's coral/orange brand color (~#D97757).
    static let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.341)
}

/// A Claude-style radial "spark" mark, approximated with tapered spokes.
///
/// This is an original drawing, not Anthropic's official logo asset — swap in
/// the real mark by dropping `Resources/AppIcon.icns` for the app icon.
struct ClaudeSpark: View {
    var color: Color = .claudeOrange
    /// Number of capsules; each renders as a symmetric pair of rays.
    var pairs: Int = 8

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<pairs, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(
                            width: side * 0.12,
                            height: side * (i.isMultiple(of: 2) ? 0.98 : 0.62)
                        )
                        .rotationEffect(.degrees(Double(i) / Double(pairs) * 180))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

enum AppLogo {
    /// A small spark rendered for the menu bar, cached.
    @MainActor static let menuBarImage: NSImage = render()

    @MainActor private static func render() -> NSImage {
        let renderer = ImageRenderer(content:
            ClaudeSpark()
                .frame(width: 16, height: 16)
                .padding(1)
        )
        renderer.scale = 2.0
        if let img = renderer.nsImage {
            img.isTemplate = false
            return img
        }
        return NSImage(size: NSSize(width: 16, height: 16))
    }
}
