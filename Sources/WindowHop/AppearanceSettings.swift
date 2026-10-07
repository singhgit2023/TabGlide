import SwiftUI

enum AppTheme {
    static func load() -> String {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "appTheme"), ["System", "Light", "Dark"].contains(saved) { return saved }
        // Migrate the former switcher preference to one shared app theme.
        for key in ["switcherAppearance", "dockAppearance"] {
            if let data = defaults.data(forKey: key),
               let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let theme = settings["theme"] as? String, ["System", "Light", "Dark"].contains(theme) {
                defaults.set(theme, forKey: "appTheme")
                return theme
            }
        }
        return "System"
    }
}

struct PreviewAppearance: Codable, Equatable {
    var material = "Liquid"
    var opacity = 0.65
    var rounded = true
    var width = 300.0
    var height = 174.0
    var lockAspect = true
    var spacing = 12.0
    var inactiveOpacity = 0.85
    var columns = 5.0
    var imageHeight: Double { lockAspect ? (width - 20) / 1.6 : height }
    var radius: CGFloat { rounded ? 27 : 0 }
    static func load(_ key: String) -> Self {
        guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save(_ key: String) { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: key) } }
}

struct PreviewSurface: View {
    let appearance: PreviewAppearance
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        ZStack {
            if appearance.material == "Liquid" {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(colors: [Color.purple.opacity(0.17 * appearance.opacity), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else if appearance.material == "Frosted" {
                shape.fill(.regularMaterial)
            }
            shape.fill((scheme == .dark ? Color.black : Color.white).opacity(appearance.opacity * (appearance.material == "Clear" ? 0.7 : 0.32)))
        }
    }
}

private final class SettingsNavigation: ObservableObject {
    @Published var page = "General"
    @Published var search = ""
}

struct SetupView: View {
    @ObservedObject var model: SwitcherModel
    let grant: () -> Void
    let grantPreviews: () -> Void
    let recheck: () -> Void
    let restart: () -> Void
    let preview: () -> Void
    @StateObject private var navigation = SettingsNavigation()
    private let pages = [("General", "gearshape", "permissions accessibility recording status appearance theme light dark system"),
                         ("Dock Previews", "dock.rectangle", "appearance liquid frosted clear rounded size hover"),
                         ("Window Switcher", "rectangle.split.2x2", "appearance liquid frosted clear rounded size shortcut delay")]
    private var dock: Bool { navigation.page == "Dock Previews" }
    private var appearance: Binding<PreviewAppearance> { dock ? $model.dockAppearance : $model.switcherAppearance }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image(nsImage: BrandIcon.app)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .accessibilityHidden(true)
                    Text("WindowHop").font(.system(size: 18, weight: .semibold))
                }.padding(.top, 14)
                TextField("Search settings…", text: $navigation.search).textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 6) {
                    Text("SETTINGS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10)
                    ForEach(pages.filter { navigation.search.isEmpty || ($0.0 + " " + $0.2).localizedCaseInsensitiveContains(navigation.search) }, id: \.0) { page in
                        Button { navigation.page = page.0 } label: {
                            Label(page.0, systemImage: page.1).font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(11)
                                .background(navigation.page == page.0 ? Color.accentColor.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                Text("WindowHop · Settings save automatically").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(18).frame(width: 220).frame(maxHeight: .infinity).background(.bar)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(navigation.page).font(.system(size: 27, weight: .bold))
                        Text(navigation.page == "General" ? "Permissions and shared preferences." : "Behavior and appearance, just the way you like it.")
                            .foregroundStyle(.secondary).font(.system(size: 13))
                    }
                    if navigation.page == "General" {
                        UpdateSettings()
                        Divider()
                        sectionTitle("APP APPEARANCE")
                        Picker("Appearance", selection: $model.appTheme) {
                            ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented)
                        Text("Applies to Settings, Dock Previews, and Window Switcher.").font(.system(size: 12)).foregroundStyle(.secondary)
                        Divider()
                        PermissionSettings(model: model, accessibility: grant, screenRecording: grantPreviews, recheck: recheck, restart: restart)
                        Divider()
                        sectionTitle("WINDOWS & PRIVACY")
                        Toggle("Include minimized windows", isOn: $model.includeMinimized)
                        Toggle("Enable thumbnail capture", isOn: $model.showPreviews)
                        Text("Thumbnails require Screen Recording access and macOS 14 or later. Previews stay in memory; nothing is uploaded.").font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                        sectionTitle("BEHAVIOR")
                        if dock {
                            Toggle("Show previews when hovering over Dock icons", isOn: $model.dockPreviews)
                            settingSlider("Hover delay", value: $model.dockDelay, range: 0.1...1, step: 0.05, suffix: "s")
                            Text("Click a thumbnail to switch. Close, minimize and quit keep the panel open.").font(.system(size: 12)).foregroundStyle(.secondary)
                        } else {
                            settingSlider("Quick-switch delay", value: $model.switchDelay, range: 0...0.6, step: 0.02, suffix: "s")
                            Text("Option + Tab switches to the previous window. Hold Option to show the picker; Shift reverses direction. Set delay to zero to show it immediately.").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Divider()
                        AppearanceControls(appearance: appearance)
                        Divider()
                        sectionTitle("PREVIEW")
                        AppearancePreviewGrid(appearance: appearance.wrappedValue)
                        Text("Six sample windows, scaled to fit. Click a card to compare selected and unselected styles.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        HStack {
                            Button("Preview switcher", action: preview)
                            Spacer()
                            Button("Reset appearance") { appearance.wrappedValue = PreviewAppearance() }
                        }
                    }
                }.padding(32).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 900, minHeight: 620).preferredColorScheme(model.colorScheme)
    }
}

private final class PreviewSelection: ObservableObject {
    @Published var index = 0
}

private struct AppearancePreviewGrid: View {
    let appearance: PreviewAppearance
    @StateObject private var selection = PreviewSelection()
    private let samples = [
        ("Project workspace", "Editor"), ("A little inspiration", "Browser"),
        ("Documents", "Finder"), ("Today's notes", "Notes"),
        ("Your favorite playlist", "Music"), ("Team conversation", "Messages")
    ]
    private var columns: Int { max(1, min(6, Int(appearance.columns))) }
    private var sceneWidth: Double { Double(columns) * appearance.width + Double(columns - 1) * appearance.spacing + 24 }
    private var sceneHeight: Double {
        let rows = (samples.count + columns - 1) / columns
        return Double(rows) * (appearance.imageHeight + 66) + Double(rows - 1) * appearance.spacing + 24
    }
    var body: some View {
        GeometryReader { geometry in
            let scale = min(1, geometry.size.width / sceneWidth)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(appearance.width), spacing: appearance.spacing), count: columns), spacing: appearance.spacing) {
                ForEach(samples.indices, id: \.self) { index in
                    WindowPreviewCard(window: WindowEntry(element: nil, app: nil, title: samples[index].0, appName: samples[index].1, minimized: false),
                                      thumbnail: nil, selected: selection.index == index, appearance: appearance,
                                      choose: { selection.index = index }, action: { _ in })
                }
            }
            .padding(12)
            .frame(width: sceneWidth, height: sceneHeight, alignment: .topLeading)
            .background(PreviewSurface(appearance: appearance, radius: appearance.rounded ? 24 : 0))
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(sceneWidth / sceneHeight, contentMode: .fit)
        .frame(maxWidth: sceneWidth)
    }
}

private struct AppearanceControls: View {
    @Binding var appearance: PreviewAppearance
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("WINDOW PREVIEW SIZE")
            Toggle("Lock aspect ratio (16:10)", isOn: $appearance.lockAspect)
            settingSlider("Preview width", value: $appearance.width, range: 260...460, step: 10, suffix: "px")
            settingSlider("Preview height", value: appearance.lockAspect ? .constant(appearance.imageHeight) : $appearance.height, range: 120...280, step: 10, suffix: "px").disabled(appearance.lockAspect)
            Text("Images keep their original proportions and fit inside the preview.").font(.system(size: 12)).foregroundStyle(.secondary)
            settingSlider("Maximum columns", value: $appearance.columns, range: 1...6, step: 1, suffix: "")
            Divider()
            sectionTitle("BACKGROUND")
            Picker("Style", selection: $appearance.material) {
                ForEach(["Liquid", "Frosted", "Clear"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            settingSlider("Opacity", value: $appearance.opacity, range: 0.15...1, step: 0.05, suffix: "×")
            Divider()
            sectionTitle("GENERAL APPEARANCE")
            settingSlider("Card spacing", value: $appearance.spacing, range: 6...24, step: 1, suffix: "px")
            settingSlider("Unselected opacity", value: $appearance.inactiveOpacity, range: 0.4...1, step: 0.05, suffix: "×")
            Toggle("Rounded corners", isOn: $appearance.rounded)
        }
    }
}

private func sectionTitle(_ title: String) -> some View {
    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
}

private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title).font(.system(size: 13))
        HStack(spacing: 14) {
            Slider(value: value, in: range, step: step)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(step < 1 ? 2 : 0))) + " " + suffix)
                .font(.system(size: 12, design: .monospaced)).monospacedDigit().frame(width: 76)
                .padding(6).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
