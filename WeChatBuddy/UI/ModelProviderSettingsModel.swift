import Foundation

enum ModelProviderSettingsStatus: Equatable {
    case ready
    case saved
    case failure(String)

    var title: String {
        switch self {
        case .ready:
            "请填写模型 ID"
        case .saved:
            "模型配置已保存"
        case let .failure(message):
            "配置错误：\(message)"
        }
    }
}

@MainActor
final class ModelProviderSettingsModel: ObservableObject {
    @Published var provider: ModelProvider = .volcanoArk
    @Published var baseURL =
        ModelProviderConfiguration.volcanoArkDefaultBaseURL
    @Published var modelID = ""
    @Published private(set) var status: ModelProviderSettingsStatus = .ready

    private let store: any ModelProviderSettingsStoring

    init(store: any ModelProviderSettingsStoring) {
        self.store = store
    }

    func refresh() {
        let configuration = store.loadConfiguration()
        provider = configuration.provider
        baseURL = configuration.baseURL
        modelID = configuration.modelID
        status = modelID.isEmpty ? .ready : .saved
    }

    func save() {
        do {
            let configuration = try ModelProviderConfigurationValidator.validated(
                provider: provider,
                baseURL: baseURL,
                modelID: modelID
            )
            store.saveConfiguration(configuration)
            baseURL = configuration.baseURL
            modelID = configuration.modelID
            status = .saved
        } catch {
            status = .failure(
                (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            )
        }
    }
}
