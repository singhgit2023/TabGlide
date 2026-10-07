import SwiftUI

private final class OnboardingProgress: ObservableObject {
    @Published var step = 0
}

struct SearchHotkeyPicker: View {
    @ObservedObject var model: SwitcherModel
    var body: some View {
        Picker("Search Mode hotkey", selection: $model.searchHotkey) {
            ForEach(["Shift + Command + L", "Option + Command + Space", "Control + Option + Space", "Disabled"], id: \.self) { Text($0).tag($0) }
        }
        Text("Opens directly into search from any app. Release the keys and type; Enter opens a result, Escape closes. Choose another shortcut if an app already uses it.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: SwitcherModel
    let grant: () -> Void
    let previews: () -> Void
    let recheck: () -> Void
    let restart: () -> Void
    let finish: () -> Void
    @StateObject private var progress = OnboardingProgress()
    private let titles = ["Welcome to TabGlide", "Find your next window", "Make it your own", "A shortcut straight to search", "Give TabGlide access", "You’re ready to glide"]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("TABGLIDE / GET STARTED").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(progress.step + 1) of 6").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 24) {
                    if progress.step == 0 || progress.step == 5 {
                        Image(nsImage: BrandIcon.app).resizable().scaledToFit().frame(width: 112, height: 112)
                    } else {
                        Image(systemName: ["", "magnifyingglass", "keyboard", "sparkle.magnifyingglass", "lock.shield", ""][progress.step])
                            .font(.system(size: 48)).foregroundStyle(.blue).frame(height: 80)
                    }
                    Text(titles[progress.step]).font(.system(size: 30, weight: .bold))
                    content.frame(maxWidth: 600)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            HStack {
                if progress.step > 0 { Button("← Back") { progress.step -= 1 }.buttonStyle(.plain) }
                Spacer()
                HStack(spacing: 6) { ForEach(0..<6) { i in Circle().fill(i == progress.step ? Color.blue : Color.secondary.opacity(0.25)).frame(width: 6, height: 6) } }
                Spacer()
                Button(progress.step == 0 ? "Get Started" : progress.step == 5 ? "Start using TabGlide" : "Continue") {
                    if progress.step == 5 { finish() } else { progress.step += 1 }
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
        }.padding(36).frame(minWidth: 720, minHeight: 560)
            .background(LinearGradient(colors: [Color.blue.opacity(0.08), Color(nsColor: .windowBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .preferredColorScheme(model.colorScheme)
    }

    @ViewBuilder private var content: some View {
        switch progress.step {
        case 0:
            Text("Less hunting. More doing.").font(.title2).foregroundStyle(.blue)
            Text("Move between windows, preview your Dock, and find browser tabs from one place. Your window titles and tab URLs stay on your Mac.").multilineTextAlignment(.center).foregroundStyle(.secondary)
        case 1:
            Text("Search by app name, window title, or tab URL. Hold your switcher shortcut to browse, or use Search Mode to start typing immediately.").multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                Label("Search windows & tabs…", systemImage: "magnifyingglass").foregroundStyle(.secondary)
                Divider()
                Label("Safari · Weekend inspiration", systemImage: "safari")
                Label("Notes · Ideas for the next project", systemImage: "note.text")
                Label("Finder · Downloads", systemImage: "folder")
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        case 2:
            Picker("Window switcher shortcut", selection: $model.shortcut) {
                ForEach(["Option + Tab", "Command + Tab", "Control + Tab"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            Text("Command + Tab replaces the native app switcher while TabGlide runs. Hold Shift to cycle backward.").font(.caption).foregroundStyle(.secondary)
            Picker("Layout", selection: $model.switcherStyle) { Text("Window cards").tag("Cards"); Text("Compact list").tag("List") }.pickerStyle(.segmented)
            if model.switcherStyle == "List" { SwitcherPlacementPicker(placement: $model.switcherPlacement) }
        case 3:
            SearchHotkeyPicker(model: model)
            Toggle("Include browser tabs", isOn: $model.browserTabsEnabled)
            Text("Search Mode includes tabs from all running supported browsers. Regular switching puts the frontmost browser’s tabs first. Safari, Chrome, Edge and Brave are supported; each needs Automation permission on first use.").font(.caption).foregroundStyle(.secondary)
        case 4:
            PermissionSettings(model: model, accessibility: grant, screenRecording: previews, recheck: recheck, restart: restart)
            Text("You can finish now and enable permissions later from Settings.").font(.caption).foregroundStyle(.secondary)
        default:
            Text("Switch windows: \(model.shortcut)\nSearch everywhere: \(model.searchHotkey)").font(.title3).multilineTextAlignment(.center)
            Text("Find Settings, Search, and this onboarding guide in the TabGlide menu-bar menu. Customize colors, Dock previews, and placement any time.").multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}
