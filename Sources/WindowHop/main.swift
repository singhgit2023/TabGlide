import AppKit
import SwiftUI
import ApplicationServices
import ScreenCaptureKit

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

struct WindowEntry: Identifiable {
    var id = UUID()
    let element: AXUIElement?
    let app: NSRunningApplication?
    let title: String
    let appName: String
    let minimized: Bool
    var bounds: CGRect? = nil
    var icon: NSImage { app?.icon ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)! }
}

final class SwitcherModel: ObservableObject {
    @Published var appTheme = AppTheme.load() {
        didSet {
            UserDefaults.standard.set(appTheme, forKey: "appTheme")
            applyTheme()
        }
    }
    var colorScheme: ColorScheme? { appTheme == "System" ? nil : (appTheme == "Light" ? .light : .dark) }
    func applyTheme() {
        NSApp.appearance = appTheme == "System" ? nil : NSAppearance(named: appTheme == "Light" ? .aqua : .darkAqua)
    }

    @Published var compactDock = UserDefaults.standard.bool(forKey: "compactDock") {
        didSet { UserDefaults.standard.set(compactDock, forKey: "compactDock") }
    }
    var compactPreview: Bool { dockMode && compactDock }
    @Published var dockAppearance = PreviewAppearance.load("dockAppearance") { didSet { dockAppearance.save("dockAppearance") } }
    @Published var switcherAppearance = PreviewAppearance.load("switcherAppearance") { didSet { switcherAppearance.save("switcherAppearance") } }
    @Published var dockDelay = UserDefaults.standard.object(forKey: "dockDelay") as? Double ?? 0.3 { didSet { UserDefaults.standard.set(dockDelay, forKey: "dockDelay") } }
    @Published var switchDelay = UserDefaults.standard.object(forKey: "switchDelay") as? Double ?? 0.18 { didSet { UserDefaults.standard.set(switchDelay, forKey: "switchDelay") } }
    var appearance: PreviewAppearance { dockMode ? dockAppearance : switcherAppearance }

    @Published var windows: [WindowEntry] = []
    @Published var selected = 0
    @Published var dockMode = false
    @Published var dockAppName = ""
    @Published var dockPreviews = UserDefaults.standard.object(forKey: "dockPreviews") as? Bool ?? true {
        didSet { UserDefaults.standard.set(dockPreviews, forKey: "dockPreviews") }
    }
    @Published var columns = 1
    @Published var thumbnails: [UUID: NSImage] = [:]
    @Published var screenCaptureAllowed = false
    @Published var showPreviews = UserDefaults.standard.object(forKey: "showPreviews") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showPreviews, forKey: "showPreviews") }
    }
    @Published var permissionsCheckedAt: Date?
    @Published var restartError: String?
    @Published var trusted = false
    @Published var shortcutReady = false
    @Published var includeMinimized = UserDefaults.standard.object(forKey: "includeMinimized") as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeMinimized, forKey: "includeMinimized") }
    }
    var selectionFromHover = false
    var lastPointerLocation = NSEvent.mouseLocation
    func hover(_ index: Int) {
        let location = NSEvent.mouseLocation
        guard location != lastPointerLocation else { return }
        lastPointerLocation = location
        selectionFromHover = true
        selected = index
    }
    func step(_ delta: Int) {
        selectionFromHover = false
        guard !windows.isEmpty else { return }
        selected = (selected + delta % windows.count + windows.count) % windows.count
    }
}

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    let choose: (Int) -> Void
    let action: (Int, PreviewAction) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: model.dockMode ? 0 : 20) {
            if !model.dockMode {
            HStack {
                Image(systemName: "rectangle.on.rectangle").foregroundStyle(.mint)
                Text(model.dockMode ? model.dockAppName : "WindowHop").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(model.windows.count) windows").foregroundStyle(.secondary).font(.system(size: 12))
            }
            }
            if model.dockMode && model.windows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "macwindow").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("No windows to show").font(.headline)
                    Text("Move away to dismiss this preview.").font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: model.appearance.spacing), count: model.columns), spacing: model.appearance.spacing) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                            WindowPreviewCard(window: window,
                                thumbnail: model.showPreviews ? model.thumbnails[window.id] : nil,
                                selected: index == model.selected, appearance: model.appearance, compact: model.compactPreview,
                                choose: { choose(index) }, action: { action(index, $0) })
                            .id(index)
                            .onContinuousHover { phase in
                                if case .active = phase { model.hover(index) }
                            }
                        }
                    }.padding(2)
                }
                .onAppear { proxy.scrollTo(model.selected, anchor: .center) }
                .onChange(of: model.selected) { value in if model.selectionFromHover { return }; withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(value, anchor: .center) } }
            }
            }
            if !model.dockMode {
            HStack(spacing: 6) {
                Text("⌥ TAB").foregroundStyle(.primary)
                Text("next").padding(.trailing, 14)
                Text("⇧").foregroundStyle(.primary)
                Text("reverse").padding(.trailing, 14)
                Text("ESC").foregroundStyle(.primary)
                Text("cancel")
                Spacer()
                Text("Release ⌥ to switch").foregroundStyle(.mint)
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(model.dockMode ? 8 : 24).background(PreviewSurface(appearance: model.appearance, radius: model.appearance.rounded ? 24 : 0)).preferredColorScheme(model.colorScheme)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = SwitcherModel()
    var statusItem: NSStatusItem!
    var setupWindow: NSWindow?
    var overlay: NSPanel?
    var eventTap: CFMachPort?
    var eventSource: CFRunLoopSource?
    var timer: Timer?
    var dockTimer: Timer?
    let dockHover = DockHover()
    var dockTarget: DockTarget?
    var dockCandidatePID: pid_t?
    var dockHoverSince = Date.distantPast
    var dockLastInside = Date.distantPast
    var dockCooldownUntil = Date.distantPast
    var revealWork: DispatchWorkItem?
    var previewTask: Task<Void, Never>?
    var pickerSession = UUID()
    var switching = false
    var previewing = false
    var swallowedKeys = Set<Int64>()
    var cachedWindows: [WindowEntry] = []
    let scanQueue = DispatchQueue(label: "WindowHop.windowScan", qos: .userInitiated)
    var scanning = false
    var scanQueued = false
    var recentWindows: [AXUIElement] = []
    var focusObservers: [pid_t: AXObserver] = [:]
    var activationObserver: NSObjectProtocol?
    var pendingFocus: AXUIElement?
    var pendingFocusDeadline = Date.distantPast

    func remember(_ window: AXUIElement) {
        recentWindows.removeAll { CFEqual($0, window) }
        recentWindows.insert(window, at: 0)
        if recentWindows.count > 256 { recentWindows.removeLast() }
    }

    func trackFocusedWindow() {
        guard model.trusted, !switching,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.1)
        guard let value = attribute(element, kAXFocusedWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        let window = value as! AXUIElement
        guard attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole else { return }
        // Ignore the old foreground window while a requested activation is in flight.
        if let pendingFocus, !CFEqual(window, pendingFocus), Date() < pendingFocusDeadline { return }
        pendingFocus = nil
        remember(window)
    }

    func updateFocusObservers() {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        let livePIDs = Set(apps.map(\.processIdentifier))
        for pid in Array(focusObservers.keys) where !livePIDs.contains(pid) {
            if let observer = focusObservers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
        for app in apps where focusObservers[app.processIdentifier] == nil {
            var observer: AXObserver?
            let result = AXObserverCreate(app.processIdentifier, { _, _, _, context in
                guard let context else { return }
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().trackFocusedWindow()
            }, &observer)
            guard result == .success, let observer else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.1)
            let added = AXObserverAddNotification(observer, element, kAXFocusedWindowChangedNotification as CFString,
                                                  Unmanaged.passUnretained(self).toOpaque())
            guard added == .success || added == .notificationAlreadyRegistered else { continue }
            focusObservers[app.processIdentifier] = observer
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    func windowsByRecency() -> [WindowEntry] {
        cachedWindows.enumerated().sorted { left, right in
            let leftRank = left.element.element.flatMap { window in recentWindows.firstIndex { CFEqual($0, window) } } ?? Int.max
            let rightRank = right.element.element.flatMap { window in recentWindows.firstIndex { CFEqual($0, window) } } ?? Int.max
            return leftRank == rightRank ? left.offset < right.offset : leftRank < rightRank
        }.map(\.element)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateChecker.shared.start()
        model.applyTheme()
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BrandIcon.menuBar
        let menu = NSMenu()
        menu.addItem(withTitle: "WindowHop Settings…", action: #selector(showSetup), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preview Switcher", action: #selector(showPreview), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit WindowHop", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.trackFocusedWindow() }
        refreshPermission()
        dockTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in self?.pollDock() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refreshPermission() }
        if !model.shortcutReady || CommandLine.arguments.contains("--setup") { showSetup() }
        if CommandLine.arguments.contains("--preview") { showPreview() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermission()
    }

    func removeTap() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes) }
        eventSource = nil
        eventTap = nil
    }

    func reconnectPermissions() {
        dismiss()
        removeTap()
        swallowedKeys.removeAll()
        refreshPermission()
    }

    func refreshPermission() {
        model.screenCaptureAllowed = CGPreflightScreenCaptureAccess()
        if !model.screenCaptureAllowed || !model.showPreviews {
            previewTask?.cancel()
            model.thumbnails.removeAll()
        }
        model.trusted = AXIsProcessTrusted()
        if !model.trusted { removeTap() }
        if let eventTap, !CFMachPortIsValid(eventTap) { removeTap() }
        if model.trusted && eventTap == nil { installTap() }
        if model.trusted, let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        model.shortcutReady = model.trusted && (eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false)
        model.permissionsCheckedAt = Date()
        if !model.trusted && switching { dismiss() }
        if model.trusted {
            updateFocusObservers()
            trackFocusedWindow()
            refreshWindows()
        }
    }

    func refreshWindows() {
        guard !scanning else { scanQueued = true; return }
        scanning = true
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        let includeMinimized = model.includeMinimized
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        scanQueue.async { [weak self] in
            var entries: [WindowEntry] = []
            for app in apps {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(appElement, 0.15)
                let focused = attribute(appElement, kAXFocusedWindowAttribute)
                guard let windows = attribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else { continue }
                var appEntries: [WindowEntry] = []
                for window in windows {
                    guard (attribute(window, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole else { continue }
                    let minimized = attribute(window, kAXMinimizedAttribute) as? Bool ?? false
                    if minimized && !includeMinimized { continue }
                    let title = attribute(window, kAXTitleAttribute) as? String ?? ""
                    let entry = WindowEntry(element: window, app: app, title: title.isEmpty ? (app.localizedName ?? "Untitled window") : title, appName: app.localizedName ?? "Application", minimized: minimized, bounds: windowBounds(window))
                    if let focused, CFEqual(window, focused) { appEntries.insert(entry, at: 0) } else { appEntries.append(entry) }
                }
                if app.processIdentifier == frontPID { entries.insert(contentsOf: appEntries, at: 0) } else { entries.append(contentsOf: appEntries) }
            }
            let result = entries
            DispatchQueue.main.async {
                guard let self else { return }
                self.cachedWindows = result.map { entry in
                    var stable = entry
                    if let element = entry.element,
                       let previous = self.cachedWindows.first(where: { $0.element.map { CFEqual($0, element) } ?? false }) {
                        stable.id = previous.id
                    }
                    return stable
                }
                self.scanning = false
                self.refreshDockCards()
                if self.scanQueued {
                    self.scanQueued = false
                    self.refreshWindows()
                }
            }
        }
    }

    func installTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            return owner.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap else { return }
        eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            dismiss()
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return false
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp { return swallowedKeys.remove(key) != nil }
        if type == .flagsChanged {
            if switching && !previewing && !model.dockMode && !event.flags.contains(.maskAlternate) { commit() }
            return false
        }
        guard type == .keyDown else { return false }
        if key == 48 && event.flags.contains(.maskAlternate) && !event.flags.contains(.maskCommand) && !event.flags.contains(.maskControl) {
            if model.dockMode { dismiss() }
            if !switching {
                guard !cachedWindows.isEmpty else { return false }
                model.windows = windowsByRecency()
                model.selected = 0
                previewing = false
                switching = true
                model.step(event.flags.contains(.maskShift) ? -1 : 1)
                pickerSession = UUID()
                let session = pickerSession
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.switching, self.pickerSession == session else { return }
                    self.showOverlay()
                }
                revealWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + model.switchDelay, execute: work)
            } else { model.step(event.flags.contains(.maskShift) ? -1 : 1) }
            swallowedKeys.insert(key)
            return true
        }
        if model.dockMode && key == 53 {
            dismiss()
            swallowedKeys.insert(key)
            return true
        }
        if switching && !model.dockMode {
            if [123, 124, 125, 126].contains(key), overlay?.isVisible != true { showOverlay() }
            switch key {
            case 53: dismiss()
            case 36, 76: commit()
            case 123: model.step(-1)
            case 124: model.step(1)
            case 126: model.step(-model.columns)
            case 125: model.step(model.columns)
            default: return false
            }
            swallowedKeys.insert(key)
            return true
        }
        return false
    }

    func showOverlay() {
        revealWork?.cancel()
        revealWork = nil
        model.lastPointerLocation = NSEvent.mouseLocation
        model.selectionFromHover = false
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main!
        // Larger thumbnail cards wrap after five columns, or earlier on smaller screens.
        let availableWidth = min(CGFloat(1600), screen.visibleFrame.width - 48)
        let appearance = model.appearance
        let compact = model.compactPreview
        let outerWidth: CGFloat = model.dockMode ? 20 : 52
        let stride = (compact ? 400 : appearance.width) + appearance.spacing
        let maxColumns = max(1, min(Int(appearance.columns), Int((availableWidth - outerWidth + appearance.spacing) / stride)))
        model.columns = compact ? 1 : min(maxColumns, max(1, model.windows.count))
        let cardsWidth = CGFloat(model.columns) * stride - appearance.spacing + outerWidth
        let width = min(availableWidth, model.dockMode ? cardsWidth : max(560, cardsWidth))
        let rows = (max(1, model.windows.count) + model.columns - 1) / model.columns
        let contentHeight = CGFloat(rows) * ((compact ? 74 : appearance.imageHeight + 66) + appearance.spacing) - appearance.spacing + 4
        let height = min(model.dockMode ? (model.windows.isEmpty ? 160 : contentHeight + 16) : contentHeight + 124, screen.visibleFrame.height - 64)
        if overlay == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.acceptsMouseMovedEvents = true
            panel.isReleasedWhenClosed = false
            overlay = panel
        }
        overlay?.contentView = NSHostingView(rootView: SwitcherView(model: model,
            choose: { [weak self] index in self?.model.selected = index; self?.commit() },
            action: { [weak self] index, action in self?.performPreviewAction(index, action) }))
        overlay?.contentView?.wantsLayer = true
        overlay?.contentView?.layer?.cornerRadius = appearance.rounded ? 24 : 0
        overlay?.contentView?.layer?.masksToBounds = true
        var frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.midY - height / 2, width: width, height: height)
        if model.dockMode, let target = dockTarget {
            let icon = target.frame
            let bottomDistance = abs(icon.minY - screen.frame.minY)
            let leftDistance = abs(icon.minX - screen.frame.minX)
            let rightDistance = abs(screen.frame.maxX - icon.maxX)
            if leftDistance < bottomDistance && leftDistance < rightDistance {
                frame.origin = CGPoint(x: icon.maxX + 10, y: icon.midY - height / 2)
            } else if rightDistance < bottomDistance && rightDistance < leftDistance {
                frame.origin = CGPoint(x: icon.minX - width - 10, y: icon.midY - height / 2)
            } else {
                frame.origin = CGPoint(x: icon.midX - width / 2, y: icon.maxY + 10)
            }
            frame.origin.x = min(max(frame.minX, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
            frame.origin.y = min(max(frame.minY, screen.visibleFrame.minY + 8), screen.visibleFrame.maxY - height - 8)
        }
        overlay?.setFrame(frame, display: true)
        // Animate the content, keeping the panel's hit area fixed above the Dock.
        // Layer animations disappear with the old content view on a rapid re-hover.
        if model.dockMode && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
           let layer = overlay?.contentView?.layer {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.18
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(fade, forKey: "dockPreviewOpening")
        }
        overlay?.orderFrontRegardless()
        startPreviews()
    }

    func pollDock() {
        guard model.trusted, model.dockPreviews else {
            if model.dockMode { dismiss() }
            return
        }
        guard (!switching || model.dockMode), Date() >= dockCooldownUntil else { return }
        let point = NSEvent.mouseLocation
        if model.dockMode, overlay?.frame.contains(point) == true {
            dockLastInside = Date()
            return
        }
        if NSEvent.pressedMouseButtons != 0 { return }
        dockHover.target(at: point) { [weak self] target in
            guard let self, self.model.dockPreviews, (!self.switching || self.model.dockMode), Date() >= self.dockCooldownUntil else { return }
            guard let target, target.app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                self.dockCandidatePID = nil
                if self.model.dockMode && Date().timeIntervalSince(self.dockLastInside) > 0.5 { self.dismiss() }
                return
            }
            self.dockLastInside = Date()
            if self.model.dockMode && self.dockTarget?.app.processIdentifier == target.app.processIdentifier { return }
            if self.dockCandidatePID != target.app.processIdentifier {
                self.dockCandidatePID = target.app.processIdentifier
                self.dockHoverSince = Date()
                return
            }
            guard Date().timeIntervalSince(self.dockHoverSince) >= self.model.dockDelay else { return }
            let windows = self.windowsByRecency().filter { $0.app?.processIdentifier == target.app.processIdentifier }
            guard !windows.isEmpty else {
                if self.model.dockMode { self.dismiss() }
                return
            }
            self.dismiss()
            self.dockTarget = target
            self.dockLastInside = Date()
            self.model.dockMode = true
            self.model.dockAppName = target.app.localizedName ?? "Application"
            self.model.windows = windows
            self.model.selected = 0
            self.switching = true
            self.showOverlay()
        }
    }

    func refreshDockCards() {
        guard model.dockMode, let target = dockTarget else { return }
        let latest = target.app.isTerminated ? [] : cachedWindows.filter { $0.app?.processIdentifier == target.app.processIdentifier }
        // Preserve card order, identity, selection and panel geometry under the pointer.
        let selectedID = model.windows.indices.contains(model.selected) ? model.windows[model.selected].id : nil
        let oldIDs = Set(model.windows.map(\.id))
        let updated = model.windows.compactMap { old in latest.first { $0.id == old.id } }
            + latest.filter { !oldIDs.contains($0.id) }
        model.windows = updated
        model.selected = selectedID.flatMap { id in updated.firstIndex { $0.id == id } }
            ?? min(model.selected, max(0, updated.count - 1))
        let previewIDs = Set(updated.filter { !$0.minimized }.map(\.id))
        model.thumbnails = model.thumbnails.filter { previewIDs.contains($0.key) }
    }

    func performPreviewAction(_ index: Int, _ action: PreviewAction) {
        guard !previewing, model.windows.indices.contains(index),
              let window = model.windows[index].element,
              let app = model.windows[index].app, !app.isTerminated else { return }
        let entry = model.windows[index]
        // Dock previews stay visible; keyboard pickers dismiss to avoid an Option-release switch.
        if model.dockMode { dockLastInside = Date() } else { dismiss() }
        DispatchQueue.main.async { [weak self] in
            var succeeded = false
            switch action {
            case .close:
                if let value = attribute(window, kAXCloseButtonAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() {
                    succeeded = AXUIElementPerformAction(value as! AXUIElement, kAXPressAction as CFString) == .success
                    if succeeded { app.activate(options: [.activateIgnoringOtherApps]) }
                }
            case .minimize:
                succeeded = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString,
                                                         entry.minimized ? kCFBooleanFalse : kCFBooleanTrue) == .success
            case .quit:
                // Normal termination lets the target app present unsaved-document prompts.
                app.activate(options: [.activateIgnoringOtherApps])
                succeeded = app.terminate()
            }
            if !succeeded { NSSound.beep() }
            self?.refreshWindows()
        }
    }

    func startPreviews() {
        previewTask?.cancel()
        guard #available(macOS 14.0, *), !previewing, model.showPreviews,
              CGPreflightScreenCaptureAccess() else { return }
        let session = pickerSession
        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.switching && self.pickerSession == session {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                    guard !Task.isCancelled else { return }
                    let selectedID = self.model.windows.indices.contains(self.model.selected) ? self.model.windows[self.model.selected].id : nil
                    let entries = self.model.windows
                    let ordered = entries.filter { $0.id == selectedID } + entries.filter { $0.id != selectedID }
                    for entry in ordered {
                        guard !Task.isCancelled, self.switching, self.pickerSession == session,
                              self.model.showPreviews, CGPreflightScreenCaptureAccess() else { return }
                        guard let window = WindowPreviews.match(entry, in: content.windows) else { continue }
                        if let image = try? await WindowPreviews.image(for: window) {
                            guard !Task.isCancelled, self.pickerSession == session else { return }
                            if self.model.windows.contains(where: { $0.id == entry.id && !$0.minimized }) {
                                self.model.thumbnails[entry.id] = image
                            }
                        }
                    }
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch { return } // Permission denial or unavailable content keeps the icon fallback.
            }
        }
    }

    func dismiss() {
        revealWork?.cancel()
        revealWork = nil
        previewTask?.cancel()
        previewTask = nil
        pickerSession = UUID()
        model.thumbnails.removeAll()
        overlay?.orderOut(nil)
        switching = false
        previewing = false
        model.dockMode = false
        dockTarget = nil
        dockCandidatePID = nil
        dockCooldownUntil = Date().addingTimeInterval(0.6)
    }
    func commit() {
        guard switching, model.windows.indices.contains(model.selected) else { dismiss(); return }
        let entry = model.windows[model.selected]
        let wasPreview = previewing
        dismiss()
        guard !wasPreview, let window = entry.element, let app = entry.app, !app.isTerminated else { return }
        // Update immediately so rapid Option+Tab presses can alternate without waiting for a scan.
        remember(window)
        pendingFocus = window
        pendingFocusDeadline = Date().addingTimeInterval(0.75)
        // Return from the event-tap callback before sending messages to other apps.
        DispatchQueue.main.async { [weak self] in
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            app.activate(options: [.activateIgnoringOtherApps])
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            self?.refreshWindows()
        }
    }
    @objc func showPreview() {
        dismiss()
        model.windows = [WindowEntry(element: nil, app: nil, title: "Project workspace", appName: "Editor", minimized: false), WindowEntry(element: nil, app: nil, title: "A little inspiration", appName: "Browser", minimized: false), WindowEntry(element: nil, app: nil, title: "Everything in its place", appName: "Finder", minimized: true)]
        model.selected = 1
        previewing = true
        switching = true
        showOverlay()
        let session = pickerSession
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            if self?.previewing == true && self?.pickerSession == session { self?.dismiss() }
        }
    }
    @objc func showSetup() {
        refreshPermission()
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: min(800, (NSScreen.main?.visibleFrame.height ?? 900) - 80)), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "WindowHop Settings"
            window.minSize = NSSize(width: 900, height: 620)
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(model: model, grant: { [weak self] in self?.grantAccess() }, grantPreviews: { [weak self] in self?.grantPreviewAccess() }, recheck: { [weak self] in self?.reconnectPermissions() }, restart: { [weak self] in self?.restartApp() }, preview: { [weak self] in self?.showPreview() }))
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }
    func grantAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrusted() { _ = AXIsProcessTrustedWithOptions(options) }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func grantPreviewAccess() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        refreshPermission()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    func restartApp() {
        model.restartError = nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--setup"]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                if app != nil {
                    self?.dismiss()
                    self?.removeTap()
                    NSApp.terminate(nil)
                } else {
                    self?.model.restartError = "Could not restart. Quit and reopen WindowHop. " + (error?.localizedDescription ?? "")
                }
            }
        }
    }
    @objc func checkForUpdates() { UpdateChecker.shared.check() }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
