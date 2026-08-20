import SwiftData
import SwiftUI

@main
struct ImobFIIsApp: App {
    private let container: ModelContainer

    init() {
        container = Persistence.makeContainer()
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
