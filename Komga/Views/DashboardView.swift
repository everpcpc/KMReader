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
  @State private var recentlyAddedBooks: [Book] = []
  @State private var recentlyAddedSeries: [Series] = []
  @State private var recentlyUpdatedSeries: [Series] = []
  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var bookViewModel = BookViewModel()
  @State private var seriesViewModel = SeriesViewModel()

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
          // Library Picker at the top
          HStack {
            Menu {
              Picker(selection: $selectedLibraryId) {
                Label("All Libraries", systemImage: "square.grid.2x2").tag("")
                ForEach(LibraryManager.shared.libraries) { library in
                  Label(library.name, systemImage: "books.vertical").tag(library.id)
                }
              } label: {
                Label(
                  selectedLibrary?.name ?? "All Libraries",
                  systemImage: selectedLibraryId.isEmpty ? "square.grid.2x2" : "books.vertical")
              }
              .pickerStyle(.inline)
            } label: {
              HStack {
                Image(systemName: selectedLibraryId.isEmpty ? "square.grid.2x2" : "books.vertical")
                Text(selectedLibrary?.name ?? "All Libraries")
                  .font(.body)
                Image(systemName: "chevron.down")
                  .font(.caption)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color(.systemGray6))
              .cornerRadius(8)
            }
            Spacer()
            Button {
              Task {
                await loadAll()
              }
            } label: {
              Image(systemName: "arrow.clockwise.circle")
                .font(.title2)
                .symbolEffect(.rotate, value: isLoading)
            }
            .disabled(isLoading)
          }
          .padding(.horizontal)
          .padding(.top, 8)

          if isLoading && keepReadingBooks.isEmpty && onDeckBooks.isEmpty
            && recentlyAddedBooks.isEmpty
          {
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

            // Recently Added Books
            if !recentlyAddedBooks.isEmpty {
              DashboardSection(
                title: "Recently Added Books",
                books: recentlyAddedBooks,
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

            if keepReadingBooks.isEmpty && onDeckBooks.isEmpty && recentlyAddedBooks.isEmpty
              && recentlyAddedSeries.isEmpty && recentlyUpdatedSeries.isEmpty
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
      .navigationTitle("Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .animation(.default, value: selectedLibraryId)
      .onChange(of: selectedLibraryId) {
        Task {
          await loadAll()
        }
      }
    }
    .task {
      await loadAll()
    }
  }

  private var selectedLibrary: LibraryInfo? {
    guard !selectedLibraryId.isEmpty else { return nil }
    return LibraryManager.shared.getLibrary(id: selectedLibraryId)
  }

  private func loadAll() async {
    isLoading = true
    errorMessage = nil

    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadKeepReading() }
      group.addTask { await self.loadOnDeck() }
      group.addTask { await self.loadRecentlyAddedBooks() }
      group.addTask { await self.loadRecentlyAddedSeries() }
      group.addTask { await self.loadRecentlyUpdatedSeries() }
    }

    isLoading = false
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

  private func loadRecentlyAddedBooks() async {
    do {
      let page = try await BookService.shared.getRecentlyAddedBooks(
        libraryId: selectedLibraryIdOptional, size: 20)
      recentlyAddedBooks = page.content
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
              BookCardView(book: book, viewModel: bookViewModel, cardWidth: 120)
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
