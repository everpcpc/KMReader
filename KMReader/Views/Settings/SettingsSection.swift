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
  case libraries
  case serverInfo
  case metrics
  case servers
  case apiKeys
  case authenticationActivity
  case offlineTasks
  case offlineBooks

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
    case .libraries:
      return "books.vertical"
    case .serverInfo:
      return "server.rack"
    case .metrics:
      return "list.bullet.clipboard"
    case .servers:
      return "list.bullet.rectangle"
    case .apiKeys:
      return "key"
    case .authenticationActivity:
      return "clock"
    case .offlineTasks:
      return "square.and.arrow.down.badge.clock"
    case .offlineBooks:
      return "square.and.arrow.down.badge.checkmark"
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
    case .libraries:
      return String(localized: "Libraries")
    case .serverInfo:
      return String(localized: "Server Info")
    case .metrics:
      return String(localized: "Tasks")
    case .servers:
      return String(localized: "Servers")
    case .apiKeys:
      return String(localized: "API Keys")
    case .authenticationActivity:
      return String(localized: "Authentication Activity")
    case .offlineTasks:
      return String(localized: "Offline Tasks")
    case .offlineBooks:
      return String(localized: "Offline Books")
    }
  }
}
