//
//  DivinaReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaReaderView: View {
  let incognito: Bool

  @State private var readerBackground: ReaderBackground
  @State private var readingDirection: ReadingDirection
  @State private var pageLayout: PageLayout
  @State private var dualPageNoCover: Bool
  @State private var webtoonPageWidthPercentage: Double

  @Environment(\.dismiss) private var dismiss

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var isAtBottom = false
  @State private var showHelperOverlay = false
  @State private var helperOverlayTimer: Timer?
  @AppStorage("showReaderHelperOverlay") private var showReaderHelperOverlay: Bool = true
  #if os(tvOS)
    @State private var isEndPageButtonFocused = false
    private enum ReaderFocusAnchor: Hashable {
      case contentGuard
    }
    @FocusState private var readerFocusAnchor: ReaderFocusAnchor?
  #endif

  init(bookId: String, incognito: Bool = false) {
    self.incognito = incognito
    self._currentBookId = State(initialValue: bookId)
    self._readerBackground = State(initialValue: AppConfig.readerBackground)
    self._readingDirection = State(initialValue: AppConfig.defaultReadingDirection)
    self._pageLayout = State(initialValue: AppConfig.pageLayout)
    self._dualPageNoCover = State(initialValue: AppConfig.dualPageNoCover)
    self._webtoonPageWidthPercentage = State(initialValue: AppConfig.webtoonPageWidthPercentage)
  }

  var shouldShowControls: Bool {
    // Always show controls when no pages are loaded or when explicitly shown
    #if os(tvOS)
      // On tvOS, don't force controls at endpage to allow navigation back
      viewModel.pages.isEmpty || showingControls
        || (readingDirection == .webtoon && isAtBottom)
    #else
      viewModel.pages.isEmpty || showingControls || isShowingEndPage
        || (readingDirection == .webtoon && isAtBottom)
    #endif
  }

  private var isShowingEndPage: Bool {
    guard !viewModel.pages.isEmpty else { return false }
    return viewModel.currentPageIndex >= viewModel.pages.count
  }

  private func shouldUseDualPage(screenSize: CGSize) -> Bool {
    guard screenSize.width > screenSize.height else { return false }  // Only in landscape
    return pageLayout == .dual
  }

  private func resetReaderPreferencesForCurrentBook() {
    readerBackground = AppConfig.readerBackground
    pageLayout = AppConfig.pageLayout
    dualPageNoCover = AppConfig.dualPageNoCover
    webtoonPageWidthPercentage = AppConfig.webtoonPageWidthPercentage
    readingDirection = AppConfig.defaultReadingDirection
  }

  #if os(tvOS)
    private var endPageFocusChangeHandler: ((Bool) -> Void) {
      { isFocused in
        // isFocused is true when any button in EndPageView has focus
        isEndPageButtonFocused = isFocused
      }
    }
  #else
    private var endPageFocusChangeHandler: ((Bool) -> Void)? {
      nil
    }
  #endif

  var body: some View {
    GeometryReader { geometry in
      let screenKey = "\(Int(geometry.size.width))x\(Int(geometry.size.height))"
      let useDualPage = shouldUseDualPage(screenSize: geometry.size)

      ZStack {
        readerBackground.color.ignoresSafeArea()
        #if os(tvOS)
          // Invisible focus anchor that receives focus when controls are hidden.
          Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .focusable(true)
            .focused($readerFocusAnchor, equals: .contentGuard)
            .opacity(0.001)
        #endif

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
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
                ).ignoresSafeArea()
              } else {
                ComicPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
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
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
                ).ignoresSafeArea()
              } else {
                MangaPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
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
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
                ).ignoresSafeArea()
              } else {
                VerticalPageView(
                  viewModel: viewModel,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
                ).ignoresSafeArea()
              }

            case .webtoon:
              #if os(iOS)
                WebtoonPageView(
                  viewModel: viewModel,
                  isAtBottom: $isAtBottom,
                  nextBook: nextBook,
                  onDismiss: { dismiss() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  pageWidthPercentage: webtoonPageWidthPercentage,
                  readerBackground: readerBackground
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
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
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
          .onChange(of: screenKey) {
            // Show helper overlay when screen orientation changes
            triggerHelperOverlay(timeout: 1)
          }
        #endif

        // Controls overlay (always rendered, use opacity to control visibility)
        ReaderControlsView(
          showingControls: $showingControls,
          showingKeyboardHelp: $showHelperOverlay,
          readingDirection: $readingDirection,
          readerBackground: $readerBackground,
          pageLayout: $pageLayout,
          dualPageNoCover: $dualPageNoCover,
          webtoonPageWidthPercentage: $webtoonPageWidthPercentage,
          viewModel: viewModel,
          currentBook: currentBook,
          bookId: currentBookId,
          dualPage: useDualPage,
          onDismiss: { dismiss() },
          goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
          goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
          nextBook: nextBook,
          onNextBook: { openNextBook(nextBookId: $0) }
        )
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .ignoresSafeArea()
        .opacity(shouldShowControls ? 1.0 : 0.0)
        .allowsHitTesting(shouldShowControls)

        #if os(macOS)
          // Keyboard shortcuts help overlay (independent of controls visibility)
          KeyboardHelpOverlay(
            readingDirection: readingDirection,
            hasTOC: !viewModel.tableOfContents.isEmpty,
            hasNextBook: nextBook != nil,
            onDismiss: {
              hideOverlay()
            }
          )
          .opacity(showHelperOverlay ? 1.0 : 0.0)
          .allowsHitTesting(showHelperOverlay)
        #endif

      }
      #if os(tvOS)
        .onPlayPauseCommand {
          // Manual toggle on tvOS should not auto-hide
          toggleControls(autoHide: false)
        }
        .onMoveCommand { direction in
          if showingControls {
            return
          }
          if isEndPageButtonFocused {
            return
          }

          let useDualPage = shouldUseDualPage(screenSize: geometry.size)

          // Execute page navigation
          switch readingDirection {
          case .ltr, .rtl:
            // Horizontal navigation
            switch direction {
            case .left:
              // RTL: left means next, LTR: left means previous
              if readingDirection == .rtl {
                goToNextPage(dualPageEnabled: useDualPage)
              } else {
                goToPreviousPage(dualPageEnabled: useDualPage)
              }
            case .right:
              // RTL: right means previous, LTR: right means next
              if readingDirection == .rtl {
                goToPreviousPage(dualPageEnabled: useDualPage)
              } else {
                goToNextPage(dualPageEnabled: useDualPage)
              }
            default:
              break
            }
          case .vertical:
            // Vertical navigation
            switch direction {
            case .up:
              goToPreviousPage(dualPageEnabled: useDualPage)
            case .down:
              goToNextPage(dualPageEnabled: useDualPage)
            default:
              break
            }
          case .webtoon:
            // Webtoon navigation (vertical)
            switch direction {
            case .up:
              goToPreviousPage(dualPageEnabled: useDualPage)
            case .down:
              goToNextPage(dualPageEnabled: useDualPage)
            default:
              break
            }
          }
        }
      #endif
    }
    #if os(macOS)
      .background(
        // Window-level keyboard event handler for keyboard help
        KeyboardEventHandler(
          onKeyPress: { keyCode, flags in
            // Handle ? key for keyboard help
            if keyCode == 44 {  // ? key (Shift + /)
              if showHelperOverlay {
                hideOverlay()
              } else {
                triggerHelperOverlay(timeout: 3)
              }
            }
          }
        )
      )
    #endif
    .ignoresSafeArea()
    #if os(iOS)
      .statusBar(hidden: !shouldShowControls)
    #endif
    .onAppear {
      viewModel.updateDualPageSettings(noCover: dualPageNoCover)
      #if os(tvOS)
        updateContentFocusAnchor()
      #endif
    }
    .onChange(of: dualPageNoCover) { _, newValue in
      viewModel.updateDualPageSettings(noCover: newValue)
    }
    .task(id: currentBookId) {
      resetReaderPreferencesForCurrentBook()
      await loadBook(bookId: currentBookId)
    }
    .onChange(of: viewModel.pages.count) { oldCount, newCount in
      // Show helper overlay when pages are first loaded (iOS and macOS)
      if oldCount == 0 && newCount > 0 {
        triggerHelperOverlay(timeout: 1)
      }
    }
    .onDisappear {
      controlsTimer?.invalidate()
      helperOverlayTimer?.invalidate()
    }
    #if os(macOS) || os(tvOS)
      .onChange(of: showingControls) { oldValue, newValue in
        // On macOS and tvOS, if controls are manually shown (from false to true),
        // cancel auto-hide timer to prevent auto-hiding
        if newValue && !oldValue {
          // User manually opened controls (via C key on macOS or play/pause on tvOS),
          // cancel any existing auto-hide timer
          controlsTimer?.invalidate()
        }
        #if os(tvOS)
          updateContentFocusAnchor()
        #endif
      }
    #endif
      .environment(\.readerBackgroundPreference, readerBackground)
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
    resetControlsTimer(timeout: 1)
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

  #if os(tvOS)
    private func updateContentFocusAnchor() {
      readerFocusAnchor = showingControls ? nil : .contentGuard
    }
  #endif

  private func toggleControls(autoHide: Bool = true) {
    #if os(tvOS)
      // On tvOS, allow toggling controls even at endpage to enable navigation back
      // Only prevent hiding for webtoon at bottom
      if readingDirection == .webtoon && isAtBottom {
        return
      }
    #else
      // Don't hide controls when at end page or webtoon at bottom
      if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
        return
      }
    #endif
    withAnimation {
      showingControls.toggle()
    }
    if showingControls {
      // Only auto-hide if autoHide is true
      // On macOS and tvOS, manual toggle should not auto-hide
      if autoHide {
        resetControlsTimer(timeout: 3)
      } else {
        // Cancel any existing timer when manually opened
        controlsTimer?.invalidate()
      }
    }
  }

  private func resetControlsTimer(timeout: TimeInterval) {
    #if os(tvOS)
      // On tvOS, allow timer to hide controls even at endpage
      // Only prevent for webtoon at bottom
      if readingDirection == .webtoon && isAtBottom {
        return
      }
    #else
      // Don't start timer when at end page or webtoon at bottom
      if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
        return
      }
    #endif

    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      withAnimation {
        showingControls = false
      }
    }
  }

  /// Hide helper overlay and cancel timer
  private func hideOverlay() {
    helperOverlayTimer?.invalidate()
    showHelperOverlay = false
  }

  /// Show reader helper overlay (Tap zones on iOS, keyboard help on macOS)
  private func triggerHelperOverlay(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showReaderHelperOverlay, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.showHelperOverlay = true
      self.resetHelperOverlayTimer(timeout: timeout)
    }
  }

  /// Auto-hide helper overlay after a platform-specific delay
  private func resetHelperOverlayTimer(timeout: TimeInterval) {
    helperOverlayTimer?.invalidate()
    helperOverlayTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        withAnimation {
          self.hideOverlay()
        }
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    currentBookId = nextBookId
    resetReaderPreferencesForCurrentBook()
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(dualPageNoCover: dualPageNoCover)
    // Preserve incognito mode for next book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideOverlay()
  }

}
