import SwiftUI

struct ResetCreditsView: View {
    let snapshot: UsageSnapshot
    var maximumVisibleRows: Int? = nil

    private var visibleCredits: [ResetCredit] {
        if let maximumVisibleRows {
            return Array(snapshot.resetCredits.prefix(maximumVisibleRows))
        }
        return snapshot.resetCredits
    }

    private var undisclosedCount: Int {
        max(0, snapshot.availableResetCount - visibleCredits.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(L10n.text("reset.title", fallback: "Usage Resets"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 8)

                Text(snapshot.availableResetCount.formatted())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .frame(minWidth: 22)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.resetAccent, in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                L10n.format(
                    "reset.accessibility_format",
                    fallback: "Usage Resets: %d",
                    snapshot.availableResetCount
                )
            )

            if visibleCredits.isEmpty, snapshot.availableResetCount > 0 {
                Text(
                    L10n.text(
                        "reset.expiry_unavailable",
                        fallback: "Expiry details unavailable"
                    )
                )
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8, alignment: .leading),
                        GridItem(.flexible(), spacing: 8, alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(visibleCredits) { credit in
                        resetCreditCell(credit)
                    }
                }
            }

            if undisclosedCount > 0 {
                Text("+\(undisclosedCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func resetCreditCell(_ credit: ResetCredit) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.resetAccent)

            Text(DisplayDateFormatter.compactDateTime(credit.expiresAt))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            AppTheme.resetAccent.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DisplayDateFormatter.expiryText(for: credit.expiresAt))
    }
}
