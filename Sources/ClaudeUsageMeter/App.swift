import SwiftUI

@main
struct ClaudeUsageMeterApp: App {
    @StateObject private var store = UsageStore()

    init() {
        // `ClaudeUsageMeter --snapshot <dir>` renders the documentation screenshots and exits.
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--snapshot"), flag + 1 < args.count {
            let directory = args[flag + 1]
            MainActor.assumeIsolated { Snapshot.render(to: directory) }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: store))
        }
        .menuBarExtraStyle(.window)
    }
}
