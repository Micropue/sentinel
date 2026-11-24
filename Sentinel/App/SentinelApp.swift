import SwiftUI

@main
@MainActor
struct SentinelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.isLocked ? "lock.shield.fill" : "lock.shield")
                .accessibilityLabel("Sentinel")
        }
        .menuBarExtraStyle(.menu)
    }
}
