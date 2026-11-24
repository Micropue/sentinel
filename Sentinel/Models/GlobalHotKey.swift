import AppKit
import Carbon
import CoreGraphics
import Foundation

struct GlobalHotKey: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let keyDisplay: String

    static let defaultLock = GlobalHotKey(
        keyCode: UInt32(kVK_ANSI_L),
        carbonModifiers: UInt32(cmdKey | optionKey),
        keyDisplay: "L"
    )

    static let defaultForceQuit = GlobalHotKey(
        keyCode: UInt32(kVK_ANSI_Q),
        carbonModifiers: UInt32(cmdKey | optionKey | controlKey),
        keyDisplay: "Q"
    )

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        return result + keyDisplay
    }

    var hasRequiredModifier: Bool {
        carbonModifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    var cgModifierFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.maskCommand)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.maskAlternate)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.maskControl)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.maskShift)
        }
        return flags
    }

    func matches(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode) else {
            return false
        }

        let relevantFlags: CGEventFlags = [
            .maskCommand,
            .maskAlternate,
            .maskControl,
            .maskShift
        ]
        return event.flags.intersection(relevantFlags) == cgModifierFlags
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(keyCode) else {
            return false
        }

        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return event.modifierFlags.intersection(relevantFlags) == appKitModifierFlags
    }

    private var appKitModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        return flags
    }

    static func from(event: NSEvent) -> GlobalHotKey? {
        guard event.type == .keyDown else {
            return nil
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        let candidate = GlobalHotKey(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            keyDisplay: keyDisplay(for: event)
        )

        return candidate.hasRequiredModifier ? candidate : nil
    }

    static func digit(from event: CGEvent) -> Character? {
        let disallowed: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        guard event.flags.intersection(disallowed).isEmpty else {
            return nil
        }

        if let character = numberKeyMap[event.getIntegerValueField(.keyboardEventKeycode)] {
            return character
        }

        guard let appKitEvent = NSEvent(cgEvent: event),
              let value = appKitEvent.charactersIgnoringModifiers,
              value.count == 1,
              let character = value.first,
              character.isASCII,
              character.isNumber
        else {
            return nil
        }

        return character
    }

    static func digit(from event: NSEvent) -> Character? {
        let disallowed: NSEvent.ModifierFlags = [.command, .option, .control]
        guard event.type == .keyDown,
              event.modifierFlags.intersection(disallowed).isEmpty
        else {
            return nil
        }

        if let character = numberKeyMap[Int64(event.keyCode)] {
            return character
        }

        guard let value = event.charactersIgnoringModifiers,
              value.count == 1,
              let character = value.first,
              character.isASCII,
              character.isNumber
        else {
            return nil
        }

        return character
    }

    private static let numberKeyMap: [Int64: Character] = [
        // Main keyboard number row.
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        // Numeric keypad.
        83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
        88: "6", 89: "7", 91: "8", 92: "9", 82: "0"
    ]

    private static func keyDisplay(for event: NSEvent) -> String {
        if let special = specialKeyDisplays[event.keyCode] {
            return special
        }

        if let characters = event.charactersIgnoringModifiers,
           let first = characters.first {
            return String(first).uppercased()
        }

        return "Key \(event.keyCode)"
    }

    private static let specialKeyDisplays: [UInt16: String] = [
        UInt16(kVK_Return): "↩",
        UInt16(kVK_ANSI_KeypadEnter): "⌤",
        UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Delete): "⌫",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_Escape): "Esc",
        UInt16(kVK_F1): "F1",
        UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5",
        UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7",
        UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11",
        UInt16(kVK_F12): "F12"
    ]
}
