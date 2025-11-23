//
//  SettingsLibrariesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsLibrariesView: View {
  @State private var viewModel = LibraryViewModel()
  @State private var performingLibraryIds: Set<String> = []
  @State private var libraryPendingDelete: Library?
  @State private var operatingLibrary: Library?
  @State private var isPerformingGlobalAction = false

  private var isDeleteAlertPresented: Binding<Bool> {
    Binding(
      get: { libraryPendingDelete != nil },
      set: { if !$0 { libraryPendingDelete = nil } }
    )
  }

  var body: some View {
    List {
      if viewModel.isLoading && viewModel.libraries.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView("Loading Libraries…")
            Spacer()
          }
        }
      } else if viewModel.libraries.isEmpty {
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
                await viewModel.loadLibraries()
              }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
        }
      } else {
        ForEach(viewModel.libraries) { library in
          libraryRowView(library)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Libraries")
    .navigationBarTitleDisplayMode(.inline)
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
      await viewModel.loadLibraries()
    }
    .task {
      await viewModel.loadLibraries()
    }
    .sheet(item: $operatingLibrary) { library in
      LibraryActionsSheet(
        library: library,
        isPerforming: performingLibraryIds.contains(library.id),
        onScan: { scanLibrary(library) },
        onScanDeep: { scanLibraryDeep(library) },
        onAnalyze: { analyzeLibrary(library) },
        onRefreshMetadata: { refreshMetadata(library) },
        onEmptyTrash: { emptyTrash(library) },
        onDelete: { libraryPendingDelete = library }
      )
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button {
            performGlobalAction {
              try await scanAllLibraries(deep: false)
            }
          } label: {
            Label("Scan All Libraries", systemImage: "arrow.clockwise")
          }
          .disabled(isPerformingGlobalAction || !AppConfig.isAdmin)

          Button {
            performGlobalAction {
              try await scanAllLibraries(deep: true)
            }
          } label: {
            Label("Scan All Libraries (Deep)", systemImage: "arrow.triangle.2.circlepath")
          }
          .disabled(isPerformingGlobalAction || !AppConfig.isAdmin)

          Button {
            performGlobalAction {
              try await emptyTrashAllLibraries()
            }
          } label: {
            Label("Empty Trash for All Libraries", systemImage: "trash.slash")
          }
          .disabled(isPerformingGlobalAction || !AppConfig.isAdmin)
        } label: {
          if isPerformingGlobalAction {
            ProgressView()
          } else {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
    }
  }

  @ViewBuilder
  private func libraryRowView(_ library: Library) -> some View {
    let isPerforming = performingLibraryIds.contains(library.id)

    librarySummary(library, isPerforming: isPerforming)
      .contentShape(Rectangle())
      .onTapGesture {
        if AppConfig.isAdmin {
          operatingLibrary = library
        }
      }
      .disabled(!AppConfig.isAdmin)
  }

  @ViewBuilder
  private func librarySummary(_ library: Library, isPerforming: Bool) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Image(systemName: "books.vertical")
        VStack(alignment: .leading, spacing: 2) {
          Text(library.name)
          if library.unavailable == true {
            Label("Unavailable", systemImage: "exclamationmark.triangle")
              .font(.caption)
              .foregroundColor(.red)
          }
        }

        Spacer()

        if isPerforming {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Image(systemName: "chevron.right")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(.vertical, 6)
  }

  private func scanLibrary(_ library: Library) {
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.scanLibrary(library)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
      }
    }
  }

  private func scanLibraryDeep(_ library: Library) {
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.scanLibrary(library, deep: true)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library scan started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
      }
    }
  }

  private func analyzeLibrary(_ library: Library) {
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.analyzeLibrary(library)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library analysis started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
      }
    }
  }

  private func refreshMetadata(_ library: Library) {
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.refreshMetadata(library)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library metadata refresh started")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
      }
    }
  }

  private func emptyTrash(_ library: Library) {
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.emptyTrash(library)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Trash emptied")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
      }
    }
  }

  private func deleteConfirmedLibrary() {
    guard let library = libraryPendingDelete else { return }
    guard !performingLibraryIds.contains(library.id) else { return }
    performingLibraryIds.insert(library.id)
    Task {
      do {
        try await viewModel.deleteLibrary(library)
        await LibraryManager.shared.refreshLibraries()
        await viewModel.loadLibraries()
        await MainActor.run {
          ErrorManager.shared.notify(message: "Library deleted")
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.id)
        libraryPendingDelete = nil
      }
    }
  }

  private func scanAllLibraries(deep: Bool) async throws {
    for library in viewModel.libraries {
      try await viewModel.scanLibrary(library, deep: deep)
    }
  }

  private func emptyTrashAllLibraries() async throws {
    for library in viewModel.libraries {
      try await viewModel.emptyTrash(library)
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

private struct LibraryActionsSheet: View {
  let library: Library
  let isPerforming: Bool
  let onScan: () -> Void
  let onScanDeep: () -> Void
  let onAnalyze: () -> Void
  let onRefreshMetadata: () -> Void
  let onEmptyTrash: () -> Void
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          actionButton(title: "Scan Library Files", systemImage: "arrow.clockwise", action: onScan)
          actionButton(
            title: "Scan Library Files (Deep)",
            systemImage: "arrow.triangle.2.circlepath",
            action: onScanDeep
          )
          actionButton(title: "Analyze", systemImage: "waveform.path.ecg", action: onAnalyze)
          actionButton(
            title: "Refresh Metadata",
            systemImage: "arrow.triangle.branch",
            action: onRefreshMetadata
          )
          actionButton(
            title: "Empty Trash",
            systemImage: "trash.slash",
            tint: .orange,
            action: onEmptyTrash
          )
          actionButton(
            title: "Delete Library",
            systemImage: "trash",
            tint: .red,
            role: .destructive,
            action: onDelete
          )
        }
        .disabled(isPerforming || !AppConfig.isAdmin)
      }
      .navigationTitle(library.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            dismiss()
          } label: {
            Label("Close", systemImage: "xmark")
          }
        }
      }
    }
  }

  private func actionButton(
    title: String,
    systemImage: String,
    tint: Color? = nil,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(role: role) {
      action()
      dismiss()
    } label: {
      Label(title, systemImage: systemImage)
        .foregroundColor(role == .destructive ? .red : .primary)
    }
    .tint(tint)
  }
}
