import SwiftUI

// MARK: - Usage ring

struct UsageRing: View {
    let title: String
    let percent: Double
    let resetsIn: String

    private var color: Color { Health(percent: percent).color }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(percent, 100) / 100)
                    .stroke(AngularGradient(colors: [color.opacity(0.6), color], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: percent)
                VStack(spacing: 0) {
                    Text("\(Int(percent.rounded()))")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)

            Text(title).font(.headline)
            Label(resetsIn, systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .medium))
                .imageScale(.large)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session row

struct SessionRow: View {
    let session: Session
    let health: Health

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: health.symbol)
                .font(.system(size: 26))
                .foregroundStyle(health.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(health.title).foregroundStyle(health.color)
                    if session.isIdle { Text("· idle").foregroundStyle(.secondary) }
                }
                .font(.system(size: 12))

                if let lastActivity = session.lastActivity {
                    let cache = CacheState(lastActivity: lastActivity)
                    HStack(spacing: 6) {
                        Text(cache.emoji).font(.system(size: 16))
                        Text(cache.label).foregroundStyle(cache.color)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(session.contextPercent.rounded()))%")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(contextCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(session.isIdle ? 0.65 : 1)
    }

    private var contextCaption: String {
        guard let size = session.contextSize else { return "context" }
        return "\(Format.tokens(size * session.contextPercent / 100)) of \(Format.tokens(size))"
    }
}

// MARK: - Panel

struct UsagePanel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 18) {
            if store.hasLimits { limits } else { waiting }
            sessionList
            footer
        }
        .padding(20)
        .frame(width: 340)
    }

    private var limits: some View {
        HStack(alignment: .top, spacing: 8) {
            UsageRing(title: "5-hour window",
                      percent: store.fiveHourPercent,
                      resetsIn: store.timeUntil(store.payload?.rateLimits?.fiveHour?.resetsAt))
            UsageRing(title: "Week",
                      percent: store.weeklyPercent,
                      resetsIn: store.timeUntil(store.payload?.rateLimits?.sevenDay?.resetsAt))
        }
    }

    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass").font(.system(size: 30)).foregroundStyle(.secondary)
            Text("Waiting for data").font(.headline)
            Text("Limits appear after Claude Code's first response.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(store.sessions.count == 1 ? "1 session open" : "\(store.sessions.count) sessions open",
                  systemImage: "terminal")
                .font(.system(size: 14, weight: .semibold))
                .imageScale(.large)

            if store.sessions.isEmpty {
                Text("No active session yet.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(store.sessions) { SessionRow(session: $0, health: store.health(of: $0)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            if store.isStale && store.hasLimits {
                Label("No recent updates", systemImage: "wifi.slash").font(.footnote).foregroundStyle(.orange)
            } else if let updatedAt = store.updatedAt {
                Text("Updated \(updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Invisible button: gives the panel a ⌘Q shortcut without a visible control.
            Button("") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
                .opacity(0)
                .frame(width: 0, height: 0)
        }
    }
}
