import SwiftData
import SwiftUI

@main
struct ImobFIIsApp: App {
    private let container: ModelContainer

    init() {
        container = Persistence.makeAppContainer()
        ImobChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .imobAppearance()
        }
        .modelContainer(container)
    }
}
