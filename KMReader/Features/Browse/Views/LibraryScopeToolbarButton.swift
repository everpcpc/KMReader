//
// LibraryScopeToolbarButton.swift
//
//

import SwiftUI

/// Labeled library scope button for leading toolbar placement (Home, Offline,
/// iPhone Library tab): shows the library icon plus the current dashboard
/// scope (single library name, or the "%lld Libraries" count) and opens the
/// shared LibraryPickerSheet. Renders nothing when there is at most one
/// library.
struct LibraryScopeToolbarButton: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  @State private var libraries: [SidebarLibraryItem] = []
  @State private var showLibraryPicker = false

  private var scopeTitle: String {
    let selectedIds = dashboard.libraryIds
    if selectedIds.count == 1,
      let name = libraries.first(where: { $0.libraryId == selectedIds[0] })?.name
    {
      return name
    }
    let format = String(
      localized: "offline.coverSync.scope.selected",
      defaultValue: "%lld Libraries"
    )
    return String.localizedStringWithFormat(
      format, selectedIds.isEmpty ? libraries.count : selectedIds.count)
  }

  var body: some View {
    Group {
      if libraries.count > 1 {
        Button {
          showLibraryPicker = true
        } label: {
          // Label gets collapsed to icon-only in the iOS 26 glass toolbar;
          // compose icon + text explicitly.
          HStack(spacing: 4) {
            Image(systemName: ContentIcon.library)
            Text(scopeTitle)
          }
        }
      }
    }
    .sheet(isPresented: $showLibraryPicker) {
      LibraryPickerSheet()
    }
    .task(id: current.instanceId) {
      await refreshLibraries()
    }
    .onReceive(NotificationCenter.default.publisher(for: .sidebarProjectionDidChange)) { notification in
      guard notification.userInfo?["instanceId"] as? String == current.instanceId else { return }
      Task {
        await loadLibraries()
      }
    }
  }

  private func refreshLibraries() async {
    await LibraryManager.shared.refreshLibraries()
    await loadLibraries()
  }

  private func loadLibraries() async {
    guard !current.instanceId.isEmpty else {
      libraries = []
      return
    }
    do {
      let database = try await DatabaseOperator.database()
      let loaded = try await database.fetchSidebarLibraries(instanceId: current.instanceId)
      if libraries != loaded {
        libraries = loaded
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
