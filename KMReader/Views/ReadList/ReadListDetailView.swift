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
  #if canImport(AppKit)
    @Environment(\.openWindow) private var openWindow
  #endif

  @State private var bookViewModel = BookViewModel()
  @State private var readList: ReadList?
  @State private var readerState: BookReaderState?
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

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
                  .font(.title3)

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

            // Books list
            BooksListViewForReadList(
              readListId: readListId,
              bookViewModel: bookViewModel,
              onReadBook: { book, incognito in
                readerState = BookReaderState(book: book, incognito: incognito)
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
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      #if canImport(UIKit)
        .fullScreenCover(
          isPresented: isBookReaderPresented,
          onDismiss: {
            Task {
              await loadReadListDetails()
            }
          }
        ) {
          if let state = readerState, let book = state.book {
            BookReaderView(book: book, incognito: state.incognito)
          }
        }
      #else
        .onChange(of: readerState) { _, newState in
          if let state = newState, let book = state.book {
            ReaderWindowManager.shared.openReader(book: book, incognito: state.incognito)
            openWindow(id: "reader")
          } else {
            ReaderWindowManager.shared.closeReader()
          }
        }
      #endif
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
        ToolbarItem(placement: .automatic) {
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
              Button {
                showEditSheet = true
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .disabled(!AppConfig.isAdmin)

              Divider()

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

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
