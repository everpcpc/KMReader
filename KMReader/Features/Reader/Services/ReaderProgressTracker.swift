//
//  ReaderProgressTracker.swift
//  KMReader
//

import Foundation

actor ReaderProgressTracker {
  static let shared = ReaderProgressTracker()

  private var inFlightUpdates: [String: Int] = [:]

  func begin(bookId: String) {
    inFlightUpdates[bookId, default: 0] += 1
  }

  func end(bookId: String) {
    guard let count = inFlightUpdates[bookId] else { return }
    if count <= 1 {
      inFlightUpdates.removeValue(forKey: bookId)
    } else {
      inFlightUpdates[bookId] = count - 1
    }
  }

  func waitUntilIdle(bookIds: Set<String>, timeout: Duration = .seconds(2)) async -> Bool {
    guard !bookIds.isEmpty else { return true }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while hasInFlightUpdates(for: bookIds) {
      guard clock.now < deadline else { return false }
      try? await Task.sleep(for: .milliseconds(50))
    }

    return true
  }

  private func hasInFlightUpdates(for bookIds: Set<String>) -> Bool {
    for bookId in bookIds where (inFlightUpdates[bookId] ?? 0) > 0 {
      return true
    }
    return false
  }
}
