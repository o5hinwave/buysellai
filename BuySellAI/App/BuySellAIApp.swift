import SwiftData
import SwiftUI

@main
struct BuySellAIApp: App {
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appStore)
                .modelContainer(for: HistoryEntryModel.self)
                .tint(Color.brand.primary)
        }
    }
}
