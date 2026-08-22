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
            HStack(spacing: 8) {
                Text(L10n.text("reset.title", fallback: "Usage Resets"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 8)

                Text(resetCountLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .frame(minWidth: 20)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppTheme.resetAccent, in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                resetAccessibilityLabel
            )

            if resetDataUnavailable {
                Text(
                    L10n.text(
                        "reset.temporarily_unavailable",
                        fallback: "Temporarily unavailable"
                    )
                )
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondaryText)
            } else if visibleCredits.isEmpty, snapshot.availableResetCount > 0 {
                Text(
                    L10n.text(
                        "reset.expiry_unavailable",
                        fallback: "Expiry details unavailable"
                    )
                )
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6, alignment: .leading),
                        GridItem(.flexible(), spacing: 6, alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(visibleCredits) { credit in
                        resetCreditCell(credit)
                    }
                }
            }

            if undisclosedCount > 0 {
                Text("+\(undisclosedCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(10)
        .appCardSurface(cornerRadius: 10)
    }

    private var resetDataUnavailable: Bool {
        !snapshot.hasCurrentResetCreditData
            && snapshot.availableResetCount == 0
            && snapshot.resetCredits.isEmpty
    }

    private var resetCountLabel: String {
        if resetDataUnavailable { return "—" }
        return snapshot.availableResetCount.formatted()
    }

    private var resetAccessibilityLabel: String {
        if resetDataUnavailable {
            return L10n.text(
                "reset.accessibility_unavailable",
                fallback: "Usage Resets temporarily unavailable"
            )
        }
        return L10n.format(
            "reset.accessibility_format",
            fallback: "Usage Resets: %d",
            snapshot.availableResetCount
        )
    }

    private func resetCreditCell(_ credit: ResetCredit) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppTheme.resetAccent)

            Text(DisplayDateFormatter.compactDateTime(credit.expiresAt))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            AppTheme.resetAccent.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.resetAccent.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DisplayDateFormatter.expiryText(for: credit.expiresAt))
    }
}
