import SwiftUI

struct QuotaRowView: View {
    let quota: QuotaWindow
    var compact = false

    private var quotaPalette: QuotaPalette {
        AppTheme.quotaPalette(for: quota.remainingPercent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 11) {
            HStack(spacing: 14) {
                Text(quota.kind.displayName)
                    .font(.system(size: compact ? 15 : 19, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(
                        width: compact ? (L10n.isSimplifiedChinese ? 53 : 64) : 72,
                        alignment: .leading
                    )

                QuotaProgressBar(
                    value: quota.remainingPercent,
                    colors: quotaPalette.progressColors
                )

                Text(
                    L10n.format(
                        "quota.remaining_format",
                        fallback: "%d%% left",
                        quota.remainingPercent
                    )
                )
                    .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(quotaPalette.accent)
                    .fixedSize()
            }

            Text(DisplayDateFormatter.resetText(for: quota.resetsAt))
                .font(.system(size: compact ? 12 : 14, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
                .padding(
                    .leading,
                    compact ? (L10n.isSimplifiedChinese ? 67 : 78) : 86
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format(
                "quota.accessibility_format",
                fallback: "%@, %d%% left, %@",
                quota.kind.displayName,
                quota.remainingPercent,
                DisplayDateFormatter.resetText(for: quota.resetsAt)
            )
        )
    }
}

struct QuotaProgressBar: View {
    let value: Int
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.track)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, proxy.size.width * CGFloat(value) / 100))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
