//
// MainSplitView.swift
//
//

import SwiftUI

#if os(iOS) || os(macOS)
  struct MainSplitView: View {
    let context: AppViewContext
    @State private var deepLinkRouter = DeepLinkRouter.shared
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
            detailContent(for: nav)
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

    @ViewBuilder
    private func detailContent(for nav: NavDestination) -> some View {
      nav.content(context: context)
        .environment(\.browseLibrarySelection, librarySelection)
        .environment(\.readerActions, context.readerActions)
        .handleNavigation(context: context)
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
