//
//  DivinaReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaReaderView: View {
  let book: Book
  let incognito: Bool
  let readList: ReadList?
  let onClose: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  #if os(iOS)
    @AppStorage("pageTransitionStyle") private var pageTransitionStyle: PageTransitionStyle = .scroll
  #endif
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("shakeToOpenLiveText") private var shakeToOpenLiveText: Bool = false
  #if os(iOS)
    @AppStorage("autoHideControls") private var autoHideControls: Bool = false
  #else
    private let autoHideControls: Bool = false
  #endif

  @State private var readingDirection: ReadingDirection
  @State private var pageLayout: PageLayout
  @State private var isolateCoverPage: Bool
  @State private var splitWidePageMode: SplitWidePageMode

  private let logger = AppLogger(.reader)

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @State private var showingControls = false
  @State private var controlsTimer: Timer?
  @State private var currentSeries: Series?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var previousBook: Book?
  @State private var isAtBottom = false
  @State private var showTapZoneOverlay = false
  @State private var tapZoneOverlayTimer: Timer?

  @State private var showKeyboardHelp = false
  @State private var keyboardHelpTimer: Timer?
  @State private var preserveReaderOptions = false

  // UI Panels states
  @State private var showingPageJumpSheet = false
  @State private var showingTOCSheet = false
  @State private var showingReaderSettingsSheet = false
  @State private var showingDetailSheet = false
  @State private var animatedPlaybackURL: URL?
  @State private var animatedPlaybackLoading = false
  @State private var boundaryDragOffset: CGFloat = 0
  private let boundarySwipeThreshold: CGFloat = 120

  #if os(tvOS)
    @State private var lastTVRemoteMoveSignature: String = ""
    @State private var lastTVRemoteMoveTimestamp: TimeInterval = 0
    @State private var lastTVRemoteSelectTimestamp: TimeInterval = 0
    @State private var tvRemoteCaptureGeneration: Int = 0
  #endif

  init(
    book: Book,
    incognito: Bool = false,
    readList: ReadList? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.book = book
    self.incognito = incognito
    self.readList = readList
    self.onClose = onClose
    self._currentBookId = State(initialValue: book.id)
    self._currentBook = State(initialValue: book)
    self._readingDirection = State(initialValue: AppConfig.defaultReadingDirection)
    self._pageLayout = State(initialValue: AppConfig.pageLayout)
    self._isolateCoverPage = State(initialValue: AppConfig.isolateCoverPage)
    self._splitWidePageMode = State(initialValue: AppConfig.splitWidePageMode)
  }

  var shouldShowControls: Bool {
    // Always show controls when no pages are loaded or when explicitly shown
    #if os(tvOS)
      // On tvOS, don't force controls at endpage to allow navigation back
      !viewModel.isZoomed
        && (viewModel.pages.isEmpty || showingControls || (readingDirection == .webtoon && isAtBottom))
    #else
      !viewModel.isZoomed
        && (viewModel.pages.isEmpty || showingControls || isShowingEndPage
          || (readingDirection == .webtoon && isAtBottom))
    #endif
  }

  #if os(iOS)
    private enum BoundaryArcTarget {
      case previous
      case next
    }

    private var boundaryArcColor: Color {
      switch readerBackground {
      case .black:
        return .white
      case .white:
        return .black
      case .gray:
        return .white
      case .system:
        return .primary
      }
    }

    private var boundaryArcTarget: BoundaryArcTarget? {
      guard boundaryDragOffset != 0 else { return nil }

      if readingDirection == .webtoon {
        guard isAtBottom, nextBook != nil else { return nil }
        return readingDirection.isForwardSwipe(boundaryDragOffset) ? .next : nil
      }

      let isAtFirstBoundary = viewModel.currentViewItemIndex == 0
      let isAtEndBoundary =
        !viewModel.viewItems.isEmpty
        && viewModel.currentViewItemIndex == viewModel.viewItems.count - 1

      if isAtFirstBoundary, previousBook != nil, readingDirection.isBackwardSwipe(boundaryDragOffset)
      {
        return .previous
      }
      if isAtEndBoundary, nextBook != nil, readingDirection.isForwardSwipe(boundaryDragOffset) {
        return .next
      }
      return nil
    }

    private var boundaryArcReadingDirection: ReadingDirection {
      switch boundaryArcTarget {
      case .previous:
        switch readingDirection {
        case .ltr:
          return .rtl
        case .rtl:
          return .ltr
        case .vertical:
          return .vertical
        case .webtoon:
          return .webtoon
        }
      case .next:
        return readingDirection
      case .none:
        return readingDirection
      }
    }

    private var boundaryArcProgress: CGFloat {
      guard boundaryArcTarget != nil else { return 0 }
      return min(abs(boundaryDragOffset) / boundarySwipeThreshold, 1.0)
    }
  #endif

  private var handoffBookId: String {
    currentBook?.id ?? book.id
  }

  private var handoffTitle: String {
    currentBook?.metadata.title ?? book.metadata.title
  }

  private var handoffPageNumber: Int? {
    viewModel.currentPage?.number
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

  private func updateHandoff() {
    let url = KomgaWebLinkBuilder.bookReader(
      serverURL: current.serverURL,
      bookId: handoffBookId,
      pageNumber: handoffPageNumber,
      incognito: incognito
    )
    readerPresentation.updateHandoff(title: handoffTitle, url: url)
  }

  private func closeReader() {
    logger.debug(
      "🚪 Closing DIVINA reader for book \(currentBookId), currentPage=\(viewModel.currentPage?.number ?? -1), totalPages=\(viewModel.pages.count)"
    )
    if let onClose {
      onClose()
    } else {
      dismiss()
    }
  }

  private func applyStatusBarVisibility(controlsHidden: Bool) {
    withAnimation {
      readerPresentation.hideStatusBar = controlsHidden
    }
  }

  private func resetReaderPreferencesForCurrentBook() {
    pageLayout = AppConfig.pageLayout
    viewModel.updatePageLayout(pageLayout)
    isolateCoverPage = AppConfig.isolateCoverPage
    splitWidePageMode = AppConfig.splitWidePageMode
    viewModel.updateSplitWidePageMode(splitWidePageMode)
    readingDirection = AppConfig.defaultReadingDirection
  }

  private func screenKey(screenSize: CGSize) -> String {
    return "\(Int(screenSize.width))x\(Int(screenSize.height))"
  }

  private func requestAnimatedPlayback(for pageIndex: Int) {
    guard !animatedPlaybackLoading else { return }
    withAnimation(.easeInOut(duration: 0.18)) {
      animatedPlaybackLoading = true
    }

    Task {
      let fileURL = await viewModel.prepareAnimatedPagePlaybackURL(pageIndex: pageIndex)
      withAnimation(.easeInOut(duration: 0.18)) {
        animatedPlaybackLoading = false
      }
      guard let fileURL else {
        logger.debug("⚠️ Animated playback unavailable for pageIndex=\(pageIndex)")
        return
      }
      controlsTimer?.invalidate()
      showingControls = false
      withAnimation(.easeInOut(duration: 0.22)) {
        animatedPlaybackURL = fileURL
      }
    }
  }

  private func dismissAnimatedPlayback() {
    withAnimation(.easeInOut(duration: 0.2)) {
      animatedPlaybackURL = nil
    }
  }

  #if os(tvOS)
    private var shouldEnableUIKitRemoteCapture: Bool {
      !showingPageJumpSheet
        && !showingTOCSheet
        && !showingReaderSettingsSheet
        && !showingDetailSheet
        && !viewModel.pages.isEmpty
    }

    private func isBackwardTVMove(_ direction: MoveCommandDirection) -> Bool {
      switch readingDirection {
      case .ltr:
        return direction == .left
      case .rtl:
        return direction == .right
      case .vertical, .webtoon:
        return direction == .up
      }
    }

    private func shouldIgnoreDuplicateTVSelectCommand() -> Bool {
      let now = Date().timeIntervalSinceReferenceDate
      let isDuplicate = now - lastTVRemoteSelectTimestamp < 0.08
      lastTVRemoteSelectTimestamp = now
      return isDuplicate
    }

    private func shouldIgnoreDuplicateTVMoveCommand(_ direction: MoveCommandDirection) -> Bool {
      let now = Date().timeIntervalSinceReferenceDate
      let signature = String(describing: direction)
      let isDuplicate =
        lastTVRemoteMoveSignature == signature
        && now - lastTVRemoteMoveTimestamp < 0.08

      if isDuplicate {
        return true
      }

      lastTVRemoteMoveSignature = signature
      lastTVRemoteMoveTimestamp = now
      return false
    }

    private func handleTVMoveCommand(_ direction: MoveCommandDirection, source: String) -> Bool {
      logger.debug(
        "📺 \(source) move direction=\(String(describing: direction)), showingControls=\(showingControls), currentPageIndex=\(viewModel.currentPageIndex), totalPages=\(viewModel.pages.count)"
      )

      if showingControls {
        logger.debug("📺 \(source) move ignored: controls are visible")
        return false
      }
      if viewModel.pages.isEmpty {
        logger.debug("📺 \(source) move ignored: pages are empty")
        return false
      }

      if shouldIgnoreDuplicateTVMoveCommand(direction) {
        logger.debug("📺 \(source) move ignored: duplicate command")
        return true
      }

      if viewModel.currentPageIndex >= viewModel.pages.count {
        if isBackwardTVMove(direction) {
          logger.debug("📺 \(source) move on end page: go to previous page")
          goToPreviousPage()
          return true
        }

        logger.debug("📺 \(source) move ignored on end page: non-backward direction")
        return false
      }

      switch readingDirection {
      case .ltr, .rtl:
        switch direction {
        case .left:
          if readingDirection == .rtl {
            goToNextPage()
          } else {
            goToPreviousPage()
          }
          return true
        case .right:
          if readingDirection == .rtl {
            goToPreviousPage()
          } else {
            goToNextPage()
          }
          return true
        default:
          return false
        }
      case .vertical:
        switch direction {
        case .up:
          goToPreviousPage()
          return true
        case .down:
          goToNextPage()
          return true
        default:
          return false
        }
      case .webtoon:
        switch direction {
        case .up:
          goToPreviousPage()
          return true
        case .down:
          goToNextPage()
          return true
        default:
          return false
        }
      }
    }

    private func handleTVSelectCommand(source: String) -> Bool {
      logger.debug(
        "📺 \(source) select, showingControls=\(showingControls), totalPages=\(viewModel.pages.count), currentPageIndex=\(viewModel.currentPageIndex)"
      )

      if shouldIgnoreDuplicateTVSelectCommand() {
        logger.debug("📺 \(source) select ignored: duplicate command")
        return true
      }

      if showingControls {
        logger.debug("📺 \(source) select ignored: controls are visible")
        return false
      }
      if viewModel.pages.isEmpty {
        logger.debug("📺 \(source) select ignored: pages are empty")
        return false
      }
      if viewModel.currentPageIndex >= viewModel.pages.count {
        logger.debug("📺 \(source) select on end page: toggle controls")
        toggleControls(autoHide: false)
        return true
      }

      toggleControls(autoHide: false)
      return true
    }
  #endif

  var body: some View {
    GeometryReader { geometry in
      let screenSize = geometry.size
      let screenKey = screenKey(screenSize: screenSize)
      let useDualPage = shouldUseDualPage(screenSize: screenSize)

      ZStack {
        readerBackground.color.readerIgnoresSafeArea()

        readerContent(
          useDualPage: useDualPage,
          screenKey: screenKey
        )

        #if os(tvOS)
          tvRemoteCommandOverlay
        #endif

        helperOverlay(screenKey: screenKey)

        #if os(iOS)
          if boundaryArcProgress > 0.01 {
            ArcEffectView(
              color: boundaryArcColor,
              progress: boundaryArcProgress,
              readingDirection: boundaryArcReadingDirection
            )
            .environment(\.layoutDirection, .leftToRight)
            .allowsHitTesting(false)
          }
        #endif

        controlsOverlay(useDualPage: useDualPage)

        if animatedPlaybackLoading {
          ProgressView()
            .padding(16)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(20)
        }

        if let animatedPlaybackURL {
          AnimatedImagePlaybackOverlay(
            fileURL: animatedPlaybackURL,
            onClose: dismissAnimatedPlayback
          )
          .transition(.opacity)
          .zIndex(30)
        }

        #if os(macOS)
          keyboardHelpOverlay
        #endif
      }
      #if os(tvOS)
        .onPlayPauseCommand {
          logger.debug("📺 onPlayPauseCommand: toggling controls, showingControls=\(showingControls)")
          toggleControls(autoHide: false)
        }
        .onExitCommand {
          logger.debug("📺 onExitCommand: showingControls=\(showingControls)")
          if showingControls {
            toggleControls(autoHide: false)
          } else {
            closeReader()
          }
        }
      #endif
      #if os(macOS)
        .background(
          // Window-level keyboard event handler
          KeyboardEventHandler(
            onKeyPress: { keyCode, flags in
              handleKeyCode(keyCode, flags: flags)
            }
          )
        )
      #endif
    }
    .iPadIgnoresSafeArea()
    #if os(iOS)
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        if shakeToOpenLiveText {
          enableLiveText.toggle()
          let message = enableLiveText ? String(localized: "Live Text: ON") : String(localized: "Live Text: OFF")
          ErrorManager.shared.notify(message: message)
        }
      }
    #endif
    .sheet(isPresented: $showingPageJumpSheet) {
      PageJumpSheetView(
        bookId: currentBookId,
        totalPages: viewModel.pages.count,
        currentPage: min(viewModel.currentPageIndex + 1, viewModel.pages.count),
        readingDirection: readingDirection,
        viewModel: viewModel,
        onJump: jumpToPage
      )
    }
    .sheet(isPresented: $showingTOCSheet) {
      DivinaTOCSheetView(
        entries: viewModel.tableOfContents,
        currentPageIndex: viewModel.currentPageIndex,
        onSelect: { entry in
          showingTOCSheet = false
          jumpToTOCEntry(entry)
        }
      )
    }
    .sheet(isPresented: $showingReaderSettingsSheet) {
      ReaderSettingsSheet(readingDirection: $readingDirection)
    }
    .readerDetailSheet(
      isPresented: $showingDetailSheet,
      book: currentBook,
      series: currentSeries
    )
    .onAppear {
      viewModel.updateDualPageSettings(noCover: !isolateCoverPage)
      updateHandoff()
    }
    .onChange(of: isolateCoverPage) { _, newValue in
      viewModel.updateDualPageSettings(noCover: !newValue)
    }
    .onChange(of: pageLayout) { _, newValue in
      viewModel.updatePageLayout(newValue)
    }
    .onChange(of: splitWidePageMode) { _, newValue in
      viewModel.updateSplitWidePageMode(newValue)
    }
    .task(id: currentBookId) {
      readerPresentation.setReaderFlushHandler {
        viewModel.flushProgress()
      }
      if !preserveReaderOptions {
        resetReaderPreferencesForCurrentBook()
      }
      await loadBook(bookId: currentBookId, preserveReaderOptions: preserveReaderOptions)
      preserveReaderOptions = false
    }
    .onChange(of: currentBook?.id) { _, _ in
      updateHandoff()
    }
    .onChange(of: viewModel.pages.count) { oldCount, newCount in
      // Show helper overlay when pages are first loaded (iOS and macOS)
      if oldCount == 0 && newCount > 0 {
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 1.5)
        applyStatusBarVisibility(controlsHidden: !shouldShowControls)
      }
    }
    .onDisappear {
      logger.debug(
        "👋 DIVINA reader disappeared for book \(currentBookId), currentPage=\(viewModel.currentPage?.number ?? -1), totalPages=\(viewModel.pages.count)"
      )
      controlsTimer?.invalidate()
      tapZoneOverlayTimer?.invalidate()
      keyboardHelpTimer?.invalidate()
      animatedPlaybackLoading = false
      animatedPlaybackURL = nil
      viewModel.clearPreloadedImages()
    }
    .onChange(of: showingControls) { _, newValue in
      applyStatusBarVisibility(controlsHidden: !newValue)
    }
    .onChange(of: viewModel.isZoomed) { _, newValue in
      if newValue {
        showingControls = false
      }
    }
    #if os(iOS)
      .onChange(of: autoHideControls) { _, newValue in
        if newValue {
          resetControlsTimer(timeout: 3)
        } else {
          controlsTimer?.invalidate()
        }
      }
    #endif
    #if os(iOS)
      .onAppear {
        if readingDirection != readerPresentation.readingDirection {
          readerPresentation.readingDirection = readingDirection
        }
      }
    #endif
    #if os(iOS) || os(macOS)
      .onChange(of: readingDirection) { _, newDirection in
        // When switching read mode via settings, briefly show overlays again
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 2)
        if readingDirection != readerPresentation.readingDirection {
          readerPresentation.readingDirection = newDirection
        }
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
      }
    #endif
    #if os(tvOS)
      .onChange(of: shouldEnableUIKitRemoteCapture) { oldValue, newValue in
        if newValue && !oldValue {
          tvRemoteCaptureGeneration += 1
          logger.debug("📺 UIKit capture enabled, restart generation=\(tvRemoteCaptureGeneration)")
        }
      }
    #endif
    #if os(macOS)
      .onChange(of: currentBook) { _, newBook in
        // Update window manager state when book changes to refresh window title
        if let book = newBook {
          ReaderWindowManager.shared.currentState = BookReaderState(
            book: book, incognito: incognito, readList: readList)
        }
      }
    #endif
    .environment(\.readerBackgroundPreference, readerBackground)
  }

  @ViewBuilder
  private func readerContent(
    useDualPage: Bool,
    screenKey: String
  ) -> some View {
    let _ = viewModel.updateActualDualPageMode(useDualPage)

    Group {
      if !viewModel.pages.isEmpty {
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
                pageWidthPercentage: webtoonPageWidthPercentage,
                readerBackground: readerBackground,
                onBoundaryPanUpdate: { translation in
                  boundaryDragOffset = translation
                }
              )
            #else
              ScrollPageView(
                mode: .vertical,
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                showingControls: showingControls,
                viewModel: viewModel,
                previousBook: previousBook,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onPreviousBook: { openPreviousBook(previousBookId: $0) },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: { goToNextPage() },
                goToPreviousPage: { goToPreviousPage() },
                toggleControls: { toggleControls() },
                onPlayAnimatedPage: { pageIndex in
                  requestAnimatedPlayback(for: pageIndex)
                },
                onScrollActivityChange: { isScrolling in
                  if isScrolling {
                    resetControlsTimer(timeout: 1.5)
                  }
                },
                onBoundaryPanUpdate: { translation in
                  boundaryDragOffset = translation
                }
              )
            #endif
          } else {
            #if os(iOS)
              if pageTransitionStyle == .pageCurl && !useDualPage {
                CurlPageView(
                  viewModel: viewModel,
                  mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                  readingDirection: readingDirection,
                  splitWidePageMode: splitWidePageMode,
                  previousBook: previousBook,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onPreviousBook: { openPreviousBook(previousBookId: $0) },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage() },
                  goToPreviousPage: { goToPreviousPage() },
                  toggleControls: { toggleControls() },
                  onPlayAnimatedPage: { pageIndex in
                    requestAnimatedPlayback(for: pageIndex)
                  },
                  onBoundaryPanUpdate: { translation in
                    boundaryDragOffset = translation
                  }
                )
              } else {
                ScrollPageView(
                  mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                  readingDirection: readingDirection,
                  splitWidePageMode: splitWidePageMode,
                  showingControls: showingControls,
                  viewModel: viewModel,
                  previousBook: previousBook,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onPreviousBook: { openPreviousBook(previousBookId: $0) },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage() },
                  goToPreviousPage: { goToPreviousPage() },
                  toggleControls: { toggleControls() },
                  onPlayAnimatedPage: { pageIndex in
                    requestAnimatedPlayback(for: pageIndex)
                  },
                  onScrollActivityChange: { isScrolling in
                    if isScrolling {
                      resetControlsTimer(timeout: 1.5)
                    }
                  },
                  onBoundaryPanUpdate: { translation in
                    boundaryDragOffset = translation
                  }
                )
              }
            #else
              ScrollPageView(
                mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                showingControls: showingControls,
                viewModel: viewModel,
                previousBook: previousBook,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onPreviousBook: { openPreviousBook(previousBookId: $0) },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: { goToNextPage() },
                goToPreviousPage: { goToPreviousPage() },
                toggleControls: { toggleControls() },
                onPlayAnimatedPage: { pageIndex in
                  requestAnimatedPlayback(for: pageIndex)
                },
                onScrollActivityChange: { isScrolling in
                  if isScrolling {
                    resetControlsTimer(timeout: 1.5)
                  }
                },
                onBoundaryPanUpdate: { translation in
                  boundaryDragOffset = translation
                }
              )
            #endif
          }
        }
        .readerIgnoresSafeArea()
        .id("\(currentBookId)-\(screenKey)-\(readingDirection)")
        .onChange(of: viewModel.currentPageIndex) { oldIndex, newIndex in
          #if os(iOS)
            boundaryDragOffset = 0
          #endif
          #if os(tvOS)
            if oldIndex >= viewModel.pages.count && newIndex < viewModel.pages.count {
              tvRemoteCaptureGeneration += 1
              logger.debug("📺 left end page, restart UIKit capture generation=\(tvRemoteCaptureGeneration)")
            }
          #endif
          updateHandoff()
          // Update progress and preload pages in background without blocking UI
          Task(priority: .userInitiated) {
            await viewModel.updateProgress()
            await viewModel.preloadPages()
          }
        }
      } else if viewModel.isLoading {
        ReaderLoadingView(
          title: String(localized: "Loading book..."),
          detail: nil,
          progress: nil
        )
      } else {
        NoPagesView(onDismiss: { closeReader() })
      }
    }
  }

  @ViewBuilder
  private func helperOverlay(screenKey: String) -> some View {
    #if os(iOS) || os(macOS)
      TapZoneOverlay(isVisible: $showTapZoneOverlay, readingDirection: readingDirection)
        .readerIgnoresSafeArea()
        .onChange(of: screenKey) {
          // Show helper overlay when screen orientation changes
          triggerTapZoneOverlay(timeout: 1)
        }
        .onChange(of: tapZoneMode) {
          // Show helper overlay when tap zone mode changes
          triggerTapZoneOverlay(timeout: 1)
        }
    #else
      EmptyView()
    #endif
  }

  #if os(tvOS)
    private var tvRemoteCommandOverlay: some View {
      TVRemoteCommandOverlay(
        isEnabled: shouldEnableUIKitRemoteCapture,
        onMoveCommand: { direction in
          handleTVMoveCommand(direction, source: "uikit.overlay")
        },
        onSelectCommand: {
          handleTVSelectCommand(source: "uikit.overlay")
        }
      )
      .readerIgnoresSafeArea()
      .accessibilityHidden(true)
      .id(tvRemoteCaptureGeneration)
    }
  #endif

  private func controlsOverlay(useDualPage: Bool) -> some View {
    DivinaControlsOverlayView(
      readingDirection: $readingDirection,
      pageLayout: $pageLayout,
      isolateCoverPage: $isolateCoverPage,
      splitWidePageMode: $splitWidePageMode,
      showingPageJumpSheet: $showingPageJumpSheet,
      showingTOCSheet: $showingTOCSheet,
      showingReaderSettingsSheet: $showingReaderSettingsSheet,
      showingDetailSheet: $showingDetailSheet,
      viewModel: viewModel,
      currentBook: currentBook,
      dualPage: useDualPage,
      incognito: incognito,
      onDismiss: { closeReader() },
      previousBook: previousBook,
      nextBook: nextBook,
      onPreviousBook: { openPreviousBook(previousBookId: $0) },
      onNextBook: { openNextBook(nextBookId: $0) },
      controlsVisible: shouldShowControls,
      showingControls: showingControls
    )
  }

  #if os(macOS)
    private var keyboardHelpOverlay: some View {
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
      .animation(.default, value: showKeyboardHelp)
    }

    private func handleKeyCode(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) {
      // Handle ESC key to close window
      if keyCode == 53 {  // ESC key
        closeReader()
        return
      }

      // Handle ? key and H key for keyboard help
      if keyCode == 44 {  // ? key (Shift + /)
        showKeyboardHelp.toggle()
        return
      }

      // Handle Return/Enter key for fullscreen toggle
      if keyCode == 36 {  // Return/Enter key
        if let window = NSApplication.shared.keyWindow {
          window.toggleFullScreen(nil)
        }
        return
      }

      // Handle Space key for toggle controls
      if keyCode == 49 {  // Space key
        toggleControls()
        return
      }

      // Ignore if modifier keys are pressed (except for system shortcuts)
      guard flags.intersection([.command, .option, .control]).isEmpty else { return }

      // Handle F key for fullscreen toggle
      if keyCode == 3 {  // F key
        if let window = NSApplication.shared.keyWindow {
          window.toggleFullScreen(nil)
        }
        return
      }

      // Handle H key for keyboard help
      if keyCode == 4 {  // H key
        showKeyboardHelp.toggle()
        return
      }

      // Handle C key for toggle controls
      if keyCode == 8 {  // C key
        toggleControls()
        return
      }

      if keyCode == 37 {  // L key
        enableLiveText.toggle()
        let message = enableLiveText ? String(localized: "Live Text: ON") : String(localized: "Live Text: OFF")
        ErrorManager.shared.notify(message: message)
        return
      }

      // Handle T key for TOC
      if keyCode == 17 {  // T key
        if !viewModel.tableOfContents.isEmpty {
          showingTOCSheet = true
        }
        return
      }

      // Handle J key for jump to page
      if keyCode == 38 {  // J key
        if !viewModel.pages.isEmpty {
          showingPageJumpSheet = true
        }
        return
      }

      // Handle N key for next book
      if keyCode == 45 {  // N key
        if let nextBook = nextBook {
          openNextBook(nextBookId: nextBook.id)
        }
        return
      }

      guard !viewModel.pages.isEmpty else { return }

      switch readingDirection {
      case .ltr:
        switch keyCode {
        case 124:  // Right arrow
          goToNextPage()
        case 123:  // Left arrow
          goToPreviousPage()
        default:
          break
        }
      case .rtl:
        switch keyCode {
        case 123:  // Left arrow
          goToNextPage()
        case 124:  // Right arrow
          goToPreviousPage()
        default:
          break
        }
      case .vertical:
        switch keyCode {
        case 125:  // Down arrow
          goToNextPage()
        case 126:  // Up arrow
          goToPreviousPage()
        default:
          break
        }
      case .webtoon:
        // Webtoon scrolling is handled by WebtoonReaderView's own keyboard monitor
        break
      }
    }
  #endif

  private func loadBook(bookId: String, preserveReaderOptions: Bool) async {
    // Mark that loading has started
    viewModel.isLoading = true

    // Set incognito mode
    viewModel.incognitoMode = incognito

    // Reset isAtBottom when switching to a new book
    isAtBottom = false

    // Load book info to get read progress page and series reading direction
    var initialPageNumber: Int? = nil

    // Resolve from in-memory/DB first, then always refresh from network when online.
    var resolvedBook: Book?
    if let currentBook, currentBook.id == bookId {
      resolvedBook = currentBook
    } else if let cachedBook = await DatabaseOperator.shared.fetchBook(id: bookId) {
      resolvedBook = cachedBook
    } else if book.id == bookId {
      resolvedBook = book
    }

    if !AppConfig.isOffline {
      if let syncedBook = try? await SyncService.shared.syncBook(bookId: bookId) {
        resolvedBook = syncedBook
      }
    }

    if let resolvedBook {
      currentBook = resolvedBook
      seriesId = resolvedBook.seriesId
      readerPresentation.trackVisitedBook(bookId: resolvedBook.id, seriesId: resolvedBook.seriesId)
      initialPageNumber = incognito ? nil : resolvedBook.readProgress?.page
    }

    if let activeBook = currentBook {
      let isBookDownloaded = await OfflineManager.shared.isBookDownloaded(bookId: activeBook.id)

      // Refresh Divina manifest only when online and the book is not downloaded offline.
      if !AppConfig.isOffline, !isBookDownloaded {
        do {
          let manifest = try await BookService.shared.getBookManifest(id: activeBook.id)
          let toc = await ReaderManifestService(bookId: activeBook.id).parseTOC(manifest: manifest)
          await DatabaseOperator.shared.updateBookTOC(bookId: activeBook.id, toc: toc)
        } catch {
          // Silently fail - we'll use cached manifest
        }
      }

      // 3. Try to get series from DB
      var series = await DatabaseOperator.shared.fetchSeries(id: activeBook.seriesId)
      if series == nil && !AppConfig.isOffline {
        series = try? await SyncService.shared.syncSeriesDetail(seriesId: activeBook.seriesId)
      }

      if let series = series {
        currentSeries = series
        let preferredDirection: ReadingDirection
        if AppConfig.forceDefaultReadingDirection {
          preferredDirection = AppConfig.defaultReadingDirection
        } else {
          let rawReadingDirection = series.metadata.readingDirection?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if let rawReadingDirection, !rawReadingDirection.isEmpty {
            preferredDirection = ReadingDirection.fromString(rawReadingDirection)
          } else {
            preferredDirection = AppConfig.defaultReadingDirection
          }
        }

        if !preserveReaderOptions {
          readingDirection = preferredDirection.isSupported ? preferredDirection : .vertical
        }
      }

      // 4. Try to get next/previous books from DB
      self.nextBook = await DatabaseOperator.shared.getNextBook(
        instanceId: AppConfig.current.instanceId,
        bookId: bookId,
        readListId: readList?.id
      )
      if self.nextBook == nil && !AppConfig.isOffline {
        self.nextBook = await SyncService.shared.syncNextBook(
          bookId: bookId, readListId: readList?.id)
      }

      self.previousBook = await DatabaseOperator.shared.getPreviousBook(
        instanceId: AppConfig.current.instanceId,
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
  }

  private func jumpToPage(page: Int) {
    guard !viewModel.pages.isEmpty else { return }
    let clampedPage = min(max(page, 1), viewModel.pages.count)
    let targetIndex = clampedPage - 1
    if targetIndex != viewModel.currentPageIndex {
      viewModel.targetPageIndex = targetIndex
    }
  }

  private func jumpToTOCEntry(_ entry: ReaderTOCEntry) {
    jumpToPage(page: entry.pageIndex + 1)
  }

  private func goToNextPage() {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      let currentIndex =
        viewModel.currentViewItemIndex < viewModel.viewItems.count
        ? viewModel.currentViewItemIndex
        : viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      let nextIndex = currentIndex + 1
      guard nextIndex < viewModel.viewItems.count else { return }
      viewModel.targetViewItemIndex = nextIndex
    case .webtoon:
      // webtoon do not have an end page
      let next = min(viewModel.currentPageIndex + 1, viewModel.pages.count - 1)
      withAnimation {
        viewModel.currentPageIndex = next
      }
    }
  }

  private func goToPreviousPage() {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      let currentIndex =
        viewModel.currentViewItemIndex < viewModel.viewItems.count
        ? viewModel.currentViewItemIndex
        : viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      let previousIndex = currentIndex - 1
      guard previousIndex >= 0 else { return }
      viewModel.targetViewItemIndex = previousIndex
    case .webtoon:
      guard viewModel.currentPageIndex > 0 else { return }
      withAnimation {
        viewModel.currentPageIndex -= 1
      }
    }
  }

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

  private func resetControlsTimer(timeout: TimeInterval) {
    // Don't start timer if auto-hide is disabled
    if !autoHideControls {
      return
    }

    // Don't start timer when at end page or webtoon at bottom
    if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
      return
    }

    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      Task { @MainActor in
        withAnimation {
          showingControls = false
        }
      }
    }
  }

  /// Hide helper overlay and cancel timer
  private func hideTapZoneOverlay() {
    tapZoneOverlayTimer?.invalidate()
    withAnimation {
      showTapZoneOverlay = false
    }
  }

  /// Show reader helper overlay (Tap zones on iOS, keyboard help on macOS)
  private func triggerTapZoneOverlay(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showTapZoneHints, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation {
        self.showTapZoneOverlay = true
      }
      self.resetTapZoneOverlayTimer(timeout: timeout)
    }
  }

  /// Auto-hide helper overlay after a platform-specific delay
  private func resetTapZoneOverlayTimer(timeout: TimeInterval) {
    tapZoneOverlayTimer?.invalidate()
    tapZoneOverlayTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        self.hideTapZoneOverlay()
      }
    }
  }

  /// Hide keyboard help overlay and cancel timer
  private func hideKeyboardHelp() {
    keyboardHelpTimer?.invalidate()
    withAnimation {
      showKeyboardHelp = false
    }
  }

  /// Show keyboard help overlay
  private func triggerKeyboardHelp(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showKeyboardHelpOverlay, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation {
        self.showKeyboardHelp = true
      }
      self.resetKeyboardHelpTimer(timeout: timeout)
    }
  }

  /// Auto-hide keyboard help overlay after a delay
  private func resetKeyboardHelpTimer(timeout: TimeInterval) {
    keyboardHelpTimer?.invalidate()
    keyboardHelpTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        self.hideKeyboardHelp()
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    logger.debug(
      "➡️ Opening next book from \(currentBookId) to \(nextBookId), flush current progress first"
    )
    viewModel.flushProgress()
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode
    )
    // Preserve incognito mode for next book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

  private func openPreviousBook(previousBookId: String) {
    logger.debug(
      "⬅️ Opening previous book from \(currentBookId) to \(previousBookId), flush current progress first"
    )
    viewModel.flushProgress()
    // Switch to previous book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = previousBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode
    )
    // Preserve incognito mode for previous book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

}
