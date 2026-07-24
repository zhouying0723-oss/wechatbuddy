import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var apiKeyModel: APIKeySettingsModel
    @StateObject private var providerModel: ModelProviderSettingsModel
    @StateObject private var connectionTestModel: ModelConnectionTestModel
    @StateObject private var rewritePreferencesModel: RewritePreferencesModel

    init(
        appState: AppState,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        providerStore: any ModelProviderSettingsStoring =
            UserDefaultsModelProviderSettingsStore(),
        rewritePreferencesStore: any RewritePreferencesStoring =
            UserDefaultsRewritePreferencesStore(),
        connectionTester: (any ModelConnectionTesting)? = nil
    ) {
        self.appState = appState
        _apiKeyModel = StateObject(
            wrappedValue: APIKeySettingsModel(store: apiKeyStore)
        )
        _providerModel = StateObject(
            wrappedValue: ModelProviderSettingsModel(store: providerStore)
        )
        _connectionTestModel = StateObject(
            wrappedValue: ModelConnectionTestModel(
                tester: connectionTester ?? ModelConnectionTester(
                    apiKeyStore: apiKeyStore,
                    configurationStore: providerStore
                )
            )
        )
        _rewritePreferencesModel = StateObject(
            wrappedValue: RewritePreferencesModel(
                store: rewritePreferencesStore
            )
        )
    }

    var body: some View {
        Form {
            Section("模型服务") {
                LabeledContent("供应商", value: providerModel.provider.title)

                TextField("Base URL", text: $providerModel.baseURL)
                    .textFieldStyle(.roundedBorder)

                TextField("模型 ID", text: $providerModel.modelID)
                    .textFieldStyle(.roundedBorder)

                Text(providerModel.status.title)
                    .font(.caption)
                    .foregroundStyle(providerStatusColor)

                Button("保存模型配置") {
                    providerModel.save()
                }
            }

            Section("火山方舟 API Key") {
                SecureField("输入 API Key", text: $apiKeyModel.input)
                    .textFieldStyle(.roundedBorder)

                Text(apiKeyModel.status.title)
                    .font(.caption)
                    .foregroundStyle(apiKeyStatusColor)

                HStack {
                    Button("保存") {
                        apiKeyModel.save()
                    }
                    .disabled(!apiKeyModel.canSave)

                    Button("删除", role: .destructive) {
                        apiKeyModel.delete()
                    }
                }

                Text("API Key 仅保存在本机 Keychain，不会写入项目文件或日志。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("连接测试") {
                Text(connectionTestModel.status.title)
                    .font(.caption)
                    .foregroundStyle(connectionTestStatusColor)
                    .textSelection(.enabled)

                HStack {
                    Button {
                        Task {
                            await connectionTestModel.testConnection()
                        }
                    } label: {
                        if connectionTestModel.isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("测试模型连接")
                        }
                    }
                    .disabled(connectionTestModel.isTesting)

                    if connectionTestModel.isTesting {
                        Button("取消", role: .cancel) {
                            connectionTestModel.cancel()
                        }
                    }

                    if let errorMessage =
                        connectionTestModel.copyableErrorMessage
                    {
                        Button("复制错误信息") {
                            copyToPasteboard(errorMessage)
                        }
                    }
                }

                Text("测试会向已保存的模型发送一条最小请求，可能产生少量 Token 消耗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("改写偏好") {
                Picker("默认语气", selection: $rewritePreferencesModel.tone) {
                    ForEach(RewriteTone.allCases) { tone in
                        Text(tone.title).tag(tone)
                    }
                }

                Text(rewritePreferencesModel.tone.instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("保存改写偏好") {
                    rewritePreferencesModel.save()
                }
            }

            Section("隐私与数据") {
                Label(
                    "仅在你主动触发时，将当前输入框草稿发送到已配置的模型服务。",
                    systemImage: "text.bubble"
                )
                Label(
                    "不读取聊天记录或联系人，不持久化保存草稿和改写结果。",
                    systemImage: "externaldrive.badge.xmark"
                )
                Label(
                    "API Key 只存于本机 Keychain；剪贴板使用后会恢复。",
                    systemImage: "key.fill"
                )
                Label(
                    "应用只写回草稿，消息始终由你确认后手动发送。",
                    systemImage: "hand.raised.fill"
                )

                Text("模型供应商可能按其服务条款处理请求数据，请同时查看供应商的隐私政策。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("安全诊断") {
                Text(diagnosticReport.text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Button("复制安全诊断信息") {
                    copyToPasteboard(diagnosticReport.text)
                }

                Text("诊断摘要不会包含 API Key、模型地址、微信草稿或模型回复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 520, height: 760)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            providerModel.refresh()
            apiKeyModel.refresh()
            rewritePreferencesModel.refresh()
            appState.refreshAccessibilityStatus()
        }
    }

    private var diagnosticReport: DiagnosticReport {
        DiagnosticReportFactory.make(
            appState: appState,
            apiKeyStatus: apiKeyModel.status,
            providerStatus: providerModel.status
        )
    }

    private var apiKeyStatusColor: Color {
        switch apiKeyModel.status {
        case .failure:
            .red
        case .saved:
            .green
        case .unknown, .notSaved:
            .secondary
        }
    }

    private var providerStatusColor: Color {
        switch providerModel.status {
        case .failure:
            .red
        case .saved:
            .green
        case .ready:
            .secondary
        }
    }

    private var connectionTestStatusColor: Color {
        switch connectionTestModel.status {
        case .failure:
            .red
        case .success:
            .green
        case .idle, .testing, .cancelled:
            .secondary
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
