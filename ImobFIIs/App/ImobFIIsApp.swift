import SwiftData
import SwiftUI

@main
struct ImobFIIsApp: App {
    private let container: ModelContainer

    init() {
        container = Persistence.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
