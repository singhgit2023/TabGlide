import AppKit
import ApplicationServices

struct DockTarget {
    let app: NSRunningApplication
    let frame: CGRect // AppKit screen coordinates
}

final class DockHover {
    private let queue = DispatchQueue(label: "WindowHop.dockHover", qos: .utility)
    private var busy = false

    func target(at point: CGPoint, completion: @escaping (DockTarget?) -> Void) {
        guard !busy else { return }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }),
              point.y < screen.frame.minY + 180 || point.x < screen.frame.minX + 180 || point.x > screen.frame.maxX - 180,
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            completion(nil)
            return
        }
        busy = true
        let screenTop = NSScreen.screens.first?.frame.maxY ?? 0
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        queue.async { [weak self] in
            let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
            AXUIElementSetMessagingTimeout(dockElement, 0.05)
            var hit: AXUIElement?
            var result: DockTarget?
            if AXUIElementCopyElementAtPosition(dockElement, Float(point.x), Float(screenTop - point.y), &hit) == .success {
                for _ in 0..<5 {
                    guard let item = hit else { break }
                    if attribute(item, kAXRoleAttribute) as? String == "AXDockItem" {
                        if let url = attribute(item, kAXURLAttribute) as? URL,
                           let app = apps.first(where: { $0.bundleURL?.standardizedFileURL == url.standardizedFileURL }),
                           let bounds = windowBounds(item) {
                            result = DockTarget(app: app, frame: CGRect(x: bounds.minX, y: screenTop - bounds.maxY, width: bounds.width, height: bounds.height))
                        }
                        break
                    }
                    guard let parent = attribute(item, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                    hit = (parent as! AXUIElement)
                }
            }
            let target = result
            DispatchQueue.main.async {
                self?.busy = false
                // Discard stale hit tests after the pointer has moved away.
                let now = NSEvent.mouseLocation
                completion(hypot(now.x - point.x, now.y - point.y) < 20 ? target : nil)
            }
        }
    }
}

enum PreviewAction {
    case close, minimize, quit
}
