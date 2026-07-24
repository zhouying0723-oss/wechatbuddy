# WeChatBuddy

WeChatBuddy 是一个面向 macOS 的微信 AI 回复辅助工具。用户在微信输入框中输入草稿后，通过全局快捷键 `Command + Shift + R` 触发文本优化；应用读取当前输入框内容，调用火山方舟等 OpenAI 协议兼容模型服务完成纠错、润色和语气优化，再将结果写回输入框，由用户确认并手动发送。

## 项目状态

当前版本：`v0.15.0`

当前阶段：阶段 5，体验与发布准备。

## 核心原则

- 使用 Swift 与 SwiftUI 开发 macOS 菜单栏应用。
- 使用 macOS Accessibility API 读取和修改微信输入框。
- 对不暴露 AX 文本控件的微信版本，使用受控键盘复制并完整恢复剪贴板。
- 安全写回时只替换输入框草稿，不模拟发送操作。
- 通过系统级 `Command + Shift + R` 快捷键触发草稿读取。
- 应用只改写草稿，不自动发送消息。
- 模型服务 API Key 仅保存在 macOS Keychain，不写入代码、日志或 Git。
- 火山方舟为默认供应商，Base URL 与模型 ID 可在设置页配置。
- 默认改写语气可选择自然、友好、专业或简洁，并保存在本机偏好中。
- 模型请求支持取消，并对超时、断网和服务限流提供明确提示。
- `Command + Shift + R` 已串联草稿读取、AI 改写、二次校验和安全写回。
- 短文本改写默认关闭深度思考，并使用 15 秒超时避免长时间等待。
- 所有开发在 `feature/*` 分支完成，经确认后再合并到 `main`。
- 每个独立功能小步提交，并同步维护 `PROJECT.md` 与 `CHANGELOG.md`。

## 技术可行性

整体方案可行，但依赖微信当前版本向 macOS Accessibility API 暴露可读写的输入控件。不同微信版本可能改变控件层级、角色或属性，因此实现中需要：

- 运行前获取“辅助功能”权限。
- 识别前台应用确实为微信。
- 从系统焦点元素开始查找可编辑文本控件，并准备层级遍历回退方案。
- 对无法读取、无法写入、微信控件结构变化等情况给出明确错误提示。
- 在真实微信版本上进行人工集成测试。

全局快捷键、菜单栏应用、OpenAI API 调用和 Apple Silicon 支持均可由 macOS 原生能力实现。Accessibility 权限无法静默授予，必须由用户在系统设置中手动开启。

## 计划技术栈

- Swift 6
- SwiftUI
- AppKit（菜单栏及必要的 macOS 生命周期集成）
- ApplicationServices / Accessibility API
- URLSession（火山方舟及 OpenAI 协议兼容 API）
- Security / Keychain Services（密钥存储）
- XCTest
- Xcode 与 Git

## 文档

- [PROJECT.md](PROJECT.md)：项目目标、架构、阶段与任务状态
- [CHANGELOG.md](CHANGELOG.md)：版本变更记录
- [docs/architecture.md](docs/architecture.md)：详细模块边界与数据流
- [docs/development.md](docs/development.md)：分支、提交、版本与验证规范
- [docs/privacy.md](docs/privacy.md)：数据发送、本机存储、剪贴板与日志边界
- [AGENTS.md](AGENTS.md)：仓库级开发与自动化代理约束

## 分支与提交规范

分支示例：

- `feature/menu-bar`
- `feature/accessibility`
- `feature/openai-api`

提交消息格式：

- `feat: 新增XXX功能`
- `fix: 修复XXX问题`
- `refactor: 重构XXX模块`
- `docs: 更新XXX文档`

功能分支只推送到远程，不由开发助手直接合并到 `main`。
