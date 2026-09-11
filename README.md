# ECNU 选课客户端

Flutter GUI 与纯 Dart CLI 共用选课接口和抢课执行层。

- 课程、教学班、教师、院系、校区、学分、可选状态和余量筛选，支持分页与排序。
- 手动选课、退课，以及服务端验证、结果轮询和已选课程核对。
- 按优先级自动抢课，支持定时开始、停止、结果记录和按账号/轮次保存目标。
- 只提醒、不提交选课的课程余量监控。
- GUI 导出包含 Token 的 Base64 配置，直接复制命令交给 CLI 运行。
- 请求超时、限流退避、未确认提交保护，以及 GUI/CLI 本机运行互斥。

## 启动 GUI

开发和 CI 统一使用 Flutter 3.44.1，依赖版本由仓库中的 pubspec.lock 固定。

```sh
cd app
flutter pub get
flutter run
```

Windows 支持 WebView2 内置登录；移动端使用 WebView；其他桌面平台可以在浏览器登录后输入 Authorization Token。登录验证成功后才进入主界面。选择轮次后会加载课程和该轮次保存的目标。

Windows 登录保留浏览器原生重定向和表单提交。登录门户并进入“选课”服务后，手动点击窗口顶部“已登录，获取凭据并关闭”。客户端此时才读取选课 Token 和用于续期的门户会话 Cookie，成功后关闭窗口；读取失败会在顶部显示原因，可继续操作后重试。直接关闭窗口会取消登录。不再定时自动提取或自动结束登录。登录异常可通过应用日志查看页面域名、加载状态和错误类型，日志不记录登录凭据或认证票据。

“设置 → 复制 CLI 只读验证命令”可直接检查 GUI 共用的账号、轮次、课程分页、人数和已选课程逻辑，无需配置抢课目标。CLI 提供 `--action account/courses/selected/count/verify`，输出 JSON；这些操作不会选退课。详见 [CLI 用法](docs/cli.md)。

## GUI → CLI

在抢课列表设置目标和优先级，点击“停止并导出 CLI 配置”。客户端会先停止任务并验证登录，有门户会话时先完成续期，再提供最新的 Base64 配置或完整启动命令；验证失败则不导出。门户会话与选课 Token 有效期互相独立，刚复制配置不代表门户会话仍有效。

```sh
cd packages/eams_core
dart pub get
dart run bin/eams.dart --config "<Base64配置>" --check
dart run bin/eams.dart --config "<Base64配置>"
```

配置已包含当前登录 Token，无需额外输入。第一条命令只检查配置和官网状态，第二条运行抢课。按 Ctrl+C 停止。

Windows 网页登录后导出的完整抢课配置还包含 `portalSession`，用于 CLI 自动续期。GUI 和 CLI 的自动任务在启动时及每 5 分钟调用学校续期接口，验证新 Token 的学生身份后使用；等待定时开抢、轮询间隔和重试等待均覆盖。续期失败即停止任务，门户会话失效后需要重新网页登录并导出配置。手动输入 Token 的登录没有门户会话，只做定时身份和保活检查，不能延长 Token 的有效期。`--check` 和只读查询不调用续期接口。

完整说明、独立编译方式和恢复规则见 [CLI 文档](docs/cli.md)。

## 运行边界

- GUI 必须保持运行；没有手机后台常驻或电脑防休眠机制。长时间运行可以交给 CLI，运行设备仍需保持唤醒。
- 停止无法撤销已发送的请求；程序会继续核对，不能确认时暂停并要求人工查看官网。
- 任务按学生、轮次、学期隔离；切换轮次或退出前先停止任务。旧版未绑定身份的任务缓存不再加载。
- 系统通知支持 Android、iOS、macOS、Linux，需要相应权限和系统通知服务；Windows/Web 请在界面查看状态。
- Web 版能否访问官网接口取决于学校的跨域策略；CLI 和原生客户端不受浏览器跨域限制。
- 培养方案、课表选课、课程包和替代重修尚未提供完整客户端流程，可使用官网。

## 项目结构与检查

- `app/`：Flutter 界面、平台登录、配置保存和通知。
- `packages/eams_core/`：共享 API、任务配置、执行器和 CLI。
- [选课 API 说明](docs/选课.md)：已有接口说明，实际规则以官网为准。

```sh
cd packages/eams_core
dart analyze
dart test
cd ../../app
flutter analyze
flutter test
```

## 构建

```sh
cd app
flutter build windows --release
# 在相应平台可使用 flutter build apk / linux / macos / web
```

推送与源码版本一致的 `vX.Y.Z` tag 后，GitHub Actions 自动检查、构建并发布 Android 签名 APK/AAB、Windows 便携 ZIP、Linux bundle 压缩包、macOS app 压缩包、Web 压缩包及各桌面平台 CLI，同时提供 SHA256SUMS。带 `-alpha.N`、`-beta.N`、`-rc.N` 的版本自动标为 Pre-release。手动触发只构建，不发布。

发布步骤和签名配置见 [发布文档](docs/releasing.md)，平台运行要求见 [下载说明](docs/release-notes.md)。Windows 包未做 Authenticode 签名，macOS 包尚未签名公证；iOS 不在自动发布范围内。

GUI 使用系统安全存储保存登录凭据；旧版明文 Token 会被清除，需要重新登录。Web 使用浏览器加密存储，需要 HTTPS。更多数据处理说明见 [隐私说明](docs/privacy.md)。

## 许可证

GPL-3.0。请遵守学校的选课和接口使用规定。
