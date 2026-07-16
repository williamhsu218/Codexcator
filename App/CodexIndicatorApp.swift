import SwiftUI

@main
struct CodexcatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = UsageStore.shared

    var body: some Scene {
        Settings {
            SettingsView(store: store)
        }
    }
}
