//
// LibraryScopeToolbarButton.swift
//
//

import SwiftUI

/// Labeled library scope button for leading toolbar placement (Home, Offline,
/// iPhone Library tab): shows the library icon plus the current dashboard
/// scope (single library name, or the "%lld Libraries" count). Parents own the
/// library list, the >1-library visibility condition, and the
/// LibraryPickerSheet presentation; this view is only the button label.
struct LibraryScopeToolbarButton: View {
  let libraries: [SidebarLibraryItem]
  @Binding var isPresented: Bool

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

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
    Button {
      isPresented = true
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
