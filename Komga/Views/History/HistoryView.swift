//
//  HistoryView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct HistoryView: View {
  @State private var bookViewModel = BookViewModel()

  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @State private var showLibraryPickerSheet = false

  private func refreshRecentlyReadBooks() {
    Task {
      await bookViewModel.loadRecentlyReadBooks(libraryId: selectedLibraryId, refresh: true)
    }
  }

  private func loadMoreRecentlyReadBooks() {
    Task {
      await bookViewModel.loadRecentlyReadBooks(libraryId: selectedLibraryId, refresh: false)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if bookViewModel.isLoading && bookViewModel.books.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
              .transition(.opacity)
          } else if let errorMessage = bookViewModel.errorMessage {
            VStack(spacing: 16) {
              Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(themeColorOption.color)
              Text(errorMessage)
                .multilineTextAlignment(.center)
              Button("Retry") {
                refreshRecentlyReadBooks()
              }
            }
            .padding()
            .transition(.opacity)
          } else if !bookViewModel.books.isEmpty {
            // Recently Read Books Section
            ReadHistorySection(
              title: "Recently Read Books",
              bookViewModel: bookViewModel,
              onLoadMore: loadMoreRecentlyReadBooks,
              onBookUpdated: {
                refreshRecentlyReadBooks()
              }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
          } else {
            VStack(spacing: 16) {
              Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
              Text("No reading history")
                .font(.headline)
              Text("Start reading some books to see your history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .transition(.opacity)
          }
        }
        .padding(.vertical)
      }
      .handleNavigation()
      .navigationTitle("History")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            showLibraryPickerSheet = true
          } label: {
            Image(systemName: "books.vertical")
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            Task {
              await bookViewModel.loadRecentlyReadBooks(
                libraryId: selectedLibraryId, refresh: true)
            }
          } label: {
            Image(systemName: "arrow.clockwise.circle")
          }
          .disabled(bookViewModel.isLoading)
        }
      }
      .sheet(isPresented: $showLibraryPickerSheet) {
        LibraryPickerSheet()
      }
      .onChange(of: selectedLibraryId) {
        refreshRecentlyReadBooks()
      }
    }
    .task {
      refreshRecentlyReadBooks()
    }
  }

  private var selectedLibrary: LibraryInfo? {
    guard !selectedLibraryId.isEmpty else { return nil }
    return LibraryManager.shared.getLibrary(id: selectedLibraryId)
  }
}

struct ReadHistorySection: View {
  let title: String
  var bookViewModel: BookViewModel
  var onLoadMore: (() -> Void)?
  var onBookUpdated: (() -> Void)? = nil

  @State private var readerState: BookReaderState?

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)

      LazyVStack(spacing: 0) {
        ForEach(Array(bookViewModel.books.enumerated()), id: \.element.id) { index, book in
          Button {
            readerState = BookReaderState(bookId: book.id, incognito: false)
          } label: {
            ReadHistoryBookRow(book: book)
              .padding(8)
              .contentShape(Rectangle())
              .contextMenu {
                BookContextMenu(
                  book: book,
                  viewModel: bookViewModel,
                  onReadBook: { incognito in
                    readerState = BookReaderState(bookId: book.id, incognito: incognito)
                  },
                  onActionCompleted: onBookUpdated
                )
              }
          }
          .buttonStyle(.plain)
          .onAppear {
            // Load next page when the last few items appear
            if let onLoadMore = onLoadMore, index >= bookViewModel.books.count - 3 {
              onLoadMore()
            }
          }
        }

        if bookViewModel.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
      .padding(.horizontal, 8)
    }
    .fullScreenCover(
      isPresented: isBookReaderPresented,
      onDismiss: {
        onBookUpdated?()
      }
    ) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
  }
}

struct ReadHistoryBookRow: View {
  let book: Book

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
  }

  var body: some View {
    HStack(spacing: 12) {
      // Thumbnail
      ThumbnailImage(url: thumbnailURL, width: 80, cornerRadius: 6)

      // Book info
      VStack(alignment: .leading, spacing: 6) {
        Text(book.seriesTitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)

        Text("#\(Int(book.number)) - \(book.metadata.title)")
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        Group {
          if book.deleted {
            Text("Unavailable")
              .foregroundColor(.red)
          } else {
            Text("\(book.media.pagesCount) pages")
              .foregroundColor(.secondary)
          }
        }.font(.caption)

        if let progress = book.readProgress {
          Text("Last read: \(formatRelativeDate(progress.readDate))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private func formatRelativeDate(_ date: Date) -> String {
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

    if let days = components.day {
      if days == 0 {
        if let hours = components.hour {
          if hours == 0 {
            if let minutes = components.minute {
              return "\(minutes)m ago"
            }
          }
          return "\(hours)h ago"
        }
      } else if days == 1 {
        return "Yesterday"
      } else if days < 7 {
        return "\(days) days ago"
      }
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
