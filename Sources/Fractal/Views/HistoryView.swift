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

            if historyStore.sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(historyStore.sessionsNewestFirst) { session in
                            SessionRow(session: session)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
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

private struct SessionRow: View {
    let session: FocusSession

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startedAt)) - \(formatter.string(from: session.endedAt))"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: session.startedAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.topicDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(dateText) - \(timeRange)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

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
                .fill(.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 1)
        )
    }
}
