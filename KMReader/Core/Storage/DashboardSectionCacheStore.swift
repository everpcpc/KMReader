//
//  DashboardSectionCacheStore.swift
//  KMReader
//

import Foundation

@MainActor
@Observable
final class DashboardSectionCacheStore {
  static let shared = DashboardSectionCacheStore()

  private(set) var cache: DashboardSectionCache

  init(cache: DashboardSectionCache) {
    self.cache = cache
  }

  convenience init() {
    self.init(cache: AppConfig.dashboardSectionCache)
  }

  func ids(for section: DashboardSection) -> [String] {
    cache.ids(for: section)
  }

  @discardableResult
  func updateIfChanged(section: DashboardSection, ids: [String]) -> Bool {
    var updated = cache
    let changed = updated.updateIfChanged(section: section, ids: ids)
    guard changed else { return false }
    cache = updated
    AppConfig.dashboardSectionCache = updated
    return true
  }

  func reset() {
    cache = DashboardSectionCache()
    AppConfig.dashboardSectionCache = cache
  }
}
