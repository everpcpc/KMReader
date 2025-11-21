//
//  ReadListDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListDetailView: View {
  let readListId: String

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("bookListSortDirection") private var sortDirection: SortDirection = .ascending

  @Environment(\.dismiss) private var dismiss

  @State private var bookViewModel = BookViewModel()
  @State private var readList: ReadList?
  @State private var readerState: BookReaderState?
  @State private var actionErrorMessage: String?

  private var thumbnailURL: URL? {
    guard let readList = readList else { return nil }
    return ReadListService.shared.getReadListThumbnailURL(id: readList.id)
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  private var isActionErrorPresented: Binding<Bool> {
    Binding(
      get: { actionErrorMessage != nil },
      set: { if !$0 { actionErrorMessage = nil } }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let readList = readList {
          // Header with thumbnail and info
          HStack(alignment: .top, spacing: 16) {
            ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

            VStack(alignment: .leading) {
              Text(readList.name)
                .font(.title2)

              // Books count
              Text("\(readList.bookIds.count) books")
                .font(.caption)
                .foregroundColor(.secondary)

              // Summary
              if !readList.summary.isEmpty {
                Text(readList.summary)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .padding(.top, 4)
              }

              // Created date
              HStack(spacing: 4) {
                Image(systemName: "calendar.badge.plus")
                  .font(.caption2)
                Text(readList.createdDate.formatted(date: .abbreviated, time: .omitted))
              }
              .font(.caption)
              .foregroundColor(.secondary)

              // Last modified date
              HStack(spacing: 4) {
                Image(systemName: "clock")
                  .font(.caption2)
                Text(readList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
              }
              .font(.caption)
              .foregroundColor(.secondary)

              // Ordered indicator
              if readList.ordered {
                HStack(spacing: 4) {
                  Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                  Text("Ordered")
                }
                .font(.caption)
                .foregroundColor(.secondary)
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
            }
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
        refreshAfterReading()
      }
    ) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
    .alert("Action Failed", isPresented: isActionErrorPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      if let actionErrorMessage {
        Text(actionErrorMessage)
      }
    }
    .task {
      await loadReadListDetails()
    }
  }
}

// Helper functions for ReadListDetailView
extension ReadListDetailView {
  private func refreshAfterReading() {
    Task {
      await refreshReadListData()
    }
  }

  @MainActor
  private func refreshReadListData() async {
    await loadReadListDetails()
    await bookViewModel.loadReadListBooks(
      readListId: readListId, sort: sortDirection.bookSortString, refresh: true)
  }

  @MainActor
  private func loadReadListDetails() async {
    do {
      let fetchedReadList = try await ReadListService.shared.getReadList(id: readListId)
      readList = fetchedReadList
      await bookViewModel.loadReadListBooks(
        readListId: readListId, sort: sortDirection.bookSortString, refresh: true)
    } catch {
      actionErrorMessage = error.localizedDescription
    }
  }
}

// Books list view for read list
struct BooksListViewForReadList: View {
  let readListId: String
  @Bindable var bookViewModel: BookViewModel
  var onReadBook: (String, Bool) -> Void
  @AppStorage("bookListSortDirection") private var sortDirection: SortDirection = .ascending

  private var sortString: String {
    "metadata.numberSort,\(sortDirection.rawValue)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        Button {
          sortDirection = sortDirection.toggle()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: sortDirection.icon)
            Text(sortDirection.displayName)
          }
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.1))
          .foregroundColor(.primary)
          .cornerRadius(4)
        }
      }

      if bookViewModel.isLoading && bookViewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        LazyVStack(spacing: 8) {
          ForEach(bookViewModel.books) { book in
            BookRowView(
              book: book,
              viewModel: bookViewModel,
              onReadBook: { incognito in
                onReadBook(book.id, incognito)
              },
              onBookUpdated: {
                refreshBooks()
              }
            )
            .onAppear {
              if book.id == bookViewModel.books.last?.id {
                Task {
                  await bookViewModel.loadReadListBooks(
                    readListId: readListId, sort: sortString, refresh: false)
                }
              }
            }
          }

          if bookViewModel.isLoading && !bookViewModel.books.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
          }
        }
      }
    }
    .task(id: readListId) {
      await bookViewModel.loadReadListBooks(readListId: readListId, sort: sortString, refresh: true)
    }
    .onChange(of: sortDirection) {
      Task {
        await bookViewModel.loadReadListBooks(
          readListId: readListId, sort: sortString, refresh: true)
      }
    }
  }
}

extension BooksListViewForReadList {
  fileprivate func refreshBooks() {
    Task {
      await bookViewModel.loadReadListBooks(readListId: readListId, sort: sortString, refresh: true)
    }
  }
}
