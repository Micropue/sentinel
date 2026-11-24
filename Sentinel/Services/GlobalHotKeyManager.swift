import Carbon
import Foundation

@MainActor
final class GlobalHotKeyManager {
    var onLock: (() -> Void)?
    var onForceQuit: (() -> Void)?

    private enum ActionID: UInt32 {
        case lock = 1
        case forceQuit = 2
    }

    private static let signature: OSType = 0x534E544C // SNTL
    private var eventHandler: EventHandlerRef?
    private var hotKeyReferences: [UInt32: EventHotKeyRef] = [:]

    init() {
        installEventHandler()
    }

    @discardableResult
    func register(lock: GlobalHotKey, forceQuit: GlobalHotKey) -> String? {
        unregisterAll()

        guard lock != forceQuit else {
            return "呼出快捷键与强制退出快捷键不能相同。"
        }

        let registrations: [(ActionID, GlobalHotKey)] = [
            (.lock, lock),
            (.forceQuit, forceQuit)
        ]

        for (actionID, hotKey) in registrations {
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: actionID.rawValue
            )
            let status = RegisterEventHotKey(
                hotKey.keyCode,
                hotKey.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &reference
            )

            guard status == noErr, let reference else {
                unregisterAll()
                return "无法注册 \(hotKey.displayString)（Carbon 状态码 \(status)）。该组合可能已被系统或其他应用占用。"
            }
            hotKeyReferences[actionID.rawValue] = reference
        }

        return nil
    }

    func unregisterAll() {
        for reference in hotKeyReferences.values {
            UnregisterEventHotKey(reference)
        }
        hotKeyReferences.removeAll()
    }

    func stop() {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installEventHandler() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handle(actionID: UInt32) {
        switch actionID {
        case ActionID.lock.rawValue:
            onLock?()
        case ActionID.forceQuit.rawValue:
            onForceQuit?()
        default:
            break
        }
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userInfo in
        guard let event, let userInfo else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else {
            return status
        }

        let manager = Unmanaged<GlobalHotKeyManager>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        Task { @MainActor in
            manager.handle(actionID: hotKeyID.id)
        }
        return noErr
    }
}
