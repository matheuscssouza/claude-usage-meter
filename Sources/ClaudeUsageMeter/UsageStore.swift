import SwiftUI

/// Reads the state written by `statusline.sh` and publishes it to the UI.
///
/// Open sessions are the live processes in Claude Code's own registry; their health comes
/// from the per-session payloads the status line persists.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var payload: Payload?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var now = Date()
    @Published private(set) var sessions: [Session] = []

    private enum Paths {
        static let home = NSHomeDirectory()
        static let registry = home + "/.claude/sessions"
        static let state = home + "/.claude/usage-meter"
        static let usage = state + "/usage.json"
        static let sessions = state + "/sessions"
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let fileManager = FileManager.default
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: Derived values

    var fiveHourPercent: Double { payload?.rateLimits?.fiveHour?.usedPercentage ?? 0 }
    var weeklyPercent: Double { payload?.rateLimits?.sevenDay?.usedPercentage ?? 0 }
    /// Limits are account-wide, so the worst of the two applies to every session.
    var accountPercent: Double { max(fiveHourPercent, weeklyPercent) }
    var hasLimits: Bool { payload?.rateLimits?.fiveHour != nil }
    var isStale: Bool { updatedAt.map { now.timeIntervalSince($0) > 600 } ?? true }

    func health(of session: Session) -> Health {
        Health(percent: max(accountPercent, session.contextPercent))
    }

    var overallHealth: Health {
        Health(percent: max(accountPercent, sessions.map(\.contextPercent).max() ?? 0))
    }

    func timeUntil(_ epoch: Double?) -> String {
        guard let epoch else { return "—" }
        let seconds = max(0, Int(epoch - now.timeIntervalSince1970))
        if seconds >= 86400 { return "\(seconds / 86400) d \((seconds % 86400) / 3600) h" }
        return "\(seconds / 3600) h \(String(format: "%02d", (seconds % 3600) / 60)) min"
    }

    // MARK: Loading

    private func refresh() {
        now = Date()
        loadSessions()
        guard let payload: Payload = decode(atPath: Paths.usage) else { return }
        self.payload = payload
        updatedAt = modificationDate(atPath: Paths.usage)
    }

    private func loadSessions() {
        var result: [Session] = []
        var seen = Set<String>()

        for file in listing(Paths.registry) where file.hasSuffix(".json") {
            guard let entry: ProcessEntry = decode(atPath: Paths.registry + "/" + file),
                  let pid = entry.pid, let id = entry.sessionId,
                  kill(pid, 0) == 0,            // signal 0 only checks that the process exists
                  seen.insert(id).inserted else { continue }

            let statePath = Paths.sessions + "/" + id + ".json"
            let state: Payload? = decode(atPath: statePath)
            result.append(Session(
                id: id,
                name: ((entry.cwd ?? "Session") as NSString).lastPathComponent,
                contextPercent: state?.contextWindow?.usedPercentage ?? 0,
                contextSize: state?.contextWindow?.contextWindowSize,
                lastActivity: state?.transcriptPath.flatMap { modificationDate(atPath: $0) },
                reportedAt: modificationDate(atPath: statePath) ?? .distantPast))
        }
        sessions = result.sorted { $0.reportedAt > $1.reportedAt }
        pruneClosedSessions(keeping: seen)
    }

    /// Removes state files of sessions that are gone, after a grace period.
    private func pruneClosedSessions(keeping open: Set<String>) {
        for file in listing(Paths.sessions) where !open.contains((file as NSString).deletingPathExtension) {
            let path = Paths.sessions + "/" + file
            if let date = modificationDate(atPath: path), Date().timeIntervalSince(date) > 600 {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }

    // MARK: File helpers

    private func listing(_ path: String) -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: path)) ?? []
    }

    private func decode<T: Decodable>(atPath path: String) -> T? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? Self.decoder.decode(T.self, from: data)
    }

    private func modificationDate(atPath path: String) -> Date? {
        (try? fileManager.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }
}
