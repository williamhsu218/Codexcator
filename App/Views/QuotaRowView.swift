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
                    value: quota.remainingPercent
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
    private let thresholds: [CGFloat] = [0.30, 0.60]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.track)

                Capsule()
                    .fill(AppTheme.quotaScaleGradient)
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: filledWidth(in: proxy.size.width))
                    }

                ForEach(thresholds, id: \.self) { threshold in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(AppTheme.quotaThresholdMarker)
                        .frame(width: 1, height: 10)
                        .position(
                            x: proxy.size.width * threshold,
                            y: proxy.size.height / 2
                        )
                }
            }
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth * CGFloat(value) / 100)
    }
}
