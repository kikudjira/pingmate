import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var transitionTimer: Timer?

    let pingService: PingService
    let settingsStorage: SettingsStorage
    private let iconGenerator = IconGenerator()
    private var monitorWindowController: MonitorWindowController?
    private var settingsWindowController: SettingsWindowController?

    override init() {
        self.settingsStorage = SettingsStorage()
        self.pingService = PingService(settings: settingsStorage.settings)

        super.init()

        self.monitorWindowController = MonitorWindowController(
            pingService: pingService,
            settingsStorage: settingsStorage
        )
        self.settingsWindowController = SettingsWindowController(
            settingsStorage: settingsStorage,
            pingService: pingService
        )

        setupStatusItem()
        setupPopover()
        setupBindings()

        // Start monitoring
        pingService.start()

        Log.tray.info("StatusBarController initialized")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = iconGenerator.defaultIcon()
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverView(
            pingService: pingService,
            settingsStorage: settingsStorage,
            onOpenMonitor: { [weak self] in
                self?.openMonitorWindow()
            },
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            }
        )

        // The hosting controller sizes itself from the content; the old fixed contentSize
        // disagreed with the view's own frame and clipped it.
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    private func setupBindings() {
        // Update icon when status changes
        pingService.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        // Update icon when monitoring state changes
        pingService.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        // Update tooltip with ping time
        pingService.$lastPingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.updateTooltip(time: time)
            }
            .store(in: &cancellables)

        // Update ping service when settings change
        settingsStorage.$settings
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.pingService.updateSettings(settings)
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        // Show stopped icon when not monitoring
        guard pingService.isMonitoring else {
            transitionTimer?.invalidate()
            button.image = iconGenerator.stoppedIcon()
            Log.tray.debug("Icon updated: stopped")
            return
        }

        let status = pingService.currentStatus
        let colors = settingsStorage.settings.iconColors

        // Check for transition icon (recovering from worse state)
        if let prev = pingService.previousStatus,
           (status == .good && (prev == .unstable || prev == .problem)) ||
           (status == .unstable && prev == .problem) {
            // Show transition icon
            button.image = iconGenerator.iconForStatus(status, previousStatus: prev, colors: colors)

            transitionTimer?.invalidate()
            transitionTimer = Timer.scheduledTimer(
                withTimeInterval: Tokens.statusTransitionDuration,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.pingService.previousStatus = nil
                    self?.updateIcon()
                }
            }
        } else {
            button.image = iconGenerator.iconForStatus(status, previousStatus: nil, colors: colors)
        }

        Log.tray.debug("Icon updated for status: \(status.rawValue)")
    }

    private func updateTooltip(time: Double?) {
        let target = settingsStorage.settings.pingTarget
        let reading = time.map { String(format: "%.0f ms", $0) } ?? "No data"
        let status = pingService.isMonitoring ? pingService.currentStatus.localizedName : "Paused"
        // Spells the status out in text — everywhere else it is carried by colour alone.
        statusItem.button?.toolTip = "PingMate — \(target): \(reading) (\(status))"
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)

            // Ensure popover window can become key
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openMonitorWindow() {
        popover.performClose(nil)
        monitorWindowController?.showWindow()
    }

    private func openSettingsWindow() {
        popover.performClose(nil)
        settingsWindowController?.showWindow()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let monitorItem = NSMenuItem(
            title: "Open History",
            action: #selector(openMonitor),
            keyEquivalent: "m"
        )
        monitorItem.target = self
        menu.addItem(monitorItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: pingService.isMonitoring ? "Stop Monitoring" : "Start Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openMonitor() {
        monitorWindowController?.showWindow()
    }

    @objc private func openSettings() {
        settingsWindowController?.showWindow()
    }

    @objc private func toggleMonitoring() {
        if pingService.isMonitoring {
            pingService.stop()
        } else {
            pingService.start()
        }
    }

    @objc private func quit() {
        pingService.stop()
        NSApp.terminate(nil)
    }
}
