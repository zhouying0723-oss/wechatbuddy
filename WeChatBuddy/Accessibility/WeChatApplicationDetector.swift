import AppKit
import Foundation

@MainActor
protocol WeChatApplicationDetecting {
    func isWeChatFrontmost() -> Bool
}

@MainActor
final class SystemWeChatApplicationDetector: NSObject, WeChatApplicationDetecting {
    static let bundleIdentifier = "com.tencent.xinWeChat"

    private let workspace: NSWorkspace
    private var history: FrontmostApplicationHistory

    override init() {
        let workspace = NSWorkspace.shared
        self.workspace = workspace
        history = FrontmostApplicationHistory(
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            targetBundleIdentifier: Self.bundleIdentifier,
            currentBundleIdentifier: workspace.frontmostApplication?.bundleIdentifier
        )

        super.init()

        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func isWeChatFrontmost() -> Bool {
        history.record(
            bundleIdentifier: workspace.frontmostApplication?.bundleIdentifier
        )
        return history.isTargetMostRecentExternalApplication
    }

    @objc
    private func applicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        history.record(bundleIdentifier: application?.bundleIdentifier)
    }
}

struct FrontmostApplicationHistory {
    let ownBundleIdentifier: String?
    let targetBundleIdentifier: String

    private(set) var mostRecentExternalBundleIdentifier: String?

    init(
        ownBundleIdentifier: String?,
        targetBundleIdentifier: String,
        currentBundleIdentifier: String?
    ) {
        self.ownBundleIdentifier = ownBundleIdentifier
        self.targetBundleIdentifier = targetBundleIdentifier
        mostRecentExternalBundleIdentifier = nil
        record(bundleIdentifier: currentBundleIdentifier)
    }

    var isTargetMostRecentExternalApplication: Bool {
        mostRecentExternalBundleIdentifier == targetBundleIdentifier
    }

    mutating func record(bundleIdentifier: String?) {
        guard
            let bundleIdentifier,
            bundleIdentifier != ownBundleIdentifier
        else {
            return
        }

        mostRecentExternalBundleIdentifier = bundleIdentifier
    }
}
