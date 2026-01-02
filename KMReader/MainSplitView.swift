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

    @Query(sort: [SortDescriptor(\KomgaCollection.name, order: .forward)]) private
      var allCollections: [KomgaCollection]

    @Query(sort: [SortDescriptor(\KomgaReadList.name, order: .forward)]) private var allReadLists:
      [KomgaReadList]

    @AppStorage("sidebarLibrariesExpanded") private var librariesExpanded: Bool = true
    @AppStorage("sidebarCollectionsExpanded") private var collectionsExpanded: Bool = true
    @AppStorage("sidebarReadListsExpanded") private var readListsExpanded: Bool = true

    @State private var nav: NavDestination? = .home
    #if os(macOS)
      @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #else
      @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    #endif

    private var libraries: [KomgaLibrary] {
      guard !currentInstanceId.isEmpty else { return [] }
      return allLibraries.filter {
        $0.instanceId == currentInstanceId && $0.libraryId != KomgaLibrary.allLibrariesId
      }
    }

    private var collections: [KomgaCollection] {
      guard !currentInstanceId.isEmpty else { return [] }
      return allCollections.filter { $0.instanceId == currentInstanceId }
    }

    private var readLists: [KomgaReadList] {
      guard !currentInstanceId.isEmpty else { return [] }
      return allReadLists.filter { $0.instanceId == currentInstanceId }
    }

    var body: some View {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        List(selection: $nav) {
          Section {
            NavigationLink(value: NavDestination.home) {
              TabItem.home.label
            }
            NavigationLink(value: NavDestination.browseSeries) {
              TabItem.series.label
            }
            NavigationLink(value: NavDestination.browseBooks) {
              TabItem.books.label
            }
          }

          if !libraries.isEmpty {
            Section(isExpanded: $librariesExpanded) {
              ForEach(libraries) { library in
                NavigationLink(
                  value: NavDestination.browseLibrary(selection: LibrarySelection(library: library))
                ) {
                  SidebarItemLabel(
                    title: library.name,
                    count: library.booksCount.map { Int($0) }
                  )
                }
              }
            } header: {
              Label(String(localized: "Libraries"), systemImage: "books.vertical")
                .foregroundStyle(.secondary)
            }
          }

          if !collections.isEmpty {
            Section(isExpanded: $collectionsExpanded) {
              ForEach(collections) { collection in
                NavigationLink(
                  value: NavDestination.collectionDetail(collectionId: collection.collectionId)
                ) {
                  SidebarItemLabel(
                    title: collection.name,
                    count: collection.seriesIds.count
                  )
                }
              }
            } header: {
              Label(String(localized: "Collections"), systemImage: "square.stack.3d.down.right")
                .foregroundStyle(.secondary)
            }
          }

          if !readLists.isEmpty {
            Section(isExpanded: $readListsExpanded) {
              ForEach(readLists) { readList in
                NavigationLink(
                  value: NavDestination.readListDetail(readListId: readList.readListId)
                ) {
                  SidebarItemLabel(
                    title: readList.name,
                    count: readList.bookIds.count
                  )
                }
              }
            } header: {
              Label(String(localized: "Read Lists"), systemImage: "list.bullet.rectangle")
                .foregroundStyle(.secondary)
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
