# macOS 阶段 A 技术验证

开始日期：2026-09-11。基线：0750c38b0c8aaf200e992ec9b4303f5cd6abba87。

## 执行范围

- [x] 固定并验证本地 Flutter/Dart、Xcode、CocoaPods、Rust 工具链。
- [x] 解析锁定依赖并生成必要代码。
- [x] 构建 arm64 Debug 和 Release；只做必要的构建/启动修复。
- [x] 启动应用，验证初始化、数据库和无账号页面。
- [x] 验证真实登录与列表取图（账号授权由用户操作）。
- [x] 执行一张图片保存验证并记录结果：下载成功，Photos 写入未通过。
- [x] 汇总产物、复现命令、发现及剩余项。

证据目录：`/Users/kzime/Projects/pixez-stage-a-evidence`。日志不应记录账号令牌、授权码或密码。

## 环境基线

主机 arm64，macOS 27.0 (26A428)，Xcode 27.0 (27A5228h)。开始时可用空间约 18 GiB。

## 工具链

- Flutter 3.47.3，revision e8113bf45620cbeb8aff64947ee4c93e16adb4cf。
- Dart 3.13.3，CocoaPods 1.17.0，Rust/Cargo 1.93.1。
- Flutter 安装路径：`/Users/kzime/.local/share/flutter/3.47.3`；`.fvmrc` 已固定版本。
- Homebrew 安装 CocoaPods 时同时安装 Ruby 4.0.6_1，并更新依赖 OpenSSL/ca-certificates。未修改 shell 配置。
- `flutter doctor -v` 的 Xcode、macOS device 和网络资源检查通过。Android 工具缺失不属于本次范围。Flutter 从 tag 检出导致 user-branch 提示，不影响固定版本构建。

## 已验证结果

1. `flutter pub get --enforce-lockfile` 通过，应用 pubspec.lock 未更新；rhttp 子项目依赖解析通过。
2. 应用 build_runner 生成 155 个输出，rhttp 生成 3 个输出。存在 analyzer 语言版本落后 SDK 的警告，但生成成功。
3. Debug 构建成功：`build/macos/Build/Products/Debug/pixez_flutter.app`。`file` 确认主程序 arm64，`codesign --verify --deep --strict` 通过。签名为本地 ad-hoc，非对外发布签名。
4. 首启完成中文/网络向导，菜单和偏好设置可打开。
5. 默认增强连接（ECH）下预览为空；通过应用设置将身份验证/API 切为标准连接并重启后，首页真实预览图片正常显示。单独的匿名 walkthrough HTTP 探测也返回 200。没有修改全局网络/代理设置，没有将此对照结果归因为 macOS 独有缺陷。
6. 应用创建 account、task1、banillustid、bantag、banuserid 五个数据库，SQLite 只读 quick_check 均为 ok。未读取或导出令牌字段。
7. 点击登录触发浏览器跳转；电脑操作工具拒绝访问登录浏览器 URL，因此该部分由用户手动完成，未读取浏览器授权码或 Token。
8. Release 构建成功：`build/macos/Build/Products/Release/pixez_flutter.app`，Flutter 报告 46.6 MB。主程序为 arm64，`codesign --verify --deep --strict` 通过。
9. 用户第一次报告登录完成后，本地 Debug 仍在登录页，账号表 count 为 0。核实两窗口分别是本次 Debug（`com.perol.dev.pixez`）和已安装的 PixEz（`com.perol.pixez`，iOS Wrapper）。后者显示已登录的推荐列表，不能计为本次构建的登录验收。
10. LaunchServices 查询确认 `pixiv://` 默认处理器为 `/Applications/PixEz.app`。用系统 NSWorkspace API 临时指定 Debug 产物后重新授权，本地账号表 count 从 0 变为 1，quick_check 为 ok，证实本次构建成功写入登录状态。未复制旧版账号或令牌。
11. 退出 Debug，启动 Release（进程 49465）。无需再次登录，真实推荐列表、作品详情和大图均正常加载。此次验证证明登录状态跨进程/构建配置保持，但不代表过期令牌自动刷新已经实测。
12. 在 Release 大图页对作品 62341877 点击保存。下载任务 status=2；缓存中出现 `62341877_p0.jpg`，1,861,719 字节，SHA-256 记录在证据 JSON 中。Photos 的 `pxez` 相册仍显示 2 Photos、November 2023–June 2025，无本次新增，故不能将下载完成计为相册写入成功。未观察到照片授权弹窗，也未收集到能明确归因的 Photos 错误；Release 缺少照片库 sandbox entitlement 是待验证因素。
13. 已执行还原脚本并查询确认 `pixiv://` 再次解析到 `/Applications/PixEz.app`。本次测试账号仍保存在本地构建自己的沙盒内。

登录链路补充检查：macOS 的 EventChannel 已接通。`Leader.pushWithUri` 在写库成功后只对 iOS 跳转首页，故 macOS 停在登录页本身不能证明失败，需结合账号记录及真实请求验收。原生层没有缓存订阅前收到的 URL，`getInitialLink` 固定返回 nil；这是冷启动时的潜在丢回调风险，当前同进程重试尚未证明触发此问题。两项暂未改动。

回调处理器的还原脚本位于证据目录 `restore-url-handler.swift`，已运行；结果见 `url-handler-restore.log`。

## 实际阻塞与处理

| 项目 | 实测结果 | 处理 |
|---|---|---|
| 缺少工作区 | 首次构建立即报 No macOS desktop project configured | 新增标准 Runner.xcworkspace；CocoaPods 随后加入 Pods 引用 |
| 老 macOS 工程 | Flutter 自动迁移最低版本至 12.0 并集成 Swift Package Manager | 保留工具生成的迁移，最低 12.0 尚未在旧系统实测 |
| Debug 签名 | Runner requires a provisioning profile | 移除 Debug 独有且未用到的 applesignin entitlement；使用命令环境指定 ad-hoc 签名 |
| Release Rust | 两次完整构建均出现 proc-macro E0463/E0432；单独 dlopen 证实 mis-aligned LINKEDIT string pool | 清理缓存不能解决；第三次设置 CARGO_PROFILE_RELEASE_STRIP=none 后完整构建成功 |
| 授权日志 | 源码会打印 verifier/code/token/回调 URL | 移除敏感打印，关闭 Dio 请求/响应内容日志；保留业务流程 |
| 多版本回调冲突 | 已安装版与本地构建都注册 pixiv scheme，系统默认打开已安装版 | 测试期间临时指定 Debug 接收回调，登录通过后已恢复 |
| macOS 登录后不跳转 | 账号已经写库，窗口仍在登录页 | 重启 Release 后正确进入已登录首页；路由缺陷已定位，暂未修改 |
| 图片保存完成状态失真 | 下载缓存成功，任务 status=2，但 Photos 未出现新图 | 原生异步结果未回传，Dart 也没有等待真实写入；保存验收失败，待修复 |

## 构建命令

```sh
export PATH=/Users/kzime/.local/share/flutter/3.47.3/bin:$PATH
export FLUTTER_XCODE_CODE_SIGN_IDENTITY=-
export FLUTTER_XCODE_DEVELOPMENT_TEAM=''
export FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
export FLUTTER_MACOS_ARM64_ONLY=true
# 本机 macOS 27 + Rust 1.93.1 的 LINKEDIT 对齐问题临时规避。
export CARGO_PROFILE_RELEASE_STRIP=none

cd /Users/kzime/Projects/pixez-flutter
flutter pub get --enforce-lockfile
cd plugins/rhttp/rhttp
flutter pub get
dart run build_runner build
cd ../../..
dart run build_runner build
flutter build macos --debug --no-pub
flutter build macos --release --no-pub
```

以上 Debug/Release 命令均已成功运行。应用当前配置的 bundle id 为 `com.perol.dev.pixez`。本轮改动在本地 `macos-stage-a` 分支，未提交或推送。

### Release 错误定位补充

仅在新的临时 Cargo target 目录编译可以通过，但在 Xcode 对应目录清理后仍复现，因此不能将原因确定为缓存损坏。主代理对失败 dylib 执行动态加载，得到 `mis-aligned LINKEDIT string pool, fileOffset=0x00257DCC`，而文件架构、签名以及 proc-macro/metadata 符号本身正常。这与 [Rust issue #157750](https://github.com/rust-lang/rust/issues/157750) 描述的 macOS 27 对裁剪后 Mach-O 文件对齐要求一致。当前仅通过构建环境覆盖裁剪设置，保留仓库 Rust release 配置和现有工具链。

## 验收结论及剩余项

本轮阶段 A 技术验证已执行完毕：本机两个配置可构建、Debug 可登录、Release 可启动并保持登录、推荐/详情/大图可加载。Photos 单图写入未通过，因此阶段 A 的全部功能验收尚未通过。

后续最小修复范围：macOS 登录成功后跳转首页；修复 Photos 授权/写入链路，将异步完成和错误传回 Dart，并让任务完成状态反映真实保存结果。冷启动回调缓存为另外的待验证项。仅验证本机 Apple Silicon/macOS 27；不代表 Intel 或 macOS 12 等旧系统兼容性通过，也未实测过期令牌自动刷新。

## 验证证据

- `build-debug-03.log`、`build-release-03.log`：成功构建日志。
- `debug-entitlements.plist`、`release-entitlements.plist`：实际产物权限。
- `debug-signature.txt`、`release-signature.txt`：签名元数据读取记录；两个产物的严格签名校验均返回成功。
- `database-check.json`：五个数据库的只读完整性检查。
- `release-proc-macro-dlopen.json`：Rust proc-macro 动态加载错误定位。
- `toolchain.json`：固定版本和本机构建环境覆盖值。
- `account-after-callback-retry.json`：本次构建账号数为 1，未导出账号内容。
- `runtime-release-01.log`：Release 启动运行日志。
- `single-image-save-check.json`：下载任务、缓存文件摘要及 Photos 实际检查结果。
- `url-handler-change.log`、`url-handler-restore.log`：临时回调切换与还原。

本轮以真实构建、启动和数据库检查验证改动，未新增与实现重复的单元测试；`git diff --check` 通过。
