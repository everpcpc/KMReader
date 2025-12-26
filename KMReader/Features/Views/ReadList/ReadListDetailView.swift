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
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  // SwiftData query for reactive updates
  @Query private var komgaReadLists: [KomgaReadList]

  @State private var bookViewModel = BookViewModel()
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

  // SwiftUI's default horizontal padding is 16 on each side (32 total)
  private let horizontalPadding: CGFloat = 16

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let readList = readList {
          // Header with thumbnail and info
          Text(readList.name)
            .font(.title2)

          HStack(alignment: .top) {
            ThumbnailImage(
              id: readListId, type: .readlist, showPlaceholder: false,
              width: PlatformHelper.detailThumbnailWidth,
              refreshTrigger: thumbnailRefreshTrigger
            )
            .thumbnailFocus()

            VStack(alignment: .leading) {

              // Summary
              if !readList.summary.isEmpty {
                Text(readList.summary)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .padding(.top, 4)
              }

              // Info chips
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                  InfoChip(
                    labelKey: "\(readList.bookIds.count) books",
                    systemImage: "books.vertical",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  if readList.ordered {
                    InfoChip(
                      labelKey: "Ordered",
                      systemImage: "arrow.up.arrow.down",
                      backgroundColor: Color.cyan.opacity(0.2),
                      foregroundColor: .cyan
                    )
                  }
                }
                InfoChip(
                  labelKey: "Created: \(formatDate(readList.createdDate))",
                  systemImage: "calendar.badge.plus",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
                InfoChip(
                  labelKey: "Modified: \(formatDate(readList.lastModifiedDate))",
                  systemImage: "clock",
                  backgroundColor: Color.purple.opacity(0.2),
                  foregroundColor: .purple
                )
              }
            }
          }

          #if os(tvOS)
            readListToolbarContent
              .padding(.vertical, 8)
          #endif

          // Books list
          if containerWidth > 0 {
            BooksListViewForReadList(
              readListId: readListId,
              bookViewModel: bookViewModel,
              layoutHelper: layoutHelper,
              showFilterSheet: $showFilterSheet
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal, horizontalPadding)
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
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { newSize in
      let newContentWidth = max(0, newSize.width - horizontalPadding * 2)
      if abs(containerWidth - newContentWidth) > 1 {
        containerWidth = newContentWidth
        layoutHelper = BrowseLayoutHelper(
          width: newContentWidth,
          browseColumns: browseColumns
        )
      }
    }
    .onChange(of: browseColumns) { _, _ in
      if containerWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: containerWidth - horizontalPadding * 2,
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
      _ = try await SyncService.shared.syncReadList(id: readListId)
      reloadThumbnail()
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaReadList == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func presentReader(book: Book, incognito: Bool) {
    readerPresentation.present(book: book, incognito: incognito, readList: readList) {
      Task {
        await loadReadListDetails()
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

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
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
        Button {
          showEditSheet = true
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .disabled(!isAdmin)

        Divider()

        Button(role: .destructive) {
          showDeleteConfirmation = true
        } label: {
          Label("Delete Read List", systemImage: "trash")
        }
        .disabled(!isAdmin)
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .toolbarButtonStyle()
    }
  }
}
