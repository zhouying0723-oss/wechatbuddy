import Foundation

struct ModelChatRequest: Equatable, Sendable {
    let systemPrompt: String
    let userText: String
}

struct ModelChatResult: Equatable, Sendable {
    let text: String
}

protocol ModelAPIRequesting: Sendable {
    func complete(_ request: ModelChatRequest) async throws -> ModelChatResult
}

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum ModelAPIClientError: LocalizedError, Equatable {
    case invalidEndpoint
    case invalidAPIKey
    case invalidHTTPResponse
    case cancelled
    case timedOut
    case networkUnavailable
    case networkError(String)
    case rateLimited(retryAfterSeconds: Int?, message: String)
    case httpError(statusCode: Int, message: String)
    case responseDecodingFailed
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "模型服务地址无效"
        case .invalidAPIKey:
            "尚未配置有效的 API Key"
        case .invalidHTTPResponse:
            "模型服务返回了无效的网络响应"
        case .cancelled:
            "模型请求已取消"
        case .timedOut:
            "模型请求超时，请稍后重试"
        case .networkUnavailable:
            "无法连接模型服务，请检查网络连接和 Base URL"
        case let .networkError(message):
            "模型服务网络请求失败：\(message)"
        case let .rateLimited(retryAfterSeconds, message):
            if let retryAfterSeconds {
                "请求过于频繁，请在 \(retryAfterSeconds) 秒后重试：\(message)"
            } else {
                "请求过于频繁，请稍后重试：\(message)"
            }
        case let .httpError(statusCode, message):
            "模型服务请求失败（HTTP \(statusCode)）：\(message)"
        case .responseDecodingFailed:
            "无法解析模型服务响应"
        case .emptyContent:
            "模型服务没有返回文本内容"
        }
    }
}

struct URLSessionHTTPTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelAPIClientError.invalidHTTPResponse
        }
        return (data, httpResponse)
    }
}

struct ModelAPIClient: ModelAPIRequesting {
    private let configuration: ModelProviderConfiguration
    private let apiKey: String
    private let transport: any HTTPTransport
    private let timeout: TimeInterval

    init(
        configuration: ModelProviderConfiguration,
        apiKey: String,
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        timeout: TimeInterval = 30
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.transport = transport
        self.timeout = timeout
    }

    func complete(_ request: ModelChatRequest) async throws -> ModelChatResult {
        let urlRequest = try makeURLRequest(for: request)
        guard !Task.isCancelled else {
            throw ModelAPIClientError.cancelled
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: urlRequest)
        } catch {
            throw mappedTransportError(error)
        }
        guard !Task.isCancelled else {
            throw ModelAPIClientError.cancelled
        }

        if response.statusCode == 429 {
            let apiError = try? JSONDecoder().decode(
                APIErrorEnvelope.self,
                from: data
            )
            throw ModelAPIClientError.rateLimited(
                retryAfterSeconds: retryAfterSeconds(from: response),
                message: redacted(apiError?.error.message ?? "已达到服务限流")
            )
        }

        guard (200 ... 299).contains(response.statusCode) else {
            let apiError = try? JSONDecoder().decode(
                APIErrorEnvelope.self,
                from: data
            )
            throw ModelAPIClientError.httpError(
                statusCode: response.statusCode,
                message: redacted(apiError?.error.message ?? "未知错误")
            )
        }

        guard
            let envelope = try? JSONDecoder().decode(
                ChatCompletionEnvelope.self,
                from: data
            )
        else {
            throw ModelAPIClientError.responseDecodingFailed
        }

        guard
            let content = envelope.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !content.isEmpty
        else {
            throw ModelAPIClientError.emptyContent
        }

        return ModelChatResult(text: content)
    }

    private func makeURLRequest(
        for chatRequest: ModelChatRequest
    ) throws -> URLRequest {
        let validatedKey = try? APIKeyValidator.validated(apiKey)
        guard let validatedKey else {
            throw ModelAPIClientError.invalidAPIKey
        }

        guard let endpoint = URL(
            string: "\(configuration.baseURL)/chat/completions"
        ) else {
            throw ModelAPIClientError.invalidEndpoint
        }

        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(validatedKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequestBody(
                model: configuration.modelID,
                messages: [
                    .init(role: "system", content: chatRequest.systemPrompt),
                    .init(role: "user", content: chatRequest.userText)
                ],
                stream: false,
                thinking: .init(type: "disabled"),
                maxTokens: 512
            )
        )
        return request
    }

    private func redacted(_ message: String) -> String {
        guard !apiKey.isEmpty else {
            return message
        }
        return message.replacingOccurrences(
            of: apiKey,
            with: "[已隐藏]"
        )
    }

    private func mappedTransportError(_ error: Error) -> ModelAPIClientError {
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .networkError(error.localizedDescription)
        }

        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return .networkUnavailable
        default:
            return .networkError(urlError.localizedDescription)
        }
    }

    private func retryAfterSeconds(
        from response: HTTPURLResponse
    ) -> Int? {
        guard
            let value = response.value(forHTTPHeaderField: "Retry-After"),
            let seconds = Int(value),
            seconds >= 0
        else {
            return nil
        }
        return seconds
    }
}

private struct ChatCompletionRequestBody: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Thinking: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
    let thinking: Thinking
    let maxTokens: Int

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case thinking
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
