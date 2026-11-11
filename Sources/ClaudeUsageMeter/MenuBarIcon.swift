import AppKit

/// Draws the menu bar item: one colored dot per open session (up to 6) and the session count.
/// Rendered as a non-template image so the health colors survive the menu bar's tinting.
@MainActor
enum MenuBarIcon {
    static func image(for store: UsageStore, labelColor: NSColor = .labelColor) -> NSImage {
        let colors = store.sessions.prefix(6).map { NSColor(store.health(of: $0).color) }
        let label = "\(store.sessions.count)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: labelColor,
        ]

        let height: CGFloat = 18, dot: CGFloat = 11, gap: CGFloat = 4
        let dotsWidth = CGFloat(colors.count) * (dot + gap)
        let size = NSSize(width: dotsWidth + label.size(withAttributes: attributes).width + 2, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for color in colors {
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: (height - dot) / 2, width: dot, height: dot)).fill()
                x += dot + gap
            }
            label.draw(at: NSPoint(x: x, y: (height - 15) / 2), withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
    }
}
