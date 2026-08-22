import AppKit
import SwiftUI

@main
struct DesignPreviewApp: App {
    @State private var store = UsageStore(previewMode: true)
    @State private var antigravityStore = AntigravityUsageStore(previewMode: true)
    @State private var stayAwakeStore = StayAwakeStore(previewMode: true)

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("QuotAI Design Preview") {
            DesignPreviewView(
                store: store,
                antigravityStore: antigravityStore,
                stayAwakeStore: stayAwakeStore
            )
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(store: store, antigravityStore: antigravityStore)
        }
    }
}
