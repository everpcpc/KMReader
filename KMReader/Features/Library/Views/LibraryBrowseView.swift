//
// LibraryBrowseView.swift
//
//

import SwiftUI

/// iPhone Library tab root: content-first browsing (Apple Books style) over the
/// global library selection (dashboard.libraryIds, shared with Home). The
/// leading toolbar button is the shared LibraryScopeToolbarButton, which
/// labels the current scope and opens the shared LibraryPickerSheet. Library
/// management stays in Settings.
struct LibraryBrowseView: View {
  let authViewModel: AuthViewModel

  var body: some View {
    BrowseView(authViewModel: authViewModel, libraryTab: true)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          LibraryScopeToolbarButton()
        }
      }
  }
}
