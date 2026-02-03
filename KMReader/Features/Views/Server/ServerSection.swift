//
//  ServerSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum ServerSection: String, CaseIterable {

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
