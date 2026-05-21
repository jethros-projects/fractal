import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore

    @State private var editingSession: FocusSession?

    private var todayTotal: String {
        FractalCopy.compactTime(historyStore.totalFocusedSeconds(on: Date()))
    }

    private var weekTotal: String {
        FractalCopy.compactTime(historyStore.totalFocusedSecondsThisWeek())
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                StatTile(title: "Today", value: todayTotal)
                StatTile(title: "This Week", value: weekTotal)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            if historyStore.sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(daySections) { section in
                            DaySeparator(date: section.date)

                            ForEach(section.sessions) { session in
                                SessionRow(session: session) {
                                    editingSession = session
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditorView(
                session: session,
                historyStore: historyStore
            )
        }
    }

    private var daySections: [HistoryDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: historyStore.sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return grouped
            .map { date, sessions in
                HistoryDaySection(
                    date: date,
                    sessions: sessions.sorted { $0.endedAt > $1.endedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No completed blocks yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Your focused time will appear here as soon as the first block ends.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)
            Spacer()
        }
        .padding(.bottom, 20)
    }
}

private struct HistoryDaySection: Identifiable {
    let date: Date
    let sessions: [FocusSession]

    var id: Date { date }
}

private struct DaySeparator: View {
    let date: Date

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(.primary.opacity(0.09))
                .frame(height: 1)

            Text(dateText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Rectangle()
                .fill(.primary.opacity(0.09))
                .frame(height: 1)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

private struct SessionRow: View {
    let session: FocusSession
    let onEdit: () -> Void

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startedAt)) - \(formatter.string(from: session.endedAt))"
    }

    private var sessionSubtitle: String {
        timeRange
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: session.isUntracked ? "questionmark.circle" : "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(session.isUntracked ? .secondary : Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.topicDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(sessionSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(session.topicDisplayName)")

            Text(FractalCopy.duration(session.durationSeconds))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(.primary.opacity(0.055))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(session.isUntracked ? 0.03 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(session.isUntracked ? 0.045 : 0.055), lineWidth: 1)
        )
    }
}

private struct SessionEditorView: View {
    let session: FocusSession

    @ObservedObject var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var startedAt: Date
    @State private var endedAt: Date

    init(session: FocusSession, historyStore: HistoryStore) {
        self.session = session
        self.historyStore = historyStore
        _title = State(initialValue: session.topic ?? "")
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.isUntracked ? "Assign Slot" : "Edit Slot")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text(session.isUntracked ? "Untracked time" : "Focused time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Focus title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                DatePicker(
                    "Start",
                    selection: $startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "End",
                    selection: $endedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .datePickerStyle(.field)

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(FractalSecondaryButtonStyle())

                Button {
                    save()
                } label: {
                    Label("Save Slot", systemImage: "checkmark")
                }
                .buttonStyle(FractalPrimaryButtonStyle())
                .disabled(endedAt <= startedAt)
            }
        }
        .padding(22)
        .frame(width: 390)
    }

    private func save() {
        let trimmedTitle = title.trimmedNonEmpty
        let kind: FocusSessionKind = trimmedTitle == nil ? session.kind : .focused
        historyStore.updateSession(
            id: session.id,
            topic: trimmedTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            kind: kind
        )
        dismiss()
    }
}
