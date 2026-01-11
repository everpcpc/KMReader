//
//  SettingsSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum SettingsSection: String, CaseIterable {
  case appearance
  case dashboard
  case cache
  case reader
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
    case .dashboard:
      return "house"
    case .cache:
      return "externaldrive"
    case .reader:
      return "book.pages"
    case .sse:
      return "antenna.radiowaves.left.and.right"
    case .logs:
      return "doc.text.magnifyingglass"
    case .network:
      return "network"

    case .offlineTasks:
      return "tray.and.arrow.down"
    case .offlineBooks:
      return "tray.full"

    case .libraries:
      return "books.vertical"
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
    case .dashboard:
      return String(localized: "Dashboard")
    case .cache:
      return String(localized: "Cache")
    case .reader:
      return String(localized: "Reader")
    case .sse:
      return String(localized: "Real-time Updates")
    case .logs:
      return String(localized: "Logs")
    case .network:
      return String(localized: "Network")

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
