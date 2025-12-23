//
//  NavDestination.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum NavDestination: Hashable {
  case seriesDetail(seriesId: String)
  case bookDetail(bookId: String)
  case collectionDetail(collectionId: String)
  case readListDetail(readListId: String)

  case settingsAppearance
  case settingsDashboard
  case settingsCache
  case settingsReader
  case settingsSSE
  case settingsLogs

  case settingsOfflineTasks
  case settingsOfflineBooks

  case settingsLibraries
  case settingsServerInfo
  case settingsTasks

  case settingsServers
  case settingsApiKey
  case settingsAuthenticationActivity
}
