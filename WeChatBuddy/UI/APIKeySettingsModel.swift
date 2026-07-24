import Foundation

enum APIKeySettingsStatus: Equatable {
    case unknown
    case notSaved
    case saved
    case failure(String)

    var title: String {
        switch self {
        case .unknown:
            "正在检查…"
        case .notSaved:
            "未保存"
        case .saved:
            "已安全保存到 Keychain"
        case let .failure(message):
            "操作失败：\(message)"
        }
    }
}

@MainActor
final class APIKeySettingsModel: ObservableObject {
    @Published var input = ""
    @Published private(set) var status: APIKeySettingsStatus = .unknown

    private let store: any APIKeyStoring

    init(store: any APIKeyStoring) {
        self.store = store
    }

    var canSave: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refresh() {
        do {
            status = try store.loadAPIKey() == nil ? .notSaved : .saved
        } catch {
            status = .failure(errorMessage(for: error))
        }
    }

    func save() {
        do {
            try store.saveAPIKey(input)
            input = ""
            status = .saved
        } catch {
            status = .failure(errorMessage(for: error))
        }
    }

    func delete() {
        do {
            try store.deleteAPIKey()
            input = ""
            status = .notSaved
        } catch {
            status = .failure(errorMessage(for: error))
        }
    }

    private func errorMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
