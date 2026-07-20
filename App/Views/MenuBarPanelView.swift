import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.nativeGlassRenderingEnabled) private var nativeGlassRenderingEnabled
    let store: UsageStore
    let stayAwakeStore: StayAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)

            if let snapshot = store.snapshot {
                quotaSection(snapshot)

                Divider()
                    .overlay(AppTheme.separator)
                    .padding(.vertical, 14)

                ResetCreditsView(snapshot: snapshot)
            } else {
                emptyState
            }

            Divider()
                .overlay(AppTheme.separator)
                .padding(.vertical, 14)

            StayAwakeView(store: stayAwakeStore)

            Divider()
                .overlay(AppTheme.separator)
                .padding(.top, 14)

            footer
                .padding(.top, 10)
        }
        .padding(18)
        .frame(width: 340)
        .appPanelSurface()
        .task { store.start() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            Text(L10n.text("quota.title", fallback: "Codex Quota"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var appIconImage: NSImage {
        if
            let previewURL = Bundle.main.url(
                forResource: "AppIcon-master",
                withExtension: "png"
            ),
            let previewImage = NSImage(contentsOf: previewURL)
        {
            return previewImage
        }
        return NSApplication.shared.applicationIconImage
    }

    @ViewBuilder
    private func quotaSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(snapshot.orderedQuotas.enumerated()), id: \.element.id) { index, quota in
                if index > 0 {
                    Divider().overlay(AppTheme.separator)
                }
                QuotaRowView(quota: quota, compact: true)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                store.isLoading
                    ? L10n.text("empty.loading", fallback: "Reading Codex quota…")
                    : L10n.text("empty.failed", fallback: "Quota unavailable")
            )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text(store.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Label(store.statusMessage(at: context.date), systemImage: statusIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            footerActions
        }
        .font(.system(size: 12, weight: .medium))
    }

    @ViewBuilder
    private var footerActions: some View {
        if #available(macOS 26.0, *), nativeGlassRenderingEnabled {
            GlassEffectContainer(spacing: 8) {
                actionButtons
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .foregroundStyle(AppTheme.primaryText)
            }
        } else {
            actionButtons
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.refresh() }
            } label: {
                Label(
                    L10n.text("action.refresh", fallback: "Refresh"),
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(store.isLoading)
            .help(L10n.text("action.refresh", fallback: "Refresh"))

            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(
                    L10n.text("action.settings", fallback: "Settings"),
                    systemImage: "gearshape"
                )
            }
            .help(L10n.text("action.settings", fallback: "Settings"))
        }
    }

    private var statusIcon: String {
        switch store.phase {
        case .ready: "checkmark.circle"
        case .loading: "arrow.triangle.2.circlepath"
        case .idle, .failed: "exclamationmark.circle"
        }
    }
}
