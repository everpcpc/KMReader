//
//  ReadListDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListDetailView: View {
  let readListId: String

  @AppStorage("readListDetailLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

  @Environment(\.dismiss) private var dismiss

  @State private var bookViewModel = BookViewModel()
  @State private var readList: ReadList?
  @State private var readerState: BookReaderState?
  @State private var showDeleteConfirmation = false

  private var thumbnailURL: URL? {
    readList.flatMap { ReadListService.shared.getReadListThumbnailURL(id: $0.id) }
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }


  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading) {
          if let readList = readList {
            // Header with thumbnail and info
            HStack(alignment: .top) {
              ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

              VStack(alignment: .leading) {
                Text(readList.name)
                  .font(.title2)

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
                    label: readList.createdDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar.badge.plus",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  InfoChip(
                    label: readList.lastModifiedDate.formatted(
                      date: .abbreviated, time: .omitted),
                    systemImage: "clock",
                    backgroundColor: Color.purple.opacity(0.2),
                    foregroundColor: .purple
                  )
                }
              }

              Spacer()
            }

            // Books list
            BooksListViewForReadList(
              readListId: readListId,
              bookViewModel: bookViewModel,
              onReadBook: { bookId, incognito in
                readerState = BookReaderState(bookId: bookId, incognito: incognito)
              },
              layoutMode: layoutMode,
              layoutHelper: BrowseLayoutHelper(
                width: geometry.size.width - 32,
                height: geometry.size.height,
                spacing: 12,
                browseColumns: browseColumns
              )
            )
          } else {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .padding(.horizontal)
      }
      .navigationTitle("Read List")
      .navigationBarTitleDisplayMode(.inline)
      .fullScreenCover(
        isPresented: isBookReaderPresented,
        onDismiss: {
          Task {
            await loadReadListDetails()
          }
        }
      ) {
        if let state = readerState, let bookId = state.bookId {
          BookReaderView(bookId: bookId, incognito: state.incognito)
        }
      }
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
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          HStack(spacing: 8) {
            Menu {
              Picker("Layout", selection: $layoutMode) {
                ForEach(BrowseLayoutMode.allCases) { mode in
                  Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
              }
              .pickerStyle(.inline)
            } label: {
              Image(systemName: layoutMode.iconName)
            }

            Menu {
              Button(role: .destructive) {
                showDeleteConfirmation = true
              } label: {
                Label("Delete Read List", systemImage: "trash")
              }
              .disabled(!AppConfig.isAdmin)
            } label: {
              Image(systemName: "ellipsis.circle")
            }
          }
        }
      }
      .task {
        await loadReadListDetails()
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
}
