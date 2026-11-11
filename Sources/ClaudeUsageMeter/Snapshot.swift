import SwiftUI

/// Renders the panel with fixed sample data so the README screenshots are reproducible
/// and never expose real project names.
@MainActor
enum Snapshot {
    static func render(to directory: String) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let store = makeDemoStore()

        for (scheme, name) in [(ColorScheme.dark, "panel-dark"), (ColorScheme.light, "panel-light")] {
            let renderer = ImageRenderer(content: Canvas(store: store, scheme: scheme))
            renderer.scale = 2
            guard let tiff = renderer.nsImage?.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: URL(fileURLWithPath: directory + "/" + name + ".png"))
        }
    }

    private static func makeDemoStore() -> UsageStore {
        let now = Date()
        let payload = Payload(
            rateLimits: RateLimits(
                fiveHour: RateLimit(usedPercentage: 46, resetsAt: now.timeIntervalSince1970 + 2 * 3600 + 14 * 60),
                sevenDay: RateLimit(usedPercentage: 31, resetsAt: now.timeIntervalSince1970 + 3 * 86400 + 4 * 3600)))
        func session(_ name: String, context: Double, idleMinutes: Double) -> Session {
            Session(id: name, name: name, contextPercent: context, contextSize: 200_000,
                    lastActivity: now.addingTimeInterval(-idleMinutes * 60), reportedAt: now)
        }
        return UsageStore(demoPayload: payload, sessions: [
            session("web-app", context: 18, idleMinutes: 9),
            session("mobile-client", context: 58, idleMinutes: 38),
            session("data-pipeline", context: 91, idleMinutes: 54),
        ], now: now)
    }

    private struct Canvas: View {
        let store: UsageStore
        let scheme: ColorScheme

        private var dark: Bool { scheme == .dark }

        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Image(nsImage: MenuBarIcon.image(for: store, labelColor: dark ? .white : .black))
                }
                .padding(.horizontal, 14)
                .frame(width: 340, height: 28)
                .background(Color(white: dark ? 0.1 : 0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                UsagePanel(store: store)
                    .background(Color(white: dark ? 0.17 : 0.97), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }
            .padding(28)
            .background(LinearGradient(colors: dark ? [Color(white: 0.07), Color(white: 0.12)]
                                                    : [Color(white: 0.92), Color(white: 0.97)],
                                       startPoint: .top, endPoint: .bottom))
            .environment(\.colorScheme, scheme)
        }
    }
}
