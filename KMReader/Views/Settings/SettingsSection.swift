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
    }
  }

  var title: String {
    switch self {
    case .appearance:
      return "Appearance"
    case .dashboard:
      return "Dashboard"
    case .cache:
      return "Cache"
    case .reader:
      return "Reader"
    case .sse:
      return "Real-time Updates"
    case .libraries:
      return "Libraries"
    case .serverInfo:
      return "Server Info"
    case .metrics:
      return "Tasks"
    case .servers:
      return "Servers"
    case .apiKeys:
      return "API Keys"
    case .authenticationActivity:
      return "Authentication Activity"
    }
  }
}
