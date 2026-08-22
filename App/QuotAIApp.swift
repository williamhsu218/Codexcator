import SwiftUI

@main
struct QuotAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = UsageStore.shared
    @State private var antigravityStore = AntigravityUsageStore.shared

    var body: some Scene {
        Settings {
            SettingsView(store: store, antigravityStore: antigravityStore)
        }
    }
}
