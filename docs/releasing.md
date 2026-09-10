# 维护者发布说明

## 版本与触发

`app/pubspec.yaml` 的 `version: X.Y.Z+BUILD` 是 GUI 版本和 Android build number 的来源；`packages/eams_core/pubspec.yaml` 的版本必须为相同的 `X.Y.Z`。每次发布递增 BUILD。CI 编译 CLI 时会注入该版本；未经版本注入的本地 CLI 显示 `development`。

推送 `vX.Y.Z` tag 自动运行完整检查、构建和发布。允许 `vX.Y.Z-alpha.N`、`vX.Y.Z-beta.N`、`vX.Y.Z-rc.N`；对应 pubspec 使用相同预发布后缀。CI 会将这些 tag 发布为 GitHub Pre-release，正式版本发布为普通 Release。tag 与源码版本不一致会立即失败。

```sh
# 完成版本更新、提交和检查后再打 tag；以下版本仅为示例。
git tag -a v1.0.0-beta.1 -m "Release 1.0.0-beta.1"
git push origin v1.0.0-beta.1
```

Pull Request 自动执行版本规则、脚本测试、Dart/Flutter 静态检查和测试。手动运行 Build and Release 会编译全部平台并保存 Actions artifacts，但不会创建 Release。可先在候选分支手动运行，确认通过后再打 tag。

## 构建和发布规则

- 所有任务固定 Flutter 3.44.1，使用仓库中的两个 pubspec.lock，并通过 `--enforce-lockfile` 校验依赖。
- Android 构建三种 ABI 的签名 APK 和 AAB；Windows 发布完整便携 ZIP；Linux 发布 bundle tar.gz；macOS 发布保留应用包结构的 ZIP；Web 发布静态 ZIP；三种桌面平台分别编译 CLI。
- 文件名含版本、平台和适用架构。所有构建成功后检查 11 个产物，生成 SHA256SUMS，上传到草稿 Release；上传全部完成后才公开。
- 构建、签名、文件缺失或上传失败不会继续公开 Release。上传中断留下的草稿可在修复后重跑发布任务。
- Actions artifacts 保留 7 天；正式下载以 Release 附件为准。
- Windows 便携包没有 Authenticode 签名；macOS 包尚未 Developer ID 签名、公证。不要将这些构建描述为商店安装包或已公证版本。iOS 不属于自动发布范围。

## Android 签名

仓库 Actions Secrets 必须配置：

| Secret | 内容 |
|---|---|
| ANDROID_KEYSTORE_BASE64 | 固定 JKS 发布密钥库的标准 Base64 |
| ANDROID_KEY_ALIAS | 密钥别名 |
| ANDROID_STORE_PASSWORD | 密钥库密码 |
| ANDROID_KEY_PASSWORD | 私钥密码 |

CI 只在临时目录还原密钥，任务结束后删除；APK/AAB 始终使用 release 签名，不使用 debug 密钥。后续更新必须沿用同一签名密钥，妥善保存独立备份，不要在每次 CI 中生成新密钥。

本地 release 构建使用同名密码/别名环境变量和 `ANDROID_KEYSTORE_PATH`，后者指向密钥库。不将私钥或密码提交进 Git，不在命令行参数中传递密码。

签名方案参考 [Flutter Android 发布说明](https://docs.flutter.dev/deployment/android)。Release 上传使用 [action-gh-release](https://github.com/softprops/action-gh-release)。
