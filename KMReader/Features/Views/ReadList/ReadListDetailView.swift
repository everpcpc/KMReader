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

  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Environment(\.dismiss) private var dismiss

  // SwiftData query for reactive updates
  @Query private var komgaReadLists: [KomgaReadList]

  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var thumbnailRefreshTrigger = 0

  init(readListId: String) {
    self.readListId = readListId
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(readListId)"
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let readList = readList {
          VStack(alignment: .leading) {
            ReadListDetailContentView(
              readList: readList,
              thumbnailRefreshTrigger: $thumbnailRefreshTrigger
            )

            #if os(tvOS)
              readListToolbarContent
                .padding(.vertical, 8)
            #endif
          }
          .padding(.horizontal)

          // Books list
          if containerWidth > 0 {
            BooksListViewForReadList(
              readListId: readListId,
              layoutHelper: layoutHelper,
              showFilterSheet: $showFilterSheet
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(String(localized: "title.readList"))
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
    .task {
      await loadReadListDetails()
    }
    .onContainerWidthChange { newWidth in
      containerWidth = newWidth
      layoutHelper = BrowseLayoutHelper(
        width: newWidth,
        browseColumns: browseColumns
      )
    }
    .onChange(of: browseColumns) { _, _ in
      if containerWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: containerWidth,
          browseColumns: browseColumns
        )
      }
    }
  }
}

// Helper functions for ReadListDetailView
extension ReadListDetailView {
  private func loadReadListDetails() async {
    do {
      // Sync from network to SwiftData (readList property will update reactively)
      let previousLastModified = komgaReadList?.lastModifiedDate
      let fetchedReadList = try await SyncService.shared.syncReadList(id: readListId)
      if previousLastModified != fetchedReadList.lastModifiedDate {
        reloadThumbnail()
      }
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

  private func reloadThumbnail() {
    guard !AppConfig.isOffline else { return }
    thumbnailRefreshTrigger += 1
  }

  @ViewBuilder
  private var readListToolbarContent: some View {
    HStack(spacing: PlatformHelper.buttonSpacing) {
      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }
      .toolbarButtonStyle()

      Menu {
        if isAdmin {
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
        Image(systemName: "ellipsis.circle")
      }
      .toolbarButtonStyle()
    }
  }
}
