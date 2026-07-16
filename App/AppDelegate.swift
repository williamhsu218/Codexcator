import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = UsageStore.shared
    private let stayAwakeStore = StayAwakeStore.shared
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    private let logger = Logger(
        subsystem: "com.willhsu.CodexQuota",
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
        stayAwakeStore.start()
        updateStatusItemAppearance()
        store.start()
        logger.info("Application did finish launching with AppKit status item")
    }

    private func migrateLegacyPreferencesIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "didMigrateLegacyCodexIndicatorPreferences"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let legacy = defaults.persistentDomain(
            forName: "com.willhsu.CodexIndicator"
        ) ?? [:]
        for key in ["refreshIntervalSeconds", "codexBinaryPath"]
            where defaults.object(forKey: key) == nil {
            if let value = legacy[key] {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }

    private func restoreSystemStatusItemVisibility() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "NSStatusItem VisibleCC CodexQuotaStatus")
        defaults.set(true, forKey: "NSStatusItem Visible CodexQuotaStatus")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        stopOutsideClickMonitor()
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
        button.toolTip = "Codexcator"
        button.setAccessibilityLabel("Codexcator")
        item.autosaveName = "CodexQuotaStatus"
        item.isVisible = true
        statusItem = item
        updateStatusItemAppearance()
        perform(#selector(logStatusItemGeometry), with: nil, afterDelay: 1)
        logger.info("Installed AppKit status item")
    }

    private func configurePopover() {
        let hostingController = NSHostingController(
            rootView: MenuBarPanelView(store: store, stayAwakeStore: stayAwakeStore)
        )
        hostingController.sizingOptions = [.preferredContentSize]
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
            logger.info("Opened quota popover")
        }
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

    @objc private func stayAwakeStateDidChange() {
        updateStatusItemAppearance()
        logger.info(
            "Updated Stay Awake menu bar indicator; visible=\(self.stayAwakeStore.isActive, privacy: .public)"
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
            "Status item ready; visible=\(statusItem.isVisible, privacy: .public), title=\(button.title, privacy: .public), hasImage=\(button.image != nil, privacy: .public), buttonWidth=\(button.frame.width, privacy: .public), windowVisible=\(window?.isVisible ?? false, privacy: .public), windowAlpha=\(window?.alphaValue ?? 0, privacy: .public), windowLevel=\(windowLevel, privacy: .public), occlusionState=\(occlusionState, privacy: .public), screen=\(screenName, privacy: .public), windowFrame=\(NSStringFromRect(windowFrame), privacy: .public), screenFrame=\(NSStringFromRect(screenFrame), privacy: .public)"
        )
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }

        let title = store.snapshot?.menuBarTitle ?? "--"
        button.title = title
        if stayAwakeStore.isActive {
            button.image = stayAwakeStatusImage()
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
        } else {
            button.image = nil
            button.imagePosition = .noImage
        }

        let awakeStatus = L10n.text(
            "awake.menu_bar_active",
            fallback: "Stay Awake on"
        )
        let toolTip = stayAwakeStore.isActive
            ? "Codexcator · \(title) · \(awakeStatus)"
            : "Codexcator · \(title)"
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
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
