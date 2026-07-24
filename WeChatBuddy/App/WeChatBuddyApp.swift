import SwiftUI

@main
struct WeChatBuddyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingPresenter = OnboardingWindowPresenter()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                appState: appState,
                showOnboarding: {
                    onboardingPresenter.present(appState: appState)
                }
            )
        } label: {
            Image(systemName: "wand.and.stars")
                .onAppear {
                    onboardingPresenter.presentIfNeeded(appState: appState)
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
