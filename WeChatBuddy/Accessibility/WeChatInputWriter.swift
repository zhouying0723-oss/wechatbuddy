import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol WeChatInputWriting {
    func writeFocusedDraft(_ text: String) throws
}

enum WeChatInputWriterError: LocalizedError, Equatable {
    case accessibilityNotAuthorized
    case weChatNotFrontmost
    case emptyReplacement
    case clipboardWriteFailed
    case keyboardEventUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityNotAuthorized:
            "尚未获得辅助功能权限"
        case .weChatNotFrontmost:
            "请先将微信切换到前台并点击输入框"
        case .emptyReplacement:
            "不能写入空白内容"
        case .clipboardWriteFailed:
            "无法把待写入文字放入临时剪贴板"
        case .keyboardEventUnavailable:
            "无法生成写入输入框所需的键盘事件"
        }
    }
}

struct WeChatDraftWriteValidator {
    static func validate(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WeChatInputWriterError.emptyReplacement
        }
    }
}

@MainActor
struct SystemWeChatInputWriter: WeChatInputWriting {
    func writeFocusedDraft(_ text: String) throws {
        try WeChatDraftWriteValidator.validate(text)

        guard AXIsProcessTrusted() else {
            throw WeChatInputWriterError.accessibilityNotAuthorized
        }

        let detection = SystemWeChatApplicationDetector().detect()
        guard detection.isFrontmost else {
            throw WeChatInputWriterError.weChatNotFrontmost
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        defer {
            snapshot.restore(to: pasteboard)
        }

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw WeChatInputWriterError.clipboardWriteFailed
        }

        try postCommandKey(keyCode: 0) // A
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        try postCommandKey(keyCode: 9) // V
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
    }

    private func postCommandKey(keyCode: CGKeyCode) throws {
        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil,
                virtualKey: keyCode,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: nil,
                virtualKey: keyCode,
                keyDown: false
            )
        else {
            throw WeChatInputWriterError.keyboardEventUnavailable
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
