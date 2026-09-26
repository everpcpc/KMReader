//
// ThumbnailTint.swift
//
//

import SwiftUI

/// View-side loader for a thumbnail's card tint: loads once per thumbnail.
/// Views forward `.thumbnailDidRefresh` notifications to `reloadIfMatches(_:)`
/// so cards pick up cover changes the same way `ThumbnailImage` does.
@Observable
@MainActor
final class ThumbnailTint {
  private(set) var color: Color?

  private var loadedKey: String?
  private var loadTask: Task<Void, Never>?

  func load(id: String, type: ThumbnailType) {
    let key = "\(type.rawValue)#\(id)"
    guard loadedKey != key else { return }
    loadedKey = key
    color = nil
    fetch(id: id, type: type, key: key, invalidate: false)
  }

  func reloadIfMatches(_ notification: Notification) {
    guard
      let key = loadedKey,
      let id = notification.userInfo?["id"] as? String,
      let typeRaw = notification.userInfo?["type"] as? String,
      let type = ThumbnailType(rawValue: typeRaw),
      key == "\(typeRaw)#\(id)"
    else { return }
    fetch(id: id, type: type, key: key, invalidate: true)
  }

  private func fetch(id: String, type: ThumbnailType, key: String, invalidate: Bool) {
    loadTask?.cancel()
    loadTask = Task {
      if invalidate {
        await ThumbnailTintColorCache.shared.invalidate(id: id, type: type)
      }
      let tint = await ThumbnailTintColorCache.shared.color(id: id, type: type)
      guard !Task.isCancelled, loadedKey == key else { return }
      color = tint
    }
  }
}
