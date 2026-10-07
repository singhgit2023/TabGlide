import AppKit
import Combine
import Sparkle
import SwiftUI

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let releasesURL = URL(string: "https://github.com/singhgit2023/WindowHop/releases")!
    let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    let controller: SPUStandardUpdaterController
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var automaticDownloads = false
    @Published private(set) var startupError: String?
    private var started = false

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticChecks)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticDownloads)
    }

    func start() {
        guard !started else { return }
        do {
            try controller.updater.start()
            started = true
            startupError = nil
        } catch {
            startupError = "Updates could not start: \(error.localizedDescription)"
        }
    }

    func check() {
        start()
        NSApp.activate(ignoringOtherApps: true)
        guard started else {
            let alert = NSAlert()
            alert.messageText = "WindowHop Updates"
            alert.informativeText = startupError ?? "Please reopen WindowHop and try again."
            alert.runModal()
            return
        }
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
    }
}

struct UpdateSettings: View {
    @ObservedObject private var updater = UpdateChecker.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPDATES").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Text("WindowHop \(updater.installedVersion) (\(updater.installedBuild))")
            if let error = updater.startupError {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack {
                Button("Check for Updates…") { updater.check() }
                    .disabled(!updater.canCheck && updater.startupError == nil)
                Link("Release history", destination: UpdateChecker.releasesURL)
            }
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updater.automaticChecks }, set: { updater.setAutomaticChecks($0) }))
            Toggle("Automatically download and install updates", isOn: Binding(
                get: { updater.automaticDownloads }, set: { updater.setAutomaticDownloads($0) }))
                .disabled(!updater.automaticChecks)
            Text("Updates are verified before installation. You can install and relaunch here without opening your browser. Automatic installation may wait until you quit the app.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
