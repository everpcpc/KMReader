//
//  DivinaReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaReaderView: View {
  let incognito: Bool
  let readList: ReadList?
  let onClose: (() -> Void)?

  @State private var readerBackground: ReaderBackground
  @State private var readingDirection: ReadingDirection
  @State private var pageLayout: PageLayout
  @State private var dualPageNoCover: Bool
  @State private var webtoonPageWidthPercentage: Double

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var previousBook: Book?
  @State private var isAtBottom = false
  @State private var showTapZoneOverlay = false
  @State private var tapZoneOverlayTimer: Timer?
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @State private var showKeyboardHelp = false
  @State private var keyboardHelpTimer: Timer?
  @State private var preserveReaderOptions = false
  #if os(tvOS)
    @State private var isEndPageButtonFocused = false
    private enum ReaderFocusAnchor: Hashable {
      case contentGuard
    }
    @FocusState private var readerFocusAnchor: ReaderFocusAnchor?
  #endif

  init(
    bookId: String,
    incognito: Bool = false,
    readList: ReadList? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.incognito = incognito
    self.readList = readList
    self.onClose = onClose
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
    guard pageLayout != .single else { return false }
    return readingDirection != .vertical
  }

  private func closeReader() {
    if let onClose {
      onClose()
    } else {
      dismiss()
    }
  }

  private func resetReaderPreferencesForCurrentBook() {
    readerBackground = AppConfig.readerBackground
    pageLayout = AppConfig.pageLayout
    viewModel.updatePageLayout(pageLayout)
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
        readerBackground.color.readerIgnoresSafeArea()
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
            if readingDirection == .webtoon {
              #if os(iOS) || os(macOS)
                WebtoonPageView(
                  viewModel: viewModel,
                  isAtBottom: $isAtBottom,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  pageWidthPercentage: webtoonPageWidthPercentage,
                  readerBackground: readerBackground
                )
                .readerIgnoresSafeArea()
              #else
                // Webtoon requires UIKit/AppKit, fallback to vertical
                PageView(
                  mode: .vertical,
                  readingDirection: readingDirection,
                  viewModel: viewModel,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                  goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                  toggleControls: { toggleControls() },
                  screenSize: geometry.size,
                  onEndPageFocusChange: endPageFocusChangeHandler
                )
                .readerIgnoresSafeArea()
              #endif
            } else {
              PageView(
                mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                readingDirection: readingDirection,
                viewModel: viewModel,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
                goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
                toggleControls: { toggleControls() },
                screenSize: geometry.size,
                onEndPageFocusChange: endPageFocusChangeHandler
              )
              .readerIgnoresSafeArea()
            }
          }
          .id("\(currentBookId)-\(screenKey)-\(readingDirection)")
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
            onDismiss: { closeReader() }
          )
        }

        // Helper overlay (iOS: always, macOS: with keyboard help)
        #if os(iOS) || os(macOS)
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
          .readerIgnoresSafeArea()
          .onChange(of: screenKey) {
            // Show helper overlay when screen orientation changes
            triggerTapZoneOverlay(timeout: 1)
          }
        #endif

        // Controls overlay (always rendered, use opacity to control visibility)
        ReaderControlsView(
          showingControls: $showingControls,
          showingKeyboardHelp: $showKeyboardHelp,
          readingDirection: $readingDirection,
          readerBackground: $readerBackground,
          pageLayout: $pageLayout,
          dualPageNoCover: $dualPageNoCover,
          webtoonPageWidthPercentage: $webtoonPageWidthPercentage,
          viewModel: viewModel,
          currentBook: currentBook,
          bookId: currentBookId,
          dualPage: useDualPage,
          onDismiss: { closeReader() },
          goToNextPage: { goToNextPage(dualPageEnabled: useDualPage) },
          goToPreviousPage: { goToPreviousPage(dualPageEnabled: useDualPage) },
          previousBook: previousBook,
          nextBook: nextBook,
          onPreviousBook: { openPreviousBook(previousBookId: $0) },
          onNextBook: { openNextBook(nextBookId: $0) }
        )
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .readerIgnoresSafeArea()
        .opacity(shouldShowControls ? 1.0 : 0.0)
        .allowsHitTesting(shouldShowControls)
        .animation(.default, value: shouldShowControls)

        #if os(macOS)
          // Keyboard shortcuts help overlay (independent of controls visibility)
          KeyboardHelpOverlay(
            readingDirection: readingDirection,
            hasTOC: !viewModel.tableOfContents.isEmpty,
            hasNextBook: nextBook != nil,
            onDismiss: {
              hideKeyboardHelp()
            }
          )
          .opacity(showKeyboardHelp ? 1.0 : 0.0)
          .allowsHitTesting(showKeyboardHelp)
        #endif

      }
      #if os(tvOS)
        .onPlayPauseCommand {
          // Manual toggle on tvOS should not auto-hide
          toggleControls(autoHide: false)
        }
        .onExitCommand {
          // Back button hides controls first; second press dismisses reader
          if showingControls {
            toggleControls(autoHide: false)
          } else {
            closeReader()
          }
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
              if showKeyboardHelp {
                hideKeyboardHelp()
              } else {
                triggerKeyboardHelp(timeout: 3)
              }
            }
          }
        )
      )
    #endif
    .readerIgnoresSafeArea()
    .onAppear {
      viewModel.updateDualPageSettings(noCover: dualPageNoCover)
      #if os(tvOS)
        updateContentFocusAnchor()
      #endif
    }
    .onChange(of: dualPageNoCover) { _, newValue in
      viewModel.updateDualPageSettings(noCover: newValue)
    }
    .onChange(of: pageLayout) { _, newValue in
      viewModel.updatePageLayout(newValue)
    }
    .task(id: currentBookId) {
      if !preserveReaderOptions {
        resetReaderPreferencesForCurrentBook()
      }
      await loadBook(bookId: currentBookId, preserveReaderOptions: preserveReaderOptions)
      preserveReaderOptions = false
    }
    .onChange(of: viewModel.pages.count) { oldCount, newCount in
      // Show helper overlay when pages are first loaded (iOS and macOS)
      if oldCount == 0 && newCount > 0 {
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 2)
      }
    }
    .onDisappear {
      controlsTimer?.invalidate()
      tapZoneOverlayTimer?.invalidate()
      keyboardHelpTimer?.invalidate()
      withAnimation {
        readerPresentation.hideStatusBar = false
      }
    }
    .onChange(of: shouldShowControls) { _, newValue in
      withAnimation {
        readerPresentation.hideStatusBar = !newValue
      }
    }
    #if os(iOS) || os(macOS)
      .onChange(of: readingDirection) { _, _ in
        // When switching read mode via settings, briefly show overlays again
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 2)
      }
    #endif
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

  private func loadBook(bookId: String, preserveReaderOptions: Bool) async {
    // Mark that loading has started
    viewModel.isLoading = true

    // Set incognito mode
    viewModel.incognitoMode = incognito

    // Reset isAtBottom when switching to a new book
    isAtBottom = false

    // Load book info to get read progress page and series reading direction
    var initialPageNumber: Int? = nil

    // 1. Try to get book from DB
    if let book = await DatabaseOperator.shared.fetchBook(id: bookId) {
      currentBook = book
      seriesId = book.seriesId
      initialPageNumber = incognito ? nil : book.readProgress?.page
    } else if !AppConfig.isOffline {
      // 2. Fetch from network if not in DB and online
      do {
        let book = try await SyncService.shared.syncBook(bookId: bookId)
        currentBook = book
        seriesId = book.seriesId
        initialPageNumber = incognito ? nil : book.readProgress?.page
      } catch {
        // Fail silently
      }
    }

    if let activeBook = currentBook {
      // 3. Try to get series from DB
      var series = await DatabaseOperator.shared.fetchSeries(id: activeBook.seriesId)
      if series == nil && !AppConfig.isOffline {
        series = try? await SyncService.shared.syncSeriesDetail(seriesId: activeBook.seriesId)
      }

      if let series = series {
        let rawReadingDirection = series.metadata.readingDirection?
          .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let preferredDirection: ReadingDirection
        if let rawReadingDirection, !rawReadingDirection.isEmpty {
          preferredDirection = ReadingDirection.fromString(rawReadingDirection)
        } else {
          preferredDirection = AppConfig.defaultReadingDirection
        }
        if !preserveReaderOptions {
          readingDirection = preferredDirection.isSupported ? preferredDirection : .vertical
        }
      }

      // 4. Try to get next/previous books from DB
      self.nextBook = await DatabaseOperator.shared.getNextBook(
        instanceId: AppConfig.currentInstanceId,
        bookId: bookId,
        readListId: readList?.id
      )
      if self.nextBook == nil && !AppConfig.isOffline {
        self.nextBook = await SyncService.shared.syncNextBook(
          bookId: bookId, readListId: readList?.id)
      }

      self.previousBook = await DatabaseOperator.shared.getPreviousBook(
        instanceId: AppConfig.currentInstanceId,
        bookId: bookId,
        readListId: readList?.id
      )
      if self.previousBook == nil && !AppConfig.isOffline {
        self.previousBook = await SyncService.shared.syncPreviousBook(bookId: bookId)
      }
    }

    let resumePageNumber = viewModel.currentPage?.number ?? initialPageNumber

    guard let activeBook = currentBook, activeBook.id == bookId else {
      viewModel.isLoading = false
      return
    }

    await viewModel.loadPages(
      book: activeBook,
      initialPageNumber: resumePageNumber
    )

    // Only preload pages if pages are available
    if viewModel.pages.isEmpty {
      return
    }
    await viewModel.preloadPages()
    #if os(tvOS)
      // Keep controls visible on tvOS when first entering reader
    #else
      // Start timer to auto-hide controls shortly after entering reader
      resetControlsTimer(timeout: 1)
    #endif
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

  #if os(tvOS)
    private func toggleControls(autoHide: Bool = true) {
      // On tvOS, allow toggling controls even at endpage to enable navigation back
      // Only prevent hiding for webtoon at bottom
      if readingDirection == .webtoon && isAtBottom {
        return
      }
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        // On tvOS, manual toggle should not auto-hide
        // Cancel any existing timer when manually opened
        controlsTimer?.invalidate()
      }
    }
  #else
    private func toggleControls(autoHide: Bool = true) {
      // Don't hide controls when at end page or webtoon at bottom
      if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
        return
      }
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        // Only auto-hide if autoHide is true
        // On macOS, manual toggle should not auto-hide
        if autoHide {
          resetControlsTimer(timeout: 3)
        } else {
          // Cancel any existing timer when manually opened
          controlsTimer?.invalidate()
        }
      }
    }
  #endif

  #if os(tvOS)
    private func resetControlsTimer(timeout: TimeInterval) {
      // Controls remain visible on tvOS
      // No-op on tvOS
    }
  #else
    private func resetControlsTimer(timeout: TimeInterval) {
      // Don't start timer when at end page or webtoon at bottom
      if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
        return
      }

      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        withAnimation {
          showingControls = false
        }
      }
    }
  #endif

  /// Hide helper overlay and cancel timer
  private func hideTapZoneOverlay() {
    tapZoneOverlayTimer?.invalidate()
    showTapZoneOverlay = false
  }

  /// Show reader helper overlay (Tap zones on iOS, keyboard help on macOS)
  private func triggerTapZoneOverlay(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showTapZoneHints, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.showTapZoneOverlay = true
      self.resetTapZoneOverlayTimer(timeout: timeout)
    }
  }

  /// Auto-hide helper overlay after a platform-specific delay
  private func resetTapZoneOverlayTimer(timeout: TimeInterval) {
    tapZoneOverlayTimer?.invalidate()
    tapZoneOverlayTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        withAnimation {
          self.hideTapZoneOverlay()
        }
      }
    }
  }

  /// Hide keyboard help overlay and cancel timer
  private func hideKeyboardHelp() {
    keyboardHelpTimer?.invalidate()
    showKeyboardHelp = false
  }

  /// Show keyboard help overlay
  private func triggerKeyboardHelp(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showKeyboardHelpOverlay, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.showKeyboardHelp = true
      self.resetKeyboardHelpTimer(timeout: timeout)
    }
  }

  /// Auto-hide keyboard help overlay after a delay
  private func resetKeyboardHelpTimer(timeout: TimeInterval) {
    keyboardHelpTimer?.invalidate()
    keyboardHelpTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        withAnimation {
          self.hideKeyboardHelp()
        }
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(dualPageNoCover: dualPageNoCover, pageLayout: pageLayout)
    // Preserve incognito mode for next book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

  private func openPreviousBook(previousBookId: String) {
    // Switch to previous book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = previousBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(dualPageNoCover: dualPageNoCover, pageLayout: pageLayout)
    // Preserve incognito mode for previous book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

}
