//
//  BooksBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BooksBrowseView: View {
  @Binding var browseOpts: BookBrowseOptions
  let width: CGFloat
  let height: CGFloat
  let searchText: String
  private let spacing: CGFloat = 16

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid

  @State private var viewModel = BookViewModel()
  @State private var readerState: BookReaderState?
  @State private var showOptions = false

  private var availableWidth: CGFloat {
    width - spacing * 2
  }

  private var isLandscape: Bool {
    width > height
  }

  private var columnsCount: Int {
    isLandscape ? browseColumns.landscape : browseColumns.portrait
  }

  private var cardWidth: CGFloat {
    guard columnsCount > 0 else { return availableWidth }
    let totalSpacing = CGFloat(columnsCount - 1) * spacing
    return (availableWidth - totalSpacing) / CGFloat(columnsCount)
  }

  private var columns: [GridItem] {
    Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: max(columnsCount, 1))
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else if let errorMessage = viewModel.errorMessage {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(themeColorOption.color)
          Text(errorMessage)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task {
              await viewModel.loadBrowseBooks(
                browseOpts: browseOpts, searchText: searchText, refresh: true)
            }
          }
        }
        .padding()
      } else if viewModel.books.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "book")
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text("No books found")
            .font(.headline)
          Text("Try selecting a different library.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
      } else {
        switch browseLayout {
        case .grid:
          gridView
        case .list:
          listView
        }

        if viewModel.isLoading {
          ProgressView()
            .padding()
        }
      }
    }
    .task {
      if viewModel.books.isEmpty {
        await viewModel.loadBrowseBooks(
          browseOpts: browseOpts, searchText: searchText, refresh: true)
      }
    }
    .onChange(of: browseOpts) { _, newValue in
      Task {
        await viewModel.loadBrowseBooks(browseOpts: newValue, searchText: searchText, refresh: true)
      }
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await viewModel.loadBrowseBooks(browseOpts: browseOpts, searchText: newValue, refresh: true)
      }
    }
    .fullScreenCover(isPresented: isBookReaderPresented) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
    .sheet(isPresented: $showOptions) {
      BookBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }

  private var gridView: some View {
    LazyVGrid(columns: columns, spacing: spacing) {
      ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
        BookCardView(
          book: book,
          viewModel: viewModel,
          cardWidth: cardWidth,
          onBookUpdated: {
            Task {
              await viewModel.loadBrowseBooks(
                browseOpts: browseOpts, searchText: searchText, refresh: true)
            }
          }
        )
        .onAppear {
          if index >= viewModel.books.count - 3 {
            Task {
              await viewModel.loadBrowseBooks(
                browseOpts: browseOpts, searchText: searchText, refresh: false)
            }
          }
        }
      }
    }
    .padding(.horizontal, spacing)
  }

  private var listView: some View {
    LazyVStack(spacing: 0) {
      ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
        BookRowView(
          book: book,
          viewModel: viewModel,
          onReadBook: { incognito in
            readerState = BookReaderState(bookId: book.id, incognito: incognito)
          },
          onBookUpdated: {
            Task {
              await viewModel.loadBrowseBooks(
                browseOpts: browseOpts, searchText: searchText, refresh: true)
            }
          },
          showSeriesTitle: true
        )
        .padding()
        .onAppear {
          if index >= viewModel.books.count - 3 {
            Task {
              await viewModel.loadBrowseBooks(
                browseOpts: browseOpts, searchText: searchText, refresh: false)
            }
          }
        }

        if index < viewModel.books.count - 1 {
          Divider()
            .padding(.leading)
        }
      }
    }
  }
}
