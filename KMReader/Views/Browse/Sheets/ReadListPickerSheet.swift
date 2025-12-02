//
//  ReadListPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
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
    NavigationStack {
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
        #if os(tvOS)
          Section {
            Button(action: confirmSelection) {
              Label("Done", systemImage: "checkmark")
            }
            .disabled(selectedReadListId == nil)

            Button {
              dismiss()
            } label: {
              Label("Cancel", systemImage: "xmark")
            }

            Button {
              showCreateSheet = true
            } label: {
              Label("Create New", systemImage: "plus.circle.fill")
            }
            .disabled(!isAdmin)
          }
          .listRowBackground(Color.clear)
        #endif
      }
      .padding(PlatformHelper.sheetPadding)
      .inlineNavigationBarTitle("Select Read List")
      .searchable(text: $searchText)
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button(action: confirmSelection) {
              Label("Done", systemImage: "checkmark")
            }
            .disabled(selectedReadListId == nil)
          }
          ToolbarItem(placement: .automatic) {
            Button {
              dismiss()
            } label: {
              Label("Cancel", systemImage: "xmark")
            }
          }
          ToolbarItem(placement: .automatic) {
            Button {
              showCreateSheet = true
            } label: {
              Label("Create New", systemImage: "plus.circle.fill")
            }
            .disabled(!isAdmin)
          }
        }
      #endif
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
    .platformSheetPresentation(detents: [.large])
  }

  private func loadReadLists(searchText: String = "") async {
    isLoading = true

    await readListViewModel.loadReadLists(
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
    NavigationStack {
      Form {
        Section {
          TextField("Read List Name", text: $name)
          TextField("Summary (Optional)", text: $summary, axis: .vertical)
            .lineLimit(3...6)
        }
      #if os(tvOS)
        Section {
          Button {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }

          Button(action: createReadList) {
            if isCreating {
              ProgressView()
            } else {
              Label("Create", systemImage: "checkmark")
            }
          }
          .disabled(name.isEmpty || isCreating)
        }
        .listRowBackground(Color.clear)
      #endif
      }
      .padding(PlatformHelper.sheetPadding)
      .inlineNavigationBarTitle("Create Read List")
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button {
              dismiss()
            } label: {
              Label("Cancel", systemImage: "xmark")
            }
          }
          ToolbarItem(placement: .automatic) {
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
      #endif
    }
    .platformSheetPresentation(detents: [.medium], minWidth: 400, minHeight: 300)
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
        await MainActor.run {
          ErrorManager.shared.notify(message: "Read list created")
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
