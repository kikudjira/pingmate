import AppKit

class IconGenerator {
    private let size = CGSize(width: 18, height: 18)

    func generateIcon(color: NSColor, ringColor: NSColor? = nil) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)

        if let ring = ringColor {
            // Draw outer ring (3px thick)
            ring.setFill()
            NSBezierPath(ovalIn: rect).fill()

            // Clear 2px transparent gap between ring and inner circle
            let gapRect = rect.insetBy(dx: 2, dy: 2)
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setBlendMode(.clear)
                ctx.fillEllipse(in: gapRect)
                ctx.setBlendMode(.normal)
            }

            // Draw inner circle
            let innerRect = rect.insetBy(dx: 4, dy: 4)
            color.setFill()
            NSBezierPath(ovalIn: innerRect).fill()
        } else {
            // Draw simple circle
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }

        image.unlockFocus()
        image.isTemplate = false  // Required for colored icons in menu bar
        return image
    }

    func iconForStatus(
        _ status: ConnectionStatus,
        previousStatus: ConnectionStatus?,
        colors: Settings.IconColors
    ) -> NSImage {
        let mainColor = status.nsColor(using: colors)

        // Transition icons: show ring when recovering from worse state
        if let prev = previousStatus {
            if status == .good {
                switch prev {
                case .unstable:
                    // Green center with yellow ring
                    return generateIcon(
                        color: NSColor(hex: colors.good),
                        ringColor: NSColor(hex: colors.unstable)
                    )
                case .problem:
                    // Green center with red ring
                    return generateIcon(
                        color: NSColor(hex: colors.good),
                        ringColor: NSColor(hex: colors.problem)
                    )
                default:
                    break
                }
            } else if status == .unstable && prev == .problem {
                // Yellow center with red ring
                return generateIcon(
                    color: NSColor(hex: colors.unstable),
                    ringColor: NSColor(hex: colors.problem)
                )
            }
        }

        return generateIcon(color: mainColor)
    }

    func defaultIcon() -> NSImage {
        return generateIcon(color: .gray)
    }

    func stoppedIcon() -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: rect).fill()

        image.unlockFocus()
        image.isTemplate = true  // Template icon adapts to menubar appearance
        return image
    }
}
