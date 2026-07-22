import AppKit
import SwiftUI

enum AppTheme {
    static let separator = Color(nsColor: .separatorColor).opacity(0.72)
    static let track = Color.primary.opacity(0.10)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let cyan = Color(nsColor: .systemTeal)
    static let lime = Color(nsColor: .systemGreen)
    static let resetAccent = Color(nsColor: .systemIndigo)
    static let awakeAccent = Color(nsColor: .systemOrange)
    static let quotaHealthy = QuotaPalette(
        accent: adaptiveColor(
            light: NSColor(displayP3Red: 0.06, green: 0.56, blue: 0.30, alpha: 1),
            dark: NSColor(displayP3Red: 0.30, green: 0.84, blue: 0.51, alpha: 1)
        ),
        progressColors: [
            adaptiveColor(
                light: NSColor(displayP3Red: 0.05, green: 0.54, blue: 0.27, alpha: 1),
                dark: NSColor(displayP3Red: 0.18, green: 0.72, blue: 0.38, alpha: 1)
            ),
            adaptiveColor(
                light: NSColor(displayP3Red: 0.25, green: 0.73, blue: 0.42, alpha: 1),
                dark: NSColor(displayP3Red: 0.39, green: 0.88, blue: 0.56, alpha: 1)
            )
        ]
    )
    static let quotaAttention = QuotaPalette(
        accent: Color(nsColor: .systemOrange),
        progressColors: [Color(nsColor: .systemOrange), Color(nsColor: .systemYellow)]
    )
    static let quotaCritical = QuotaPalette(
        accent: Color(nsColor: .systemRed),
        progressColors: [Color(nsColor: .systemRed), Color(nsColor: .systemPink)]
    )

    static func quotaPalette(for remainingPercent: Int) -> QuotaPalette {
        switch remainingPercent {
        case 60...:
            quotaHealthy
        case 30..<60:
            quotaAttention
        default:
            quotaCritical
        }
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? dark
                    : light
            }
        )
    }
}

struct QuotaPalette {
    let accent: Color
    let progressColors: [Color]
}

struct AppPanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        AppTheme.cyan.opacity(colorScheme == .dark ? 0.10 : 0.065),
                        .clear,
                        AppTheme.lime.opacity(colorScheme == .dark ? 0.055 : 0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

private struct NativeGlassRenderingKey: EnvironmentKey {
    static let defaultValue = true
}

private struct SystemPopoverSurfaceKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DesignPreviewRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var nativeGlassRenderingEnabled: Bool {
        get { self[NativeGlassRenderingKey.self] }
        set { self[NativeGlassRenderingKey.self] = newValue }
    }

    var usesSystemPopoverSurface: Bool {
        get { self[SystemPopoverSurfaceKey.self] }
        set { self[SystemPopoverSurfaceKey.self] = newValue }
    }

    var designPreviewRendering: Bool {
        get { self[DesignPreviewRenderingKey.self] }
        set { self[DesignPreviewRenderingKey.self] = newValue }
    }
}

private struct AppPanelSurfaceModifier: ViewModifier {
    @Environment(\.nativeGlassRenderingEnabled) private var nativeGlassRenderingEnabled
    @Environment(\.usesSystemPopoverSurface) private var usesSystemPopoverSurface

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if usesSystemPopoverSurface {
            // NSPopover provides native Liquid Glass on macOS 26. Applying a
            // second full-panel effect here flattens the system refraction.
            content
        } else if #available(macOS 26.0, *), nativeGlassRenderingEnabled {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background {
                AppPanelBackground()
                    .clipShape(shape)
            }
        }
    }
}

extension View {
    func appPanelSurface() -> some View {
        modifier(AppPanelSurfaceModifier())
    }
}
