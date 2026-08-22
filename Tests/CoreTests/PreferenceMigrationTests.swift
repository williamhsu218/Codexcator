import Foundation
import Testing
@testable import QuotAICore

@Test("Migrates the actual CodexQuota preferences into QuotAI")
func migratesActualLegacyPreferences() throws {
    let suiteName = "QuotAIPreferenceMigrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let migrated = QuotAIPreferenceMigration.migrate(
        defaults: defaults,
        legacyDomains: [[
            MenuBarQuotaDisplayMode.defaultsKey: MenuBarQuotaDisplayMode.sevenDay.rawValue,
            QuotaProvider.menuBarDefaultsKey: QuotaProvider.antigravity.rawValue,
            QuotaProvider.panelDefaultsKey: QuotaProvider.codex.rawValue,
            AntigravityQuotaGroup.menuBarGroupDefaultsKey: "gemini",
            "stayAwakeDuration": "indefinitely"
        ]]
    )

    #expect(migrated)
    #expect(defaults.string(forKey: MenuBarQuotaDisplayMode.defaultsKey) == "sevenDay")
    #expect(defaults.string(forKey: QuotaProvider.menuBarDefaultsKey) == "antigravity")
    #expect(defaults.string(forKey: QuotaProvider.panelDefaultsKey) == "codex")
    #expect(defaults.string(forKey: AntigravityQuotaGroup.menuBarGroupDefaultsKey) == "gemini")
    #expect(defaults.string(forKey: "stayAwakeDuration") == "indefinitely")
    #expect(defaults.bool(forKey: QuotAIPreferenceMigration.migrationKey))
}

@Test("Migration preserves existing QuotAI choices and only runs once")
func preservesExistingQuotAIPreferences() throws {
    let suiteName = "QuotAIPreferenceMigrationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(MenuBarQuotaDisplayMode.fiveHour.rawValue, forKey: MenuBarQuotaDisplayMode.defaultsKey)

    #expect(QuotAIPreferenceMigration.migrate(
        defaults: defaults,
        legacyDomains: [[MenuBarQuotaDisplayMode.defaultsKey: MenuBarQuotaDisplayMode.sevenDay.rawValue]]
    ))
    #expect(defaults.string(forKey: MenuBarQuotaDisplayMode.defaultsKey) == "fiveHour")
    #expect(!QuotAIPreferenceMigration.migrate(
        defaults: defaults,
        legacyDomains: [[MenuBarQuotaDisplayMode.defaultsKey: MenuBarQuotaDisplayMode.both.rawValue]]
    ))
    #expect(defaults.string(forKey: MenuBarQuotaDisplayMode.defaultsKey) == "fiveHour")
}

@Test("Disabled or unavailable Antigravity falls back to Codex")
func resolvesEffectiveQuotaProvider() {
    #expect(
        QuotaProvider.antigravity.effectiveProvider(
            antigravityEnabled: false,
            antigravityAvailable: true
        ) == .codex
    )
    #expect(
        QuotaProvider.antigravity.effectiveProvider(
            antigravityEnabled: true,
            antigravityAvailable: false
        ) == .codex
    )
    #expect(
        QuotaProvider.antigravity.effectiveProvider(
            antigravityEnabled: true,
            antigravityAvailable: true
        ) == .antigravity
    )
}
