import Foundation

protocol ModelProviderSettingsStoring: Sendable {
    func loadConfiguration() -> ModelProviderConfiguration
    func saveConfiguration(_ configuration: ModelProviderConfiguration)
}

struct UserDefaultsModelProviderSettingsStore: ModelProviderSettingsStoring {
    private enum Key {
        static let provider = "modelProvider.provider"
        static let baseURL = "modelProvider.baseURL"
        static let modelID = "modelProvider.modelID"
    }

    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func loadConfiguration() -> ModelProviderConfiguration {
        let defaults = userDefaults
        let storedProvider = defaults.string(forKey: Key.provider)
            .flatMap(ModelProvider.init(rawValue:))
            ?? .volcanoArk

        return ModelProviderConfiguration(
            provider: storedProvider,
            baseURL: defaults.string(forKey: Key.baseURL)
                ?? ModelProviderConfiguration.volcanoArkDefaultBaseURL,
            modelID: defaults.string(forKey: Key.modelID) ?? ""
        )
    }

    func saveConfiguration(_ configuration: ModelProviderConfiguration) {
        let defaults = userDefaults
        defaults.set(configuration.provider.rawValue, forKey: Key.provider)
        defaults.set(configuration.baseURL, forKey: Key.baseURL)
        defaults.set(configuration.modelID, forKey: Key.modelID)
    }

    private var userDefaults: UserDefaults {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        return .standard
    }
}
