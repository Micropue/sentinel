import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class InputLockService {
    private let forceQuitHotKey: GlobalHotKey
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hasRevealed = false

    var onReveal: (() -> Void)?
    var onDigit: ((Character) -> Void)?
    var onForceQuit: (() -> Void)?

    init(forceQuitHotKey: GlobalHotKey) {
        self.forceQuitHotKey = forceQuitHotKey
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }
        guard Self.isAccessibilityTrusted else {
            return false
        }

        // Intercept every event family so media keys, gestures and future
        // system-defined input cannot bypass the protection layer.
        let eventMask = CGEventMask.max

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let tap = Self.createEventTap(eventMask: eventMask, userInfo: userInfo)
        guard let tap else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        hasRevealed = false
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            return nil

        case .keyDown:
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
               forceQuitHotKey.matches(event) {
                DispatchQueue.main.async { [weak self] in
                    self?.onForceQuit?()
                }
                return nil
            }

            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
               let digit = GlobalHotKey.digit(from: event) {
                DispatchQueue.main.async { [weak self] in
                    self?.onDigit?(digit)
                }
            }
            return nil

        case .mouseMoved,
             .leftMouseDown,
             .leftMouseUp,
             .rightMouseDown,
             .rightMouseUp,
             .otherMouseDown,
             .otherMouseUp,
             .leftMouseDragged,
             .rightMouseDragged,
             .otherMouseDragged,
             .scrollWheel,
             .tabletPointer,
             .tabletProximity:
            if !hasRevealed {
                hasRevealed = true
                DispatchQueue.main.async { [weak self] in
                    self?.onReveal?()
                }
            }
            return nil

        default:
            return nil
        }
    }

    private static func createEventTap(
        eventMask: CGEventMask,
        userInfo: UnsafeMutableRawPointer
    ) -> CFMachPort? {
        let locations: [CGEventTapLocation] = [
            .cghidEventTap,
            .cgSessionEventTap
        ]

        for location in locations {
            if let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: eventTapCallback,
                userInfo: userInfo
            ) {
                return tap
            }
        }
        return nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<InputLockService>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return service.handle(type: type, event: event)
    }
}
