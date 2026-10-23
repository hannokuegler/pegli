import AppKit
import Combine
import SwiftUI

/// Reines AppKit-Gerüst: Statusleisten-Icon, Popover mit der SwiftUI-Ansicht, Kontextmenü.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let monitor = Monitor()
    private let state = PanelState()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    /// Gerundete Prozentwerte des zuletzt gezeichneten Icons.
    private var lastIconKey: [Int]?
    private var escapeMonitor: Any?
    /// Transientes Popover schließt schon beim mouseDown auf das Icon – das folgende mouseUp darf es nicht wieder öffnen.
    private var lastClose = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.launchAtLogin = LoginItem.isEnabled
        wirePanelState()
        setupStatusItem()
        setupPopover()
        observeWorkspace()
        monitor.start()
    }

    // MARK: - Statusleiste

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = StatusIconRenderer.image(cpu: 0, memory: 0, disk: 0)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        monitor.$snapshot
            .sink { [weak self] snapshot in self?.updateIcon(snapshot) }
            .store(in: &cancellables)
    }

    private func updateIcon(_ s: Snapshot) {
        let disk = (s.disks.first(where: \.isBoot) ?? s.disks.first)?.usedFraction ?? 0
        let key = [s.cpu.usage, s.memory.fraction, disk].map { Int(($0 * 100).rounded()) }
        guard key != lastIconKey, let button = statusItem.button else { return }
        lastIconKey = key
        button.image = StatusIconRenderer.image(cpu: s.cpu.usage, memory: s.memory.fraction, disk: disk)
        let text = "CPU \(key[0]) %, Speicher \(key[1]) %, Festplatte \(key[2]) %"
        button.toolTip = text
        button.setAccessibilityLabel("Pegli – \(text)")
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRight {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        if popover.isShown { popover.performClose(nil) }
        let menu = NSMenu()
        let login = NSMenuItem(title: "Beim Anmelden starten", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Pegli beenden", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // Menü nur für diesen Klick anhängen, sonst öffnet auch Linksklick das Menü.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        state.onSetLaunchAtLogin(!LoginItem.isEnabled)
    }

    @objc private func quit() {
        state.onQuit()
    }

    // MARK: - Popover

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(lastClose) > 0.3 {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        // Hosting-Controller nur solange offen → geschlossen kein SwiftUI-Update je Tick.
        let hosting = NSHostingController(rootView: PopoverView(monitor: monitor, state: state))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.contentSize = hosting.view.fittingSize
        popover.behavior = state.isPinned ? .applicationDefined : .transient
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    func popoverWillShow(_ notification: Notification) {
        monitor.detailed = true
        installEscapeMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.detailed = false
        lastClose = Date()
        removeEscapeMonitor()
        popover.contentViewController = nil
    }

    /// Escape schließt das Panel – auch wenn angepinnt.
    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.closePopover() }
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let m = escapeMonitor { NSEvent.removeMonitor(m) }
        escapeMonitor = nil
    }

    // MARK: - PanelState-Aktionen

    private func wirePanelState() {
        state.onTogglePin = { [weak self] in
            guard let self else { return }
            state.isPinned.toggle()
            popover.behavior = state.isPinned ? .applicationDefined : .transient
        }
        state.onClose = { [weak self] in self?.closePopover() }
        state.onQuit = { NSApp.terminate(nil) }
        state.onSetLaunchAtLogin = { [weak self] enabled in
            do {
                if enabled { try LoginItem.enable() } else { try LoginItem.disable() }
            } catch {
                NSLog("Pegli: Autostart konnte nicht geändert werden: \(error.localizedDescription)")
            }
            self?.state.launchAtLogin = LoginItem.isEnabled
        }
        state.onOpenExternal = { [weak self] section in
            self?.openExternal(section)
        }
    }

    private func openExternal(_ section: PanelSection) {
        switch section {
        case .cpu, .memory, .network, .thermal:
            openApp("com.apple.ActivityMonitor")
        case .disk:
            openApp("com.apple.DiskUtility")
        case .battery:
            if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
        if !state.isPinned { closePopover() }
    }

    private func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("Pegli: App \(bundleID) nicht gefunden")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error { NSLog("Pegli: \(bundleID) ließ sich nicht öffnen: \(error.localizedDescription)") }
        }
    }

    // MARK: - System-Ereignisse

    private func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        Publishers.Merge(
            nc.publisher(for: NSWorkspace.didMountNotification),
            nc.publisher(for: NSWorkspace.didUnmountNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.monitor.refreshDisks() }
        .store(in: &cancellables)

        // Nach dem Aufwachen Timer neu aufsetzen (Dispatch-Timer laufen nach Sleep versetzt).
        nc.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.monitor.start() }
            .store(in: &cancellables)
    }
}
