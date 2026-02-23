//
// ReadingStatsCacheStore.swift
//
//

import Foundation

@MainActor
@Observable
final class ReadingStatsCacheStore {
  static let shared = ReadingStatsCacheStore()

  private(set) var cache: ReadingStatsCache

  init(cache: ReadingStatsCache) {
    self.cache = cache
  }

  convenience init() {
    self.init(cache: AppConfig.readingStatsCache)
  }

  func snapshot(instanceId: String, libraryId: String) -> ReadingStatsSnapshot? {
    cache.snapshot(instanceId: instanceId, libraryId: libraryId)
  }

  func upsert(snapshot: ReadingStatsSnapshot, instanceId: String, libraryId: String) {
    var updated = cache
    updated.upsert(snapshot: snapshot, instanceId: instanceId, libraryId: libraryId)
    cache = updated
    AppConfig.readingStatsCache = updated
  }

  func clear(instanceId: String) {
    var updated = cache
    updated.clear(instanceId: instanceId)
    cache = updated
    AppConfig.readingStatsCache = updated
  }

  func reset() {
    cache = ReadingStatsCache()
    AppConfig.readingStatsCache = cache
  }
}
