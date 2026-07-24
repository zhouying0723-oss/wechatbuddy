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

    func isWeChatFrontmost() -> Bool {
        isFrontmost
    }
}
