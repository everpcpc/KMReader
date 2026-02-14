//
//  MainSplitView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(iOS) || os(macOS)
  struct MainSplitView: View {
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var nav: NavDestination? = .home
    @State private var detailPath = NavigationPath()
    #if os(macOS)
      @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #else
      @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    #endif

    var librarySelection: LibrarySelection? {
      guard let nav else { return nil }
      switch nav {
      case .browseLibrary(let library):
        return library
      default:
        return nil
      }
    }

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        SidebarView(selection: $nav)
      } detail: {
        NavigationStack(path: $detailPath) {
          if let nav {
            nav.content
              .handleNavigation()
              .environment(\.browseLibrarySelection, librarySelection)
          } else {
            ContentUnavailableView {
              Label(String(localized: "Select a Category"), systemImage: "sidebar.left")
            } description: {
              Text(String(localized: "Pick something from the sidebar to get started."))
            }
          }
        }
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
        nav = .home
        detailPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          detailPath.append(NavDestination.bookDetail(bookId: bookId))
        }
      case .series(let seriesId):
        nav = .home
        detailPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          detailPath.append(NavDestination.seriesDetail(seriesId: seriesId))
        }
      case .search:
        nav = .browseSeries
      case .downloads:
        nav = .offline
      }
    }
  }
#endif
