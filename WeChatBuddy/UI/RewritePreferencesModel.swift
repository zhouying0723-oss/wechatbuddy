import Foundation

@MainActor
final class RewritePreferencesModel: ObservableObject {
    @Published var tone: RewriteTone = .natural
    @Published var customInstruction =
        UserDefaultsRewritePreferencesStore.defaultCustomInstruction

    private let store: any RewritePreferencesStoring

    init(store: any RewritePreferencesStoring) {
        self.store = store
    }

    func refresh() {
        tone = store.loadTone()
        customInstruction = store.loadCustomInstruction()
    }

    func save() {
        store.saveTone(tone)
        store.saveCustomInstruction(customInstruction)
        customInstruction = store.loadCustomInstruction()
    }

    func restoreDefaultInstruction() {
        customInstruction =
            UserDefaultsRewritePreferencesStore.defaultCustomInstruction
        store.saveCustomInstruction(customInstruction)
    }
}
