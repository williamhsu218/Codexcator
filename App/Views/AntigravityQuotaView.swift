import SwiftUI

struct AntigravityQuotaView: View {
    let store: AntigravityUsageStore

    var body: some View {
        if let snapshot = store.snapshot {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.groups) { group in
                    quotaGroup(group)
                }
            }
        } else {
            emptyState
        }
    }

    private func quotaGroup(_ group: AntigravityQuotaGroup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Circle()
                    .fill(groupAccent(for: group.id))
                    .frame(width: 6, height: 6)

                Text(group.localizedDisplayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(Array(group.orderedQuotas.enumerated()), id: \.element.id) { index, quota in
                    if index > 0 {
                        Divider()
                            .overlay(AppTheme.separator.opacity(0.5))
                    }
                    QuotaRowView(quota: quota, compact: true)
                }
            }
        }
        .padding(10)
        .appCardSurface(cornerRadius: 10)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(
                store.isLoading
                    ? L10n.text(
                        "empty.antigravity_loading",
                        fallback: "Reading Antigravity quota…"
                    )
                    : L10n.text(
                        "empty.antigravity_failed",
                        fallback: "Antigravity quota unavailable"
                    )
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
}
