import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private lazy var store = UsageStore.shared
    private lazy var antigravityStore = AntigravityUsageStore.shared
    private lazy var stayAwakeStore = StayAwakeStore.shared
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.willhsu.QuotAI",
        category: "Lifecycle"
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        migrateLegacyPreferencesIfNeeded()
        restoreSystemStatusItemVisibility()
        installStatusItem()
        configurePopover()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(usageSnapshotDidChange),
            name: .codexUsageSnapshotDidChange,
            object: store
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stayAwakeStateDidChange),
            name: .stayAwakeStateDidChange,
            object: stayAwakeStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(antigravityUsageSnapshotDidChange),
            name: .antigravityUsageSnapshotDidChange,
            object: antigravityStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarQuotaPreferencesDidChange),
            name: .menuBarQuotaPreferencesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(antigravityIntegrationPreferenceDidChange),
            name: .antigravityIntegrationPreferenceDidChange,
            object: nil
        )
        stayAwakeStore.start()
        updateStatusItemAppearance()
        store.start()
        if antigravityIntegrationEnabled {
            antigravityStore.start()
        }
        logger.info("Application did finish launching with AppKit status item")
    }

    private func migrateLegacyPreferencesIfNeeded() {
        if QuotAIPreferenceMigration.migrate() {
            logger.info("Migrated legacy preferences into QuotAI")
        }
    }

    private func restoreSystemStatusItemVisibility() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "NSStatusItem VisibleCC QuotAIQuotaStatus")
        defaults.set(true, forKey: "NSStatusItem Visible QuotAIQuotaStatus")
        defaults.set(true, forKey: "NSStatusItem VisibleCC CodexQuotaStatus")
        defaults.set(true, forKey: "NSStatusItem Visible CodexQuotaStatus")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        stopOutsideClickMonitor()
        antigravityStore.stop()
        stayAwakeStore.shutdown()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            logger.error("Unable to create the AppKit status item button")
            return
        }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "QuotAI"
        button.setAccessibilityLabel("QuotAI")
        item.autosaveName = "QuotAIQuotaStatus"
        item.isVisible = true
        statusItem = item
        updateStatusItemAppearance()
        perform(#selector(logStatusItemGeometry), with: nil, afterDelay: 1)
        logger.info("Installed AppKit status item")
    }

    private func configurePopover() {
        let hostingController = NSHostingController(
            rootView: MenuBarPanelView(
                store: store,
                antigravityStore: antigravityStore,
                stayAwakeStore: stayAwakeStore
            )
                .environment(\.usesSystemPopoverSurface, true)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hostingController
    }

    func popoverDidShow(_ notification: Notification) {
        startOutsideClickMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            logger.info("Closed quota popover")
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // An accessory app has no activatable window until the popover is
            // shown. Activate immediately afterwards, before AppKit commits the
            // first frame, so Liquid Glass starts in its active appearance.
            NSApp.activate(ignoringOtherApps: true)
            makePopoverKeyWindow()
        }
    }

    private func makePopoverKeyWindow() {
        guard let window = popover.contentViewController?.view.window else {
            logger.error("Popover was shown without a backing window")
            return
        }
        window.makeKey()
        logger.info(
            "Opened active quota popover; appActive=\(NSApp.isActive, privacy: .public), windowKey=\(window.isKeyWindow, privacy: .public)"
        )
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismissPopoverAfterOutsideClick()
            }
        }
        logger.info("Started outside-click monitoring")
    }

    private func stopOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
        logger.info("Stopped outside-click monitoring")
    }

    private func dismissPopoverAfterOutsideClick() {
        guard outsideClickMonitor != nil, popover.isShown else { return }
        stopOutsideClickMonitor()
        popover.performClose(nil)
        logger.info("Closed quota popover after outside click")
    }

    @objc private func usageSnapshotDidChange() {
        updateStatusItemAppearance()
    }

    @objc private func antigravityUsageSnapshotDidChange() {
        updateStatusItemAppearance()
    }

    @objc private func stayAwakeStateDidChange() {
        updateStatusItemAppearance()
        logger.info(
            "Updated Stay Awake menu bar indicator; visible=\(self.stayAwakeStore.isActive, privacy: .public)"
        )
    }

    @objc private func menuBarQuotaPreferencesDidChange() {
        updateStatusItemAppearance()
        logger.info(
            "Updated menu bar quota display; provider=\(self.effectiveMenuBarQuotaProvider.rawValue, privacy: .public), mode=\(self.menuBarQuotaDisplayMode.rawValue, privacy: .public)"
        )
    }

    @objc private func antigravityIntegrationPreferenceDidChange() {
        if antigravityIntegrationEnabled {
            antigravityStore.start()
        } else {
            antigravityStore.stop()
        }
        updateStatusItemAppearance()
        logger.info(
            "Updated Antigravity integration; enabled=\(self.antigravityIntegrationEnabled, privacy: .public)"
        )
    }

    @objc private func logStatusItemGeometry() {
        guard let statusItem, let button = statusItem.button else { return }
        let window = button.window
        let windowFrame = window?.frame ?? .zero
        let screenName = window?.screen?.localizedName ?? "none"
        let screenFrame = window?.screen?.frame ?? .zero
        let windowLevel = window?.level.rawValue ?? 0
        let occlusionState = window?.occlusionState.rawValue ?? 0
        logger.info(
            "Status item ready; visible=\(statusItem.isVisible, privacy: .public), titleCharacterCount=\(button.title.count, privacy: .public), hasImage=\(button.image != nil, privacy: .public), buttonWidth=\(button.frame.width, privacy: .public), windowVisible=\(window?.isVisible ?? false, privacy: .public), windowAlpha=\(window?.alphaValue ?? 0, privacy: .public), windowLevel=\(windowLevel, privacy: .public), occlusionState=\(occlusionState, privacy: .public), screen=\(screenName, privacy: .public), windowFrame=\(NSStringFromRect(windowFrame), privacy: .public), screenFrame=\(NSStringFromRect(screenFrame), privacy: .public)"
        )
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }

        let presentation = menuBarPresentation
        let title = presentation.title
        button.title = title
        button.image = menuBarStatusImage()
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown

        let awakeStatus = L10n.text(
            "awake.menu_bar_active",
            fallback: "Stay Awake on"
        )
        let toolTip = stayAwakeStore.isActive
            ? "QuotAI · \(presentation.detail) · \(awakeStatus)"
            : "QuotAI · \(presentation.detail)"
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
    }

    private func menuBarStatusImage() -> NSImage? {
        if stayAwakeStore.isActive {
            return stayAwakeStatusImage()
        }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let symbol = NSImage(
            systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
            accessibilityDescription: "QuotAI"
        ) {
            let img = symbol.withSymbolConfiguration(config) ?? symbol
            img.isTemplate = true
            return img
        }
        return nil
    }

    private var menuBarQuotaDisplayMode: MenuBarQuotaDisplayMode {
        let rawValue = UserDefaults.standard.string(
            forKey: MenuBarQuotaDisplayMode.defaultsKey
        )
        return rawValue.flatMap(MenuBarQuotaDisplayMode.init(rawValue:)) ?? .both
    }

    private var menuBarQuotaProvider: QuotaProvider {
        let rawValue = UserDefaults.standard.string(
            forKey: QuotaProvider.menuBarDefaultsKey
        )
        return rawValue.flatMap(QuotaProvider.init(rawValue:)) ?? .codex
    }

    private var antigravityIntegrationEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = QuotaProvider.antigravityIntegrationDefaultsKey
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    private var effectiveMenuBarQuotaProvider: QuotaProvider {
        menuBarQuotaProvider.effectiveProvider(
            antigravityEnabled: antigravityIntegrationEnabled,
            antigravityAvailable: antigravityStore.isInstalled
        )
    }

    private var menuBarPresentation: (title: String, detail: String) {
        switch effectiveMenuBarQuotaProvider {
        case .codex:
            let title = store.snapshot?.menuBarTitle(for: menuBarQuotaDisplayMode) ?? "--"
            return (title, "Codex · \(title)")
        case .antigravity:
            let groupID = UserDefaults.standard.string(
                forKey: AntigravityQuotaGroup.menuBarGroupDefaultsKey
            )
            guard let group = antigravityStore.snapshot?.group(id: groupID) else {
                return ("AG --", "Antigravity · --")
            }
            let title = group.menuBarTitle(for: menuBarQuotaDisplayMode)
            return (title, "Antigravity · \(group.localizedDisplayName) · \(title)")
        }
    }

    private func stayAwakeStatusImage() -> NSImage? {
        let description = L10n.text(
            "awake.menu_bar_active",
            fallback: "Stay Awake on"
        )
        guard let baseImage = NSImage(
            systemSymbolName: "cup.and.saucer.fill",
            accessibilityDescription: description
        ) else {
            return nil
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let image = baseImage.withSymbolConfiguration(configuration) ?? baseImage
        image.isTemplate = true
        return image
    }
}
