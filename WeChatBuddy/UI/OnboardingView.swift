import AppKit
import SwiftUI

@MainActor
final class OnboardingStore {
    private enum Key {
        static let hasCompleted = "onboarding.hasCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompleted: Bool {
        defaults.bool(forKey: Key.hasCompleted)
    }

    func complete() {
        defaults.set(true, forKey: Key.hasCompleted)
    }
}

enum OnboardingLink {
    static let modelActivation = URL(
        string: "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement"
    )!
    static let apiKey = URL(
        string: "https://console.volcengine.com/ark/region:ark+cn-beijing/apikey"
    )!
    static let documentation = URL(
        string: "https://www.volcengine.com/docs/82379/"
    )!
}

@MainActor
final class OnboardingWindowPresenter: ObservableObject {
    private let store: OnboardingStore
    private var windowController: NSWindowController?

    init(store: OnboardingStore = OnboardingStore()) {
        self.store = store
    }

    func presentIfNeeded(appState: AppState) {
        guard !store.hasCompleted else {
            return
        }
        present(appState: appState)
    }

    func present(appState: AppState) {
        if let window = windowController?.window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView(
            appState: appState,
            onComplete: { [weak self] in
                self?.store.complete()
                self?.windowController?.close()
                self?.windowController = nil
            }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "欢迎使用 WeChatBuddy"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 520))
        window.center()
        windowController = NSWindowController(window: window)

        NSApplication.shared.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
    }
}

private struct OnboardingView: View {
    @ObservedObject var appState: AppState
    let onComplete: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: stepIcon)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(stepTitle)
                .font(.title.bold())

            Group {
                switch step {
                case 0:
                    welcomeStep
                case 1:
                    permissionStep
                case 2:
                    modelStep
                default:
                    usageStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("上一步") {
                    step -= 1
                }
                .disabled(step == 0)

                Spacer()

                Text("\(step + 1) / 4")
                    .foregroundStyle(.secondary)

                Spacer()

                if step < 3 {
                    Button("下一步") {
                        step += 1
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("开始使用") {
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(32)
        .onAppear {
            appState.refreshAccessibilityStatus()
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("在微信输入草稿后，按下 ⌘⇧R，WeChatBuddy 会润色文字并写回输入框。")
                .font(.title3)
                .multilineTextAlignment(.center)

            Label("不会读取聊天记录", systemImage: "checkmark.shield")
            Label("不会自动发送消息", systemImage: "hand.raised")
            Label("改写结果由你确认后手动发送", systemImage: "paperplane")
        }
    }

    private var permissionStep: some View {
        VStack(spacing: 18) {
            Text("WeChatBuddy 需要 macOS 辅助功能权限，才能读取和写回微信当前输入框。")
                .multilineTextAlignment(.center)

            Label(
                "当前状态：\(appState.accessibilityStatus.title)",
                systemImage: appState.accessibilityStatus == .authorized
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(
                appState.accessibilityStatus == .authorized ? .green : .orange
            )

            HStack {
                Button("请求权限") {
                    appState.requestAccessibilityAccess()
                }
                Button("打开辅助功能设置") {
                    appState.openAccessibilitySettings()
                }
                Button("重新检查") {
                    appState.refreshAccessibilityStatus()
                }
            }
        }
    }

    private var modelStep: some View {
        VStack(spacing: 14) {
            Text("使用前需要开通火山方舟模型并创建 API Key，然后在应用设置中保存配置。")
                .multilineTextAlignment(.center)

            Link(destination: OnboardingLink.modelActivation) {
                Label("1. 开通火山方舟模型", systemImage: "safari")
            }
            Link(destination: OnboardingLink.apiKey) {
                Label("2. 创建或管理 API Key", systemImage: "key")
            }
            Link(destination: OnboardingLink.documentation) {
                Label("查看火山方舟官方文档", systemImage: "book")
            }

            SettingsLink {
                Label("3. 打开 WeChatBuddy 设置", systemImage: "gear")
            }

            Text("在设置中保存 API Key 和模型 ID，然后点击“测试模型连接”。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var usageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            instruction(1, "打开微信并进入任意聊天")
            instruction(2, "点击输入框，输入一段待优化的草稿")
            instruction(3, "按下 Command + Shift + R")
            instruction(4, "等待优化结果写回，检查后手动发送")

            Divider()

            Label(
                "快捷键只会替换当前草稿，不会替你发送消息。",
                systemImage: "info.circle"
            )
            .foregroundStyle(.secondary)
        }
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
            Text(text)
        }
    }

    private var stepTitle: String {
        ["欢迎", "辅助功能权限", "配置模型服务", "开始改写"][step]
    }

    private var stepIcon: String {
        ["wand.and.stars", "accessibility", "brain", "keyboard"][step]
    }
}
