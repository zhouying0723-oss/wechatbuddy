import AppKit
import CoreGraphics
import Foundation

enum ClipboardDraftReaderError: LocalizedError, Equatable {
    case keyboardEventUnavailable
    case clipboardUnchanged
    case copiedTextUnavailable
    case emptyDraft

    var errorDescription: String? {
        switch self {
        case .keyboardEventUnavailable:
            "无法生成读取输入框所需的键盘事件"
        case .clipboardUnchanged:
            "复制操作没有产生新的剪贴板内容，请确认光标位于微信输入框"
        case .copiedTextUnavailable:
            "剪贴板中没有可读取的文字"
        case .emptyDraft:
            "当前输入框没有文字"
        }
    }
}

struct ClipboardDraftValidator {
    static func validate(
        copiedText: String?,
        clipboardChanged: Bool
    ) throws -> String {
        guard clipboardChanged else {
            throw ClipboardDraftReaderError.clipboardUnchanged
        }

        guard let copiedText else {
            throw ClipboardDraftReaderError.copiedTextUnavailable
        }

        guard !copiedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClipboardDraftReaderError.emptyDraft
        }

        return copiedText
    }
}

@MainActor
struct ClipboardDraftReader {
    func readSelectedInput() throws -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let originalChangeCount = pasteboard.changeCount
        defer {
            snapshot.restore(to: pasteboard)
        }

        try postCommandKey(keyCode: 0) // A
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        try postCommandKey(keyCode: 8) // C
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))

        return try ClipboardDraftValidator.validate(
            copiedText: pasteboard.string(forType: .string),
            clipboardChanged: pasteboard.changeCount != originalChangeCount
        )
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
            throw ClipboardDraftReaderError.keyboardEventUnavailable
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

struct PasteboardSnapshot {
    struct Item {
        let values: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    let items: [Item]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { pasteboardItem in
            Item(values: pasteboardItem.types.compactMap { type in
                pasteboardItem.data(forType: type).map { (type, $0) }
            })
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let restoredItems = items.map { item in
            let pasteboardItem = NSPasteboardItem()
            for value in item.values {
                pasteboardItem.setData(value.data, forType: value.type)
            }
            return pasteboardItem
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
