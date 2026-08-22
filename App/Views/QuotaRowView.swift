import SwiftUI

struct QuotaRowView: View {
    let quota: QuotaWindow
    var compact = false

    private var quotaPalette: QuotaPalette {
        AppTheme.quotaPalette(for: quota.remainingPercent)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(quota.kind.displayName)
                .font(.system(size: compact ? 13.5 : 15.5, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(
                    width: compact ? (L10n.isSimplifiedChinese ? 50 : 58) : 66,
                    alignment: .leading
                )
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                HStack(spacing: 8) {
                    QuotaProgressBar(
                        value: quota.remainingPercent
                    )

                    percentageLabel
                }

                Text(DisplayDateFormatter.resetText(for: quota.resetsAt))
                    .font(.system(size: compact ? 11 : 12.5, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
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

    @ViewBuilder
    private var percentageLabel: some View {
        if L10n.isSimplifiedChinese {
            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                Text(L10n.text("quota.remaining_prefix", fallback: "剩余"))
                    .font(.system(size: compact ? 10.5 : 12, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("\(quota.remainingPercent)")
                    .font(.system(size: compact ? 13.5 : 15.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(quotaPalette.accent)
                Text("%")
                    .font(.system(size: compact ? 10.5 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(quotaPalette.accent.opacity(0.85))
            }
            .fixedSize()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                Text("\(quota.remainingPercent)")
                    .font(.system(size: compact ? 13.5 : 15.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(quotaPalette.accent)
                Text("% left")
                    .font(.system(size: compact ? 10.5 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .fixedSize()
        }
    }
}

struct QuotaProgressBar: View {
    let value: Int

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let totalHeight = proxy.size.height
            let fillWidth = max(0, totalWidth * CGFloat(value) / 100)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.track)

                Capsule()
                    .fill(AppTheme.quotaFillGradient(for: value))
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: fillWidth)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.32), location: 0.0),
                                .init(color: .clear, location: 0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: totalHeight * 0.45)
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: fillWidth)
                    }
                    .offset(y: -totalHeight * 0.25)

                ForEach(AppTheme.quotaScaleThresholds, id: \.self) { threshold in
                    let xPos = totalWidth * threshold
                    ZStack {
                        Rectangle()
                            .fill(AppTheme.quotaThresholdMarkerEdge)
                            .frame(width: 1.5, height: totalHeight)

                        Rectangle()
                            .fill(AppTheme.quotaThresholdMarkerHighlight)
                            .frame(width: 0.75, height: totalHeight)
                            .offset(x: 0.4)
                    }
                    .position(x: xPos, y: totalHeight / 2)
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
