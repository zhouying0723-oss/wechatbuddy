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
        var focusedElementValue: CFTypeRef?
        let focusedElementError = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )

        guard
            focusedElementError == .success,
            let focusedElement = focusedElementValue
        else {
            throw WeChatInputReaderError.focusedElementUnavailable(focusedElementError)
        }

        let element = focusedElement as! AXUIElement
        let role = try stringAttribute(kAXRoleAttribute, from: element) ?? "未知"
        var valueIsSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueIsSettable
        )

        guard
            Self.editableRoles.contains(role),
            settableError == .success,
            valueIsSettable.boolValue
        else {
            throw WeChatInputReaderError.unsupportedRole(role)
        }

        guard let draft = try stringAttribute(kAXValueAttribute, from: element) else {
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

    private func stringAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) throws -> String? {
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
}
