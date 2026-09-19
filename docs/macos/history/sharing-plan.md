# Windows / macOS 共用桌面端：实现与维护方案

日期：2026-09-12。状态：研究草案；需求类型：现有工程改造。来源：用户希望明确 iPhone、iPad、Windows、macOS 的代码共享边界、具体实现步骤和长期分支维护方式。

## 1. 结论与证据边界

建议从上游 master 继续开发，在同一仓库内让 Windows / macOS 共用现有 Fluent 页面、导航和交互。iPhone / iPad 继续使用现有 Material 界面。网络、模型、账户、分页等业务实现继续共用，系统能力由各平台原生工程实现。

本轮检查了平台入口、页面 imports、状态类、原生插件、上游远端分支及 CI；只拉取远端引用并新增本研究文档，没有切换或合并工作分支，没有改动实现代码。Fluent 在 macOS 上的运行表现仍未实测；之前 Stage A 运行的是 Material 界面。

本地工作分支 macos-stage-a，代码基线 0750c38b0c8aaf200e992ec9b4303f5cd6abba87，已有未提交的 Stage A 改动。最新远端 master 为 7f89bc86f1b01e00ae65973cbc12b6c536037604；本地与该提交的已提交内容差异涉及 6 个文件，本轮没有合并这些变化。

## 2. 是否从 Windows 分支派生

不建议。git ls-remote 和定向 fetch 后检查到的远端分支头如下：

| 分支 | 提交 | 提交日期（+08:00） | 判断 |
|---|---|---|---|
| master | 7f89bc8 | 2026-09-12 | 当前主线，已经含 Fluent UI、Windows Runner 和 Windows CI |
| windows | c7ea8af | 2022-04-14 | 历史 Windows 预览支持分支，不能凭名称认为是当前桌面开发基线 |
| windows_dev | e178800 | 2023-05-11 | 历史开发分支头，同样不宜作为新适配基线 |

当前是浅克隆。以上为分支头/源码快照比较，没有据此宣称完整祖先关系或所有历史改动已合并。推荐 master 的依据是当前共享代码和构建流程都已在主线上，而旧分支快照显著陈旧。

上游参考：[主仓库](https://github.com/Notsfsssf/pixez-flutter)、[Windows 历史提交](https://github.com/Notsfsssf/pixez-flutter/commit/c7ea8afd47ff9f029f440497b9a4750f3f762768)、[windows_dev 历史提交](https://github.com/Notsfsssf/pixez-flutter/commit/e178800664497cfb5fc912412f6fc2c132ae1b06)。

## 3. 现有共享边界

“共享”指编译时引用同一份源码，不代表不同应用/设备共用账户数据库或自动同步用户数据。

| 代码范围 | 目前如何使用 | 目标维护边界 |
|---|---|---|
| lib/network/ | API、OAuth、刷新令牌、网络配置由多端调用 | 四种目标设备继续共用；网络模式与平台接入另作配置 |
| lib/models/ | 插画、用户、账户、任务等模型及部分 SQLite Provider | 继续共用模型/业务读写；数据库驱动与存储目录保持平台初始化 |
| lib/store/ | 账户、偏好、屏蔽、收藏标签、下载等状态 | 继续共享；不是全部纯业务，下载提示/路由需局部拆出 |
| lib/lighting/lighting_store.dart | Material 与 Fluent 列表共同使用的数据源与分页状态 | 继续共用分页、刷新和数据状态 |
| lib/page/** 下的 *_store.dart | 目录名像移动页面，但多个类实际被 Fluent 引用 | 保持共用；不要整目录复制或移动 |
| lib/page/、lib/component/ 的界面 | iPhone/iPad 与当前 Mac Material 入口使用；个别界面也被 Fluent 复用 | iPhone/iPad 保留；Mac 切 Fluent 后仍须检查这些跨界面引用 |
| lib/fluent/ | 当前仅 Windows 默认启用，含独立页面、组件、导航 | 逐步成为 Windows/Mac 共用桌面表现层 |
| lib/*_plugin.dart | Dart 侧系统能力接口，多平台调用 | 共享接口，不保证各端方法都已实现 |
| ios/、windows/、macos/ | 各自 Runner、系统 API、权限、签名与打包 | 分平台维护；iPhone/iPad 共用 ios 工程 |
| plugins/rhttp/rhttp/ | Dart/Rust 网络实现及不同平台构建接入 | 共用网络实现，分别验证原生构建 |
| 国际化资源、图片资源 | 两套页面共同使用 | 继续共享 |

具体引用例子：

- [Fluent 搜索列表](/Users/kzime/Projects/pixez-flutter/lib/fluent/page/search/result_illust_list.dart:26) 使用 [ResultIllustStore](/Users/kzime/Projects/pixez-flutter/lib/page/search/result_illust_store.dart)。
- [Fluent 图片卡片](/Users/kzime/Projects/pixez-flutter/lib/fluent/component/illust_card.dart:36) 使用 [IllustStore](/Users/kzime/Projects/pixez-flutter/lib/page/picture/illust_store.dart)。
- [Fluent 用户页](/Users/kzime/Projects/pixez-flutter/lib/fluent/page/user/users_page.dart:45) 使用 [UserStore](/Users/kzime/Projects/pixez-flutter/lib/page/user/user_store.dart)。
- [Fluent 动图加载器](/Users/kzime/Projects/pixez-flutter/lib/fluent/page/picture/ugoira_loader.dart:24) 使用 [UgoiraStore](/Users/kzime/Projects/pixez-flutter/lib/page/picture/ugoira_store.dart)。播放与导出能力不能混为一谈。

## 4. Windows / Mac 具体共用哪些交互

iPhone / iPad 使用同一 lib/main.dart 和 ios Runner；[Xcode 工程](/Users/kzime/Projects/pixez-flutter/ios/Runner.xcodeproj/project.pbxproj:545) 的 TARGETED_DEVICE_FAMILY 为 1,2，[Info.plist](/Users/kzime/Projects/pixez-flutter/ios/Runner/Info.plist:102) 单独配置了 iPad 支持的方向。没有单独的 iPad Dart 入口。现有 Material 首页按窗口宽高比切 NavigationRail；这属于同一界面的布局适配，不能把 iPad 当作另一个需要同步代码的项目。

原生实现需要特别区分：iOS 和 macOS 虽然都使用 Swift，仍是不同文件、不同 Runner 和权限环境。ios/Runner/DocumentPlugin.swift 与 macos/Runner/DocumentPlugin.swift 不会因语言相同而自动同步。Windows 保存位于 windows/runner/plugins/document_plugin.cpp；三端共用 Dart DocumentPlugin 接口，但其方法实现和完成语义需要逐一对齐。图片剪贴板的 lib/clipboard_plugin.dart 目前只把 Windows 标为 supported，Mac 不能直接照搬该入口。

| 系统能力 | iPhone / iPad | Windows | macOS |
|---|---|---|---|
| 图片保存 | 同一 iOS DocumentPlugin，Photos；异步真实结果没有完整回传 | DocumentPlugin 使用系统文件夹/文件保存 API | 独立 Swift Photos 实现；Stage A 下载成功、相册保存未通过 |
| 文件夹接口 | 原生 DocumentPlugin 缺 get_path/choice_folder 等方法，不能等同整个应用没有文件选择能力 | 已有 get_path/choice_folder/openSave/exist | 对应自定义方法尚未实现 |
| 登录界面/回调 | 内嵌 WebView；iOS DeepLinkPlugin 另处理系统链接 | 外部授权/启动参数与单实例管道 | 外部浏览器、AppDelegate URL 事件；当前仅注册 pixiv scheme |
| 文本/图片剪贴板 | 普通文本用 Flutter Clipboard；自定义图片通道未实现 | 普通文本共用，图片另有 clipboard_plugin.cpp | 普通文本共用，自定义图片通道未实现 |
| 动图播放 | 共用 Dart ZIP 解包、帧信息和绘制逻辑 | 使用共用数据/播放实现与桌面表现 | 可复用相同逻辑，但 Fluent Mac 仍待运行验证 |
| GIF 导出 | 有 ImageIO 编码入口，但返回值与 Dart 当前期待的路径契约不一致，不能当成可靠共用基础 | 没有 Dart 当前调用的编码通道，saveFromPath 也缺失 | 同样缺编码通道与 saveFromPath |

参考：[iOS 插件注册](/Users/kzime/Projects/pixez-flutter/ios/Runner/AppDelegate.swift:12)、[Windows 保存方法](/Users/kzime/Projects/pixez-flutter/windows/runner/plugins/document_plugin.cpp:29)、[Mac 保存方法](/Users/kzime/Projects/pixez-flutter/macos/Runner/DocumentPlugin.swift:14)、[Dart GIF 导出合约](/Users/kzime/Projects/pixez-flutter/lib/page/picture/ugoira_store.dart:101)。这些为源码结论，除 Stage A 已标明的 Mac 实测外，不代表本轮完成了各端功能运行测试。

| 桌面模块 | 现有承载文件/目录 | 两端共用内容 | 平台差异 |
|---|---|---|---|
| 应用主题/启动界面 | lib/fluent/fluentui.dart、page/splash/ | FluentApp、主题、加载页面 | 原生窗口初始化、背景特效 |
| 首页导航 | lib/fluent/page/hello/fluent_hello_page.dart | 侧栏、搜索入口、推荐/排行/收藏/关注入口 | 窗口栏、菜单栏 |
| 返回与页面路由 | lib/fluent/navigation_framework.dart、lib/er/fluent_leader.dart | 页面栈、当前导航项、返回命令、鼠标侧键 | Win Alt+Left，Mac 对应 Command 键映射 |
| 列表与图片详情 | lib/fluent/component/、page/picture/ | 卡片、右键操作、详情页面、滚动浏览 | 图片复制、打开系统应用等落地能力 |
| 搜索 | lib/fluent/component/search_box/、page/search/ | 搜索建议、提交搜索、筛选与结果 | 系统级快捷键绑定 |
| 看图 | lib/fluent/page/zoom/、page/picture/ugoira_loader.dart | 大图浏览、缩放入口、动图表现 | 手势/滚轮手感需分别实测，导出用原生接口 |
| 下载任务 | lib/fluent/page/task/ + 共用 SaveStore/Fetcher | 列表、进度、重试、真实结果显示 | 文件夹选择/授权、Finder/资源管理器定位 |
| 设置 | lib/fluent/page/hello/setting/ | 通用配置、主题、下载命名等 | 平台设置页与不支持能力的入口 |

Windows 现有页面是可复用的起点，不代表它已满足全部桌面交互目标。例如列表/详情分栏和完整前进历史应作为后续共享功能评估，不能记为现有能力。

## 5. 必须先处理的代码问题

1. **UI 模式和操作系统混用。** [Constants.isFluent](/Users/kzime/Projects/pixez-flutter/lib/constants.dart:27) 目前等于 Platform.isWindows。引入 Mac 预览时，仅改变 UI 选择，不能把所有 Windows 分支机械扩大为桌面判断。例如 [main.dart](/Users/kzime/Projects/pixez-flutter/lib/main.dart:69) 的 sqflite FFI/单实例初始化就不应直接套给 Mac。
2. **Windows 窗口假设。** [fluentui.dart](/Users/kzime/Projects/pixez-flutter/lib/fluent/fluentui.dart:22) 的初始化隐藏原生窗口控件；[navigation_framework.dart](/Users/kzime/Projects/pixez-flutter/lib/fluent/navigation_framework.dart:100) 自绘标题栏与 WindowCaption。Mac 要保留原生交通灯并提供适当拖动区域；Windows 背景特效只在 Windows 启用。
3. **Fluent 缺少 Mac 回调订阅。** 现有 [Material HelloPage](/Users/kzime/Projects/pixez-flutter/lib/page/hello/hello_page.dart:110) 订阅 DeepLinkPlugin；FluentHelloPage 没有对应订阅。Windows 主要经 [SingleInstancePlugin](/Users/kzime/Projects/pixez-flutter/lib/single_instance_plugin.dart:27) 接收启动参数。切 UI 后必须保留 Mac 的原生事件入口，否则已有登录可用却无法重新登录。
4. **重复的登录业务。** Leader 与 FluentLeader 各自实现 code 兑换、账户组装、写库和跳转；Material Mac 不跳首页、Fluent 路径仍打印授权码，是两条路径分别修改导致的不一致。抽出一个共用的登录完成函数，界面只决定导航和提示，所有入口避免完整授权参数日志。
5. **平台设置非 Windows 直接抛错。** [PlatformPage](/Users/kzime/Projects/pixez-flutter/lib/fluent/page/platform/platform_page.dart:14) 抛 UnimplementedError。应让通用设置复用，系统差异局部呈现。
6. **共享下载层携带移动 UI。** [save_store.dart](/Users/kzime/Projects/pixez-flutter/lib/store/save_store.dart:126) 内部创建 Material 弹层、MaterialPageRoute 和移动 JobPage。业务层发出下载事件即可，桌面/移动界面各自订阅展示，避免桌面任务入口又跳回手机页面。
7. **下载结束不等于保存结束。** [fetcher.dart](/Users/kzime/Projects/pixez-flutter/lib/er/fetcher.dart:223) 在真实落盘前写 status=2；Mac 原生 Photos 异步结果也未回传。共用接口需清楚区分成功、取消、失败，成功提示与任务状态必须等待最终保存结果。

原生热启动、冷启动回调要统一交给应用生命周期入口，并保证同一回调只消费一次；不能同时从初始链接和事件流重复兑换一次性授权码。冷启动缺少 PKCE verifier 时应明确重新登录，不能把旧验证码当作可重复使用数据。

## 6. 实施步骤与文件范围

### 第一步：保留可回退的 Fluent 预览

先将当前 Stage A 改动按构建接入/授权日志分成可审阅提交，再在主线基础的短期功能分支开展工作。此处是后续流程建议，本轮没有提交或建新分支。

在 constants.dart 和 main.dart 的 UI 选择处提供 Mac 预览开关（建议编译时开关，先不增加产品设置页面）。Windows 仍按原默认路径，Mac 可选择 Material 或 Fluent。沿用 Mac 已有数据库位置和 bundle ID，避免把账户迁到另一套沙盒。

调整 fluentui.dart / navigation_framework.dart 的窗口处理；保留现有目录名 lib/fluent，不复制成 lib/macos，也不先批量改名为 lib/desktop。验收推荐、搜索、详情、返回、设置均可打开。

### 第二步：补齐共用桌面入口

在应用级接入 Mac DeepLinkPlugin；把 Windows 参数回调与 Mac URL 事件归一到现有路由入口。对 Leader/FluentLeader 中重复的账户兑换和持久化做小范围提取，保持导航区别。补正确的快捷键映射与键盘焦点行为，输入框编辑时不误触发全局命令。

不要创建覆盖全部系统能力的复杂平台框架；先把窗口初始化、快捷键和保存等已有差异各自集中在少数位置。

### 第三步：可靠的桌面文件保存

建议 Windows / Mac 都提供“选择文件夹 → 保存原图/套图 → 显示实际结果 → 在系统文件管理器定位”。是否将文件夹设为 Mac 默认目标仍是产品选择，Photos 可以保留为可选目标。

优先扩展现有 DocumentPlugin 合约，并补 macos/Runner/DocumentPlugin.swift 的对应实现。用户所选目录的 sandbox 授权需要能跨重启恢复；取消、重名、失效授权、写入失败不能显示成功。Dart 调用处等待原生完成；下载任务将网络下载完成与最终保存完成分开。

将 SaveStore 中弹层和页面跳转移到各 UI 的监听处，共享下载状态和重试逻辑。套图、GIF/ZIP 与单图分别验收；先明确支持清单，避免所有格式都流入 Photos 图片 API。

### 第四步：两端共同改进交互

在 lib/fluent 内改列表/详情布局、右键菜单、图片浏览和任务页，两端自动编译同一份改动。Mac 只在窗口、菜单、快捷键映射、原生文件能力处保留差异。不为 Mac 再维护另一份 SearchPage、IllustStore 或 DownloadStore。

只有出现真实的重复代码或边界阻塞时才局部提取共用模块。早期不全仓迁移 store，不更换状态管理方案，不把一次桌面适配扩展为业务层重写。

## 7. 长期分支与上游同步

建议在自己的 fork 内维护一个共同桌面集成分支；分支名 desktop 仅为建议，尚未创建。master 可以保持上游镜像；功能分支短期存在，用于 UI、保存、登录等独立改动。Windows 和 Mac 不各自维持永久分叉的业务主线。

目标关系：上游 master → fork 中共同桌面集成分支 → 短期 feature/fix 分支 → 合回集成分支 → 同一提交分别产出 Windows / macOS 应用。

当前 origin 指向原作者仓库，不是用户 fork。将来创建 fork 后才配置 origin 指向自己的仓库、upstream 指向原作者；本轮未修改 remote，也未创建线上 fork。

常规同步步骤：

1. 在已保存、干净的工作树上 fetch 上游 master，查看锁文件、Flutter/Rust、共享网络/账户、Fluent UI 和原生工程的变化。
2. 建临时同步分支，将上游 master 合并到共同桌面集成分支的当前状态。长期共享分支优先 merge，避免反复重写协作者历史；尚未共享的短期功能分支可按需要 rebase。
3. 处理冲突时重新检查意图，不能简单整段选 ours/theirs。由 Flutter/CocoaPods 生成的内容按锁定工具链重新生成并核对。
4. 跑变化对应的多端检查和 Windows/macOS 构建，经过必要的真实交互验证后再合回集成分支。
5. 使用同一 Git 提交标记可用版本；记录对应 Flutter、Rust、Xcode/SDK 和应用产物。

初期可按每周或准备发版时同步；涉及登录/API失效的上游修复及时处理。这个频率是建议，没有设置自动任务。

优先把小而通用的修复提交给上游：Mac 构建接入、平台设置防崩、回调/授权日志、下载真实结果、可复用桌面交互应分别审阅。是否被上游接收不能预设；接收后后续同步可逐步消除自己的补丁差异。

## 8. 改一次代码，哪些平台要验证

| 改动 | 自动检查建议 | 必须关注的实际体验 |
|---|---|---|
| API/账户/模型/分页 | 共享单元测试；Win/Mac 构建；iOS 编译，必要时 Android 编译 | 登录/刷新、搜索、分页、收藏数据一致性 |
| Fluent 页面/导航 | 组件/路由测试；Win/Mac 构建 | 两端返回、侧栏选择、滚动位置、键盘焦点；iOS 入口仍走 Material |
| SaveStore/DocumentPlugin 合约 | 成功/取消/失败/重名的契约测试；调用平台编译 | Win/Mac 实际文件、iOS Photos；以落盘为准 |
| macos 原生代码/entitlements | Mac Debug+Release 构建、签名/权限检查 | 真实授权、文件访问、回调、重启；共享接口改动仍需回归其他端 |
| ios 原生/布局 | iOS 编译，iPhone 与 iPad 尺寸覆盖 | 触控、横竖屏、分屏与权限 |
| Flutter/Rust/pubspec/锁文件 | 多端依赖解析、代码生成与编译 | 冷启动、网络、图片与原生插件关键调用 |

仓库目前有 .github/workflows/build_windows.yml 和 build_ios.yml；本地 test/widget_test.dart 只有空的 smoke test 体，不能视为已有有效回归覆盖。新增测试应验证真实行为，例如取消保存不会完成任务、回调只兑换一次、修改快捷键不会吞掉输入框操作，不写仅复述实现的测试。

Windows 构建/交互需要 Windows runner 或真机。只在 Mac 编译成功，不能宣称两端兼容已验收。Mac Release 和 Debug 都要验证；iPhone/iPad 共用 iOS 编译，但仍需覆盖两种设备布局。

## 9. 数据、接口与范围

无需为了桌面适配新建业务后端，继续使用现有 Pixiv API 和模型。本轮没有迁移账号数据库或改令牌存储，也没有扩大 Photos 权限。新增持久化预期主要是 Mac 保存目录授权、窗口偏好；具体格式在实现时以最少改动确定。

维护成本主要来自三个点：上游依赖/登录变化、共享代码尚夹杂 UI、两端原生保存与窗口行为。复用 Fluent 可以减少重复页面维护，但不能消除系统测试成本。当前不提供未经测量的复用百分比或固定工期承诺。

## 10. 交付验收和待决定事项

实现验收：

- Windows 和 Mac 使用同一份 Fluent 导航、推荐、搜索、详情、任务界面；iPhone/iPad 不被误切到 Fluent。
- Mac 保留合适的原生窗口控制，关键操作有按钮/菜单及正确的键盘映射。
- Mac 从已登录状态启动可用，同时全新登录、失败/取消、热回调、冷启动也有明确结果。
- 下载完成必须对应实际目标文件成功，拒绝/取消/权限失效不显示成功；重启后目录授权可用。
- 同一提交通过 Windows/macOS 构建；共享业务变化覆盖 iOS 编译与 iPhone/iPad 布局检查。
- 旧 Material 预览可回退；Windows 原有设置和保存行为无回归。

产品待决定：是否接受首版 Fluent 风格；Mac 是否默认文件夹保存；首版只面向 Apple Silicon 自用还是公开分发。当前建议按 Fluent 预览、Apple Silicon、自用验证推进，文件夹默认值在实施前明确。

开发待验证：Fluent 在 Mac 的首轮运行；Windows 真机/runner 可用性；目录授权和回调契约；共享依赖升级是否影响 Windows/iOS。上述未验证事项不阻塞本研究结论，但不能据此宣称已实现。

变更记录：v1.0，2026-09-12，基于源码依赖、Stage A 实测和远端分支快照形成方案。
