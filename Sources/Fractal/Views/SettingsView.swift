import SwiftUI

struct FractalSettingsView: View {
    @ObservedObject var settings: AppSettings

    let onQuit: () -> Void

    @State private var customMinutesText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                lengthSection
                notificationSection
                appSection
            }
            .padding(18)
        }
        .onAppear {
            customMinutesText = "\(settings.blockLengthMinutes)"
        }
        .onChange(of: settings.blockLengthMinutes) { newValue in
            customMinutesText = "\(newValue)"
        }
    }

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Block Length")

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(AppSettings.presetMinutes, id: \.self) { minutes in
                    Button {
                        settings.blockLengthMinutes = minutes
                    } label: {
                        Text("\(minutes) min")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SettingPillButtonStyle(isSelected: settings.blockLengthMinutes == minutes))
                }
            }

            HStack(spacing: 10) {
                Text("Custom")
                    .font(.system(size: 13, weight: .semibold))

                TextField("Minutes", text: $customMinutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 86)
                    .onSubmit(commitCustomMinutes)

                Button("Apply") {
                    commitCustomMinutes()
                }
                .buttonStyle(FractalSecondaryButtonStyle())

                Stepper("", value: Binding(
                    get: { settings.blockLengthMinutes },
                    set: { settings.blockLengthMinutes = $0 }
                ), in: 1...240)
                .labelsHidden()

                Spacer()
            }
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notifications")

            Toggle("Sound notifications", isOn: $settings.soundEnabled)
            Toggle("Auto-start after Continue", isOn: $settings.autoStartAfterContinue)
            Toggle("Show seconds in menu bar", isOn: $settings.showSecondsInMenuBar)
        }
        .toggleStyle(.switch)
        .padding(14)
        .background(sectionBackground)
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App")

            Button(role: .destructive) {
                onQuit()
            } label: {
                Label("Quit Fractal", systemImage: "power")
            }
            .buttonStyle(FractalSecondaryButtonStyle())
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(0.055), lineWidth: 1)
            )
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func commitCustomMinutes() {
        let filtered = customMinutesText.filter(\.isNumber)
        guard let value = Int(filtered) else {
            customMinutesText = "\(settings.blockLengthMinutes)"
            return
        }

        settings.blockLengthMinutes = max(1, min(value, 240))
        customMinutesText = "\(settings.blockLengthMinutes)"
    }
}

private struct SettingPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.94) : .primary.opacity(configuration.isPressed ? 0.09 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? .clear : .primary.opacity(0.065), lineWidth: 1)
            )
    }
}
