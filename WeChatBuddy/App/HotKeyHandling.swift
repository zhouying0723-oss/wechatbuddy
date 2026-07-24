import Foundation

protocol HotKeyHandling: Sendable {
    func registerRewriteShortcut(handler: @escaping @Sendable () -> Void) throws
    func unregisterRewriteShortcut()
}
