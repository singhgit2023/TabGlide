import AppKit
import SwiftUI

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ value: String) {
        let value = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else { return nil }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        parts = numbers
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }
    let tag_name: String
    let html_url: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
}

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let releasesURL = URL(string: "https://github.com/singhgit2023/WindowHop/releases")!
    let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    @Published private(set) var checking = false
    @Published private(set) var message = "Check GitHub for the latest version of WindowHop."
    @Published private(set) var downloadURL: URL?
    @Published private(set) var downloadLabel = "Download Update"

    func check(showAlert: Bool = false) {
        guard !checking else { return }
        checking = true
        downloadURL = nil
        message = "Checking for updates…"
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/singhgit2023/WindowHop/releases/latest")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("WindowHop/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                defer {
                    self.checking = false
                    if showAlert { self.presentResult() }
                }
                if let error = error {
                    self.message = "Could not check for updates. \(error.localizedDescription)"
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    self.message = "GitHub returned an invalid response. Please try again."
                    return
                }
                guard response.statusCode == 200 else {
                    switch response.statusCode {
                    case 404: self.message = "No public release is available yet."
                    case 403, 429: self.message = "GitHub is limiting requests. Please try again later."
                    default: self.message = "Could not check for updates (HTTP \(response.statusCode)). Try again later."
                    }
                    return
                }
                guard let data = data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
                      !release.draft, !release.prerelease,
                      let latest = ReleaseVersion(release.tag_name),
                      let installed = ReleaseVersion(self.installedVersion) else {
                    self.message = "Could not compare release versions. Visit GitHub Releases for details."
                    return
                }
                guard latest > installed else {
                    self.message = "You’re up to date. Installed version: \(self.installedVersion)."
                    return
                }
                self.message = "WindowHop \(release.tag_name) is available. You have \(self.installedVersion)."
                #if arch(arm64)
                let suffix = "-macOS-arm64.zip"
                #else
                let suffix = "-macOS-x86_64.zip"
                #endif
                if let asset = release.assets.first(where: {
                    $0.name.hasPrefix("WindowHop-") && $0.name.hasSuffix(suffix) &&
                    Self.isReleaseURL($0.browser_download_url)
                }) {
                    self.downloadURL = asset.browser_download_url
                    self.downloadLabel = "Download Update"
                } else {
                    self.downloadURL = Self.isReleaseURL(release.html_url) ? release.html_url : Self.releasesURL
                    self.downloadLabel = "View Release"
                    self.message += " View the release for compatible downloads or source."
                }
            }
        }.resume()
    }

    private static func isReleaseURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com" &&
        url.path.hasPrefix("/singhgit2023/WindowHop/releases/")
    }

    func openDownload() {
        if let url = downloadURL { NSWorkspace.shared.open(url) }
    }

    private func presentResult() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = downloadURL == nil ? "WindowHop Updates" : "Update Available"
        alert.informativeText = message
        if downloadURL != nil {
            alert.addButton(withTitle: downloadLabel)
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn { openDownload() }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

struct UpdateSettings: View {
    @ObservedObject private var updater = UpdateChecker.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPDATES").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Text("WindowHop \(updater.installedVersion) (\(updater.installedBuild))")
            Text(updater.message).font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button(updater.checking ? "Checking…" : "Check for Updates") { updater.check() }
                    .disabled(updater.checking)
                if updater.downloadURL != nil {
                    Button(updater.downloadLabel) { updater.openDownload() }
                }
                Link("GitHub Releases", destination: UpdateChecker.releasesURL)
            }
            Text("Downloads open in your browser. Install updates manually by replacing WindowHop in Applications.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
