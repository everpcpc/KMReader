//
//  ReadListPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListPickerSheet: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @Environment(\.dismiss) private var dismiss

  @State private var readListViewModel = ReadListViewModel()
  @State private var selectedReadListId: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
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
    NavigationStack {
      Form {
        if isLoading && readListViewModel.readLists.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if let errorMessage = errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
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
      .navigationTitle("Select Read List")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            if let selectedReadListId = selectedReadListId {
              onSelect(selectedReadListId)
              dismiss()
            }
          } label: {
            Label("Done", systemImage: "checkmark")
          }
          .disabled(selectedReadListId == nil)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button {
            showCreateSheet = true
          } label: {
            Label("Create New", systemImage: "plus.circle.fill")
          }
          .disabled(!AppConfig.isAdmin)
        }
      }
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
          onCreate: { readListId in
            // Create already adds books, so just complete and dismiss
            onComplete?()
            dismiss()
          }
        )
      }
    }
  }

  private func loadReadLists(searchText: String = "") async {
    isLoading = true
    errorMessage = nil

    await readListViewModel.loadReadLists(
      libraryId: selectedLibraryId,
      sort: "name,asc",
      searchText: searchText,
      refresh: true
    )

    if let viewModelError = readListViewModel.errorMessage {
      errorMessage = viewModelError
    }

    isLoading = false
  }
}

struct CreateReadListSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var isCreating: Bool
  let bookIds: [String]
  let onCreate: (String) -> Void

  @State private var name: String = ""
  @State private var summary: String = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Read List Name", text: $name)
          TextField("Summary (Optional)", text: $summary, axis: .vertical)
            .lineLimit(3...6)
        }

        if let errorMessage = errorMessage {
          Section {
            Text(errorMessage)
              .foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Create Read List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            createReadList()
          } label: {
            if isCreating {
              ProgressView()
            } else {
              Label("Create", systemImage: "checkmark")
            }
          }
          .disabled(name.isEmpty || isCreating)
        }
      }
    }
  }

  private func createReadList() {
    guard !name.isEmpty else { return }

    isCreating = true
    errorMessage = nil

    Task {
      do {
        let readList = try await ReadListService.shared.createReadList(
          name: name,
          summary: summary,
          bookIds: bookIds
        )
        await MainActor.run {
          isCreating = false
          onCreate(readList.id)
          dismiss()
        }
      } catch {
        await MainActor.run {
          isCreating = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}
