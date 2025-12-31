//
//  NavDestination.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum NavDestination: Hashable {
  case home
  case browse
  case settings

  case browseLibrary(selection: LibrarySelection)

  case seriesDetail(seriesId: String)
  case bookDetail(bookId: String)
  case oneshotDetail(seriesId: String)
  case collectionDetail(collectionId: String)
  case readListDetail(readListId: String)
  case dashboardSectionDetail(section: DashboardSection)

  case settingsAppearance
  case settingsDashboard
  case settingsCache
  case settingsReader
  case settingsSSE
  case settingsLogs
  case settingsNetwork

  case settingsOfflineTasks
  case settingsOfflineBooks

  case settingsLibraries
  case settingsServerInfo
  case settingsTasks

  case settingsServers
  case settingsApiKey
  case settingsAuthenticationActivity

  @ViewBuilder
  var content: some View {
    switch self {
    case .home:
      DashboardView()
    case .browse:
      BrowseView()
    case .settings:
      SettingsView()

    case .browseLibrary(let selection):
      BrowseView(library: selection)

    case .seriesDetail(let seriesId):
      SeriesDetailView(seriesId: seriesId)
    case .bookDetail(let bookId):
      BookDetailView(bookId: bookId)
    case .oneshotDetail(let seriesId):
      OneshotDetailView(seriesId: seriesId)
    case .collectionDetail(let collectionId):
      CollectionDetailView(collectionId: collectionId)
    case .readListDetail(let readListId):
      ReadListDetailView(readListId: readListId)
    case .dashboardSectionDetail(let section):
      DashboardSectionDetailView(section: section)

    case .settingsAppearance:
      SettingsAppearanceView()
    case .settingsDashboard:
      SettingsDashboardView()
    case .settingsCache:
      SettingsCacheView()
    case .settingsReader:
      SettingsReaderView()
    case .settingsSSE:
      SettingsSSEView()
    case .settingsLogs:
      SettingsLogsView()
    case .settingsNetwork:
      SettingsNetworkView()

    case .settingsOfflineTasks:
      SettingsOfflineTasksView()
    case .settingsOfflineBooks:
      SettingsOfflineBooksView()

    case .settingsLibraries:
      SettingsLibrariesView()
    case .settingsServerInfo:
      SettingsServerInfoView()
    case .settingsTasks:
      SettingsTasksView()

    case .settingsServers:
      SettingsServersView()
    case .settingsApiKey:
      SettingsApiKeyView()
    case .settingsAuthenticationActivity:
      AuthenticationActivityView()
    }
  }
}
