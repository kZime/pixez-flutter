# macOS 桌面预览

维护方向：优先复用 Windows 的 Fluent 页面与桌面逻辑，分别适配系统行为。当前通过编译开关验证，没有改变 Windows 或移动端的默认界面。

## 本地启动

在仓库根目录运行：

```sh
./tool/macos_preview.sh
```

默认启动 Fluent Debug 预览。脚本优先使用 `.fvm/flutter_sdk` 或本机按 `.fvmrc` 安装的 SDK；其他安装位置通过 `FLUTTER_BIN=/path/to/flutter/bin/flutter` 指定。脚本只使用本地 ad-hoc 签名，不代表可公开分发。

```sh
./tool/macos_preview.sh fluent release
./tool/macos_preview.sh material debug
./tool/macos_preview.sh legacy debug
```

首次准备依赖和生成代码的步骤见 [Stage A 记录](history/stage-a.md)。旧记录中的构建成功仅对应当时源码；当前验证结果以 [Fluent 验证记录](fluent-validation.md) 为准。

## 入口与功能边界

| 构建参数 | macOS | Windows |
|---|---|---|
| 无预览开关 | 旧 Material 入口 | 现有 Fluent |
| `MACOS_FLUENT_PREVIEW=true` | 共享 Fluent 预览 | 保持 Fluent |
| `DESKTOP_PREVIEW=true` | 保留的 Material 桌面原型 | Material 桌面原型 |

同时设置两个开关时，Material 桌面原型优先。不要将 UI 选择当成操作系统判断。

Fluent Mac 预览使用系统标题栏、外部浏览器登录及 URL 回调、原生另存为。推荐、搜索、详情和卡片使用现有 Fluent 页面。另存为使用与 Material 桌面原型相同的保存实现，不写 Photos 或移动下载队列；多页依次询问保存位置，取消会停止本批。暂不保证旧下载任务、保存命名模板、目录批量导出或 GIF 导出已经适配。

`⌘F` 展开侧栏并聚焦搜索，Enter 提交；View 菜单中的 Back（`⌘[`）返回上一页，编辑文本时不触发页面返回。

macOS 与已安装 iOS 版 PixEz 可能同时注册 `pixiv://`。授权后打开错误应用时，应先核实系统协议处理器；不要复制或记录授权 URL、code、token。应用进程重启后内存中的 PKCE verifier 会丢失，需要重新发起登录。

## 目录与后续维护

- `lib/fluent/`：Windows/macOS 共享界面；改动须做 Windows 回归。
- `lib/desktop/`：保留的 Material 原型及目前共享的文件保存实现。
- `macos/`：系统窗口、URL 回调、权限和构建工程。
- `test/`：桌面导航、键盘、文件保存与数据状态回归。
- [Material 原型说明](material-preview.md)：历史交互验证，不作为后续完整页面开发路线。
- [历史共享方案](history/sharing-plan.md)、[Stage A](history/stage-a.md)：保留原始研究与验收边界。

从上游 `master` 创建短期功能分支；平台修复、共享逻辑和界面变化分别评审。构建产物、日志、账号数据库和本机证据不提交。Debug 通过不等于 Release 或 Windows 已验证。
