//
// SettingsSection.swift
//
//

import SwiftUI

enum SettingsSection: String, CaseIterable {
  case appearance
  case browse
  case dashboard
  case cache
  case divinaReader
  #if os(iOS) || os(macOS)
    case pdfReader
  #endif
  #if os(iOS) || os(macOS)
    case epubTheme
    case epubSettings
  #endif
  case sse
  case sync
  #if os(iOS) || os(macOS)
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
      return "photo.on.rectangle.angled"
    #if os(iOS) || os(macOS)
      case .pdfReader:
        return "doc.richtext"
    #endif
    #if os(iOS) || os(macOS)
      case .epubTheme:
        return "textformat.size"
      case .epubSettings:
        return "character.book.closed"
    #endif
    case .sse:
      return "antenna.radiowaves.left.and.right"
    case .sync:
      return "arrow.triangle.2.circlepath"
    #if os(iOS) || os(macOS)
      case .spotlight:
        return "magnifyingglass.circle"
    #endif
    case .network:
      return "network"
    case .logs:
      return "doc.text.magnifyingglass"
    }
  }

  var color: Color {
    switch self {
    case .appearance:
      return .blue
    case .browse:
      return .purple
    case .dashboard:
      return .orange
    case .cache:
      return .gray
    case .divinaReader:
      return .green
    #if os(iOS) || os(macOS)
      case .pdfReader:
        return .red
    #endif
    #if os(iOS) || os(macOS)
      case .epubTheme:
        return .indigo
      case .epubSettings:
        return .mint
    #endif
    case .sse:
      return .orange
    case .sync:
      return .blue
    #if os(iOS) || os(macOS)
      case .spotlight:
        return .gray
    #endif
    case .network:
      return .teal
    case .logs:
      return .brown
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
    #if os(iOS) || os(macOS)
      case .epubTheme:
        return String(localized: "EPUB Theme")
      case .epubSettings:
        return String(localized: "EPUB Settings")
    #endif
    case .sse:
      return String(localized: "Real-time Updates")
    case .sync:
      return String(localized: "Sync & Handoff")
    #if os(iOS) || os(macOS)
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
