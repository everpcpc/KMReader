//
//  DashboardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Combine
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
  @State private var showLibraryPickerSheet = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading) {
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
              DashboardBooksSection(
                title: "Keep Reading",
                books: keepReadingBooks,
                bookViewModel: bookViewModel,
                onBookUpdated: refreshDashboardData
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // On Deck Section
            if !onDeckBooks.isEmpty {
              DashboardBooksSection(
                title: "On Deck",
                books: onDeckBooks,
                bookViewModel: bookViewModel,
                onBookUpdated: refreshDashboardData
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recently Added Books
            if !recentlyAddedBooks.isEmpty {
              DashboardBooksSection(
                title: "Recently Added Books",
                books: recentlyAddedBooks,
                bookViewModel: bookViewModel,
                onBookUpdated: refreshDashboardData
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recently Updated Series
            if !recentlyUpdatedSeries.isEmpty {
              DashboardSeriesSection(
                title: "Recently Updated Series",
                series: recentlyUpdatedSeries,
                seriesViewModel: seriesViewModel,
                onSeriesUpdated: refreshDashboardData
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recently Added Series
            if !recentlyAddedSeries.isEmpty {
              DashboardSeriesSection(
                title: "Recently Added Series",
                series: recentlyAddedSeries,
                seriesViewModel: seriesViewModel,
                onSeriesUpdated: refreshDashboardData
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
      .handleNavigation()
      .navigationTitle("Dashboard")
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
              await loadAll()
            }
          } label: {
            Image(systemName: "arrow.clockwise.circle")
          }
          .disabled(isLoading)
        }
      }
      .sheet(isPresented: $showLibraryPickerSheet) {
        LibraryPickerSheet()
      }
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
      let condition = BookSearch.buildCondition(
        libraryId: selectedLibraryId.isEmpty ? nil : selectedLibraryId,
        readStatus: ReadStatus.inProgress
      )

      let search = BookSearch(condition: condition)

      let page = try await BookService.shared.getBooksList(
        search: search,
        size: 20,
        sort: "readProgress.readDate,desc"
      )
      withAnimation {
        keepReadingBooks = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadOnDeck() async {
    do {
      let page = try await BookService.shared.getBooksOnDeck(
        libraryId: selectedLibraryId, size: 20)
      withAnimation {
        onDeckBooks = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadRecentlyAddedBooks() async {
    do {
      let page = try await BookService.shared.getRecentlyAddedBooks(
        libraryId: selectedLibraryId, size: 20)
      withAnimation {
        recentlyAddedBooks = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadRecentlyAddedSeries() async {
    await seriesViewModel.loadNewSeries(libraryId: selectedLibraryId)
    withAnimation {
      recentlyAddedSeries = seriesViewModel.series
    }
  }

  private func loadRecentlyUpdatedSeries() async {
    await seriesViewModel.loadUpdatedSeries(libraryId: selectedLibraryId)
    withAnimation {
      recentlyUpdatedSeries = seriesViewModel.series
    }
  }

  private func refreshDashboardData() {
    Task {
      await loadAll()
    }
  }
}

struct DashboardBooksSection: View {
  let title: String
  let books: [Book]
  var bookViewModel: BookViewModel
  var onBookUpdated: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(books) { book in
            BookCardView(
              book: book,
              viewModel: bookViewModel,
              cardWidth: 120,
              onBookUpdated: onBookUpdated
            )
          }
        }.padding()
      }
    }
  }
}

struct DashboardSeriesSection: View {
  let title: String
  let series: [Series]
  var seriesViewModel: SeriesViewModel
  var onSeriesUpdated: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(series) { s in
            NavigationLink(value: NavDestination.seriesDetail(seriesId: s.id)) {
              SeriesCardView(
                series: s,
                cardWidth: 120,
                onActionCompleted: onSeriesUpdated
              )
            }
            .buttonStyle(.plain)
          }
        }.padding()
      }
    }
  }
}

#Preview {
  DashboardView()
}
