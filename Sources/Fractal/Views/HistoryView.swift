import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    let defaultLogDurationSeconds: Int

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
                    LazyVStack(spacing: 8) {
                        ForEach(daySections) { section in
                            HistoryDayHeader(section: section)

                            ForEach(section.entries) { entry in
                                HistorySessionRow(
                                    session: entry.session,
                                    isPreview: entry.isPreview,
                                    defaultLogDurationSeconds: defaultLogDurationSeconds
                                ) { title, startedAt, endedAt in
                                    saveSession(
                                        title: title,
                                        startedAt: startedAt,
                                        endedAt: endedAt,
                                        for: entry
                                    )
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
                let sortedEntries = entries.sorted { $0.session.endedAt > $1.session.endedAt }

                return HistoryDaySection(
                    date: date,
                    entries: sortedEntries
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func saveSession(
        title: String,
        startedAt: Date,
        endedAt: Date,
        for entry: HistoryListEntry
    ) {
        let trimmedTitle = title.trimmedNonEmpty

        if entry.isPreview {
            guard let trimmedTitle else {
                return
            }

            historyStore.logFocusedSession(
                topic: trimmedTitle,
                startedAt: startedAt,
                endedAt: endedAt
            )
            return
        }

        if entry.session.isUntracked {
            guard let trimmedTitle else {
                return
            }

            historyStore.logFocusedSession(
                topic: trimmedTitle,
                startedAt: startedAt,
                endedAt: endedAt,
                replacingUntrackedSessionID: entry.session.id
            )
            return
        }

        historyStore.updateSession(
            id: entry.session.id,
            topic: trimmedTitle,
            startedAt: startedAt,
            endedAt: endedAt,
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
            Text("Start a day or complete a focus block to build your timeline.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)
            Spacer()
        }
        .padding(.bottom, 20)
    }
}

struct HistoryDaySection: Identifiable {
    let date: Date
    let entries: [HistoryListEntry]

    var id: Date { date }

    var focusedSeconds: Int {
        entries
            .filter { $0.session.kind == .focused }
            .map(\.session.durationSeconds)
            .reduce(0, +)
    }

    var freeSeconds: Int {
        entries
            .filter { $0.session.isUntracked }
            .map(\.session.durationSeconds)
            .reduce(0, +)
    }
}

struct HistoryListEntry: Identifiable {
    let session: FocusSession
    let isPreview: Bool

    var id: UUID { session.id }
}
