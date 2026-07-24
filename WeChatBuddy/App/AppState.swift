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

enum DraftReadStatus: Equatable {
    case idle
    case success(String)
    case failure(String)

    var title: String {
        switch self {
        case .idle:
            "尚未读取"
        case let .success(text):
            "读取成功：\(Self.preview(text))"
        case let .failure(message):
            "读取失败：\(message)"
        }
    }

    private static func preview(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > 80 else {
            return singleLine
        }

        return "\(singleLine.prefix(80))…"
    }
}

enum HotKeyStatus: Equatable {
    case registered
    case failed(String)

    var title: String {
        switch self {
        case .registered:
            "已启用（⌘⇧R）"
        case let .failed(message):
            "注册失败：\(message)"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: AppStatus = .ready
    @Published private(set) var accessibilityStatus: AccessibilityAuthorizationStatus
    @Published private(set) var weChatFrontmostStatus: WeChatFrontmostStatus
    @Published private(set) var detectedFrontmostBundleIdentifier: String?
    @Published private(set) var draftReadStatus: DraftReadStatus = .idle
    @Published private(set) var hotKeyStatus: HotKeyStatus = .registered

    private let accessibilityAuthorizer: any AccessibilityAuthorizing
    private let weChatApplicationDetector: any WeChatApplicationDetecting
    private let weChatInputReader: any WeChatInputReading
    private let hotKeyService: any HotKeyHandling

    init(
        accessibilityAuthorizer: any AccessibilityAuthorizing = SystemAccessibilityAuthorizer(),
        weChatApplicationDetector: any WeChatApplicationDetecting = SystemWeChatApplicationDetector(),
        weChatInputReader: any WeChatInputReading = SystemWeChatInputReader(),
        hotKeyService: any HotKeyHandling = SystemHotKeyService()
    ) {
        self.accessibilityAuthorizer = accessibilityAuthorizer
        self.weChatApplicationDetector = weChatApplicationDetector
        self.weChatInputReader = weChatInputReader
        self.hotKeyService = hotKeyService
        accessibilityStatus = accessibilityAuthorizer.isTrusted()
            ? .authorized
            : .notAuthorized
        let detection = weChatApplicationDetector.detect()
        weChatFrontmostStatus = detection.isFrontmost ? .frontmost : .notFrontmost
        detectedFrontmostBundleIdentifier = detection.detectedBundleIdentifier

        do {
            try hotKeyService.registerRewriteShortcut { [weak self] in
                _ = self?.readWeChatDraft()
            }
            hotKeyStatus = .registered
        } catch {
            hotKeyStatus = .failed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
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
        let detection = weChatApplicationDetector.detect()
        weChatFrontmostStatus = detection.isFrontmost ? .frontmost : .notFrontmost
        detectedFrontmostBundleIdentifier = detection.detectedBundleIdentifier
    }

    @discardableResult
    func readWeChatDraft() -> String {
        refreshAccessibilityStatus()
        refreshWeChatFrontmostStatus()

        guard accessibilityStatus == .authorized else {
            draftReadStatus = .failure("尚未获得辅助功能权限")
            return draftReadStatus.title
        }

        guard weChatFrontmostStatus == .frontmost else {
            draftReadStatus = .failure("请先将微信切换到前台并点击输入框")
            return draftReadStatus.title
        }

        do {
            draftReadStatus = .success(try weChatInputReader.readFocusedDraft())
        } catch {
            draftReadStatus = .failure(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }

        return draftReadStatus.title
    }
}
