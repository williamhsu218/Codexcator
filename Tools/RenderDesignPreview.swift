import AppKit
import SwiftUI

@main
@MainActor
struct RenderDesignPreview {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            fputs("usage: RenderDesignPreview <output.png>\n", stderr)
            exit(2)
        }

        let provider: QuotaProvider = CommandLine.arguments.contains("--antigravity")
            ? .antigravity
            : .codex
        UserDefaults.standard.set(provider.rawValue, forKey: QuotaProvider.panelDefaultsKey)
        UserDefaults.standard.set(provider.rawValue, forKey: QuotaProvider.menuBarDefaultsKey)
        if provider == .antigravity {
            UserDefaults.standard.set(
                "gemini",
                forKey: AntigravityQuotaGroup.menuBarGroupDefaultsKey
            )
        }

        let store = UsageStore(
            previewMode: true,
            previewSnapshot: CommandLine.arguments.contains("--sparse")
                ? sparseCodexSnapshot
                : nil
        )
        let antigravityStore = AntigravityUsageStore(previewMode: true)
        let stayAwakeStore = StayAwakeStore(previewMode: true)
        let colorScheme: ColorScheme = CommandLine.arguments.contains("--dark") ? .dark : .light
        if CommandLine.arguments.contains("--settings") {
            let size = CGSize(width: 480, height: 420)
            let initialTab: SettingsTab = CommandLine.arguments.contains("--about") ? .about : .general
            try write(
                SettingsView(
                    store: store,
                    antigravityStore: antigravityStore,
                    initialTab: initialTab
                )
                    .environment(\.colorScheme, colorScheme)
                    .environment(\.nativeGlassRenderingEnabled, false)
                    .frame(width: size.width, height: size.height),
                size: size
            )
        } else {
            let size = CGSize(width: 520, height: 760)
            try write(
                DesignPreviewView(
                    store: store,
                    antigravityStore: antigravityStore,
                    stayAwakeStore: stayAwakeStore
                )
                    .environment(\.colorScheme, colorScheme)
                    .environment(\.nativeGlassRenderingEnabled, false)
                    .environment(\.designPreviewRendering, true)
                    .frame(width: size.width, height: size.height),
                size: size
            )
        }
    }

    private static var sparseCodexSnapshot: UsageSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = timeZone
            components.year = 2026
            components.month = 9
            components.day = day
            components.hour = hour
            components.minute = minute
            return components.date!
        }

        return UsageSnapshot(
            fetchedAt: date(1, 16, 0),
            fiveHour: nil,
            sevenDay: QuotaWindow(
                kind: .sevenDay,
                remainingPercent: 75,
                resetsAt: date(7, 10, 29)
            ),
            subscriptionPlan: SubscriptionPlan(identifier: "prolite"),
            availableResetCount: 1,
            resetCredits: [
                ResetCredit(
                    grantedAt: date(1, 8, 23),
                    expiresAt: date(21, 8, 23),
                    status: "available"
                )
            ]
        )
    }

    private static func write<Content: View>(_ content: Content, size: CGSize) throws {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2

        guard let image = renderer.cgImage else {
            fputs("could not render preview\n", stderr)
            exit(1)
        }
        let representation = NSBitmapImageRep(cgImage: image)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            fputs("could not encode design preview\n", stderr)
            exit(1)
        }

        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
