//
// CacheSizeActor.swift
//
//

import Foundation

/// Actor for thread-safe cache size and count management
actor CacheSizeActor {
  private struct Entry {
    var cachedSize: Int64?
    var cachedCount: Int?
    var isValid = false
    var cleanupInProgress = false
    var lastCleanupAt: Date?
  }

  private var entries: [String: Entry] = [:]

  func get(namespace: String = "__default__") -> (size: Int64?, count: Int?, isValid: Bool) {
    let entry = entry(for: namespace)
    return (entry.cachedSize, entry.cachedCount, entry.isValid)
  }

  func set(size: Int64, count: Int, namespace: String = "__default__") {
    updateEntry(for: namespace) { entry in
      entry.cachedSize = size
      entry.cachedCount = count
      entry.isValid = true
    }
  }

  func invalidate(namespace: String = "__default__") {
    updateEntry(for: namespace) { entry in
      entry.isValid = false
    }
  }

  func removeAll() {
    entries.removeAll()
  }

  func updateSize(delta: Int64, namespace: String = "__default__") {
    updateEntry(for: namespace) { entry in
      if entry.isValid, let currentSize = entry.cachedSize {
        entry.cachedSize = max(0, currentSize + delta)
      } else {
        entry.isValid = false
      }
    }
  }

  func updateCount(delta: Int, namespace: String = "__default__") {
    updateEntry(for: namespace) { entry in
      if entry.isValid, let currentCount = entry.cachedCount {
        entry.cachedCount = max(0, currentCount + delta)
      } else {
        entry.isValid = false
      }
    }
  }

  func tryBeginCleanup(
    minInterval: TimeInterval,
    force: Bool = false,
    now: Date = Date(),
    namespace: String = "__default__"
  ) -> Bool {
    var entry = entry(for: namespace)
    if entry.cleanupInProgress {
      return false
    }

    if !force, let lastCleanupAt = entry.lastCleanupAt,
      now.timeIntervalSince(lastCleanupAt) < minInterval
    {
      return false
    }

    entry.cleanupInProgress = true
    entries[namespace] = entry
    return true
  }

  func endCleanup(now: Date = Date(), namespace: String = "__default__") {
    updateEntry(for: namespace) { entry in
      entry.cleanupInProgress = false
      entry.lastCleanupAt = now
    }
  }

  private func entry(for namespace: String) -> Entry {
    entries[namespace] ?? Entry()
  }

  private func updateEntry(for namespace: String, _ update: (inout Entry) -> Void) {
    var entry = entry(for: namespace)
    update(&entry)
    entries[namespace] = entry
  }
}
