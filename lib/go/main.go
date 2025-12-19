package main

import (
	"fmt"

	"github.com/2018wzh/ecnu-eams-client/examples"
)

func main() {
	fmt.Println("运行基础使用示例...")
	examples.BasicUsageExample()

	fmt.Println("\n运行抢课示例...")
	examples.RobExample()
}
