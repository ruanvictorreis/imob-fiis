import SwiftData
import SwiftUI

@main
struct ImobFIIsApp: App {
    @State private var launcher = AppLauncher.live()

    init() {
        ImobChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch launcher.state {
                case .ready(let container, let syncMonitor):
                    RootTabView()
                        .modelContainer(container)
                        .environment(syncMonitor)
                case .failed(let errorDescription):
                    StoreRecoveryView(
                        errorDescription: errorDescription,
                        restoreFailed: launcher.restoreFailed,
                        onRetry: launcher.retry,
                        onRestore: launcher.restoreBackup
                    )
                }
            }
            .imobAppearance()
        }
    }
}
