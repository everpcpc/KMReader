//
//  ReadListDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListDetailView: View {
  let readListId: String

  @AppStorage("browseLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var bookViewModel = BookViewModel()
  @State private var readList: ReadList?
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()

  // SwiftUI's default horizontal padding is 16 on each side (32 total)
  private let horizontalPadding: CGFloat = 16

  private var thumbnailURL: URL? {
    readList.flatMap { ReadListService.shared.getReadListThumbnailURL(id: $0.id) }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let readList = readList {
          // Header with thumbnail and info
          Text(readList.name)
            .font(.title3)

          HStack(alignment: .top) {
            ThumbnailImage(
              url: thumbnailURL, showPlaceholder: false, width: PlatformHelper.detailThumbnailWidth
            )
            #if os(tvOS)
              .focusable()
            #endif

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
                    label: "\(readList.bookIds.count) books",
                    systemImage: "books.vertical",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  if readList.ordered {
                    InfoChip(
                      label: "Ordered",
                      systemImage: "arrow.up.arrow.down",
                      backgroundColor: Color.cyan.opacity(0.2),
                      foregroundColor: .cyan
                    )
                  }
                }
                InfoChip(
                  label: "Created: \(formatDate(readList.createdDate))",
                  systemImage: "calendar.badge.plus",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
                InfoChip(
                  label: "Modified: \(formatDate(readList.lastModifiedDate))",
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
              onReadBook: { book, incognito in
                presentReader(book: book, incognito: incognito)
              },
              layoutMode: layoutMode,
              layoutHelper: layoutHelper
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal, horizontalPadding)
    }
    .inlineNavigationBarTitle("Read List")
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
      readList = try await ReadListService.shared.getReadList(id: readListId)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func presentReader(book: Book, incognito: Bool) {
    readerPresentation.present(book: book, incognito: incognito) {
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
        ErrorManager.shared.notify(message: "Read list deleted")
        dismiss()
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  @ViewBuilder
  private var readListToolbarContent: some View {
    HStack(spacing: 8) {
      Menu {
        Picker("Layout", selection: $layoutMode) {
          ForEach(BrowseLayoutMode.allCases) { mode in
            Label(mode.displayName, systemImage: mode.iconName).tag(mode)
          }
        }
        .pickerStyle(.inline)
      } label: {
        Label("Layout", systemImage: layoutMode.iconName)
          .labelStyle(.iconOnly)
      }

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
    }
  }
}
