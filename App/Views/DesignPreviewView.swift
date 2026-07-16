import AppKit
import SwiftUI

struct DesignPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    let store: UsageStore
    let stayAwakeStore: StayAwakeStore

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                if stayAwakeStore.isActive {
                    Image(systemName: "cup.and.saucer.fill")
                        .accessibilityLabel(
                            L10n.text("awake.menu_bar_active", fallback: "Stay Awake on")
                        )
                }
                Text(store.snapshot?.menuBarTitle ?? "Codex --")
            }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))

            MenuBarPanelView(store: store, stayAwakeStore: stayAwakeStore)
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
        }
        .padding(44)
        .foregroundStyle(AppTheme.primaryText)
        .background { previewBackdrop }
    }

    private var previewBackdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [
                    AppTheme.cyan.opacity(colorScheme == .dark ? 0.22 : 0.18),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 430
            )
            RadialGradient(
                colors: [
                    AppTheme.lime.opacity(colorScheme == .dark ? 0.15 : 0.12),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 390
            )
        }
    }
}
