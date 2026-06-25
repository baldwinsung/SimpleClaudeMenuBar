import Foundation
import Combine

@MainActor
final class UsageModel: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    /// Minutes between automatic refreshes. Persisted; clamped to a sane range.
    @Published var refreshMinutes: Int {
        didSet {
            refreshMinutes = max(1, min(refreshMinutes, 120))
            UserDefaults.standard.set(refreshMinutes, forKey: Self.intervalKey)
            scheduleTimer()
        }
    }

    private static let intervalKey = "refreshMinutes"
    private var timer: Timer?

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        refreshMinutes = stored == 0 ? 5 : max(1, min(stored, 120))
        scheduleTimer()
        Task { await refresh() }
    }

    /// Title shown in the menu bar, e.g. "22% · 9:59p".
    var menuBarTitle: String {
        if let s = snapshot.session {
            return "\(s.percent)% · \(s.resetShort)"
        }
        if lastError != nil { return "Claude ⚠" }
        return "Claude …"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let result: Result<String, Error> = await Task.detached(priority: .utility) {
            do { return .success(try UsageFetcher.run(timeout: 90)) }
            catch { return .failure(error) }
        }.value

        switch result {
        case .success(let output):
            let parsed = UsageParser.parse(output)
            if parsed.session == nil && parsed.week == nil {
                lastError = "Couldn't parse /usage output."
            } else {
                snapshot = parsed
                lastUpdated = Date()
                lastError = nil
            }
        case .failure(let error):
            lastError = error.localizedDescription
        }
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
