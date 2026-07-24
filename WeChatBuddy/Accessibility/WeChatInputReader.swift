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
    case editableElementUnavailable(String)
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
        case let .editableElementUnavailable(diagnostic):
            "在微信当前窗口中找不到可编辑输入框（\(diagnostic)）"
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

        let applications = NSWorkspace.shared.runningApplications
            .filter(isWeChatApplication)
            .sorted { lhs, rhs in
                applicationPriority(lhs) < applicationPriority(rhs)
            }

        guard !applications.isEmpty else {
            throw WeChatInputReaderError.weChatNotRunning
        }

        var diagnostics: [String] = []

        for application in applications {
            let applicationElement = AXUIElementCreateApplication(
                application.processIdentifier
            )
            _ = AXUIElementSetAttributeValue(
                applicationElement,
                "AXEnhancedUserInterface" as CFString,
                kCFBooleanTrue
            )

            let focusedElementResult = elementAttribute(
                kAXFocusedUIElementAttribute,
                from: applicationElement
            )

            if
                focusedElementResult.error == .success,
                let focusedElement = focusedElementResult.element,
                isEditable(focusedElement)
            {
                return try draft(from: focusedElement)
            }

            let searchResult = editableElementInFocusedWindow(of: applicationElement)
            if let editableElement = searchResult.element {
                return try draft(from: editableElement)
            }

            let identifier = application.bundleIdentifier ?? "PID \(application.processIdentifier)"
            diagnostics.append("\(identifier)：\(searchResult.diagnostic)")
        }

        throw WeChatInputReaderError.editableElementUnavailable(
            diagnostics.joined(separator: "；")
        )
    }

    private func isWeChatApplication(_ application: NSRunningApplication) -> Bool {
        guard !application.isTerminated else {
            return false
        }

        let bundleIdentifier = application.bundleIdentifier ?? ""
        return bundleIdentifier == SystemWeChatApplicationDetector.bundleIdentifier
            || bundleIdentifier.hasPrefix("com.tencent.flue.WeChatAppEx")
    }

    private func applicationPriority(_ application: NSRunningApplication) -> Int {
        application.bundleIdentifier == SystemWeChatApplicationDetector.bundleIdentifier
            ? 0
            : 1
    }

    private func draft(from element: AXUIElement) throws -> String {
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
    ) -> (element: AXUIElement?, diagnostic: String) {
        let focusedWindow = elementAttribute(
            kAXFocusedWindowAttribute,
            from: applicationElement
        ).element

        let root = focusedWindow ?? firstWindow(of: applicationElement)
            ?? applicationElement

        var queue = [root]
        var visitedElements = Set<CFHashCode>()
        var firstEditableElement: AXUIElement?
        var firstNonEmptyEditableElement: AXUIElement?
        var roleCounts: [String: Int] = [:]
        var settableValueCount = 0
        var visitedCount = 0

        while !queue.isEmpty, visitedCount < 5_000 {
            let element = queue.removeFirst()
            let elementHash = CFHash(element)
            guard visitedElements.insert(elementHash).inserted else {
                continue
            }

            visitedCount += 1
            let role = stringAttribute(kAXRoleAttribute, from: element) ?? "未知"
            roleCounts[role, default: 0] += 1

            if isValueSettable(element) {
                settableValueCount += 1
            }

            if isEditable(element) {
                firstEditableElement = firstEditableElement ?? element

                if boolAttribute(kAXFocusedAttribute, from: element) == true {
                    return (element, diagnostic(
                        visitedCount: visitedCount,
                        roleCounts: roleCounts,
                        settableValueCount: settableValueCount
                    ))
                }

                if
                    firstNonEmptyEditableElement == nil,
                    let value = stringAttribute(kAXValueAttribute, from: element),
                    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    firstNonEmptyEditableElement = element
                }
            }

            for attribute in childAttributes {
                queue.append(contentsOf: elementArrayAttribute(
                    attribute,
                    from: element
                ))
            }
        }

        return (
            firstNonEmptyEditableElement ?? firstEditableElement,
            diagnostic(
                visitedCount: visitedCount,
                roleCounts: roleCounts,
                settableValueCount: settableValueCount
            )
        )
    }

    private var childAttributes: [String] {
        [
            kAXChildrenAttribute,
            kAXVisibleChildrenAttribute,
            kAXContentsAttribute,
            NSAccessibility.Attribute.childrenInNavigationOrderAttribute.rawValue
        ]
    }

    private func diagnostic(
        visitedCount: Int,
        roleCounts: [String: Int],
        settableValueCount: Int
    ) -> String {
        let roles = roleCounts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(8)
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ", ")

        return "扫描 \(visitedCount) 个控件，可写 Value \(settableValueCount) 个，角色 \(roles)"
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

        return isValueSettable(element)
    }

    private func isValueSettable(_ element: AXUIElement) -> Bool {
        var valueIsSettable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueIsSettable
        )

        return error == .success && valueIsSettable.boolValue
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

        guard
            error == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return (nil, error)
        }

        return ((value as! AXUIElement), error)
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
