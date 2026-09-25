//
// SidebarView.swift
//
//

import SwiftUI

struct SidebarView: View {
  @Binding var selection: NavDestination?

  @Environment(\.colorScheme) private var colorScheme

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  @AppStorage("sidebarBrowseExpanded") private var browseExpanded: Bool = true
  @AppStorage("sidebarLibrariesExpanded") private var librariesExpanded: Bool = true
  @AppStorage("sidebarCollectionsExpanded") private var collectionsExpanded: Bool = false
  @AppStorage("sidebarReadListsExpanded") private var readListsExpanded: Bool = false

  @State private var isRefreshing: Bool = false
  @State private var libraries: [SidebarLibraryItem] = []
  @State private var collections: [SidebarCollectionItem] = []
  @State private var readLists: [SidebarReadListItem] = []

  private var showsSettingsLink: Bool {
    #if os(iOS)
      return true
    #else
      return false
    #endif
  }

  private var browseExpandedBinding: Binding<Bool> {
    Binding(
      get: { browseExpanded },
      set: { setBrowseExpanded($0) }
    )
  }

  private var librariesExpandedBinding: Binding<Bool> {
    Binding(
      get: { librariesExpanded },
      set: { setLibrariesExpanded($0) }
    )
  }

  private var collectionsExpandedBinding: Binding<Bool> {
    Binding(
      get: { collectionsExpanded },
      set: { setCollectionsExpanded($0) }
    )
  }

  private var readListsExpandedBinding: Binding<Bool> {
    Binding(
      get: { readListsExpanded },
      set: { setReadListsExpanded($0) }
    )
  }

  private func refreshSidebar() async {
    guard !current.instanceId.isEmpty, !isRefreshing else { return }
    withAnimation {
      isRefreshing = true
    }
    ErrorManager.shared.notify(message: String(localized: "notification.refreshing"))
    defer {
      withAnimation {
        isRefreshing = false
      }
      ErrorManager.shared.notify(message: String(localized: "notification.refresh_completed"))
    }
    await SyncService.syncLibraries(instanceId: current.instanceId)
    await SyncService.syncCollections(instanceId: current.instanceId)
    await SyncService.syncReadLists(instanceId: current.instanceId)
    await loadSidebarItems(instanceId: current.instanceId)
  }

  private func loadSidebarItems(instanceId: String) async {
    guard !instanceId.isEmpty else {
      clearSidebarItemsIfNeeded()
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      let loadedLibraries = try await database.fetchSidebarLibraries(instanceId: instanceId)
      let loadedCollections = try await database.fetchSidebarCollections(instanceId: instanceId)
      let loadedReadLists = try await database.fetchSidebarReadLists(instanceId: instanceId)

      applySidebarItems(
        libraries: loadedLibraries,
        collections: loadedCollections,
        readLists: loadedReadLists
      )
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func clearSidebarItemsIfNeeded() {
    guard !libraries.isEmpty || !collections.isEmpty || !readLists.isEmpty else { return }

    withAnimation {
      libraries = []
      collections = []
      readLists = []
    }
  }

  private func applySidebarItems(
    libraries loadedLibraries: [SidebarLibraryItem],
    collections loadedCollections: [SidebarCollectionItem],
    readLists loadedReadLists: [SidebarReadListItem]
  ) {
    guard
      libraries != loadedLibraries || collections != loadedCollections
        || readLists != loadedReadLists
    else { return }

    withAnimation {
      if libraries != loadedLibraries { libraries = loadedLibraries }
      if collections != loadedCollections { collections = loadedCollections }
      if readLists != loadedReadLists { readLists = loadedReadLists }
    }
  }

  private func setBrowseExpanded(_ isExpanded: Bool) {
    guard browseExpanded != isExpanded else { return }
    withAnimation {
      browseExpanded = isExpanded
    }
  }

  private func setLibrariesExpanded(_ isExpanded: Bool) {
    guard librariesExpanded != isExpanded else { return }
    withAnimation {
      librariesExpanded = isExpanded
    }
  }

  private func setCollectionsExpanded(_ isExpanded: Bool) {
    guard collectionsExpanded != isExpanded else { return }
    withAnimation {
      collectionsExpanded = isExpanded
    }
  }

  private func setReadListsExpanded(_ isExpanded: Bool) {
    guard readListsExpanded != isExpanded else { return }
    withAnimation {
      readListsExpanded = isExpanded
    }
  }

  var body: some View {
    Group {
      List(selection: $selection) {
        listContent
      }
    }
    // macOS needs the sidebar style too: the default list style paints the
    // selection with the accent color, which is unreadable against the
    // monochrome (near-black/near-white) accent.
    #if os(iOS) || os(macOS)
      .listStyle(.sidebar)
    #endif
    #if os(iOS)
      .refreshable {
        await refreshSidebar()
      }
    #endif
    .task(id: current.instanceId) {
      await loadSidebarItems(instanceId: current.instanceId)
    }
    .onReceive(NotificationCenter.default.publisher(for: .sidebarProjectionDidChange)) {
      notification in
      guard notification.userInfo?["instanceId"] as? String == current.instanceId else { return }
      Task {
        await loadSidebarItems(instanceId: current.instanceId)
      }
    }
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

  /// The sidebar selection pill is painted with the accent color while the
  /// system renders selected rows in white, which is unreadable on the
  /// near-white dark-mode accent; selected rows flip to dark content there.
  @ViewBuilder
  private func sidebarRowContent<Content: View>(
    for destination: NavDestination,
    @ViewBuilder content: () -> Content
  ) -> some View {
    if selection == destination, colorScheme == .dark {
      content().foregroundStyle(.black)
    } else {
      content()
    }
  }

  @ViewBuilder
  private var listContent: some View {
    Section {
      NavigationLink(value: NavDestination.home) {
        sidebarRowContent(for: .home) {
          Label(String(localized: "tab.home"), systemImage: "house")
        }
      }
      NavigationLink(value: NavDestination.offline) {
        sidebarRowContent(for: .offline) {
          Label(TabItem.offline.title, systemImage: TabItem.offline.icon)
        }
      }
      NavigationLink(value: NavDestination.server) {
        sidebarRowContent(for: .server) {
          Label(TabItem.server.title, systemImage: TabItem.server.icon)
        }
      }
    }

    Section(isExpanded: browseExpandedBinding) {
      NavigationLink(value: NavDestination.browseSeries) {
        sidebarRowContent(for: .browseSeries) {
          Label(String(localized: "tab.series"), systemImage: ContentIcon.series)
        }
      }
      NavigationLink(value: NavDestination.browseBooks) {
        sidebarRowContent(for: .browseBooks) {
          Label(String(localized: "tab.books"), systemImage: ContentIcon.book)
        }
      }
      NavigationLink(value: NavDestination.browseCollections) {
        sidebarRowContent(for: .browseCollections) {
          Label(String(localized: "tab.collections"), systemImage: ContentIcon.collection)
        }
      }
      NavigationLink(value: NavDestination.browseReadLists) {
        sidebarRowContent(for: .browseReadLists) {
          Label(String(localized: "tab.readLists"), systemImage: ContentIcon.readList)
        }
      }
    } header: {
      Label(String(localized: "Browse"), systemImage: ContentIcon.browse)
    }

    if !libraries.isEmpty {
      Section(isExpanded: librariesExpandedBinding) {
        ForEach(libraries) { library in
          let destination = NavDestination.browseLibrary(
            selection: LibrarySelection(sidebarItem: library))
          NavigationLink(value: destination) {
            sidebarRowContent(for: destination) {
              SidebarItemLabel(
                title: library.name,
                count: library.displayBookCount
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
        }
      } header: {
        Label(String(localized: "Libraries"), systemImage: ContentIcon.library)
      }
    }

    if !collections.isEmpty {
      Section(isExpanded: collectionsExpandedBinding) {
        ForEach(collections) { collection in
          let destination = NavDestination.collectionDetail(collectionId: collection.collectionId)
          NavigationLink(value: destination) {
            sidebarRowContent(for: destination) {
              SidebarItemLabel(
                title: collection.name,
                count: collection.seriesCount
              )
            }
          }
        }
      } header: {
        Label(String(localized: "Collections"), systemImage: ContentIcon.collection)
      }
    }

    if !readLists.isEmpty {
      Section(isExpanded: readListsExpandedBinding) {
        ForEach(readLists) { readList in
          let destination = NavDestination.readListDetail(readListId: readList.readListId)
          NavigationLink(value: destination) {
            sidebarRowContent(for: destination) {
              SidebarItemLabel(
                title: readList.name,
                count: readList.bookCount
              )
            }
          }
        }
      } header: {
        Label(String(localized: "Read Lists"), systemImage: ContentIcon.readList)
      }
    }

    if showsSettingsLink {
      Section {
        NavigationLink(value: NavDestination.settings) {
          sidebarRowContent(for: .settings) {
            TabItem.settings.label
          }
        }
      }
    }
  }
}
