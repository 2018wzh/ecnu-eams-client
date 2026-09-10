# CLI 查询、验证与抢课

GUI 和 CLI 共用纯 Dart 的 API 和抢课执行层。CLI 不需要启动 Flutter 窗口，但需要网络连接，运行期间电脑不能休眠。

## 用 CLI 验证 GUI 的业务流程

在 GUI 的“设置”中点击“复制 CLI 只读验证命令”。无需添加抢课目标；已选择轮次时只验证该轮次，否则验证账号的所有开放轮次。

```sh
eams --config "<Base64配置>" --action verify
eams --config "<Base64配置>" --action account
eams --config "<Base64配置>" --action courses --turn 123 --course "课程名" --page 1
eams --config "<Base64配置>" --action courses --turn 123 --available --with-seats
eams --config "<Base64配置>" --action selected --turn 123
eams --config "<Base64配置>" --action count --turn 123 --lesson 456
```

将示例 ID 替换为 `account` / `courses` 返回的 ID。已绑定轮次的配置不能通过 `--turn` 改为另一轮次。`courses`、`selected`、`count` 在存在多个轮次且配置未绑定时要求明确指定轮次。

这些操作输出 JSON，成功退出码为 0，失败为 1；不会提交选退课、获取写锁或读写自动任务日志，可以与 GUI 同时运行。只读配置最少为 `{"version":1,"token":"当前Token"}` 的标准 Base64；可附加 `studentId`、`turnId`、`semesterId`。完整抢课配置也可用于只读操作。凭据仍只从 `--config` 读取。

`verify` 通过 GUI 使用的共享服务依次检查登录身份、轮次与学期、普通课程分页和人数解析、筛选条件、已选课程、服务端可选/有余量筛选，以及一门课程的人数详情。默认从每个轮次的第一页（20 门）开始，再抽查课程名称搜索和另一页（有多页时），不遍历全部课程。它返回各步骤统计，遇到错误会标明失败阶段并返回非零退出码。它不能验证原生窗口布局、账号密码/扫码认证或通知弹窗；这些才需要界面检查。

`courses` 支持 `--teacher`、`--lesson-name`、`--campus`、`--course-type`、`--course-property`、`--department`、`--major`、`--grade`、`--week`、`--credit-min`、`--credit-max`、`--page` 和 `--page-size`（1–100）。课程人数与 GUI 使用同一套六字段解析，不把跨专业分类与总人数相加或相减。是否可选以学校筛选结果为准。

## GUI 生成配置

1. 登录，选择轮次，在搜索页将课程添加到抢课列表。
2. 在抢课页调整课程优先级、检查间隔和开始日期时间。
3. 点击“停止并导出 CLI 配置”。应用会先停止本地任务，等待已发出的选退课请求核对结果。
4. 复制 Base64 配置或完整启动命令。桌面和移动端使用相同的复制入口。

配置包含 `token`、学生、轮次、学期、时间参数、课程 ID 和意愿值，采用 UTF-8 JSON 的标准 Base64 编码。目标顺序即执行优先级。未知版本、重复课程、缺少身份或无时区的开始时间会直接报错。

## 运行

使用发布的 `eams` 可执行文件时：

将对应平台的下载文件重命名为 `eams`（Windows 为 `eams.exe`）。Linux/macOS 下载后需添加执行权限，例如 `chmod +x eams`；未放入 PATH 时用 `./eams` 运行。

```sh
eams --config "<Base64配置>" --check
eams --config "<Base64配置>"
```

`--check` 会读取官网数据验证身份、轮次、学期和课程，**不会提交选课**。运行命令会自动等待轮次开始和配置的定时时间（取较晚者），并在轮次截止时停止。

将示例中的 `<Base64配置>` 替换为 GUI 复制的字符串，或直接使用 GUI 的“复制检查命令”和“复制启动命令”。CLI 从配置的 `token` 字段读取登录凭据；不再读取配置文件、Token 环境变量或标准输入。Base64 是编码，不是加密；该配置具有登录凭据的敏感性。

从源码运行：

```sh
cd packages/eams_core
dart pub get
dart run bin/eams.dart --config "<Base64配置>" --check
dart run bin/eams.dart --config "<Base64配置>"
```

编译独立入口：

```sh
cd packages/eams_core
dart pub get
mkdir -p build
dart compile exe bin/eams.dart -o build/eams
```

Windows 可以将输出名设为 `build/eams.exe`，并使用 `eams.exe` 运行。每个平台需要分别编译；构建工作流提供对应操作系统和架构命名的 CLI 文件。

## 停止和恢复

- `Ctrl+C` 停止后续提交；已发送的请求仍进行有超时上限的结果核对。在支持的系统上也处理 SIGTERM。
- `--once` 只执行一轮检查，适合检查当前余量和执行状态；它**会**选课。
- 每次提交前保存状态到用户状态目录，文件名为 `<学生ID>-<轮次ID>-<学期ID>.state.json`。Windows 使用 `LOCALAPPDATA/ecnu-eams`，macOS 使用 `HOME/Library/Application Support/ecnu-eams`，Linux 使用 `XDG_STATE_HOME/ecnu-eams`（未设置时为 `HOME/.local/state/ecnu-eams`）。状态不含 Token，更新 Token 或从其他工作目录启动仍会读取同一轮次状态。保留该文件再重启，可以发现上次进程中断时的未确认提交。
- 重启时先读取已选课程，已经选中的目标不会重复提交。
- 如果上次提交结果不确定且仍无法确认，程序会停止。请先在官网核对；不要通过删除状态文件绕过检查。
- 仅在已人工确认所有不确定操作、且服务端不存在待处理请求后，使用 `--acknowledge-uncertain` 允许重新运行。GUI 中对应“我已在官网核对”。
- 业务校验拒绝会标记该目标失败，不会无限重试。修改目标或解决冲突后重新运行。网络错误和限流会有限退避，限流尊重 `Retry-After`；提交后的通信错误不会直接重发。

同一台电脑上的 GUI 与 CLI 自动选课通过学生运行锁互斥。只读查询不占用写锁。不同电脑之间不共享锁；同一账号应只在一个设备上运行自动选课。

## 退出码

| 退出码 | 含义 |
|---|---|
| 0 | 检查通过，或全部目标已确认选中 |
| 1 | 配置、登录、运行失败，或存在失败/未确认结果 |
| 3 | 单轮运行结束，仍有未选中的目标 |
| 130 | 用户中断 |

课程资格以官网实时筛选及选课验证为准。普通名额与跨专业名额不能直接相加推断当前学生一定可选。CLI 只处理普通教学班选课，不实现课程包、替代重修等尚未建模的专用提交路径。
