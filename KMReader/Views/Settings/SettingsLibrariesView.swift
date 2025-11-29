//
//  SettingsLibrariesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsLibrariesView: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  @State private var performingLibraryIds: Set<String> = []
  @State private var libraryPendingDelete: KomgaLibrary?
  @State private var isPerformingGlobalAction = false
  @State private var isLoading = false

  private let libraryService = LibraryService.shared

  private var libraries: [KomgaLibrary] {
    guard !currentInstanceId.isEmpty else {
      return []
    }
    return allLibraries.filter { $0.instanceId == currentInstanceId }
  }

  private var isDeleteAlertPresented: Binding<Bool> {
    Binding(
      get: { libraryPendingDelete != nil },
      set: { if !$0 { libraryPendingDelete = nil } }
    )
  }

  var body: some View {
    List {
      if isLoading && libraries.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView("Loading Libraries…")
            Spacer()
          }
        }
      } else if libraries.isEmpty {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "books.vertical")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("No libraries found")
              .font(.headline)
            Text("Add a library from Komga's web interface to manage it here.")
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await refreshLibraries()
              }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
        }
      } else {
        allLibrariesRowView()
        ForEach(libraries) { library in
          libraryRowView(library)
        }
      }
    }
    #if os(iOS)
      .listStyle(.insetGrouped)
    #elseif os(macOS)
      .listStyle(.sidebar)
    #elseif os(tvOS)
      .focusSection()
    #endif
    .inlineNavigationBarTitle("Libraries")
    .alert("Delete Library?", isPresented: isDeleteAlertPresented) {
      Button("Delete", role: .destructive) {
        deleteConfirmedLibrary()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let libraryPendingDelete {
        Text("This will permanently delete \(libraryPendingDelete.name) from Komga.")
      }
    }
    .refreshable {
      await refreshLibraries()
    }
    .task {
      await refreshLibraries()
    }
  }

  private func refreshLibraries() async {
    isLoading = true
    await LibraryManager.shared.refreshLibraries()
    isLoading = false
  }

  @ViewBuilder
  private func allLibrariesRowView() -> some View {
    let isSelected = selectedLibraryId.isEmpty

    Button {
      AppConfig.selectedLibraryId = ""
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "square.grid.2x2")
        Text("All Libraries")
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.footnote)
            .foregroundColor(.accentColor)
        }
      }
      .padding(.vertical, 6)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      if AppConfig.isAdmin {
        Button {
          performGlobalAction {
            try await scanAllLibraries(deep: false)
          }
        } label: {
          Label("Scan All Libraries", systemImage: "arrow.clockwise")
        }
        .disabled(isPerformingGlobalAction)

        Button {
          performGlobalAction {
            try await scanAllLibraries(deep: true)
          }
        } label: {
          Label("Scan All Libraries (Deep)", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(isPerformingGlobalAction)

        Button {
          performGlobalAction {
            try await emptyTrashAllLibraries()
          }
        } label: {
          Label("Empty Trash for All Libraries", systemImage: "trash.slash")
        }
        .disabled(isPerformingGlobalAction)
      }
    }
  }

  @ViewBuilder
  private func libraryRowView(_ library: KomgaLibrary) -> some View {
    let isPerforming = performingLibraryIds.contains(library.libraryId)
    let isSelected = selectedLibraryId == library.libraryId

    Button {
      AppConfig.selectedLibraryId = library.libraryId
    } label: {
      librarySummary(library, isPerforming: isPerforming, isSelected: isSelected)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      if AppConfig.isAdmin {
        Button {
          scanLibrary(library)
        } label: {
          Label("Scan Library Files", systemImage: "arrow.clockwise")
        }
        .disabled(isPerforming)

        Button {
          scanLibraryDeep(library)
        } label: {
          Label("Scan Library Files (Deep)", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(isPerforming)

        Button {
          analyzeLibrary(library)
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(isPerforming)

        Button {
          refreshMetadata(library)
        } label: {
          Label("Refresh Metadata", systemImage: "arrow.triangle.branch")
        }
        .disabled(isPerforming)

        Button {
          emptyTrash(library)
        } label: {
          Label("Empty Trash", systemImage: "trash.slash")
        }
        .disabled(isPerforming)

        Divider()

        Button(role: .destructive) {
          libraryPendingDelete = library
        } label: {
          Label("Delete Library", systemImage: "trash")
        }
        .disabled(isPerforming)
      }
    }
  }

  @ViewBuilder
  private func librarySummary(_ library: KomgaLibrary, isPerforming: Bool, isSelected: Bool)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Image(systemName: "books.vertical")
        VStack(alignment: .leading, spacing: 2) {
          Text(library.name)
        }

        Spacer()

        if isPerforming {
          ProgressView()
            .progressViewStyle(.circular)
        } else if isSelected {
          Image(systemName: "checkmark")
            .font(.footnote)
            .foregroundColor(.accentColor)
        }
      }
    }
    .padding(.vertical, 6)
  }

  private func scanLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func scanLibraryDeep(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId, deep: true)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func analyzeLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.analyzeLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library analysis started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func refreshMetadata(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.refreshMetadata(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library metadata refresh started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func emptyTrash(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.emptyTrash(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Trash emptied")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func deleteConfirmedLibrary() {
    guard let library = libraryPendingDelete else { return }
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.deleteLibrary(id: library.libraryId)
        await refreshLibraries()
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library deleted")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
        libraryPendingDelete = nil
      }
    }
  }

  private func scanAllLibraries(deep: Bool) async throws {
    for library in libraries {
      try await libraryService.scanLibrary(id: library.libraryId, deep: deep)
    }
  }

  private func emptyTrashAllLibraries() async throws {
    for library in libraries {
      try await libraryService.emptyTrash(id: library.libraryId)
    }
  }

  private func performGlobalAction(_ action: @escaping () async throws -> Void) {
    guard !isPerformingGlobalAction else { return }
    isPerformingGlobalAction = true
    Task {
      do {
        try await action()
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        isPerformingGlobalAction = false
      }
    }
  }
}
