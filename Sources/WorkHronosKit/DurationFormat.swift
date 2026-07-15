import Foundation

public enum DurationFormat {
    /// Formatira trajanje kao H:MM:SS (npr. 4517 → "1:15:17").
    public static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// Parsira unos trajanja (Toggl semantika):
    /// "1:30:45" = h:mm:ss, "1:30" = h:mm, "90" = 90 minuta, "1h 30m", "45m", "30s".
    public static func parse(_ input: String) -> TimeInterval? {
        let text = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return nil }

        if text.contains(":") {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
            let numbers = parts.compactMap { Int($0) }
            guard numbers.count == parts.count else { return nil }
            switch numbers.count {
            case 2 where numbers[1] < 60:
                return TimeInterval(numbers[0] * 3600 + numbers[1] * 60)
            case 3 where numbers[1] < 60 && numbers[2] < 60:
                return TimeInterval(numbers[0] * 3600 + numbers[1] * 60 + numbers[2])
            default:
                return nil
            }
        }

        if text.contains("h") || text.contains("m") || text.contains("s") {
            let pattern = #/^(?:(\d+(?:[.,]\d+)?)\s*h)?\s*(?:(\d+)\s*m)?\s*(?:(\d+)\s*s)?$/#
            guard let match = text.wholeMatch(of: pattern),
                  match.1 != nil || match.2 != nil || match.3 != nil else { return nil }
            var total: TimeInterval = 0
            if let hours = match.1 {
                total += (Double(hours.replacingOccurrences(of: ",", with: ".")) ?? 0) * 3600
            }
            if let minutes = match.2 { total += TimeInterval(Int(minutes) ?? 0) * 60 }
            if let seconds = match.3 { total += TimeInterval(Int(seconds) ?? 0) }
            return total
        }

        if let minutes = Double(text.replacingOccurrences(of: ",", with: ".")) {
            return minutes * 60
        }
        return nil
    }
}
