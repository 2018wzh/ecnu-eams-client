package main

import (
	"fmt"

	"github.com/ecnu-eams-client/course-selection/examples"
)

func main() {
	fmt.Println("运行基础使用示例...")
	examples.BasicUsageExample()

	fmt.Println("\n运行抢课示例...")
	examples.RobExample()
}
