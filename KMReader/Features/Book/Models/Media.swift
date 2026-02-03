//
//  Media.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

nonisolated enum MediaProfile: String, Codable, Hashable, Sendable {
  case divina = "DIVINA"
  case pdf = "PDF"
  case epub = "EPUB"
  case unknown = ""
}

nonisolated enum MediaStatus: String, Codable, Hashable, Sendable {
  case ready = "READY"
  case unknown = "UNKNOWN"
  case error = "ERROR"
  case unsupported = "UNSUPPORTED"
  case outdated = "OUTDATED"

  var message: String {
    switch self {
    case .ready:
      return ""
    case .error:
      return String(localized: "Failed to load media")
    case .unsupported:
      return String(localized: "Media format is not supported")
    case .outdated:
      return String(localized: "Media is outdated")
    case .unknown:
      return String(localized: "Media status is unknown")
    }
  }

  var label: String {
    switch self {
    case .ready:
      return String(localized: "Ready")
    case .error:
      return String(localized: "Error")
    case .unsupported:
      return String(localized: "Unsupported")
    case .outdated:
      return String(localized: "Outdated")
    case .unknown:
      return String(localized: "Unknown")
    }
  }

  var icon: String {
    switch self {
    case .ready:
      return ""
    case .error:
      return "exclamationmark.triangle"
    case .unsupported:
      return "xmark.circle"
    case .outdated:
      return "clock.badge.exclamationmark"
    case .unknown:
      return "questionmark.circle"
    }
  }

  var color: Color {
    switch self {
    case .ready:
      return .blue
    case .error:
      return .red
    case .unsupported:
      return .orange
    case .outdated:
      return .yellow
    case .unknown:
      return .gray
    }
  }
}

nonisolated struct Media: Equatable, Hashable, Sendable {
  var statusRaw: String
  var mediaType: String
  var pagesCount: Int
  var comment: String?
  var mediaProfileRaw: String?
  var epubDivinaCompatible: Bool?
  var epubIsKepub: Bool?

  var status: MediaStatus {
    MediaStatus(rawValue: statusRaw) ?? .unknown
  }

  var mediaProfile: MediaProfile? {
    mediaProfileRaw.flatMap(MediaProfile.init)
  }

  init(
    status: MediaStatus,
    mediaType: String,
    pagesCount: Int,
    comment: String? = nil,
    mediaProfile: MediaProfile? = nil,
    epubDivinaCompatible: Bool? = nil,
    epubIsKepub: Bool? = nil
  ) {
    self.statusRaw = status.rawValue
    self.mediaType = mediaType
    self.pagesCount = pagesCount
    self.comment = comment
    self.mediaProfileRaw = mediaProfile?.rawValue
    self.epubDivinaCompatible = epubDivinaCompatible
    self.epubIsKepub = epubIsKepub
  }
}

extension Media: Codable {
  enum CodingKeys: String, CodingKey {
    case statusRaw = "status"
    case mediaType
    case pagesCount
    case comment
    case mediaProfileRaw = "mediaProfile"
    case epubDivinaCompatible
    case epubIsKepub
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    statusRaw = try container.decode(String.self, forKey: .statusRaw)
    mediaType = try container.decode(String.self, forKey: .mediaType)
    pagesCount = try container.decode(Int.self, forKey: .pagesCount)
    comment = try container.decodeIfPresent(String.self, forKey: .comment)
    mediaProfileRaw = try container.decodeIfPresent(String.self, forKey: .mediaProfileRaw)
    epubDivinaCompatible = try container.decodeIfPresent(Bool.self, forKey: .epubDivinaCompatible)
    epubIsKepub = try container.decodeIfPresent(Bool.self, forKey: .epubIsKepub)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(statusRaw, forKey: .statusRaw)
    try container.encode(mediaType, forKey: .mediaType)
    try container.encode(pagesCount, forKey: .pagesCount)
    try container.encodeIfPresent(comment, forKey: .comment)
    try container.encodeIfPresent(mediaProfileRaw, forKey: .mediaProfileRaw)
    try container.encodeIfPresent(epubDivinaCompatible, forKey: .epubDivinaCompatible)
    try container.encodeIfPresent(epubIsKepub, forKey: .epubIsKepub)
  }
}
