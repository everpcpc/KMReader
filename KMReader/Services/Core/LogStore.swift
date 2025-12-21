//
//  LogStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SQLite3

actor LogStore {
  static let shared = LogStore()

  private var db: OpaquePointer?
  private let dbPath: URL

  private init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    )
    .first!
    let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    dbPath = logsDir.appendingPathComponent("logs.sqlite")

    // Open and setup database synchronously in init
    if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
      print("Failed to open log database")
    }

    // Migration: check if schema matches exactly, if not drop table to recreate it
    var checkStmt: OpaquePointer?
    let checkSql = "PRAGMA table_info(logs)"
    var columns: [String: String] = [:]
    if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
      while sqlite3_step(checkStmt) == SQLITE_ROW {
        if let name = sqlite3_column_text(checkStmt, 1),
          let type = sqlite3_column_text(checkStmt, 2)
        {
          columns[String(cString: name)] = String(cString: type).uppercased()
        }
      }
      sqlite3_finalize(checkStmt)
    }

    let expectedSchema = [
      "id": "INTEGER",
      "date": "REAL",
      "level": "INTEGER",
      "category": "TEXT",
      "message": "TEXT",
    ]
    if !columns.isEmpty && columns != expectedSchema {
      sqlite3_exec(db, "DROP TABLE IF EXISTS logs", nil, nil, nil)
    }

    let sql = """
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date REAL NOT NULL,
        level INTEGER NOT NULL,
        category TEXT NOT NULL,
        message TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_logs_date ON logs(date);
      CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);
      """
    sqlite3_exec(db, sql, nil, nil, nil)

    Task { await cleanup() }
  }

  func insert(date: Date, level: Int, category: String, message: String) {
    let sql = "INSERT INTO logs (date, level, category, message) VALUES (?, ?, ?, ?)"
    var stmt: OpaquePointer?

    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
      sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
      sqlite3_bind_int(stmt, 2, Int32(level))
      sqlite3_bind_text(stmt, 3, category, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      sqlite3_bind_text(stmt, 4, message, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      sqlite3_step(stmt)
    }
    sqlite3_finalize(stmt)
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
    var conditions: [String] = []
    var params: [Any] = []

    if let minPriority = minPriority {
      conditions.append("level >= ?")
      params.append(minPriority)
    }
    if let category = category, category != "All" {
      conditions.append("category = ?")
      params.append(category)
    }
    if let search = search, !search.isEmpty {
      conditions.append("(message LIKE ? OR category LIKE ?)")
      params.append("%\(search)%")
      params.append("%\(search)%")
    }
    if let since = since {
      conditions.append("date >= ?")
      params.append(since.timeIntervalSince1970)
    }

    let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
    let sql =
      "SELECT id, date, level, category, message FROM logs \(whereClause) ORDER BY date DESC LIMIT \(limit)"

    var stmt: OpaquePointer?
    var entries: [LogEntry] = []

    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
      var paramIndex: Int32 = 1
      for param in params {
        if let str = param as? String {
          sqlite3_bind_text(
            stmt, paramIndex, str, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if let double = param as? Double {
          sqlite3_bind_double(stmt, paramIndex, double)
        } else if let int = param as? Int {
          sqlite3_bind_int(stmt, paramIndex, Int32(int))
        }
        paramIndex += 1
      }

      while sqlite3_step(stmt) == SQLITE_ROW {
        let id = sqlite3_column_int64(stmt, 0)
        let date = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        let level = Int(sqlite3_column_int(stmt, 2))
        let category = String(cString: sqlite3_column_text(stmt, 3))
        let message = String(cString: sqlite3_column_text(stmt, 4))
        entries.append(
          LogEntry(id: id, date: date, level: level, category: category, message: message))
      }
    }
    sqlite3_finalize(stmt)
    return entries
  }

  func categories() -> [String] {
    let sql = "SELECT DISTINCT category FROM logs ORDER BY category"
    var stmt: OpaquePointer?
    var categories: [String] = []

    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
      while sqlite3_step(stmt) == SQLITE_ROW {
        categories.append(String(cString: sqlite3_column_text(stmt, 0)))
      }
    }
    sqlite3_finalize(stmt)
    return categories
  }

  func categoryCounts(minPriority: Int? = nil, since: Date? = nil) -> [String: Int] {
    var conditions: [String] = []
    var params: [Any] = []

    if let minPriority = minPriority {
      conditions.append("level >= ?")
      params.append(minPriority)
    }
    if let since = since {
      conditions.append("date >= ?")
      params.append(since.timeIntervalSince1970)
    }

    let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
    let sql = "SELECT category, COUNT(*) FROM logs \(whereClause) GROUP BY category"

    var stmt: OpaquePointer?
    var counts: [String: Int] = [:]

    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
      var paramIndex: Int32 = 1
      for param in params {
        if let str = param as? String {
          sqlite3_bind_text(
            stmt, paramIndex, str, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else if let double = param as? Double {
          sqlite3_bind_double(stmt, paramIndex, double)
        } else if let int = param as? Int {
          sqlite3_bind_int(stmt, paramIndex, Int32(int))
        }
        paramIndex += 1
      }

      while sqlite3_step(stmt) == SQLITE_ROW {
        let category = String(cString: sqlite3_column_text(stmt, 0))
        let count = Int(sqlite3_column_int(stmt, 1))
        counts[category] = count
      }
    }
    sqlite3_finalize(stmt)
    return counts
  }

  func cleanup(keepDays: Int = 7) {
    let cutoff = Date().addingTimeInterval(-Double(keepDays * 24 * 60 * 60))
    let sql = "DELETE FROM logs WHERE date < ?"
    var stmt: OpaquePointer?

    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
      sqlite3_bind_double(stmt, 1, cutoff.timeIntervalSince1970)
      sqlite3_step(stmt)
    }
    sqlite3_finalize(stmt)
  }

  func clear() {
    sqlite3_exec(db, "DELETE FROM logs", nil, nil, nil)
  }
}
