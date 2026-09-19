# Fluent macOS 预览验证

日期：2026-09-19。工作分支：`macos-fluent-preview`。已 fast-forward 到上游 `7f89bc86f1b01e00ae65973cbc12b6c536037604`，保留之前的 macOS 平台修复与 Material 原型。

## 本轮已观察到的结果

| 项目 | 实测结果 |
|---|---|
| Debug 构建 | 成功，arm64，本地严格签名校验通过 |
| Release 构建 | 首次、图片进度修复后和最终菜单修复后均成功；最终 48.4 MB、arm64，严格签名校验通过 |
| Release 运行 | 最终 Release 冷启动回调进入目标详情，真实图片加载；`⌘[` 返回、`⌘F` 搜索及 Enter 提交复验通过；只保留一个 Release 窗口 |
| 账号恢复 | 使用本地构建已有账号，Debug/Release 重启后保持登录；未复制账号数据库或令牌 |
| 浏览 | 推荐、搜索 `landscape`、作品详情、大图可用 |
| 桌面快捷键 | 最终 Debug 中 `⌘F` 展开并聚焦窄窗搜索，Enter 提交；原生 View → Back / `⌘[` 返回已实测 |
| 保存 | 右键保存打开系统对话框，完成后显示已保存；实写 JPEG 512×384，57,203 字节 |
| 取消保存 | 系统面板取消后返回详情，无保存成功提示 |
| URL 回调 | 指定测试应用接收运行中和冷启动 `pixiv://illusts/...`，均进入目标 Fluent 详情 |
| 协议处理器 | 本轮未修改默认关联，查询仍为 `/Applications/PixEz.app` |

测试图片为作品 149831745，文件名 `fluent-save-149831745_p0.jpg`，SHA-256 为 `e562c1d471a6f4cf5b8e898fdfd97129632c68a3a3aeb9525c9caf02de1926f4`。测试图片与运行日志保存在仓库外的本机证据目录，没有加入版本控制。

## 构建复现

使用 `.fvmrc` 固定的 Flutter 3.47.3。SDK 工作树未修改。准备依赖后：

```sh
export FLUTTER_XCODE_CODE_SIGN_IDENTITY=-
export FLUTTER_XCODE_DEVELOPMENT_TEAM=''
export FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
export FLUTTER_MACOS_ARM64_ONLY=true
export CARGO_PROFILE_RELEASE_STRIP=none
flutter build macos --debug --no-pub --dart-define=MACOS_FLUENT_PREVIEW=true
flutter build macos --release --no-pub --dart-define=MACOS_FLUENT_PREVIEW=true
```

此处 Rust strip 环境覆盖沿用本机原有 LINKEDIT 问题的规避方式；没有修改仓库的 Rust release 配置。签名是本地 ad-hoc，不是 Developer ID 签名或公证。

历史 Material 桌面预览曾触发 [Flutter #191575](https://github.com/flutter/flutter/issues/191575) 相同症状的 AOT 崩溃。本轮 Fluent Release 成功仅证明此次源码与工具链组合可构建，不能证明该 SDK 问题已彻底修复，也不能据此推断 Material 原型的 Release 同样通过。

## 边界与待验收事项

- 尚未重新走完整的外部浏览器授权；已有账号恢复和作品 URL 回调不等于新账号登录验收。
- Windows 构建/运行与 iOS、Android 回归未执行；默认平台入口未主动切换。
- `flutter test --no-pub --dart-define=MACOS_FLUENT_PREVIEW=true` 的 24 项测试通过，覆盖保存完成/取消/批量顺序、分页竞态、Material 回退、Fluent 导航重建、窄窗收起后的搜索唤起、菜单返回与文本编辑保护，以及未知图片长度。
- 本轮 35 个新增或修改的 Dart 文件定向静态分析通过；最后修改的导航与测试文件再次分析通过。不是整个上游仓库零告警的声明。
- 初次运行观察到图片总长度为负数导致的 Debug 断言和窄窗搜索唤起缺失，已在项目中修复；没有修改 pubcache 或 Flutter SDK。Flutter accessibility tree 更新错误仍需后续调查，自动化过程中结合截图验证，没有只依赖 AX 树。
- 初次窄窗运行出现过 `RenderFlex` 水平溢出；最终 Debug 的宽窄窗搜索、推荐和详情检查未复现图片长度断言、布局溢出或未处理异常，但尚未完成所有页面、窗口尺寸和缩放比例的视觉回归。
- 旧下载任务、Photos、保存命名模板、目录批量导出、GIF 导出和公开分发尚未完成适配验收。

## 仓库整理

- 改动前的二进制 patch、未跟踪源码副本和分支/HEAD 清单保存于仓库外 `pixez-stage-a-evidence/fluent-backup-20260919-163736`。
- 历史研究与构建记录收纳至 `docs/macos/history/`，Material 原型说明保留为 `docs/macos/material-preview.md`。
- 添加 `tool/macos_preview.sh` 作为本地 Fluent/Material/旧入口启动命令。
- 清理未使用的原生 Photos 示例函数、空 custom-tab channel 与无断言的计数器占位测试。
- 本地提交按 macOS 工程与回调、共享图片缓存、桌面预览、文档与启动工具分组。桌面提交同时归档此前未提交的 Material 原型，不宜不拆分就作为单个上游 PR。
- 没有删除 Material 原型、修改默认协议关联、推送远端、创建 PR 或发布应用。
