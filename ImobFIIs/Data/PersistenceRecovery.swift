import Foundation

/// Tira do caminho os stores que não abrem e deixa o backup local mais recente pronto para
/// importação no próximo carregamento: a cópia em JSON da carteira ou, sem ela, o `default.store`
/// da migração da V1. Posições que estão no iCloud voltam pela sincronização do CloudKit.
enum PersistenceRecovery {
    static let damagedDirectoryName = "DamagedStores"

    private static let storeBaseNames = [Persistence.portfolioStoreName, Persistence.marketCacheStoreName]
        .map { ($0 as NSString).deletingPathExtension }

    /// Retorna `true` quando um backup local foi recolocado para importação.
    @discardableResult
    static func restoreFromBackup(
        in directory: URL,
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws -> Bool {
        try moveDamagedStores(in: directory, fileManager: fileManager, now: now)
        if try PortfolioBackupStore(directory: directory, fileManager: fileManager).stageLatestForRestore() {
            return true
        }
        return try stageLatestLegacyBackup(in: directory, fileManager: fileManager)
    }

    /// Inclui os arquivos auxiliares do SQLite (`-shm`, `-wal`) e do CloudKit (`.portfolio_SUPPORT`, `_ckAssets`).
    private static func moveDamagedStores(in directory: URL, fileManager: FileManager, now: Date) throws {
        let names = try fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        let damaged = names.filter { name in
            storeBaseNames.contains { base in name.hasPrefix(base) || name.hasPrefix(".\(base)") }
        }
        guard !damaged.isEmpty else { return }

        let destination = directory
            .appending(path: damagedDirectoryName)
            .appending(path: String(Int(now.timeIntervalSince1970)))
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in damaged {
            try fileManager.moveItem(at: directory.appending(path: name), to: destination.appending(path: name))
        }
    }

    private static func stageLatestLegacyBackup(in directory: URL, fileManager: FileManager) throws -> Bool {
        let legacyName = Persistence.legacyStoreName
        guard !fileManager.fileExists(atPath: directory.appending(path: legacyName).path(percentEncoded: false)),
              let backup = latestBackupDirectory(in: directory, fileManager: fileManager)
        else { return false }

        for suffix in ["", "-shm", "-wal"] {
            let source = backup.appending(path: legacyName + suffix)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            try fileManager.copyItem(at: source, to: directory.appending(path: legacyName + suffix))
        }
        return true
    }

    static func latestBackupDirectory(in directory: URL, fileManager: FileManager = .default) -> URL? {
        let root = directory.appending(path: LegacyStoreImporter.backupDirectoryName)
        let names = (try? fileManager.contentsOfDirectory(atPath: root.path(percentEncoded: false))) ?? []
        return names
            .compactMap { name in Int(name).map { (timestamp: $0, name: name) } }
            .filter { entry in
                let store = root.appending(path: entry.name).appending(path: Persistence.legacyStoreName)
                return fileManager.fileExists(atPath: store.path(percentEncoded: false))
            }
            .max { $0.timestamp < $1.timestamp }
            .map { root.appending(path: $0.name) }
    }
}
