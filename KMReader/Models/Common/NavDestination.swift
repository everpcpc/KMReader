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

  case settingsLibraries
  case settingsAppearance
  case settingsCache
  case settingsReader
  case settingsDashboard
  case settingsSSE
  case settingsServerInfo
  case settingsMetrics
  case settingsAuthenticationActivity
  case settingsApiKey
  case settingsServers
  case settingsOfflineTasks
  case settingsOfflineBooks
}
