import AppKit
import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case unlock
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .unlock: "解锁"
        case .shortcuts: "快捷键"
        case .about: "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .unlock: "lock.fill"
        case .shortcuts: "command"
        case .about: "info.circle"
        }
    }
}

private enum PasswordField: Hashable {
    case current
    case new
    case confirmation
}

@MainActor
private final class SettingsDraft: ObservableObject {
    @Published var selectedCategory: SettingsCategory = .general
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmation = ""
    @Published var isSavingPassword = false
    @Published var isImportingLegacyPassword = false
    @Published var showsPasswordEditor = false
    @Published var feedbackText: String?
    @Published var feedbackIsError = false
    @Published var hotKeyFeedback: String?
    @Published var hotKeyRegistrationMessage: String?
}

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    @StateObject private var draft = SettingsDraft()
    @StateObject private var recorder = HotKeyRecorder()
    @FocusState private var focusedPasswordField: PasswordField?

    var body: some View {
        TabView(selection: $draft.selectedCategory) {
            Tab("通用", systemImage: SettingsCategory.general.symbol, value: .general) {
                settingsForm { generalContent }
            }

            Tab("解锁", systemImage: SettingsCategory.unlock.symbol, value: .unlock) {
                settingsForm { unlockContent }
            }

            Tab("快捷键", systemImage: SettingsCategory.shortcuts.symbol, value: .shortcuts) {
                settingsForm { shortcutsContent }
            }

            Tab("关于", systemImage: SettingsCategory.about.symbol, value: .about) {
                settingsForm { aboutContent }
            }
        }
        .frame(
            minWidth: 540,
            idealWidth: 600,
            maxWidth: 680,
            minHeight: 440,
            idealHeight: 520,
            maxHeight: 620
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(
            Color(nsColor: .windowBackgroundColor),
            for: .windowToolbar
        )
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .onAppear {
            coordinator.refreshPermissionsAndSettings()
            if !coordinator.hasPassword {
                draft.selectedCategory = .unlock
                draft.showsPasswordEditor = true
            }
        }
        .onDisappear {
            recorder.cancel()
        }
        .onChange(of: draft.selectedCategory) {
            recorder.cancel()
        }
        .onChange(of: draft.showsPasswordEditor) {
            guard draft.showsPasswordEditor else {
                focusedPasswordField = nil
                return
            }

            DispatchQueue.main.async {
                focusedPasswordField = coordinator.hasPassword ? .current : .new
            }
        }
    }

    private func settingsForm<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var generalContent: some View {
        if !coordinator.hasPassword {
            Section("开始使用") {
                SettingsIconLabel(
                    symbol: "key.fill",
                    title: "先创建解锁密码",
                    subtitle: "设置 6 位数字密码后，才能启用全屏输入保护。",
                    tint: .orange
                )

                Button("前往解锁设置") {
                    draft.selectedCategory = .unlock
                    draft.showsPasswordEditor = true
                }
                .buttonStyle(.glassProminent)
            }
        }

        Section("系统权限") {
            LabeledContent {
                Label(
                    coordinator.accessibilityTrusted ? "已授权" : "未授权",
                    systemImage: coordinator.accessibilityTrusted
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    coordinator.accessibilityTrusted ? Color.green : Color.orange
                )
            } label: {
                SettingsIconLabel(
                    symbol: "accessibility",
                    title: "辅助功能",
                    subtitle: "拦截全系统键盘、鼠标与触控板事件",
                    tint: coordinator.accessibilityTrusted ? .green : .orange
                )
            }

            if !coordinator.accessibilityTrusted {
                Text("请允许 Sentinel 控制此电脑。没有该权限时，应用会拒绝显示保护层。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if !coordinator.accessibilityTrusted {
                    Button("请求授权") {
                        coordinator.requestAccessibilityPermission()
                    }
                    .buttonStyle(.glassProminent)
                }

                Button(coordinator.accessibilityTrusted ? "刷新状态" : "打开系统设置") {
                    if coordinator.accessibilityTrusted {
                        coordinator.refreshAccessibilityStatus()
                    } else {
                        coordinator.openAccessibilitySettings()
                    }
                }
                .buttonStyle(.glass)
            }
        }

        Section("启动与后台") {
            Toggle("登录时自动启动 Sentinel", isOn: launchAtLoginBinding)
                .disabled(coordinator.launchAtLoginRequiresApproval)

            if coordinator.launchAtLoginRequiresApproval {
                Text("macOS 正在等待你在“登录项与扩展”中确认。")
                    .foregroundStyle(.secondary)

                Button("打开登录项设置") {
                    coordinator.openLoginItemsSettings()
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private var unlockContent: some View {
        Section("解锁密码") {
            if coordinator.hasPassword && !draft.showsPasswordEditor {
                LabeledContent {
                    Label("已设置", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                } label: {
                    SettingsIconLabel(
                        symbol: "number",
                        title: "6 位数字密码",
                        subtitle: "键盘输入 6 个数字后自动解锁",
                        tint: .accentColor
                    )
                }

                Text("密码以加盐摘要形式保存在本机 Application Support，启动、锁定和解锁均不会访问钥匙串。")
                    .foregroundStyle(.secondary)

                if draft.feedbackText != nil {
                    feedbackLabel
                }

                Button("更改密码") {
                    clearPasswordFeedback()
                    draft.showsPasswordEditor = true
                }
                .buttonStyle(.glass)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !coordinator.hasPassword {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("从 1.1.3 或更早版本升级")
                                .font(.headline)

                            Text("旧版密码摘要保存在系统钥匙串。只有点击下方按钮时才会读取一次；日常启动、锁定和解锁不会访问钥匙串。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                importLegacyPassword()
                            } label: {
                                HStack(spacing: 6) {
                                    if draft.isImportingLegacyPassword {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text("导入旧版钥匙串密码")
                                }
                            }
                            .buttonStyle(.glass)
                            .disabled(
                                draft.isImportingLegacyPassword
                                    || draft.isSavingPassword
                            )
                        }
                        .padding(.vertical, 4)
                    }

                    if coordinator.hasPassword {
                        passwordInput(
                            title: "当前密码",
                            prompt: "输入当前 6 位密码",
                            text: currentPasswordBinding,
                            field: .current
                        )
                    }

                    passwordInput(
                        title: coordinator.hasPassword ? "新密码" : "创建密码",
                        prompt: "输入 6 位数字",
                        text: newPasswordBinding,
                        field: .new
                    )

                    passwordInput(
                        title: "确认密码",
                        prompt: "再次输入 6 位数字",
                        text: confirmationBinding,
                        field: .confirmation
                    )

                    if draft.feedbackText != nil {
                        feedbackLabel
                    }

                    HStack {
                        if coordinator.hasPassword {
                            Button("取消", role: .cancel) {
                                resetPasswordDraft()
                                clearPasswordFeedback()
                                draft.showsPasswordEditor = false
                            }
                            .buttonStyle(.glass)
                            .disabled(
                                draft.isSavingPassword
                                    || draft.isImportingLegacyPassword
                            )
                        }

                        Spacer()

                        Button {
                            savePassword()
                        } label: {
                            HStack(spacing: 6) {
                                if draft.isSavingPassword {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(coordinator.hasPassword ? "验证并更新" : "设置密码")
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(
                            !canSavePassword
                                || draft.isImportingLegacyPassword
                        )
                    }

                    Text("只能输入 0–9，共 6 位。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }

        Section("Touch ID") {
            Toggle("允许使用 Touch ID 解锁", isOn: touchIDBinding)
                .disabled(
                    !coordinator.hasPassword
                        || (
                            !coordinator.biometricAvailability.isAvailable
                                && !coordinator.settings.touchIDEnabled
                        )
                )

            LabeledContent("可用状态", value: coordinator.biometricAvailability.statusText)

            if !coordinator.hasPassword {
                Text("设置密码后才能启用 Touch ID 快捷解锁。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var shortcutsContent: some View {
        Section("呼出保护层") {
            shortcutRow(
                title: HotKeyTarget.lock.title,
                subtitle: "在任何 App 中呼出透明保护层",
                symbol: "lock.shield",
                hotKey: coordinator.settings.lockHotKey,
                target: .lock
            )
        }

        Section("紧急退出") {
            shortcutRow(
                title: HotKeyTarget.forceQuit.title,
                subtitle: "保护层内唯一允许的退出方式",
                symbol: "power",
                hotKey: coordinator.settings.forceQuitHotKey,
                target: .forceQuit
            )

            Text("录制时全局快捷键会暂时停用，按 Esc 可取消。组合键至少需要 ⌘、⌥ 或 ⌃ 中的任意一个修饰键。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Section {
            if let message = displayedHotKeyError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let hotKeyFeedback = draft.hotKeyFeedback {
                Label(hotKeyFeedback, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }

            Button("恢复默认快捷键") {
                recorder.cancel()
                draft.hotKeyFeedback = nil
                draft.hotKeyRegistrationMessage = nil
                coordinator.resetHotKeys()
                if coordinator.hotKeyRegistrationError == nil {
                    draft.hotKeyFeedback = "已恢复默认快捷键"
                }
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private var aboutContent: some View {
        Section {
            HStack(spacing: 14) {
                appMark

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sentinel")
                        .font(.title3.weight(.semibold))

                    Text("版本 v\(appVersion)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("macOS 27")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.vertical, 5)
        }

        Section("作者") {
            HStack(spacing: 14) {
                profileAvatar

                VStack(alignment: .leading, spacing: 3) {
                    Text("Micropue")
                        .font(.headline)

                    Text("Sentinel 作者")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            LabeledContent("GitHub") {
                Link(
                    "github.com/Micropue",
                    destination: URL(string: "https://github.com/Micropue")!
                )
            }

            LabeledContent("官网") {
                Link(
                    "micropue.com.cn",
                    destination: URL(string: "https://micropue.com.cn")!
                )
            }
        }

        Section("保护方式") {
            Label(
                "保护层不截图、不录制屏幕，背景由 macOS 合成器实时渲染。",
                systemImage: "rectangle.inset.filled"
            )
            Label(
                "所有显示器均由保护层覆盖，密码圆点只显示在主显示器。",
                systemImage: "display.2"
            )
            Label(
                "保护中请使用 \(coordinator.settings.forceQuitHotKey.displayString) 紧急退出。",
                systemImage: "power"
            )
        }

        Section("当前快捷键") {
            LabeledContent("呼出保护层") {
                Text(coordinator.settings.lockHotKey.displayString)
                    .monospacedDigit()
            }

            LabeledContent("紧急退出") {
                Text(coordinator.settings.forceQuitHotKey.displayString)
                    .monospacedDigit()
            }
        }

        Section("安全边界") {
            Text("Sentinel 不能防御 root、管理员、内核级程序、重启、恢复模式或物理断电。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("它用于防止非电脑拥有者在 AI 任务运行时误操作，不等同于固件级或硬件级锁定。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.accentColor.gradient)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: 46, height: 46)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }

    private var profileAvatar: some View {
        Group {
            if let url = Bundle.main.url(
                forResource: "MicropueAvatar",
                withExtension: "png"
            ),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func passwordInput(
        title: String,
        prompt: String,
        text: Binding<String>,
        field: PasswordField
    ) -> some View {
        LabeledContent(title) {
            SecureField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.bordered)
                .textInputBorderShape(.roundedRectangle)
                .pointerStyle(.horizontalText)
                .font(.body.monospacedDigit())
                .focused($focusedPasswordField, equals: field)
                .disabled(draft.isSavingPassword)
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
                .accessibilityLabel(Text(title))
        }
    }

    private func shortcutRow(
        title: String,
        subtitle: String,
        symbol: String,
        hotKey: GlobalHotKey,
        target: HotKeyTarget
    ) -> some View {
        LabeledContent {
            Button {
                toggleRecording(for: target)
            } label: {
                Label(
                    recorder.target == target ? "取消录制" : hotKey.displayString,
                    systemImage: recorder.target == target ? "escape" : "keyboard"
                )
                .monospacedDigit()
                .frame(minWidth: 108)
            }
            .buttonStyle(.glass)
            .tint(recorder.target == target ? Color.orange : Color.accentColor)
        } label: {
            SettingsIconLabel(
                symbol: symbol,
                title: title,
                subtitle: recorder.target == target
                    ? "\(recorder.hint) · Esc 取消"
                    : subtitle,
                tint: recorder.target == target ? .orange : .accentColor
            )
        }
    }

    private var feedbackLabel: some View {
        Label(
            draft.feedbackText ?? "",
            systemImage: draft.feedbackIsError
                ? "exclamationmark.circle.fill"
                : "checkmark.circle.fill"
        )
        .foregroundStyle(draft.feedbackIsError ? Color.red : Color.green)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var currentPasswordBinding: Binding<String> {
        Binding(
            get: { draft.currentPassword },
            set: { draft.currentPassword = sanitizePassword($0) }
        )
    }

    private var newPasswordBinding: Binding<String> {
        Binding(
            get: { draft.newPassword },
            set: { draft.newPassword = sanitizePassword($0) }
        )
    }

    private var confirmationBinding: Binding<String> {
        Binding(
            get: { draft.confirmation },
            set: { draft.confirmation = sanitizePassword($0) }
        )
    }

    private var touchIDBinding: Binding<Bool> {
        Binding(
            get: { coordinator.settings.touchIDEnabled },
            set: { coordinator.setTouchIDEnabled($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { coordinator.launchAtLoginEnabled },
            set: { coordinator.setLaunchAtLogin($0) }
        )
    }

    private var canSavePassword: Bool {
        guard !draft.isSavingPassword,
              isSixDigits(draft.newPassword),
              draft.newPassword == draft.confirmation
        else {
            return false
        }
        return !coordinator.hasPassword || isSixDigits(draft.currentPassword)
    }

    private var displayedHotKeyError: String? {
        coordinator.hotKeyRegistrationError ?? draft.hotKeyRegistrationMessage
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0.0"
    }

    private func sanitizePassword(_ value: String) -> String {
        String(value.filter { "0123456789".contains($0) }.prefix(6))
    }

    private func isSixDigits(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy { "0123456789".contains($0) }
    }

    private func savePassword() {
        guard canSavePassword else {
            return
        }

        clearPasswordFeedback()
        draft.isSavingPassword = true
        let previousPassword = draft.currentPassword
        let replacement = draft.newPassword

        Task { @MainActor in
            do {
                if coordinator.hasPassword {
                    let isVerified = await coordinator.verifyPassword(previousPassword)
                    guard isVerified else {
                        draft.feedbackIsError = true
                        draft.feedbackText = "当前密码不正确。"
                        draft.currentPassword = ""
                        draft.isSavingPassword = false
                        return
                    }
                }

                try await coordinator.setPassword(replacement)
                guard coordinator.hasPassword else {
                    throw PasswordVaultError.corruptRecord
                }

                resetPasswordDraft()
                draft.showsPasswordEditor = false
                draft.feedbackIsError = false
                draft.feedbackText = "解锁密码已安全保存。"
                draft.isSavingPassword = false
            } catch {
                draft.feedbackIsError = true
                draft.feedbackText = error.localizedDescription
                draft.isSavingPassword = false
            }
        }
    }

    private func importLegacyPassword() {
        guard !draft.isImportingLegacyPassword else {
            return
        }

        clearPasswordFeedback()
        draft.isImportingLegacyPassword = true

        Task { @MainActor in
            do {
                try await coordinator.importLegacyPasswordRecord()
                focusedPasswordField = nil
                draft.feedbackIsError = false
                draft.feedbackText = "已导入旧版密码摘要，后续解锁不再读取钥匙串。"
                draft.showsPasswordEditor = false
            } catch {
                draft.feedbackIsError = true
                draft.feedbackText = error.localizedDescription
            }
            draft.isImportingLegacyPassword = false
        }
    }

    private func resetPasswordDraft() {
        draft.currentPassword = ""
        draft.newPassword = ""
        draft.confirmation = ""
    }

    private func clearPasswordFeedback() {
        draft.feedbackText = nil
        draft.feedbackIsError = false
    }

    private func toggleRecording(for target: HotKeyTarget) {
        if recorder.target == target {
            recorder.cancel()
            return
        }

        draft.hotKeyFeedback = nil
        draft.hotKeyRegistrationMessage = nil
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
                draft.hotKeyRegistrationMessage = "呼出快捷键不能与强制关闭快捷键相同。"
                return
            }
            coordinator.setLockHotKey(hotKey)
            draft.hotKeyFeedback = "呼出快捷键已更新为 \(hotKey.displayString)"

        case .forceQuit:
            guard hotKey != coordinator.settings.lockHotKey else {
                draft.hotKeyRegistrationMessage = "强制关闭快捷键不能与呼出快捷键相同。"
                return
            }
            coordinator.setForceQuitHotKey(hotKey)
            draft.hotKeyFeedback = "强制关闭快捷键已更新为 \(hotKey.displayString)"
        }
    }
}

private struct SettingsIconLabel: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
