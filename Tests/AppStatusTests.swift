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
