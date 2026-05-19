enum FractalCopy {
    static func duration(_ seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return "\(minutes) min"
    }

    static func sentenceDuration(_ seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return "\(minutes)-minute"
    }

    static func compactTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }
}
