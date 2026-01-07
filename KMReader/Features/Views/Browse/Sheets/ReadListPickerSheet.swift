//
//  ReadListPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

private struct ReadListItem: Identifiable {
  let id: String
  let name: String
  let alreadyIn: Bool
}

struct ReadListPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var selectedReadListId: String?
  @State private var isLoading = false
  @State private var searchText: String = ""
  @State private var showCreateSheet = false
  @State private var isCreating = false

  @Query private var komgaReadLists: [KomgaReadList]

  let bookId: String
  let onSelect: (String) -> Void

  init(
    bookId: String,
    onSelect: @escaping (String) -> Void
  ) {
    self.bookId = bookId
    self.onSelect = onSelect

    let instanceId = AppConfig.currentInstanceId
    _komgaReadLists = Query(
      filter: #Predicate<KomgaReadList> { $0.instanceId == instanceId },
      sort: [SortDescriptor(\KomgaReadList.name, order: .forward)]
    )
  }

  private var filteredReadLists: [KomgaReadList] {
    if searchText.isEmpty {
      return Array(komgaReadLists)
    }
    return komgaReadLists.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  private func isAlreadyInReadList(_ readList: KomgaReadList) -> Bool {
    return readList.bookIds.contains(bookId)
  }

  private var readListItems: [ReadListItem] {
    filteredReadLists.map { readList in
      ReadListItem(
        id: readList.readListId,
        name: readList.name,
        alreadyIn: readList.bookIds.contains(bookId)
      )
    }
  }

  var body: some View {
    SheetView(title: String(localized: "Select Read List"), size: .large, applyFormStyle: true) {
      Form {
        if isLoading && komgaReadLists.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else if filteredReadLists.isEmpty && searchText.isEmpty {
          Text("No read lists found")
            .foregroundColor(.secondary)
        } else {
          Section {
            ForEach(readListItems) { item in
              Button {
                if !item.alreadyIn {
                  selectedReadListId = item.id
                }
              } label: {
                HStack {
                  Label(item.name, systemImage: "list.bullet")
                  Spacer()
                  if item.alreadyIn {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.green)
                  } else if selectedReadListId == item.id {
                    Image(systemName: "checkmark")
                      .foregroundStyle(.tint)
                  }
                }
                .foregroundStyle(item.alreadyIn ? .secondary : .primary)
              }
              .disabled(item.alreadyIn)
            }
          }
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
      await syncReadLists()
    }
    .sheet(isPresented: $showCreateSheet) {
      CreateReadListSheet(
        isCreating: $isCreating,
        bookId: bookId,
        onCreate: { _ in
          dismiss()
        }
      )
    }
  }

  private func syncReadLists() async {
    guard !AppConfig.isOffline else { return }
    isLoading = true
    await SyncService.shared.syncReadLists(instanceId: AppConfig.currentInstanceId)
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
  let bookId: String
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
          bookIds: [bookId]
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
