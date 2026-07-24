import XCTest
@testable import WeChatBuddy

final class RewriteCoordinatorTests: XCTestCase {
    @MainActor
    func testRewritesWithSavedToneAndWritesResult() async throws {
        let reader = CoordinatorInputReaderMock(
            drafts: ["原始草稿", "原始草稿"]
        )
        let writer = CoordinatorInputWriterMock()
        let rewriter = CoordinatorTextRewriterMock(
            result: .success(RewriteResult(text: "优化草稿"))
        )
        let coordinator = RewriteCoordinator(
            inputReader: reader,
            inputWriter: writer,
            textRewriter: rewriter,
            preferencesStore: CoordinatorPreferencesStoreMock(tone: .friendly)
        )

        let result = try await coordinator.rewriteFocusedDraft()
        let requests = await rewriter.requests

        XCTAssertEqual(result.text, "优化草稿")
        XCTAssertEqual(
            requests,
            [RewriteRequest(text: "原始草稿", tone: .friendly)]
        )
        XCTAssertEqual(reader.readCount, 2)
        XCTAssertEqual(writer.writtenTexts, ["优化草稿"])
        XCTAssertFalse(coordinator.isProcessing)
    }

    @MainActor
    func testDoesNotOverwriteDraftChangedWhileWaiting() async {
        let reader = CoordinatorInputReaderMock(
            drafts: ["原始草稿", "用户刚刚修改的草稿"]
        )
        let writer = CoordinatorInputWriterMock()
        let coordinator = RewriteCoordinator(
            inputReader: reader,
            inputWriter: writer,
            textRewriter: CoordinatorTextRewriterMock(
                result: .success(RewriteResult(text: "优化草稿"))
            ),
            preferencesStore: CoordinatorPreferencesStoreMock(tone: .natural)
        )

        do {
            _ = try await coordinator.rewriteFocusedDraft()
            XCTFail("Expected changed draft protection")
        } catch {
            XCTAssertEqual(
                error as? RewriteCoordinatorError,
                .draftChanged
            )
            XCTAssertTrue(writer.writtenTexts.isEmpty)
        }
    }

    @MainActor
    func testRejectsConcurrentRewrite() async {
        let coordinator = RewriteCoordinator(
            inputReader: CoordinatorInputReaderMock(
                drafts: ["原始草稿", "原始草稿"]
            ),
            inputWriter: CoordinatorInputWriterMock(),
            textRewriter: CoordinatorTextRewriterMock(result: .waiting),
            preferencesStore: CoordinatorPreferencesStoreMock(tone: .natural)
        )
        let firstOperation = Task {
            try await coordinator.rewriteFocusedDraft()
        }
        await Task.yield()

        do {
            _ = try await coordinator.rewriteFocusedDraft()
            XCTFail("Expected duplicate request rejection")
        } catch {
            XCTAssertEqual(
                error as? RewriteCoordinatorError,
                .alreadyProcessing
            )
        }

        firstOperation.cancel()
        _ = try? await firstOperation.value
        XCTAssertFalse(coordinator.isProcessing)
    }
}

@MainActor
private final class CoordinatorInputReaderMock: WeChatInputReading {
    private var drafts: [String]
    private(set) var readCount = 0

    init(drafts: [String]) {
        self.drafts = drafts
    }

    func readFocusedDraft() throws -> String {
        readCount += 1
        return drafts.removeFirst()
    }
}

@MainActor
private final class CoordinatorInputWriterMock: WeChatInputWriting {
    private(set) var writtenTexts: [String] = []

    func writeFocusedDraft(_ text: String) throws {
        writtenTexts.append(text)
    }
}

private actor CoordinatorTextRewriterMock: TextRewriting {
    enum Result {
        case success(RewriteResult)
        case waiting
    }

    private let result: Result
    private(set) var requests: [RewriteRequest] = []

    init(result: Result) {
        self.result = result
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        requests.append(request)
        switch result {
        case let .success(result):
            return result
        case .waiting:
            try await Task.sleep(for: .seconds(60))
            return RewriteResult(text: "不应返回")
        }
    }
}

private struct CoordinatorPreferencesStoreMock: RewritePreferencesStoring {
    let tone: RewriteTone

    func loadTone() -> RewriteTone {
        tone
    }

    func saveTone(_ tone: RewriteTone) {}
}
