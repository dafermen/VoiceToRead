import Foundation

enum SessionClock {
    static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return max(0, Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000)
    }

    static func format(_ duration: TimeInterval) -> String {
        let seconds = Int(min(Double(Int.max / 2), max(0, duration.isFinite ? duration : 0)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

extension CaptionState {
    var title: String {
        switch self {
        case .idle: "Ready to start"
        case .preparing: "Preparing microphone and speech"
        case .listening: "LIVE · Listening"
        case .stopping: "Finalizing captions"
        case .paused: "Paused"
        case .ended: "Session ended"
        case .problem: "Listening stopped"
        }
    }
}

/// A useful default without an extra naming screen or a network service.
enum SessionTitle {
    static func suggested(at date: Date = Date(), locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d HHmm")
        return "Session · " + formatter.string(from: date)
    }
    static func resolved(_ proposed: String, at date: Date) -> String {
        let clean = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? suggested(at: date) : String(clean.prefix(120))
    }
}
