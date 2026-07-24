import XCTest
@testable import WeChatBuddy

final class ModelProviderSettingsTests: XCTestCase {
    func testDefaultConfigurationUsesVolcanoArkBeijingEndpoint() {
        XCTAssertEqual(
            ModelProviderConfiguration.defaultValue,
            ModelProviderConfiguration(
                provider: .volcanoArk,
                baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                modelID: ""
            )
        )
    }

    func testValidatorNormalizesConfiguration() throws {
        let configuration = try ModelProviderConfigurationValidator.validated(
            provider: .volcanoArk,
            baseURL: " https://ark.cn-beijing.volces.com/api/v3/ ",
            modelID: " model-test "
        )

        XCTAssertEqual(
            configuration.baseURL,
            "https://ark.cn-beijing.volces.com/api/v3"
        )
        XCTAssertEqual(configuration.modelID, "model-test")
    }

    func testValidatorRejectsHTTPBaseURL() {
        XCTAssertThrowsError(
            try ModelProviderConfigurationValidator.validated(
                provider: .volcanoArk,
                baseURL: "http://example.com/api/v3",
                modelID: "model-test"
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelProviderConfigurationError,
                .invalidBaseURL
            )
        }
    }

    func testValidatorRejectsEmptyModelID() {
        XCTAssertThrowsError(
            try ModelProviderConfigurationValidator.validated(
                provider: .volcanoArk,
                baseURL: ModelProviderConfiguration.volcanoArkDefaultBaseURL,
                modelID: " "
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelProviderConfigurationError,
                .emptyModelID
            )
        }
    }

    func testUserDefaultsStoreRoundTripsConfiguration() {
        let suiteName = "ModelProviderSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsModelProviderSettingsStore(suiteName: suiteName)
        let expected = ModelProviderConfiguration(
            provider: .volcanoArk,
            baseURL: "https://example.com/api/v3",
            modelID: "model-test"
        )

        store.saveConfiguration(expected)

        XCTAssertEqual(store.loadConfiguration(), expected)
    }

    @MainActor
    func testSettingsModelSavesValidatedConfiguration() {
        let store = ModelProviderSettingsStoreMock()
        let model = ModelProviderSettingsModel(store: store)
        model.baseURL = "https://example.com/api/v3/"
        model.modelID = " model-test "

        model.save()

        XCTAssertEqual(
            store.configuration,
            ModelProviderConfiguration(
                provider: .volcanoArk,
                baseURL: "https://example.com/api/v3",
                modelID: "model-test"
            )
        )
        XCTAssertEqual(model.status, .saved)
    }
}

private final class ModelProviderSettingsStoreMock:
    ModelProviderSettingsStoring,
    @unchecked Sendable
{
    var configuration = ModelProviderConfiguration.defaultValue

    func loadConfiguration() -> ModelProviderConfiguration {
        configuration
    }

    func saveConfiguration(_ configuration: ModelProviderConfiguration) {
        self.configuration = configuration
    }
}
