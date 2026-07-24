import Foundation

enum ModelConnectionTestStatus: Equatable {
    case idle
    case testing
    case success
    case failure(String)

    var title: String {
        switch self {
        case .idle:
            "保存模型配置和 API Key 后可测试真实连接"
        case .testing:
            "正在连接火山方舟…"
        case .success:
            "连接成功，API Key 与模型配置可用"
        case let .failure(message):
            "连接失败：\(message)"
        }
    }
}

@MainActor
final class ModelConnectionTestModel: ObservableObject {
    @Published private(set) var status: ModelConnectionTestStatus = .idle

    private let tester: any ModelConnectionTesting

    init(tester: any ModelConnectionTesting) {
        self.tester = tester
    }

    var isTesting: Bool {
        status == .testing
    }

    func testConnection() async {
        guard !isTesting else {
            return
        }

        status = .testing
        do {
            _ = try await tester.testConnection()
            status = .success
        } catch {
            status = .failure(
                (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            )
        }
    }
}
