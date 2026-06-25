import Foundation

/// One "Current session" / "Current week" line from `claude -p "/usage"`.
struct UsageLine: Equatable {
    /// Percent of the limit used, e.g. 22.
    var percent: Int
    /// Full reset description, e.g. "Jun 25 at 9:59pm".
    var resetFull: String
    /// Compact reset time for the menu bar, e.g. "9:59p".
    var resetShort: String
}

struct UsageSnapshot: Equatable {
    var session: UsageLine?
    var week: UsageLine?
}

/// Parses the plain-text output of `claude -p "/usage"`.
///
/// Expected lines look like:
///   Current session: 22% used · resets Jun 25 at 9:59pm (America/New_York)
///   Current week (all models): 73% used · resets Jun 28 at 1:59pm (America/New_York)
enum UsageParser {
    static func parse(_ output: String) -> UsageSnapshot {
        UsageSnapshot(
            session: line(from: output, prefix: "Current session"),
            week: line(from: output, prefix: "Current week")
        )
    }

    private static func line(from output: String, prefix: String) -> UsageLine? {
        for raw in output.split(separator: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix(prefix) else { continue }
            guard let percent = firstInt(in: l, pattern: #"(\d+)%"#) else { return nil }
            let resetFull = (capture(in: l, pattern: #"resets\s+(.+?)\s*(?:\(|$)"#) ?? "")
                .trimmingCharacters(in: .whitespaces)
            return UsageLine(
                percent: percent,
                resetFull: resetFull,
                resetShort: shortTime(in: l) ?? resetFull
            )
        }
        return nil
    }

    /// "... at 9:59pm ..." -> "9:59p"; "... at 10pm ..." -> "10p"
    private static func shortTime(in s: String) -> String? {
        // Optional minutes so on-the-hour times ("10pm") also match.
        guard let re = try? NSRegularExpression(
            pattern: #"(\d{1,2})(?::(\d{2}))?\s*([ap])m"#, options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: range) else { return nil }

        func group(_ i: Int) -> String? {
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        }
        guard let hour = group(1), let ap = group(3)?.lowercased() else { return nil }
        if let minutes = group(2) {
            return "\(hour):\(minutes)\(ap)"
        }
        return "\(hour)\(ap)"
    }

    // MARK: - Regex helpers

    private static func firstInt(in s: String, pattern: String) -> Int? {
        capture(in: s, pattern: pattern).flatMap { Int($0) }
    }

    private static func capture(in s: String, pattern: String) -> String? {
        firstMatch(in: s, pattern: pattern, groups: 1)?.first
    }

    /// Returns the requested number of capture groups from the first match, or nil.
    private static func firstMatch(in s: String, pattern: String, groups: Int) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: range), m.numberOfRanges > groups else {
            return nil
        }
        var out: [String] = []
        for i in 1...groups {
            guard let r = Range(m.range(at: i), in: s) else { return nil }
            out.append(String(s[r]))
        }
        return out
    }
}
