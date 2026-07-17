# Codexcator

macOS 原生菜单栏工具，用于展示本机 Codex 的：

- 5 小时剩余额度；Codex 暂不返回该窗口时整行隐藏
- 7 天剩余额度
- 各额度窗口的北京时间重置时间
- 可用重置卡数量与每张卡的北京时间过期时间
- 内置 Stay Awake（Caffeine）功能，可按 5/10/15/30 分钟、1/2/5 小时或无限期阻止显示器与 Mac 因空闲休眠
- English 与简体中文；跟随 macOS 系统语言或“App Language”设置
- macOS 26+ 使用原生 Liquid Glass 面板与玻璃按钮；macOS 14–15 自动回退为系统材质
- 菜单栏入口由 AppKit `NSStatusItem` 持有，不受 SwiftUI 菜单项“已移除”状态影响
- 深色青绿双环 App Icon，包含完整 macOS 16–1024 px 尺寸集

## 本地运行

要求 macOS 14+、Xcode 16+，并确保本机 ChatGPT/Codex 已登录。

```bash
./script/build_and_run.sh
```

程序是 `LSUIElement` 菜单栏 App，不显示 Dock 图标。构建后的 App 位于：

```text
build/DerivedData/Build/Products/Debug/Codexcator.app
```

常用验证命令：

```bash
swift test
./script/build_and_run.sh --verify
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --render-preview
./script/build_and_run.sh --package-release
```

`--package-release` 会生成不含调试文件的 Universal Release ZIP，同时支持
Apple Silicon 与 Intel。由于 App 使用 ad-hoc 签名而非 Apple Developer ID，
通过微信、浏览器等方式传输后 macOS 会添加隔离标记。如果双击无法打开，先将
App 移到“应用程序”，再运行：

```bash
xattr -dr com.apple.quarantine "/Applications/Codexcator.app"
open "/Applications/Codexcator.app"
```

这一步不需要管理员密码，但只应对可信来源的 App 执行。若希望接收者无需此步骤，
则必须使用 Developer ID 签名并完成 Apple 公证。

如果安装了 Bartender 等菜单栏管理工具，请在该工具中把 Codexcator 设置为
始终显示；此类工具可以在 App 已正常创建状态项后继续将它放入隐藏区。

## 数据与隐私

App 通过本机 `codex app-server --stdio` 的 `account/rateLimits/read` 读取数据，不上传数据，也不保存登录令牌、账号 ID 或邮箱。最近一次成功额度仅缓存在本机 Application Support 目录。

从 Finder 启动时，App 会保留已有的 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、
`CODEX_CA_CERTIFICATE` 和 `SSL_CERT_FILE`，并在未设置代理环境变量时读取 macOS
系统的 HTTP、HTTPS 或 SOCKS 代理，再传给 `codex app-server`。代理地址和证书路径
不会写入日志。

App 会依次尝试本机 Codex CLI、PATH 中的 Codex 和 ChatGPT 内置 Codex，并选择首个
能够返回额度的版本。额度仅适用于 ChatGPT Codex 登录；API Key 登录不包含 ChatGPT
订阅额度。若本机所有 Codex 版本都不支持 `account/rateLimits/read`，App 会提示更新
ChatGPT 或 Codex CLI。

本项目面向个人本机使用，构建脚本采用无开发者账号签名的本地构建方式，不需要 Apple Developer Program。

## Stay Awake

弹窗中的“保持唤醒”使用 macOS 原生 `ProcessInfo` 活动断言，不依赖外部
Caffeine 或 `caffeinate` 进程。开启后只阻止 Mac 因用户空闲进入系统睡眠，不会阻止
显示器按 macOS 的锁屏与显示器睡眠设置熄灭；选择有限时长时会在到期后自动释放，
无限期状态会在 App 重启后恢复。

该功能不会阻止用户手动选择睡眠、合上 MacBook 屏幕、低电量或系统因其他安全原因
进入睡眠。退出 Codexcator 时，当前进程持有的活动断言会立即释放。

## 语言

App、菜单栏、设置和错误提示均支持 English 与简体中文。默认跟随 macOS 语言，也可以在“系统设置 → 通用 → 语言与地区 → 应用程序”中单独指定 Codexcator 的语言；切换后重新启动 App 生效。

## App Icon

图标主稿保存在 `Design/AppIcon-master.png`，生产尺寸集位于 `Assets.xcassets/AppIcon.appiconset`。Xcode 会在构建时生成并写入 `AppIcon.icns`；菜单栏仍保留额度文字，方便直接读取剩余百分比。
