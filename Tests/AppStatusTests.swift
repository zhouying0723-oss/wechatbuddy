import XCTest
@testable import WeChatBuddy

final class AppStatusTests: XCTestCase {
    func testReadyStatusHasLocalizedTitle() {
        XCTAssertEqual(AppStatus.ready.title, "就绪")
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

    @MainActor
    func testReadWeChatDraftShowsTextWhenRequirementsAreMet() {
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: true),
            weChatInputReader: WeChatInputReaderMock(result: .success("测试草稿"))
        )

        state.readWeChatDraft()

        XCTAssertEqual(state.draftReadStatus, .success("测试草稿"))
    }

    @MainActor
    func testReadWeChatDraftDoesNotReadWhenWeChatIsNotFrontmost() {
        let reader = WeChatInputReaderMock(result: .success("不应读取"))
        let state = AppState(
            accessibilityAuthorizer: AccessibilityAuthorizerMock(isTrusted: true),
            weChatApplicationDetector: WeChatApplicationDetectorMock(isFrontmost: false),
            weChatInputReader: reader
        )

        state.readWeChatDraft()

        XCTAssertEqual(
            state.draftReadStatus,
            .failure("请先将微信切换到前台并点击输入框")
        )
        XCTAssertEqual(reader.readCount, 0)
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
