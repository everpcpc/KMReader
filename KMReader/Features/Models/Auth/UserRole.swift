//
//  UserRole.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum UserRole: String, Codable, CaseIterable {
  case admin = "ADMIN"
  case fileDownload = "FILE_DOWNLOAD"
  case pageStreaming = "PAGE_STREAMING"
  case koboSync = "KOBO_SYNC"
  case koreaderSync = "KOREADER_SYNC"

  var displayName: String {
    switch self {
    case .admin:
      return String(localized: "user.role.admin")
    case .fileDownload:
      return String(localized: "user.role.fileDownload")
    case .pageStreaming:
      return String(localized: "user.role.pageStreaming")
    case .koboSync:
      return String(localized: "user.role.koboSync")
    case .koreaderSync:
      return String(localized: "user.role.koreaderSync")
    }
  }

  var icon: String {
    switch self {
    case .admin:
      return "shield"
    case .fileDownload:
      return "arrow.down.circle"
    case .pageStreaming:
      return "play.circle"
    case .koboSync:
      return "arrow.2.circlepath"
    case .koreaderSync:
      return "arrow.triangle.2.circlepath"
    }
  }
}
