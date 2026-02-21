//
// LogStore.swift
//
//

import Foundation
import OSLog
import SQLite3

@globalActor
actor LogStore {
  static let shared = LogStore()

  nonisolated private static let systemLogger = Logger(
    subsystem: "com.everpcpc.kmreader",
    category: "Database"
  )
  nonisolated private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  struct CategoryCount: Hashable, Sendable {
    let category: String
    let count: Int
  }

  private let dbPath: URL
  private var db: OpaquePointer?

  private init() {
    let appSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    dbPath = logsDir.appendingPathComponent("logs.sqlite")

    var database: OpaquePointer?
    let openResult = sqlite3_open(dbPath.path, &database)
    guard openResult == SQLITE_OK, let database else {
      let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
      print("Failed to open log database: \(message)")
      if let database {
        sqlite3_close(database)
      }
      db = nil
      return
    }

    guard Self.migrate(on: database) else {
      sqlite3_close(database)
      db = nil
      return
    }

    db = database
    Task { await cleanup() }
  }

  private enum SQLValue {
    case int(Int32)
    case double(Double)
    case text(String)
  }

  private static func migrate(on db: OpaquePointer) -> Bool {
    let schema = currentSchema(on: db)
    let needsRebuild = !schema.isEmpty && !isCompatible(schema: schema)
    if needsRebuild {
      let schemaDescription = schema.keys.sorted().map { key in
        "\(key)=\(schema[key] ?? "")"
      }.joined(separator: ", ")
      systemLogger.notice(
        "Rebuilding logs table due to schema mismatch. Existing schema: \(schemaDescription, privacy: .public)"
      )
      guard execute("DROP TABLE IF EXISTS logs", on: db) else {
        systemLogger.error("Failed to drop logs table while rebuilding logs schema")
        return false
      }
    }

    let createSQL = """
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date REAL NOT NULL,
        level INTEGER NOT NULL,
        category TEXT NOT NULL,
        message TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_logs_date ON logs(date);
      CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);
      CREATE INDEX IF NOT EXISTS idx_logs_category ON logs(category);
      """
    let created = execute(createSQL, on: db)
    if created && needsRebuild {
      systemLogger.notice("Logs table rebuild completed")
    }
    return created
  }

  private static func currentSchema(on db: OpaquePointer) -> [String: String] {
    let sql = "PRAGMA table_info(logs)"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      return [:]
    }

    var columns: [String: String] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
      guard
        let namePtr = sqlite3_column_text(statement, 1),
        let typePtr = sqlite3_column_text(statement, 2)
      else {
        continue
      }

      columns[String(cString: namePtr)] = String(cString: typePtr).uppercased()
    }
    return columns
  }

  private static func isCompatible(schema: [String: String]) -> Bool {
    guard schema.count == 5 else { return false }
    guard schema["id"] == "INTEGER" else { return false }
    guard schema["level"] == "INTEGER" else { return false }
    guard schema["category"] == "TEXT" else { return false }
    guard schema["message"] == "TEXT" else { return false }
    guard let dateType = schema["date"] else { return false }
    return dateType == "REAL" || dateType == "INTEGER"
  }

  private static func execute(_ sql: String, on db: OpaquePointer) -> Bool {
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
    guard result == SQLITE_OK else {
      let message: String
      if let errorMessage {
        message = String(cString: errorMessage)
        sqlite3_free(errorMessage)
      } else {
        message = String(cString: sqlite3_errmsg(db))
      }
      print("Failed to execute SQL: \(message)")
      return false
    }
    return true
  }

  private func bind(_ values: [SQLValue], to statement: OpaquePointer?) {
    guard let statement else { return }
    for (index, value) in values.enumerated() {
      let position = Int32(index + 1)
      switch value {
      case .int(let number):
        sqlite3_bind_int(statement, position, number)
      case .double(let number):
        sqlite3_bind_double(statement, position, number)
      case .text(let text):
        sqlite3_bind_text(statement, position, text, -1, Self.sqliteTransient)
      }
    }
  }

  func insert(date: Date, level: Int, category: String, message: String) {
    guard let db else { return }

    let sql = "INSERT INTO logs (date, level, category, message) VALUES (?, ?, ?, ?)"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(db)))")
      return
    }

    bind(
      [
        .double(date.timeIntervalSince1970),
        .int(Int32(clamping: level)),
        .text(category),
        .text(message),
      ],
      to: statement
    )

    if sqlite3_step(statement) != SQLITE_DONE {
      print("Failed to insert log entry: \(String(cString: sqlite3_errmsg(db)))")
    }
  }

  struct LogEntry: Identifiable, Hashable {
    let id: Int64
    let date: Date
    let level: Int
    let category: String
    let message: String
  }

  func query(
    minPriority: Int? = nil,
    category: String? = nil,
    search: String? = nil,
    since: Date? = nil,
    limit: Int = 500
  ) -> [LogEntry] {
    guard let db else { return [] }

    var conditions: [String] = []
    var params: [SQLValue] = []

    if let minPriority {
      conditions.append("level >= ?")
      params.append(.int(Int32(clamping: minPriority)))
    }
    if let category, category != "All" {
      conditions.append("category = ?")
      params.append(.text(category))
    }

    let searchTerm = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !searchTerm.isEmpty {
      let keyword = "%\(searchTerm)%"
      conditions.append("(message LIKE ? OR category LIKE ?)")
      params.append(.text(keyword))
      params.append(.text(keyword))
    }
    if let since {
      conditions.append("date >= ?")
      params.append(.double(since.timeIntervalSince1970))
    }

    let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
    let sql = """
      SELECT id, date, level, category, message
      FROM logs
      \(whereClause)
      ORDER BY date DESC
      LIMIT ?
      """

    params.append(.int(Int32(clamping: max(1, limit))))

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("Failed to prepare query statement: \(String(cString: sqlite3_errmsg(db)))")
      return []
    }

    bind(params, to: statement)

    var entries: [LogEntry] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      let id = sqlite3_column_int64(statement, 0)
      let date = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
      let level = Int(sqlite3_column_int(statement, 2))
      let category = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
      let message = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
      entries.append(LogEntry(id: id, date: date, level: level, category: category, message: message))
    }

    return entries
  }

  func categories() -> [String] {
    guard let db else { return [] }

    let sql = "SELECT DISTINCT category FROM logs ORDER BY category"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("Failed to prepare categories statement: \(String(cString: sqlite3_errmsg(db)))")
      return []
    }

    var categories: [String] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      if let categoryPtr = sqlite3_column_text(statement, 0) {
        categories.append(String(cString: categoryPtr))
      }
    }
    return categories
  }

  func categoryCounts(minPriority: Int? = nil, since: Date? = nil) -> [CategoryCount] {
    guard let db else { return [] }

    var conditions: [String] = []
    var params: [SQLValue] = []
    if let minPriority {
      conditions.append("level >= ?")
      params.append(.int(Int32(clamping: minPriority)))
    }
    if let since {
      conditions.append("date >= ?")
      params.append(.double(since.timeIntervalSince1970))
    }

    let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
    let sql = """
      SELECT category, COUNT(*) as count
      FROM logs
      \(whereClause)
      GROUP BY category
      ORDER BY count DESC, category ASC
      """

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("Failed to prepare category counts statement: \(String(cString: sqlite3_errmsg(db)))")
      return []
    }

    bind(params, to: statement)

    var counts: [CategoryCount] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      guard let categoryPtr = sqlite3_column_text(statement, 0) else {
        continue
      }
      counts.append(
        CategoryCount(
          category: String(cString: categoryPtr),
          count: Int(sqlite3_column_int(statement, 1))
        )
      )
    }
    return counts
  }

  func cleanup(keepDays: Int = 7) {
    guard let db else { return }
    let cutoff = Date().addingTimeInterval(-Double(keepDays * 24 * 60 * 60))

    let sql = "DELETE FROM logs WHERE date < ?"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("Failed to prepare cleanup statement: \(String(cString: sqlite3_errmsg(db)))")
      return
    }

    bind([.double(cutoff.timeIntervalSince1970)], to: statement)
    if sqlite3_step(statement) != SQLITE_DONE {
      print("Failed to cleanup logs: \(String(cString: sqlite3_errmsg(db)))")
    }
  }

  func clear() {
    guard let db else { return }
    if !Self.execute("DELETE FROM logs", on: db) {
      print("Failed to clear logs")
    }
  }
}
