//
// NavDestination.swift
//
//

import Foundation
import SwiftUI

enum NavDestination: Hashable {
  case home
  case browseSeries
  case browseBooks
  case browseCollections
  case browseReadLists
  case offline
  case server
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
  #if os(iOS) || os(macOS)
    case settingsPdfReader
  #endif
  #if os(iOS)
    case settingsEpubReader
  #endif
  case settingsSSE
  #if os(iOS) || os(macOS)
    case settingsSpotlight
  #endif
  case settingsNetwork
  case settingsLogs

  case settingsOfflineTasks
  case settingsOfflineBooks

  case settingsLibraries
  case settingsReadingStats
  case settingsServerInfo
  case settingsTasks
  case settingsHistory
  case settingsMedia
  case settingsMediaAnalysis
  case settingsMediaMissingPosters
  case settingsMediaDuplicateFiles
  case settingsMediaDuplicatePagesKnown
  case settingsMediaDuplicatePagesUnknown

  case settingsServers
  case settingsApiKey
  case settingsAuthenticationActivity

  @ViewBuilder
  func content(context: AppViewContext) -> some View {
    switch self {
    case .home:
      DashboardView(
        authViewModel: context.authViewModel,
        readerPresentation: context.readerPresentation
      )
    case .browseSeries:
      BrowseView(authViewModel: context.authViewModel, fixedContent: .series)
    case .browseBooks:
      BrowseView(authViewModel: context.authViewModel, fixedContent: .books)
    case .browseCollections:
      BrowseView(authViewModel: context.authViewModel, fixedContent: .collections)
    case .browseReadLists:
      BrowseView(authViewModel: context.authViewModel, fixedContent: .readlists)
    case .offline:
      OfflineView(authViewModel: context.authViewModel)
    case .server:
      ServerView(authViewModel: context.authViewModel)
    case .settings:
      SettingsView()

    // NOTE: library selection passed via environment
    case .browseLibrary(_):
      BrowseView(authViewModel: context.authViewModel)

    case .browseSeriesWithPublisher(let publisher):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .series,
        metadataFilter: MetadataFilterConfig.forPublisher(publisher)
      )
    case .browseSeriesWithAuthor(let author):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .series,
        metadataFilter: MetadataFilterConfig.forAuthors([author])
      )
    case .browseSeriesWithGenre(let genre):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .series,
        metadataFilter: MetadataFilterConfig.forGenres([genre])
      )
    case .browseSeriesWithTag(let tag):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .series,
        metadataFilter: MetadataFilterConfig.forTags([tag])
      )
    case .browseBooksWithAuthor(let author):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .books,
        metadataFilter: MetadataFilterConfig.forAuthors([author])
      )
    case .browseBooksWithTag(let tag):
      BrowseView(
        authViewModel: context.authViewModel,
        fixedContent: .books,
        metadataFilter: MetadataFilterConfig.forTags([tag])
      )

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
    #if os(iOS) || os(macOS)
      case .settingsPdfReader:
        PdfPreferencesView()
    #endif
    #if os(iOS)
      case .settingsEpubReader:
        EpubPreferencesView()
    #endif
    case .settingsSSE:
      SettingsSSEView()
    #if os(iOS) || os(macOS)
      case .settingsSpotlight:
        SettingsSpotlightView()
    #endif
    case .settingsNetwork:
      SettingsNetworkView()
    case .settingsLogs:
      SettingsLogsView()

    case .settingsOfflineTasks:
      OfflineTasksView()
    case .settingsOfflineBooks:
      OfflineBooksView()

    case .settingsLibraries:
      ServerLibrariesView()
    case .settingsReadingStats:
      ServerReadingStatsView()
    case .settingsServerInfo:
      ServerInfoView()
    case .settingsTasks:
      ServerTasksView()
    case .settingsHistory:
      ServerHistoryView()
    case .settingsMedia:
      MediaManagementView()
    case .settingsMediaAnalysis:
      MediaAnalysisView()
    case .settingsMediaMissingPosters:
      MissingPostersView()
    case .settingsMediaDuplicateFiles:
      DuplicateFilesView()
    case .settingsMediaDuplicatePagesKnown:
      DuplicatePagesKnownView()
    case .settingsMediaDuplicatePagesUnknown:
      DuplicatePagesUnknownView()

    case .settingsServers:
      ServerListView(authViewModel: context.authViewModel)
    case .settingsApiKey:
      ApiKeysView()
    case .settingsAuthenticationActivity:
      AccountActivityView()
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
