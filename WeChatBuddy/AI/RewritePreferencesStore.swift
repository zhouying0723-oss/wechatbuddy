import Foundation

protocol RewritePreferencesStoring: Sendable {
    func loadTone() -> RewriteTone
    func saveTone(_ tone: RewriteTone)
}

struct UserDefaultsRewritePreferencesStore: RewritePreferencesStoring {
    private static let toneKey = "rewritePreferences.tone"
    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func loadTone() -> RewriteTone {
        userDefaults.string(forKey: Self.toneKey)
            .flatMap(RewriteTone.init(rawValue:))
            ?? .natural
    }

    func saveTone(_ tone: RewriteTone) {
        userDefaults.set(tone.rawValue, forKey: Self.toneKey)
    }

    private var userDefaults: UserDefaults {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        return .standard
    }
}
