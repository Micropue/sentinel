# Sentinel

Sentinel 是一个只驻留在 macOS 菜单栏的原生输入保护工具。它适合在电脑执行长时间 AI 任务、渲染或下载时临时锁住键盘与鼠标，避免其他人中断或操作当前任务。

应用使用 Swift、SwiftUI、AppKit 与 macOS 27 SDK 构建，发布包原生支持 Apple Silicon（arm64）。

<p>
  <img alt="macOS 27 SDK" src="https://img.shields.io/badge/macOS_27-SDK-000000?style=flat-square&logo=apple&logoColor=white">
  <img alt="Swift 6.4" src="https://img.shields.io/badge/Swift-6.4-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF?style=flat-square&logo=swift&logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple_Silicon-arm64-111111?style=flat-square&logo=apple&logoColor=white">
  <img alt="Menu bar app" src="https://img.shields.io/badge/LSUIElement-menu_bar-5E5CE6?style=flat-square">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-blue?style=flat-square"></a>
</p>

## 功能

- 菜单栏常驻，不在 Dock 显示，不创建启动主窗口
- 6 位数字解锁密码，以 PBKDF2-HMAC-SHA256 加盐摘要保存在本机 Application Support
- 启动、锁定和解锁流程不读取钥匙串；旧版用户可主动导入一次钥匙串中的密码摘要
- 默认 `⌘⌥L` 呼出保护层，可在设置中录制新快捷键
- 默认 `⌘⌥⌃Q` 在保护层内强制退出 Sentinel
- 全屏保护层默认完全透明，直接显示桌面与实时运行的任务，不截图、不录制屏幕
- 移动鼠标、滚动、点按或按键后，由 macOS 实时增加背景模糊并显示六位密码圆点
- 保护期间拦截键盘、修饰键、鼠标按键、拖动、滚轮和触控板指针事件
- 解锁界面只显示六个圆点，不显示数字键盘；每位密码输入后对应圆点变为实心
- 10 秒无输入后自动清除已输入内容，重新隐藏圆点并恢复完全透明
- 可选的 Touch ID 解锁；系统支持且已录入指纹时，可在密码界面出现后自动请求一次
- 多显示器时每一块屏幕都会显示保护层，只有主显示器显示密码圆点
- 支持登录时自动启动，并在解锁后恢复此前的前台应用

## 系统要求

- Apple Silicon Mac（arm64）
- macOS 27 或更高版本

应用使用 macOS 27 SDK 构建，部署目标同为 macOS 27，以启用当前系统的原生窗口外观和 Liquid Glass 控件。

## 安装

从 GitHub Releases 下载 `Sentinel-<版本>-macos-arm64.zip` 或 `.dmg`，将 `Sentinel.app` 放入“应用程序”文件夹。

未配置签名证书时，发布包使用 ad-hoc 签名，也没有经过 Apple Developer ID 公证。首次打开时可能需要在 Finder 中右键应用并选择“打开”。如果 macOS 仍然阻止打开，可在“系统设置 → 隐私与安全性”中允许本次运行。

辅助功能授权由 macOS TCC 绑定到代码签名身份。ad-hoc 构建在重新编译后签名身份会变化，因此升级后可能仍被要求重新授权；这是系统机制，应用无法在未获授权时绕过。要跨版本保留授权，Release 必须使用固定证书签名。打包脚本会自动优先选择本机钥匙串中的 `Developer ID Application` 或 `Apple Development` 身份，也可以通过 `SENTINEL_SIGNING_IDENTITY` 显式指定。

## 首次设置

1. 启动 Sentinel，菜单栏会出现盾牌图标。
2. 在自动打开的设置窗口中创建 6 位数字密码。
3. 打开“系统设置 → 隐私与安全性 → 辅助功能”，允许 Sentinel 控制此电脑。
4. 回到 Sentinel 设置，确认辅助功能状态为“已授权”。
5. 按需启用 Touch ID、登录时自动启动，并录制快捷键。

Sentinel 不会在缺少辅助功能权限时显示保护层。此设计避免出现鼠标和键盘仍能直接操作、保护层却看似已生效的假保护。

Sentinel 不会在每次启动或锁定时自动请求辅助功能权限。首次授权请只在设置页点击“请求授权”；之后 macOS 会复用该授权。如果控制台提示旧版钥匙串数据，可从“解锁”设置页点击“导入旧版钥匙串密码”，仅该操作会读取一次钥匙串。

### 升级后排障

- 如果每次启动都弹出钥匙串访问请求，说明仍在运行 1.1.3 或更早版本。升级到 1.1.4 后，启动、锁定和解锁不会再读取钥匙串。
- 如果升级到 1.1.4 后辅助功能状态变回“未授权”，这是 ad-hoc 签名的二进制发生变化后 macOS 重置 TCC 的结果。重新授权一次即可；后续正常启动不会再次请求。要在后续版本间持续保留授权，需按下方说明配置固定签名证书。
- 不要把不同的 Sentinel 构建分别放在“下载”和“应用程序”中交替打开。始终保留“应用程序”中的同一份安装。

## 使用

- 按 `⌘⌥L` 或点击菜单栏中的 Sentinel，再选择“立即锁定”。
- 所有显示器会立即覆盖完全透明的保护层，各屏幕左上角显示一个黑色圆形锁头。
- 移动鼠标、点击、滚动或按下任意键后，背景实时增加模糊，主显示器显示 6 个密码圆点。
- 直接从键盘输入 6 位数字，圆点会逐位变为实心。密码正确后保护层关闭，并恢复输入能力。
- 若 10 秒内没有新的输入，Sentinel 会清除已输入数字并恢复完全透明，但电脑仍保持锁定。
- 如果启用了 Touch ID，系统会在密码界面出现后请求一次指纹验证。
- 保护层内如遇紧急情况，按 `⌘⌥⌃Q` 强制退出 Sentinel。

## 设置

设置窗口提供：

- 创建或更改解锁密码
- 启用或关闭 Touch ID
- 修改呼出与强制退出快捷键
- 查看、请求或打开辅助功能权限设置
- 启用登录时自动启动
- 恢复默认快捷键

录制快捷键时，全局快捷键会暂时停用。按 `Esc` 可以取消录制；新组合键至少需要 `⌘`、`⌥` 或 `⌃` 中的一个修饰键，并且两个快捷键不能相同。

## 构建

仓库使用 Swift Package Manager，不需要 `.xcodeproj`：

```bash
swift build -c release --arch arm64
```

本地生成可分发应用：

```bash
chmod +x Scripts/package.sh
SENTINEL_VERSION=1.1.4 BUILD_NUMBER=1 Scripts/package.sh
```

打包脚本会：

1. 编译 arm64 Release 可执行文件
2. 组装 `dist/Sentinel.app`
3. 生成并嵌入 `.icns` 应用图标
4. 优先使用本机稳定签名身份；没有证书时回退为 ad-hoc 签名
5. 输出 ZIP 与 DMG

显式指定签名身份：

```bash
SENTINEL_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
SENTINEL_VERSION=1.1.4 \
Scripts/package.sh
```

对自签名证书或其他不提供时间戳服务的证书，可以设置 `SENTINEL_TIMESTAMP=0`。固定证书只能解决签名身份变化导致的授权重置；若还需免右键打开和 Gatekeeper 校验，应使用 Developer ID 并完成 `notarytool` 公证。

## 自动发布

`.github/workflows/release.yml` 监听以 `v` 开头的标签：

```bash
git tag v1.1.4
git push origin v1.1.4
```

工作流会在 `xcode-27`（macOS 27 / arm64）运行器上构建应用，生成 ZIP 和 DMG，并附加到对应的 GitHub Release。

要让 GitHub Release 保持稳定的代码签名身份，在仓库 Actions Secrets 中配置：

- `MACOS_CERTIFICATE_P12_BASE64`：代码签名证书与私钥导出的 `.p12` 文件，经 Base64 编码
- `MACOS_CERTIFICATE_PASSWORD`：`.p12` 密码
- `MACOS_KEYCHAIN_PASSWORD`：工作流临时钥匙串密码

工作流只在证书 Secret 存在时导入身份；未配置时仍会完成 ad-hoc 构建，但不能保证辅助功能授权跨版本保留。私钥不要提交到仓库。

## 许可证

本项目采用 [MIT License](LICENSE)。Copyright (c) 2026 Micropue。

## 安全边界

Sentinel 是用户态应用，目标是防止普通用户在保护层开启时误操作或直接使用键盘鼠标。它不是内核安全产品，也不提供硬件级锁定。

它不能防御：

- root、管理员权限或恶意内核扩展
- 远程登录、SSH、屏幕共享或其他独立的系统控制通道
- 强制重启、关机、恢复模式、物理断电或外接硬件攻击
- 系统安全认证、关机确认、Touch ID 等由 macOS 自己管理的安全界面
- 具有更高安全级别或绕过普通事件拦截能力的软件

不要在不可信环境中把 Sentinel 当作唯一的保密措施。怀疑系统已被入侵时，应停止任务、断开网络并完整关机。

## 隐私

- Sentinel 不截屏、不录屏、不读取屏幕像素
- 不访问网络
- 不收集分析数据或遥测
- 密码只以不可逆加盐摘要形式保存在 `~/Library/Application Support/com.micropue.sentinel/unlock.json`
- 该文件权限设置为仅当前用户可读写，日常运行不访问钥匙串
- 保护层背景由 macOS 窗口合成与材质系统实时绘制

## 项目结构

```text
Sentinel/
  App/         应用入口、生命周期与协调器
  Models/      设置、快捷键与解锁状态
  Services/    本地凭据、旧版迁移、Touch ID、登录项、热键与输入拦截
  Views/       菜单栏、设置、全屏保护层与系统模糊背景
  Resources/   Info.plist
Scripts/       图标生成与应用打包
.github/       Release 工作流
```
