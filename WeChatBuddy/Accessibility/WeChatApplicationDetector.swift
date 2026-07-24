import AppKit
import Foundation

@MainActor
protocol WeChatApplicationDetecting {
    func isWeChatFrontmost() -> Bool
}

@MainActor
struct SystemWeChatApplicationDetector: WeChatApplicationDetecting {
    static let bundleIdentifier = "com.tencent.xinWeChat"

    func isWeChatFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.bundleIdentifier
    }
}
