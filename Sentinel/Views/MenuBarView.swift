import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Button("立即锁定") {
            coordinator.requestLock()
        }
        .disabled(coordinator.isLocked || !coordinator.hasPassword)

        Divider()

        Button {
            coordinator.openAccessibilitySettings()
        } label: {
            Label(
                coordinator.accessibilityTrusted
                    ? "辅助功能：已授权"
                    : "打开辅助功能设置",
                systemImage: coordinator.accessibilityTrusted
                    ? "checkmark.shield"
                    : "exclamationmark.shield"
            )
        }

        Button {
            coordinator.setTouchIDEnabled(!coordinator.settings.touchIDEnabled)
        } label: {
            Label(
                coordinator.settings.touchIDEnabled ? "Touch ID：已启用" : "Touch ID：已关闭",
                systemImage: coordinator.settings.touchIDEnabled ? "touchid" : "touchid"
            )
        }
        .disabled(
            !coordinator.hasPassword
                || (
                    !coordinator.biometricAvailability.isAvailable
                        && !coordinator.settings.touchIDEnabled
                )
        )

        Divider()

        SettingsLink {
            Label("设置…", systemImage: "gearshape")
        }

        Button("退出 Sentinel") {
            coordinator.forceQuit()
        }
    }
}
