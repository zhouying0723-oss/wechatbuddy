import XCTest
@testable import WeChatBuddy

final class APIKeySettingsTests: XCTestCase {
    func testValidatorTrimsAPIKey() throws {
        XCTAssertEqual(
            try APIKeyValidator.validated("  test-key\n"),
            "test-key"
        )
    }

    func testValidatorRejectsBlankAPIKey() {
        XCTAssertThrowsError(try APIKeyValidator.validated(" \n")) { error in
            XCTAssertEqual(error as? APIKeyValidationError, .empty)
        }
    }

    @MainActor
    func testRefreshDoesNotExposeStoredAPIKey() {
        let store = APIKeyStoreMock(apiKey: "stored-test-key")
        let model = APIKeySettingsModel(store: store)

        model.refresh()

        XCTAssertEqual(model.status, .saved)
        XCTAssertTrue(model.input.isEmpty)
    }

    @MainActor
    func testSaveClearsInputAndStoresTrimmedAPIKey() {
        let store = APIKeyStoreMock()
        let model = APIKeySettingsModel(store: store)
        model.input = "  test-key  "

        model.save()

        XCTAssertEqual(store.apiKey, "test-key")
        XCTAssertEqual(model.status, .saved)
        XCTAssertTrue(model.input.isEmpty)
    }

    @MainActor
    func testDeleteRemovesStoredAPIKey() {
        let store = APIKeyStoreMock(apiKey: "stored-test-key")
        let model = APIKeySettingsModel(store: store)

        model.delete()

        XCTAssertNil(store.apiKey)
        XCTAssertEqual(model.status, .notSaved)
    }
}

private final class APIKeyStoreMock: APIKeyStoring, @unchecked Sendable {
    var apiKey: String?

    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
        apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        self.apiKey = try APIKeyValidator.validated(apiKey)
    }

    func deleteAPIKey() throws {
        apiKey = nil
    }
}
