import SwiftUI

struct FocusView: View {
    @ObservedObject var timer: FocusTimer
    @ObservedObject var settings: AppSettings

    private var topicBinding: Binding<String> {
        Binding(
            get: { timer.topic },
            set: { timer.topic = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 18)

            timerDial

            VStack(spacing: 9) {
                TextField("No topic set", text: topicBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 28)

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            controls

            Spacer(minLength: 22)
        }
        .padding(.horizontal, 22)
    }

    private var timerDial: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.075), lineWidth: 6)

            Circle()
                .trim(from: 0, to: max(0.001, timer.progress))
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.accentColor.opacity(0.92),
                            Color.accentColor.opacity(0.44),
                            Color.accentColor.opacity(0.92)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: timer.progress)

            VStack(spacing: 10) {
                Text(timer.displayClock)
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)

                Text(FractalCopy.duration(settings.blockLengthSeconds))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: 224, height: 224)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Remaining time \(timer.displayClock)")
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                timer.startOrResume()
            } label: {
                Label(startLabel, systemImage: "play.fill")
            }
            .buttonStyle(FractalPrimaryButtonStyle())
            .disabled(timer.state == .running)

            Button {
                timer.pause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(FractalSecondaryButtonStyle())
            .disabled(timer.state != .running)

            Button {
                timer.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(FractalSecondaryButtonStyle())
        }
    }

    private var startLabel: String {
        timer.state == .paused ? "Resume" : "Start"
    }

    private var statusText: String {
        switch timer.state {
        case .idle:
            return "Ready"
        case .running:
            return "Focusing"
        case .paused:
            return "Paused"
        case .completed:
            return "Block complete"
        }
    }
}
