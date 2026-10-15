# LinkPort

原生 macOS 菜单栏浏览器选择器。外部应用打开网站时，在鼠标附近选择浏览器，或者只复制网址。

支持 **macOS 26+、Apple Silicon 和 Intel**。使用 SwiftUI + AppKit，无第三方依赖。

## 构建与安装

需要 macOS 26 SDK、Swift 6.2 或更新的命令行开发工具。可用 `xcode-select --install` 安装工具，无需完整 Xcode。

```sh
./scripts/build-app.sh
open dist/LinkPort.app
```

脚本分别编译 arm64、x86_64，合并 Universal 二进制，生成图标并进行本机 ad-hoc 签名。最终产物位于 `dist/LinkPort.app`，同时生成便于复制的 `dist/LinkPort.zip`。也可以用 Xcode 打开 `Package.swift` 浏览和编辑源码；注册为默认浏览器时必须运行完整 `.app`，不能只使用 `swift run`。

建议把 `LinkPort.app` 拖至 `/Applications` 或 `~/Applications` 后再启动，在「通用」页点击「设为默认浏览器」并接受 macOS 的确认。应用会检查 HTTP 和 HTTPS 两种处理器状态。也可以在「系统设置 → 桌面与程序坞 → 默认网页浏览器」手动选择 LinkPort。

本机签名用于本机使用，当前产物没有 Developer ID 签名和 Apple 公证，不能作为面向其他用户的正式发行包。

## 使用

- 点击邮件、终端或其他应用中交给系统默认浏览器的 HTTP/HTTPS 链接，鼠标附近会出现选择卡片。
- 点击浏览器打开，点击「复制网址」只复制；路径、查询参数、百分号编码和片段均保留。
- `⌘1–9` 直接选择前九个可见浏览器；方向键移动，回车打开；`⌘C` 复制；`Esc` 或点击外部取消。
- 多条链接逐条排队，选择或复制后处理下一条。仍在队列中的相同网址合并；取消会清空整个待处理队列。
- 从菜单栏打开「设置」，在「浏览器」页拖动排序、使用上下箭头调整位置，或隐藏/恢复浏览器。新发现的应用追加到已有顺序之后。
- 「预览选择卡片」可在不更改默认浏览器的情况下体验功能。
- 双击应用会打开设置。关闭设置窗口后菜单栏仍保留；退出后，下一次系统交来链接时应用会自动启动。不自动配置登录启动。

卡片支持多屏幕定位、浅色/深色外观、键盘导航及辅助功能标签。界面跟随系统显示简体中文或英文，其他语言回退至英文。

## 恢复默认浏览器与卸载

先在系统设置中把默认网页浏览器改回 Safari 或其他浏览器，再退出 LinkPort 并删除应用。偏好保存在 `com.linkport.app` 的 UserDefaults 中；网址不会写入偏好或日志。运行期间尚未处理的网址只在内存中保存。

## 测试

```sh
./scripts/test.sh
lipo -archs dist/LinkPort.app/Contents/MacOS/LinkPort
codesign --verify --strict dist/LinkPort.app
open -a "$PWD/dist/LinkPort.app" 'https://example.com/path?x=1&next=%2Fwork#section'
```

自动化测试使用可替换的系统服务和独立 UserDefaults，覆盖链接校验、队列去重、参数保留、排序隐藏、偏好、取消竞态、打开/复制失败和默认处理器拒绝。

测试脚本在必要时仅为当前进程选择已安装的 `/Applications/Xcode.app`，不会修改全局开发工具配置。如果命令行工具缺少可用的测试模块，需要安装 Xcode 并通过 `DEVELOPER_DIR` 指向它；应用构建本身不需要完整 Xcode。

UI 与系统集成的人工验证清单及本机构建结果见 [VALIDATION.md](VALIDATION.md)。Intel 构建成功不等同于 Intel 真机运行测试。

## 结构与边界

- `LinkPortCore`：可测试的队列、浏览器目录、偏好、状态控制及窗口定位计算。
- `LinkPort`：AppKit 系统适配、菜单栏、SwiftUI 设置及选择卡片，中英文本地化。
- `scripts` / `Configuration`：双架构构建、图标生成和应用元数据。

浏览器列表来自系统注册的 HTTP/HTTPS 处理应用，因此其他链接路由器也可能出现在列表中，可手动隐藏。LinkPort 自身始终排除。应用内嵌网页、明确指定其他浏览器的打开操作、自定义 URL 协议和本地 HTML 文件不在接管范围内。

首版不包含网站规则、Profile、浏览历史、远程分析、同步、浏览器扩展或自动更新。
