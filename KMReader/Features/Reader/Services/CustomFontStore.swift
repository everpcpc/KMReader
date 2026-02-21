//
// CustomFontStore.swift
//
//

import Dependencies
import Foundation
import SQLiteData

@MainActor
final class CustomFontStore {
  static let shared = CustomFontStore()
  @Dependency(\.defaultDatabase) private var database
  private let logger = AppLogger(.reader)

  private init() {}

  func fetchCustomFonts() -> [String] {
    do {
      return try database.read { db in
        try CustomFontRecord
          .order(by: \.name)
          .select { $0.name }
          .fetchAll(db)
      }
    } catch {
      logger.error("Failed to fetch custom fonts: \(error.localizedDescription)")
      return []
    }
  }

  func customFontCount() -> Int {
    do {
      return try database.read { db in
        try CustomFontRecord.fetchCount(db)
      }
    } catch {
      logger.error("Failed to count custom fonts: \(error.localizedDescription)")
      return 0
    }
  }

  func getFontPath(for fontName: String) -> String? {
    let relativePath: String?
    do {
      relativePath = try database.read { db in
        try CustomFontRecord
          .where { $0.name.eq(fontName) }
          .fetchOne(db)?
          .path
      }
    } catch {
      logger.error("Failed to resolve custom font path for \(fontName): \(error.localizedDescription)")
      return nil
    }

    guard let relativePath else { return nil }

    return FontFileManager.resolvePath(relativePath)
  }
}
