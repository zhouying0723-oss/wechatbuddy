# 发布与打包

## 当前发布边界

仓库提供 Apple Silicon 本机验收归档脚本，但不保存证书、私钥、Apple ID、App Store Connect API Key 或公证凭据。

无签名包只能用于开发机本地检查，不能作为公开下载包。面向其他用户分发时，必须使用 Apple Developer Program 提供的 `Developer ID Application` 证书签名，并完成 Apple 公证和 stapling。

## 本机验收包

在项目根目录执行：

```bash
./scripts/build-local-release.sh
```

默认输出：

```text
build/release/WeChatBuddy.xcarchive
build/release/WeChatBuddy-local-unsigned.zip
```

脚本固定构建 `arm64` Release 版本，不修改源码，不读取签名凭据。`build/` 已被 Git 忽略。

## 正式分发前置条件

1. 加入 Apple Developer Program。
2. 在 Xcode 中登录开发者账号。
3. 创建并安装有效的 `Developer ID Application` 证书。
4. 为 `com.wechatbuddy.app` 配置稳定的签名团队与能力。
5. 在 Release 配置中启用 Hardened Runtime。
6. 使用 Developer ID 对 Archive 导出产物签名。
7. 使用 `notarytool` 提交 Apple 公证。
8. 公证成功后使用 `stapler` 附加票据。
9. 使用 `codesign`、`spctl` 和 `stapler validate` 验证最终产物。

## 发布检查清单

- [ ] 当前提交位于待发布 tag，工作区干净。
- [ ] `MARKETING_VERSION` 与 CHANGELOG 一致。
- [ ] Finder、应用切换器和“应用程序”目录正确显示 WeChatBuddy 图标。
- [ ] arm64 自动测试全部通过。
- [ ] 首次使用向导和设置窗口布局正常。
- [ ] 辅助功能授权在正式签名 App 上保持稳定。
- [ ] 火山方舟 API Key 只保存在 Keychain。
- [ ] 微信草稿读取、改写、写回和手动发送流程通过。
- [ ] 剪贴板在成功和失败路径均恢复。
- [ ] 应用未包含 API Key、聊天内容、开发日志或个人配置。
- [ ] Developer ID 签名验证通过。
- [ ] Apple 公证与 stapling 验证通过。
- [ ] 在一台未参与开发的 Apple Silicon Mac 上完成安装和首次启动测试。

## 正式包验证命令

以下命令只用于验证已经签名并公证的最终 App：

```bash
codesign --verify --deep --strict --verbose=2 WeChatBuddy.app
spctl --assess --type execute --verbose=4 WeChatBuddy.app
xcrun stapler validate WeChatBuddy.app
```

不要把证书、密码或公证凭据写入脚本、Git 或终端历史。正式签名自动化应通过本机 Keychain 或 CI Secret 注入。
