import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Recuperação do banco de dados")
struct PersistenceRecoveryTests {
    @Test @MainActor
    func loadThrowsWhenStoreIsCorrupted() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeGarbage(to: directory.appending(path: Persistence.portfolioStoreName))

        #expect(throws: (any Error).self) {
            try Persistence.loadAppPersistence(directory: directory, cloudKitDatabase: nil)
        }
    }

    @Test @MainActor
    func launcherShowsRecoveryAndRestoresLatestBackup() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeGarbage(to: directory.appending(path: Persistence.portfolioStoreName))
        try writeGarbage(to: directory.appending(path: Persistence.portfolioStoreName + "-wal"))
        try placeBackup("legacy-versioned", timestamp: 1_700_000_000, in: directory)
        try placeBackup("legacy-unversioned", timestamp: 1_800_000_000, in: directory)
        let now = Date(timeIntervalSince1970: 1_900_000_000)

        let launcher = AppLauncher(
            load: { try Persistence.loadAppPersistence(directory: directory, cloudKitDatabase: nil) },
            restore: { try PersistenceRecovery.restoreFromBackup(in: directory, now: now) }
        )
        guard case .failed = launcher.state else {
            Issue.record("Store corrompido deveria abrir a tela de recuperação")
            return
        }

        launcher.restoreBackup()

        guard case .ready(let container, let monitor) = launcher.state else {
            Issue.record("Restauração deveria abrir o container")
            return
        }
        let holdings = try container.mainContext.fetch(FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.ticker)]))
        #expect(holdings.map(\.ticker) == ["HGLG11", "KNCR11"])
        #expect(holdings.allSatisfy { $0.updatedAt == nil })
        #expect(monitor.status == .localOnly)

        let damaged = directory
            .appending(path: PersistenceRecovery.damagedDirectoryName)
            .appending(path: "1900000000")
        #expect(fileExists(damaged.appending(path: Persistence.portfolioStoreName)))
        #expect(fileExists(damaged.appending(path: Persistence.portfolioStoreName + "-wal")))
    }

    @Test
    func restoreWithoutBackupOnlyMovesDamagedStores() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeGarbage(to: directory.appending(path: Persistence.marketCacheStoreName))

        let restored = try PersistenceRecovery.restoreFromBackup(in: directory)

        #expect(!restored)
        #expect(!fileExists(directory.appending(path: Persistence.marketCacheStoreName)))
        #expect(!fileExists(directory.appending(path: Persistence.legacyStoreName)))
    }

    @Test @MainActor
    func retryKeepsRecoveryWhileStoreIsStillBroken() throws {
        let launcher = AppLauncher(
            load: { throw CocoaError(.fileReadCorruptFile) },
            restore: { throw CocoaError(.fileWriteNoPermission) }
        )

        launcher.restoreBackup()

        guard case .failed = launcher.state else {
            Issue.record("Deveria continuar na tela de recuperação")
            return
        }
        #expect(launcher.restoreFailed)
        launcher.retry()
        #expect(!launcher.restoreFailed)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PersistenceRecoveryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeGarbage(to url: URL) throws {
        try Data("isto não é um banco sqlite".utf8).write(to: url)
    }

    private func placeBackup(_ fixture: String, timestamp: Int, in directory: URL) throws {
        let bundle = Bundle(for: RecoveryBundleToken.self)
        let source = try #require(bundle.url(forResource: fixture, withExtension: "store"))
        let backup = directory
            .appending(path: LegacyStoreImporter.backupDirectoryName)
            .appending(path: String(timestamp))
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: backup.appending(path: Persistence.legacyStoreName))
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}

private final class RecoveryBundleToken {}
