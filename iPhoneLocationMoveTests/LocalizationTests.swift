import XCTest
@testable import iPhoneLocationMove

@MainActor
final class LocalizationTests: XCTestCase {
    func testNewStoreDefaultsToEnglish() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer { defaults.removePersistentDomain(forName: #function) }

        let store = AppLanguageStore(defaults: defaults)

        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(
            L10n.text(.language, language: store.language),
            "Language"
        )
    }

    func testSelectedLanguagePersistsAndHasThaiTranslations() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer { defaults.removePersistentDomain(forName: #function) }

        let store = AppLanguageStore(defaults: defaults)
        store.setLanguage(.thai)

        XCTAssertEqual(store.language, .thai)
        XCTAssertEqual(
            AppLanguageStore(defaults: defaults).language,
            .thai
        )
        XCTAssertEqual(L10n.text(.language, language: .thai), "ภาษา")
        XCTAssertNotEqual(
            L10n.text(.mapAndRoute, language: .english),
            L10n.text(.mapAndRoute, language: .thai)
        )
    }
}
