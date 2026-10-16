# LinkPort

[![CI](https://github.com/qianmokano/LinkPort/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/qianmokano/LinkPort/actions/workflows/ci.yml)

**每个链接，自由选择。** 原生 macOS 菜单栏工具：其他应用打开网站时，选择使用哪个浏览器，或者只复制网址。

[English](README.md) · [贡献指南](CONTRIBUTING.md) · [开发文档](docs/development.md) · [MIT 许可证](LICENSE)

![LinkPort 为示例网址显示浏览器选择卡片](docs/images/picker.png)

## 功能

- 在鼠标附近的紧凑卡片中选择已安装的浏览器。
- 处理系统交给默认浏览器的 HTTP/HTTPS 链接和本地 HTML/XHTML 文件。
- 按 `⌘C` 复制完整网址，保留编码、查询参数和片段。
- 调整浏览器顺序或隐藏浏览器，多条链接逐条处理。
- 支持键盘导航、多显示器及系统外观。
- 随时切换 English、简体中文或跟随系统，立即生效。
- 偏好仅保存在本机，无需账户，不含分析统计，不保存浏览历史。

LinkPort 使用 SwiftUI 和 AppKit，没有第三方运行时依赖。

## 系统要求与发布状态

| | 要求 |
| --- | --- |
| 运行 | macOS 26 或更新版本；Apple Silicon 或 Intel |
| 构建 | Xcode 27 或更新版本，包含 macOS 27 SDK 和 Swift 6.4 或更新版本 |
| 完整检查 | 上述构建工具，加上 Python 3.9 或更新版本（仅使用标准库） |

**[1.0.0 社区版](https://github.com/qianmokano/LinkPort/releases/tag/v1.0.0)。** 应用保留 **ad-hoc 签名**，未进行 Developer ID 签名和 Apple 公证。[发布指南](docs/releasing.md)分别说明这种社区版发行方式，以及 Developer ID 签名与公证的另一条发行路径。

已在 macOS 27 的 Apple Silicon 上本地试用。Intel 版本已完成交叉编译并通过 Rosetta 启动；Intel 真机和 macOS 26 仍需设备验证。详见[测试与兼容性](docs/testing.md)。

## 构建与安装

下载 **[LinkPort 1.0.0（Universal ZIP）](https://github.com/qianmokano/LinkPort/releases/download/v1.0.0/LinkPort.zip)**，同时支持 Apple Silicon 和 Intel。解压后将 `LinkPort.app` 移至“应用程序”并启动。已知限制见[发行说明](https://github.com/qianmokano/LinkPort/releases/tag/v1.0.0)；如果被 macOS 拦截，请按下方 [Gatekeeper 步骤](#首次打开被-gatekeeper-拦截)处理。

### 从源码构建

下载或检出源码，在项目目录打开终端并运行：

```sh
./scripts/build-app.sh
```

产物为 `dist/LinkPort.app`、`dist/LinkPort.zip` 和 `dist/SHA256SUMS`。将应用拖至 `/Applications` 或 `~/Applications`，再启动该安装副本。双击 LinkPort 会打开设置。

全局选中 Command Line Tools 时，脚本会使用已安装的 `/Applications/Xcode.app`。若 Xcode 位于其他位置，请将 `DEVELOPER_DIR` 指向其 `Contents/Developer` 目录。脚本不会修改全局开发工具配置。

在**设置 → 通用**中点击**设为默认浏览器**，并接受 macOS 确认；也可以在**系统设置 → 桌面与程序坞 → 默认网页浏览器**中选择 LinkPort。HTTP 和 HTTPS 均需指向 LinkPort。注册需要完整 `.app` 应用包，不能通过 `swift run` 安装。

也可以先点击通用设置中的**试试看**。预览只使用示例网址，选择浏览器之前不会打开网页。

### 首次打开被 Gatekeeper 拦截

当前包采用 ad-hoc 签名，未进行 Developer ID 签名和 Apple 公证。从互联网下载后，macOS 可能提示“无法验证开发者”或“Apple 无法检查 App 是不是包含恶意软件”。

仅在信任下载来源时继续。

1. 解压 ZIP，将 `LinkPort.app` 放入“应用程序”，先尝试打开一次。
2. 如果被拦截，关闭提示，进入**系统设置 → 隐私与安全性**。
3. 向下滚动至**安全性**，找到关于 LinkPort 的提示，点击**仍要打开**。
4. 查看再次出现的确认提示，确定继续时点击**打开**。macOS 会为该应用保存例外。

受管理的 Mac 可能由管理员限制此选项。如果提示“App 已损坏”或“将损坏你的电脑”，请停止打开，重新下载或联系维护者，不要将其当作普通的开发者验证提示处理。详见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

#### 终端处理方式

对于你确认可信的副本，也可以在终端移除下载隔离标记，然后再次打开应用：

```sh
xattr -dr com.apple.quarantine "/Applications/LinkPort.app"
```

如果安装在其他位置，请替换为实际路径。这条命令会递归移除指定应用及其内部文件的隔离标记，不会重新签名或进行 Apple 公证。测试上面的 Gatekeeper 处理流程时，请先保留隔离标记。

## 使用

点击其他应用中的链接后，选择一个浏览器。LinkPort 只处理通过系统默认浏览器打开的链接；应用内嵌网页和明确指定其他浏览器的操作仍由原应用处理。

| 快捷键 | 操作 |
| --- | --- |
| `⌘1`–`⌘9` | 使用前九个可见浏览器之一打开 |
| `←` `↑` `↓` `→`，然后 `Return` | 选择浏览器并打开 |
| `⌘C` | 将完整网址复制到系统剪贴板 |
| `Esc` 或点击外部 | 取消全部待处理链接 |

多条链接按顺序排队；仍在队列中的相同网址会合并。打开或复制后处理下一条，取消则清空队列。

从菜单栏打开**设置**，调整浏览器顺序和显示状态。启用的浏览器始终在前，可通过拖动或箭头按钮调整各组内顺序；拖动时停留在列表上下边缘可持续滚动。开启浏览器会将其移到启用组末尾，关闭则移到隐藏组开头；新发现的浏览器追加到启用组末尾。

关闭设置后，LinkPort 仍驻留菜单栏。退出后，macOS 可在下一次交来链接时再次启动它。应用不会自动配置登录启动。

<details>
<summary>通用设置（英文界面）</summary>

![LinkPort 的英文通用设置](docs/images/settings.png)

</details>

截图来自 macOS 27 上的实际应用，仅使用示例网址。浏览器列表和外观会随本机环境变化。

## 隐私与范围

LinkPort 本身不发送网络请求，也不保存网址历史。待处理网址仅保留在内存中，处理或取消后移除。UserDefaults 中仅保存浏览器顺序、显示状态、语言和欢迎提示偏好，偏好域为 `com.linkport.app`。选择浏览器会将网址交给该浏览器，`⌘C` 则将其写入系统剪贴板。

浏览器列表来自 macOS 注册的 HTTP/HTTPS 处理程序，因此其他链接路由工具也可能出现，可手动隐藏。支持的本地文件扩展名为 `.html`、`.htm`、`.xhtml` 和 `.xht`。当前不处理远程文件主机、其他文件类型及自定义 URL 协议，也不包含网站规则、浏览器 Profile、同步、扩展或自动更新。

## 恢复默认浏览器与卸载

先在系统设置中将默认网页浏览器改回 Safari 或其他浏览器，再退出 LinkPort 并删除应用。如需同时清除偏好，请在**退出应用后**运行：

```sh
defaults delete com.linkport.app
```

## 开发与参与

```sh
./scripts/test.sh    # Swift 测试及覆盖率
./scripts/check.sh   # 完整检查，包括 Universal 构建
```

请阅读[开发指南](docs/development.md)、[测试矩阵](docs/testing.md)和[贡献指南](CONTRIBUTING.md)。Issue 和 PR 均接受英文或中文。参与时遵守[行为准则](CODE_OF_CONDUCT.md)，安全问题请依照[安全政策](SECURITY.md)报告。

源码和协作入口为 [qianmokano/LinkPort](https://github.com/qianmokano/LinkPort)。问题与功能建议请使用 [Issues](https://github.com/qianmokano/LinkPort/issues)，检查结果见 [GitHub Actions](https://github.com/qianmokano/LinkPort/actions/workflows/ci.yml)，安全问题请使用[私密漏洞报告](https://github.com/qianmokano/LinkPort/security/advisories/new)。

## 许可证

LinkPort 代码、文档和原创分叉图标采用 [MIT 许可证](LICENSE)，版权 © 2026 qianmokano。系统显示的浏览器图标归各自权利人所有。
