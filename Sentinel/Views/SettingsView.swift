import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    @StateObject private var recorder = HotKeyRecorder()
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSavingPassword = false
    @State private var showsPasswordEditor = false
    @State private var feedbackText: String?
    @State private var feedbackIsError = false
    @State private var hotKeyFeedback: String?
    @State private var hotKeyRegistrationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !coordinator.hasPassword {
                    setupBanner
                }

                permissionsCard
                passwordCard
                authenticationCard
                shortcutsCard
                startupCard
                footer
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
        }
        .background(SettingsCanvas())
        .frame(minWidth: 720, idealWidth: 790, minHeight: 620, idealHeight: 760)
        .onAppear {
            coordinator.refreshPermissionsAndSettings()
            if !coordinator.hasPassword {
                showsPasswordEditor = true
            }
        }
        .onDisappear {
            recorder.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.43, blue: 0.73),
                                Color(red: 0.33, green: 0.23, blue: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.96))
            }
            .frame(width: 58, height: 58)
            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 7)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Sentinel")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("v\(appVersion)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                Text("AI 任务运行时，把键盘和鼠标交给保护层。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Circle()
                    .fill(protectionColor)
                    .frame(width: 7, height: 7)
                Text(protectionStatus)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.055), in: Capsule())
        }
    }

    private var setupBanner: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "key.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("先创建解锁密码")
                    .font(.system(size: 13, weight: .semibold))
                Text("设置一组 6 位数字密码后，菜单栏中的“立即锁定”才会启用。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var permissionsCard: some View {
        SettingsCard(
            title: "系统权限",
            subtitle: "保护层必须先拿到全系统输入拦截能力，才会出现。",
            systemImage: "hand.raised.fill"
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: coordinator.accessibilityTrusted
                      ? "checkmark.circle.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(coordinator.accessibilityTrusted ? Color.green : Color.orange)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.accessibilityTrusted ? "辅助功能权限已授权" : "辅助功能权限未授权")
                        .font(.system(size: 13, weight: .semibold))
                    Text(
                        coordinator.accessibilityTrusted
                            ? "Sentinel 已可拦截全系统的键盘、鼠标与触控板事件。"
                            : "请允许 Sentinel 控制此电脑。没有该权限时，应用会拒绝显示保护层，避免产生可被绕过的假保护。"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    if !coordinator.accessibilityTrusted {
                        Button("请求授权") {
                            coordinator.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(coordinator.accessibilityTrusted ? "刷新状态" : "系统设置") {
                        if coordinator.accessibilityTrusted {
                            coordinator.refreshAccessibilityStatus()
                        } else {
                            coordinator.openAccessibilitySettings()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var passwordCard: some View {
        SettingsCard(
            title: "解锁密码",
            subtitle: "键盘只会接受 0–9，密码不会离开本机钥匙串。",
            systemImage: "number.square.fill"
        ) {
            if coordinator.hasPassword && !showsPasswordEditor {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("已设置 6 位数字密码")
                            .font(.system(size: 13, weight: .medium))
                        Text("PBKDF2-SHA256 加盐摘要，保存在 macOS 钥匙串")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("更改密码") {
                        clearPasswordFeedback()
                        showsPasswordEditor = true
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 13) {
                    if coordinator.hasPassword {
                        CodeSecureField(
                            title: "当前密码",
                            text: $currentPassword,
                            isDisabled: isSavingPassword
                        )
                    }

                    HStack(alignment: .top, spacing: 12) {
                        CodeSecureField(
                            title: coordinator.hasPassword ? "新密码" : "创建 6 位密码",
                            text: $newPassword,
                            isDisabled: isSavingPassword
                        )
                        CodeSecureField(
                            title: "再次输入",
                            text: $confirmation,
                            isDisabled: isSavingPassword
                        )
                    }

                    if let feedbackText {
                        Label(
                            feedbackText,
                            systemImage: feedbackIsError
                                ? "exclamationmark.circle.fill"
                                : "checkmark.circle.fill"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(feedbackIsError ? Color.red : Color.green)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 9) {
                        Text("只能是 0–9，共 6 位。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)

                        Spacer()

                        if coordinator.hasPassword {
                            Button("取消") {
                                resetPasswordDraft()
                                showsPasswordEditor = false
                            }
                            .disabled(isSavingPassword)
                        }

                        Button {
                            savePassword()
                        } label: {
                            HStack(spacing: 6) {
                                if isSavingPassword {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                                Text(coordinator.hasPassword ? "验证并更新" : "设置密码")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSavePassword)
                    }
                }
            }

            if let feedbackText, coordinator.hasPassword, !showsPasswordEditor {
                Label(
                    feedbackText,
                    systemImage: feedbackIsError
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(feedbackIsError ? Color.red : Color.green)
            }
        }
    }

    private var authenticationCard: some View {
        SettingsCard(
            title: "生物识别",
            subtitle: "呼出密码界面后，可自动请求一次 Touch ID。",
            systemImage: "touchid"
        ) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "允许使用 Touch ID 解锁",
                        isOn: Binding(
                            get: { coordinator.settings.touchIDEnabled },
                            set: { coordinator.setTouchIDEnabled($0) }
                        )
                    )
                    .font(.system(size: 13, weight: .medium))
                    .disabled(
                        !coordinator.hasPassword
                            || (
                                !coordinator.biometricAvailability.isAvailable
                                    && !coordinator.settings.touchIDEnabled
                            )
                    )

                    Text(coordinator.biometricAvailability.statusText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)

                    if !coordinator.hasPassword {
                        Text("设置密码后才能启用 Touch ID 快捷解锁。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "touchid")
                    .font(.system(size: 31, weight: .light))
                    .foregroundStyle(Color.accentColor.opacity(0.72))
            }
        }
    }

    private var shortcutsCard: some View {
        SettingsCard(
            title: "全局快捷键",
            subtitle: "录制时全局快捷键会暂时停用，按 Esc 可取消。",
            systemImage: "keyboard"
        ) {
            VStack(spacing: 0) {
                HotKeySettingRow(
                    title: HotKeyTarget.lock.title,
                    subtitle: "随时呼出 Liquid Glass 保护层",
                    hotKey: coordinator.settings.lockHotKey,
                    isRecording: recorder.target == .lock,
                    hint: recorder.target == .lock
                        ? "\(recorder.hint) · Esc 取消"
                        : nil,
                    action: {
                        toggleRecording(for: .lock)
                    }
                )

                Divider()
                    .padding(.vertical, 11)

                HotKeySettingRow(
                    title: HotKeyTarget.forceQuit.title,
                    subtitle: "保护层内唯一允许的退出方式",
                    hotKey: coordinator.settings.forceQuitHotKey,
                    isRecording: recorder.target == .forceQuit,
                    hint: recorder.target == .forceQuit
                        ? "\(recorder.hint) · Esc 取消"
                        : nil,
                    action: {
                        toggleRecording(for: .forceQuit)
                    }
                )
            }

            if let message = displayedHotKeyError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            } else if let hotKeyFeedback {
                Label(hotKeyFeedback, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.green)
                    .padding(.top, 12)
            }

            HStack {
                Text("快捷键至少需要 ⌘、⌥ 或 ⌃ 中的任意一个修饰键。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("恢复默认") {
                    recorder.cancel()
                    hotKeyFeedback = nil
                    coordinator.resetHotKeys()
                    if coordinator.hotKeyRegistrationError == nil {
                        hotKeyFeedback = "已恢复默认快捷键"
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 12)
        }
    }

    private var startupCard: some View {
        SettingsCard(
            title: "启动与后台",
            subtitle: "应用只在菜单栏出现，不会占用 Dock 或打开主窗口。",
            systemImage: "menubar.rectangle"
        ) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle(
                        "登录时自动启动 Sentinel",
                        isOn: Binding(
                            get: { coordinator.launchAtLoginEnabled },
                            set: { coordinator.setLaunchAtLogin($0) }
                        )
                    )
                    .font(.system(size: 13, weight: .medium))
                    .disabled(coordinator.launchAtLoginRequiresApproval)

                    Text(startupStatusText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if coordinator.launchAtLoginRequiresApproval {
                    Button("打开登录项设置") {
                        coordinator.openLoginItemsSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                "保护层不截图、不录制屏幕，背景画面由 macOS 合成器实时渲染。",
                systemImage: "eye.slash"
            )
            Label(
                "保护中请使用 \(coordinator.settings.forceQuitHotKey.displayString) 紧急退出。",
                systemImage: "power"
            )
            Text("Sentinel 不能防御 root、管理员、内核级程序、重启、恢复模式或物理断电。")
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var protectionStatus: String {
        if !coordinator.hasPassword {
            return "等待设置"
        }
        return coordinator.accessibilityTrusted ? "保护就绪" : "需要权限"
    }

    private var protectionColor: Color {
        if !coordinator.hasPassword {
            return .orange
        }
        return coordinator.accessibilityTrusted ? .green : .orange
    }

    private var startupStatusText: String {
        if coordinator.launchAtLoginRequiresApproval {
            return "macOS 正在等待你在“登录项与扩展”中确认。"
        }
        return coordinator.launchAtLoginEnabled
            ? "下次登录 Mac 时会自动在菜单栏启动。"
            : "目前仅在手动打开时运行。"
    }

    private var canSavePassword: Bool {
        guard !isSavingPassword,
              isSixDigits(newPassword),
              newPassword == confirmation
        else {
            return false
        }
        return !coordinator.hasPassword || isSixDigits(currentPassword)
    }

    private var displayedHotKeyError: String? {
        coordinator.hotKeyRegistrationError ?? hotKeyRegistrationMessage
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func isSixDigits(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy { "0123456789".contains($0) }
    }

    private func savePassword() {
        guard canSavePassword else {
            return
        }

        clearPasswordFeedback()
        isSavingPassword = true
        let previousPassword = currentPassword
        let replacement = newPassword

        Task { @MainActor in
            do {
                if coordinator.hasPassword {
                    let isVerified = await coordinator.verifyPassword(previousPassword)
                    guard isVerified else {
                        feedbackIsError = true
                        feedbackText = "当前密码不正确。"
                        currentPassword = ""
                        isSavingPassword = false
                        return
                    }
                }

                try await coordinator.setPassword(replacement)
                guard coordinator.hasPassword else {
                    throw PasswordVaultError.corruptRecord
                }

                resetPasswordDraft()
                showsPasswordEditor = false
                feedbackIsError = false
                feedbackText = "解锁密码已安全保存。"
                isSavingPassword = false
            } catch {
                feedbackIsError = true
                feedbackText = error.localizedDescription
                isSavingPassword = false
            }
        }
    }

    private func resetPasswordDraft() {
        currentPassword = ""
        newPassword = ""
        confirmation = ""
    }

    private func clearPasswordFeedback() {
        feedbackText = nil
        feedbackIsError = false
    }

    private func toggleRecording(for target: HotKeyTarget) {
        if recorder.target == target {
            recorder.cancel()
            return
        }

        hotKeyFeedback = nil
        hotKeyRegistrationMessage = nil
        recorder.start(
            target: target,
            onBegin: {
                coordinator.beginHotKeyRecording()
            },
            onEnd: {
                coordinator.endHotKeyRecording()
            },
            onRecord: { target, hotKey in
                applyRecordedHotKey(hotKey, for: target)
            }
        )
    }

    private func applyRecordedHotKey(_ hotKey: GlobalHotKey, for target: HotKeyTarget) {
        switch target {
        case .lock:
            guard hotKey != coordinator.settings.forceQuitHotKey else {
                hotKeyRegistrationMessage = "呼出快捷键不能与强制关闭快捷键相同。"
                return
            }
            coordinator.setLockHotKey(hotKey)
            hotKeyFeedback = "呼出快捷键已更新为 \(hotKey.displayString)"

        case .forceQuit:
            guard hotKey != coordinator.settings.lockHotKey else {
                hotKeyRegistrationMessage = "强制关闭快捷键不能与呼出快捷键相同。"
                return
            }
            coordinator.setForceQuitHotKey(hotKey)
            hotKeyFeedback = "强制关闭快捷键已更新为 \(hotKey.displayString)"
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 16, y: 6)
    }
}

private struct HotKeySettingRow: View {
    let title: String
    let subtitle: String
    let hotKey: GlobalHotKey
    let isRecording: Bool
    let hint: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(hint ?? subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(isRecording ? Color.orange : Color.secondary)
                    .contentTransition(.opacity)
            }

            Spacer()

            Button(action: action) {
                HStack(spacing: 7) {
                    Image(systemName: isRecording ? "escape" : "keyboard")
                    Text(isRecording ? "取消录制" : hotKey.displayString)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(minWidth: 104)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .orange : .accentColor)
        }
    }
}

private struct CodeSecureField: View {
    let title: String
    @Binding var text: String
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(text.count)/6")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            SecureField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .disabled(isDisabled)
                .onChange(of: text) { _, newValue in
                    let filtered = String(newValue.filter { "0123456789".contains($0) }.prefix(6))
                    if filtered != newValue {
                        text = filtered
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsCanvas: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [
                    Color(red: 0.17, green: 0.48, blue: 0.86).opacity(0.12),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color(red: 0.47, green: 0.29, blue: 0.79).opacity(0.08),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}
