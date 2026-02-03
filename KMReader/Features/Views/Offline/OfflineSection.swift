//
//  OfflineSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum OfflineSection: String, CaseIterable {
  case tasks
  case books

  var icon: String {
    switch self {
    case .tasks:
      return "tray.and.arrow.down"
    case .books:
      return "tray.full"
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
