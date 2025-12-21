//
//  SettingsLibrariesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsLibrariesView: View {
  @State private var libraryPendingDelete: KomgaLibrary?
  @State private var deleteConfirmationText: String = ""

  private var isDeleteAlertPresented: Binding<Bool> {
    Binding(
      get: { libraryPendingDelete != nil },
      set: {
        if !$0 {
          libraryPendingDelete = nil
          deleteConfirmationText = ""
        }
      }
    )
  }

  var body: some View {
    LibraryListContent(
      showDeleteAction: true,
      alwaysRefreshMetrics: true,
      forceMetricsOnAppear: true,
      onDeleteLibrary: { library in
        libraryPendingDelete = library
        deleteConfirmationText = ""
      }
    )
    .inlineNavigationBarTitle(String(localized: "settings.libraries.title"))
    .alert(String(localized: "settings.libraries.alert.title"), isPresented: isDeleteAlertPresented)
    {
      if let libraryPendingDelete {
        TextField(
          String(localized: "settings.libraries.alert.placeholder"),
          text: $deleteConfirmationText)
        Button(String(localized: "settings.libraries.alert.delete"), role: .destructive) {
          deleteConfirmedLibrary(libraryPendingDelete)
        }
        .disabled(deleteConfirmationText != libraryPendingDelete.name)
        Button(String(localized: "common.cancel"), role: .cancel) {
          deleteConfirmationText = ""
        }
      }
    } message: {
      if let libraryPendingDelete {
        Text(
          deleteLibraryConfirmationMessage(for: libraryPendingDelete)
        )
      }
    }
  }

  private func deleteConfirmedLibrary(_ library: KomgaLibrary) {
    Task {
      do {
        try await LibraryService.shared.deleteLibrary(id: library.libraryId)
        await LibraryManager.shared.refreshLibraries()
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.library.deleted"))
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        libraryPendingDelete = nil
        deleteConfirmationText = ""
      }
    }
  }
}

private func deleteLibraryConfirmationMessage(for library: KomgaLibrary) -> String {
  let format = String(
    localized: "settings.libraries.alert.message",
    defaultValue:
      "This will permanently delete %1$@ from Komga.\n\nTo confirm, please type the library name: %2$@"
  )
  return String(format: format, locale: Locale.current, library.name, library.name)
}
