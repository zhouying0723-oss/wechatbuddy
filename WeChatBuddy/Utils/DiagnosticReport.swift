import Foundation

struct DiagnosticReport {
    let appVersion: String
    let macOSVersion: String
    let accessibilityAuthorized: Bool
    let hotKeyAvailable: Bool
    let apiKeyConfigured: Bool
    let modelConfigured: Bool
    let latestWorkflowState: String

    var text: String {
        [
            "WeChatBuddy 安全诊断",
            "应用版本：\(appVersion)",
            "macOS：\(macOSVersion)",
            "辅助功能权限：\(yesNo(accessibilityAuthorized))",
            "全局快捷键：\(yesNo(hotKeyAvailable))",
            "API Key：\(configured(apiKeyConfigured))",
            "模型配置：\(configured(modelConfigured))",
            "最近运行状态：\(latestWorkflowState)",
            "隐私提示：本摘要不包含 API Key、模型地址、微信草稿或模型回复。"
        ].joined(separator: "\n")
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "可用" : "不可用"
    }

    private func configured(_ value: Bool) -> String {
        value ? "已配置" : "未配置"
    }
}

enum DiagnosticReportFactory {
    @MainActor
    static func make(
        appState: AppState,
        apiKeyStatus: APIKeySettingsStatus,
        providerStatus: ModelProviderSettingsStatus,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> DiagnosticReport {
        DiagnosticReport(
            appVersion: bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "未知",
            macOSVersion: processInfo.operatingSystemVersionString,
            accessibilityAuthorized:
                appState.accessibilityStatus == .authorized,
            hotKeyAvailable: appState.hotKeyStatus == .registered,
            apiKeyConfigured: apiKeyStatus == .saved,
            modelConfigured: providerStatus == .saved,
            latestWorkflowState: workflowSummary(
                appState.rewriteWorkflowStatus
            )
        )
    }

    private static func workflowSummary(
        _ status: RewriteWorkflowStatus
    ) -> String {
        switch status {
        case .idle:
            "尚未运行"
        case .processing:
            "处理中"
        case .success:
            "最近一次成功"
        case .failure:
            "最近一次失败（详细内容已省略）"
        }
    }
}
