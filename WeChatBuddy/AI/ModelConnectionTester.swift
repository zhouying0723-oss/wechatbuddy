import Foundation

protocol ModelConnectionTesting: Sendable {
    func testConnection() async throws -> ModelChatResult
}

enum ModelConnectionTestError: LocalizedError, Equatable {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先保存 API Key"
        }
    }
}

struct ModelConnectionTester: ModelConnectionTesting {
    private let apiKeyStore: any APIKeyStoring
    private let configurationStore: any ModelProviderSettingsStoring
    private let transport: any HTTPTransport

    init(
        apiKeyStore: any APIKeyStoring,
        configurationStore: any ModelProviderSettingsStoring,
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.transport = transport
    }

    func testConnection() async throws -> ModelChatResult {
        guard let apiKey = try apiKeyStore.loadAPIKey() else {
            throw ModelConnectionTestError.missingAPIKey
        }

        let storedConfiguration = configurationStore.loadConfiguration()
        let configuration = try ModelProviderConfigurationValidator.validated(
            provider: storedConfiguration.provider,
            baseURL: storedConfiguration.baseURL,
            modelID: storedConfiguration.modelID
        )
        let client = ModelAPIClient(
            configuration: configuration,
            apiKey: apiKey,
            transport: transport
        )

        return try await client.complete(
            ModelChatRequest(
                systemPrompt: "你是连接测试助手。请仅回复“连接成功”。",
                userText: "测试模型服务连接。"
            )
        )
    }
}
