import SwiftUI

struct SettingsView: View {
    let store: UsageStore
    @AppStorage("refreshIntervalSeconds") private var refreshInterval = 300.0
    @AppStorage("codexBinaryPath") private var codexBinaryPath = ""

    var body: some View {
        Form {
            Picker(
                L10n.text("settings.auto_refresh", fallback: "Auto-refresh"),
                selection: $refreshInterval
            ) {
                Text(L10n.text("settings.every_5_minutes", fallback: "Every 5 minutes"))
                    .tag(300.0)
                Text(L10n.text("settings.every_10_minutes", fallback: "Every 10 minutes"))
                    .tag(600.0)
                Text(L10n.text("settings.every_15_minutes", fallback: "Every 15 minutes"))
                    .tag(900.0)
            }

            TextField(
                L10n.text(
                    "settings.codex_path",
                    fallback: "Codex path"
                ),
                text: $codexBinaryPath,
                prompt: Text("/Applications/ChatGPT.app/Contents/Resources/codex")
            )
            .help(
                L10n.text(
                    "settings.codex_path_help",
                    fallback: "Leave blank to find Codex automatically."
                )
            )

            HStack {
                Text(
                    L10n.text(
                        "settings.privacy_note",
                        fallback: "Quota data stays on this Mac; login tokens are never saved."
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L10n.text("action.refresh_now", fallback: "Refresh Now")) {
                    Task { await store.refresh() }
                }
                .disabled(store.isLoading)
            }

            HStack {
                Spacer()
                Button(L10n.text("action.quit", fallback: "Quit Codexcator")) {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 290)
        .padding()
    }
}
