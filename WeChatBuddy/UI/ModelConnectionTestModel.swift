import Foundation

enum ModelConnectionTestStatus: Equatable {
    case idle
    case testing
    case success
    case cancelled
    case failure(String)

    var title: String {
        switch self {
        case .idle:
            "保存模型配置和 API Key 后可测试真实连接"
        case .testing:
            "正在连接火山方舟…"
        case .success:
            "连接成功，API Key 与模型配置可用"
        case .cancelled:
            "连接测试已取消"
        case let .failure(message):
            "连接失败：\(message)"
        }
    }
}

@MainActor
final class ModelConnectionTestModel: ObservableObject {
    @Published private(set) var status: ModelConnectionTestStatus = .idle

    private let tester: any ModelConnectionTesting
    private var currentTask: Task<ModelChatResult, Error>?

    init(tester: any ModelConnectionTesting) {
        self.tester = tester
    }

    var isTesting: Bool {
        status == .testing
    }

    var copyableErrorMessage: String? {
        guard case let .failure(message) = status else {
            return nil
        }
        return message
    }

    func testConnection() async {
        guard !isTesting else {
            return
        }

        status = .testing
        let task = Task {
            try await tester.testConnection()
        }
        currentTask = task

        do {
            _ = try await task.value
            try Task.checkCancellation()
            status = .success
        } catch is CancellationError {
            status = .cancelled
        } catch ModelAPIClientError.cancelled {
            status = .cancelled
        } catch {
            status = .failure(
                (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            )
        }
        currentTask = nil
    }

    func cancel() {
        guard isTesting else {
            return
        }
        currentTask?.cancel()
        status = .cancelled
    }
}
