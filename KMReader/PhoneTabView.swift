//
//  PhoneTabView.swift
//  KMReader
//

import SwiftUI

#if os(iOS)
  @available(iOS 18.0, *)
  struct PhoneTabView: View {
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedTab: TabItem = .home
    @State private var homePath = NavigationPath()

    var body: some View {
      TabView(selection: $selectedTab) {
        Tab(TabItem.home.title, systemImage: TabItem.home.icon, value: TabItem.home) {
          NavigationStack(path: $homePath) {
            TabItem.home.content
              .handleNavigation()
          }
        }

        Tab(TabItem.browse.title, systemImage: TabItem.browse.icon, value: TabItem.browse) {
          NavigationStack {
            TabItem.browse.content
              .handleNavigation()
          }
        }

        Tab(TabItem.offline.title, systemImage: TabItem.offline.icon, value: TabItem.offline) {
          NavigationStack {
            TabItem.offline.content
              .handleNavigation()
          }
        }

        Tab(TabItem.server.title, systemImage: TabItem.server.icon, value: TabItem.server) {
          NavigationStack {
            TabItem.server.content
              .handleNavigation()
          }
        }

        Tab(
          TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings,
          role: .search
        ) {
          NavigationStack {
            TabItem.settings.content
              .handleNavigation()
          }
        }
      }
      .tabBarMinimizeBehaviorIfAvailable()
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
#endif
