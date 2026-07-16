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

        let store = UsageStore(previewMode: true)
        let stayAwakeStore = StayAwakeStore(previewMode: true)
        let colorScheme: ColorScheme = CommandLine.arguments.contains("--dark") ? .dark : .light
        if CommandLine.arguments.contains("--settings") {
            let size = CGSize(width: 560, height: 330)
            try write(
                SettingsView(store: store)
                    .environment(\.colorScheme, colorScheme)
                    .environment(\.nativeGlassRenderingEnabled, false)
                    .frame(width: size.width, height: size.height),
                size: size
            )
        } else {
            let size = CGSize(width: 520, height: 690)
            try write(
                DesignPreviewView(store: store, stayAwakeStore: stayAwakeStore)
                    .environment(\.colorScheme, colorScheme)
                    .environment(\.nativeGlassRenderingEnabled, false)
                    .environment(\.designPreviewRendering, true)
                    .frame(width: size.width, height: size.height),
                size: size
            )
        }
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
