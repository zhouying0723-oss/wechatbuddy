import Foundation

enum AppStatus: Equatable {
    case ready

    var title: String {
        switch self {
        case .ready:
            "就绪"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: AppStatus = .ready
}
