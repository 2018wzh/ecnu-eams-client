# ECNU选课系统客户端

基于Flutter开发的ECNU选课系统客户端，支持浏览课程、选课、退课和抢课功能。

## 功能特性

- ✅ 浏览器登录获取Cookie
- ✅ 浏览和搜索课程
- ✅ 选课和退课
- ✅ 抢课功能（自动轮询选课）
- ✅ 友好的用户界面
- ✅ 跨平台支持（Windows、macOS、Linux、Android、iOS）
- ✅ 提供Go库供二次开发

### 前置要求
- Flutter 3.0+
- Chrome/Chromium（用于浏览器登录）

### 运行Flutter应用

```bash
cd app
flutter pub get
flutter run
```

## 构建和发布

本项目使用GitHub Actions自动构建多平台可执行程序。

### 自动构建触发条件

- **推送Tag**: 当推送以`v`开头的tag时，会自动构建所有平台并创建GitHub Release
- **手动触发**: 在GitHub Actions页面手动触发构建

### 支持的平台

- **Android**: APK和AAB格式
- **Windows**: MSIX包
- **Linux**: AppImage格式
- **macOS**: DMG包
- **Web**: 静态网站文件

### 本地构建

#### Android
```bash
cd app
flutter build apk --release  # 构建APK
flutter build appbundle --release  # 构建AAB
```

#### Windows
```bash
cd app
flutter config --enable-windows-desktop
flutter build windows --release
flutter pub run msix:create --release  # 创建MSIX包
```

#### Linux
```bash
cd app
flutter config --enable-linux-desktop
flutter build linux --release
```

#### macOS
```bash
cd app
flutter config --enable-macos-desktop
flutter build macos --release
```

#### Web
```bash
cd app
flutter build web --release
```

## 使用说明

### 1. 登录

1. 打开应用后，会自动打开登录页面
2. 在WebView中完成ECNU统一认证登录
3. 登录成功后，Cookies会自动保存

### 2. 选择选课轮次

1. 在"选课轮次"标签页中选择当前要使用的选课轮次
2. 系统会自动加载该轮次的相关信息

### 3. 搜索课程

1. 切换到"搜索课程"标签页
2. 输入课程名称或代码进行搜索
3. 可以使用筛选条件（校区、课程类型等）
4. 点击课程卡片查看详情并选课

### 4. 查看已选课程

1. 切换到"已选课程"标签页
2. 查看当前已选的所有课程
3. 可以在此退选课程

### 5. 抢课功能

1. 在搜索课程时，可以将课程添加到抢课列表
2. 切换到"抢课"标签页
3. 开启抢课开关
4. 系统会自动轮询检查课程名额并尝试选课

### Flutter开发

```bash
cd app

# 获取依赖
flutter pub get

# 运行
flutter run

# 构建
flutter build
```

## API文档

详见 [docs/选课.md](docs/选课.md)

## 许可证

GNU General Public License v3.0 (GPL-3.0)

## 贡献

欢迎提交Issue和Pull Request！

## 免责声明

本工具仅供学习和研究使用，使用者需自行承担使用风险。请遵守学校相关规定，不得用于任何违法违规用途。
