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
    static let planBadgeText = adaptiveColor(
        light: NSColor(displayP3Red: 0.25, green: 0.22, blue: 0.66, alpha: 1),
        dark: NSColor(displayP3Red: 0.78, green: 0.86, blue: 1.00, alpha: 1)
    )
    static let planBadgeBackground = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(displayP3Red: 0.39, green: 0.31, blue: 0.91, alpha: 0.18),
                dark: NSColor(displayP3Red: 0.49, green: 0.43, blue: 1.00, alpha: 0.26)
            ),
            adaptiveColor(
                light: NSColor(displayP3Red: 0.08, green: 0.59, blue: 0.80, alpha: 0.15),
                dark: NSColor(displayP3Red: 0.15, green: 0.71, blue: 0.92, alpha: 0.22)
            ),
            adaptiveColor(
                light: NSColor(displayP3Red: 0.16, green: 0.68, blue: 0.48, alpha: 0.11),
                dark: NSColor(displayP3Red: 0.31, green: 0.82, blue: 0.58, alpha: 0.17)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let planBadgeBorder = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(displayP3Red: 0.37, green: 0.28, blue: 0.84, alpha: 0.46),
                dark: NSColor(displayP3Red: 0.63, green: 0.58, blue: 1.00, alpha: 0.56)
            ),
            adaptiveColor(
                light: NSColor(displayP3Red: 0.06, green: 0.57, blue: 0.76, alpha: 0.34),
                dark: NSColor(displayP3Red: 0.27, green: 0.78, blue: 0.94, alpha: 0.46)
            )
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let planBadgeShadow = adaptiveColor(
        light: NSColor(displayP3Red: 0.25, green: 0.26, blue: 0.75, alpha: 0.12),
        dark: NSColor(displayP3Red: 0.20, green: 0.65, blue: 0.92, alpha: 0.14)
    )
    static let quotaHealthy = QuotaPalette(
        accent: adaptiveColor(
            light: NSColor(displayP3Red: 0.06, green: 0.56, blue: 0.30, alpha: 1),
            dark: NSColor(displayP3Red: 0.30, green: 0.84, blue: 0.51, alpha: 1)
        )
    )
    static let quotaAttention = QuotaPalette(
        accent: Color(nsColor: .systemOrange)
    )
    static let quotaCritical = QuotaPalette(
        accent: Color(nsColor: .systemRed)
    )
    static let quotaScaleGradient = LinearGradient(
        stops: [
            .init(color: Color(nsColor: .systemRed), location: 0.00),
            .init(color: Color(nsColor: .systemRed), location: 0.27),
            .init(color: Color(nsColor: .systemOrange), location: 0.33),
            .init(color: Color(nsColor: .systemOrange), location: 0.57),
            .init(
                color: adaptiveColor(
                    light: NSColor(displayP3Red: 0.06, green: 0.56, blue: 0.30, alpha: 1),
                    dark: NSColor(displayP3Red: 0.30, green: 0.84, blue: 0.51, alpha: 1)
                ),
                location: 0.63
            ),
            .init(
                color: adaptiveColor(
                    light: NSColor(displayP3Red: 0.25, green: 0.73, blue: 0.42, alpha: 1),
                    dark: NSColor(displayP3Red: 0.39, green: 0.88, blue: 0.56, alpha: 1)
                ),
                location: 1.00
            )
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let quotaThresholdMarker = adaptiveColor(
        light: NSColor(white: 0.06, alpha: 0.40),
        dark: NSColor(white: 1.00, alpha: 0.56)
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
