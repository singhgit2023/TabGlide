import AppKit

enum BrandIcon {
    static let app: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }()

    // A filled pair of tabs, rendered by macOS for the current menu-bar contrast.
    static let menuBar: NSImage = {
        let symbol = NSImage(systemSymbolName: "rectangle.on.rectangle.fill",
                             accessibilityDescription: "TabGlide")!
        let image = symbol.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)) ?? symbol
        image.isTemplate = true
        return image
    }()
}
