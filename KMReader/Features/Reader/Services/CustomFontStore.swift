//
// CustomFontStore.swift
//
//

import Foundation
import GRDB

#if os(iOS)
  import CoreText
#endif

@MainActor
final class CustomFontStore {
  static let shared = CustomFontStore()

  private var dbQueue: DatabaseQueue?

  private init() {}

  func configure(with dbQueue: DatabaseQueue) {
    self.dbQueue = dbQueue
  }

  func fetchCustomFonts() -> [String] {
    guard let dbQueue else { return [] }
    return (try? dbQueue.read { db in
      try CustomFont.fetchAll(db).sorted { $0.name < $1.name }.map(\.name)
    }) ?? []
  }

  func customFontCount() -> Int {
    guard let dbQueue else { return 0 }
    return (try? dbQueue.read { db in
      try CustomFont.fetchCount(db)
    }) ?? 0
  }

  func getFontPath(for fontName: String) -> String? {
    guard let dbQueue,
      let relativePath = try? dbQueue.read({ db in
        try CustomFont.fetchOne(db, key: fontName)?.path
      })
    else {
      return nil
    }

    // Resolve relative path to absolute path using FontFileManager
    return FontFileManager.resolvePath(relativePath)
  }
}
