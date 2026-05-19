import AppKit
import SwiftUI

@MainActor
final class CompletionPanelController: NSObject, NSWindowDelegate {
    private let session: FocusSession
    private let timer: FocusTimer
    private let settings: AppSettings
    private let onClose: () -> Void

    private var panel: NSPanel?
    private var resolved = false

    init(
        session: FocusSession,
        timer: FocusTimer,
        settings: AppSettings,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.timer = timer
        self.settings = settings
        self.onClose = onClose
    }

    func show() {
        let rootView = CompletionPromptView(
            session: session,
            timer: timer,
            settings: settings,
            onResolved: { [weak self] in
                self?.resolved = true
                self?.panel?.close()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 392),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Fractal"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController
        panel.delegate = self
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if !resolved, timer.state == .completed {
            timer.logOnlyAfterCompletion()
        }

        panel = nil
        onClose()
    }
}

private enum CompletionMode {
    case decision
    case switchTopic
}

struct CompletionPromptView: View {
    let session: FocusSession

    @ObservedObject var timer: FocusTimer
    @ObservedObject var settings: AppSettings

    let onResolved: () -> Void

    @State private var mode: CompletionMode = .decision
    @State private var newTopic = ""

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, emphasized: true)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                switch mode {
                case .decision:
                    decisionView
                case .switchTopic:
                    switchTopicView
                }
            }
            .padding(28)
        }
        .frame(width: 470, height: 392)
    }

    private var decisionView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 13) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                Text("Nice work.")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                Text("You just completed a \(FractalCopy.sentenceDuration(session.durationSeconds)) block.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(continueQuestion)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)

            VStack(spacing: 10) {
                Button {
                    timer.continueCurrentTopic(shouldStart: settings.autoStartAfterContinue)
                    onResolved()
                } label: {
                    Label(continueButtonTitle, systemImage: settings.autoStartAfterContinue ? "arrow.clockwise" : "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FractalPrimaryButtonStyle())

                HStack(spacing: 10) {
                    Button {
                        newTopic = timer.topic.trimmedNonEmpty ?? ""
                        withAnimation(.easeOut(duration: 0.16)) {
                            mode = .switchTopic
                        }
                    } label: {
                        Label("Switch", systemImage: "arrow.triangle.branch")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FractalSecondaryButtonStyle())

                    Button {
                        timer.logOnlyAfterCompletion()
                        onResolved()
                    } label: {
                        Label("Log Only", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FractalSecondaryButtonStyle())
                }
            }
        }
    }

    private var switchTopicView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 34, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                Text("Switch to something new")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text("Name the next focus topic before the block begins.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("New topic", text: $newTopic)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: 350)

            VStack(spacing: 10) {
                Button {
                    timer.startNewBlock(topic: newTopic, shouldStart: true)
                    onResolved()
                } label: {
                    Label("Start New Block", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FractalPrimaryButtonStyle())

                HStack(spacing: 10) {
                    Button {
                        timer.startNewBlock(topic: newTopic, shouldStart: false)
                        onResolved()
                    } label: {
                        Label("Set Topic", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FractalSecondaryButtonStyle())

                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            mode = .decision
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FractalSecondaryButtonStyle())
                }
            }
        }
    }

    private var continueQuestion: String {
        let duration = FractalCopy.sentenceDuration(settings.blockLengthSeconds)

        if let topic = session.topic?.trimmedNonEmpty {
            return "Would you like to keep focusing on \(topic) for another \(duration) block?"
        }

        return "Would you like to begin another \(duration) block?"
    }

    private var continueButtonTitle: String {
        settings.autoStartAfterContinue ? "Continue" : "Prepare Next Block"
    }
}
