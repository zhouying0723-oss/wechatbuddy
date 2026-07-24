import XCTest
@testable import WeChatBuddy

final class ModelAPIClientTests: XCTestCase {
    func testBuildsAuthenticatedChatCompletionRequest() async throws {
        let transport = HTTPTransportMock(
            data: successResponse(text: "优化结果"),
            statusCode: 200
        )
        let client = makeClient(transport: transport)

        _ = try await client.complete(
            ModelChatRequest(
                systemPrompt: "系统提示",
                userText: "原始草稿"
            )
        )

        let capturedRequest = await transport.lastRequest
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-api-key"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["model"] as? String, "model-test")
        XCTAssertEqual(json["stream"] as? Bool, false)

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "系统提示")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "原始草稿")
    }

    func testParsesFirstTextChoice() async throws {
        let transport = HTTPTransportMock(
            data: successResponse(text: "  优化结果  "),
            statusCode: 200
        )

        let result = try await makeClient(transport: transport).complete(
            ModelChatRequest(systemPrompt: "提示", userText: "草稿")
        )

        XCTAssertEqual(result, ModelChatResult(text: "优化结果"))
    }

    func testMapsAPIErrorWithoutExposingAPIKey() async {
        let data = Data(
            #"{"error":{"message":"bad test-api-key","type":"invalid_request_error"}}"#
                .utf8
        )
        let transport = HTTPTransportMock(data: data, statusCode: 400)

        do {
            _ = try await makeClient(transport: transport).complete(
                ModelChatRequest(systemPrompt: "提示", userText: "草稿")
            )
            XCTFail("Expected request to fail")
        } catch {
            XCTAssertEqual(
                error as? ModelAPIClientError,
                .httpError(statusCode: 400, message: "bad [已隐藏]")
            )
            XCTAssertFalse(error.localizedDescription.contains("test-api-key"))
        }
    }

    func testRejectsMalformedSuccessResponse() async {
        let transport = HTTPTransportMock(
            data: Data(#"{"unexpected":true}"#.utf8),
            statusCode: 200
        )

        do {
            _ = try await makeClient(transport: transport).complete(
                ModelChatRequest(systemPrompt: "提示", userText: "草稿")
            )
            XCTFail("Expected decoding to fail")
        } catch {
            XCTAssertEqual(
                error as? ModelAPIClientError,
                .responseDecodingFailed
            )
        }
    }

    func testRejectsEmptyTextResponse() async {
        let transport = HTTPTransportMock(
            data: successResponse(text: " \n"),
            statusCode: 200
        )

        do {
            _ = try await makeClient(transport: transport).complete(
                ModelChatRequest(systemPrompt: "提示", userText: "草稿")
            )
            XCTFail("Expected empty response to fail")
        } catch {
            XCTAssertEqual(error as? ModelAPIClientError, .emptyContent)
        }
    }

    private func makeClient(
        transport: any HTTPTransport
    ) -> ModelAPIClient {
        ModelAPIClient(
            configuration: ModelProviderConfiguration(
                provider: .volcanoArk,
                baseURL: ModelProviderConfiguration.volcanoArkDefaultBaseURL,
                modelID: "model-test"
            ),
            apiKey: "test-api-key",
            transport: transport
        )
    }

    private func successResponse(text: String) -> Data {
        try! JSONSerialization.data(
            withJSONObject: [
                "choices": [
                    ["message": ["content": text]]
                ]
            ]
        )
    }
}

private actor HTTPTransportMock: HTTPTransport {
    private let responseData: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        responseData = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }
}
