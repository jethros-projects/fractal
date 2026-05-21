import AppKit
import Combine
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let historyStore = HistoryStore()
    private lazy var focusTimer = FocusTimer(settings: settings, historyStore: historyStore)
    private lazy var statusImage = Self.makeStatusImage()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var completionPanelController: CompletionPanelController?
    private var dayRolloverTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        bindUpdates()
        finishExpiredDayIfNeeded()

        focusTimer.onBlockCompleted = { [weak self] session in
            self?.showCompletionPrompt(for: session)
        }

        updateStatusItem()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        dayRolloverTimer?.invalidate()
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
        popover.contentSize = FractalPopoverView.initialContentSize
        popover.contentViewController = NSHostingController(
            rootView: FractalPopoverView(
                timer: focusTimer,
                settings: settings,
                historyStore: historyStore,
                onQuit: { NSApp.terminate(nil) },
                onContentSizeChange: { [weak popover] size in
                    popover?.contentSize = size
                }
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

        historyStore.$activeDayStartedAt
            .sink { [weak self] startedAt in
                Task { @MainActor in
                    self?.scheduleDayRollover(for: startedAt)
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
            finishExpiredDayIfNeeded()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func finishExpiredDayIfNeeded() {
        let activeBlockInterval = focusTimer.currentBlockInterval(until: Date()).map { [$0] } ?? []
        historyStore.finishExpiredActiveDay(additionalOccupiedIntervals: activeBlockInterval)
        scheduleDayRollover(for: historyStore.activeDayStartedAt)
    }

    private func scheduleDayRollover(for startedAt: Date?) {
        dayRolloverTimer?.invalidate()
        dayRolloverTimer = nil

        guard
            let startedAt,
            let dayEnd = Calendar.current.dateInterval(of: .day, for: startedAt)?.end
        else {
            return
        }

        guard Date() < dayEnd else {
            finishExpiredDayIfNeeded()
            return
        }

        let timer = Timer(fire: dayEnd, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishExpiredDayIfNeeded()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dayRolloverTimer = timer
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        button.toolTip = "Fractal"
        button.contentTintColor = nil
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageLeading

        if focusTimer.isActive {
            button.image = statusImage
            button.title = focusTimer.menuBarTitle(showSeconds: settings.showSecondsInMenuBar)
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        } else {
            button.title = ""
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.image = statusImage
        }
    }

    private static func makeStatusImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let triangles: [[CGPoint]] = [
                [CGPoint(x: 32, y: 6), CGPoint(x: 1.98, y: 58), CGPoint(x: 62.02, y: 58)],
                [CGPoint(x: 16.99, y: 32), CGPoint(x: 47.01, y: 32), CGPoint(x: 32, y: 58)],
                [CGPoint(x: 24.5, y: 19), CGPoint(x: 39.5, y: 19), CGPoint(x: 32, y: 32)],
                [CGPoint(x: 9.49, y: 45), CGPoint(x: 24.5, y: 45), CGPoint(x: 16.99, y: 58)],
                [CGPoint(x: 39.5, y: 45), CGPoint(x: 54.51, y: 45), CGPoint(x: 47.01, y: 58)]
            ]

            func point(from source: CGPoint) -> CGPoint {
                CGPoint(
                    x: rect.minX + (source.x / 64) * rect.width,
                    y: rect.maxY - (source.y / 64) * rect.height
                )
            }

            func strokeTriangle(_ vertices: [CGPoint]) {
                guard vertices.count == 3 else {
                    return
                }

                let path = NSBezierPath()
                path.move(to: point(from: vertices[0]))
                path.line(to: point(from: vertices[1]))
                path.line(to: point(from: vertices[2]))
                path.close()
                path.lineWidth = 1.45
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                path.stroke()
            }

            NSColor.black.setStroke()
            triangles.forEach(strokeTriangle)

            return true
        }

        image.isTemplate = true
        return image
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
