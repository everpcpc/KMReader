//
// LogStore.swift
//
//

import Foundation
import SQLiteData

@Table("logs")
nonisolated private struct StoredLogEntry {
  let id: Int64
  @Column(as: Date.UnixTimeRepresentation.self)
  var date: Date
  var level: Int
  var category: String
  var message: String
}

@Selection
nonisolated private struct LogCategoryCountRow {
  let category: String
  let count: Int
}

@globalActor
actor LogStore {
  static let shared = LogStore()

  private let database: DatabaseQueue?
  private let dbPath: URL

  private init() {
    let appSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    dbPath = logsDir.appendingPathComponent("logs.sqlite")

    do {
      print("LogStore opening database at: \(dbPath.path)")
      let db = try DatabaseQueue(path: dbPath.path)
      try Self.migrate(on: db, at: dbPath)
      let existingCount = try db.read { db in
        try StoredLogEntry.fetchCount(db)
      }
      print("LogStore open complete, existing rows: \(existingCount)")
      database = db
    } catch {
      print("Failed to open log database: \(error)")
      database = nil
    }

    Task { await cleanup() }
  }

  private static func migrate(on database: DatabaseQueue, at dbPath: URL) throws {
    print("LogStore migration start: \(dbPath.path)")
    var migrator = DatabaseMigrator()
    migrator.registerMigration("reset_logs_v2") { db in
      print("LogStore migration reset_logs_v2: dropping and recreating logs table")
      try #sql("DROP TABLE IF EXISTS logs").execute(db)
      try #sql(
        """
        CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date INTEGER NOT NULL,
          level INTEGER NOT NULL,
          category TEXT NOT NULL,
          message TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql("CREATE INDEX idx_logs_date ON logs(date)").execute(db)
      try #sql("CREATE INDEX idx_logs_level ON logs(level)").execute(db)
      try #sql("CREATE INDEX idx_logs_category ON logs(category)").execute(db)
    }
    try migrator.migrate(database)
    print("LogStore migration done")
  }

  func insert(date: Date, level: Int, category: String, message: String) {
    guard let database else { return }
    do {
      try database.write { db in
        try StoredLogEntry.insert {
          StoredLogEntry.Draft(
            date: date,
            level: level,
            category: category,
            message: message
          )
        }
        .execute(db)
      }
    } catch {
      print("Failed to insert log entry: \(error)")
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
    guard let database else { return [] }

    let categoryFilter: String? = {
      guard let category else { return nil }
      return category == "All" ? nil : category
    }()
    let searchTerm = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let hasMinPriority = minPriority != nil
    let minPriorityValue = minPriority ?? 0
    let hasCategory = categoryFilter != nil
    let categoryValue = categoryFilter ?? ""
    let hasSearch = !searchTerm.isEmpty
    let hasSince = since != nil
    let sinceValue = Date.UnixTimeRepresentation(queryOutput: since ?? .distantPast)
    let limitValue = max(1, limit)

    do {
      let rows = try database.read { db in
        try StoredLogEntry
          .where {
            (!hasMinPriority || $0.level >= minPriorityValue)
              && (!hasCategory || $0.category.eq(categoryValue))
              && (!hasSearch || $0.message.contains(searchTerm) || $0.category.contains(searchTerm))
              && (!hasSince || $0.date >= sinceValue)
          }
          .order { $0.date.desc() }
          .limit(limitValue)
          .fetchAll(db)
      }

      return rows.map { row in
        LogEntry(
          id: row.id,
          date: row.date,
          level: row.level,
          category: row.category,
          message: row.message
        )
      }
    } catch {
      print("Failed to query logs: \(error)")
      return []
    }
  }

  func categories() -> [String] {
    guard let database else { return [] }
    do {
      return try database.read { db in
        try StoredLogEntry
          .group(by: \.category)
          .order(by: \.category)
          .select { $0.category }
          .fetchAll(db)
      }
    } catch {
      print("Failed to query log categories: \(error)")
      return []
    }
  }

  func categoryCounts(minPriority: Int? = nil, since: Date? = nil) -> [String: Int] {
    guard let database else { return [:] }

    let hasMinPriority = minPriority != nil
    let minPriorityValue = minPriority ?? 0
    let hasSince = since != nil
    let sinceValue = Date.UnixTimeRepresentation(queryOutput: since ?? .distantPast)

    do {
      let rows = try database.read { db in
        try StoredLogEntry
          .where {
            (!hasMinPriority || $0.level >= minPriorityValue)
              && (!hasSince || $0.date >= sinceValue)
          }
          .group(by: \.category)
          .order(by: \.category)
          .select {
            LogCategoryCountRow.Columns(
              category: $0.category,
              count: $0.count()
            )
          }
          .fetchAll(db)
      }

      var counts: [String: Int] = [:]
      counts.reserveCapacity(rows.count)
      for row in rows {
        counts[row.category] = row.count
      }
      return counts
    } catch {
      print("Failed to query log category counts: \(error)")
      return [:]
    }
  }

  func cleanup(keepDays: Int = 7) {
    guard let database else { return }
    let cutoff = Date().addingTimeInterval(-Double(keepDays * 24 * 60 * 60))
    let cutoffValue = Date.UnixTimeRepresentation(queryOutput: cutoff)
    do {
      let removedCount = try database.write { db in
        let toDelete =
          try StoredLogEntry
          .where { $0.date < cutoffValue }
          .fetchCount(db)
        if toDelete > 0 {
          print("LogStore cleanup removing \(toDelete) rows older than \(cutoff)")
        }
        try StoredLogEntry
          .where { $0.date < cutoffValue }
          .delete()
          .execute(db)
        return toDelete
      }
      if removedCount == 0 {
        print("LogStore cleanup removed 0 rows")
      }
    } catch {
      print("Failed to cleanup logs: \(error)")
    }
  }

  func clear() {
    guard let database else { return }
    do {
      try database.write { db in
        try StoredLogEntry.delete().execute(db)
      }
    } catch {
      print("Failed to clear logs: \(error)")
    }
  }
}
