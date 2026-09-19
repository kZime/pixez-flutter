# 桌面 CI 验证

macOS 与 Windows 继续共享 `lib/fluent/`。此阶段验证干净的 GitHub runner 能还原依赖、执行测试和生成 Release；macOS 仍使用 `MACOS_FLUENT_PREVIEW=true`，默认入口不变。

## 工作流

| 工作流 | 环境 | 测试与产物 |
|---|---|---|
| [Build macOS Fluent Preview](../../.github/workflows/build_macos.yml) | `macos-26`，ARM64 | Fluent 预览测试、Release 构建、打包前后严格签名校验、app ZIP 与 SHA-256 |
| [Build Windows](../../.github/workflows/build_windows.yml) | `windows-2022`，x64 | 默认入口测试、现有 Fluent Release 构建与二进制产物 |

两端均读取 `.fvmrc` 固定的 Flutter 版本。根项目使用锁文件还原，再从源码生成 MobX/Freezed 等文件。rhttp 子库未提交自身锁文件，沿用上游方式解析其代码生成依赖；这部分开发依赖仍存在版本漂移的边界。Windows 保留原有版本号与可选签名打包流程；fork 没有证书时跳过 MSIX 签名。

macOS 工作流可由 `macos-fluent-preview` 分支 push、pull request 或手动触发。Windows 沿用现有触发规则。普通分支构建只上传 Actions artifacts，不发布 GitHub Release。macOS artifact 保留 7 天，过期后需重跑。

## 本地检查

```sh
flutter test --no-pub --dart-define=MACOS_FLUENT_PREVIEW=true
flutter test --no-pub
actionlint .github/workflows/build_macos.yml .github/workflows/build_windows.yml
```

第一条应在 macOS 上运行。macOS 原生菜单用例在其他平台或未开启预览时明确标为 skipped；共享测试仍执行。文件保存测试使用各系统的临时路径，不依赖 `/tmp` 或固定盘符。

## 下载与验收

在对应 Actions run 的 Artifacts 区域下载产物。macOS artifact 内含 `pixez-macos-fluent-preview-arm64.zip` 及同名 `.sha256`；解开 artifact 外层 ZIP 后：

```sh
shasum -a 256 -c pixez-macos-fluent-preview-arm64.zip.sha256
ditto -x -k pixez-macos-fluent-preview-arm64.zip preview
codesign --verify --deep --strict preview/pixez_flutter.app
```

macOS 包使用 ad-hoc 签名，未做 Developer ID 签名或公证；CI 通过不代表可以公开分发，也不代表新账号 OAuth、Windows 真机交互、所有窗口尺寸或移动端已完成验收。CI 不需要 Pixiv 账号、Token 或本地数据库。

完整浏览器登录与 Windows 真机测试的当前状态见 [桌面交互验收](interactive-validation.md)。

上游 `7f89bc8` 的 Windows run [34675225044](https://github.com/Notsfsssf/pixez-flutter/actions/runs/34675225044) 已成功生成二进制，但失败于 MSIX 签名（SignTool 未找到匹配证书）；这与 macOS 适配的编译结果应分别判断。

## Fork 开发约定

本轮 fork 为 [kZime/pixez-flutter](https://github.com/kZime/pixez-flutter)，验证分支为 `macos-fluent-preview`。本地 `origin` 仍指向上游，`fork` 指向个人仓库，当前分支跟踪 `fork/macos-fluent-preview`。fork 的 `master` 保留为上游基线；预览阶段不修改上游、不创建发布 tag。

后续同步上游时先检查工作区，再从 `origin/master` 更新短期分支。平台工程、共享逻辑、CI 与完整预览页面应分别评审，不直接把包含 Material 历史原型的整条实验分支提交为一个上游 PR。

## 2026-09-19 验证记录

验证源码提交：`623ba552ad69b7afa8ec59ff0193a4f88e56ec5e`，Flutter 3.47.3 / Dart 3.13.3。

- [macOS run 35434819052](https://github.com/kZime/pixez-flutter/actions/runs/35434819052)：24 项测试通过，Release 48.8 MB，构建与打包前后签名校验全部通过。[下载 ARM64 artifact](https://github.com/kZime/pixez-flutter/actions/runs/35434819052/artifacts/10582023669)。
- [Windows run 35434819042](https://github.com/kZime/pixez-flutter/actions/runs/35434819042)：23 项测试通过、1 项 macOS 专用测试跳过；Release 构建和上传成功，MSIX 签名及发布按预期跳过。[下载 x64 artifact](https://github.com/kZime/pixez-flutter/actions/runs/35434819042/artifacts/10582093828)，下载后确认含 `pixez.exe`（PE32+ x86-64）、rhttp DLL 和 Flutter 资源；没有在 Windows 真机上执行交互验收。
- 下载 CI 产物到本机后再次验证 SHA-256 和严格签名，启动的进程路径确认为下载目录中的应用。已有账号恢复、`⌘F` 搜索、Enter 提交、详情图片、`⌘[` 返回和原生另存为均通过。
- 保存作品 149831745 得到 JPEG 512×384，文件 SHA-256 为 `e562c1d471a6f4cf5b8e898fdfd97129632c68a3a3aeb9525c9caf02de1926f4`，与此前本机构建保存结果一致。没有上传账号数据库、Token 或测试图片。

macOS app ZIP 的 SHA-256：

```text
097860a05a034c8aed1730e13565fe66a3552aa29ee3a64453ad93c9dae67bba
```

首次 macOS run 因 rhttp 子库没有提交锁文件而失败。修复 CI 的依赖还原方式后，以上 run 在干净 runner 上成功；没有通过复制本机生成文件绕过验证，也没有修改 Flutter SDK。
