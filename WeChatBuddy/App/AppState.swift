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

enum WeChatFrontmostStatus: Equatable {
    case frontmost
    case notFrontmost

    var title: String {
        switch self {
        case .frontmost:
            "是"
        case .notFrontmost:
            "否"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: AppStatus = .ready
    @Published private(set) var accessibilityStatus: AccessibilityAuthorizationStatus
    @Published private(set) var weChatFrontmostStatus: WeChatFrontmostStatus

    private let accessibilityAuthorizer: any AccessibilityAuthorizing
    private let weChatApplicationDetector: any WeChatApplicationDetecting

    init(
        accessibilityAuthorizer: any AccessibilityAuthorizing = SystemAccessibilityAuthorizer(),
        weChatApplicationDetector: any WeChatApplicationDetecting = SystemWeChatApplicationDetector()
    ) {
        self.accessibilityAuthorizer = accessibilityAuthorizer
        self.weChatApplicationDetector = weChatApplicationDetector
        accessibilityStatus = accessibilityAuthorizer.isTrusted()
            ? .authorized
            : .notAuthorized
        weChatFrontmostStatus = weChatApplicationDetector.isWeChatFrontmost()
            ? .frontmost
            : .notFrontmost
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

    func refreshWeChatFrontmostStatus() {
        weChatFrontmostStatus = weChatApplicationDetector.isWeChatFrontmost()
            ? .frontmost
            : .notFrontmost
    }
}
