//
// EpubReaderView.swift
//
//

#if os(iOS) || os(macOS)
  import SwiftUI

  struct EpubReaderView: View {
    private let sessionID: UUID
    private let book: Book
    private let incognito: Bool
    private let readListContext: ReaderReadListContext?
    private let readerPresentation: ReaderPresentationManager
    private let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("currentAccount") private var current: Current = .init()
    @AppStorage("epubPreferences") private var globalPreferences: EpubReaderPreferences = .init()
    @AppStorage("epubPageTransitionStyle") private var epubPageTransitionStyle: PageTransitionStyle = .scroll

    @State private var viewModel: EpubReaderViewModel
    @State private var activePreferences: EpubReaderPreferences
    @State private var bookPreferences: EpubReaderPreferences?
    @State private var showingControls = false
    @State private var currentSeries: Series?
    @State private var currentBook: Book?
    @State private var showingChapterSheet = false
    @State private var showingPreferencesSheet = false
    @State private var showingDetailSheet = false
    @State private var showingQuickActions = false
    @State private var showingEndPage = false
    #if os(macOS)
      @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
      @State private var showKeyboardHelp = false
      @State private var keyboardHelpTimer: Timer?
    #endif

    private let logger = AppLogger(.reader)

    init(
      sessionID: UUID,
      book: Book,
      incognito: Bool = false,
      readListContext: ReaderReadListContext? = nil,
      readerPresentation: ReaderPresentationManager,
      onClose: (() -> Void)? = nil
    ) {
      self.sessionID = sessionID
      self.book = book
      self.incognito = incognito
      self.readListContext = readListContext
      self.readerPresentation = readerPresentation
      self.onClose = onClose
      _viewModel = State(initialValue: EpubReaderViewModel(incognito: incognito))
      _activePreferences = State(initialValue: AppConfig.epubPreferences)
      _bookPreferences = State(initialValue: nil)
      _currentBook = State(initialValue: book)
    }

    private func closeReader() {
      logger.debug(
        "🚪 Closing EPUB reader for book \(handoffBookId), chapter=\(viewModel.currentChapterIndex), page=\(viewModel.currentPageIndex)"
      )
      if let onClose {
        onClose()
      } else {
        dismiss()
      }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
      guard phase != .active || !shouldShowControls else { return }
      showingControls = true
    }

    var shouldShowControls: Bool {
      guard viewModel.errorMessage == nil else { return true }
      guard !viewModel.isLoading else { return true }
      return showingControls
    }

    private var handoffBookId: String {
      currentBook?.id ?? book.id
    }

    private var handoffTitle: String {
      currentBook?.metadata.title ?? book.metadata.title
    }

    private var buttonStyle: AdaptiveButtonStyleType {
      return .bordered
    }

    private var animation: Animation {
      .default
    }

    private var isUsingBookPreferences: Bool {
      bookPreferences != nil
    }

    private var dismissGestureReadingDirection: ReadingDirection {
      switch activePreferences.flowStyle {
      case .paged:
        return viewModel.publicationReadingProgression == .rtl ? .rtl : .ltr
      case .scrolled:
        return .webtoon
      }
    }

    private var readerTheme: ReaderTheme {
      activePreferences.resolvedTheme(for: colorScheme)
    }

    #if os(macOS)
      private var supportsOverlayControls: Bool {
        false
      }
    #else
      private var supportsOverlayControls: Bool {
        true
      }
    #endif

    private func updateHandoff() {
      let url = KomgaWebLinkBuilder.epubReader(
        serverURL: current.serverURL,
        bookId: handoffBookId,
        incognito: incognito
      )
      readerPresentation.updateHandoff(sessionID: sessionID, title: handoffTitle, url: url)
    }

    private func updateReaderLiveActivityProgress() {
      #if os(iOS)
      let progress = viewModel.currentLocation?.totalProgression ?? 0
      ReaderLiveActivityManager.shared.updateReadingProgress(progress)
      #endif
    }

    var body: some View {
      readerBody
        #if os(iOS)
          .statusBarHidden(!shouldShowControls)
          .iPadIgnoresSafeArea()
        #endif
        .task(id: book.id) {
          readerPresentation.registerFlushHandler(for: sessionID) {
            viewModel.flushProgress()
          }
          await loadBook()
        }
        .onAppear {
          updateHandoff()
          viewModel.applyPreferences(activePreferences, colorScheme: colorScheme)
          #if os(macOS)
            configureMacReaderCommands()
          #endif
        }
        .onChange(of: currentBook) { _, newBook in
          if let newBook {
            readerPresentation.updatePresentedBook(sessionID: sessionID, book: newBook)
          }
          updateHandoff()
        }
        #if os(macOS)
          .onChange(of: macReaderCommandState) { _, newState in
            readerPresentation.updateMacReaderCommandState(newState)
          }
        #endif
        .onChange(of: viewModel.currentLocation) { _, _ in
          updateReaderLiveActivityProgress()
        }
        #if os(macOS)
          .onChange(of: viewModel.hasContent) { oldValue, newValue in
            if !oldValue && newValue {
              triggerKeyboardHelp(timeout: 1.5)
            }
          }
        #endif
        .onChange(of: showingEndPage) { _, newValue in
          guard newValue else { return }
          #if os(iOS)
            ReaderLiveActivityManager.shared.updateReadingProgress(1)
          #endif
        }
        .onChange(of: activePreferences) { _, newPrefs in
          viewModel.applyPreferences(newPrefs, colorScheme: colorScheme)
        }
        .onChange(of: globalPreferences) { _, newPrefs in
          guard !isUsingBookPreferences else { return }
          activePreferences = newPrefs
        }
        .onChange(of: colorScheme) { _, newScheme in
          viewModel.applyPreferences(activePreferences, colorScheme: newScheme)
        }
        .onReceive(
          NotificationCenter.default.publisher(for: .fileDownloadProgress)
        ) { notification in
          viewModel.updateDownloadProgress(notification: notification)
        }
        .onDisappear {
          logger.debug(
            "👋 EPUB reader disappeared for book \(handoffBookId), chapter=\(viewModel.currentChapterIndex), page=\(viewModel.currentPageIndex), hasLocation=\(viewModel.currentLocation != nil)"
          )
          readerPresentation.clearFlushHandler(for: sessionID)
          #if os(macOS)
            keyboardHelpTimer?.invalidate()
            readerPresentation.clearMacReaderCommands()
          #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
          handleScenePhaseChange(newPhase)
        }
        #if os(iOS)
          .readerDismissGesture(readingDirection: dismissGestureReadingDirection)
        #endif
        #if os(macOS)
          .background(
            KeyboardEventHandler(
              onKeyPress: { keyCode, flags in
                handleKeyCode(keyCode, flags: flags)
              }
            )
          )
        #endif
    }

    private func loadBook() async {
      viewModel.beginLoading()

      currentBook = book
      bookPreferences = nil
      activePreferences = globalPreferences
      do {
        currentBook = try await SyncService.shared.syncBook(bookId: book.id)
      } catch {
      }

      guard let activeBook = currentBook else {
        viewModel.errorMessage =
          AppErrorType.missingRequiredData(
            message: "Missing book metadata. Please try again."
          ).localizedDescription
        viewModel.loadingStage = .idle
        viewModel.isLoading = false
        return
      }

      let database = await DatabaseOperator.databaseIfConfigured()
      let savedPreferences = await database?.fetchBookEpubPreferences(bookId: activeBook.id)
      if !incognito {
        readerPresentation.trackVisitedBook(
          sessionID: sessionID,
          bookId: activeBook.id,
          seriesId: activeBook.seriesId
        )
      }
      bookPreferences = savedPreferences
      activePreferences = savedPreferences ?? globalPreferences

      // Refresh WebPub manifest if online
      if !AppConfig.isOffline {
        do {
          let manifest = try await BookService.shared.getBookWebPubManifest(bookId: activeBook.id)
          await database?.updateBookWebPubManifest(bookId: activeBook.id, manifest: manifest)
        } catch {
          // Silently fail - we'll use cached manifest
        }
      }

      var series = await database?.fetchSeries(id: activeBook.seriesId)
      if series == nil && !AppConfig.isOffline {
        do {
          series = try await SyncService.shared.syncSeriesDetail(seriesId: activeBook.seriesId)
        } catch {
          // Silently fail
        }
      }
      if let series = series {
        currentSeries = series
      }

      await viewModel.load(book: activeBook)
    }

    @ViewBuilder
    private var readerBody: some View {
      GeometryReader { geometry in
        ZStack {
          readerTheme.backgroundColor.readerIgnoresSafeArea()

          contentView(for: geometry.size, viewModel: viewModel)

          controlsOverlay

          #if os(macOS)
            keyboardHelpOverlay
          #endif
        }
        .onAppear {
          viewModel.updateViewport(size: geometry.size)
        }
        .onChange(of: geometry.size) { _, newSize in
          viewModel.updateViewport(size: newSize)
        }
      }
    }

    @ViewBuilder
    private func contentView(for size: CGSize, viewModel: EpubReaderViewModel) -> some View {
      if showingEndPage {
        EpubEndPageView(
          bookTitle: currentBook?.metadata.title,
          preferences: activePreferences,
          colorScheme: colorScheme,
          onReturn: {
            // Hide end page first, then navigate to last page
            showingEndPage = false

            // Navigate back to the last page of the last chapter
            Task { @MainActor in
              // Small delay to ensure view hierarchy is updated
              try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
              if let lastPosition = viewModel.lastPagePosition() {
                viewModel.targetChapterIndex = lastPosition.chapterIndex
                viewModel.targetPageIndex = lastPosition.pageIndex
              }
            }
          },
          onClose: {
            closeReader()
          }
        )
      } else if viewModel.isLoading {
        ReaderLoadingView(
          title: loadingTitle,
          detail: loadingDetail,
          progress: (viewModel.downloadBytesReceived > 0 || viewModel.downloadProgress > 0)
            ? viewModel.downloadProgress : nil
        )
      } else if let error = viewModel.errorMessage {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
          Text(error)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task {
              await loadBook()
            }
          }
        }
        .padding()
      } else if viewModel.hasContent {
        readerContent
      } else {
        Text("No content available.")
          .foregroundStyle(.secondary)
      }
    }

    @ViewBuilder
    private var readerContent: some View {
      #if os(macOS)
        switch activePreferences.flowStyle {
        case .paged:
          WebPubPagedScrollView(
            viewModel: viewModel,
            preferences: activePreferences,
            colorScheme: colorScheme,
            showingControls: shouldShowControls,
            bookTitle: currentBook?.metadata.title,
            onCenterTap: {
              toggleControls()
            },
            onEndReached: {
              if !showingEndPage {
                viewModel.syncEndProgression()
                showingEndPage = true
              }
            }
          )
        case .scrolled:
          WebPubScrolledView(
            viewModel: viewModel,
            preferences: activePreferences,
            colorScheme: colorScheme,
            showingControls: shouldShowControls,
            bookTitle: currentBook?.metadata.title,
            onCenterTap: {
              toggleControls()
            },
            onEndReached: {
              if !showingEndPage {
                viewModel.syncEndProgression()
                showingEndPage = true
              }
            }
          )
        }
      #else
        switch activePreferences.flowStyle {
        case .paged:
          switch epubPageTransitionStyle {
          case .scroll:
            WebPubPagedScrollView(
              viewModel: viewModel,
              preferences: activePreferences,
              colorScheme: colorScheme,
              showingControls: shouldShowControls,
              bookTitle: currentBook?.metadata.title,
              onCenterTap: {
                toggleControls()
              },
              onEndReached: {
                if !showingEndPage {
                  viewModel.syncEndProgression()
                  showingEndPage = true
                }
              }
            ).readerIgnoresSafeArea()
          case .cover:
            WebPubPagedCoverView(
              viewModel: viewModel,
              preferences: activePreferences,
              colorScheme: colorScheme,
              showingControls: shouldShowControls,
              bookTitle: currentBook?.metadata.title,
              onCenterTap: {
                toggleControls()
              },
              onEndReached: {
                if !showingEndPage {
                  viewModel.syncEndProgression()
                  showingEndPage = true
                }
              }
            ).readerIgnoresSafeArea()
          case .pageCurl:
            WebPubPagedCurlView(
              viewModel: viewModel,
              preferences: activePreferences,
              colorScheme: colorScheme,
              showingControls: shouldShowControls,
              bookTitle: currentBook?.metadata.title,
              onCenterTap: {
                toggleControls()
              },
              onEndReached: {
                if !showingEndPage {
                  viewModel.syncEndProgression()
                  showingEndPage = true
                }
              }
            ).readerIgnoresSafeArea()
          }
        case .scrolled:
          WebPubScrolledView(
            viewModel: viewModel,
            preferences: activePreferences,
            colorScheme: colorScheme,
            showingControls: shouldShowControls,
            bookTitle: currentBook?.metadata.title,
            onCenterTap: {
              toggleControls()
            },
            onEndReached: {
              if !showingEndPage {
                viewModel.syncEndProgression()
                showingEndPage = true
              }
            }
          ).readerIgnoresSafeArea()
        }
      #endif
    }

    private var loadingTitle: String {
      switch viewModel.loadingStage {
      case .fetchingMetadata:
        return String(localized: "Fetching book info...")
      case .downloading:
        return String(localized: "Downloading book...")
      case .preparingReader:
        return String(localized: "Preparing reader...")
      case .paginating:
        return String(localized: "Paginating chapters...")
      case .idle:
        return String(localized: "Loading...")
      }
    }

    private var loadingDetail: String? {
      switch viewModel.loadingStage {
      case .fetchingMetadata:
        return String(localized: "Fetching book metadata")
      case .downloading:
        if let expectedBytes = viewModel.downloadBytesExpected {
          let received = Double(viewModel.downloadBytesReceived)
          let expected = Double(expectedBytes)
          return
            "\(String(format: "%.1f", received / 1024 / 1024)) / \(String(format: "%.1f", expected / 1024 / 1024)) MB"
        }
        return String(localized: "Downloading book content")
      case .preparingReader:
        return String(localized: "Preparing reader view")
      case .paginating:
        return String(localized: "Calculating chapter pages")
      case .idle:
        return String(localized: "Loading...")
      }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
      Color.clear
        .overlay(alignment: .topTrailing) {
          if supportsOverlayControls && shouldShowControls {
            Button {
              closeReader()
            } label: {
              Image(systemName: "xmark")
            }
            .contentShape(Circle())
            .controlSize(.extraLarge)
            .buttonBorderShape(.circle)
            .adaptiveButtonStyle(buttonStyle)
            .padding(.top, 24)
            .padding(.trailing, 12)
            .transition(
              .asymmetric(
                insertion: .scale(scale: 0).combined(with: .opacity),
                removal: .scale(scale: 0).combined(with: .opacity)
              )
            )
          }
        }
        .overlay(alignment: .bottomTrailing) {
          VStack(alignment: .trailing) {
            if supportsOverlayControls && shouldShowControls && showingQuickActions {
              quickActionsPanel
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                  )
                )
            }
            if supportsOverlayControls && shouldShowControls {
              Button {
                withAnimation(animation) {
                  showingQuickActions.toggle()
                }
              } label: {
                Image(systemName: showingQuickActions ? "xmark" : "line.3.horizontal")
                  .padding(2)
                  .contentTransition(.symbolEffect(.replace, options: .nonRepeating))
              }
              .contentShape(Circle())
              .controlSize(.extraLarge)
              .buttonBorderShape(.circle)
              .adaptiveButtonStyle(buttonStyle)
              .padding(.bottom, 24)
              .padding(.trailing, 12)
              .transition(
                .asymmetric(
                  insertion: .scale(scale: 0).combined(with: .opacity),
                  removal: .scale(scale: 0).combined(with: .opacity)
                )
              )
            }
          }
        }
        .tint(.primary)
        .iPadIgnoresSafeArea(paddingTop: 24)
        .allowsHitTesting(supportsOverlayControls && shouldShowControls)
        .sheet(isPresented: $showingChapterSheet) {
          EpubTocSheetView(
            chapters: viewModel.tableOfContents,
            currentLink: currentChapterLink,
            goToChapter: { link in
              showingChapterSheet = false
              viewModel.goToChapter(link: link)
            }
          )
        }
        .sheet(isPresented: $showingPreferencesSheet) {
          NavigationStack {
            EpubPreferencesView(
              inSheet: true,
              bookId: currentBook?.id ?? book.id,
              hasBookPreferences: bookPreferences != nil,
              initialPreferences: activePreferences,
              onPreferencesSaved: { newPreferences in
                activePreferences = newPreferences
                bookPreferences = newPreferences
              },
              onPreferencesCleared: {
                activePreferences = globalPreferences
                bookPreferences = nil
              }
            )
          }
        }
        .readerDetailSheet(
          isPresented: $showingDetailSheet,
          book: currentBook,
          series: currentSeries
        )
    }

    @ViewBuilder
    private var quickActionsPanel: some View {
      VStack(alignment: .trailing, spacing: 6) {
        if let currentLocation = viewModel.currentLocation,
          let totalProgression = currentLocation.totalProgression
        {
          Button {
            showingChapterSheet = true
          } label: {
            HStack {
              Text("Contents · \(totalProgression * 100, specifier: "%.1f")%")
                .font(.callout)
              Image(systemName: "list.bullet")
            }
          }
          .adaptiveButtonStyle(buttonStyle)
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          .disabled(viewModel.tableOfContents.isEmpty)
        }

        Button {
          showingPreferencesSheet = true
        } label: {
          HStack {
            Text("Themes & Settings")
              .font(.callout)
            Image(systemName: "textformat")
          }
        }
        .adaptiveButtonStyle(buttonStyle)
        .buttonBorderShape(.capsule)
        .controlSize(.large)

        Button {
          showingDetailSheet = true
        } label: {
          HStack {
            Text("Book Info")
              .font(.callout)
            Image(systemName: "info.circle")
          }
        }
        .adaptiveButtonStyle(buttonStyle)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
      }
      .transition(
        .asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .trailing).combined(with: .opacity)
        )
        )
    }

    private func toggleControls() {
      withAnimation(animation) {
        showingControls.toggle()
      }
      if !showingControls {
        showingQuickActions = false
      }
    }

    private var currentChapterLink: WebPubLink? {
      guard let currentLocation = viewModel.currentLocation else {
        return nil
      }
      return findLink(href: currentLocation.href, in: viewModel.tableOfContents)
    }

    private func findLink(href: String, in links: [WebPubLink]) -> WebPubLink? {
      for link in links {
        if link.href == href {
          return link
        }
        if let children = link.children, let found = findLink(href: href, in: children) {
          return found
        }
      }
      return nil
    }

    #if os(macOS)
      private var macReaderCommandState: ReaderPresentationManager.MacReaderCommandState {
        ReaderPresentationManager.MacReaderCommandState(
          isActive: true,
          supportsReaderSettings: true,
          supportsBookDetails: currentBook != nil && currentSeries != nil,
          hasPages: viewModel.hasContent,
          hasTableOfContents: !viewModel.tableOfContents.isEmpty,
          supportsPageJump: false,
          supportsBookNavigation: false,
          canOpenPreviousBook: false,
          canOpenNextBook: false,
          readingDirection: dismissGestureReadingDirection,
          pageLayout: .single,
          isolateCoverPage: false,
          splitWidePageMode: .none,
          supportsReadingDirectionSelection: false,
          supportsPageLayoutSelection: false,
          supportsDualPageOptions: false,
          supportsSplitWidePageMode: false
        )
      }

      private var keyboardHelpOverlay: some View {
        KeyboardHelpOverlay(
          readingDirection: dismissGestureReadingDirection,
          hasTOC: !viewModel.tableOfContents.isEmpty,
          supportsLiveText: false,
          supportsJumpToPage: false,
          supportsToggleControls: supportsOverlayControls,
          hasNextBook: false,
          onDismiss: {
            hideKeyboardHelp()
          }
        )
        .opacity(showKeyboardHelp ? 1.0 : 0.0)
        .allowsHitTesting(showKeyboardHelp)
        .animation(.default, value: showKeyboardHelp)
      }

      private func configureMacReaderCommands() {
        readerPresentation.configureMacReaderCommands(
          state: macReaderCommandState,
          handlers: ReaderPresentationManager.MacReaderCommandHandlers(
            showReaderSettings: {
              showingPreferencesSheet = true
            },
            showBookDetails: {
              if currentBook != nil && currentSeries != nil {
                showingDetailSheet = true
              }
            },
            showTableOfContents: {
              if !viewModel.tableOfContents.isEmpty {
                showingChapterSheet = true
              }
            },
            showPageJump: {},
            openPreviousBook: {},
            openNextBook: {},
            setReadingDirection: { _ in },
            setPageLayout: { _ in },
            toggleIsolateCoverPage: {},
            setSplitWidePageMode: { _ in }
          )
        )
      }

      private func handleKeyCode(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if keyCode == 53 {
          closeReader()
          return true
        }

        if keyCode == 44 || keyCode == 4 {
          showKeyboardHelp.toggle()
          return true
        }

        if keyCode == 36 || keyCode == 3 {
          if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
          }
          return true
        }

        if keyCode == 49 || keyCode == 8 {
          return true
        }

        guard flags.intersection([.command, .option, .control]).isEmpty else { return false }

        if keyCode == 17 {
          if !viewModel.tableOfContents.isEmpty {
            showingChapterSheet = true
          }
          return true
        }

        guard viewModel.hasContent else { return false }

        switch dismissGestureReadingDirection {
        case .ltr:
          switch keyCode {
          case 124:
            viewModel.goToNextPage()
            return true
          case 123:
            viewModel.goToPreviousPage()
            return true
          default:
            return false
          }
        case .rtl:
          switch keyCode {
          case 123:
            viewModel.goToNextPage()
            return true
          case 124:
            viewModel.goToPreviousPage()
            return true
          default:
            return false
          }
        case .vertical, .webtoon:
          switch keyCode {
          case 125:
            viewModel.goToNextPage()
            return true
          case 126:
            viewModel.goToPreviousPage()
            return true
          default:
            return false
          }
        }
      }

      private func hideKeyboardHelp() {
        keyboardHelpTimer?.invalidate()
        keyboardHelpTimer = nil
        showKeyboardHelp = false
      }

      private func triggerKeyboardHelp(timeout: TimeInterval) {
        keyboardHelpTimer?.invalidate()
        guard showKeyboardHelpOverlay, viewModel.hasContent else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
          self.showKeyboardHelp = true
          self.keyboardHelpTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            Task { @MainActor in
              self.hideKeyboardHelp()
            }
          }
        }
      }
    #endif
  }
#endif
