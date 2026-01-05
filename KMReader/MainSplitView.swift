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
    @AppStorage("sidebarCollectionsExpanded") private var collectionsExpanded: Bool = false
    @AppStorage("sidebarReadListsExpanded") private var readListsExpanded: Bool = false

    @State private var nav: NavDestination? = .home
    @State private var isRefreshing: Bool = false
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

    private func refreshSidebar() async {
      guard !currentInstanceId.isEmpty, !isRefreshing else { return }
      isRefreshing = true
      ErrorManager.shared.notify(message: String(localized: "notification.refreshing"))
      defer {
        isRefreshing = false
        ErrorManager.shared.notify(message: String(localized: "notification.refresh_completed"))
      }
      await SyncService.shared.syncLibraries(instanceId: currentInstanceId)
      await SyncService.shared.syncCollections(instanceId: currentInstanceId)
      await SyncService.shared.syncReadLists(instanceId: currentInstanceId)
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
            }
          }

          #if os(iOS)
            NavigationLink(value: NavDestination.settings) {
              TabItem.settings.label
            }
          #endif
        }
        .listStyle(.sidebar)
        .animation(.default, value: nav)
        .animation(.default, value: libraries)
        .animation(.default, value: collections)
        .animation(.default, value: readLists)
        .animation(.default, value: librariesExpanded)
        .animation(.default, value: collectionsExpanded)
        .animation(.default, value: readListsExpanded)
        #if os(iOS)
          .refreshable {
            await refreshSidebar()
          }
        #endif
        #if os(macOS)
          .safeAreaInset(edge: .bottom) {
            Button {
              Task { await refreshSidebar() }
            } label: {
              HStack {
                if isRefreshing {
                  ProgressView().controlSize(.small)
                  Text(String(localized: "notification.refreshing"))
                } else {
                  Image(systemName: "arrow.clockwise")
                  Text(String(localized: "Refresh"))
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
            }
            .disabled(isRefreshing)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
          }
        #endif
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
