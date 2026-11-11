import SwiftUI

// MARK: - Claude Code payload
// Subset of the JSON that Claude Code pipes to the status line command.
// Every field is optional: the payload varies by plan and Claude Code version.

struct RateLimit: Decodable {
    var usedPercentage: Double?
    var resetsAt: Double?          // Unix epoch, seconds
}

struct RateLimits: Decodable {
    var fiveHour: RateLimit?
    var sevenDay: RateLimit?
}

struct ContextWindow: Decodable {
    var usedPercentage: Double?
    var contextWindowSize: Double? // tokens
}

struct Payload: Decodable {
    var sessionId: String?
    var transcriptPath: String?
    var rateLimits: RateLimits?
    var contextWindow: ContextWindow?
}

/// Entry of Claude Code's live-process registry (`~/.claude/sessions/<pid>.json`).
struct ProcessEntry: Decodable {
    var pid: Int32?
    var sessionId: String?
    var cwd: String?
}

// MARK: - Session

struct Session: Identifiable {
    let id: String
    let name: String
    let contextPercent: Double
    let contextSize: Double?
    /// Last real activity (transcript modification time); drives the prompt caching countdown.
    let lastActivity: Date?
    /// When the status line last reported for this session.
    let reportedAt: Date

    var isIdle: Bool { Date().timeIntervalSince(reportedAt) > 600 }
}

// MARK: - Health

enum Health {
    case healthy, attention, heavy, newSession

    init(percent: Double) {
        switch percent {
        case ..<50: self = .healthy
        case ..<80: self = .attention
        case ..<96: self = .heavy
        default: self = .newSession
        }
    }

    var title: String {
        switch self {
        case .healthy: "Healthy session"
        case .attention: "Attention"
        case .heavy: "Heavy session"
        case .newSession: "Time for a new session"
        }
    }

    var color: Color {
        switch self {
        case .healthy: .green
        case .attention: .yellow
        case .heavy: .orange
        case .newSession: .red
        }
    }

    var symbol: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .heavy: "flame.circle.fill"
        case .newSession: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

// MARK: - Prompt caching

/// Estimated state of the prompt cache, assuming a fixed TTL counted from the last activity.
enum CacheState {
    case active(minutes: Int), cooling(minutes: Int), ending(minutes: Int), expired

    static let ttl: TimeInterval = 3600

    init(lastActivity: Date, now: Date = Date()) {
        let remaining = Int(Self.ttl - now.timeIntervalSince(lastActivity))
        let minutes = max(0, (remaining + 59) / 60)
        switch remaining {
        case 1801...: self = .active(minutes: minutes)
        case 601...: self = .cooling(minutes: minutes)
        case 1...: self = .ending(minutes: minutes)
        default: self = .expired
        }
    }

    var emoji: String {
        switch self {
        case .active: "🔥"
        case .cooling: "💨"
        case .ending, .expired: "💀"
        }
    }

    var label: String {
        switch self {
        case .active(let m): "active \(m) min"
        case .cooling(let m): "cooling \(m) min"
        case .ending(let m): "ending \(m) min"
        case .expired: "expired"
        }
    }

    var color: Color {
        switch self {
        case .active: .orange
        case .cooling: .secondary
        case .ending, .expired: .red
        }
    }
}

// MARK: - Formatting

enum Format {
    static func tokens(_ n: Double) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", n / 1_000_000) : "\(Int((n / 1000).rounded()))k"
    }
}
