import SwiftUI

@main
struct ClaudeUsageMeterApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: store))
        }
        .menuBarExtraStyle(.window)
    }
}
