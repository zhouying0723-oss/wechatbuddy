import Foundation

enum RewriteCoordinatorError: LocalizedError, Equatable {
    case alreadyProcessing
    case draftChanged

    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            "已有改写任务正在进行"
        case .draftChanged:
            "等待模型回复期间微信草稿已变化，为避免误覆盖，本次未写回"
        }
    }
}

@MainActor
protocol RewriteCoordinating {
    var isProcessing: Bool { get }
    func rewriteFocusedDraft() async throws -> RewriteResult
}

@MainActor
final class RewriteCoordinator: RewriteCoordinating {
    private(set) var isProcessing = false

    private let inputReader: any WeChatInputReading
    private let inputWriter: any WeChatInputWriting
    private let textRewriter: any TextRewriting
    private let preferencesStore: any RewritePreferencesStoring

    init(
        inputReader: any WeChatInputReading,
        inputWriter: any WeChatInputWriting,
        textRewriter: any TextRewriting,
        preferencesStore: any RewritePreferencesStoring
    ) {
        self.inputReader = inputReader
        self.inputWriter = inputWriter
        self.textRewriter = textRewriter
        self.preferencesStore = preferencesStore
    }

    func rewriteFocusedDraft() async throws -> RewriteResult {
        guard !isProcessing else {
            throw RewriteCoordinatorError.alreadyProcessing
        }
        isProcessing = true
        defer {
            isProcessing = false
        }

        let originalDraft = try inputReader.readFocusedDraft()
        let result = try await textRewriter.rewrite(
            RewriteRequest(
                text: originalDraft,
                tone: preferencesStore.loadTone(),
                customInstruction:
                    preferencesStore.loadCustomInstruction()
            )
        )

        let currentDraft = try inputReader.readFocusedDraft()
        guard currentDraft == originalDraft else {
            throw RewriteCoordinatorError.draftChanged
        }

        try inputWriter.writeFocusedDraft(result.text)
        return result
    }
}
