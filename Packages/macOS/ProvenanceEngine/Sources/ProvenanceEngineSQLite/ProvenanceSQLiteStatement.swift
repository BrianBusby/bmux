import Foundation
import SQLite3

/// Prepared SQLite statement wrapper with typed binding and column accessors.
final class ProvenanceSQLiteStatement {
    private let database: OpaquePointer
    private var statement: OpaquePointer?

    /// Creates a statement wrapper around a prepared SQLite statement.
    ///
    /// - Parameters:
    ///   - database: SQLite database handle used for error messages.
    ///   - statement: Prepared SQLite statement handle.
    init(database: OpaquePointer, statement: OpaquePointer) {
        self.database = database
        self.statement = statement
    }

    deinit {
        finalize()
    }

    /// Finalizes the underlying prepared statement if it is still open.
    func finalize() {
        if let statement {
            sqlite3_finalize(statement)
            self.statement = nil
        }
    }

    /// Binds an optional string value.
    ///
    /// - Parameters:
    ///   - value: String value to bind, or `nil` for SQL `NULL`.
    ///   - index: One-based SQLite parameter index.
    /// - Throws: ``ProvenanceSQLiteError`` when binding fails.
    func bind(_ value: String?, at index: Int32) throws {
        guard let statement else { return }
        if let value {
            let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
            guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
                throw ProvenanceSQLiteError.sqlite(message: message)
            }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw ProvenanceSQLiteError.sqlite(message: message)
            }
        }
    }

    /// Binds an integer value.
    ///
    /// - Parameters:
    ///   - value: Integer value to bind.
    ///   - index: One-based SQLite parameter index.
    /// - Throws: ``ProvenanceSQLiteError`` when binding fails.
    func bind(_ value: Int, at index: Int32) throws {
        guard let statement else { return }
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw ProvenanceSQLiteError.sqlite(message: message)
        }
    }

    /// Binds an optional double value.
    ///
    /// - Parameters:
    ///   - value: Double value to bind, or `nil` for SQL `NULL`.
    ///   - index: One-based SQLite parameter index.
    /// - Throws: ``ProvenanceSQLiteError`` when binding fails.
    func bind(_ value: Double?, at index: Int32) throws {
        guard let statement else { return }
        if let value {
            guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
                throw ProvenanceSQLiteError.sqlite(message: message)
            }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw ProvenanceSQLiteError.sqlite(message: message)
            }
        }
    }

    /// Advances the statement by one row.
    ///
    /// - Returns: `true` when a row is available, or `false` when the statement is complete.
    /// - Throws: ``ProvenanceSQLiteError`` when stepping fails.
    func step() throws -> Bool {
        guard let statement else { return false }
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return true
        }
        if result == SQLITE_DONE {
            return false
        }
        throw ProvenanceSQLiteError.sqlite(message: message)
    }

    /// Returns an optional string column.
    ///
    /// - Parameter index: Zero-based SQLite column index.
    /// - Returns: The column value, or `nil` for SQL `NULL`.
    func string(at index: Int32) -> String? {
        guard let statement, let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    /// Returns an integer column.
    ///
    /// - Parameter index: Zero-based SQLite column index.
    /// - Returns: The column value, or `0` when the statement has been finalized.
    func int(at index: Int32) -> Int {
        guard let statement else { return 0 }
        return Int(sqlite3_column_int64(statement, index))
    }

    /// Returns an optional integer column.
    ///
    /// - Parameter index: Zero-based SQLite column index.
    /// - Returns: The column value, or `nil` for SQL `NULL`.
    func optionalInt(at index: Int32) -> Int? {
        guard let statement else { return nil }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    /// Returns a 32-bit integer column.
    ///
    /// - Parameter index: Zero-based SQLite column index.
    /// - Returns: The column value, or `0` when the statement has been finalized.
    func int32(at index: Int32) -> Int32 {
        guard let statement else { return 0 }
        return sqlite3_column_int(statement, index)
    }

    /// Returns an optional double column.
    ///
    /// - Parameter index: Zero-based SQLite column index.
    /// - Returns: The column value, or `nil` for SQL `NULL`.
    func double(at index: Int32) -> Double? {
        guard let statement else { return nil }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private var message: String {
        guard let raw = sqlite3_errmsg(database) else { return "unknown sqlite error" }
        return String(cString: raw)
    }
}
