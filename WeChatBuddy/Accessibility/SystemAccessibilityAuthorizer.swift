import AppKit
@preconcurrency import ApplicationServices
import Foundation

struct SystemAccessibilityAuthorizer: AccessibilityAuthorizing {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccess() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
