import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore

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

            if historyEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(daySections) { section in
                            DaySeparator(date: section.date)

                            ForEach(section.entries) { entry in
                                SessionRow(
                                    session: entry.session,
                                    isPreview: entry.isPreview
                                ) { title in
                                    saveTitle(title, for: entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
    }

    private var historyEntries: [HistoryListEntry] {
        historyStore.sessions.map { HistoryListEntry(session: $0, isPreview: false) }
            + historyStore.activeDayPreviewSessions().map { HistoryListEntry(session: $0, isPreview: true) }
    }

    private var daySections: [HistoryDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: historyEntries) { entry in
            calendar.startOfDay(for: entry.session.startedAt)
        }

        return grouped
            .map { date, entries in
                HistoryDaySection(
                    date: date,
                    entries: entries.sorted { $0.session.endedAt > $1.session.endedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func saveTitle(_ title: String, for entry: HistoryListEntry) {
        let trimmedTitle = title.trimmedNonEmpty

        if entry.isPreview {
            guard let trimmedTitle else {
                return
            }

            historyStore.append(FocusSession(
                id: entry.session.id,
                topic: trimmedTitle,
                startedAt: entry.session.startedAt,
                endedAt: entry.session.endedAt,
                kind: .focused
            ))
            return
        }

        historyStore.updateSession(
            id: entry.session.id,
            topic: trimmedTitle,
            startedAt: entry.session.startedAt,
            endedAt: entry.session.endedAt,
            kind: trimmedTitle == nil ? entry.session.kind : .focused
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No history yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Focused blocks and flexible free time will appear here as they are logged.")
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
    let entries: [HistoryListEntry]

    var id: Date { date }
}

private struct HistoryListEntry: Identifiable {
    let session: FocusSession
    let isPreview: Bool

    var id: UUID { session.id }
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
    let isPreview: Bool
    let onTitleCommit: (String) -> Void

    @State private var draftTitle: String
    @FocusState private var isTitleFocused: Bool

    init(
        session: FocusSession,
        isPreview: Bool,
        onTitleCommit: @escaping (String) -> Void
    ) {
        self.session = session
        self.isPreview = isPreview
        self.onTitleCommit = onTitleCommit
        _draftTitle = State(initialValue: session.topic ?? "")
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startedAt)) - \(formatter.string(from: session.endedAt))"
    }

    private var titlePlaceholder: String {
        isPreview || session.isUntracked ? "Free time" : "No topic set"
    }

    private var durationText: String {
        if session.durationSeconds >= 60 * 60 {
            return FractalCopy.compactTime(session.durationSeconds)
        }

        return FractalCopy.duration(session.durationSeconds)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                TextField(titlePlaceholder, text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .focused($isTitleFocused)
                    .onSubmit(commitTitle)
                    .accessibilityLabel("Session title")

                Text(timeRange)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(durationText)
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
        .onChange(of: isTitleFocused) { focused in
            if !focused {
                commitTitle()
            }
        }
        .onChange(of: session.topic) { topic in
            guard !isTitleFocused else {
                return
            }

            draftTitle = topic ?? ""
        }
    }

    private func commitTitle() {
        let normalizedTitle = draftTitle.trimmedNonEmpty ?? ""

        if draftTitle != normalizedTitle {
            draftTitle = normalizedTitle
        }

        guard normalizedTitle != (session.topic ?? "") else {
            return
        }

        onTitleCommit(normalizedTitle)
    }
}
