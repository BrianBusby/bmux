import Foundation
import SQLite3

/// Thin SQLite connection wrapper intended to be owned by a higher-level repository actor.
final class ProvenanceSQLiteDatabase {
    private static let defaultBusyTimeoutMilliseconds: Int32 = 5_000

    private var handle: OpaquePointer?
    let url: URL

    /// Opens or creates a SQLite database file.
    ///
    /// - Parameters:
    ///   - url: Database file URL to open.
    ///   - fileManager: Filesystem dependency used to create the parent directory.
    /// - Throws: ``ProvenanceSQLiteError`` or filesystem errors.
    init(
        url: URL,
        fileManager: FileManager = .default,
        busyTimeoutMilliseconds: Int32 = ProvenanceSQLiteDatabase.defaultBusyTimeoutMilliseconds
    ) throws {
        self.url = url
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "open failed"
            if let opened {
                sqlite3_close(opened)
            }
            throw ProvenanceSQLiteError.sqlite(message: message)
        }
        self.handle = opened
        sqlite3_busy_timeout(opened, max(0, busyTimeoutMilliseconds))
        try executeConnectionPragmaAllowingLockContention("PRAGMA journal_mode = WAL")
        try executeConnectionPragmaAllowingLockContention("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    /// Executes SQL that does not return rows.
    ///
    /// - Parameter sql: SQL statement or statements to execute.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the statement.
    func execute(_ sql: String) throws {
        guard let handle else {
            throw ProvenanceSQLiteError.sqlite(message: "database is closed")
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? self.message
            sqlite3_free(errorMessage)
            throw ProvenanceSQLiteError.sqlite(message: message)
        }
    }

    /// Prepares one SQL statement for binding and stepping.
    ///
    /// - Parameter sql: SQL statement to prepare.
    /// - Returns: A finalized-on-deinit statement wrapper.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the statement.
    func prepare(_ sql: String) throws -> ProvenanceSQLiteStatement {
        guard let handle else {
            throw ProvenanceSQLiteError.sqlite(message: "database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ProvenanceSQLiteError.sqlite(message: message)
        }
        return ProvenanceSQLiteStatement(database: handle, statement: statement)
    }

    /// SQLite `PRAGMA user_version` for the open database.
    var userVersion: Int32 {
        get throws {
            let statement = try prepare("PRAGMA user_version")
            defer { statement.finalize() }
            guard try statement.step() else { return 0 }
            return statement.int32(at: 0)
        }
    }

    /// Updates SQLite `PRAGMA user_version` for the open database.
    ///
    /// - Parameter version: Schema version to record.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the update.
    func setUserVersion(_ version: Int32) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    /// Number of rows changed by the most recent SQLite write.
    var changes: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_changes(handle))
    }

    /// Most recent SQLite error message for this connection.
    var message: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else { return "unknown sqlite error" }
        return String(cString: raw)
    }

    private func executeConnectionPragmaAllowingLockContention(_ sql: String) throws {
        do {
            try execute(sql)
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error,
               Self.isLockContentionMessage(message) {
                return
            }
            throw error
        }
    }

    private static func isLockContentionMessage(_ message: String) -> Bool {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("database is locked")
            || normalized.contains("database is busy")
    }
}
