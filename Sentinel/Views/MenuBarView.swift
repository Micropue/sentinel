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
            if coordinator.accessibilityTrusted {
                coordinator.openAccessibilitySettings()
            } else {
                coordinator.requestAccessibilityPermission()
            }
        } label: {
            Label(
                coordinator.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：需要授权",
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

        Button("设置…") {
            coordinator.presentSettings()
        }

        Button("退出 Sentinel") {
            coordinator.forceQuit()
        }
    }
}
