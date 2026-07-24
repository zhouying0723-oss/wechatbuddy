import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var apiKeyModel: APIKeySettingsModel
    @StateObject private var providerModel: ModelProviderSettingsModel
    @StateObject private var connectionTestModel: ModelConnectionTestModel

    init(
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        providerStore: any ModelProviderSettingsStoring =
            UserDefaultsModelProviderSettingsStore(),
        connectionTester: (any ModelConnectionTesting)? = nil
    ) {
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

                Text("测试会向已保存的模型发送一条最小请求，可能产生少量 Token 消耗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 500, height: 560)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            providerModel.refresh()
            apiKeyModel.refresh()
        }
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
        case .idle, .testing:
            .secondary
        }
    }
}
