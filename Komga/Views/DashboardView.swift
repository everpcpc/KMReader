//
//  DashboardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DashboardView: View {
  @State private var keepReadingBooks: [Book] = []
  @State private var onDeckBooks: [Book] = []
  @State private var recentlyAddedSeries: [Series] = []
  @State private var recentlyUpdatedSeries: [Series] = []
  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var bookViewModel = BookViewModel()
  @State private var seriesViewModel = SeriesViewModel()

  @State private var libraries: [Library] = []
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @State private var showLibraryPicker = false

  private var selectedLibraryIdOptional: String? {
    selectedLibraryId.isEmpty ? nil : selectedLibraryId
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if isLoading && keepReadingBooks.isEmpty && onDeckBooks.isEmpty {
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
                  await loadAll()
                }
              }
            }
            .padding()
            .transition(.opacity)
          } else {
            // Keep Reading Section
            if !keepReadingBooks.isEmpty {
              DashboardSection(
                title: "Keep Reading",
                books: keepReadingBooks,
                bookViewModel: bookViewModel
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // On Deck Section
            if !onDeckBooks.isEmpty {
              DashboardSection(
                title: "On Deck",
                books: onDeckBooks,
                bookViewModel: bookViewModel
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recently Updated Series
            if !recentlyUpdatedSeries.isEmpty {
              DashboardSeriesSection(
                title: "Recently Updated Series",
                series: recentlyUpdatedSeries,
                seriesViewModel: seriesViewModel
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recently Added Series
            if !recentlyAddedSeries.isEmpty {
              DashboardSeriesSection(
                title: "Recently Added Series",
                series: recentlyAddedSeries,
                seriesViewModel: seriesViewModel
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            if keepReadingBooks.isEmpty && onDeckBooks.isEmpty && recentlyAddedSeries.isEmpty
              && recentlyUpdatedSeries.isEmpty
            {
              VStack(spacing: 16) {
                Image(systemName: "book")
                  .font(.system(size: 60))
                  .foregroundColor(.secondary)
                Text("Nothing to show")
                  .font(.headline)
                Text("Start reading to see recommendations here")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .transition(.opacity)
            }
          }
        }
        .padding(.vertical)
      }
      .navigationTitle(selectedLibrary?.name ?? "All Libraries")
      .navigationBarTitleDisplayMode(.inline)
      .animation(.default, value: selectedLibraryId)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          HStack(spacing: 16) {
            Button {
              Task {
                await loadAll(showLoading: false)
              }
            } label: {
              Image(systemName: "arrow.clockwise.circle")
            }
            .disabled(isLoading)

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
      }
      .onChange(of: selectedLibraryId) {
        Task {
          await loadAll()
        }
      }
    }
    .task {
      await loadLibraries()
      await loadAll()
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

  private func loadAll(showLoading: Bool = true) async {
    if showLoading {
      isLoading = true
    }
    errorMessage = nil

    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadKeepReading() }
      group.addTask { await self.loadOnDeck() }
      group.addTask { await self.loadRecentlyAddedSeries() }
      group.addTask { await self.loadRecentlyUpdatedSeries() }
    }

    if showLoading {
      isLoading = false
    }
  }

  private func loadKeepReading() async {
    do {
      // Load books with IN_PROGRESS read status
      let condition: BookSearch.Condition
      if let selectedId = selectedLibraryIdOptional {
        // Filter by both library and read status
        condition = .libraryIdAndReadStatus(libraryId: selectedId, readStatus: .inProgress)
      } else {
        // Filter by read status only
        condition = .readStatus(.inProgress)
      }

      let search = BookSearch(condition: condition)

      let page = try await BookService.shared.getBooksList(
        search: search,
        size: 20,
        sort: "readProgress.readDate,desc"
      )
      keepReadingBooks = page.content
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadOnDeck() async {
    do {
      let page = try await BookService.shared.getBooksOnDeck(
        libraryId: selectedLibraryIdOptional, size: 20)
      onDeckBooks = page.content
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadRecentlyAddedSeries() async {
    await seriesViewModel.loadNewSeries(libraryId: selectedLibraryIdOptional)
    recentlyAddedSeries = seriesViewModel.series
  }

  private func loadRecentlyUpdatedSeries() async {
    await seriesViewModel.loadUpdatedSeries(libraryId: selectedLibraryIdOptional)
    recentlyUpdatedSeries = seriesViewModel.series
  }
}

struct DashboardSection: View {
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

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(books) { book in
            Button {
              selectedBookId = book.id
            } label: {
              DashboardBookCard(book: book, viewModel: bookViewModel)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(.horizontal)
      }
    }
    .animation(.default, value: books)
    .fullScreenCover(isPresented: isBookReaderPresented) {
      if let bookId = selectedBookId {
        BookReaderView(bookId: bookId)
      }
    }
  }
}

struct DashboardBookCard: View {
  let book: Book
  var viewModel: BookViewModel
  @State private var thumbnail: UIImage?
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  private var progress: Double {
    guard let readProgress = book.readProgress else { return 0 }
    guard book.media.pagesCount > 0 else { return 0 }
    return Double(readProgress.page) / Double(book.media.pagesCount)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
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
      .frame(width: 120, height: 180)
      .clipped()
      .cornerRadius(8)
      .overlay(alignment: .topTrailing) {
        if book.readProgress == nil {
          Circle()
            .fill(themeColorOption.color)
            .frame(width: 12, height: 12)
            .padding(4)
        }
      }
      .overlay(alignment: .bottom) {
        if book.readProgress != nil {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 4)
                .cornerRadius(2)

              Rectangle()
                .fill(themeColorOption.color)
                .frame(width: geometry.size.width * progress, height: 4)
                .cornerRadius(2)
            }
          }
          .frame(height: 4)
          .padding(.horizontal, 4)
          .padding(.bottom, 4)
        }
      }

      // Book info
      VStack(alignment: .leading, spacing: 2) {
        // Series title
        Text(book.seriesTitle)
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)

        // Book number - Book title
        Text("\(book.metadata.number) - \(book.metadata.title)")
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)

        // Pages count and file size
        Text("\(book.media.pagesCount) pages · \(book.size)")
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(width: 120, alignment: .leading)
    }
    .task {
      thumbnail = await viewModel.loadThumbnail(for: book.id)
    }
  }
}

struct DashboardSeriesSection: View {
  let title: String
  let series: [Series]
  var seriesViewModel: SeriesViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(series) { s in
            NavigationLink(destination: SeriesDetailView(seriesId: s.id)) {
              SeriesCardView(series: s, viewModel: seriesViewModel, cardWidth: 120)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(.horizontal)
      }
    }
    .animation(.default, value: series)
  }
}

#Preview {
  DashboardView()
}
