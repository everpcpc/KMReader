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

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  @Environment(\.dismiss) private var dismiss

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var isAtBottom = false
  @State private var showingReadingDirectionPicker = false
  @State private var readingDirection: ReadingDirection = .ltr
  @State private var showTapZoneOverlay = false
  @State private var overlayTimer: Timer?

  init(bookId: String, incognito: Bool = false) {
    self.initialBookId = bookId
    self.incognito = incognito
    self._currentBookId = State(initialValue: bookId)
  }

  var shouldShowControls: Bool {
    // Always show controls when no pages are loaded or when explicitly shown
    viewModel.pages.isEmpty || showingControls || isShowingEndPage
      || (readingDirection == .webtoon && isAtBottom)
  }

  private var isShowingEndPage: Bool {
    guard !viewModel.pages.isEmpty else { return false }
    return viewModel.currentPageIndex >= viewModel.pages.count
  }

  var body: some View {
    GeometryReader { geometry in
      let screenKey = "\(Int(geometry.size.width))x\(Int(geometry.size.height))"
      let screenSize = geometry.size

      ZStack {
        readerBackground.color.ignoresSafeArea()

        if !viewModel.pages.isEmpty {
          // Page viewer based on reading direction
          Group {
            switch readingDirection {
            case .ltr:
              ComicPageView(
                viewModel: viewModel,
                nextBook: nextBook,
                onDismiss: { dismiss() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: goToNextPage,
                goToPreviousPage: goToPreviousPage,
                toggleControls: toggleControls,
                screenSize: screenSize
              ).ignoresSafeArea()
            case .rtl:
              MangaPageView(
                viewModel: viewModel,
                nextBook: nextBook,
                onDismiss: { dismiss() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: goToNextPage,
                goToPreviousPage: goToPreviousPage,
                toggleControls: toggleControls,
                screenSize: screenSize
              ).ignoresSafeArea()
            case .vertical:
              VerticalPageView(
                viewModel: viewModel,
                nextBook: nextBook,
                onDismiss: { dismiss() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: goToNextPage,
                goToPreviousPage: goToPreviousPage,
                toggleControls: toggleControls,
                screenSize: screenSize
              ).ignoresSafeArea()
            case .webtoon:
              WebtoonPageView(
                viewModel: viewModel,
                currentPage: currentPageBinding,
                isAtBottom: $isAtBottom,
                nextBook: nextBook,
                onDismiss: { dismiss() },
                onNextBook: { openNextBook(nextBookId: $0) },
                toggleControls: toggleControls,
                screenSize: screenSize
              ).ignoresSafeArea()
            }
          }
          .id(screenKey)
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

        // Tap zone overlay(always rendered, use opacity to control visibility)
        Group {
          switch readingDirection {
          case .ltr:
            ComicTapZoneOverlay(isVisible: $showTapZoneOverlay)
          case .rtl:
            MangaTapZoneOverlay(isVisible: $showTapZoneOverlay)
          case .vertical:
            VerticalTapZoneOverlay(isVisible: $showTapZoneOverlay)
          case .webtoon:
            WebtoonTapZoneOverlay(isVisible: $showTapZoneOverlay)
          }
        }
        .ignoresSafeArea()
        .onChange(of: viewModel.pages.count) { oldCount, newCount in
          // Show tap zone overlay when pages are first loaded
          if oldCount == 0 && newCount > 0 {
            triggerTapZoneDisplay()
          }
        }
        .onChange(of: showTapZoneOverlay) { _, newValue in
          if newValue {
            resetOverlayTimer()
          } else {
            overlayTimer?.invalidate()
          }
        }
        .onChange(of: screenKey) {
          // Show tap zone overlay when screen orientation changes
          if !viewModel.pages.isEmpty {
            triggerTapZoneDisplay()
          }
        }

        // Controls overlay (always rendered, use opacity to control visibility)
        ReaderControlsView(
          showingControls: $showingControls,
          showingReadingDirectionPicker: $showingReadingDirectionPicker,
          readingDirection: $readingDirection,
          viewModel: viewModel,
          currentBook: currentBook,
          onDismiss: { dismiss() }
        )
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .ignoresSafeArea()
        .opacity(shouldShowControls ? 1.0 : 0.0)
        .allowsHitTesting(shouldShowControls)
      }
    }
    .ignoresSafeArea()
    .statusBar(hidden: !shouldShowControls)
    .task(id: currentBookId) {
      await loadBook(bookId: currentBookId)
    }
    .onDisappear {
      controlsTimer?.invalidate()
      overlayTimer?.invalidate()
    }
  }

  private func loadBook(bookId: String) async {
    // Mark that loading has started
    viewModel.isLoading = true

    // Set incognito mode
    viewModel.incognitoMode = incognito

    // Reset isAtBottom when switching to a new book
    isAtBottom = false

    // Load book info to get read progress page and series reading direction
    var initialPageNumber: Int? = nil
    do {
      let book = try await BookService.shared.getBook(id: bookId)
      currentBook = book
      seriesId = book.seriesId
      // In incognito mode, always start from the first page
      initialPageNumber = incognito ? nil : book.readProgress?.page

      // Get series reading direction
      let series = try await SeriesService.shared.getOneSeries(id: book.seriesId)
      if let readingDirectionString = series.metadata.readingDirection {
        readingDirection = ReadingDirection.fromString(readingDirectionString)
      }

      // Load next book
      if let nextBook = try await BookService.shared.getNextBook(bookId: bookId) {
        self.nextBook = nextBook
      } else {
        nextBook = nil
      }
    } catch {
      // Silently fail, will start from first page
    }

    let resumePageNumber = viewModel.currentPage?.number ?? initialPageNumber

    await viewModel.loadPages(
      bookId: bookId,
      initialPageNumber: resumePageNumber
    )

    // Only preload pages if pages are available
    if viewModel.pages.isEmpty {
      return
    }
    await viewModel.preloadPages()
    // Start timer to auto-hide controls after 3 seconds when entering reader
    resetControlsTimer()
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
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      let next = max(0, min(viewModel.currentPageIndex + 1, viewModel.pages.count - 1))
      withAnimation {
        viewModel.currentPageIndex = next
      }
    case .webtoon:
      // webtoon do not have an end page
      let next = max(0, min(viewModel.currentPageIndex + 1, viewModel.pages.count - 1))
      withAnimation {
        viewModel.currentPageIndex = next
      }
    }
  }

  private func goToPreviousPage() {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      guard viewModel.currentPageIndex > 0 else { return }
      let current = min(viewModel.currentPageIndex, viewModel.pages.count)
      withAnimation {
        viewModel.currentPageIndex = current - 1
      }
    case .webtoon:
      guard viewModel.currentPageIndex > 0 else { return }
      withAnimation {
        viewModel.currentPageIndex -= 1
      }
    }
  }

  private func toggleControls() {
    // Don't hide controls when at end page or webtoon at bottom
    if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
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
    if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
      return
    }
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }

  private func triggerTapZoneDisplay() {
    guard !viewModel.pages.isEmpty else { return }
    showTapZoneOverlay = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      showTapZoneOverlay = true
    }
  }

  private func resetOverlayTimer() {
    overlayTimer?.invalidate()
    overlayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
      withAnimation {
        showTapZoneOverlay = false
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
    // Reset overlay state
    showTapZoneOverlay = false
  }
}
