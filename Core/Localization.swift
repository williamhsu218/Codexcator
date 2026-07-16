import Foundation

public enum L10n {
    public static var isSimplifiedChinese: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true
    }

    public static var locale: Locale {
        Locale(identifier: isSimplifiedChinese ? "zh_CN" : "en_US")
    }

    public static func text(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: "Localizable")
    }

    public static func format(
        _ key: String,
        fallback: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, fallback: fallback),
            locale: locale,
            arguments: arguments
        )
    }
}
