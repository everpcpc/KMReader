//
//  MainSplitView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

#if os(iOS) || os(macOS)
  struct MainSplitView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
      [KomgaLibrary]

    @State private var nav: NavDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private var libraries: [KomgaLibrary] {
      guard !currentInstanceId.isEmpty else { return [] }
      return allLibraries.filter {
        $0.instanceId == currentInstanceId && $0.libraryId != KomgaLibrary.allLibrariesId
      }
    }

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        List(selection: $nav) {
          Section {
            NavigationLink(value: NavDestination.home) {
              TabItem.home.label
            }
            NavigationLink(value: NavDestination.browse) {
              TabItem.browse.label
            }
          }

          if !libraries.isEmpty {
            Section(String(localized: "Libraries")) {
              ForEach(libraries) { library in
                NavigationLink(value: NavDestination.browseLibrary(selection: LibrarySelection(library: library))) {
                  SidebarLibraryLabel(library: library)
                }
              }
            }
          }

          #if os(iOS)
            Section(String(localized: "Settings")) {
              NavigationLink(value: NavDestination.settings) {
                TabItem.settings.label
              }
            }
          #endif
        }
        .listStyle(.sidebar)
      } detail: {
        if let nav {
          nav.content
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
#endif
