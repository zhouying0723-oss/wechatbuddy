import Foundation

protocol RewritePreferencesStoring: Sendable {
    func loadTone() -> RewriteTone
    func saveTone(_ tone: RewriteTone)
    func loadCustomInstruction() -> String
    func saveCustomInstruction(_ instruction: String)
}

struct UserDefaultsRewritePreferencesStore: RewritePreferencesStoring {
    private static let toneKey = "rewritePreferences.tone"
    private static let customInstructionKey =
        "rewritePreferences.customInstruction"

    static let defaultCustomInstruction =
        "保持表达自然，不添加原文没有的表情、称呼或信息。"
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

    func loadCustomInstruction() -> String {
        userDefaults.string(forKey: Self.customInstructionKey)
            ?? Self.defaultCustomInstruction
    }

    func saveCustomInstruction(_ instruction: String) {
        userDefaults.set(
            instruction.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: Self.customInstructionKey
        )
    }

    private var userDefaults: UserDefaults {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        return .standard
    }
}
