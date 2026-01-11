//
//  UserRole.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum UserRole: Hashable, Codable, RawRepresentable {
  case admin
  case fileDownload
  case pageStreaming
  case koboSync
  case koreaderSync
  case user
  case other(String)

  public init(rawValue: String) {
    switch rawValue {
    case "ADMIN": self = .admin
    case "FILE_DOWNLOAD": self = .fileDownload
    case "PAGE_STREAMING": self = .pageStreaming
    case "KOBO_SYNC": self = .koboSync
    case "KOREADER_SYNC": self = .koreaderSync
    case "USER": self = .user
    default: self = .other(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .admin: return "ADMIN"
    case .fileDownload: return "FILE_DOWNLOAD"
    case .pageStreaming: return "PAGE_STREAMING"
    case .koboSync: return "KOBO_SYNC"
    case .koreaderSync: return "KOREADER_SYNC"
    case .user: return "USER"
    case .other(let value): return value
    }
  }

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
    case .user:
      return String(localized: "user.role.user")
    case .other(let value):
      return value
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
    case .user:
      return "person"
    case .other:
      return "tag"
    }
  }
}
