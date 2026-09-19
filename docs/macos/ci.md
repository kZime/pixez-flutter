# 桌面 CI 验证

macOS 与 Windows 继续共享 `lib/fluent/`。此阶段验证干净的 GitHub runner 能还原依赖、执行测试和生成 Release；macOS 仍使用 `MACOS_FLUENT_PREVIEW=true`，默认入口不变。

## 工作流

| 工作流 | 环境 | 测试与产物 |
|---|---|---|
| [Build macOS Fluent Preview](../../.github/workflows/build_macos.yml) | `macos-26`，ARM64 | Fluent 预览测试、Release 构建、打包前后严格签名校验、app ZIP 与 SHA-256 |
| [Build Windows](../../.github/workflows/build_windows.yml) | `windows-2022`，x64 | 默认入口测试、现有 Fluent Release 构建与二进制产物 |

两端均读取 `.fvmrc` 固定的 Flutter 版本。根项目和 macOS 工作流中的 rhttp 依赖使用锁文件还原，再从源码生成 MobX/Freezed 等文件。Windows 保留原有版本号与可选签名打包流程；fork 没有证书时跳过 MSIX 签名。

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

上游 `7f89bc8` 的 Windows run [34675225044](https://github.com/Notsfsssf/pixez-flutter/actions/runs/34675225044) 已成功生成二进制，但失败于 MSIX 签名（SignTool 未找到匹配证书）；这与 macOS 适配的编译结果应分别判断。
