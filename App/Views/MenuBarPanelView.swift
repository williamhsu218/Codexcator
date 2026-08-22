import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.nativeGlassRenderingEnabled) private var nativeGlassRenderingEnabled
    @AppStorage(QuotaProvider.panelDefaultsKey)
    private var quotaProvider = QuotaProvider.codex
    @AppStorage(QuotaProvider.antigravityIntegrationDefaultsKey)
    private var antigravityIntegrationEnabled = true

    let store: UsageStore
    let antigravityStore: AntigravityUsageStore
    let stayAwakeStore: StayAwakeStore

    private var shouldShowAntigravity: Bool {
        antigravityIntegrationEnabled && (antigravityStore.isInstalled || antigravityStore.isAvailable)
    }

    private var effectiveQuotaProvider: QuotaProvider {
        quotaProvider.effectiveProvider(
            antigravityEnabled: antigravityIntegrationEnabled,
            antigravityAvailable: shouldShowAntigravity
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, shouldShowAntigravity ? 10 : 12)

            if shouldShowAntigravity {
                quotaProviderPicker
                    .padding(.bottom, 12)
            }

            quotaContent

            StayAwakeView(store: stayAwakeStore)
                .padding(.top, 10)

            Divider()
                .overlay(AppTheme.separator)
                .padding(.top, 12)

            footer
                .padding(.top, 10)
        }
        .padding(16)
        .frame(width: 340)
        .appPanelSurface()
        .task {
            store.start()
            if shouldShowAntigravity {
                antigravityStore.start()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: appMarkImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            Text(L10n.text("quota.title", fallback: "QuotAI"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 8)

            if effectiveQuotaProvider == .codex, let plan = store.snapshot?.subscriptionPlan {
                SubscriptionPlanBadge(plan: plan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quotaProviderPicker: some View {
        HStack(spacing: 2) {
            ForEach(QuotaProvider.allCases, id: \.self) { provider in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        quotaProvider = provider
                    }
                } label: {
                    Text(provider.displayName)
                        .font(.system(size: 12, weight: quotaProvider == provider ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    quotaProvider == provider
                        ? AppTheme.primaryText
                        : AppTheme.secondaryText
                )
                .background {
                    if quotaProvider == provider {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.pickerSelectedBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppTheme.pickerSelectedBorder, lineWidth: 0.5)
                            }
                            .shadow(color: AppTheme.pickerSelectedShadow, radius: 2, y: 1)
                    }
                }
                .accessibilityLabel(provider.displayName)
                .accessibilityAddTraits(
                    quotaProvider == provider ? .isSelected : []
                )
            }
        }
        .padding(2.5)
        .background(
            AppTheme.pickerTrack,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L10n.text("quota.provider", fallback: "Quota provider")
        )
    }

    @ViewBuilder
    private var quotaContent: some View {
        if effectiveQuotaProvider == .codex {
            codexQuotaContent
        } else {
            AntigravityQuotaView(store: antigravityStore)
        }
    }

    @ViewBuilder
    private var codexQuotaContent: some View {
        if let snapshot = store.snapshot {
            VStack(spacing: 10) {
                quotaSection(snapshot)

                ResetCreditsView(snapshot: snapshot)
            }
        } else {
            emptyState
        }
    }

    private var appMarkImage: NSImage {
        if let bundledImage = NSImage(named: "AppMark") {
            return bundledImage
        }
        if
            let previewURL = Bundle.main.url(
                forResource: "AppMark-master",
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
        VStack(spacing: 8) {
            ForEach(Array(snapshot.orderedQuotas.enumerated()), id: \.element.id) { index, quota in
                if index > 0 {
                    Divider()
                        .overlay(AppTheme.separator.opacity(0.5))
                }
                QuotaRowView(quota: quota, compact: true)
            }
        }
        .padding(10)
        .appCardSurface(cornerRadius: 10)
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
                Label(statusMessage(at: context.date), systemImage: statusIcon)
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
                refreshSelectedProvider()
            } label: {
                Label(
                    L10n.text("action.refresh", fallback: "Refresh"),
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(isSelectedProviderLoading)
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
        switch effectiveQuotaProvider {
        case .codex:
            switch store.phase {
            case .ready: "checkmark.circle"
            case .loading: "arrow.triangle.2.circlepath"
            case .idle, .failed: "exclamationmark.circle"
            }
        case .antigravity:
            switch antigravityStore.phase {
            case .ready: "checkmark.circle"
            case .loading: "arrow.triangle.2.circlepath"
            case .idle, .failed: "exclamationmark.circle"
            }
        }
    }

    private var isSelectedProviderLoading: Bool {
        effectiveQuotaProvider == .codex ? store.isLoading : antigravityStore.isLoading
    }

    private func statusMessage(at date: Date) -> String {
        effectiveQuotaProvider == .codex
            ? store.statusMessage(at: date)
            : antigravityStore.statusMessage(at: date)
    }

    private func refreshSelectedProvider() {
        switch effectiveQuotaProvider {
        case .codex:
            Task { await store.refresh() }
        case .antigravity:
            Task { await antigravityStore.refresh() }
        }
    }
}

private struct SubscriptionPlanBadge: View {
    let plan: SubscriptionPlan

    var body: some View {
        Text(plan.displayName)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.planBadgeText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(AppTheme.planBadgeBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.planBadgeBorder, lineWidth: 0.5)
            }
            .shadow(color: AppTheme.planBadgeShadow, radius: 3, y: 1)
            .accessibilityLabel(
                L10n.format(
                    "subscription.plan_accessibility_format",
                    fallback: "ChatGPT %@ plan",
                    plan.displayName
                )
            )
    }
}
