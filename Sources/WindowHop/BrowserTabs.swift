import AppKit

struct BrowserTab {
    let bundle: String
    let windowID: Int32
    let tabID: Int32
    let index: Int
    let url: String
}

enum BrowserTabs {
    static let supported = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser"]
    private static let queue = DispatchQueue(label: "TabGlide.browser-tabs", qos: .userInitiated)

    static func load(app: NSRunningApplication, completion: @escaping ([WindowEntry], String) -> Void) {
        guard let bundle = app.bundleIdentifier, supported.contains(bundle), !app.isTerminated else { completion([], "Browser is no longer running."); return }
        queue.async {
            let safari = bundle == "com.apple.Safari"
            let source = """
            with timeout of 8 seconds
                tell application id "\(bundle)"
                    set resultRows to {}
                    repeat with w in windows
                        set n to 0
                        repeat with t in tabs of w
                            set n to n + 1
                            set end of resultRows to {id of w as integer, \(safari ? "n" : "id of t as integer"), n, \(safari ? "name" : "title") of t as text, URL of t as text}
                        end repeat
                    end repeat
                    return resultRows
                end tell
            end timeout
            """
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            var entries: [WindowEntry] = []
            if let result, error == nil, result.numberOfItems > 0 {
                for i in 1...result.numberOfItems {
                    guard let row = result.atIndex(i), let title = row.atIndex(4)?.stringValue, let url = row.atIndex(5)?.stringValue else { continue }
                    let tab = BrowserTab(bundle: bundle, windowID: row.atIndex(1)?.int32Value ?? 0, tabID: row.atIndex(2)?.int32Value ?? 0, index: Int(row.atIndex(3)?.int32Value ?? 0), url: url)
                    entries.append(WindowEntry(element: nil, app: app, title: title, appName: (app.localizedName ?? "Browser") + " · Tab", minimized: false, browserTab: tab))
                }
            }
            let status = error == nil ? "" : "Browser tabs unavailable. Allow TabGlide in System Settings → Privacy & Security → Automation, then reopen the switcher."
            DispatchQueue.main.async { completion(entries, status) }
        }
    }

    static func activate(_ tab: BrowserTab, completion: @escaping (Bool) -> Void) {
        guard supported.contains(tab.bundle), !NSRunningApplication.runningApplications(withBundleIdentifier: tab.bundle).isEmpty else { completion(false); return }
        queue.async {
            let selection: String
            if tab.bundle == "com.apple.Safari" {
                // Safari has no stable tab ID: verify the URL before selecting its captured index.
                let urlLiteral = tab.url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
                selection = "if URL of tab \(tab.index) of w is not \"\(urlLiteral)\" then error \"Tab moved; reopen TabGlide\"\nset current tab of w to tab \(tab.index) of w"
            } else {
                selection = "set foundTab to false\nrepeat with n from 1 to count of tabs of w\nif (id of tab n of w as integer) is \(tab.tabID) then\nset active tab index of w to n\nset foundTab to true\nexit repeat\nend if\nend repeat\nif not foundTab then error \"Tab closed\""
            }
            let source = "with timeout of 8 seconds\ntell application id \"\(tab.bundle)\"\nset w to window id \(tab.windowID)\n\(selection)\nset index of w to 1\nactivate\nend tell\nend timeout"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            let success = error == nil
            DispatchQueue.main.async { completion(success) }
        }
    }
}
