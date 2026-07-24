import XCTest
@testable import WeChatBuddy

final class AppStatusTests: XCTestCase {
    func testReadyStatusHasLocalizedTitle() {
        XCTAssertEqual(AppStatus.ready.title, "就绪")
    }
}
