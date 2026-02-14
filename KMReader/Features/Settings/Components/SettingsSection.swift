//
//  SettingsSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum SettingsSection: String, CaseIterable {
  case appearance
  case browse
  case dashboard
  case cache
  case divinaReader
  #if os(iOS) || os(macOS)
    case pdfReader
  #endif
  #if os(iOS)
    case epubReader
  #endif
  case sse
  #if !os(tvOS)
    case spotlight
  #endif
  case network
  case logs

  var icon: String {
    switch self {
    case .appearance:
      return "paintbrush"
    case .browse:
      return "square.grid.2x2"
    case .dashboard:
      return "house"
    case .cache:
      return "externaldrive"
    case .divinaReader:
      return "book.pages"
    #if os(iOS) || os(macOS)
      case .pdfReader:
        return "doc.richtext"
    #endif
    #if os(iOS)
      case .epubReader:
        return "character.book.closed"
    #endif
    case .sse:
      return "antenna.radiowaves.left.and.right"
    #if !os(tvOS)
      case .spotlight:
        return "magnifyingglass.circle"
    #endif
    case .network:
      return "network"
    case .logs:
      return "doc.text.magnifyingglass"
    }
  }

  var title: String {
    switch self {
    case .appearance:
      return String(localized: "Appearance")
    case .browse:
      return String(localized: "Browse")
    case .dashboard:
      return String(localized: "Dashboard")
    case .cache:
      return String(localized: "Cache")
    case .divinaReader:
      return String(localized: "DIVINA Reader")
    #if os(iOS) || os(macOS)
      case .pdfReader:
        return String(localized: "PDF Reader")
    #endif
    #if os(iOS)
      case .epubReader:
        return String(localized: "EPUB Reader")
    #endif
    case .sse:
      return String(localized: "Real-time Updates")
    #if !os(tvOS)
      case .spotlight:
        return String(localized: "Spotlight")
    #endif
    case .network:
      return String(localized: "Network")
    case .logs:
      return String(localized: "Logs")
    }
  }
}
