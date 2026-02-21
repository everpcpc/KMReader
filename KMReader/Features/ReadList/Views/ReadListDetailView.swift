//
// ReadListDetailView.swift
//
//

import SQLiteData
import SwiftUI

struct ReadListDetailView: View {
  let readListId: String

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("readListDetailLayout") private var readListDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  @FetchAll private var komgaReadLists: [KomgaReadListRecord]
  @FetchAll private var readListLocalStateList: [KomgaReadListLocalStateRecord]

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(readListId: String) {
    self.readListId = readListId
    let instanceId = AppConfig.current.instanceId
    _komgaReadLists = FetchAll(
      KomgaReadListRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }.limit(1)
    )
    _readListLocalStateList = FetchAll(
      KomgaReadListLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.readListId.eq(readListId) }.limit(1)
    )
  }

  private var komgaReadList: KomgaReadListRecord? {
    komgaReadLists.first
  }

  private var readList: ReadList? {
    komgaReadList?.toReadList()
  }

  private var readListLocalState: KomgaReadListLocalStateRecord? {
    readListLocalStateList.first
  }

  private var navigationTitle: String {
    readList?.name ?? String(localized: "title.readList")
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let readList = readList {
          VStack(alignment: .leading) {
            ReadListDetailContentView(
              readList: readList
            )

            #if os(tvOS)
              readListToolbarContent
                .padding(.vertical, 8)
            #endif

            Divider()
            if let komgaReadList = komgaReadList {
              ReadListDownloadActionsSection(
                readList: komgaReadList.toReadList(),
                localState: readListLocalState
              )
            }
            Divider()
          }
          .padding(.horizontal)

          // Books list
          if komgaReadList != nil {
            BooksListViewForReadList(
              readListId: readListId,
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(navigationTitle)
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.readList(serverURL: current.serverURL, readListId: readListId),
      scope: .browse
    )
    .alert("Delete Read List?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        Task {
          await deleteReadList()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(readList?.name ?? "this read list") from Komga.")
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          readListToolbarContent
        }
      }
    #endif
    .sheet(isPresented: $showEditSheet) {
      if let readList = readList {
        ReadListEditSheet(readList: readList)
          .onDisappear {
            Task {
              await loadReadListDetails()
            }
          }
      }
    }
    .sheet(isPresented: $showSavedFilters) {
      SavedFiltersView(filterType: .readListBooks)
    }
    .task {
      await loadReadListDetails()
    }
  }
}

// Helper functions for ReadListDetailView
extension ReadListDetailView {
  private func loadReadListDetails() async {
    do {
      _ = try await SyncService.shared.syncReadList(id: readListId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaReadList == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  @MainActor
  private func deleteReadList() async {
    do {
      try await ReadListService.shared.deleteReadList(readListId: readListId)
      ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  @ViewBuilder
  private var readListToolbarContent: some View {
    HStack {
      Button {
        showSavedFilters = true
      } label: {
        Image(systemName: "bookmark")
      }

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      Menu {
        LayoutModePicker(selection: $readListDetailLayout)

        Divider()

        if current.isAdmin {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Read List", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
      .appMenuStyle()
    }.toolbarButtonStyle()
  }
}
