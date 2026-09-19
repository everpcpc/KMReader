//
// DashboardEmptyLibraryView.swift
//
//

import SwiftUI

struct DashboardEmptyLibraryView: View {
  let isAdmin: Bool
  let onCreateLibrary: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(String(localized: "No Libraries Yet"), systemImage: ContentIcon.library)
    } description: {
      if isAdmin {
        Text(
          String(
            localized: "Create a library pointing to a folder on your server to get started."))
      } else {
        Text(String(localized: "Ask your server administrator to create a library to get started."))
      }
    } actions: {
      if isAdmin {
        Button(action: onCreateLibrary) {
          Text(String(localized: "Add Library"))
        }
        .adaptiveButtonStyle(.borderedProminent)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 64)
  }
}
