package examples

import (
	"fmt"
	"log"
	"time"

	"github.com/ecnu-eams-client/course-selection/pkg/api"
	"github.com/ecnu-eams-client/course-selection/pkg/auth"
)

// BasicUsageExample 基础使用示例
func BasicUsageExample() {
	// 1. 浏览器登录获取Cookies
	fmt.Println("正在启动浏览器登录...")
	browserAuth, err := auth.NewBrowserAuth(false) // false表示显示浏览器窗口
	if err != nil {
		log.Fatalf("启动浏览器失败: %v", err)
	}
	defer browserAuth.Close()

	loginURL := "https://byyt.ecnu.edu.cn/"
	cookies, err := browserAuth.Login(loginURL, 5*time.Minute)
	if err != nil {
		log.Fatalf("登录失败: %v", err)
	}
	fmt.Println("登录成功！")

	// 2. 创建API客户端
	client := api.NewClient()
	client.SetCookies(cookies)

	// 3. 获取学生ID
	fmt.Println("正在获取学生信息...")
	studentIDs, err := client.GetStudentID()
	if err != nil {
		log.Fatalf("获取学生ID失败: %v", err)
	}
	if len(studentIDs) == 0 {
		log.Fatal("未找到学生ID")
	}
	studentID := studentIDs[0]
	fmt.Printf("学生ID: %d\n", studentID)

	// 4. 获取选课轮次
	fmt.Println("正在获取选课轮次...")
	turns, err := client.GetOpenTurns(studentID)
	if err != nil {
		log.Fatalf("获取选课轮次失败: %v", err)
	}
	if len(turns) == 0 {
		log.Fatal("未找到选课轮次")
	}
	fmt.Printf("找到 %d 个选课轮次:\n", len(turns))
	for _, turn := range turns {
		fmt.Printf("  - %s (ID: %d)\n", turn.Name, turn.ID)
	}

	// 5. 获取选课详情
	turnID := turns[0].ID
	fmt.Printf("\n正在获取选课详情 (轮次ID: %d)...\n", turnID)
	selectDetail, err := client.GetSelectDetail(studentID, turnID)
	if err != nil {
		log.Fatalf("获取选课详情失败: %v", err)
	}
	fmt.Printf("学期: %s\n", selectDetail.Semester.NameZh)

	// 6. 搜索课程
	fmt.Println("\n正在搜索课程...")
	queryReq := &api.LessonQueryRequest{
		TurnID:           turnID,
		StudentID:        studentID,
		SemesterID:       selectDetail.Semester.ID,
		PageNo:           1,
		PageSize:         10,
		CourseNameOrCode: "",
		CanSelect:        true,
		CanSelectText:    "可选",
		SortField:        "lesson",
		SortType:         "ASC",
	}

	result, err := client.QueryLessons(studentID, turnID, queryReq)
	if err != nil {
		log.Fatalf("搜索课程失败: %v", err)
	}
	fmt.Printf("找到 %d 门课程 (共 %d 门)\n", len(result.Lessons), result.PageInfo.TotalRows)

	// 显示前几门课程
	for i, lesson := range result.Lessons {
		if i >= 5 {
			break
		}
		fmt.Printf("\n课程 %d:\n", i+1)
		fmt.Printf("  名称: %s\n", lesson.NameZh)
		fmt.Printf("  代码: %s\n", lesson.Code)
		if lesson.Course.NameZh != "" {
			fmt.Printf("  课程: %s\n", lesson.Course.NameZh)
		}
		fmt.Printf("  学分: %.1f\n", lesson.Course.Credits)
		if len(lesson.Teachers) > 0 {
			fmt.Printf("  教师: %s\n", lesson.Teachers[0].NameZh)
		}
		fmt.Printf("  名额: %d/%d\n", lesson.LimitCount, lesson.LimitCount)
	}

	// 7. 获取已选课程
	fmt.Println("\n正在获取已选课程...")
	selectedLessons, err := client.GetSelectedLessons(turnID, studentID)
	if err != nil {
		log.Fatalf("获取已选课程失败: %v", err)
	}
	fmt.Printf("已选 %d 门课程\n", len(selectedLessons))
	for _, lesson := range selectedLessons {
		fmt.Printf("  - %s (%s)\n", lesson.NameZh, lesson.Code)
	}

	fmt.Println("\n示例完成！")
}
