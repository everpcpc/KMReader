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
  case browseSeries
  case browseBooks
  case browseCollections
  case browseReadLists
  case settings

  case browseLibrary(selection: LibrarySelection)

  // Browse with metadata filter
  case browseSeriesWithPublisher(publisher: String)
  case browseSeriesWithAuthor(author: String)
  case browseSeriesWithGenre(genre: String)
  case browseSeriesWithTag(tag: String)
  case browseBooksWithAuthor(author: String)
  case browseBooksWithTag(tag: String)

  case seriesDetail(seriesId: String)
  case bookDetail(bookId: String)
  case oneshotDetail(seriesId: String)
  case collectionDetail(collectionId: String)
  case readListDetail(readListId: String)
  case dashboardSectionDetail(section: DashboardSection)

  case settingsAppearance
  case settingsBrowse
  case settingsDashboard
  case settingsCache
  case settingsDivinaReader
  #if os(iOS)
    case settingsEpubReader
  #endif
  case settingsSSE
  case settingsNetwork
  case settingsLogs

  case settingsOfflineTasks
  case settingsOfflineBooks

  case settingsLibraries
  case settingsServerInfo
  case settingsTasks
  case settingsHistory

  case settingsServers
  case settingsAccountDetails
  case settingsApiKey
  case settingsAuthenticationActivity

  @ViewBuilder
  var content: some View {
    switch self {
    case .home:
      DashboardView()
    case .browseSeries:
      BrowseView(fixedContent: .series)
    case .browseBooks:
      BrowseView(fixedContent: .books)
    case .browseCollections:
      BrowseView(fixedContent: .collections)
    case .browseReadLists:
      BrowseView(fixedContent: .readlists)
    case .settings:
      SettingsView()

    // NOTE: library selection passed via environment
    case .browseLibrary(_):
      BrowseView()

    case .browseSeriesWithPublisher(let publisher):
      BrowseView(fixedContent: .series, metadataFilter: MetadataFilterConfig.forPublisher(publisher))
    case .browseSeriesWithAuthor(let author):
      BrowseView(fixedContent: .series, metadataFilter: MetadataFilterConfig.forAuthors([author]))
    case .browseSeriesWithGenre(let genre):
      BrowseView(fixedContent: .series, metadataFilter: MetadataFilterConfig.forGenres([genre]))
    case .browseSeriesWithTag(let tag):
      BrowseView(fixedContent: .series, metadataFilter: MetadataFilterConfig.forTags([tag]))
    case .browseBooksWithAuthor(let author):
      BrowseView(fixedContent: .books, metadataFilter: MetadataFilterConfig.forAuthors([author]))
    case .browseBooksWithTag(let tag):
      BrowseView(fixedContent: .books, metadataFilter: MetadataFilterConfig.forTags([tag]))

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
    case .settingsBrowse:
      SettingsBrowseView()
    case .settingsDashboard:
      SettingsDashboardView()
    case .settingsCache:
      SettingsCacheView()
    case .settingsDivinaReader:
      DivinaPreferencesView()
    #if os(iOS)
      case .settingsEpubReader:
        EpubPreferencesView()
    #endif
    case .settingsSSE:
      SettingsSSEView()
    case .settingsNetwork:
      SettingsNetworkView()
    case .settingsLogs:
      SettingsLogsView()

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
    case .settingsHistory:
      SettingsHistoryView()

    case .settingsServers:
      ServersView()
    case .settingsAccountDetails:
      AccountDetailsView()
    case .settingsApiKey:
      SettingsApiKeyView()
    case .settingsAuthenticationActivity:
      AuthenticationActivityView()
    }
  }

  var zoomSourceID: String? {
    switch self {
    case .seriesDetail(let seriesId):
      return seriesId
    case .bookDetail(let bookId):
      return bookId
    case .oneshotDetail(let seriesId):
      return seriesId
    default:
      return nil
    }
  }
}
