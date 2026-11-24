import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator.shared
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.openSettingsHandler = { [weak self] in
            self?.showSettings()
        }
        coordinator.start()

        if !coordinator.hasPassword {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.refreshPermissionsAndSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.shutdown()
    }

    func showSettings() {
        if settingsWindowController == nil {
            let hostingController = NSHostingController(
                rootView: SettingsView(coordinator: coordinator)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Sentinel 设置"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 790, height: 760))
            window.minSize = NSSize(width: 720, height: 620)
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }

        coordinator.refreshPermissionsAndSettings()
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
