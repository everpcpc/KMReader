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
  #if os(iOS)
    case epubReader
  #endif
  case sse
  case logs
  case network

  case offlineTasks
  case offlineBooks

  case libraries
  case serverInfo
  case tasks
  case history

  case servers
  case account
  case apiKeys
  case authenticationActivity

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
    #if os(iOS)
      case .epubReader:
        return "character.book.closed"
    #endif
    case .sse:
      return "antenna.radiowaves.left.and.right"
    case .network:
      return "network"
    case .logs:
      return "doc.text.magnifyingglass"

    case .offlineTasks:
      return "tray.and.arrow.down"
    case .offlineBooks:
      return "tray.full"

    case .libraries:
      return ContentIcon.library
    case .serverInfo:
      return "server.rack"
    case .tasks:
      return "list.bullet.clipboard"
    case .history:
      return "clock.arrow.circlepath"

    case .servers:
      return "list.bullet.rectangle"
    case .account:
      return "person.crop.circle"
    case .apiKeys:
      return "key"
    case .authenticationActivity:
      return "clock"

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
      return String(localized: "Divina Reader")
    #if os(iOS)
      case .epubReader:
        return String(localized: "EPUB Reader")
    #endif
    case .sse:
      return String(localized: "Real-time Updates")
    case .network:
      return String(localized: "Network")
    case .logs:
      return String(localized: "Logs")

    case .offlineTasks:
      return String(localized: "Download Tasks")
    case .offlineBooks:
      return String(localized: "Downloaded Books")

    case .libraries:
      return String(localized: "Libraries")
    case .serverInfo:
      return String(localized: "Server Info")
    case .tasks:
      return String(localized: "Tasks")
    case .history:
      return String(localized: "History")

    case .servers:
      return String(localized: "Servers")
    case .account:
      return String(localized: "Account")
    case .apiKeys:
      return String(localized: "API Keys")
    case .authenticationActivity:
      return String(localized: "Authentication Activity")

    }
  }
}
