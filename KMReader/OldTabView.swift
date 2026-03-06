//
// OldTabView.swift
//
//

import SwiftUI

struct OldTabView: View {
  let context: AppViewContext
  @State private var deepLinkRouter = DeepLinkRouter.shared
  @State private var selectedTab: TabItem = .home
  @State private var homePath = NavigationPath()

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack(path: $homePath) {
        rootContent(for: .home)
      }
      .tabItem { TabItem.home.label }
      .tag(TabItem.home)

      NavigationStack {
        rootContent(for: .browse)
      }
      .tabItem { TabItem.browse.label }
      .tag(TabItem.browse)

      NavigationStack {
        rootContent(for: .offline)
      }
      .tabItem { TabItem.offline.label }
      .tag(TabItem.offline)

      NavigationStack {
        rootContent(for: .server)
      }
      .tabItem { TabItem.server.label }
      .tag(TabItem.server)

      NavigationStack {
        rootContent(for: .settings)
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

  @ViewBuilder
  private func rootContent(for tab: TabItem) -> some View {
    tab.content(context: context)
      .environment(\.readerActions, context.readerActions)
      .handleNavigation(context: context)
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
