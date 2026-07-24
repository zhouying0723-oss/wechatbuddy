import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var model: APIKeySettingsModel

    init(store: any APIKeyStoring = KeychainAPIKeyStore()) {
        _model = StateObject(
            wrappedValue: APIKeySettingsModel(store: store)
        )
    }

    var body: some View {
        Form {
            Section("OpenAI API") {
                SecureField("输入 API Key", text: $model.input)
                    .textFieldStyle(.roundedBorder)

                Text(model.status.title)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                HStack {
                    Button("保存") {
                        model.save()
                    }
                    .disabled(!model.canSave)

                    Button("删除", role: .destructive) {
                        model.delete()
                    }
                }

                Text("API Key 仅保存在本机 Keychain，不会写入项目文件或日志。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 460, height: 240)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            model.refresh()
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .failure:
            .red
        case .saved:
            .green
        case .unknown, .notSaved:
            .secondary
        }
    }
}
