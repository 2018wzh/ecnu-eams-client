package examples

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/2018wzh/ecnu-eams-client/pkg/api"
	"github.com/2018wzh/ecnu-eams-client/pkg/auth"
	"github.com/2018wzh/ecnu-eams-client/pkg/robber"
)

// RobExample 抢课示例
func RobExample() {
	// 1. 浏览器登录
	fmt.Println("正在启动浏览器登录...")
	browserAuth, err := auth.NewBrowserAuth(false)
	if err != nil {
		log.Fatalf("启动浏览器失败: %v", err)
	}
	defer browserAuth.Close()

	loginURL := "https://byyt.ecnu.edu.cn/"
	cookies, err := browserAuth.Login(loginURL, 5*time.Minute)
	if err != nil {
		log.Fatalf("登录失败: %v", err)
	}

	// 2. 创建API客户端
	client := api.NewClient()
	client.SetCookies(cookies)

	// 3. 获取学生ID和选课轮次
	studentIDs, err := client.GetStudentID()
	if err != nil {
		log.Fatalf("获取学生ID失败: %v", err)
	}
	studentID := studentIDs[0]

	turns, err := client.GetOpenTurns(studentID)
	if err != nil {
		log.Fatalf("获取选课轮次失败: %v", err)
	}
	if len(turns) == 0 {
		log.Fatal("未找到选课轮次")
	}
	turnID := turns[0].ID

	fmt.Printf("学生ID: %d, 选课轮次ID: %d\n", studentID, turnID)

	// 4. 创建抢课器
	robber := robber.NewRobber(client, studentID, turnID)
	robber.SetInterval(500 * time.Millisecond) // 设置抢课间隔为500ms
	robber.SetMaxRetries(3)

	// 5. 添加抢课目标（需要替换为实际的课程ID）
	// 示例：添加课程ID为123456的课程，意愿值为0，优先级为1
	lessonID := 123456 // 请替换为实际的课程ID
	robber.AddTarget(lessonID, 0, 1)

	fmt.Printf("已添加抢课目标: 课程ID %d\n", lessonID)
	fmt.Println("按 Ctrl+C 停止抢课")

	// 6. 启动抢课
	err = robber.Start()
	if err != nil {
		log.Fatalf("启动抢课失败: %v", err)
	}

	// 7. 等待中断信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	// 8. 停止抢课
	fmt.Println("\n正在停止抢课...")
	robber.Stop()
	fmt.Println("抢课已停止")
}
