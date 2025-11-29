//
//  DivinaReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaReaderView: View {
  let incognito: Bool

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("pageLayout") private var pageLayout: PageLayout = .dual

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
  @State private var showHelperOverlay = false
  @State private var helperOverlayTimer: Timer?
  @AppStorage("showReaderHelperOverlay") private var showReaderHelperOverlay: Bool = true

  init(bookId: String, incognito: Bool = false) {
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

  private func shouldUseDualPage(screenSize: CGSize) -> Bool {
    guard screenSize.width > screenSize.height else { return false }  // Only in landscape
    return pageLayout == .dual
  }

  var body: some View {
    GeometryReader { geometry in
      let screenKey = "\(Int(geometry.size.width))x\(Int(geometry.size.height))"
      let useDualPage = shouldUseDualPage(screenSize: geometry.size)

      ZStack {
        readerBackground.color.ignoresSafeArea()

        if !viewModel.pages.isEmpty {
          // Page viewer based on reading direction
          Group {
            switch readingDirection {
            case .ltr:
              if useDualPage {
                ComicDualPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              } else {
                ComicPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              }

            case .rtl:
              if useDualPage {
                MangaDualPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              } else {
                MangaPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              }

            case .vertical:
              if useDualPage {
                VerticalDualPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              } else {
                VerticalPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              }

            case .webtoon:
              #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                WebtoonPageView(
                  viewModel: viewModel,
                  isAtBottom: $isAtBottom,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              #else
                // Webtoon requires UIKit on iOS/iPadOS, fallback to vertical
                VerticalPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: toggleControls,
                  screenSize: geometry.size
                ).ignoresSafeArea()
              #endif
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
          // No pages available
          NoPagesView(
            onDismiss: { dismiss() }
          )
        }

        // Helper overlay (only used on iOS; always rendered, use opacity to control visibility)
        #if os(iOS)
          Group {
            switch readingDirection {
            case .ltr:
              ComicTapZoneOverlay(isVisible: $showHelperOverlay)
            case .rtl:
              MangaTapZoneOverlay(isVisible: $showHelperOverlay)
            case .vertical:
              VerticalTapZoneOverlay(isVisible: $showHelperOverlay)
            case .webtoon:
              WebtoonTapZoneOverlay(isVisible: $showHelperOverlay)
            }
          }
          .ignoresSafeArea()
          .onChange(of: viewModel.pages.count) { oldCount, newCount in
            // Show helper overlay when pages are first loaded
            if oldCount == 0 && newCount > 0 {
              triggerHelperOverlay()
            }
          }
          .onChange(of: showHelperOverlay) { _, newValue in
            if newValue {
              resetHelperOverlayTimer()
            } else {
              helperOverlayTimer?.invalidate()
            }
          }
          .onChange(of: screenKey) {
            // Show helper overlay when screen orientation changes
            if !viewModel.pages.isEmpty {
              triggerHelperOverlay()
            }
          }
        #endif

        // Controls overlay (always rendered, use opacity to control visibility)
        ReaderControlsView(
          showingControls: $showingControls,
          showingReadingDirectionPicker: $showingReadingDirectionPicker,
          readingDirection: $readingDirection,
          viewModel: viewModel,
          currentBook: currentBook,
          bookId: currentBookId,
          dualPage: useDualPage,
          onDismiss: { dismiss() },
          goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
          goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
          showingKeyboardHelp: $showHelperOverlay
        )
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .ignoresSafeArea()
        .opacity(shouldShowControls ? 1.0 : 0.0)
        .allowsHitTesting(shouldShowControls)

        #if canImport(AppKit)
          // Keyboard shortcuts help overlay (independent of controls visibility)
          KeyboardHelpOverlay(
            readingDirection: readingDirection,
            hasTOC: !viewModel.tableOfContents.isEmpty,
            onDismiss: {
              showHelperOverlay = false
            }
          )
          .opacity(showHelperOverlay ? 1.0 : 0.0)
          .allowsHitTesting(showHelperOverlay)
        #endif
      }
    }
    #if canImport(AppKit)
      .background(
        // Window-level keyboard event handler for keyboard help
        KeyboardEventHandler(
          onKeyPress: { keyCode, flags in
            // Handle ? key for keyboard help
            if keyCode == 44 {  // ? key (Shift + /)
              showingKeyboardHelp.toggle()
            }
          }
        )
      )
    #endif
    .ignoresSafeArea()
    #if os(iOS)
      .statusBar(hidden: !shouldShowControls)
    #endif
    #if canImport(AppKit)
      .onAppear {
        // Optionally show helper overlay briefly on macOS when enabled in settings
        triggerHelperOverlay()
      }
    #endif
    .task(id: currentBookId) {
      await loadBook(bookId: currentBookId)
    }
    .onDisappear {
      controlsTimer?.invalidate()
      helperOverlayTimer?.invalidate()
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
        let direction = ReadingDirection.fromString(readingDirectionString)
        // Fallback to vertical if webtoon is not supported on current platform
        readingDirection = direction.isSupported ? direction : .vertical
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
      initialPageNumber: resumePageNumber,
    )

    // Only preload pages if pages are available
    if viewModel.pages.isEmpty {
      return
    }
    await viewModel.preloadPages()
    // Start timer to auto-hide controls after 3 seconds when entering reader
    resetControlsTimer()
  }

  private func goToNextPage(dualPageEnabled: Bool) {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      // Use dual-page logic only when enabled
      if dualPageEnabled {
        // Check if we're in dual page mode by checking if currentPageIndex has a PagePair
        let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
        if let currentPair = currentPair {
          // Dual page mode: calculate next page based on current pair
          if let second = currentPair.second {
            viewModel.targetPageIndex = min(viewModel.pages.count, second + 1)
          } else {
            viewModel.targetPageIndex = min(viewModel.pages.count, currentPair.first + 1)
          }
        } else {
          // If pair info is missing, fallback to single-page increment
          let next = min(viewModel.currentPageIndex + 1, viewModel.pages.count)
          viewModel.targetPageIndex = next
        }
      } else {
        // Single page mode: simple increment
        let next = min(viewModel.currentPageIndex + 1, viewModel.pages.count)
        viewModel.targetPageIndex = next
      }
    case .webtoon:
      // webtoon do not have an end page
      let next = min(viewModel.currentPageIndex + 1, viewModel.pages.count - 1)
      withAnimation {
        viewModel.currentPageIndex = next
      }
    }
  }

  private func goToPreviousPage(dualPageEnabled: Bool) {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      guard viewModel.currentPageIndex > 0 else { return }
      if dualPageEnabled {
        // Check if we're in dual page mode by checking if currentPageIndex has a PagePair
        let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
        if let currentPair = currentPair {
          // Dual page mode: go to previous pair's first page
          viewModel.targetPageIndex = max(0, currentPair.first - 1)
        } else {
          // If pair info is missing, fallback to single-page decrement
          let previous = viewModel.currentPageIndex - 1
          viewModel.targetPageIndex = previous
        }
      } else {
        // Single page mode: simple decrement
        let previous = viewModel.currentPageIndex - 1
        viewModel.targetPageIndex = previous
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
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }

  /// Show reader helper overlay (Tap zones on iOS, keyboard help on macOS)
  private func triggerHelperOverlay() {
    // Respect user preference and ensure we have content
    guard showReaderHelperOverlay, !viewModel.pages.isEmpty else { return }

    // Restart overlay with a tiny delay so animations look nicer
    showHelperOverlay = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      showHelperOverlay = true
      resetHelperOverlayTimer()
    }
  }

  /// Auto-hide helper overlay after a platform-specific delay
  private func resetHelperOverlayTimer() {
    helperOverlayTimer?.invalidate()
    let timeout: TimeInterval
    #if os(iOS)
      timeout = 1.5
    #elseif os(macOS)
      timeout = 2.0
    #else
      timeout = 1.5
    #endif

    helperOverlayTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      withAnimation {
        showHelperOverlay = false
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
    showHelperOverlay = false
  }

}

#if canImport(AppKit)
  import AppKit

  // Window-level keyboard event handler
  private struct KeyboardEventHandler: NSViewRepresentable {
    let onKeyPress: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyboardHandlerView {
      let view = KeyboardHandlerView()
      view.onKeyPress = onKeyPress
      return view
    }

    func updateNSView(_ nsView: KeyboardHandlerView, context: Context) {
      nsView.onKeyPress = onKeyPress
    }
  }

  private class KeyboardHandlerView: NSView {
    var onKeyPress: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool {
      return true
    }

    override func becomeFirstResponder() -> Bool {
      return true
    }

    override func keyDown(with event: NSEvent) {
      onKeyPress?(event.keyCode, event.modifierFlags)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Make this view the first responder when added to window
      DispatchQueue.main.async { [weak self] in
        self?.window?.makeFirstResponder(self)
      }
    }
  }
#endif
