import Foundation
import Combine

@MainActor
final class UsageModel: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    /// Minutes between automatic refreshes. Persisted; clamped to a sane range.
    ///
    /// The clamp guards against re-entry: assigning to a `@Published` property
    /// from inside its own `didSet` re-enters the setter (the observer lives on
    /// the wrapper's computed accessor, so Swift's "don't recurse in didSet"
    /// rule doesn't apply). An unconditional self-assignment here recurses until
    /// the stack overflows — the SIGSEGV crash seen on macOS 26. Only re-assign
    /// when the value is actually out of range, which bottoms out after one hop.
    @Published var refreshMinutes: Int {
        didSet {
            let clamped = max(1, min(refreshMinutes, 120))
            if clamped != refreshMinutes {
                refreshMinutes = clamped
                return
            }
            UserDefaults.standard.set(refreshMinutes, forKey: Self.intervalKey)
            scheduleTimer()
        }
    }

    private static let intervalKey = "refreshMinutes"
    private var timer: Timer?

    /// Near-term retry used when we have no usable snapshot yet — chiefly at
    /// login, when the app fires its first fetch before the network is up and
    /// `claude -p /usage` comes back with no limit lines. Without this we'd sit
    /// on the error until the next full `refreshMinutes` tick (up to 2 hours).
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private let retryBackoff: [TimeInterval] = [5, 15, 30, 60, 120]

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        refreshMinutes = stored == 0 ? 10 : max(1, min(stored, 120))
        scheduleTimer()
        Task { await refresh() }
    }

    /// Title shown in the menu bar, e.g. "22% used · 9:59p".
    var menuBarTitle: String {
        if let s = snapshot.session {
            return "\(s.percent)% used · \(s.resetShort)"
        }
        if lastError != nil { return "⚠" }
        return "…"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // `claude -p /usage` intermittently omits the "Current session/week"
        // limit lines (they come from a server-side fetch that occasionally
        // returns nothing) while still printing the rest of the breakdown.
        // Retry once before giving up, and never clobber a good snapshot.
        for attempt in 0..<2 {
            let result: Result<String, Error> = await Task.detached(priority: .utility) {
                do { return .success(try UsageFetcher.run(timeout: 90)) }
                catch { return .failure(error) }
            }.value

            switch result {
            case .success(let output):
                let parsed = UsageParser.parse(output)
                if parsed.session != nil || parsed.week != nil {
                    snapshot = parsed
                    lastUpdated = Date()
                    lastError = nil
                    clearRetry()
                    return
                }
                // Limit lines were absent — a transient miss. Retry once.
            case .failure(let error):
                lastError = error.localizedDescription
                scheduleRetry()
                return
            }

            if attempt == 0 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
        }

        // Both attempts came back without usage limits. Keep showing the last
        // good snapshot if we have one; only surface an error when we don't.
        if snapshot.session == nil && snapshot.week == nil {
            lastError = "Claude didn't return usage limits — try Refresh again."
            scheduleRetry()
        }
    }

    /// Queue a backoff retry while we still have nothing to show (e.g. the
    /// network wasn't ready at login). Cleared as soon as a fetch succeeds; the
    /// regular `refreshMinutes` timer keeps running independently.
    private func scheduleRetry() {
        guard snapshot.session == nil && snapshot.week == nil else {
            clearRetry()
            return
        }
        let delay = retryBackoff[min(retryAttempt, retryBackoff.count - 1)]
        retryAttempt += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    private func clearRetry() {
        retryAttempt = 0
        retryTask?.cancel()
        retryTask = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(refreshMinutes * 60)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        t.tolerance = 30
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
