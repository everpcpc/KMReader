//
//  HistoryView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct HistoryView: View {
  @State private var recentlyReadBooks: [Book] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var bookViewModel = BookViewModel()

  @State private var libraries: [Library] = []
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  private var selectedLibraryIdOptional: String? {
    selectedLibraryId.isEmpty ? nil : selectedLibraryId
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if isLoading && recentlyReadBooks.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
              .transition(.opacity)
          } else if let errorMessage = errorMessage {
            VStack(spacing: 16) {
              Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(themeColorOption.color)
              Text(errorMessage)
                .multilineTextAlignment(.center)
              Button("Retry") {
                Task {
                  await loadRecentlyRead()
                }
              }
            }
            .padding()
            .transition(.opacity)
          } else if !recentlyReadBooks.isEmpty {
            // Recently Read Books Section
            ReadHistorySection(
              title: "Recently Read Books",
              books: recentlyReadBooks,
              bookViewModel: bookViewModel
            )
            .animation(.default, value: recentlyReadBooks)
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
      .navigationTitle("History")
      .navigationBarTitleDisplayMode(.inline)
      .animation(.default, value: selectedLibraryId)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker(selection: $selectedLibraryId) {
              Label("All Libraries", systemImage: "square.grid.2x2").tag("")
              ForEach(libraries) { library in
                Label(library.name, systemImage: "books.vertical").tag(library.id)
              }
            } label: {
              Label(
                selectedLibrary?.name ?? "All Libraries",
                systemImage: selectedLibraryId.isEmpty ? "square.grid.2x2" : "books.vertical")
            }
            .pickerStyle(.menu)
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .onChange(of: selectedLibraryId) {
        Task {
          await loadRecentlyRead(showLoading: false)
        }
      }
    }
    .task {
      await loadLibraries()
      await loadRecentlyRead(showLoading: true)
    }
  }

  private var selectedLibrary: Library? {
    guard !selectedLibraryId.isEmpty else { return nil }
    return libraries.first { $0.id == selectedLibraryId }
  }

  private func loadLibraries() async {
    do {
      libraries = try await LibraryService.shared.getLibraries()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadRecentlyRead(showLoading: Bool = true) async {
    if showLoading {
      isLoading = true
    }
    errorMessage = nil

    do {
      let page = try await BookService.shared.getRecentlyReadBooks(
        libraryId: selectedLibraryIdOptional,
        size: 50
      )
      recentlyReadBooks = page.content
    } catch {
      errorMessage = error.localizedDescription
    }

    if showLoading {
      isLoading = false
    }
  }
}

struct ReadHistorySection: View {
  let title: String
  let books: [Book]
  var bookViewModel: BookViewModel

  @State private var selectedBookId: String?

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { selectedBookId != nil },
      set: { if !$0 { selectedBookId = nil } }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)

      LazyVStack(spacing: 8) {
        ForEach(books) { book in
          Button {
            selectedBookId = book.id
          } label: {
            ReadHistoryBookRow(book: book, viewModel: bookViewModel)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding(.horizontal)
    }
    .fullScreenCover(isPresented: isBookReaderPresented) {
      if let bookId = selectedBookId {
        BookReaderView(bookId: bookId)
      }
    }
  }
}

struct ReadHistoryBookRow: View {
  let book: Book
  var viewModel: BookViewModel
  @State private var thumbnail: UIImage?

  var body: some View {
    HStack(spacing: 12) {
      // Thumbnail
      ZStack {
        if let thumbnail = thumbnail {
          Image(uiImage: thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
        } else {
          Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
              ProgressView()
            }
        }
      }
      .frame(width: 80, height: 100)
      .clipped()
      .cornerRadius(6)

      // Book info
      VStack(alignment: .leading, spacing: 6) {
        Text(book.seriesTitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)

        Text(book.metadata.title)
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        Text("#\(Int(book.number)) - \(book.media.pagesCount) pages")
          .font(.caption)
          .foregroundColor(.secondary)

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
    .animation(.default, value: thumbnail)
    .task {
      thumbnail = await viewModel.loadThumbnail(for: book.id)
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
