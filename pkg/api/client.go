package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	BaseURL = "https://byyt.ecnu.edu.cn/course-selection-api/api/v1"
)

// Client 选课API客户端
type Client struct {
	httpClient *http.Client
	baseURL    string
	cookies    []*http.Cookie
	headers    map[string]string
}

// NewClient 创建新的API客户端
func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: BaseURL,
		headers: make(map[string]string),
	}
}

// SetCookies 设置Cookies
func (c *Client) SetCookies(cookies []*http.Cookie) {
	c.cookies = cookies
}

// SetHeader 设置请求头
func (c *Client) SetHeader(key, value string) {
	c.headers[key] = value
}

// doRequest 执行HTTP请求
func (c *Client) doRequest(method, endpoint string, body interface{}) (*http.Response, error) {
	var reqBody io.Reader
	if body != nil {
		jsonData, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		reqBody = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequest(method, c.baseURL+endpoint, reqBody)
	if err != nil {
		return nil, err
	}

	// 设置请求头
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	for k, v := range c.headers {
		req.Header.Set(k, v)
	}

	// 设置Cookies
	for _, cookie := range c.cookies {
		req.AddCookie(cookie)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

// doJSONRequest 执行请求并解析JSON响应
func (c *Client) doJSONRequest(method, endpoint string, body interface{}, result interface{}) error {
	resp, err := c.doRequest(method, endpoint, body)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(bodyBytes))
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var apiResponse struct {
		Result  int             `json:"result"`
		Message *string         `json:"message"`
		Data    json.RawMessage `json:"data"`
	}

	if err := json.Unmarshal(bodyBytes, &apiResponse); err != nil {
		return err
	}

	if apiResponse.Result != 0 {
		msg := "unknown error"
		if apiResponse.Message != nil {
			msg = *apiResponse.Message
		}
		return fmt.Errorf("API error: %s", msg)
	}

	if result != nil {
		return json.Unmarshal(apiResponse.Data, result)
	}

	return nil
}

// Get 执行GET请求
func (c *Client) Get(endpoint string, result interface{}) error {
	return c.doJSONRequest("GET", endpoint, nil, result)
}

// Post 执行POST请求
func (c *Client) Post(endpoint string, body interface{}, result interface{}) error {
	return c.doJSONRequest("POST", endpoint, body, result)
}

// GetWithQuery 执行带查询参数的GET请求
func (c *Client) GetWithQuery(endpoint string, params map[string]string, result interface{}) error {
	u, err := url.Parse(c.baseURL + endpoint)
	if err != nil {
		return err
	}

	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	for k, v := range c.headers {
		req.Header.Set(k, v)
	}

	for _, cookie := range c.cookies {
		req.AddCookie(cookie)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(bodyBytes))
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var apiResponse struct {
		Result  int             `json:"result"`
		Message *string         `json:"message"`
		Data    json.RawMessage `json:"data"`
	}

	if err := json.Unmarshal(bodyBytes, &apiResponse); err != nil {
		return err
	}

	if apiResponse.Result != 0 {
		msg := "unknown error"
		if apiResponse.Message != nil {
			msg = *apiResponse.Message
		}
		return fmt.Errorf("API error: %s", msg)
	}

	if result != nil {
		return json.Unmarshal(apiResponse.Data, result)
	}

	return nil
}


