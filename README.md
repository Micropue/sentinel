# Sentinel

Sentinel 是一个只驻留在 macOS 菜单栏的原生输入保护工具。它适合在电脑执行长时间 AI 任务、渲染或下载时临时锁住键盘与鼠标，避免其他人中断或操作当前任务。

应用使用 Swift、SwiftUI、AppKit 与 macOS 27 SDK 构建，发布包原生支持 Apple Silicon（arm64）。

## 功能

- 菜单栏常驻，不在 Dock 显示，不创建启动主窗口
- 6 位数字解锁密码，使用 PBKDF2-SHA256 加盐摘要保存在 macOS 钥匙串
- 默认 `⌘⌥L` 呼出保护层，可在设置中录制新快捷键
- 默认 `⌘⌥⌃Q` 在保护层内强制退出 Sentinel
- 全屏 Liquid Glass 保护层，背景由系统合成器实时渲染，不截图、不录制屏幕
- 鼠标首次移动、滚动或点按后提高玻璃模糊与暗化强度，并显示密码界面
- 保护期间拦截键盘、修饰键、鼠标按键、拖动、滚轮和触控板指针事件
- 密码界面只接受主键盘或数字小键盘的 `0` 到 `9`，不响应鼠标点击
- 可选的 Touch ID 解锁；系统支持且已录入指纹时，可在密码界面出现后自动请求一次
- 多显示器时每一块屏幕都会显示保护层，只有主显示器显示密码键盘
- 支持登录时自动启动，并在解锁后恢复此前的前台应用

## 系统要求

- Apple Silicon Mac（arm64）
- macOS 14 或更高版本
- macOS 26 或更高版本会使用系统原生 `NSGlassEffectView` 材质
- macOS 14 至 15 会使用 `NSVisualEffectView` 实时材质回退

发布包在最新 macOS SDK 上编译，实际运行最低版本由 `Info.plist` 与 SwiftPM 部署目标决定。

## 安装

从 GitHub Releases 下载 `Sentinel-<版本>-macos-arm64.zip` 或 `.dmg`，将 `Sentinel.app` 放入“应用程序”文件夹。

发布包使用 ad-hoc 签名，没有经过 Apple Developer ID 公证。首次打开时可能需要在 Finder 中右键应用并选择“打开”。如果 macOS 仍然阻止打开，可在“系统设置 → 隐私与安全性”中允许本次运行。

由于每次重新签名或替换应用可能改变系统记录的权限身份，升级后可能需要重新确认辅助功能和登录项权限。

## 首次设置

1. 启动 Sentinel，菜单栏会出现盾牌图标。
2. 在自动打开的设置窗口中创建 6 位数字密码。
3. 打开“系统设置 → 隐私与安全性 → 辅助功能”，允许 Sentinel 控制此电脑。
4. 回到 Sentinel 设置，确认辅助功能状态为“已授权”。
5. 按需启用 Touch ID、登录时自动启动，并录制快捷键。

Sentinel 不会在缺少辅助功能权限时显示保护层。此设计避免出现鼠标和键盘仍能直接操作、保护层却看似已生效的假保护。

## 使用

- 按 `⌘⌥L` 或点击菜单栏中的 Sentinel，再选择“立即锁定”。
- 所有显示器会立即显示实时 Liquid Glass 保护层。
- 移动鼠标、点击或滚动后，主显示器会显示 6 个密码圆点和密码键盘。
- 直接从键盘输入 6 位数字。密码正确后保护层关闭，并恢复输入能力。
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
SENTINEL_VERSION=1.0.0 BUILD_NUMBER=1 Scripts/package.sh
```

打包脚本会：

1. 编译 arm64 Release 可执行文件
2. 组装 `dist/Sentinel.app`
3. 生成并嵌入 `.icns` 应用图标
4. 使用 ad-hoc 签名
5. 输出 ZIP 与 DMG

如果需要 Developer ID 公证版本，需要自行配置 Apple Developer 证书、`notarytool` 凭据，并修改打包与签名流程。

## 自动发布

`.github/workflows/release.yml` 监听以 `v` 开头的标签：

```bash
git tag v1.0.0
git push origin v1.0.0
```

工作流会在 `macos-latest` 上构建 arm64 应用，生成 ZIP 和 DMG，并附加到对应的 GitHub Release。

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
- 密码只以不可逆加盐摘要形式保存在本机钥匙串
- 保护层背景由 macOS 窗口合成与材质系统实时绘制

## 项目结构

```text
Sentinel/
  App/         应用入口、生命周期与协调器
  Models/      设置、快捷键与解锁状态
  Services/    钥匙串、密码、Touch ID、登录项、热键与输入拦截
  Views/       菜单栏、设置、全屏保护层与 Liquid Glass 材质
  Resources/   Info.plist
Scripts/       图标生成与应用打包
.github/       Release 工作流
```
