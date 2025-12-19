# ECNU选课系统 Go库

Go语言实现的ECNU选课系统API客户端库。

## 安装

```bash
go get github.com/ecnu-eams-client/course-selection/pkg/api
go get github.com/ecnu-eams-client/course-selection/pkg/auth
go get github.com/ecnu-eams-client/course-selection/pkg/robber
```

## 使用

### 基本使用

```go
import (
    "github.com/ecnu-eams-client/course-selection/pkg/api"
    "github.com/ecnu-eams-client/course-selection/pkg/auth"
)
```

### API客户端

```go
client := api.NewClient()
client.SetCookies(cookies)

// 获取学生ID
studentIDs, err := client.GetStudentID()

// 获取选课轮次
turns, err := client.GetOpenTurns(studentID)

// 搜索课程
result, err := client.QueryLessons(studentID, turnID, &api.LessonQueryRequest{
    PageNo: 1,
    PageSize: 20,
})

// 选课
err := client.AddCourse(studentID, turnID, lessonID, 0)

// 退课
err := client.DropCourse(studentID, turnID, lessonID)
```

### 浏览器登录

```go
browserAuth, err := auth.NewBrowserAuth(false)
defer browserAuth.Close()

cookies, err := browserAuth.Login(
    "https://byyt.ecnu.edu.cn/",
    5*time.Minute,
)
```

### 抢课功能

```go
robber := robber.NewRobber(client, studentID, turnID)
robber.AddTarget(lessonID, 0, 1)
robber.SetInterval(100 * time.Millisecond)
robber.Start()
```

## API文档

详见 [docs/选课.md](../docs/选课.md)

