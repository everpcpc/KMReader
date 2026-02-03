//
//  ReadListDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListDetailView: View {
  let readListId: String

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("readListDetailLayout") private var readListDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  // SwiftData query for reactive updates
  @Query private var komgaReadLists: [KomgaReadList]

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(readListId: String) {
    self.readListId = readListId
    let compositeId = CompositeID.generate(id: readListId)
    _komgaReadLists = Query(filter: #Predicate<KomgaReadList> { $0.id == compositeId })
  }

  /// The KomgaReadList from SwiftData (reactive).
  private var komgaReadList: KomgaReadList? {
    komgaReadLists.first
  }

  /// Convert to API ReadList type for compatibility with existing components.
  private var readList: ReadList? {
    komgaReadList?.toReadList()
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
              ReadListDownloadActionsSection(komgaReadList: komgaReadList)
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
      // Sync from network to SwiftData (readList property will update reactively)
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
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
        dismiss()
      }
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
    }.toolbarButtonStyle()
  }
}
