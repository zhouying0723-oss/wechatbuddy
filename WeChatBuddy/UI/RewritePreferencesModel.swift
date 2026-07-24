import Foundation

@MainActor
final class RewritePreferencesModel: ObservableObject {
    @Published var tone: RewriteTone = .natural

    private let store: any RewritePreferencesStoring

    init(store: any RewritePreferencesStoring) {
        self.store = store
    }

    func refresh() {
        tone = store.loadTone()
    }

    func save() {
        store.saveTone(tone)
    }
}
