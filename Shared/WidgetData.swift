//
//  WidgetData.swift
//  KMReader
//
//  Shared data model for widget communication via App Groups.
//

import Foundation

struct WidgetBookEntry: Codable, Sendable {
  let id: String
  let seriesId: String
  let title: String
  let seriesTitle: String
  let number: Double
  let progressPage: Int?
  let totalPages: Int
  let progressCompleted: Bool
  let thumbnailFileName: String?
  let createdDate: Date
}

enum WidgetDataStore: Sendable {
  static nonisolated let suiteName = "group.com.everpcpc.Komga"
  static nonisolated let keepReadingKey = "widget.keepReading"
  static nonisolated let recentlyAddedKey = "widget.recentlyAdded"
  private static nonisolated let thumbnailDirectoryName = "WidgetThumbnails"

  static nonisolated var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  static nonisolated var sharedContainerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
  }

  static nonisolated var thumbnailDirectory: URL? {
    sharedContainerURL?.appendingPathComponent(thumbnailDirectoryName, isDirectory: true)
  }

  static nonisolated func saveEntries(_ entries: [WidgetBookEntry], forKey key: String) {
    guard let defaults = sharedDefaults else { return }
    guard let data = try? JSONEncoder().encode(entries) else { return }
    defaults.set(data, forKey: key)
  }

  static nonisolated func loadEntries(forKey key: String) -> [WidgetBookEntry] {
    guard let defaults = sharedDefaults,
      let data = defaults.data(forKey: key),
      let entries = try? JSONDecoder().decode([WidgetBookEntry].self, from: data)
    else { return [] }
    return entries
  }

  static nonisolated func thumbnailURL(for entry: WidgetBookEntry) -> URL? {
    guard let fileName = entry.thumbnailFileName else { return nil }
    return thumbnailDirectory?.appendingPathComponent(fileName)
  }

  static nonisolated func clearAll() {
    sharedDefaults?.removeObject(forKey: keepReadingKey)
    sharedDefaults?.removeObject(forKey: recentlyAddedKey)
    if let dir = thumbnailDirectory {
      try? FileManager.default.removeItem(at: dir)
    }
  }

  static nonisolated func bookDeepLinkURL(bookId: String) -> URL {
    URL(string: "kmreader://book/\(bookId)")!
  }
}
