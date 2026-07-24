import Carbon
import Foundation

@MainActor
protocol HotKeyHandling: AnyObject {
    func registerRewriteShortcut(handler: @escaping @MainActor () -> Void) throws
    func unregisterRewriteShortcut()
}

struct RewriteHotKey: Equatable {
    static let signature: OSType = 0x57425544 // "WBUD"
    static let identifier: UInt32 = 1

    let keyCode: UInt32
    let modifiers: UInt32

    static let standard = RewriteHotKey(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    func matches(_ hotKeyID: EventHotKeyID) -> Bool {
        hotKeyID.signature == Self.signature
            && hotKeyID.id == Self.identifier
    }
}

enum HotKeyRegistrationError: LocalizedError, Equatable {
    case eventHandlerInstallationFailed(OSStatus)
    case shortcutRegistrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .eventHandlerInstallationFailed(status):
            "无法安装快捷键事件处理器（系统错误 \(status)）"
        case let .shortcutRegistrationFailed(status):
            "无法注册 Command + Shift + R（系统错误 \(status)）"
        }
    }
}

@MainActor
final class SystemHotKeyService: HotKeyHandling {
    private var eventHandler: EventHandlerRef?
    private var hotKeyReference: EventHotKeyRef?
    private var handler: (@MainActor () -> Void)?

    isolated deinit {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func registerRewriteShortcut(handler: @escaping @MainActor () -> Void) throws {
        unregisterRewriteShortcut()
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installationStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard installationStatus == noErr else {
            self.handler = nil
            throw HotKeyRegistrationError.eventHandlerInstallationFailed(installationStatus)
        }

        let hotKeyID = EventHotKeyID(
            signature: RewriteHotKey.signature,
            id: RewriteHotKey.identifier
        )
        let shortcut = RewriteHotKey.standard
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
        guard registrationStatus == noErr else {
            unregisterRewriteShortcut()
            throw HotKeyRegistrationError.shortcutRegistrationFailed(registrationStatus)
        }
    }

    func unregisterRewriteShortcut() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handler = nil
    }

    private static let eventHandlerCallback: EventHandlerUPP = {
        _, event, userData in
        guard let event, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let parameterStatus = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard parameterStatus == noErr, RewriteHotKey.standard.matches(hotKeyID) else {
            return OSStatus(eventNotHandledErr)
        }

        let serviceAddress = UInt(bitPattern: userData)
        return MainActor.assumeIsolated {
            guard let servicePointer = UnsafeRawPointer(bitPattern: serviceAddress) else {
                return OSStatus(eventNotHandledErr)
            }
            let service = Unmanaged<SystemHotKeyService>
                .fromOpaque(servicePointer)
                .takeUnretainedValue()
            service.handler?()
            return noErr
        }
    }
}
