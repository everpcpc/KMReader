//
// PhoneTabView.swift
//
//

import SwiftUI

#if os(iOS)
  @available(iOS 18.0, *)
  struct PhoneTabView: View {
    let context: AppViewContext
    @State private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedTab: TabItem = .home
    @State private var homePath = NavigationPath()

    var body: some View {
      TabView(selection: $selectedTab) {
        Tab(TabItem.home.title, systemImage: TabItem.home.icon, value: TabItem.home) {
          NavigationStack(path: $homePath) {
            rootContent(for: .home)
          }
        }

        Tab(TabItem.browse.title, systemImage: TabItem.browse.icon, value: TabItem.browse) {
          NavigationStack {
            rootContent(for: .browse)
          }
        }

        Tab(TabItem.offline.title, systemImage: TabItem.offline.icon, value: TabItem.offline) {
          NavigationStack {
            rootContent(for: .offline)
          }
        }

        Tab(TabItem.server.title, systemImage: TabItem.server.icon, value: TabItem.server) {
          NavigationStack {
            rootContent(for: .server)
          }
        }

        Tab(
          TabItem.settings.title, systemImage: TabItem.settings.icon, value: TabItem.settings,
          role: .search
        ) {
          NavigationStack {
            rootContent(for: .settings)
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
#endif
