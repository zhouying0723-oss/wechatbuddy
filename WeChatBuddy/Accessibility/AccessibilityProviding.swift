import Foundation

protocol AccessibilityProviding: Sendable {
    func isTrusted() -> Bool
    func readFocusedDraft() throws -> String
    func writeFocusedDraft(_ text: String) throws
}
