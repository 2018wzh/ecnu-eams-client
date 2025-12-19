package api

import "../../../../pkg/api/fmt"

// GetStudentID 获取学生ID
func (c *Client) GetStudentID() ([]int, error) {
	var result []int
	err := c.Get("/student/course-select/students", &result)
	return result, err
}

// GetOpenTurns 获取选课轮次列表
func (c *Client) GetOpenTurns(studentID int) ([]Turn, error) {
	var result []Turn
	endpoint := fmt.Sprintf("/student/course-select/open-turns/%d", studentID)
	err := c.Get(endpoint, &result)
	return result, err
}

// GetSelectDetail 获取选课详情
func (c *Client) GetSelectDetail(studentID, turnID int) (*SelectDetail, error) {
	var result SelectDetail
	endpoint := fmt.Sprintf("/student/course-select/%d/turn/%d/select", studentID, turnID)
	err := c.Get(endpoint, &result)
	return &result, err
}

// GetSelectedLessons 获取已选课程
func (c *Client) GetSelectedLessons(turnID, studentID int) ([]Lesson, error) {
	var result []Lesson
	endpoint := fmt.Sprintf("/student/course-select/selected-lessons/%d/%d", turnID, studentID)
	err := c.Get(endpoint, &result)
	return result, err
}

// GetQueryCondition 获取筛选条件
func (c *Client) GetQueryCondition(turnID int) (*QueryCondition, error) {
	var result QueryCondition
	endpoint := fmt.Sprintf("/student/course-select/query-condition/%d", turnID)
	err := c.Get(endpoint, &result)
	return &result, err
}

// QueryLessons 筛选课程
func (c *Client) QueryLessons(studentID, turnID int, req *LessonQueryRequest) (*LessonQueryResponse, error) {
	if req == nil {
		req = &LessonQueryRequest{
			TurnID:        turnID,
			StudentID:     studentID,
			PageNo:        1,
			PageSize:      20,
			CanSelect:     true,
			CanSelectText: "可选",
			SortField:     "lesson",
			SortType:      "ASC",
		}
	}

	var result LessonQueryResponse
	endpoint := fmt.Sprintf("/student/course-select/query-lesson/%d/%d", studentID, turnID)
	err := c.Post(endpoint, req, &result)
	return &result, err
}

// GetRepairedCourses 获取重修课程
func (c *Client) GetRepairedCourses(turnID, studentID int) ([]RepairedCourse, error) {
	var result []RepairedCourse
	endpoint := fmt.Sprintf("/student/course-select/repaired-courses/%d/%d", turnID, studentID)
	err := c.Get(endpoint, &result)
	return result, err
}

// GetCountInfo 获取课程名额信息
func (c *Client) GetCountInfo(lessonID int) (*CountInfo, error) {
	var result CountInfo
	params := map[string]string{
		"lessonId": fmt.Sprintf("%d", lessonID),
	}
	err := c.GetWithQuery("/student/course-select/count-info", params, &result)
	return &result, err
}

// GetCountInfoBatch 批量获取课程名额信息
func (c *Client) GetCountInfoBatch(lessonIDs []int) (map[string]string, error) {
	var result map[string]string
	idsStr := ""
	for i, id := range lessonIDs {
		if i > 0 {
			idsStr += ","
		}
		idsStr += fmt.Sprintf("%d", id)
	}
	params := map[string]string{
		"lessonIds": idsStr,
	}
	err := c.GetWithQuery("/student/course-select/std-count", params, &result)
	return result, err
}

// AddCoursePredicate 发起选课验证请求
func (c *Client) AddCoursePredicate(req *AddPredicate) (string, error) {
	var result string
	err := c.Post("/student/course-select/add-predicate", req, &result)
	return result, err
}

// AddCourseRequest 发起选课请求
func (c *Client) AddCourseRequest(req *AddRequest) (string, error) {
	var result string
	err := c.Post("/student/course-select/add-request", req, &result)
	return result, err
}

// DropCoursePredicate 发起退课验证请求
func (c *Client) DropCoursePredicate(req *DropPredicate) (string, error) {
	var result string
	err := c.Post("/student/course-select/drop-predicate", req, &result)
	return result, err
}

// DropCourseRequest 发起退课请求
func (c *Client) DropCourseRequest(req *DropRequest) (string, error) {
	var result string
	err := c.Post("/student/course-select/drop-request", req, &result)
	return result, err
}

// GetPredicateResponse 查询验证结果
func (c *Client) GetPredicateResponse(studentID int, requestID string) (*AddDropResponse, error) {
	var result AddDropResponse
	endpoint := fmt.Sprintf("/student/course-select/predicate-response/%d/%s", studentID, requestID)
	err := c.Get(endpoint, &result)
	return &result, err
}

// GetAddDropResponse 查询选退课结果
func (c *Client) GetAddDropResponse(studentID int, requestID string) (*AddDropResponse, error) {
	var result AddDropResponse
	endpoint := fmt.Sprintf("/student/course-select/add-drop-response/%d/%s", studentID, requestID)
	err := c.Get(endpoint, &result)
	return &result, err
}

// AddCourse 选课（包含验证和提交）
func (c *Client) AddCourse(studentID, turnID, lessonID int, virtualCost int) error {
	reqp := &AddPredicate{
		StudentAssoc:          studentID,
		CourseSelectTurnAssoc: turnID,
		RequestMiddleDtos: []RequestMiddleDto{
			{
				LessonAssoc: lessonID,
				VirtualCost: virtualCost,
			},
		},
		CoursePackAssoc: nil,
	}

	// 先验证
	requestID, err := c.AddCoursePredicate(reqp)
	if err != nil {
		return fmt.Errorf("验证失败: %w", err)
	}

	// 查询验证结果
	resp, err := c.GetPredicateResponse(studentID, requestID)
	if err != nil {
		return fmt.Errorf("查询验证结果失败: %w", err)
	}

	if !resp.Success {
		msg := "未知错误"
		if resp.ErrorMessage != nil {
			msg = *resp.ErrorMessage
		}
		return fmt.Errorf("验证失败: %s", msg)
	}

	reqr := &AddRequest{
		StudentAssoc:          studentID,
		CourseSelectTurnAssoc: turnID,
		RequestMiddleDtos: []RequestMiddleDto{
			{
				LessonAssoc: lessonID,
				VirtualCost: virtualCost,
			},
		},
		CoursePackAssoc: nil,
	}

	// 提交选课请求
	requestID, err = c.AddCourseRequest(reqr)
	if err != nil {
		return fmt.Errorf("提交选课请求失败: %w", err)
	}

	// 查询选课结果
	resp, err = c.GetAddDropResponse(studentID, requestID)
	if err != nil {
		return fmt.Errorf("查询选课结果失败: %w", err)
	}

	if !resp.Success {
		msg := "未知错误"
		if resp.ErrorMessage != nil {
			msg = *resp.ErrorMessage
		}
		return fmt.Errorf("选课失败: %s", msg)
	}

	return nil
}

// DropCourse 退课（包含验证和提交）
func (c *Client) DropCourse(studentID, turnID, lessonID int) error {
	reqp := &DropPredicate{
		StudentAssoc:          studentID,
		CourseSelectTurnAssoc: turnID,
		LessonAssocSet:        []int{lessonID},
	}

	// 先验证
	requestID, err := c.DropCoursePredicate(reqp)
	if err != nil {
		return fmt.Errorf("验证失败: %w", err)
	}

	// 查询验证结果
	resp, err := c.GetPredicateResponse(studentID, requestID)
	if err != nil {
		return fmt.Errorf("查询验证结果失败: %w", err)
	}

	if !resp.Success {
		msg := "未知错误"
		if resp.ErrorMessage != nil {
			msg = *resp.ErrorMessage
		}
		return fmt.Errorf("验证失败: %s", msg)
	}

	reqr := &DropRequest{
		StudentAssoc:          studentID,
		CourseSelectTurnAssoc: turnID,
		LessonAssocs:          []int{lessonID},
		CoursePackAssoc:       nil,
	}

	// 提交退课请求
	requestID, err = c.DropCourseRequest(reqr)
	if err != nil {
		return fmt.Errorf("提交退课请求失败: %w", err)
	}

	// 查询退课结果
	resp, err = c.GetAddDropResponse(studentID, requestID)
	if err != nil {
		return fmt.Errorf("查询退课结果失败: %w", err)
	}

	if !resp.Success {
		msg := "未知错误"
		if resp.ErrorMessage != nil {
			msg = *resp.ErrorMessage
		}
		return fmt.Errorf("退课失败: %s", msg)
	}

	return nil
}
