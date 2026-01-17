//
//  MainSplitView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(iOS) || os(macOS)
  struct MainSplitView: View {
    @State private var nav: NavDestination? = .home
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
        NavigationStack {
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
    }
  }
#endif
