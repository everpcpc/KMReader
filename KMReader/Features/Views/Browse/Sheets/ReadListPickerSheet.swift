//
//  ReadListPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var readListViewModel = ReadListViewModel()
  @State private var selectedReadListId: String?
  @State private var isLoading = false
  @State private var searchText: String = ""
  @State private var showCreateSheet = false
  @State private var isCreating = false

  let bookIds: [String]
  let onSelect: (String) -> Void
  let onComplete: (() -> Void)?

  init(
    bookIds: [String] = [],
    onSelect: @escaping (String) -> Void,
    onComplete: (() -> Void)? = nil
  ) {
    self.bookIds = bookIds
    self.onSelect = onSelect
    self.onComplete = onComplete
  }

  var body: some View {
    SheetView(title: String(localized: "Select Read List"), size: .large, applyFormStyle: true) {
      Form {
        if isLoading && readListViewModel.readLists.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if readListViewModel.readLists.isEmpty && searchText.isEmpty {
          Text("No read lists found")
            .foregroundColor(.secondary)
        } else {
          Picker("Read List", selection: $selectedReadListId) {
            ForEach(readListViewModel.readLists) { readList in
              Label(readList.name, systemImage: "list.bullet").tag(readList.id as String?)
            }
          }
          .pickerStyle(.inline)
        }
      }
    } controls: {
      Button {
        showCreateSheet = true
      } label: {
        Label("Create New", systemImage: "plus.circle.fill")
      }
      .disabled(!isAdmin)

      HStack(spacing: 12) {
        Button(action: confirmSelection) {
          Label("Done", systemImage: "checkmark")
        }
        .disabled(selectedReadListId == nil)
      }
    }
    .searchable(text: $searchText)
    .task {
      await loadReadLists()
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await loadReadLists(searchText: newValue)
      }
    }
    .sheet(isPresented: $showCreateSheet) {
      CreateReadListSheet(
        isCreating: $isCreating,
        bookIds: bookIds,
        onCreate: { _ in
          onComplete?()
          dismiss()
        }
      )
    }
  }

  private func loadReadLists(searchText: String = "") async {
    isLoading = true

    await readListViewModel.loadReadLists(
      context: modelContext,
      libraryIds: dashboard.libraryIds,
      sort: "name,asc",
      searchText: searchText,
      refresh: true
    )

    isLoading = false
  }

  private func confirmSelection() {
    if let selectedReadListId = selectedReadListId {
      onSelect(selectedReadListId)
      dismiss()
    }
  }
}

struct CreateReadListSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var isCreating: Bool
  let bookIds: [String]
  let onCreate: (String) -> Void

  @State private var name: String = ""
  @State private var summary: String = ""

  var body: some View {
    SheetView(title: String(localized: "Create Read List"), size: .medium, applyFormStyle: true) {
      Form {
        Section {
          TextField("Read List Name", text: $name)
          TextField("Summary (Optional)", text: $summary, axis: .vertical)
            .lineLimit(3...6)
        }
      }
    } controls: {
      Button(action: createReadList) {
        if isCreating {
          ProgressView()
        } else {
          Label("Create", systemImage: "checkmark")
        }
      }
      .disabled(name.isEmpty || isCreating)
    }
  }

  private func createReadList() {
    guard !name.isEmpty else { return }

    isCreating = true

    Task {
      do {
        let readList = try await ReadListService.shared.createReadList(
          name: name,
          summary: summary,
          bookIds: bookIds
        )
        // Sync the readlist to update its bookIds in local SwiftData
        _ = try? await SyncService.shared.syncReadList(id: readList.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.readList.created"))
          isCreating = false
          onCreate(readList.id)
          dismiss()
        }
      } catch {
        await MainActor.run {
          isCreating = false
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
