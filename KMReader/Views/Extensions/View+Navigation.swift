//
//  View+Navigation.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  /// Apply inline navigation bar title style on supported platforms.
  /// - On iOS: sets navigation title and uses `.navigationBarTitleDisplayMode(.inline)`
  /// - On macOS: sets navigation title only
  /// - On other platforms (tvOS, etc.): no-op (does not set title)
  func inlineNavigationBarTitle(_ title: String) -> some View {
    #if os(iOS)
      return self.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      return self.navigationTitle(title)
    #else
      return self
    #endif
  }

  func handleNavigation() -> some View {
    self
      .navigationDestination(for: NavDestination.self) { destination in
        switch destination {
        case .seriesDetail(let seriesId):
          SeriesDetailView(seriesId: seriesId)
        case .bookDetail(let bookId):
          BookDetailView(bookId: bookId)
        case .collectionDetail(let collectionId):
          CollectionDetailView(collectionId: collectionId)
        case .readListDetail(let readListId):
          ReadListDetailView(readListId: readListId)

        #if !os(macOS)
          case .settingsLibraries:
            SettingsLibrariesView()
          case .settingsAppearance:
            SettingsAppearanceView()
          case .settingsCache:
            SettingsCacheView()
          case .settingsReader:
            SettingsReaderView()
          case .settingsDashboard:
            SettingsDashboardView()
          case .settingsSSE:
            SettingsSSEView()
          case .settingsServerInfo:
            SettingsServerInfoView()
          case .settingsMetrics:
            SettingsTasksView()
          case .settingsApiKey:
            SettingsApiKeyView()
          case .settingsAuthenticationActivity:
            AuthenticationActivityView()
          case .settingsServers:
            SettingsServersView()
          case .settingsOfflineTasks:
            SettingsOfflineTasksView()
        #else
          case .settingsLibraries,
            .settingsAppearance,
            .settingsCache,
            .settingsReader,
            .settingsDashboard,
            .settingsSSE,
            .settingsServerInfo,
            .settingsMetrics,
            .settingsApiKey,
            .settingsAuthenticationActivity,
            .settingsServers,
            .settingsOfflineTasks:
            VStack(spacing: 16) {
              Image(systemName: "gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
              Text("Settings are available in the Settings window")
                .font(.headline)
              Text("Use ⌘, to open Settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        }
      }
  }
}
