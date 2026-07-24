import SwiftUI

@main
struct WeChatBuddyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("WeChatBuddy", systemImage: "wand.and.stars") {
            MenuBarContent(appState: appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
