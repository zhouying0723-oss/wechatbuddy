import AppKit
import CoreGraphics
import Foundation

struct WeChatApplicationDetection: Equatable {
    let isFrontmost: Bool
    let detectedBundleIdentifier: String?
}

@MainActor
protocol WeChatApplicationDetecting {
    func detect() -> WeChatApplicationDetection
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

    func detect() -> WeChatApplicationDetection {
        let windowOwnerBundleIdentifiers = frontmostWindowOwnerBundleIdentifiers()
        let detectedBundleIdentifier = FrontmostExternalApplicationResolver.resolve(
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            windowOwnerBundleIdentifiers: windowOwnerBundleIdentifiers,
            workspaceFrontmostBundleIdentifier: workspace.frontmostApplication?.bundleIdentifier,
            fallbackBundleIdentifier: history.mostRecentExternalBundleIdentifier
        )
        history.record(bundleIdentifier: detectedBundleIdentifier)

        return WeChatApplicationDetection(
            isFrontmost: detectedBundleIdentifier == Self.bundleIdentifier,
            detectedBundleIdentifier: detectedBundleIdentifier
        )
    }

    @objc
    private func applicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        history.record(bundleIdentifier: application?.bundleIdentifier)
    }

    private func frontmostWindowOwnerBundleIdentifiers() -> [String] {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            CGWindowID(0)
        ) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap { window in
            guard
                (window[kCGWindowLayer as String] as? Int) == 0,
                let processIdentifier = window[kCGWindowOwnerPID as String] as? Int32
            else {
                return nil
            }

            return NSRunningApplication(processIdentifier: processIdentifier)?
                .bundleIdentifier
        }
    }
}

struct FrontmostExternalApplicationResolver {
    static func resolve(
        ownBundleIdentifier: String?,
        windowOwnerBundleIdentifiers: [String],
        workspaceFrontmostBundleIdentifier: String?,
        fallbackBundleIdentifier: String?
    ) -> String? {
        if let windowOwner = windowOwnerBundleIdentifiers.first(where: {
            $0 != ownBundleIdentifier
        }) {
            return windowOwner
        }

        if workspaceFrontmostBundleIdentifier != ownBundleIdentifier {
            return workspaceFrontmostBundleIdentifier ?? fallbackBundleIdentifier
        }

        return fallbackBundleIdentifier
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
