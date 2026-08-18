import Foundation

/// One "Current session" / "Current week" line from `claude -p "/usage"`.
struct UsageLine: Equatable {
    /// Percent of the limit used, e.g. 22.
    var percent: Int
    /// Full reset description, e.g. "Jun 25 at 9:59pm".
    var resetFull: String
    /// Compact reset time for the menu bar, e.g. "9:59p".
    var resetShort: String
    /// Absolute time the window rolls over, when the line can be resolved to
    /// one. Used to tell a real 0% (the window reset) from a bad reading.
    var resetDate: Date?
}

struct UsageSnapshot: Equatable {
    var session: UsageLine?
    var week: UsageLine?
}

/// Rejects the all-zero reading that `/usage` returns when it is being polled
/// too often.
///
/// A throttled server-side fetch answers `0% used` for both windows — for hours
/// at a stretch — while real usage is unchanged. Usage only genuinely falls to
/// zero when a window rolls over, so a 0/0 reading that arrives while a
/// previously non-zero window is still open is a bad reading, not news.
enum ZeroReadingGuard {
    static func isSuspect(new: UsageSnapshot, previous: UsageSnapshot, now: Date = Date()) -> Bool {
        guard let session = new.session, let week = new.week,
              session.percent == 0, week.percent == 0 else { return false }
        return stillOpen(previous.session, now: now) || stillOpen(previous.week, now: now)
    }

    /// True when `line` reported usage that cannot have vanished by `now`.
    private static func stillOpen(_ line: UsageLine?, now: Date) -> Bool {
        guard let line, line.percent > 0, let reset = line.resetDate else { return false }
        return now < reset
    }
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
                resetShort: shortTime(in: l) ?? resetFull,
                resetDate: resetDate(in: l)
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

    /// "... resets Aug 17 at 10:59pm (America/New_York)" -> the absolute Date.
    ///
    /// The line carries no year, so the candidate nearest to now wins — which is
    /// right for both windows (a session resets within hours, a week within days)
    /// and handles the December/January wrap.
    private static func resetDate(in s: String, now: Date = Date()) -> Date? {
        let pattern =
            #"resets\s+([A-Za-z]{3,})\s+(\d{1,2})\s+at\s+(\d{1,2})(?::(\d{2}))?\s*([ap])m(?:\s*\(([^)]+)\))?"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }

        func group(_ i: Int) -> String? {
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        }
        guard let month = group(1).flatMap(monthNumber),
              let day = group(2).flatMap({ Int($0) }),
              var hour = group(3).flatMap({ Int($0) }),
              let meridiem = group(5)?.lowercased() else { return nil }
        if meridiem == "p", hour != 12 { hour += 12 }
        if meridiem == "a", hour == 12 { hour = 0 }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = group(6).flatMap { TimeZone(identifier: $0) } ?? .current

        var components = DateComponents()
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = group(4).flatMap { Int($0) } ?? 0

        let thisYear = calendar.component(.year, from: now)
        return [thisYear - 1, thisYear, thisYear + 1]
            .compactMap { year -> Date? in
                var withYear = components
                withYear.year = year
                return calendar.date(from: withYear)
            }
            .min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
    }

    /// "Aug" -> 8, using a fixed locale so the app's locale can't change it.
    private static func monthNumber(_ name: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let needle = name.prefix(3).lowercased()
        return formatter.shortMonthSymbols
            .firstIndex { $0.prefix(3).lowercased() == needle }
            .map { $0 + 1 }
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
