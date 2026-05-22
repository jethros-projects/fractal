import SwiftUI

private enum PopoverSection: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var contentHeight: CGFloat {
        switch self {
        case .focus:
            return FractalPopoverView.focusContentHeight
        case .history, .settings:
            return FractalPopoverView.standardContentHeight
        }
    }
}

struct FractalPopoverView: View {
    static let contentWidth: CGFloat = 420
    static let focusContentHeight: CGFloat = 520
    static let standardContentHeight: CGFloat = 590
    static let initialContentSize = CGSize(width: contentWidth, height: focusContentHeight)

    @ObservedObject var timer: FocusTimer
    @ObservedObject var settings: AppSettings
    @ObservedObject var historyStore: HistoryStore

    let onQuit: () -> Void
    var onContentSizeChange: (CGSize) -> Void = { _ in }

    @State private var section: PopoverSection = .focus

    private var contentSize: CGSize {
        CGSize(width: Self.contentWidth, height: section.contentHeight)
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                Divider()
                    .opacity(0.45)

                Group {
                    switch section {
                    case .focus:
                        FocusView(
                            timer: timer,
                            settings: settings,
                            historyStore: historyStore
                        )
                    case .history:
                        HistoryView(
                            historyStore: historyStore,
                            defaultLogDurationSeconds: settings.blockLengthSeconds
                        )
                    case .settings:
                        FractalSettingsView(
                            settings: settings,
                            onQuit: onQuit
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .animation(.easeOut(duration: 0.16), value: section)
            }
        }
        .frame(width: Self.contentWidth, height: section.contentHeight)
        .onAppear {
            onContentSizeChange(contentSize)
        }
        .onChange(of: section) { _ in
            onContentSizeChange(contentSize)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                FractalLogoMark()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.primary)
                Text("Fractal")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            Picker("", selection: $section) {
                ForEach(PopoverSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 248)
        }
    }
}
