import SwiftUI

struct StayAwakeView: View {
    @Environment(\.designPreviewRendering) private var designPreviewRendering
    let store: StayAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: store.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.isActive ? .white : AppTheme.awakeAccent)
                    .frame(width: 26, height: 26)
                    .background(
                        store.isActive
                            ? AppTheme.awakeAccent
                            : AppTheme.awakeAccent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                Text(L10n.text("awake.title", fallback: "Stay Awake"))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 8)

                toggleControl
            }

            HStack(spacing: 8) {
                Label(statusText, systemImage: store.isActive ? "bolt.fill" : "moon.zzz")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.isActive ? AppTheme.awakeAccent : AppTheme.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }

            HStack(spacing: 7) {
                modeMenu
                Spacer(minLength: 4)
                durationMenu
            }
        }
        .padding(10)
        .appCardSurface(
            cornerRadius: 10,
            tintColor: AppTheme.awakeAccent,
            isActive: store.isActive
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.isActive },
            set: { store.setEnabled($0) }
        )
    }

    private var toggleControl: some View {
        Toggle("", isOn: enabledBinding)
            .labelsHidden()
            .toggleStyle(AwakeSwitchToggleStyle())
            .accessibilityLabel(L10n.text("awake.title", fallback: "Stay Awake"))
    }

    @ViewBuilder
    private var modeMenu: some View {
        if designPreviewRendering {
            modeMenuLabel
        } else {
            Menu {
                ForEach(StayAwakeMode.allCases) { mode in
                    Button {
                        store.selectMode(mode)
                    } label: {
                        if mode == store.selectedMode {
                            Label(mode.localizedTitle, systemImage: "checkmark")
                        } else {
                            Text(mode.localizedTitle)
                        }
                    }
                }
            } label: {
                modeMenuLabel
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L10n.text("awake.mode", fallback: "Display behavior"))
        }
    }

    private var modeMenuLabel: some View {
        menuLabel(
            title: store.selectedMode.localizedTitle,
            systemImage: store.selectedMode.preventsDisplaySleep ? "display" : "display.2"
        )
    }

    @ViewBuilder
    private var durationMenu: some View {
        if designPreviewRendering {
            durationMenuLabel
        } else {
            Menu {
                ForEach(StayAwakeDuration.allCases) { duration in
                    Button {
                        store.selectDuration(duration)
                    } label: {
                        if duration == store.selectedDuration {
                            Label(duration.localizedTitle, systemImage: "checkmark")
                        } else {
                            Text(duration.localizedTitle)
                        }
                    }
                }
            } label: {
                durationMenuLabel
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L10n.text("awake.duration", fallback: "Duration"))
        }
    }

    private var durationMenuLabel: some View {
        menuLabel(title: store.selectedDuration.localizedTitle, systemImage: "clock")
    }

    private func menuLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppTheme.primaryText)
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    store.isActive
                        ? AppTheme.awakeAccent.opacity(0.12)
                        : AppTheme.pickerTrack
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    store.isActive
                        ? LinearGradient(
                            colors: [
                                AppTheme.awakeAccent.opacity(0.35),
                                AppTheme.awakeAccent.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : AppTheme.cardSpecularBorder,
                    lineWidth: 0.5
                )
        }
    }

    private var statusText: String {
        guard store.isActive else {
            return L10n.text("awake.status_off", fallback: "Off · Mac sleeps normally")
        }
        guard let expiresAt = store.expiresAt else {
            return L10n.text("awake.status_indefinite", fallback: "On until turned off")
        }
        return L10n.format(
            "awake.status_until_format",
            fallback: "On until %@",
            DisplayDateFormatter.localTime(expiresAt)
        )
    }
}

private struct AwakeSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(
                    configuration.isOn
                        ? AppTheme.awakeAccent
                        : Color.primary.opacity(0.14)
                )
                .frame(width: 40, height: 22)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            Color.primary.opacity(configuration.isOn ? 0.06 : 0.14),
                            lineWidth: 0.5
                        )
                }
                .overlay {
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                        .offset(x: configuration.isOn ? 9 : -9)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.16), value: configuration.isOn)
    }
}

private extension StayAwakeMode {
    var localizedTitle: String {
        L10n.text(titleLocalizationKey, fallback: titleFallback)
    }

    var titleLocalizationKey: String {
        switch self {
        case .allowDisplaySleep: "awake.mode_allow_display_sleep"
        case .keepDisplayAwake: "awake.mode_keep_display_awake"
        }
    }

    var titleFallback: String {
        switch self {
        case .allowDisplaySleep: "Allow display sleep"
        case .keepDisplayAwake: "Keep display awake"
        }
    }
}

private extension StayAwakeDuration {
    var localizedTitle: String {
        switch self {
        case .fiveMinutes:
            L10n.text("awake.duration_5m", fallback: "5 minutes")
        case .tenMinutes:
            L10n.text("awake.duration_10m", fallback: "10 minutes")
        case .fifteenMinutes:
            L10n.text("awake.duration_15m", fallback: "15 minutes")
        case .thirtyMinutes:
            L10n.text("awake.duration_30m", fallback: "30 minutes")
        case .oneHour:
            L10n.text("awake.duration_1h", fallback: "1 hour")
        case .twoHours:
            L10n.text("awake.duration_2h", fallback: "2 hours")
        case .fiveHours:
            L10n.text("awake.duration_5h", fallback: "5 hours")
        case .indefinitely:
            L10n.text("awake.duration_indefinite", fallback: "Indefinitely")
        }
    }
}
