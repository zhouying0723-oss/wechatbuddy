import Foundation

protocol AccessibilityAuthorizing: Sendable {
    func isTrusted() -> Bool
    func requestAccess() -> Bool
    func openSystemSettings()
}

protocol AccessibilityProviding: AccessibilityAuthorizing {
    func readFocusedDraft() throws -> String
    func writeFocusedDraft(_ text: String) throws
}
