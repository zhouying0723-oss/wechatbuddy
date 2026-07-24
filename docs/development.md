# 开发规范

## 开发前检查

每次开始任务前依次查看：

1. `README.md`
2. `PROJECT.md`
3. `CHANGELOG.md`
4. `git log -5 --oneline`
5. `git status`

## 分支策略

- `main` 只接收经过用户确认的合并。
- 每项功能从最新主线创建独立 `feature/*` 分支。
- 示例：`feature/menu-bar`、`feature/accessibility`、`feature/openai-api`。
- 功能完成后推送远程分支，等待用户确认，不自动合并。

## 提交策略

每个可独立验证的功能单独提交，避免累计大量改动。提交前必须：

1. 运行与改动范围匹配的构建和测试。
2. 检查 `git diff` 与 `git status`。
3. 更新 `PROJECT.md` 的任务状态。
4. 更新 `CHANGELOG.md` 的当前版本记录。
5. 执行 `git add`、`git commit` 和 `git push`。

提交消息使用：

- `feat: 新增XXX功能`
- `fix: 修复XXX问题`
- `refactor: 重构XXX模块`
- `docs: 更新XXX文档`

## 版本规则

开发阶段使用 `0.x.y`：

- 阶段或重要能力完成时增加次版本号 `x`。
- 兼容修复和小型改进增加修订号 `y`。
- 每个版本在 `CHANGELOG.md` 中记录日期及新增、修改、修复内容。

## 验证要求

- Swift 改动至少通过命令行构建。
- 可测试逻辑需通过对应单元测试。
- Accessibility 与微信交互需记录 macOS、微信版本和人工测试结果。
- 禁止提交 API Key、签名凭据、个人配置及构建产物。
