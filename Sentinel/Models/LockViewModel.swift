import Combine
import Foundation

@MainActor
final class LockViewModel: ObservableObject {
    static let passwordLength = 6

    let forceQuitHotKey: GlobalHotKey
    let touchIDConfigured: Bool
    let touchIDAvailable: Bool

    @Published private(set) var glassIntensity: Double = 0.18
    @Published private(set) var showsPasswordEntry = false
    @Published private(set) var enteredDigits = ""
    @Published private(set) var isVerifying = false
    @Published private(set) var isBiometricPrompting = false
    @Published private(set) var message = "移动鼠标或点按鼠标以解锁"
    @Published private(set) var showsError = false
    @Published private(set) var errorPulse = 0

    private var revealTask: Task<Void, Never>?

    init(
        forceQuitHotKey: GlobalHotKey,
        touchIDConfigured: Bool,
        touchIDAvailable: Bool
    ) {
        self.forceQuitHotKey = forceQuitHotKey
        self.touchIDConfigured = touchIDConfigured
        self.touchIDAvailable = touchIDAvailable
    }

    func revealPasswordEntry() {
        guard !showsPasswordEntry else {
            return
        }

        glassIntensity = 1
        message = "正在唤出密码输入界面…"
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled, let self else {
                return
            }
            self.showsPasswordEntry = true
            self.message = self.touchIDConfigured && self.touchIDAvailable
                ? "输入 6 位数字，或使用 Touch ID"
                : "使用键盘输入 6 位数字"
        }
    }

    @discardableResult
    func appendDigit(_ digit: Character) -> Bool {
        guard showsPasswordEntry,
              !isVerifying,
              enteredDigits.count < Self.passwordLength
        else {
            return false
        }

        showsError = false
        enteredDigits.append(digit)
        let remaining = Self.passwordLength - enteredDigits.count
        message = remaining > 0
            ? "还需要 \(remaining) 位数字"
            : "正在检查密码…"
        return enteredDigits.count == Self.passwordLength
    }

    func beginVerification() {
        isVerifying = true
        showsError = false
        message = "正在验证…"
    }

    func rejectPassword() {
        isVerifying = false
        isBiometricPrompting = false
        enteredDigits = ""
        message = "密码不正确，请重新输入"
        showsError = true
        errorPulse += 1
    }

    func beginBiometricPrompt() {
        isBiometricPrompting = true
        showsError = false
        message = "正在等待 Touch ID…"
    }

    func finishBiometricPrompt(success: Bool) {
        isBiometricPrompting = false
        guard !success else {
            return
        }
        message = "Touch ID 未通过，请输入密码"
        showsError = true
        errorPulse += 1
    }

    func cancelBiometricPrompt() {
        isBiometricPrompting = false
        message = "使用键盘输入 6 位数字"
    }
}
