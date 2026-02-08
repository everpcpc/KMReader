//
//  OfflineView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct OfflineView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(\.browseLibrarySelection) private var librarySelection

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("seriesBrowseLayout") private var seriesBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("bookBrowseLayout") private var bookBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("offlineBrowseContent") private var offlineBrowseContent: BrowseContentType = .series
  @AppStorage("isOffline") private var isOffline: Bool = false

  @Query private var instances: [KomgaInstance]

  @State private var refreshTrigger = UUID()
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var showLibraryPicker = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false
  @State private var showSyncConfirmation = false

  private var instanceInitializer: InstanceInitializer {
    InstanceInitializer.shared
  }

  private var currentInstance: KomgaInstance? {
    guard let uuid = UUID(uuidString: current.instanceId) else { return nil }
    return instances.first { $0.id == uuid }
  }

  private var lastSyncTimeText: String {
    guard let instance = currentInstance else {
      return String(localized: "settings.sync_data.never")
    }
    let latestSync = max(instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
    if latestSync == Date(timeIntervalSince1970: 0) {
      return String(localized: "settings.sync_data.never")
    }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: latestSync, relativeTo: Date())
  }

  private var title: String {
    if let library = librarySelection {
      return library.name
    }
    return String(localized: "tab.offline")
  }

  private var resolvedLibraryIds: [String] {
    if let library = librarySelection {
      return [library.libraryId]
    }
    return dashboard.libraryIds
  }

  private var resolvedLibraryIdsKey: String {
    resolvedLibraryIds.joined(separator: ",")
  }

  private var resolvedOfflineContent: BrowseContentType {
    switch offlineBrowseContent {
    case .series, .books:
      return offlineBrowseContent
    case .collections, .readlists:
      return .series
    }
  }

  private var offlineContentBinding: Binding<BrowseContentType> {
    Binding(
      get: { resolvedOfflineContent },
      set: { newValue in
        offlineBrowseContent = newValue == .books ? .books : .series
      }
    )
  }

  private var layoutModeBinding: Binding<BrowseLayoutMode> {
    switch resolvedOfflineContent {
    case .books:
      return $bookBrowseLayout
    case .series, .collections, .readlists:
      return $seriesBrowseLayout
    }
  }

  private var savedFilterType: SavedFilterType {
    resolvedOfflineContent == .books ? .books : .series
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if let library = librarySelection {
          VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: ContentIcon.library)
              Text(library.name)
                .font(.title2)
              if let fileSize = library.fileSize {
                Text(fileSize.humanReadableFileSize)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              Spacer()
            }
          }
          .padding()
        }

        VStack(spacing: 12) {
          syncCard
          downloadShortcuts
        }
        .padding(.horizontal)
        .padding(.top, librarySelection == nil ? 12 : 0)
        .padding(.bottom, 12)

        HStack {
          Spacer()
          Picker("", selection: offlineContentBinding) {
            Text(String(localized: "browse.content.series")).tag(BrowseContentType.series)
            Text(String(localized: "browse.content.books")).tag(BrowseContentType.books)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)

        browseContentView
      }
    }
    .inlineNavigationBarTitle(title)
    .searchable(text: $searchQuery)
    #if !os(tvOS)
      .toolbar {
        if librarySelection == nil {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: ContentIcon.library)
            }
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          HStack {
            Button {
              showSavedFilters = true
            } label: {
              Image(systemName: "bookmark")
            }

            Button {
              showFilterSheet = true
            } label: {
              Image(systemName: "line.3.horizontal.decrease.circle")
            }

            Menu {
              LayoutModePicker(
                selection: layoutModeBinding,
                showGridDensity: true
              )
            } label: {
              Image(systemName: "ellipsis")
            }
            .appMenuStyle()
          }
        }
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
      .sheet(isPresented: $showSavedFilters) {
        SavedFiltersView(filterType: savedFilterType)
      }
    #endif
    .alert(
      String(localized: "offline.sync.confirm.title"),
      isPresented: $showSyncConfirmation
    ) {
      Button(String(localized: "offline.sync.confirm.action")) {
        Task {
          await instanceInitializer.syncData()
        }
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    } message: {
      Text(String(localized: "offline.sync.confirm.message"))
    }
    .onSubmit(of: .search) {
      activeSearchText = searchQuery
    }
    .onChange(of: searchQuery) { _, newValue in
      if newValue.isEmpty {
        activeSearchText = ""
      }
    }
    .onChange(of: authViewModel.isSwitching) { oldValue, newValue in
      guard librarySelection == nil else { return }
      if oldValue && !newValue {
        refreshBrowse()
      }
    }
    .task(id: resolvedLibraryIdsKey) {
      guard !authViewModel.isSwitching else { return }
      refreshBrowse()
    }
  }

  @ViewBuilder
  private var browseContentView: some View {
    switch resolvedOfflineContent {
    case .series, .collections, .readlists:
      OfflineSeriesBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters
      )
    case .books:
      OfflineBooksBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters
      )
    }
  }

  private var syncCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        showSyncConfirmation = true
      } label: {
        HStack {
          Label(
            String(localized: "settings.sync_data"),
            systemImage: "arrow.triangle.2.circlepath"
          )
          Spacer()
          if instanceInitializer.isSyncing {
            ProgressView()
          } else {
            Text(lastSyncTimeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .disabled(instanceInitializer.isSyncing || isOffline)

      Text(String(localized: "settings.sync_data.description"))
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var downloadShortcuts: some View {
    VStack(spacing: 8) {
      NavigationLink(value: NavDestination.settingsOfflineTasks) {
        OfflineShortcutRow(
          title: OfflineSection.tasks.title,
          subtitle: String(localized: "offline.shortcuts.tasks.subtitle"),
          systemImage: OfflineSection.tasks.icon
        ) {
          OfflineTasksStatusView()
        }
      }
      .adaptiveButtonStyle(.plain)
      NavigationLink(value: NavDestination.settingsOfflineBooks) {
        OfflineShortcutRow(
          title: OfflineSection.books.title,
          subtitle: String(localized: "offline.shortcuts.books.subtitle"),
          systemImage: OfflineSection.books.icon
        ) {
          OfflineBooksCountView()
        }
      }
      .adaptiveButtonStyle(.plain)
    }
  }

  private func refreshBrowse() {
    refreshTrigger = UUID()
  }
}
