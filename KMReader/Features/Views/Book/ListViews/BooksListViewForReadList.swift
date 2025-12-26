//
//  BooksListViewForReadList.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

// Books list view for read list
struct BooksListViewForReadList: View {
  let readListId: String
  @Bindable var bookViewModel: BookViewModel
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("readListDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("readListBookBrowseOptions") private var browseOpts: ReadListBookBrowseOptions =
    ReadListBookBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var selectedBookIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false
  @Environment(\.modelContext) private var modelContext

  @Query private var readLists: [KomgaReadList]

  private var readList: KomgaReadList? {
    readLists.first
  }

  init(
    readListId: String, bookViewModel: BookViewModel,
    layoutHelper: BrowseLayoutHelper, showFilterSheet: Binding<Bool>
  ) {
    self.readListId = readListId
    self.bookViewModel = bookViewModel
    self.layoutHelper = layoutHelper
    self._showFilterSheet = showFilterSheet

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(readListId)"
    _readLists = Query(filter: #Predicate<KomgaReadList> { $0.id == compositeId })
  }

  private var supportsSelectionMode: Bool {
    #if os(tvOS)
      return false
    #else
      return true
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Button {
          Task {
            await refreshBooks()
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(bookViewModel.isLoading)
        .adaptiveButtonStyle(.bordered)
        .controlSize(.mini)

        Spacer()

        HStack(spacing: 8) {
          ReadListBookFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            layoutMode: $layoutMode
          )

          if supportsSelectionMode && !isSelectionMode && isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil.circle")
            }
            .adaptiveButtonStyle(.bordered)
            .controlSize(.small)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      if supportsSelectionMode && isSelectionMode {
        SelectionToolbar(
          selectedCount: selectedBookIds.count,
          totalCount: readList?.bookIds.count ?? 0,
          isDeleting: isDeleting,
          onSelectAll: {
            if let bookIds = readList?.bookIds {
              if selectedBookIds.count == bookIds.count {
                selectedBookIds.removeAll()
              } else {
                selectedBookIds = Set(bookIds)
              }
            }
          },
          onDelete: {
            Task {
              await deleteSelectedBooks()
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedBookIds.removeAll()
          }
        )
      }

      if readList?.bookIds != nil {
        ReadListBooksQueryView(
          readListId: readListId,
          bookViewModel: bookViewModel,
          browseOpts: browseOpts,
          layoutHelper: layoutHelper,
          browseLayout: layoutMode,
          isSelectionMode: isSelectionMode,
          selectedBookIds: $selectedBookIds,
          isAdmin: isAdmin,
          refreshBooks: {
            Task {
              await refreshBooks()
            }
          }
        )
      } else if bookViewModel.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      }
    }
    .task(id: readListId) {
      await refreshBooks()
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshBooks()
      }
    }
  }

  private func refreshBooks() async {
    await bookViewModel.loadReadListBooks(
      context: modelContext,
      readListId: readListId,
      browseOpts: browseOpts,
      libraryIds: dashboard.libraryIds,
      refresh: true
    )
  }
}

extension BooksListViewForReadList {
  @MainActor
  private func deleteSelectedBooks() async {
    guard !selectedBookIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await ReadListService.shared.removeBooksFromReadList(
        readListId: readListId,
        bookIds: Array(selectedBookIds)
      )
      // Sync the readlist to update its bookIds in local SwiftData
      _ = try? await SyncService.shared.syncReadList(id: readListId)

      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.readList.booksRemoved"))
      }

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedBookIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the books list
      await refreshBooks()
    } catch {
      await MainActor.run {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
