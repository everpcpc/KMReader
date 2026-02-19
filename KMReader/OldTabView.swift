//
// OldTabView.swift
//
//

import SwiftUI

struct OldTabView: View {
  @Environment(DeepLinkRouter.self) private var deepLinkRouter
  @State private var selectedTab: TabItem = .home
  @State private var homePath = NavigationPath()

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack(path: $homePath) {
        TabItem.home.content
          .handleNavigation()
      }
      .tabItem { TabItem.home.label }
      .tag(TabItem.home)

      NavigationStack {
        TabItem.browse.content
          .handleNavigation()
      }
      .tabItem { TabItem.browse.label }
      .tag(TabItem.browse)

      NavigationStack {
        TabItem.offline.content
          .handleNavigation()
      }
      .tabItem { TabItem.offline.label }
      .tag(TabItem.offline)

      NavigationStack {
        TabItem.server.content
          .handleNavigation()
      }
      .tabItem { TabItem.server.label }
      .tag(TabItem.server)

      NavigationStack {
        TabItem.settings.content
          .handleNavigation()
      }
      .tabItem { TabItem.settings.label }
      .tag(TabItem.settings)
    }
    .onAppear {
      if let link = deepLinkRouter.pendingDeepLink {
        handleDeepLink(link)
      }
    }
    .onChange(of: deepLinkRouter.pendingDeepLink) { _, link in
      guard let link else { return }
      handleDeepLink(link)
    }
  }

  private func handleDeepLink(_ link: DeepLink) {
    deepLinkRouter.pendingDeepLink = nil
    switch link {
    case .book(let bookId):
      selectedTab = .home
      homePath = NavigationPath()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        homePath.append(NavDestination.bookDetail(bookId: bookId))
      }
    case .series(let seriesId):
      selectedTab = .home
      homePath = NavigationPath()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        homePath.append(NavDestination.seriesDetail(seriesId: seriesId))
      }
    case .search:
      selectedTab = .browse
    case .downloads:
      selectedTab = .offline
    }
  }
}
