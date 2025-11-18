//
//  BookReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookReaderView: View {
  let initialBookId: String
  let incognito: Bool

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var isAtBottom = false
  @State private var isAtEndPage = false
  @State private var showingReadingDirectionPicker = false

  init(bookId: String, incognito: Bool = false) {
    self.initialBookId = bookId
    self.incognito = incognito
    self._currentBookId = State(initialValue: bookId)
  }

  var shouldShowControls: Bool {
    // Always show controls when no pages are loaded or when explicitly shown
    viewModel.pages.isEmpty || showingControls || isAtEndPage
      || (viewModel.readingDirection == .webtoon && isAtBottom)
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if !viewModel.pages.isEmpty {
        // Page viewer based on reading direction
        Group {
          switch viewModel.readingDirection {
          case .ltr, .rtl:
            HorizontalPageView(
              viewModel: viewModel,
              isAtEndPage: $isAtEndPage,
              showingControls: $showingControls,
              nextBook: nextBook,
              onDismiss: { dismiss() },
              onNextBook: { openNextBook(nextBookId: $0) },
              goToNextPage: goToNextPage,
              goToPreviousPage: goToPreviousPage,
              toggleControls: toggleControls
            ).ignoresSafeArea()
          case .vertical:
            VerticalPageView(
              viewModel: viewModel,
              isAtEndPage: $isAtEndPage,
              showingControls: $showingControls,
              nextBook: nextBook,
              onDismiss: { dismiss() },
              onNextBook: { openNextBook(nextBookId: $0) },
              goToNextPage: goToNextPage,
              goToPreviousPage: goToPreviousPage,
              toggleControls: toggleControls
            ).ignoresSafeArea()
          case .webtoon:
            WebtoonPageView(
              viewModel: viewModel,
              currentPage: currentPageBinding,
              isAtBottom: $isAtBottom,
              nextBook: nextBook,
              onDismiss: { dismiss() },
              onNextBook: { openNextBook(nextBookId: $0) },
              toggleControls: toggleControls
            ).ignoresSafeArea()
          }
        }
        .onChange(of: viewModel.currentPageIndex) {
          // Update progress and preload pages in background without blocking UI
          Task(priority: .userInitiated) {
            await viewModel.updateProgress()
            await viewModel.preloadPages()
          }
        }
      } else if viewModel.isLoading {
        // Show loading indicator when loading
        ProgressView()
          .tint(.white)
      } else {
        // No pages available - only show error when loading has completed
        NoPagesView(
          errorMessage: viewModel.errorMessage,
          onDismiss: { dismiss() }
        )
      }

      // Controls overlay (always rendered, use opacity to control visibility)
      ReaderControlsView(
        showingControls: $showingControls,
        showingReadingDirectionPicker: $showingReadingDirectionPicker,
        viewModel: viewModel,
        currentBook: currentBook,
        onDismiss: { dismiss() }
      )
      .opacity(shouldShowControls ? 1.0 : 0.0)
      .allowsHitTesting(shouldShowControls)
    }
    .statusBar(hidden: !showingControls && !viewModel.pages.isEmpty)
    .sheet(isPresented: $showingReadingDirectionPicker) {
      NavigationStack {
        Form {
          Picker("Reading Direction", selection: $viewModel.readingDirection) {
            ForEach(ReadingDirection.allCases, id: \.self) { direction in
              Label(direction.displayName, systemImage: direction.icon)
                .tag(direction)
            }
          }
          .pickerStyle(.inline)
        }
        .navigationTitle("Reading Mode")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium])
      .onChange(of: viewModel.readingDirection) {
        showingReadingDirectionPicker = false
      }
    }
    .task(id: currentBookId) {
      // Mark that loading has started
      viewModel.isLoading = true

      // Set incognito mode
      viewModel.incognitoMode = incognito

      // Reset isAtBottom and isAtEndPage when switching to a new book
      isAtBottom = false
      isAtEndPage = false

      // Load book info to get read progress page and series reading direction
      var initialPageNumber: Int? = nil
      do {
        let book = try await BookService.shared.getBook(id: currentBookId)
        currentBook = book
        seriesId = book.seriesId
        // In incognito mode, always start from the first page
        initialPageNumber = incognito ? nil : book.readProgress?.page

        // Get series reading direction
        let series = try await SeriesService.shared.getOneSeries(id: book.seriesId)
        if let readingDirectionString = series.metadata.readingDirection {
          viewModel.readingDirection = ReadingDirection.fromString(readingDirectionString)
        }

        // Load next book
        if let nextBook = try await BookService.shared.getNextBook(bookId: currentBookId) {
          self.nextBook = nextBook
        } else {
          nextBook = nil
        }
      } catch {
        // Silently fail, will start from first page
      }

      await viewModel.loadPages(bookId: currentBookId, initialPageNumber: initialPageNumber)

      // Only preload pages if pages are available
      if !viewModel.pages.isEmpty {
        await viewModel.preloadPages()
        // Start timer to auto-hide controls after 3 seconds when entering reader
        resetControlsTimer()
      } else {
        // Ensure controls are visible when no pages are available
        showingControls = true
      }
    }
    .onDisappear {
      controlsTimer?.invalidate()
    }
  }

  private var currentPageBinding: Binding<Int> {
    Binding(
      get: { viewModel.currentPageIndex },
      set: { newPage in
        if newPage != viewModel.currentPageIndex {
          viewModel.currentPageIndex = newPage
        }
      }
    )
  }

  private func goToNextPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if viewModel.currentPageIndex < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPageIndex += 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .rtl:
      if viewModel.currentPageIndex > 0 {
        withAnimation {
          viewModel.currentPageIndex -= 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page (which is at -1 for RTL)
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .vertical:
      if viewModel.currentPageIndex < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPageIndex += 1
          isAtEndPage = false
        }
      } else {
        // Navigate to end page
        withAnimation {
          isAtEndPage = true
          showingControls = true  // Show controls when reaching end page
        }
      }
    case .webtoon:
      // Webtoon mode uses scroll, so we scroll to next page
      if viewModel.currentPageIndex < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPageIndex += 1
        }
      }
    }
  }

  private func goToPreviousPage() {
    switch viewModel.readingDirection {
    case .ltr:
      if isAtEndPage {
        // Go back from end page to last page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPageIndex = viewModel.pages.count - 1
        }
      } else if viewModel.currentPageIndex > 0 {
        withAnimation {
          viewModel.currentPageIndex -= 1
        }
      }
    case .rtl:
      if isAtEndPage {
        // Go back from end page to first page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPageIndex = 0
        }
      } else if viewModel.currentPageIndex < viewModel.pages.count - 1 {
        withAnimation {
          viewModel.currentPageIndex += 1
        }
      }
    case .vertical:
      if isAtEndPage {
        // Go back from end page to last page
        withAnimation {
          isAtEndPage = false
          viewModel.currentPageIndex = viewModel.pages.count - 1
        }
      } else if viewModel.currentPageIndex > 0 {
        withAnimation {
          viewModel.currentPageIndex -= 1
        }
      }
    case .webtoon:
      // Webtoon mode uses scroll, so we scroll to previous page
      if viewModel.currentPageIndex > 0 {
        withAnimation {
          viewModel.currentPageIndex -= 1
        }
      }
    }
  }

  private func toggleReadingDirection() {
    // Toggle direction
    viewModel.readingDirection = viewModel.readingDirection == .ltr ? .rtl : .ltr

    // The currentPageIndex remains the same (actual page index)
    // The display will update automatically through the TabView binding
  }

  private func toggleControls() {
    // Don't hide controls when at end page or webtoon at bottom
    if isAtEndPage || (viewModel.readingDirection == .webtoon && isAtBottom) {
      return
    }
    withAnimation {
      showingControls.toggle()
    }
    if showingControls {
      resetControlsTimer()
    }
  }

  private func resetControlsTimer() {
    // Don't start timer when at end page or webtoon at bottom
    if isAtEndPage || (viewModel.readingDirection == .webtoon && isAtBottom) {
      return
    }
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel()
    // Preserve incognito mode for next book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
  }
}
