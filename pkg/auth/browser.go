package auth

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/launcher"
	"github.com/go-rod/stealth"
)

// BrowserAuth 浏览器认证
type BrowserAuth struct {
	browser *rod.Browser
	page    *rod.Page
}

// NewBrowserAuth 创建浏览器认证实例
func NewBrowserAuth(headless bool) (*BrowserAuth, error) {
	launcher := launcher.New().
		Headless(headless).
		Set("disable-blink-features", "AutomationControlled").
		UserDataDir("")

	browserURL, err := launcher.Launch()
	if err != nil {
		return nil, fmt.Errorf("启动浏览器失败: %w", err)
	}

	browser := rod.New().ControlURL(browserURL)
	if err := browser.Connect(); err != nil {
		return nil, fmt.Errorf("连接浏览器失败: %w", err)
	}

	// 使用stealth模式避免被检测
	page, err := stealth.Page(browser)
	if err != nil {
		return nil, fmt.Errorf("创建页面失败: %w", err)
	}

	return &BrowserAuth{
		browser: browser,
		page:    page,
	}, nil
}

// Login 登录并获取Cookies
func (ba *BrowserAuth) Login(loginURL string, timeout time.Duration) ([]*http.Cookie, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// 导航到登录页面
	if err := ba.page.Context(ctx).Navigate(loginURL); err != nil {
		return nil, fmt.Errorf("导航到登录页面失败: %w", err)
	}

	// 等待用户登录（检测URL变化或特定元素出现）
	// 这里假设登录后会跳转到特定页面
	ba.page.WaitStable(time.Second)

	// 获取Cookies
	cookies, err := ba.page.Cookies([]string{"https://byyt.ecnu.edu.cn"})
	if err != nil {
		return nil, fmt.Errorf("获取Cookies失败: %w", err)
	}

	// 转换为http.Cookie
	httpCookies := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		var expires time.Time
		if cookie.Expires > 0 {
			expires = time.Unix(int64(cookie.Expires), 0)
		}
		
		var sameSite http.SameSite
		switch cookie.SameSite {
		case "Strict":
			sameSite = http.SameSiteStrictMode
		case "Lax":
			sameSite = http.SameSiteLaxMode
		case "None":
			sameSite = http.SameSiteNoneMode
		default:
			sameSite = http.SameSiteDefaultMode
		}
		
		httpCookie := &http.Cookie{
			Name:     cookie.Name,
			Value:    cookie.Value,
			Path:     cookie.Path,
			Domain:   cookie.Domain,
			Expires:  expires,
			Secure:   cookie.Secure,
			HttpOnly: cookie.HTTPOnly,
			SameSite: sameSite,
		}
		httpCookies = append(httpCookies, httpCookie)
	}

	return httpCookies, nil
}

// WaitForLogin 等待用户登录完成
func (ba *BrowserAuth) WaitForLogin(checkURL string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// 等待URL包含特定字符串或特定元素出现
	err := ba.page.Context(ctx).WaitStable(time.Second)
	if err != nil {
		return fmt.Errorf("等待登录超时: %w", err)
	}

	// 可以添加更多检查逻辑，比如检查特定元素是否存在
	return nil
}

// GetCookies 获取当前页面的Cookies
func (ba *BrowserAuth) GetCookies() ([]*http.Cookie, error) {
	cookies, err := ba.page.Cookies([]string{"https://byyt.ecnu.edu.cn"})
	if err != nil {
		return nil, fmt.Errorf("获取Cookies失败: %w", err)
	}

	httpCookies := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		var expires time.Time
		if cookie.Expires > 0 {
			expires = time.Unix(int64(cookie.Expires), 0)
		}
		
		var sameSite http.SameSite
		switch cookie.SameSite {
		case "Strict":
			sameSite = http.SameSiteStrictMode
		case "Lax":
			sameSite = http.SameSiteLaxMode
		case "None":
			sameSite = http.SameSiteNoneMode
		default:
			sameSite = http.SameSiteDefaultMode
		}
		
		httpCookie := &http.Cookie{
			Name:     cookie.Name,
			Value:    cookie.Value,
			Path:     cookie.Path,
			Domain:   cookie.Domain,
			Expires:  expires,
			Secure:   cookie.Secure,
			HttpOnly: cookie.HTTPOnly,
			SameSite: sameSite,
		}
		httpCookies = append(httpCookies, httpCookie)
	}

	return httpCookies, nil
}

// Close 关闭浏览器
func (ba *BrowserAuth) Close() error {
	if ba.browser != nil {
		return ba.browser.Close()
	}
	return nil
}

// GetPage 获取页面对象（用于高级操作）
func (ba *BrowserAuth) GetPage() *rod.Page {
	return ba.page
}

