# ECNU选课系统客户端

基于Go和Flutter开发的ECNU选课系统客户端，支持浏览课程、选课、退课和抢课功能。

## 功能特性

- ✅ 浏览器登录获取Cookie
- ✅ 浏览和搜索课程
- ✅ 选课和退课
- ✅ 抢课功能（自动轮询选课）
- ✅ 友好的用户界面
- ✅ 跨平台支持（Windows、macOS、Linux、Android、iOS）

## 项目结构

```
.
├── pkg/                    # Go库
│   ├── api/               # API客户端
│   │   ├── client.go      # HTTP客户端
│   │   ├── models.go      # 数据模型
│   │   └── course_selection.go  # 选课API方法
│   ├── auth/              # 认证模块
│   │   └── browser.go     # 浏览器登录
│   └── robber/            # 抢课模块
│       └── robber.go      # 抢课器
├── app/           # Flutter应用
│   ├── lib/
│   │   ├── main.dart      # 入口文件
│   │   ├── providers/     # 状态管理
│   │   ├── screens/       # 界面
│   │   ├── services/      # API服务
│   │   └── widgets/       # 组件
│   └── pubspec.yaml       # 依赖配置
└── docs/                  # 文档
    └── 选课.md            # API文档
```

## 快速开始

### 前置要求

- Go 1.21+
- Flutter 3.0+
- Chrome/Chromium（用于浏览器登录）

### 安装Go依赖

```bash
go mod tidy
```

### 运行Flutter应用

```bash
cd app
flutter pub get
flutter run
```

## 使用说明

### 1. 登录

1. 打开应用后，会自动打开登录页面
2. 在WebView中完成ECNU统一认证登录
3. 登录成功后，Cookies会自动保存

### 2. 选择选课轮次

1. 在"选课轮次"标签页中选择当前要使用的选课轮次
2. 系统会自动加载该轮次的相关信息

### 3. 搜索课程

1. 切换到"搜索课程"标签页
2. 输入课程名称或代码进行搜索
3. 可以使用筛选条件（校区、课程类型等）
4. 点击课程卡片查看详情并选课

### 4. 查看已选课程

1. 切换到"已选课程"标签页
2. 查看当前已选的所有课程
3. 可以在此退选课程

### 5. 抢课功能

1. 在搜索课程时，可以将课程添加到抢课列表
2. 切换到"抢课"标签页
3. 开启抢课开关
4. 系统会自动轮询检查课程名额并尝试选课

## Go库使用示例

```go
package main

import (
    "fmt"
    "github.com/ecnu-eams-client/course-selection/pkg/api"
    "github.com/ecnu-eams-client/course-selection/pkg/auth"
)

func main() {
    // 浏览器登录获取Cookies
    browserAuth, err := auth.NewBrowserAuth(false) // false表示显示浏览器窗口
    if err != nil {
        panic(err)
    }
    defer browserAuth.Close()

    cookies, err := browserAuth.Login("https://byyt.ecnu.edu.cn/cas", 5*time.Minute)
    if err != nil {
        panic(err)
    }

    // 创建API客户端
    client := api.NewClient()
    client.SetCookies(cookies)

    // 获取学生ID
    studentIDs, err := client.GetStudentID()
    if err != nil {
        panic(err)
    }
    studentID := studentIDs[0]

    // 获取选课轮次
    turns, err := client.GetOpenTurns(studentID)
    if err != nil {
        panic(err)
    }

    // 选课
    err = client.AddCourse(studentID, turns[0].ID, lessonID, 0)
    if err != nil {
        fmt.Printf("选课失败: %v\n", err)
    } else {
        fmt.Println("选课成功！")
    }
}
```

## 抢课功能

```go
// 创建抢课器
robber := robber.NewRobber(client, studentID, turnID)

// 添加抢课目标
robber.AddTarget(lessonID, 0, 1) // lessonID, virtualCost, priority

// 设置抢课间隔
robber.SetInterval(100 * time.Millisecond)

// 开始抢课
err := robber.Start()
if err != nil {
    panic(err)
}

// 停止抢课
robber.Stop()
```

## 注意事项

1. **Cookie安全**: Cookies会保存在本地，请妥善保管
2. **选课规则**: 请遵守学校的选课规则，不要滥用抢课功能
3. **网络**: 确保网络连接稳定
4. **浏览器**: 首次使用需要安装Chrome或Chromium

## 开发

### Go库开发

```bash
# 运行测试
go test ./...

# 构建
go build ./...
```

### Flutter开发

```bash
cd app

# 获取依赖
flutter pub get

# 运行
flutter run

# 构建
flutter build
```

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

## 免责声明

本工具仅供学习和研究使用，使用者需自行承担使用风险。请遵守学校相关规定，不得用于任何违法违规用途。
