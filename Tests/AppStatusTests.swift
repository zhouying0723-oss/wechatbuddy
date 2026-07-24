import Carbon
import XCTest
@testable import WeChatBuddy

final class AppStatusTests: XCTestCase {
    func testReadyStatusHasLocalizedTitle() {
        XCTAssertEqual(AppStatus.ready.title, "就绪")
    }

    func testRewriteShortcutUsesCommandShiftR() {
        XCTAssertEqual(RewriteHotKey.standard.keyCode, UInt32(kVK_ANSI_R))
        XCTAssertEqual(RewriteHotKey.standard.modifiers, UInt32(cmdKey | shiftKey))
    }

    func testRewriteShortcutMatchesOnlyItsRegisteredIdentifier() {
        XCTAssertTrue(
            RewriteHotKey.standard.matches(
                EventHotKeyID(
                    signature: RewriteHotKey.signature,
                    id: RewriteHotKey.identifier
                )
            )
        )
        XCTAssertFalse(
            RewriteHotKey.standard.matches(
                EventHotKeyID(
                    signature: RewriteHotKey.signature,
                    id: RewriteHotKey.identifier + 1
                )
            )
        )
    }

    @MainActor
    func testAccessibilityStatusIsAuthorizedWhenServiceIsTrusted() {
        let authorizer = AccessibilityAuthorizerMock(isTrusted: true)
        let state = AppState(accessibilityAuthorizer: authorizer)

        XCTAssertEqual(state.accessibilityStatus, .authorized)
    }

    @MainActor
    func testRequestRefreshesAccessibilityStatus() {
        let authorizer = AccessibilityAuthorizerMock(isTrusted: false)
        let state = AppState(accessibilityAuthorizer: authorizer)

        authorizer.trusted = true
        state.requestAccessibilityAccess()

        XCTAssertEqual(state.accessibilityStatus, .authorized)
        XCTAssertEqual(authorizer.requestCount, 1)
    }

    @MainActor
    func testWeChatStatusIsFrontmostWhenDetectorMatches() {
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: true)
        )

        XCTAssertEqual(state.weChatFrontmostStatus, .frontmost)
    }

    @MainActor
    func testWeChatStatusRefreshesWhenFrontmostApplicationChanges() {
        let detector = WeChatApplicationDetectorMock(isFrontmost: false)
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: detector
        )

        detector.isFrontmost = true
        state.refreshWeChatFrontmostStatus()

        XCTAssertEqual(state.weChatFrontmostStatus, .frontmost)
    }

    func testFrontmostHistoryKeepsWeChatWhenMenuBarAppActivates() {
        var history = FrontmostApplicationHistory(
            ownBundleIdentifier: "com.wechatbuddy.app",
            targetBundleIdentifier: "com.tencent.xinWeChat",
            currentBundleIdentifier: "com.tencent.xinWeChat"
        )

        history.record(bundleIdentifier: "com.wechatbuddy.app")

        XCTAssertTrue(history.isTargetMostRecentExternalApplication)
    }

    func testFrontmostHistoryChangesForAnotherExternalApplication() {
        var history = FrontmostApplicationHistory(
            ownBundleIdentifier: "com.wechatbuddy.app",
            targetBundleIdentifier: "com.tencent.xinWeChat",
            currentBundleIdentifier: "com.tencent.xinWeChat"
        )

        history.record(bundleIdentifier: "com.apple.dt.Xcode")

        XCTAssertFalse(history.isTargetMostRecentExternalApplication)
    }

    func testWindowOrderFindsWeChatBehindMenuBarApplication() {
        let bundleIdentifier = FrontmostExternalApplicationResolver.resolve(
            ownBundleIdentifier: "com.wechatbuddy.app",
            windowOwnerBundleIdentifiers: [
                "com.wechatbuddy.app",
                "com.tencent.xinWeChat",
                "com.apple.dt.Xcode"
            ],
            workspaceFrontmostBundleIdentifier: "com.wechatbuddy.app",
            fallbackBundleIdentifier: "com.apple.dt.Xcode"
        )

        XCTAssertEqual(bundleIdentifier, "com.tencent.xinWeChat")
    }

    func testResolverFallsBackToActivationHistoryWithoutWindowInformation() {
        let bundleIdentifier = FrontmostExternalApplicationResolver.resolve(
            ownBundleIdentifier: "com.wechatbuddy.app",
            windowOwnerBundleIdentifiers: [],
            workspaceFrontmostBundleIdentifier: "com.wechatbuddy.app",
            fallbackBundleIdentifier: "com.tencent.xinWeChat"
        )

        XCTAssertEqual(bundleIdentifier, "com.tencent.xinWeChat")
    }

    func testNoFocusedValueHasActionableErrorMessage() {
        XCTAssertEqual(
            WeChatInputReaderError.editableElementUnavailable(
                "扫描 10 个控件"
            ).errorDescription,
            "在微信当前窗口中找不到可编辑输入框（扫描 10 个控件）"
        )
    }

    func testWeChatProcessPathMustBeInsideOfficialApplicationBundle() {
        XCTAssertTrue(
            WeChatProcessDiscovery.isExecutablePath(
                "/Applications/WeChat.app/Contents/MacOS/WeChatAppEx Helper",
                insideBundleAtPath: "/Applications/WeChat.app"
            )
        )
        XCTAssertFalse(
            WeChatProcessDiscovery.isExecutablePath(
                "/tmp/WeChat.app/Contents/MacOS/WeChatAppEx Helper",
                insideBundleAtPath: "/Applications/WeChat.app"
            )
        )
    }

    func testClipboardDraftValidationReturnsCopiedText() throws {
        XCTAssertEqual(
            try ClipboardDraftValidator.validate(
                copiedText: "测试草稿",
                clipboardChanged: true
            ),
            "测试草稿"
        )
    }

    func testClipboardDraftValidationRejectsUnchangedClipboard() {
        XCTAssertThrowsError(
            try ClipboardDraftValidator.validate(
                copiedText: "旧剪贴板内容",
                clipboardChanged: false
            )
        ) { error in
            XCTAssertEqual(error as? ClipboardDraftReaderError, .clipboardUnchanged)
        }
    }

    func testClipboardDraftValidationRejectsEmptyDraft() {
        XCTAssertThrowsError(
            try ClipboardDraftValidator.validate(
                copiedText: " \n",
                clipboardChanged: true
            )
        ) { error in
            XCTAssertEqual(error as? ClipboardDraftReaderError, .emptyDraft)
        }
    }

    func testClipboardCopyRetriesUntilMaximumAttempt() {
        let policy = ClipboardCopyRetryPolicy(maximumAttempts: 3)

        XCTAssertTrue(
            policy.shouldRetry(clipboardChanged: false, completedAttempts: 1)
        )
        XCTAssertFalse(
            policy.shouldRetry(clipboardChanged: true, completedAttempts: 1)
        )
        XCTAssertFalse(
            policy.shouldRetry(clipboardChanged: false, completedAttempts: 3)
        )
    }

    func testDraftWriteValidationRejectsEmptyReplacement() {
        XCTAssertThrowsError(
            try WeChatDraftWriteValidator.validate(" \n")
        ) { error in
            XCTAssertEqual(error as? WeChatInputWriterError, .emptyReplacement)
        }
    }

    @MainActor
    func testRewriteShortcutStartsCoordinator() async {
        let hotKeyService = HotKeyServiceMock()
        let coordinator = RewriteCoordinatorMock()
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: true),
            hotKeyService: hotKeyService,
            rewriteCoordinator: coordinator
        )

        hotKeyService.trigger()
        for _ in 0 ..< 10 where state.rewriteWorkflowStatus == .processing {
            await Task.yield()
        }

        XCTAssertEqual(state.rewriteWorkflowStatus, .success)
        XCTAssertEqual(coordinator.rewriteCount, 1)
        XCTAssertEqual(hotKeyService.registrationCount, 1)
    }

    @MainActor
    func testReadWeChatDraftDoesNotReadWhenWeChatIsNotFrontmost() {
        let reader = WeChatInputReaderMock(result: .success("不应读取"))
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: false),
            weChatInputReader: reader
        )

        let message = state.readWeChatDraft()

        XCTAssertEqual(
            state.draftReadStatus,
            .failure("请先将微信切换到前台并点击输入框")
        )
        XCTAssertEqual(message, "读取失败：请先将微信切换到前台并点击输入框")
        XCTAssertEqual(reader.readCount, 0)
    }

    @MainActor
    func testWriteTestDraftAddsVisiblePrefix() {
        let writer = WeChatInputWriterMock()
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: true),
            weChatInputReader: WeChatInputReaderMock(result: .success("测试草稿")),
            weChatInputWriter: writer,
            hotKeyService: HotKeyServiceMock()
        )

        let message = state.testWriteWeChatDraft()

        XCTAssertEqual(writer.writtenTexts, ["【写回测试】测试草稿"])
        XCTAssertEqual(state.draftWriteStatus, .success)
        XCTAssertEqual(message, "写回成功，请在微信中确认")
    }
}

private final class AccessibilityAuthorizerMock: AccessibilityAuthorizing, @unchecked Sendable {
    var trusted: Bool
    private(set) var requestCount = 0

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    func isTrusted() -> Bool {
        trusted
    }

    func requestAccess() -> Bool {
        requestCount += 1
        return trusted
    }

    func openSystemSettings() {}
}

@MainActor
private final class WeChatApplicationDetectorMock: WeChatApplicationDetecting {
    var isFrontmost: Bool

    init(isFrontmost: Bool) {
        self.isFrontmost = isFrontmost
    }

    func detect() -> WeChatApplicationDetection {
        WeChatApplicationDetection(
            isFrontmost: isFrontmost,
            detectedBundleIdentifier: isFrontmost
                ? SystemWeChatApplicationDetector.bundleIdentifier
                : "com.apple.dt.Xcode"
        )
    }
}

@MainActor
private final class WeChatInputReaderMock: WeChatInputReading {
    let result: Result<String, Error>
    private(set) var readCount = 0

    init(result: Result<String, Error>) {
        self.result = result
    }

    func readFocusedDraft() throws -> String {
        readCount += 1
        return try result.get()
    }
}

@MainActor
private final class WeChatInputWriterMock: WeChatInputWriting {
    private(set) var writtenTexts: [String] = []

    func writeFocusedDraft(_ text: String) throws {
        writtenTexts.append(text)
    }
}

@MainActor
private final class HotKeyServiceMock: HotKeyHandling {
    private(set) var registrationCount = 0
    private var handler: (@MainActor () -> Void)?

    func registerRewriteShortcut(handler: @escaping @MainActor () -> Void) throws {
        registrationCount += 1
        self.handler = handler
    }

    func unregisterRewriteShortcut() {
        handler = nil
    }

    func trigger() {
        handler?()
    }
}

@MainActor
private final class RewriteCoordinatorMock: RewriteCoordinating {
    private(set) var isProcessing = false
    private(set) var rewriteCount = 0

    func rewriteFocusedDraft() async throws -> RewriteResult {
        isProcessing = true
        rewriteCount += 1
        isProcessing = false
        return RewriteResult(text: "优化草稿")
    }
}
