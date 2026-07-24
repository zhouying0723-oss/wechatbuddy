import Foundation

enum ModelTextRewriterError: LocalizedError, Equatable {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先在设置中保存 API Key"
        }
    }
}

struct ModelTextRewriter: TextRewriting {
    private let apiKeyStore: any APIKeyStoring
    private let configurationStore: any ModelProviderSettingsStoring
    private let transport: any HTTPTransport
    private let promptBuilder: RewritePromptBuilder

    init(
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        configurationStore: any ModelProviderSettingsStoring =
            UserDefaultsModelProviderSettingsStore(),
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        promptBuilder: RewritePromptBuilder = RewritePromptBuilder()
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.transport = transport
        self.promptBuilder = promptBuilder
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        guard let apiKey = try apiKeyStore.loadAPIKey() else {
            throw ModelTextRewriterError.missingAPIKey
        }
        let storedConfiguration = configurationStore.loadConfiguration()
        let configuration = try ModelProviderConfigurationValidator.validated(
            provider: storedConfiguration.provider,
            baseURL: storedConfiguration.baseURL,
            modelID: storedConfiguration.modelID
        )
        let chatRequest = try promptBuilder.makeChatRequest(from: request)
        let result = try await ModelAPIClient(
            configuration: configuration,
            apiKey: apiKey,
            transport: transport,
            timeout: 15
        ).complete(chatRequest)

        return RewriteResult(text: result.text)
    }
}
