import AppKit
import Combine
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    @Published private(set) var settings: SentinelSettings
    @Published private(set) var hasPassword: Bool
    @Published private(set) var isLocked = false
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginRequiresApproval: Bool
    @Published private(set) var biometricAvailability: BiometricAvailability
    @Published private(set) var hotKeyRegistrationError: String?

    var openSettingsHandler: (() -> Void)?

    private let vault: PasswordVault
    private let biometric: BiometricAuthenticator
    private let overlayController: LockOverlayController
    private let hotKeyManager: GlobalHotKeyManager

    private var inputLockService: InputLockService?
    private var previousApplication: NSRunningApplication?
    private var lockViewModel: LockViewModel?
    private var verificationTask: Task<Void, Never>?
    private var biometricTask: Task<Void, Never>?
    private var biometricPromptToken = UUID()
    private var biometricAttempted = false
    private var hotKeySuspensionDepth = 0
    private var didStart = false

    init(vault: PasswordVault = PasswordVault()) {
        let loadedSettings = SettingsPersistence.load()
        let biometric = BiometricAuthenticator()
        let loginItem = LoginItemManager()

        self.vault = vault
        self.settings = loadedSettings
        self.hasPassword = vault.hasPassword
        self.biometric = biometric
        self.biometricAvailability = biometric.availability
        self.overlayController = LockOverlayController()
        self.hotKeyManager = GlobalHotKeyManager()
        self.accessibilityTrusted = InputLockService.isAccessibilityTrusted
        self.launchAtLoginEnabled = loginItem.isEnabled
        self.launchAtLoginRequiresApproval = loginItem.requiresApproval
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true

        hotKeyManager.onLock = { [weak self] in
            self?.requestLock()
        }
        hotKeyManager.onForceQuit = { [weak self] in
            self?.forceQuit()
        }

        if let error = hotKeyManager.register(
            lock: settings.lockHotKey,
            forceQuit: settings.forceQuitHotKey
        ) {
            hotKeyRegistrationError = error
        } else {
            hotKeyRegistrationError = nil
        }

        refreshPermissionsAndSettings()
    }

    func requestLock() {
        guard !isLocked else {
            return
        }

        refreshPermissionsAndSettings()

        guard hasPassword else {
            presentSettings()
            presentAlert(
                title: "尚未设置解锁密码",
                message: "请先在设置中创建 6 位数字密码，Sentinel 才能启用保护。"
            )
            return
        }

        guard InputLockService.isAccessibilityTrusted else {
            InputLockService.requestAccessibilityPermission()
            presentSettings()
            presentAlert(
                title: "需要辅助功能权限",
                message: "请在“系统设置 → 隐私与安全性 → 辅助功能”中允许 Sentinel。未获得此权限时，Sentinel 不会显示保护层，以免形成可被键盘和鼠标绕过的假保护。"
            )
            return
        }

        let model = LockViewModel(
            forceQuitHotKey: settings.forceQuitHotKey,
            touchIDConfigured: settings.touchIDEnabled,
            touchIDAvailable: biometric.availability.isAvailable
        )
        let inputLock = InputLockService(forceQuitHotKey: settings.forceQuitHotKey)

        inputLock.onReveal = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleReveal()
            }
        }
        inputLock.onDigit = { [weak self] digit in
            Task { @MainActor [weak self] in
                self?.handleDigit(digit)
            }
        }
        inputLock.onForceQuit = { [weak self] in
            Task { @MainActor [weak self] in
                self?.forceQuit()
            }
        }

        guard inputLock.start() else {
            presentAlert(
                title: "无法启动输入保护",
                message: "Sentinel 无法创建系统输入拦截器。请确认电池没有处于极端节能状态，并重新授予辅助功能权限。"
            )
            refreshPermissionsAndSettings()
            return
        }

        previousApplication = NSWorkspace.shared.frontmostApplication
        lockViewModel = model
        inputLockService = inputLock
        verificationTask = nil
        biometricTask = nil
        biometricAttempted = false
        biometricPromptToken = UUID()
        isLocked = true

        overlayController.show(viewModel: model)
    }

    func presentSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettingsHandler?()
    }

    func setPassword(_ password: String) async throws {
        guard !isLocked else {
            throw PasswordVaultError.invalidFormat
        }

        let vault = self.vault
        try await Task.detached(priority: .userInitiated) {
            try vault.setPassword(password)
        }.value
        hasPassword = vault.hasPassword
    }

    func verifyPassword(_ password: String) async -> Bool {
        await vault.verify(password)
    }

    func setTouchIDEnabled(_ enabled: Bool) {
        refreshBiometricAvailability()

        if enabled && !biometricAvailability.isAvailable {
            presentAlert(
                title: "Touch ID 不可用",
                message: biometricAvailability.statusText
            )
            return
        }

        var updated = settings
        updated.touchIDEnabled = enabled
        settings = updated
        SettingsPersistence.save(updated)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let loginItem = LoginItemManager()
        do {
            try loginItem.setEnabled(enabled)
            refreshLoginItemStatus()
            if enabled && loginItem.requiresApproval {
                presentAlert(
                    title: "需要在系统设置中确认",
                    message: "macOS 要求你允许 Sentinel 在登录时打开。请在“系统设置 → 通用 → 登录项与扩展”中确认。"
                )
            }
        } catch {
            refreshLoginItemStatus()
            presentAlert(title: "无法更改登录项", message: error.localizedDescription)
        }
    }

    func requestAccessibilityPermission() {
        InputLockService.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        LoginItemManager().openLoginItemsSettings()
    }

    func setLockHotKey(_ hotKey: GlobalHotKey) {
        applyHotKeys(
            lock: hotKey,
            forceQuit: settings.forceQuitHotKey
        )
    }

    func setForceQuitHotKey(_ hotKey: GlobalHotKey) {
        applyHotKeys(
            lock: settings.lockHotKey,
            forceQuit: hotKey
        )
    }

    func resetHotKeys() {
        applyHotKeys(
            lock: .defaultLock,
            forceQuit: .defaultForceQuit
        )
    }

    func beginHotKeyRecording() {
        hotKeySuspensionDepth += 1
        if hotKeySuspensionDepth == 1 {
            hotKeyManager.unregisterAll()
        }
    }

    func endHotKeyRecording() {
        if hotKeySuspensionDepth > 0 {
            hotKeySuspensionDepth -= 1
        }
        if hotKeySuspensionDepth == 0 {
            restoreHotKeyRegistration()
        }
    }

    func forceEndHotKeyRecording() {
        hotKeySuspensionDepth = 0
        restoreHotKeyRegistration()
    }

    func refreshPermissionsAndSettings() {
        refreshAccessibilityStatus()
        refreshBiometricAvailability()
        refreshLoginItemStatus()
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = InputLockService.isAccessibilityTrusted
    }

    func refreshLoginItemStatus() {
        let manager = LoginItemManager()
        launchAtLoginEnabled = manager.isEnabled
        launchAtLoginRequiresApproval = manager.requiresApproval
    }

    func forceQuit() {
        tearDownProtection(restorePreviousApplication: false)
        hotKeyManager.stop()
        NSApp.terminate(nil)
    }

    func shutdown() {
        tearDownProtection(restorePreviousApplication: false)
        hotKeyManager.stop()
    }

    private func handleReveal() {
        guard isLocked, let model = lockViewModel, !model.showsPasswordEntry else {
            return
        }

        model.revealPasswordEntry()
        biometricTask?.cancel()
        biometricTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.attemptBiometricUnlockIfNeeded()
        }
    }

    private func handleDigit(_ digit: Character) {
        guard isLocked, let model = lockViewModel else {
            return
        }

        if model.isBiometricPrompting {
            biometricPromptToken = UUID()
            biometric.cancel()
            model.cancelBiometricPrompt()
        }

        let isComplete = model.appendDigit(digit)
        if isComplete {
            beginPasswordVerification()
        }
    }

    private func beginPasswordVerification() {
        guard let model = lockViewModel,
              model.enteredDigits.count == LockViewModel.passwordLength
        else {
            return
        }

        let candidate = model.enteredDigits
        model.beginVerification()
        verificationTask?.cancel()
        verificationTask = Task { [weak self] in
            guard let self else {
                return
            }
            let isValid = await self.vault.verify(candidate)
            guard !Task.isCancelled,
                  self.isLocked,
                  self.lockViewModel === model
            else {
                return
            }

            if isValid {
                self.completeUnlock()
            } else {
                model.rejectPassword()
            }
        }
    }

    private func attemptBiometricUnlockIfNeeded() {
        guard isLocked,
              !biometricAttempted,
              settings.touchIDEnabled,
              biometric.availability.isAvailable,
              let model = lockViewModel,
              model.showsPasswordEntry,
              model.enteredDigits.isEmpty,
              !model.isVerifying
        else {
            return
        }

        biometricAttempted = true
        let token = UUID()
        biometricPromptToken = token
        model.beginBiometricPrompt()

        biometricTask = Task { [weak self] in
            guard let self else {
                return
            }
            let success = await self.biometric.authenticate(
                reason: "验证身份以结束 Sentinel 输入保护"
            )
            guard !Task.isCancelled,
                  self.isLocked,
                  self.biometricPromptToken == token
            else {
                return
            }

            self.lockViewModel?.finishBiometricPrompt(success: success)
            if success {
                self.completeUnlock()
            }
        }
    }

    private func completeUnlock() {
        tearDownProtection(restorePreviousApplication: true)
    }

    private func tearDownProtection(restorePreviousApplication: Bool) {
        verificationTask?.cancel()
        verificationTask = nil
        biometricTask?.cancel()
        biometricTask = nil
        biometricPromptToken = UUID()
        biometric.cancel()

        inputLockService?.stop()
        inputLockService = nil
        overlayController.dismiss()
        isLocked = false
        lockViewModel = nil

        let application = previousApplication
        previousApplication = nil
        if restorePreviousApplication, let application, application != NSRunningApplication.current {
            DispatchQueue.main.async {
                application.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    private func applyHotKeys(lock: GlobalHotKey, forceQuit: GlobalHotKey) {
        guard lock != forceQuit else {
            hotKeyRegistrationError = "呼出快捷键与强制退出快捷键不能相同。"
            return
        }

        if hotKeySuspensionDepth == 0 {
            if let error = hotKeyManager.register(lock: lock, forceQuit: forceQuit) {
                hotKeyRegistrationError = error
                return
            }
        }

        var updated = settings
        updated.lockHotKey = lock
        updated.forceQuitHotKey = forceQuit
        settings = updated
        SettingsPersistence.save(updated)
        hotKeyRegistrationError = nil
    }

    private func restoreHotKeyRegistration() {
        if let error = hotKeyManager.register(
            lock: settings.lockHotKey,
            forceQuit: settings.forceQuitHotKey
        ) {
            hotKeyRegistrationError = error
            presentAlert(
                title: "快捷键注册失败",
                message: "\(error)\n\n请回到快捷键设置，改用其他组合。"
            )
        } else {
            hotKeyRegistrationError = nil
        }
    }

    private func refreshBiometricAvailability() {
        biometricAvailability = biometric.availability
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
