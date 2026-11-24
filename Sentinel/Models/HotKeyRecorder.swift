import AppKit
import Combine
import Foundation

enum HotKeyTarget: String, Identifiable {
    case lock
    case forceQuit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock:
            return "呼出保护层"
        case .forceQuit:
            return "强制关闭保护层"
        }
    }
}

final class HotKeyRecorder: ObservableObject {
    @Published private(set) var target: HotKeyTarget?
    @Published private(set) var hint = ""

    private var monitor: Any?
    private var beginRecording: (() -> Void)?
    private var endRecording: (() -> Void)?
    private var didRecord: ((HotKeyTarget, GlobalHotKey) -> Void)?

    func start(
        target: HotKeyTarget,
        onBegin: @escaping () -> Void,
        onEnd: @escaping () -> Void,
        onRecord: @escaping (HotKeyTarget, GlobalHotKey) -> Void
    ) {
        cancel()

        self.target = target
        beginRecording = onBegin
        endRecording = onEnd
        didRecord = onRecord
        hint = "请按下包含 ⌘、⌥ 或 ⌃ 的组合键"

        beginRecording?()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            return self.handle(event)
        }
    }

    func cancel() {
        guard target != nil else {
            return
        }

        removeMonitor()
        target = nil
        hint = ""
        let onEnd = endRecording
        beginRecording = nil
        endRecording = nil
        didRecord = nil
        onEnd?()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let target else {
            return event
        }

        if event.keyCode == 53 {
            cancel()
            return nil
        }

        if event.isARepeat {
            return nil
        }

        guard let hotKey = GlobalHotKey.from(event: event) else {
            hint = "组合键至少要包含 ⌘、⌥ 或 ⌃"
            NSSound.beep()
            return nil
        }

        removeMonitor()
        self.target = nil
        hint = ""

        let onRecord = didRecord
        let onEnd = endRecording
        beginRecording = nil
        endRecording = nil
        didRecord = nil

        onRecord?(target, hotKey)
        onEnd?()
        return nil
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
