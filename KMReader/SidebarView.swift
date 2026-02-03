//
//  SidebarView.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct SidebarView: View {
  @Binding var selection: NavDestination?

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries: [KomgaLibrary]
  @Query(sort: [SortDescriptor(\KomgaCollection.name, order: .forward)]) private
    var allCollections: [KomgaCollection]
  @Query(sort: [SortDescriptor(\KomgaReadList.name, order: .forward)]) private var allReadLists: [KomgaReadList]

  @AppStorage("sidebarBrowseExpanded") private var browseExpanded: Bool = true
  @AppStorage("sidebarLibrariesExpanded") private var librariesExpanded: Bool = true
  @AppStorage("sidebarCollectionsExpanded") private var collectionsExpanded: Bool = false
  @AppStorage("sidebarReadListsExpanded") private var readListsExpanded: Bool = false

  @State private var isRefreshing: Bool = false

  private var showsSettingsLink: Bool {
    #if os(iOS)
      return true
    #else
      return false
    #endif
  }

  private var libraries: [KomgaLibrary] {
    guard !current.instanceId.isEmpty else { return [] }
    return allLibraries.filter {
      $0.instanceId == current.instanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var collections: [KomgaCollection] {
    guard !current.instanceId.isEmpty else { return [] }
    return allCollections.filter { $0.instanceId == current.instanceId }
  }

  private var readLists: [KomgaReadList] {
    guard !current.instanceId.isEmpty else { return [] }
    return allReadLists.filter { $0.instanceId == current.instanceId }
  }

  private func refreshSidebar() async {
    guard !current.instanceId.isEmpty, !isRefreshing else { return }
    isRefreshing = true
    ErrorManager.shared.notify(message: String(localized: "notification.refreshing"))
    defer {
      isRefreshing = false
      ErrorManager.shared.notify(message: String(localized: "notification.refresh_completed"))
    }
    await SyncService.shared.syncLibraries(instanceId: current.instanceId)
    await SyncService.shared.syncCollections(instanceId: current.instanceId)
    await SyncService.shared.syncReadLists(instanceId: current.instanceId)
  }

  var body: some View {
    Group {
      List(selection: $selection) {
        listContent
      }
    }
    #if os(iOS)
      .listStyle(.sidebar)
    #endif
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
  }

  @ViewBuilder
  private var listContent: some View {
    Section {
      NavigationLink(value: NavDestination.home) {
        Label(String(localized: "tab.home"), systemImage: "house")
      }
      NavigationLink(value: NavDestination.offline) {
        Label(TabItem.offline.title, systemImage: TabItem.offline.icon)
      }
      NavigationLink(value: NavDestination.server) {
        Label(TabItem.server.title, systemImage: TabItem.server.icon)
      }
    }

    Section(isExpanded: $browseExpanded) {
      NavigationLink(value: NavDestination.browseSeries) {
        Label(String(localized: "tab.series"), systemImage: ContentIcon.series)
      }
      NavigationLink(value: NavDestination.browseBooks) {
        Label(String(localized: "tab.books"), systemImage: ContentIcon.book)
      }
      NavigationLink(value: NavDestination.browseCollections) {
        Label(String(localized: "tab.collections"), systemImage: ContentIcon.collection)
      }
      NavigationLink(value: NavDestination.browseReadLists) {
        Label(String(localized: "tab.readLists"), systemImage: ContentIcon.readList)
      }
    } header: {
      Label(String(localized: "Browse"), systemImage: ContentIcon.browse)
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
            .contextMenu {
              if current.isAdmin && !isOffline {
                ForEach(LibraryAction.allCases, id: \.self) { action in
                  Button {
                    action.perform(for: library.libraryId)
                  } label: {
                    action.label
                  }
                }
              }
            }
          }
        }
      } header: {
        Label(String(localized: "Libraries"), systemImage: ContentIcon.library)
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
        Label(String(localized: "Collections"), systemImage: ContentIcon.collection)
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
        Label(String(localized: "Read Lists"), systemImage: ContentIcon.readList)
      }
    }

    if showsSettingsLink {
      Section {
        NavigationLink(value: NavDestination.settings) {
          TabItem.settings.label
        }
      }
    }
  }
}
