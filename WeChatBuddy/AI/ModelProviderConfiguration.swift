import Foundation

enum ModelProvider: String, Codable, CaseIterable, Sendable {
    case volcanoArk

    var title: String {
        switch self {
        case .volcanoArk:
            "火山方舟"
        }
    }
}

struct ModelProviderConfiguration: Codable, Equatable, Sendable {
    static let volcanoArkDefaultBaseURL =
        "https://ark.cn-beijing.volces.com/api/v3"

    let provider: ModelProvider
    let baseURL: String
    let modelID: String

    static let defaultValue = ModelProviderConfiguration(
        provider: .volcanoArk,
        baseURL: volcanoArkDefaultBaseURL,
        modelID: ""
    )
}

enum ModelProviderConfigurationError: LocalizedError, Equatable {
    case invalidBaseURL
    case emptyModelID

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL 必须是有效的 HTTPS 地址"
        case .emptyModelID:
            "模型 ID 不能为空"
        }
    }
}

struct ModelProviderConfigurationValidator {
    static func validated(
        provider: ModelProvider,
        baseURL: String,
        modelID: String
    ) throws -> ModelProviderConfiguration {
        var normalizedBaseURL = baseURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        while normalizedBaseURL.hasSuffix("/") {
            normalizedBaseURL.removeLast()
        }

        guard
            let components = URLComponents(string: normalizedBaseURL),
            components.scheme?.lowercased() == "https",
            components.host?.isEmpty == false
        else {
            throw ModelProviderConfigurationError.invalidBaseURL
        }

        let normalizedModelID = modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedModelID.isEmpty else {
            throw ModelProviderConfigurationError.emptyModelID
        }

        return ModelProviderConfiguration(
            provider: provider,
            baseURL: normalizedBaseURL,
            modelID: normalizedModelID
        )
    }
}
