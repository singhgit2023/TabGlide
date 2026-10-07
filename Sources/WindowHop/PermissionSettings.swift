import SwiftUI
import AppKit

struct PermissionSettings: View {
    @ObservedObject var model: SwitcherModel
    let accessibility: () -> Void
    let screenRecording: () -> Void
    let recheck: () -> Void
    let restart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions & status").font(.headline)
            row("Accessibility", status: model.trusted ? "Enabled" : "Not enabled for this app",
                detail: "Required to switch windows and show Dock previews.", enabled: model.trusted,
                action: accessibility)
            if #available(macOS 14.0, *) {
                row("Screen Recording", status: model.screenCaptureAllowed ? "Enabled" : "Not enabled for this app",
                    detail: "Optional. Enables window thumbnails; icons work without it.", enabled: model.screenCaptureAllowed,
                    action: screenRecording)
            }
            HStack {
                Image(systemName: model.shortcutReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(model.shortcutReady ? .mint : .orange)
                Text(model.shortcutReady ? model.shortcut + " is ready" : (model.trusted ? "Access is enabled; shortcut needs reconnecting" : "Shortcut is waiting for Accessibility"))
                    .font(.system(size: 12, weight: .medium))
            }
            HStack {
                Button("Recheck & reconnect", action: recheck)
                Button("Restart TabGlide", action: restart)
            }.buttonStyle(.bordered)
            if let checked = model.permissionsCheckedAt {
                Text("Checked at \(checked.formatted(date: .omitted, time: .standard)). Updates automatically when you return.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            DisclosureGroup("Enabled in Settings, but still not working?") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("First try Recheck, then Restart. If this happened after an update, remove the old TabGlide entry in System Settings, add this copy, and enable it again.")
                    Text("Use Show app in Finder to locate the exact copy that is running. You can drag it into the permission list, or use + to add it.")
                    Button("Show app in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }.buttonStyle(.bordered)
                    Text(Bundle.main.bundlePath).textSelection(.enabled).font(.system(size: 10, design: .monospaced))
                }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 8)
            }.font(.system(size: 12))
            if let error = model.restartError {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange)
            }
        }
    }

    private func row(_ title: String, status: String, detail: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Label(status, systemImage: enabled ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(enabled ? .mint : .orange)
            }
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Button(enabled ? "Open Settings" : "Enable in Settings", action: action).buttonStyle(.bordered)
        }
    }
}
