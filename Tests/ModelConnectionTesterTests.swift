import XCTest
@testable import WeChatBuddy

final class ModelConnectionTesterTests: XCTestCase {
    func testUsesStoredCredentialsForRealClientRequest() async throws {
        let transport = ConnectionHTTPTransportMock()
        let tester = ModelConnectionTester(
            apiKeyStore: ConnectionAPIKeyStoreMock(apiKey: "stored-key"),
            configurationStore: ConnectionConfigurationStoreMock(),
            transport: transport
        )

        _ = try await tester.testConnection()

        let request = await transport.lastRequest
        XCTAssertEqual(
            request?.value(forHTTPHeaderField: "Authorization"),
            "Bearer stored-key"
        )
        XCTAssertEqual(
            request?.url?.absoluteString,
            "https://example.com/api/v3/chat/completions"
        )
    }

    func testRejectsMissingAPIKeyBeforeNetworkRequest() async {
        let transport = ConnectionHTTPTransportMock()
        let tester = ModelConnectionTester(
            apiKeyStore: ConnectionAPIKeyStoreMock(apiKey: nil),
            configurationStore: ConnectionConfigurationStoreMock(),
            transport: transport
        )

        do {
            _ = try await tester.testConnection()
            XCTFail("Expected missing API Key error")
        } catch {
            XCTAssertEqual(
                error as? ModelConnectionTestError,
                .missingAPIKey
            )
            let request = await transport.lastRequest
            XCTAssertNil(request)
        }
    }

    @MainActor
    func testSettingsModelReportsSuccess() async {
        let model = ModelConnectionTestModel(
            tester: ModelConnectionTestingMock(result: .success)
        )

        await model.testConnection()

        XCTAssertEqual(model.status, .success)
        XCTAssertFalse(model.isTesting)
    }

    @MainActor
    func testSettingsModelReportsLocalizedFailure() async {
        let model = ModelConnectionTestModel(
            tester: ModelConnectionTestingMock(result: .failure)
        )

        await model.testConnection()

        XCTAssertEqual(model.status, .failure("请先保存 API Key"))
        XCTAssertEqual(model.copyableErrorMessage, "请先保存 API Key")
        XCTAssertFalse(model.isTesting)
    }

    @MainActor
    func testSettingsModelHasNoCopyableErrorAfterSuccess() async {
        let model = ModelConnectionTestModel(
            tester: ModelConnectionTestingMock(result: .success)
        )

        await model.testConnection()

        XCTAssertNil(model.copyableErrorMessage)
    }

    @MainActor
    func testSettingsModelCanCancelRequest() async {
        let model = ModelConnectionTestModel(
            tester: ModelConnectionTestingMock(result: .waiting)
        )
        let operation = Task {
            await model.testConnection()
        }
        await Task.yield()

        model.cancel()
        await operation.value

        XCTAssertEqual(model.status, .cancelled)
        XCTAssertFalse(model.isTesting)
    }
}

private struct ConnectionAPIKeyStoreMock: APIKeyStoring {
    let apiKey: String?

    func loadAPIKey() throws -> String? {
        apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {}
    func deleteAPIKey() throws {}
}

private struct ConnectionConfigurationStoreMock:
    ModelProviderSettingsStoring
{
    func loadConfiguration() -> ModelProviderConfiguration {
        ModelProviderConfiguration(
            provider: .volcanoArk,
            baseURL: "https://example.com/api/v3",
            modelID: "model-test"
        )
    }

    func saveConfiguration(_ configuration: ModelProviderConfiguration) {}
}

private actor ConnectionHTTPTransportMock: HTTPTransport {
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (
            Data(#"{"choices":[{"message":{"content":"连接成功"}}]}"#.utf8),
            response
        )
    }
}

private struct ModelConnectionTestingMock: ModelConnectionTesting {
    enum Result {
        case success
        case failure
        case waiting
    }

    let result: Result

    func testConnection() async throws -> ModelChatResult {
        switch result {
        case .success:
            return ModelChatResult(text: "连接成功")
        case .failure:
            throw ModelConnectionTestError.missingAPIKey
        case .waiting:
            try await Task.sleep(for: .seconds(60))
            return ModelChatResult(text: "不应返回")
        }
    }
}
