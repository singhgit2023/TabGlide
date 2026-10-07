import AppKit
import ScreenCaptureKit
import ApplicationServices

func windowBounds(_ window: AXUIElement) -> CGRect? {
    guard let position = attribute(window, kAXPositionAttribute),
          let size = attribute(window, kAXSizeAttribute),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
          AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
    return CGRect(origin: point, size: dimensions)
}

@available(macOS 14.0, *)
enum WindowPreviews {
    // AX does not expose a public window ID. Match conservatively by owner and
    // geometry/title, and leave ambiguous windows on the icon fallback.
    static func match(_ entry: WindowEntry, in windows: [SCWindow]) -> SCWindow? {
        guard !entry.minimized, let pid = entry.app?.processIdentifier else { return nil }
        let owned = windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 }
        if let bounds = entry.bounds {
            let matches = owned.filter {
                abs($0.frame.minX - bounds.minX) < 3 && abs($0.frame.minY - bounds.minY) < 3 &&
                abs($0.frame.width - bounds.width) < 3 && abs($0.frame.height - bounds.height) < 3
            }
            if matches.count == 1 { return matches[0] }
            let titled = matches.filter { $0.title == entry.title }
            if titled.count == 1 { return titled[0] }
        }
        let titled = owned.filter { $0.title == entry.title }
        return titled.count == 1 ? titled[0] : nil
    }

    static func image(for window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let ratio = max(window.frame.width, 1) / max(window.frame.height, 1)
        config.width = ratio >= 1 ? 480 : max(1, Int(300 * ratio))
        config.height = ratio >= 1 ? max(1, Int(480 / ratio)) : 300
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
