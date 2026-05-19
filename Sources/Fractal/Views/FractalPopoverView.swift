import SwiftUI

private enum PopoverSection: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }
}

struct FractalPopoverView: View {
    @ObservedObject var timer: FocusTimer
    @ObservedObject var settings: AppSettings
    @ObservedObject var historyStore: HistoryStore

    let onQuit: () -> Void

    @State private var section: PopoverSection = .focus

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
                        FocusView(timer: timer, settings: settings)
                    case .history:
                        HistoryView(historyStore: historyStore)
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
        .frame(width: 420, height: 590)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 16, weight: .medium))
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
