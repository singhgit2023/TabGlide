import SwiftUI

private final class ListReveal: ObservableObject {
    @Published var visible = false
}

struct ListSwitcher: View {
    @ObservedObject var model: SwitcherModel
    let choose: (Int) -> Void
    let settings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var reveal = ListReveal()

    private var sideAttached: Bool { ["Left", "Right"].contains(model.switcherPlacement) }
    private var notchAttached: Bool { model.switcherPlacement == "From Notch" }

    var body: some View {
        GeometryReader { geometry in
            panel
                .offset(x: reveal.visible ? 0 : model.switcherPlacement == "Left" ? -geometry.size.width : model.switcherPlacement == "Right" ? geometry.size.width : 0,
                        y: reveal.visible ? 0 : notchAttached ? -geometry.size.height : sideAttached ? 0 : 12)
                .opacity(reveal.visible ? 1 : 0)
                .onAppear {
                    withAnimation(reduceMotion ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.32)) {
                        reveal.visible = true
                    }
                }
        }.clipped()
    }

    private var panel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("TabGlide").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.modifierLabel + " TAB").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }.padding(.horizontal, 10).padding(.top, 8)
            SwitcherSearch(model: model)
            ScrollViewReader { proxy in
                ScrollView(notchAttached ? .horizontal : .vertical, showsIndicators: false) {
                    (notchAttached ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 4))) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                            Button { choose(index) } label: {
                                HStack(spacing: 10) {
                                    Image(nsImage: window.icon).resizable().scaledToFit().frame(width: 30, height: 30)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(window.appName).font(.system(size: 12, weight: .semibold))
                                        Text(window.title).font(.system(size: 11)).foregroundStyle(.secondary)
                                    }.lineLimit(1).truncationMode(.tail)
                                    Spacer(minLength: 0)
                                    if window.minimized {
                                        Image(systemName: "minus.rectangle").font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10).frame(width: notchAttached ? 210 : nil, height: notchAttached ? 82 : 52)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index == model.selected ? Color.primary.opacity(0.14) : .clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain).help(window.appName + " — " + window.title)
                                .accessibilityAddTraits(index == model.selected ? [.isSelected] : [])
                                .id(index)
                                .onContinuousHover { phase in
                                    if case .active = phase { model.hover(index) }
                                }
                        }
                    }.padding(2)
                }
                .onAppear { proxy.scrollTo(model.selected, anchor: .center) }
                .onChange(of: model.selected) { value in
                    guard !model.selectionFromHover else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { proxy.scrollTo(value, anchor: .center) }
                }
            }
            HStack {
                Text(model.searching ? "Enter to switch" : "Release " + model.modifierLabel + " to switch").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(action: settings) { Image(systemName: "gearshape.fill").font(.system(size: 13)).frame(width: 28, height: 24) }
                    .buttonStyle(.plain).help("Open TabGlide Settings").accessibilityLabel("Open TabGlide Settings")
            }.padding(.horizontal, 10)
        }
        .padding(10)
        .padding(.vertical, sideAttached ? 20 : 0)
        .padding(.horizontal, notchAttached ? 20 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PreviewSurface(appearance: model.switcherAppearance, radius: 0)
            .clipShape(ConnectedPanelShape(placement: model.switcherPlacement, rounded: model.switcherAppearance.rounded)))
        .overlay(ConnectedPanelShape(placement: model.switcherPlacement, rounded: model.switcherAppearance.rounded)
            .stroke(Color.primary.opacity(0.12), lineWidth: 1).allowsHitTesting(false))
        .preferredColorScheme(model.colorScheme)
    }
}

struct SwitcherPlacementPicker: View {
    @Binding var placement: String
    var body: some View {
        HStack(spacing: 10) {
            ForEach(["Left", "Center", "Right", "From Notch"], id: \.self) { value in
                Button { placement = value } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: value == "Left" ? .leading : value == "Right" ? .trailing : value == "From Notch" ? .top : .center) {
                            RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 4).fill(placement == value ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: 19, height: 32).padding(value == "From Notch" ? .top : .horizontal, 4)
                        }.frame(height: 56)
                        Text(value).font(.system(size: 11, weight: .medium))
                    }.padding(9).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(placement == value ? Color.accentColor : Color.primary.opacity(0.12)))
                }.buttonStyle(.plain).accessibilityAddTraits(placement == value ? [.isSelected] : [])
            }
        }
    }
}

/// Concave shoulders connect the panel to an edge; the exposed corners remain convex.
struct ConnectedPanelShape: Shape {
    let placement: String
    let rounded: Bool

    func path(in rect: CGRect) -> Path {
        guard placement != "Center" else {
            return Path(roundedRect: rect, cornerRadius: rounded ? 24 : 0)
        }
        let top = placement == "From Notch"
        let w = top ? rect.height : rect.width
        let h = top ? rect.width : rect.height
        let shoulder: CGFloat = min(20, h / 4)
        let r: CGFloat = rounded ? min(28, w / 3, (h - 2 * shoulder) / 3) : 0
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: shoulder, y: shoulder), control: CGPoint(x: 0, y: shoulder))
        p.addLine(to: CGPoint(x: w - r, y: shoulder))
        p.addQuadCurve(to: CGPoint(x: w, y: shoulder + r), control: CGPoint(x: w, y: shoulder))
        p.addLine(to: CGPoint(x: w, y: h - shoulder - r))
        p.addQuadCurve(to: CGPoint(x: w - r, y: h - shoulder), control: CGPoint(x: w, y: h - shoulder))
        p.addLine(to: CGPoint(x: shoulder, y: h - shoulder))
        p.addQuadCurve(to: CGPoint(x: 0, y: h), control: CGPoint(x: 0, y: h - shoulder))
        p.closeSubpath()
        let transform: CGAffineTransform
        if top {
            transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: rect.minX, ty: rect.minY)
        } else if placement == "Right" {
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.maxX, ty: rect.minY)
        } else {
            transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        }
        return p.applying(transform)
    }
}
