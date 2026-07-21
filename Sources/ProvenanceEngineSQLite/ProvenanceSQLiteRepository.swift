import Foundation

/// Internal repository actor that owns one migrated SQLite database connection.
actor ProvenanceSQLiteRepository {
    private let database: ProvenanceSQLiteDatabase

    /// Opens the database and applies the supplied migrations before returning.
    ///
    /// - Parameters:
    ///   - url: SQLite database file URL.
    ///   - migrations: Ordered migration steps supported by this repository.
    ///   - fileManager: Filesystem dependency used by the SQLite connection.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors when opening or migrating fails.
    init(
        url: URL,
        migrations: [ProvenanceSQLiteMigration],
        fileManager: FileManager = .default
    ) throws {
        let migrator = try ProvenanceSQLiteMigrator(migrations: migrations)
        let database = try ProvenanceSQLiteDatabase(url: url, fileManager: fileManager)
        try migrator.migrate(database)

        self.database = database
    }

    /// Current migrated schema version recorded in SQLite `PRAGMA user_version`.
    func schemaVersion() throws -> Int32 {
        try database.userVersion
    }
}
