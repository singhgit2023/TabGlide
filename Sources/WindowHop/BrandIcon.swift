import AppKit

enum BrandIcon {
    static let app: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }()

    // A small, vector counterpart to the app icon: two windows and a hopping arrow.
    // Template rendering lets macOS supply the correct menu-bar contrast.
    static let menuBar: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()
            let back = NSBezierPath()
            back.move(to: NSPoint(x: 3, y: 11))
            back.line(to: NSPoint(x: 3, y: 3))
            back.curve(to: NSPoint(x: 5, y: 1), controlPoint1: NSPoint(x: 3, y: 1.5), controlPoint2: NSPoint(x: 3.5, y: 1))
            back.line(to: NSPoint(x: 13, y: 1))
            back.curve(to: NSPoint(x: 15, y: 3), controlPoint1: NSPoint(x: 14.5, y: 1), controlPoint2: NSPoint(x: 15, y: 1.5))
            back.lineWidth = 1.5
            back.lineCapStyle = .round
            back.stroke()

            let front = NSBezierPath(roundedRect: NSRect(x: 7, y: 4, width: 12, height: 9), xRadius: 2, yRadius: 2)
            front.lineWidth = 1.5
            front.stroke()
            let titleBar = NSBezierPath()
            titleBar.move(to: NSPoint(x: 7.5, y: 7))
            titleBar.line(to: NSPoint(x: 18.5, y: 7))
            titleBar.lineWidth = 1
            titleBar.stroke()

            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 2, y: 11))
            arrow.curve(to: NSPoint(x: 13, y: 16), controlPoint1: NSPoint(x: 1, y: 16), controlPoint2: NSPoint(x: 8, y: 18))
            arrow.move(to: NSPoint(x: 10, y: 14.5))
            arrow.line(to: NSPoint(x: 13, y: 16))
            arrow.line(to: NSPoint(x: 11, y: 17.5))
            arrow.lineWidth = 1.5
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "WindowHop"
        return image
    }()
}
