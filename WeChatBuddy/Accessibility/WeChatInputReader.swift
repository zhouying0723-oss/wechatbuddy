import AppKit
import ApplicationServices
import Foundation

@MainActor
protocol WeChatInputReading {
    func readFocusedDraft() throws -> String
}

enum WeChatInputReaderError: LocalizedError, Equatable {
    case accessibilityNotAuthorized
    case weChatNotRunning
    case focusedElementUnavailable(AXError)
    case editableElementUnavailable
    case unsupportedRole(String)
    case valueNotReadable
    case emptyDraft

    var errorDescription: String? {
        switch self {
        case .accessibilityNotAuthorized:
            "尚未获得辅助功能权限"
        case .weChatNotRunning:
            "微信未运行"
        case let .focusedElementUnavailable(error):
            "无法获取微信焦点控件（AX 错误 \(error.rawValue)）"
        case .editableElementUnavailable:
            "在微信当前窗口中找不到可编辑输入框"
        case let .unsupportedRole(role):
            "当前焦点不是可编辑输入框（角色：\(role)）"
        case .valueNotReadable:
            "无法读取当前输入框文字"
        case .emptyDraft:
            "当前输入框没有文字"
        }
    }
}

struct SystemWeChatInputReader: WeChatInputReading {
    func readFocusedDraft() throws -> String {
        guard AXIsProcessTrusted() else {
            throw WeChatInputReaderError.accessibilityNotAuthorized
        }

        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: SystemWeChatApplicationDetector.bundleIdentifier
        ).first(where: { !$0.isTerminated }) else {
            throw WeChatInputReaderError.weChatNotRunning
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        let focusedElementResult = elementAttribute(
            kAXFocusedUIElementAttribute,
            from: applicationElement
        )
        let element: AXUIElement

        if
            focusedElementResult.error == .success,
            let focusedElement = focusedElementResult.element,
            isEditable(focusedElement)
        {
            element = focusedElement
        } else if let editableElement = editableElementInFocusedWindow(
            of: applicationElement
        ) {
            element = editableElement
        } else if focusedElementResult.error == .success {
            let role = focusedElementResult.element
                .flatMap { stringAttribute(kAXRoleAttribute, from: $0) } ?? "未知"
            throw WeChatInputReaderError.unsupportedRole(role)
        } else if focusedElementResult.error == .noValue {
            throw WeChatInputReaderError.editableElementUnavailable
        } else {
            throw WeChatInputReaderError.focusedElementUnavailable(
                focusedElementResult.error
            )
        }

        guard let draft = stringAttribute(kAXValueAttribute, from: element) else {
            throw WeChatInputReaderError.valueNotReadable
        }

        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WeChatInputReaderError.emptyDraft
        }

        return draft
    }

    private static let editableRoles: Set<String> = [
        kAXTextAreaRole,
        kAXTextFieldRole,
        kAXComboBoxRole
    ]

    private func editableElementInFocusedWindow(
        of applicationElement: AXUIElement
    ) -> AXUIElement? {
        let focusedWindow = elementAttribute(
            kAXFocusedWindowAttribute,
            from: applicationElement
        ).element

        let root = focusedWindow ?? firstWindow(of: applicationElement)
        guard let root else {
            return nil
        }

        var queue = [root]
        var firstEditableElement: AXUIElement?
        var firstNonEmptyEditableElement: AXUIElement?
        var visitedCount = 0

        while !queue.isEmpty, visitedCount < 500 {
            let element = queue.removeFirst()
            visitedCount += 1

            if isEditable(element) {
                firstEditableElement = firstEditableElement ?? element

                if boolAttribute(kAXFocusedAttribute, from: element) == true {
                    return element
                }

                if
                    firstNonEmptyEditableElement == nil,
                    let value = stringAttribute(kAXValueAttribute, from: element),
                    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    firstNonEmptyEditableElement = element
                }
            }

            queue.append(contentsOf: elementArrayAttribute(
                kAXChildrenAttribute,
                from: element
            ))
        }

        return firstNonEmptyEditableElement ?? firstEditableElement
    }

    private func firstWindow(of applicationElement: AXUIElement) -> AXUIElement? {
        elementArrayAttribute(kAXWindowsAttribute, from: applicationElement)
            .first(where: { boolAttribute(kAXMainAttribute, from: $0) == true })
            ?? elementArrayAttribute(kAXWindowsAttribute, from: applicationElement).first
    }

    private func isEditable(_ element: AXUIElement) -> Bool {
        guard
            let role = stringAttribute(kAXRoleAttribute, from: element),
            Self.editableRoles.contains(role)
        else {
            return false
        }

        var valueIsSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueIsSettable
        )

        return settableError == .success && valueIsSettable.boolValue
    }

    private func stringAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> Bool? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success else {
            return nil
        }

        return value as? Bool
    }

    private func elementAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> (element: AXUIElement?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success, let value else {
            return (nil, error)
        }

        return (value as! AXUIElement, error)
    }

    private func elementArrayAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> [AXUIElement] {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }
}
