import Foundation
import Testing

@Test("English and Simplified Chinese localization resources stay in sync")
func localizationResourcesStayInSync() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let english = try loadStrings(
        at: projectRoot.appendingPathComponent("Resources/en.lproj/Localizable.strings")
    )
    let simplifiedChinese = try loadStrings(
        at: projectRoot.appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")
    )

    #expect(!english.isEmpty)
    #expect(Set(english.keys) == Set(simplifiedChinese.keys))

    for key in english.keys {
        let englishValue = try #require(english[key])
        let chineseValue = try #require(simplifiedChinese[key])
        #expect(!englishValue.isEmpty)
        #expect(!chineseValue.isEmpty)
        #expect(formatTokens(in: englishValue) == formatTokens(in: chineseValue))
    }
}

private func loadStrings(at url: URL) throws -> [String: String] {
    let data = try Data(contentsOf: url)
    return try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
    )
}

private func formatTokens(in value: String) -> [String] {
    let pattern = #"%(?:\d+\$)?[@d]|%%"#
    let expression = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(value.startIndex..., in: value)
    return expression.matches(in: value, range: range).compactMap { match in
        Range(match.range, in: value).map { String(value[$0]) }
    }
}
