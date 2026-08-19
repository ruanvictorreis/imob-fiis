import SwiftData
import SwiftUI

@main
struct ImobFIIsApp: App {
    private let container: ModelContainer

    init() {
        let container = Persistence.makeContainer()
        SampleData.seedIfNeeded(in: container.mainContext)
        self.container = container
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
