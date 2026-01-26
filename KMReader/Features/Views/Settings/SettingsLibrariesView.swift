//
//  SettingsLibrariesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsLibrariesView: View {
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var libraryPendingDelete: LibrarySelection?
  @State private var deleteConfirmationText: String = ""
  @State private var showAddSheet = false
  @State private var libraryToEdit: Library?

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

  private var isEditSheetPresented: Binding<Bool> {
    Binding(
      get: { libraryToEdit != nil },
      set: { if !$0 { libraryToEdit = nil } }
    )
  }

  var body: some View {
    LibraryListContent(
      alwaysRefreshMetrics: true,
      forceMetricsOnAppear: true,
      onEditLibrary: { libraryId in
        fetchAndEditLibrary(libraryId)
      },
      onDeleteLibrary: { library in
        libraryPendingDelete = library
        deleteConfirmationText = ""
      }
    )
    .inlineNavigationBarTitle(SettingsSection.libraries.title)
    .toolbar {
      if current.isAdmin && !isOffline {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showAddSheet = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
    .sheet(isPresented: $showAddSheet) {
      LibraryAddSheet()
    }
    .sheet(isPresented: isEditSheetPresented) {
      if let library = libraryToEdit {
        LibraryEditSheet(library: library)
      }
    }
    .alert(String(localized: "settings.libraries.alert.title"), isPresented: isDeleteAlertPresented) {
      if let libraryPendingDelete {
        TextField(
          String(localized: "settings.libraries.alert.placeholder"),
          text: $deleteConfirmationText)
        Button(String(localized: "settings.libraries.alert.delete"), role: .destructive) {
          deleteConfirmedLibrary(libraryPendingDelete)
        }
        .disabled(deleteConfirmationText != libraryPendingDelete.name)
        Button(String(localized: "Cancel"), role: .cancel) {
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

  private func fetchAndEditLibrary(_ libraryId: String) {
    Task {
      do {
        let library = try await LibraryService.shared.getLibrary(id: libraryId)
        await MainActor.run {
          libraryToEdit = library
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteConfirmedLibrary(_ library: LibrarySelection) {
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

private func deleteLibraryConfirmationMessage(for library: LibrarySelection) -> String {
  let format = String(
    localized: "settings.libraries.alert.message",
    defaultValue:
      "This will permanently delete %1$@ from Komga.\n\nTo confirm, please type the library name: %2$@"
  )
  return String(format: format, locale: Locale.current, library.name, library.name)
}
