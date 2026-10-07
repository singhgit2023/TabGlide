import SwiftUI
import AppKit

struct WindowPreviewCard: View {
    let window: WindowEntry
    let thumbnail: NSImage?
    let selected: Bool
    var appearance = PreviewAppearance()
    var compact = false
    let choose: () -> Void
    let action: (PreviewAction) -> Void

    var body: some View {
        Group {
        if compact {
            HStack(spacing: 10) {
                Button(action: choose) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: appearance.rounded ? 8 : 0).fill(.black.opacity(0.15))
                            Image(nsImage: thumbnail ?? window.icon).resizable().scaledToFit().padding(4)
                        }.frame(width: 76, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: appearance.rounded ? 8 : 0))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(window.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            HStack(spacing: 5) {
                                Image(nsImage: window.icon).resizable().scaledToFit().frame(width: 16, height: 16)
                                Text(window.minimized ? "Minimized" : window.appName).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help(window.title).accessibilityLabel("Switch to " + window.title)
                if window.browserTab == nil { controls }
            }.frame(height: 54)
        } else {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: choose) {
                    HStack(spacing: 7) {
                        Image(nsImage: window.icon).resizable().scaledToFit().frame(width: 22, height: 22)
                        Text(window.title + " — " + window.appName)
                    }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1).truncationMode(.middle)
                        .padding(.horizontal, 13)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.11), lineWidth: 1))
                        .contentShape(Capsule())
                }.buttonStyle(.plain).help(window.title + " — " + window.appName)

                if window.browserTab == nil { controls }
            }

            Button(action: choose) {
                ZStack {
                    RoundedRectangle(cornerRadius: appearance.rounded ? 18 : 0).fill(Color.black.opacity(0.32))
                    if let thumbnail {
                        Image(nsImage: thumbnail).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            Image(nsImage: window.icon).resizable().frame(width: 52, height: 52)
                            Text(window.minimized ? "Minimized" : window.appName)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: appearance.imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: appearance.rounded ? 18 : 0))
                .overlay(RoundedRectangle(cornerRadius: appearance.rounded ? 18 : 0).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: appearance.rounded ? 18 : 0))
            }.buttonStyle(.plain).accessibilityLabel("Switch to " + window.title)
        }
        }
        }
        .padding(10)
        .frame(maxWidth: compact ? 400 : appearance.width)
        .background(PreviewSurface(appearance: appearance, radius: appearance.radius))
        .overlay(RoundedRectangle(cornerRadius: appearance.radius).strokeBorder(
            selected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.13), lineWidth: selected ? 2 : 1))
        .overlay(RoundedRectangle(cornerRadius: max(0, appearance.radius - 4)).inset(by: 4)
            .strokeBorder(Color.primary.opacity(appearance.material == "Liquid" ? 0.06 : 0), lineWidth: 1))
        .opacity(selected ? 1 : appearance.inactiveOpacity)

    }

    private var controls: some View {
                HStack(spacing: 0) {
                    trafficLight(.red, symbol: "xmark", label: "Close window") { action(.close) }
                    trafficLight(.yellow, symbol: window.minimized ? "plus" : "minus",
                                 label: window.minimized ? "Restore window" : "Minimize window") { action(.minimize) }
                    trafficLight(.green, symbol: "power", label: "Quit " + window.appName + " (all windows)") { action(.quit) }
                }
                .padding(.horizontal, 8).frame(height: 36)
                .background(Capsule().fill(.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.11), lineWidth: 1))
                .disabled(window.element == nil)
    }

    private func trafficLight(_ color: Color, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        TrafficLightButton(color: color, symbol: symbol, label: label,
                           enabled: window.element != nil, action: action)
    }
}

private final class TrafficLightHover: ObservableObject {
    @Published var active = false
}

private struct TrafficLightButton: View {
    let color: Color
    let symbol: String
    let label: String
    let enabled: Bool
    let action: () -> Void
    @StateObject private var hover = TrafficLightHover()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var highlighted: Bool { enabled && hover.active }

    var body: some View {
        Button(action: action) {
            Circle().fill(color.gradient)
                .overlay(Circle().strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
                .overlay(Image(systemName: symbol).font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black.opacity(highlighted ? 0.85 : 0.55)))
                .frame(width: 13, height: 13)
                .scaleEffect(highlighted && !reduceMotion ? 1.18 : 1)
                .shadow(color: color.opacity(highlighted ? 0.5 : 0), radius: 4)
                .frame(width: 25, height: 30)
                .background(Circle().fill(color.opacity(highlighted ? 0.18 : 0)).frame(width: 24, height: 24))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled)
        .help(label).accessibilityLabel(label)
        .onHover { hover.active = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: highlighted)
    }
}
