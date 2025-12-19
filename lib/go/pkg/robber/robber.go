package robber

import (
	"fmt"
	"sync"
	"time"

	"github.com/2018wzh/ecnu-eams-client/pkg/api"
)

// Robber 抢课器
type Robber struct {
	client     *api.Client
	studentID  int
	turnID     int
	targets    []Target
	interval   time.Duration
	maxRetries int
	mu         sync.Mutex
	running    bool
	stopCh     chan struct{}
}

// Target 抢课目标
type Target struct {
	LessonID    int
	VirtualCost int
	Priority    int // 优先级，数字越大优先级越高
}

// NewRobber 创建抢课器
func NewRobber(client *api.Client, studentID, turnID int) *Robber {
	return &Robber{
		client:     client,
		studentID:  studentID,
		turnID:     turnID,
		targets:    make([]Target, 0),
		interval:   100 * time.Millisecond, // 默认100ms间隔
		maxRetries: 3,
		stopCh:     make(chan struct{}),
	}
}

// SetInterval 设置抢课间隔
func (r *Robber) SetInterval(interval time.Duration) {
	r.interval = interval
}

// SetMaxRetries 设置最大重试次数
func (r *Robber) SetMaxRetries(maxRetries int) {
	r.maxRetries = maxRetries
}

// AddTarget 添加抢课目标
func (r *Robber) AddTarget(lessonID, virtualCost, priority int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.targets = append(r.targets, Target{
		LessonID:    lessonID,
		VirtualCost: virtualCost,
		Priority:    priority,
	})
}

// RemoveTarget 移除抢课目标
func (r *Robber) RemoveTarget(lessonID int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	for i, target := range r.targets {
		if target.LessonID == lessonID {
			r.targets = append(r.targets[:i], r.targets[i+1:]...)
			break
		}
	}
}

// ClearTargets 清空所有目标
func (r *Robber) ClearTargets() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.targets = make([]Target, 0)
}

// GetTargets 获取所有目标
func (r *Robber) GetTargets() []Target {
	r.mu.Lock()
	defer r.mu.Unlock()

	result := make([]Target, len(r.targets))
	copy(result, r.targets)
	return result
}

// Start 开始抢课
func (r *Robber) Start() error {
	r.mu.Lock()
	if r.running {
		r.mu.Unlock()
		return fmt.Errorf("抢课器已在运行")
	}
	r.running = true
	r.stopCh = make(chan struct{})
	r.mu.Unlock()

	go r.run()

	return nil
}

// Stop 停止抢课
func (r *Robber) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if !r.running {
		return
	}

	r.running = false
	close(r.stopCh)
}

// IsRunning 检查是否正在运行
func (r *Robber) IsRunning() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.running
}

// run 抢课主循环
func (r *Robber) run() {
	ticker := time.NewTicker(r.interval)
	defer ticker.Stop()

	for {
		select {
		case <-r.stopCh:
			return
		case <-ticker.C:
			r.tryRob()
		}
	}
}

// tryRob 尝试抢课
func (r *Robber) tryRob() {
	targets := r.GetTargets()
	if len(targets) == 0 {
		return
	}

	// 按优先级排序
	for i := 0; i < len(targets)-1; i++ {
		for j := i + 1; j < len(targets); j++ {
			if targets[i].Priority < targets[j].Priority {
				targets[i], targets[j] = targets[j], targets[i]
			}
		}
	}

	// 检查课程名额
	for _, target := range targets {
		countInfo, err := r.client.GetCountInfo(target.LessonID)
		if err != nil {
			continue
		}

		// 检查是否还有名额
		available := countInfo.LimitCount - countInfo.StdCount
		if available > 0 {
			// 尝试选课
			err := r.client.AddCourse(r.studentID, r.turnID, target.LessonID, target.VirtualCost)
			if err == nil {
				// 选课成功，移除目标
				r.RemoveTarget(target.LessonID)
				continue
			}
		}
	}
}

// RobCourse 单次抢课尝试
func (r *Robber) RobCourse(lessonID, virtualCost int) error {
	return r.client.AddCourse(r.studentID, r.turnID, lessonID, virtualCost)
}
