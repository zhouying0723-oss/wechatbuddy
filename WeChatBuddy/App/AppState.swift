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

enum AccessibilityAuthorizationStatus: Equatable {
    case authorized
    case notAuthorized

    var title: String {
        switch self {
        case .authorized:
            "已授权"
        case .notAuthorized:
            "未授权"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: AppStatus = .ready
    @Published private(set) var accessibilityStatus: AccessibilityAuthorizationStatus

    private let accessibilityAuthorizer: any AccessibilityAuthorizing

    init(
        accessibilityAuthorizer: any AccessibilityAuthorizing = SystemAccessibilityAuthorizer()
    ) {
        self.accessibilityAuthorizer = accessibilityAuthorizer
        accessibilityStatus = accessibilityAuthorizer.isTrusted()
            ? .authorized
            : .notAuthorized
    }

    func refreshAccessibilityStatus() {
        accessibilityStatus = accessibilityAuthorizer.isTrusted()
            ? .authorized
            : .notAuthorized
    }

    func requestAccessibilityAccess() {
        _ = accessibilityAuthorizer.requestAccess()
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        accessibilityAuthorizer.openSystemSettings()
    }
}
