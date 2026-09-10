## 2.0.1 更新

- 修复 Windows 内置网页登录的重定向和表单提交，支持读取学校认证 Cookie，并显示登录提取错误。
- 修复课程人数六字段解析和已选人数显示，课程名称、教学班和教师搜索按学校课程索引筛选。
- GUI 与 CLI 共用账号、轮次、课程分页和人数解析逻辑，新增只读 `account`、`courses`、`selected`、`count`、`verify` 操作。
- 设置页可复制 CLI 只读验证命令，无需配置抢课目标；完整自动选课配置仍支持定时启动。
- Windows 便携包附带所需 MSVC 运行库。

## 下载与运行

- Android：通常选择 `android-arm64-v8a.apk`；其他 ABI 按设备选择。AAB 用于应用分发平台，不能直接安装。APK 使用项目固定发布密钥签名。
- Windows：解压 `windows-x64.zip`，保留整个目录再运行程序。包内附带 MSVC 运行库；内置网页登录需要 WebView2 Runtime。
- Linux：解压 `linux-*.tar.gz` 后运行 bundle 中的程序。需要 GTK 3、WebKitGTK 4.1、libsecret、libjsoncpp 及桌面 keyring 服务。
- macOS：解压 `macos-*.zip` 后打开应用。本项目尚未提供 Apple Developer ID 签名和公证，系统可能阻止直接打开。
- CLI：下载与系统、CPU 架构匹配的 `cli-*` 压缩包。使用 GUI 复制的 `eams --config "<Base64配置>"` 命令运行。
- Web：`web.zip` 是静态站点文件，需由 HTTPS 服务托管。学校接口跨域策略仍可能限制访问。

`SHA256SUMS` 包含全部下载文件的 SHA-256。源代码位于本 Release 对应 tag，采用 GPL-3.0；客户端不是学校官方产品。

Base64 配置包含登录 Token，编码不等于加密。不要公开配置或将其附在问题报告中。当前版本会要求使用旧版明文登录存储的用户重新登录。

自动化运行期间请保持设备唤醒和网络连接。首次使用可先运行 `--check` 做只读检查；未确认提交请先在官网核对。
