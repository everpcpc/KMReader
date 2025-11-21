//
//  View+Navigation.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
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

        case .settingsLibraries:
          SettingsLibrariesView()
        case .settingsAppearance:
          SettingsAppearanceView()
        case .settingsCache:
          SettingsCacheView()
        case .settingsReader:
          SettingsReaderView()
        case .settingsServerInfo:
          SettingsServerInfoView()
        case .settingsAuthenticationActivity:
          AuthenticationActivityView()
        }
      }
  }
}
