import Foundation

public enum QuotAIPreferenceMigration {
    public static let migrationKey = "didMigrateLegacyQuotAIPreferencesV2"

    public static let legacyDomainNames = [
        "com.willhsu.CodexQuota",
        "com.willhsu.Codexcator",
        "com.willhsu.CodexIndicator"
    ]

    public static let migratedKeys = [
        "refreshIntervalSeconds",
        "codexBinaryPath",
        MenuBarQuotaDisplayMode.defaultsKey,
        QuotaProvider.menuBarDefaultsKey,
        QuotaProvider.panelDefaultsKey,
        AntigravityQuotaGroup.menuBarGroupDefaultsKey,
        QuotaProvider.antigravityIntegrationDefaultsKey,
        "appLanguage",
        "stayAwakeEnabled",
        "stayAwakeDuration",
        "stayAwakeExpiration",
        "stayAwakeMode"
    ]

    @discardableResult
    public static func migrate(defaults: UserDefaults = .standard) -> Bool {
        let legacyDomains = legacyDomainNames.map {
            defaults.persistentDomain(forName: $0) ?? [:]
        }
        return migrate(defaults: defaults, legacyDomains: legacyDomains)
    }

    @discardableResult
    public static func migrate(
        defaults: UserDefaults,
        legacyDomains: [[String: Any]]
    ) -> Bool {
        guard !defaults.bool(forKey: migrationKey) else { return false }

        for legacy in legacyDomains {
            for key in migratedKeys where defaults.object(forKey: key) == nil {
                if let value = legacy[key] {
                    defaults.set(value, forKey: key)
                }
            }
        }
        defaults.set(true, forKey: migrationKey)
        return true
    }
}
