import SwiftUI

struct HistoryDayHeader: View {
    let section: HistoryDaySection

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: section.date)
    }

    private var summaryText: String {
        var parts: [String] = []

        if section.focusedSeconds > 0 {
            parts.append("\(FractalCopy.compactTime(section.focusedSeconds)) focused")
        }

        if section.freeSeconds > 0 {
            parts.append("\(FractalCopy.compactTime(section.freeSeconds)) free")
        }

        return parts.isEmpty ? "No tracked focus yet" : parts.joined(separator: " / ")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(dateText)
                .font(.system(size: 12, weight: .semibold))

            Text(summaryText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.horizontal, 2)
    }
}

struct HistorySessionRow: View {
    let session: FocusSession
    let isPreview: Bool
    let defaultLogDurationSeconds: Int
    let onSessionCommit: (String, Date, Date) -> Void

    @State private var draftTitle: String
    @State private var draftStart: Date
    @State private var draftEnd: Date
    @State private var isEditing = false
    @FocusState private var isTitleFocused: Bool

    init(
        session: FocusSession,
        isPreview: Bool,
        defaultLogDurationSeconds: Int,
        onSessionCommit: @escaping (String, Date, Date) -> Void
    ) {
        self.session = session
        self.isPreview = isPreview
        self.defaultLogDurationSeconds = max(60, defaultLogDurationSeconds)
        self.onSessionCommit = onSessionCommit
        _draftTitle = State(initialValue: session.topic ?? "")
        _draftStart = State(initialValue: session.startedAt)
        _draftEnd = State(initialValue: Self.initialDraftEnd(
            for: session,
            isPreview: isPreview,
            defaultLogDurationSeconds: max(60, defaultLogDurationSeconds)
        ))
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startedAt)) - \(formatter.string(from: session.endedAt))"
    }

    private var titlePlaceholder: String {
        isPreview || session.isUntracked ? "What happened here?" : "No topic set"
    }

    private var displayTitle: String {
        if let topic = session.topic {
            return topic
        }

        if isPreview || session.isUntracked {
            return "Free time"
        }

        return "No topic set"
    }

    private var statusText: String {
        if isPreview {
            return "Live preview"
        }

        if session.isUntracked {
            return "Untracked"
        }

        return "Focused"
    }

    private var statusIcon: String {
        if isPreview || session.isUntracked {
            return "clock"
        }

        return "checkmark.circle.fill"
    }

    private var durationText: String {
        if session.durationSeconds >= 60 * 60 {
            return FractalCopy.compactTime(session.durationSeconds)
        }

        return FractalCopy.duration(session.durationSeconds)
    }

    private var draftTimeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: draftStart)) - \(formatter.string(from: draftEnd))"
    }

    private var draftDurationText: String {
        FractalCopy.compactTime(Int(draftEnd.timeIntervalSince(draftStart).rounded()))
    }

    var body: some View {
        Group {
            if isEditing {
                editingBody
            } else {
                displayBody
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(session.isUntracked ? 0.025 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(session.isUntracked ? 0.05 : 0.06), lineWidth: 1)
        )
        .onChange(of: session.topic) { topic in
            guard !isTitleFocused else {
                return
            }

            draftTitle = topic ?? ""
        }
        .onChange(of: draftStart) { start in
            guard draftEnd <= start else {
                return
            }

            draftEnd = minDate(session.endedAt, start.addingTimeInterval(TimeInterval(defaultLogDurationSeconds)))
        }
        .onChange(of: draftEnd) { end in
            guard end <= draftStart else {
                return
            }

            draftStart = maxDate(session.startedAt, end.addingTimeInterval(-TimeInterval(defaultLogDurationSeconds)))
        }
    }

    private var displayBody: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(session.isUntracked ? Color.secondary : Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(statusText) - \(timeRange)")
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

            Button {
                beginEditing()
            } label: {
                if isPreview || session.isUntracked {
                    Label("Log", systemImage: "plus.circle")
                } else {
                    Image(systemName: "pencil")
                        .frame(width: 24)
                }
            }
            .buttonStyle(FractalCompactButtonStyle())
            .accessibilityLabel(isPreview || session.isUntracked ? "Log free time" : "Edit title")
            .help(isPreview || session.isUntracked ? "Log this free time" : "Edit title")
        }
    }

    private var editingBody: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                TextField(titlePlaceholder, text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .focused($isTitleFocused)
                    .onSubmit(commitTitle)
                    .accessibilityLabel("Session title")

                if isPreview || session.isUntracked {
                    HStack(spacing: 6) {
                        DatePicker(
                            "Start",
                            selection: $draftStart,
                            in: session.startedAt...session.endedAt,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .frame(width: 92)

                        Text("-")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "End",
                            selection: $draftEnd,
                            in: session.startedAt...session.endedAt,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .frame(width: 92)

                        Text(draftDurationText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .accessibilityLabel("Log time range \(draftTimeRangeText)")
                } else {
                    Text(timeRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                commitTitle()
            } label: {
                Image(systemName: "checkmark")
                    .frame(width: 24)
            }
            .buttonStyle(FractalCompactButtonStyle())
            .disabled(!canCommitTitle)
            .accessibilityLabel("Save title")
            .help("Save")

            Button {
                cancelEditing()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24)
            }
            .buttonStyle(FractalCompactButtonStyle())
            .accessibilityLabel("Cancel editing")
            .help("Cancel")
        }
    }

    private var canCommitTitle: Bool {
        if isPreview || session.isUntracked {
            return draftTitle.trimmedNonEmpty != nil && draftEnd > draftStart
        }

        return true
    }

    private func beginEditing() {
        draftTitle = session.topic ?? ""
        draftStart = session.startedAt
        draftEnd = Self.initialDraftEnd(
            for: session,
            isPreview: isPreview,
            defaultLogDurationSeconds: defaultLogDurationSeconds
        )
        isEditing = true
        isTitleFocused = true
    }

    private func cancelEditing() {
        draftTitle = session.topic ?? ""
        draftStart = session.startedAt
        draftEnd = Self.initialDraftEnd(
            for: session,
            isPreview: isPreview,
            defaultLogDurationSeconds: defaultLogDurationSeconds
        )
        isEditing = false
        isTitleFocused = false
    }

    private func commitTitle() {
        guard canCommitTitle else {
            return
        }

        let normalizedTitle = draftTitle.trimmedNonEmpty ?? ""

        if draftTitle != normalizedTitle {
            draftTitle = normalizedTitle
        }

        defer {
            isEditing = false
            isTitleFocused = false
        }

        guard normalizedTitle != (session.topic ?? "") || isPreview || session.isUntracked else {
            return
        }

        onSessionCommit(normalizedTitle, draftStart, draftEnd)
    }

    private static func initialDraftEnd(
        for session: FocusSession,
        isPreview: Bool,
        defaultLogDurationSeconds: Int
    ) -> Date {
        guard isPreview || session.isUntracked else {
            return session.endedAt
        }

        return min(
            session.endedAt,
            session.startedAt.addingTimeInterval(TimeInterval(defaultLogDurationSeconds))
        )
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}
