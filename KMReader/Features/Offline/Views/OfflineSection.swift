//
// OfflineSection.swift
//
//

import Foundation

enum OfflineSection: String, CaseIterable {
  case tasks
  case books

  var icon: String {
    switch self {
    case .tasks:
      return "arrow.down.circle"
    case .books:
      return "books.vertical"
    }
  }

  var title: String {
    switch self {
    case .tasks:
      return String(localized: "Download Tasks")
    case .books:
      return String(localized: "Downloaded Books")
    }
  }
}
