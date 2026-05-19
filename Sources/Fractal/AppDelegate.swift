import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let historyStore = HistoryStore()
    private lazy var focusTimer = FocusTimer(settings: settings, historyStore: historyStore)

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var completionPanelController: CompletionPanelController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        bindUpdates()

        focusTimer.onBlockCompleted = { [weak self] session in
            self?.showCompletionPrompt(for: session)
        }

        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusTimer.pause()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 590)
        popover.contentViewController = NSHostingController(
            rootView: FractalPopoverView(
                timer: focusTimer,
                settings: settings,
                historyStore: historyStore,
                onQuit: { NSApp.terminate(nil) }
            )
        )
        self.popover = popover
    }

    private func bindUpdates() {
        focusTimer.onUpdate = { [weak self] in
            self?.updateStatusItem()
        }

        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        button.toolTip = "Fractal"

        if focusTimer.isActive {
            button.image = nil
            button.title = focusTimer.menuBarTitle(showSeconds: settings.showSecondsInMenuBar)
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            button.contentTintColor = focusTimer.state == .paused ? .secondaryLabelColor : .labelColor
        } else {
            button.title = ""
            button.font = .systemFont(ofSize: 13, weight: .medium)
            let image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "Fractal")
                ?? NSImage(systemSymbolName: "timelapse", accessibilityDescription: "Fractal")
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = .labelColor
        }
    }

    private func showCompletionPrompt(for session: FocusSession) {
        if settings.soundEnabled {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }

        popover?.performClose(nil)

        let controller = CompletionPanelController(
            session: session,
            timer: focusTimer,
            settings: settings
        ) { [weak self] in
            self?.completionPanelController = nil
        }
        completionPanelController = controller
        controller.show()
    }
}
