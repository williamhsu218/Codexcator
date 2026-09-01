import SwiftUI

struct AntigravityQuotaView: View {
    let store: AntigravityUsageStore

    var body: some View {
        if let snapshot = store.snapshot {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.compact) {
                ForEach(snapshot.groups) { group in
                    quotaGroup(group)
                }
            }
        } else {
            emptyState
        }
    }

    private func quotaGroup(_ group: AntigravityQuotaGroup) -> some View {
        let accent = groupAccent(for: group.id)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: AppTheme.Spacing.small) {
                Text(group.localizedDisplayName)
                    .font(.system(size: AppTheme.TypeSize.cardTitle, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()
            }

            VStack(spacing: AppTheme.Spacing.small) {
                ForEach(Array(group.orderedQuotas.enumerated()), id: \.element.id) { index, quota in
                    if index > 0 {
                        Divider()
                            .overlay(AppTheme.separator.opacity(0.5))
                    }
                    QuotaRowView(quota: quota, compact: true)
                }
            }
        }
        .padding(AppTheme.Spacing.compact)
        .appCardSurface(cornerRadius: 10)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accent)
                .frame(width: 2)
                .padding(.vertical, AppTheme.Spacing.compact)
                .padding(.leading, 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func groupAccent(for groupID: String) -> Color {
        switch groupID {
        case "gemini":
            return AppTheme.cyan
        default:
            return AppTheme.lime
        }
    }

    private var emptyState: some View {
        QuotaEmptyState(
            isLoading: store.isLoading,
            title: store.isLoading
                ? L10n.text(
                    "empty.antigravity_loading",
                    fallback: "Reading Antigravity quota…"
                )
                : L10n.text(
                    "empty.antigravity_failed",
                    fallback: "Antigravity quota unavailable"
                ),
            detail: store.statusMessage
        ) {
            Task { await store.refresh() }
        }
    }
}
