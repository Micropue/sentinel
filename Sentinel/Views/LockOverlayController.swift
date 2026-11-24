import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class LockOverlayController: NSObject {
    private var panels: [LockPanel] = []
    private var viewModel: LockViewModel?
    private var primaryDisplayID: CGDirectDisplayID?
    private var cursorIsHidden = false

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func show(viewModel: LockViewModel) {
        self.viewModel = viewModel
        primaryDisplayID = Self.mainDisplayID()

        rebuildWindows()
        hideCursorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        closeWindows()
        viewModel = nil
        primaryDisplayID = nil
        restoreCursorIfNeeded()
    }

    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        guard viewModel != nil else {
            return
        }
        primaryDisplayID = Self.mainDisplayID()
        rebuildWindows()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func workspaceDidChange(_ notification: Notification) {
        guard !panels.isEmpty else {
            return
        }
        bringPanelsForward()
    }

    private func rebuildWindows() {
        closeWindows()
        guard let viewModel else {
            return
        }

        let screens = NSScreen.screens
        if let primaryDisplayID,
           !screens.contains(where: { Self.displayID(for: $0) == primaryDisplayID }) {
            self.primaryDisplayID = Self.mainDisplayID()
        }

        let primaryScreen = screens.first {
            Self.displayID(for: $0) == primaryDisplayID
        } ?? screens.first

        for screen in NSScreen.screens {
            let isPrimaryDisplay = screen === primaryScreen
            let panel = makePanel(
                for: screen,
                viewModel: viewModel,
                isPrimaryDisplay: isPrimaryDisplay
            )
            panel.isPrimaryDisplay = isPrimaryDisplay
            panels.append(panel)
        }

        panels.first(where: \.isPrimaryDisplay)?.makeKeyAndOrderFront(nil)

        bringPanelsForward()
    }

    private func makePanel(
        for screen: NSScreen,
        viewModel: LockViewModel,
        isPrimaryDisplay: Bool
    ) -> LockPanel {
        let panel = LockPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)

        let hostingView = NSHostingView(
            rootView: LockScreenView(
                model: viewModel,
                isPrimaryDisplay: isPrimaryDisplay
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setFrame(screen.frame, display: true)

        return panel
    }

    private func bringPanelsForward() {
        for panel in panels {
            panel.orderFrontRegardless()
        }
    }

    private func closeWindows() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }

    private func hideCursorIfNeeded() {
        guard !cursorIsHidden else {
            return
        }
        NSCursor.hide()
        cursorIsHidden = true
    }

    private func restoreCursorIfNeeded() {
        guard cursorIsHidden else {
            return
        }
        NSCursor.unhide()
        cursorIsHidden = false
    }

    private static func mainDisplayID() -> CGDirectDisplayID? {
        let screens = NSScreen.screens
        let displayID = CGMainDisplayID()
        if screens.contains(where: { Self.displayID(for: $0) == displayID }) {
            return displayID
        }
        return Self.displayID(for: screens.first)
    }

    private static func displayID(for screen: NSScreen?) -> CGDirectDisplayID? {
        guard let screen,
              let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber
        else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}

private final class LockPanel: NSPanel {
    var isPrimaryDisplay = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
