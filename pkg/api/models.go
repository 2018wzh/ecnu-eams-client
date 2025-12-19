package api

// Student 学生信息
type Student struct {
	ID int `json:"id"`
}

// Turn 选课轮次
type Turn struct {
	ID                  int       `json:"id"`
	Name                string    `json:"name"`
	Bulletin            string    `json:"bulletin"`
	OpenDateTimeText    string    `json:"openDateTimeText"`
	SelectDateTimeText  string    `json:"selectDateTimeText"`
	DropDateTimeText    string    `json:"dropDateTimeText"`
	OpenDateTimeRange   TimeRange `json:"openDateTimeRange"`
	SelectDateTimeRange TimeRange `json:"selectDateTimeRange"`
	DropDateTimeRange   TimeRange `json:"dropDateTimeRange"`
	AddRulesText        []string  `json:"addRulesText"`
	DropRulesText       []string  `json:"dropRulesText"`
	TurnMode            TurnMode  `json:"turnMode"`
	AllowEnter          bool      `json:"allowEnter"`
}

// TimeRange 时间范围
type TimeRange struct {
	StartDateTime string `json:"startDateTime"`
	EndDateTime   string `json:"endDateTime"`
}

// TurnMode 选课模式
type TurnMode struct {
	EnablePreSelect      bool `json:"enablePreSelect"`
	EnableDelayRelease   bool `json:"enableDelayRelease"`
	EnableVirtualWallet  bool `json:"enableVirtualWallet"`
	ShowCount            bool `json:"showCount"`
	EnableStudentPreset  bool `json:"enableStudentPreset"`
}

// Lesson 课程
type Lesson struct {
	ID                    int                `json:"id"`
	NameZh                string             `json:"nameZh"`
	NameEn                *string            `json:"nameEn"`
	Code                  string             `json:"code"`
	Teachers              []Teacher          `json:"teachers"`
	Course                Course             `json:"course"`
	CourseType            CourseType         `json:"courseType"`
	ExamMode              ExamMode           `json:"examMode"`
	CourseProperty        CourseProperty     `json:"courseProperty"`
	Campus                Campus             `json:"campus"`
	LimitCount            int                `json:"limitCount"`
	AcrossMajorLimitCount int                `json:"acrossMajorLimitCount"`
	AcrossMajorEnable     bool               `json:"acrossMajorEnable"`
	DateTimePlace         DateTimePlace      `json:"dateTimePlace"`
	ScheduleGroups        []ScheduleGroup    `json:"scheduleGroups"`
	VirtualCost           *int               `json:"virtualCost"`
	Retake                bool               `json:"retake"`
	Setup                 bool               `json:"setup"`
	Pinned                bool               `json:"pinned"`
	NeedAttend            bool               `json:"needAttend"`
	AcrossMajor           bool               `json:"acrossMajor"`
}

// Teacher 教师
type Teacher struct {
	ID     int     `json:"id"`
	NameZh string  `json:"nameZh"`
	NameEn *string `json:"nameEn"`
}

// Course 课程信息
type Course struct {
	ID        int      `json:"id"`
	NameZh    string   `json:"nameZh"`
	NameEn    *string  `json:"nameEn"`
	Code      string   `json:"code"`
	Credits   float64  `json:"credits"`
	Flags     []string `json:"flags"`
	Department Department `json:"department"`
}

// Department 部门
type Department struct {
	ID        int     `json:"id"`
	NameZh    string  `json:"nameZh"`
	NameEn    *string `json:"nameEn"`
	Code      string  `json:"code"`
	Telephone *string `json:"telephone"`
}

// CourseType 课程类型
type CourseType struct {
	ID     int     `json:"id"`
	NameZh string  `json:"nameZh"`
	NameEn *string `json:"nameEn"`
	Code   string  `json:"code"`
}

// ExamMode 考核模式
type ExamMode struct {
	ID     int     `json:"id"`
	NameZh string  `json:"nameZh"`
	NameEn *string `json:"nameEn"`
	Code   string  `json:"code"`
}

// CourseProperty 课程属性
type CourseProperty struct {
	ID     int     `json:"id"`
	NameZh string  `json:"nameZh"`
	NameEn *string `json:"nameEn"`
	Code   string  `json:"code"`
}

// Campus 校区
type Campus struct {
	ID     int     `json:"id"`
	NameZh string  `json:"nameZh"`
	NameEn *string `json:"nameEn"`
}

// DateTimePlace 时间地点
type DateTimePlace struct {
	TextZh string  `json:"textZh"`
	TextEn string  `json:"textEn"`
	Text   string  `json:"text"`
}

// ScheduleGroup 课程时间组
type ScheduleGroup struct {
	ID            int          `json:"id"`
	No            int          `json:"no"`
	Default       bool         `json:"default"`
	LimitCount    int          `json:"limitCount"`
	DateTimePlace DateTimePlace `json:"dateTimePlace"`
	Schedules     []Schedule   `json:"schedules"`
}

// Schedule 课程时间
type Schedule struct {
	LessonID        int `json:"lessonId"`
	ScheduleGroupID int `json:"scheduleGroupId"`
	Weekday         int `json:"weekday"`
	StartUnit       int `json:"startUnit"`
	EndUnit         int `json:"endUnit"`
	StartTime       int `json:"startTime"`
	EndTime         int `json:"entTime"`
}

// SelectDetail 选课详情
type SelectDetail struct {
	PackCourseSelect      bool      `json:"packCourseSelect"`
	RetakeDisallow        bool      `json:"retakeDisallow"`
	RetakeExclusiveAllow  bool      `json:"retakeExclusiveAllow"`
	SubstituteCourseRetake bool     `json:"substituteCourseRetake"`
	RetakePassedDisallow  bool      `json:"retakePassedDisallow"`
	ConflictAgreeNotAttend bool    `json:"conflictAgreeNotAttend"`
	Turn                  TurnDetail `json:"turn"`
	BizTypeID             int        `json:"bizTypeId"`
	Semester              Semester   `json:"semester"`
	CampusID              int        `json:"campusId"`
	ProgramID             int        `json:"programId"`
	Program                Program    `json:"program"`
}

// TurnDetail 轮次详情
type TurnDetail struct {
	ID          int      `json:"id"`
	SemesterAssoc int    `json:"semesterAssoc"`
	TurnMode    TurnMode `json:"turnMode"`
	TurnTab     TurnTab  `json:"turnTab"`
	Name        string   `json:"name"`
	Bulletin    string   `json:"bulletin"`
}

// TurnTab 选课标签
type TurnTab struct {
	ShowPlanTab           bool    `json:"showPlanTab"`
	PlanTabName           string  `json:"planTabName"`
	ShowPublicCourseTab   bool    `json:"showPublicCourseTab"`
	PublicCourseTabName   string  `json:"publicCourseTabName"`
	ShowAcrossMajorTab    bool    `json:"showAcrossMajorTab"`
	AcrossMajorTabName    string  `json:"acrossMajorTabName"`
	ShowRetakeTab         bool    `json:"showRetakeTab"`
	RetakeTabName         string  `json:"retakeTabName"`
	ShowAllCourseTab      bool    `json:"showAllCourseTab"`
	AllCourseTabName      string  `json:"allCourseTabName"`
	ShowSelectedTab       bool    `json:"showSelectedTab"`
	SelectedTabName       string  `json:"selectedTabName"`
	ShowCourseTableTab    bool    `json:"showCourseTableTab"`
	CourseTableTabName    string  `json:"courseTableTabName"`
}

// Semester 学期
type Semester struct {
	ID        int     `json:"id"`
	NameZh    string  `json:"nameZh"`
	NameEn    string  `json:"nameEn"`
	Season    string  `json:"season"`
	CalendarID int    `json:"calendarId"`
}

// Program 培养方案
type Program struct {
	ID            int     `json:"id"`
	NameZh        string  `json:"nameZh"`
	NameEn        *string `json:"nameEn"`
	ProgramType   string  `json:"programType"`
	Season        string  `json:"season"`
	BizTypeID     int     `json:"bizTypeId"`
	RequireCredits int    `json:"requireCredits"`
}

// QueryCondition 查询条件
type QueryCondition struct {
	Grades          []string     `json:"grades"`
	Departments     []Department `json:"departments"`
	Campuses        []Campus     `json:"campuses"`
	CourseTypes     []CourseType `json:"courseTypes"`
	CourseProperties []CourseProperty `json:"courseProperties"`
}

// LessonQueryRequest 课程查询请求
type LessonQueryRequest struct {
	TurnID              int     `json:"turnId"`
	StudentID           int     `json:"studentId"`
	SemesterID          int     `json:"semesterId"`
	PageNo              int     `json:"pageNo"`
	PageSize            int     `json:"pageSize"`
	CourseNameOrCode    string  `json:"courseNameOrCode"`
	LessonNameOrCode    string  `json:"lessonNameOrCode"`
	TeacherNameOrCode   string  `json:"teacherNameOrCode"`
	Week                string  `json:"week"`
	Grade               string  `json:"grade"`
	DepartmentID        string  `json:"departmentId"`
	MajorID             string  `json:"majorId"`
	AdminclassID        string  `json:"adminclassId"`
	CampusID            string  `json:"campusId"`
	OpenDepartmentID    string  `json:"openDepartmentId"`
	CourseTypeID        string  `json:"courseTypeId"`
	CoursePropertyID    string  `json:"coursePropertyId"`
	CanSelect           bool    `json:"canSelect"`
	CanSelectText       string  `json:"_canSelect"`
	CreditGte           *float64 `json:"creditGte"`
	CreditLte           *float64 `json:"creditLte"`
	HasCount            *bool    `json:"hasCount"`
	IDs                 []int    `json:"ids"`
	SubstitutedCourseID *int     `json:"substitutedCourseId"`
	CourseSubstitutePoolID *int  `json:"courseSubstitutePoolId"`
	SortField           string   `json:"sortField"`
	SortType            string   `json:"sortType"`
}

// LessonQueryResponse 课程查询响应
type LessonQueryResponse struct {
	Lessons  []Lesson `json:"lessons"`
	PageInfo PageInfo `json:"pageInfo"`
}

// PageInfo 分页信息
type PageInfo struct {
	CurrentPage int `json:"currentPage"`
	RowsInPage  int `json:"rowsInPage"`
	RowsPerPage int `json:"rowsPerPage"`
	TotalRows   int `json:"totalRows"`
	TotalPages  int `json:"totalPages"`
}

// RepairedCourse 重修课程
type RepairedCourse struct {
	ID                    int         `json:"id"`
	NameZh                string      `json:"nameZh"`
	NameEn                string      `json:"nameEn"`
	Code                  string      `json:"code"`
	Credits               float64     `json:"credits"`
	Flags                 interface{} `json:"flags"`
	Department            Department  `json:"department"`
	Score                 int         `json:"score"`
	CourseSelectPassStatus string     `json:"courseSelectPassStatus"`
	CourseType            CourseType  `json:"courseType"`
	Passed                bool        `json:"passed"`
}

// CountInfo 课程名额信息
type CountInfo struct {
	LimitCount     int `json:"limitCount"`
	AmLimitCount   int `json:"amLimitCount"`
	StdCount       int `json:"stdCount"`
	AmStdCount     int `json:"amStdCount"`
	PreStdCount    int `json:"preStdCount"`
	PreAmStdCount  int `json:"preAmStdCount"`
}

// AddDropRequest 选退课请求
type AddDropRequest struct {
	StudentAssoc        int                `json:"studentAssoc"`
	CourseSelectTurnAssoc int              `json:"courseSelectTurnAssoc"`
	RequestMiddleDtos   []RequestMiddleDto `json:"requestMiddleDtos"`
	CoursePackAssoc     *int               `json:"coursePackAssoc"`
}

// RequestMiddleDto 请求中间DTO
type RequestMiddleDto struct {
	LessonAssoc int `json:"lessonAssoc"`
	VirtualCost int `json:"virtualCost"`
}

// AddDropResponse 选退课响应
type AddDropResponse struct {
	ID          string                 `json:"id"`
	RequestID   string                 `json:"requestId"`
	Exception   interface{}            `json:"exception"`
	ErrorMessage *string               `json:"errorMessage"`
	Success     bool                   `json:"success"`
	Result      map[string]interface{} `json:"result"`
}

