import AppKit

/// Programmatic menubar icon for Nudgy.
/// Drawn as a template image so macOS handles dark/light mode automatically.
///
/// Design: A solid dot in the bottom-left with concentric arcs radiating outward —
/// a pulse/ping signal representing "hey, pay attention."
enum NudgyIcon {

    /// Create the menubar icon.
    /// - Parameters:
    ///   - filled: Whether the dot is larger and arcs are thicker (active/attention) or thin (idle).
    ///   - badge: Whether to show a small dot badge in the upper-right (needs attention).
    ///   - size: Point size of the icon (standard menubar is 18pt).
    static func menuBarIcon(filled: Bool = false, badge: Bool = false, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawPulse(in: rect, filled: filled)
            if badge {
                drawBadge(in: rect)
            }
            return true
        }
        return image
    }

    // MARK: - Drawing

    private static func drawPulse(in rect: NSRect, filled: Bool) {
        let w = rect.width
        let h = rect.height

        // Origin dot — bottom-left area
        let dotRadius = filled ? w * 0.11 : w * 0.09
        let dotCenter = NSPoint(x: w * 0.22, y: h * 0.22)
        let dot = NSBezierPath(
            ovalIn: NSRect(
                x: dotCenter.x - dotRadius,
                y: dotCenter.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
        )
        NSColor.black.setFill()
        dot.fill()

        // Radiating arcs — quarter circles sweeping from the dot outward
        let strokeBase: CGFloat = filled ? 1.6 : 1.3
        let arcCenter = dotCenter

        // Arc 1 (closest)
        let arc1 = NSBezierPath()
        arc1.appendArc(
            withCenter: arcCenter,
            radius: w * 0.28,
            startAngle: 20,
            endAngle: 80
        )
        arc1.lineWidth = strokeBase
        arc1.lineCapStyle = .round
        NSColor.black.set()
        arc1.stroke()

        // Arc 2 (middle)
        let arc2 = NSBezierPath()
        arc2.appendArc(
            withCenter: arcCenter,
            radius: w * 0.46,
            startAngle: 18,
            endAngle: 82
        )
        arc2.lineWidth = strokeBase * 0.9
        arc2.lineCapStyle = .round
        NSColor.black.withAlphaComponent(filled ? 0.85 : 0.7).set()
        arc2.stroke()

        // Arc 3 (farthest)
        let arc3 = NSBezierPath()
        arc3.appendArc(
            withCenter: arcCenter,
            radius: w * 0.64,
            startAngle: 16,
            endAngle: 84
        )
        arc3.lineWidth = strokeBase * 0.75
        arc3.lineCapStyle = .round
        NSColor.black.withAlphaComponent(filled ? 0.6 : 0.4).set()
        arc3.stroke()
    }

    private static func drawBadge(in rect: NSRect) {
        let w = rect.width
        let h = rect.height

        // Small circular badge in upper-right corner
        let badgeSize = w * 0.28
        let badgeRect = NSRect(
            x: w - badgeSize - w * 0.02,
            y: h - badgeSize - h * 0.02,
            width: badgeSize,
            height: badgeSize
        )

        NSColor.black.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
    }
}
