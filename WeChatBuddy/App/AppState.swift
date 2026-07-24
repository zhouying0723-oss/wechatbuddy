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

enum DraftWriteStatus: Equatable {
    case idle
    case success
    case failure(String)

    var title: String {
        switch self {
        case .idle:
            "尚未测试写回"
        case .success:
            "写回成功，请在微信中确认"
        case let .failure(message):
            "写回失败：\(message)"
        }
    }
}

enum RewriteWorkflowStatus: Equatable {
    case idle
    case processing
    case success
    case failure(String)

    var title: String {
        switch self {
        case .idle:
            "AI 改写：等待触发"
        case .processing:
            "AI 改写：处理中…"
        case .success:
            "AI 改写：已写回，请确认后手动发送"
        case let .failure(message):
            "AI 改写失败：\(message)"
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
    @Published private(set) var draftWriteStatus: DraftWriteStatus = .idle
    @Published private(set) var rewriteWorkflowStatus: RewriteWorkflowStatus =
        .idle

    private let accessibilityAuthorizer: any AccessibilityAuthorizing
    private let weChatApplicationDetector: any WeChatApplicationDetecting
    private let weChatInputReader: any WeChatInputReading
    private let weChatInputWriter: any WeChatInputWriting
    private let hotKeyService: any HotKeyHandling
    private let rewriteCoordinator: any RewriteCoordinating

    init(
        accessibilityAuthorizer: any AccessibilityAuthorizing = SystemAccessibilityAuthorizer(),
        weChatApplicationDetector: any WeChatApplicationDetecting = SystemWeChatApplicationDetector(),
        weChatInputReader: any WeChatInputReading = SystemWeChatInputReader(),
        weChatInputWriter: any WeChatInputWriting = SystemWeChatInputWriter(),
        hotKeyService: any HotKeyHandling = SystemHotKeyService(),
        rewriteCoordinator: (any RewriteCoordinating)? = nil
    ) {
        self.accessibilityAuthorizer = accessibilityAuthorizer
        self.weChatApplicationDetector = weChatApplicationDetector
        self.weChatInputReader = weChatInputReader
        self.weChatInputWriter = weChatInputWriter
        self.hotKeyService = hotKeyService
        self.rewriteCoordinator = rewriteCoordinator ?? RewriteCoordinator(
            inputReader: weChatInputReader,
            inputWriter: weChatInputWriter,
            textRewriter: ModelTextRewriter(),
            preferencesStore: UserDefaultsRewritePreferencesStore()
        )
        accessibilityStatus = accessibilityAuthorizer.isTrusted()
            ? .authorized
            : .notAuthorized
        let detection = weChatApplicationDetector.detect()
        weChatFrontmostStatus = detection.isFrontmost ? .frontmost : .notFrontmost
        detectedFrontmostBundleIdentifier = detection.detectedBundleIdentifier

        do {
            try hotKeyService.registerRewriteShortcut { [weak self] in
                self?.startRewrite()
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

    @discardableResult
    func testWriteWeChatDraft() -> String {
        let readResult = readWeChatDraft()
        guard case let .success(draft) = draftReadStatus else {
            draftWriteStatus = .failure(readResult)
            return draftWriteStatus.title
        }

        do {
            try weChatInputWriter.writeFocusedDraft("【写回测试】\(draft)")
            draftWriteStatus = .success
        } catch {
            draftWriteStatus = .failure(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }

        return draftWriteStatus.title
    }

    func startRewrite() {
        guard rewriteWorkflowStatus != .processing else {
            return
        }
        rewriteWorkflowStatus = .processing
        Task {
            await performRewrite()
        }
    }

    @discardableResult
    func rewriteWeChatDraft() async -> String {
        guard rewriteWorkflowStatus != .processing else {
            return RewriteCoordinatorError.alreadyProcessing.errorDescription!
        }
        rewriteWorkflowStatus = .processing
        await performRewrite()
        return rewriteWorkflowStatus.title
    }

    private func performRewrite() async {
        do {
            _ = try await rewriteCoordinator.rewriteFocusedDraft()
            rewriteWorkflowStatus = .success
        } catch {
            rewriteWorkflowStatus = .failure(
                (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            )
        }
    }
}
