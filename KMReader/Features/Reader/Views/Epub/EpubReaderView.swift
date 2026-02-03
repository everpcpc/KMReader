//
//  EpubReaderView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI

  struct EpubReaderView: View {
    private let book: Book
    private let incognito: Bool
    private let readList: ReadList?
    private let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    @AppStorage("currentAccount") private var current: Current = .init()
    @AppStorage("epubPreferences") private var globalPreferences: EpubReaderPreferences = .init()
    @AppStorage("epubPageTransitionStyle") private var epubPageTransitionStyle: PageTransitionStyle = .scroll

    @State private var viewModel: EpubReaderViewModel
    @State private var activePreferences: EpubReaderPreferences
    @State private var bookPreferences: EpubReaderPreferences?
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var currentSeries: Series?
    @State private var currentBook: Book?
    @State private var showingChapterSheet = false
    @State private var showingPreferencesSheet = false
    @State private var showingDetailSheet = false
    @State private var showingQuickActions = false
    @State private var showingEndPage = false

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
      _viewModel = State(initialValue: EpubReaderViewModel(incognito: incognito))
      _activePreferences = State(initialValue: AppConfig.epubPreferences)
      _bookPreferences = State(initialValue: nil)
      _currentBook = State(initialValue: book)
    }

    private func closeReader() {
      if let onClose {
        onClose()
      } else {
        dismiss()
      }
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

    private func updateHandoff() {
      let url = KomgaWebLinkBuilder.epubReader(
        serverURL: current.serverURL,
        bookId: handoffBookId,
        incognito: incognito
      )
      readerPresentation.updateHandoff(title: handoffTitle, url: url)
    }

    var body: some View {
      readerBody
        .iPadIgnoresSafeArea()
        .task(id: book.id) {
          await loadBook()
        }
        .onAppear {
          updateHandoff()
          viewModel.applyPreferences(activePreferences, colorScheme: colorScheme)
        }
        .onChange(of: currentBook?.id) { _, _ in
          updateHandoff()
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
          controlsTimer?.invalidate()
          withAnimation {
            readerPresentation.hideStatusBar = false
          }
        }
        .onChange(of: shouldShowControls) { _, newValue in
          withAnimation {
            readerPresentation.hideStatusBar = !newValue
          }
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
          if !newValue {
            forceInitialAutoHide(timeout: 1.5)
          }
        }
    }

    private func loadBook() async {
      viewModel.beginLoading()

      currentBook = book
      await MainActor.run {
        bookPreferences = nil
        activePreferences = globalPreferences
      }
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

      let savedPreferences = await DatabaseOperator.shared.fetchBookEpubPreferences(
        bookId: activeBook.id
      )
      await MainActor.run {
        bookPreferences = savedPreferences
        activePreferences = savedPreferences ?? globalPreferences
      }

      // Refresh WebPub manifest if online
      if !AppConfig.isOffline {
        do {
          let manifest = try await BookService.shared.getBookWebPubManifest(bookId: activeBook.id)
          await DatabaseOperator.shared.updateBookWebPubManifest(bookId: activeBook.id, manifest: manifest)
        } catch {
          // Silently fail - we'll use cached manifest
        }
      }

      var series = await DatabaseOperator.shared.fetchSeries(id: activeBook.seriesId)
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
          Color.clear.readerIgnoresSafeArea()

          contentView(for: geometry.size, viewModel: viewModel)

          controlsOverlay
        }
        .onAppear {
          viewModel.updateViewport(size: geometry.size)
          if .ltr != readerPresentation.readingDirection {
            readerPresentation.readingDirection = .ltr
          }
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
        switch epubPageTransitionStyle {
        case .scroll:
          WebPubScrollView(
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
          WebPubPageView(
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
      } else {
        Text("No content available.")
          .foregroundStyle(.secondary)
      }
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
          if shouldShowControls {
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
            if shouldShowControls && showingQuickActions {
              quickActionsPanel
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                  )
                )
            }
            if shouldShowControls {
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
        .allowsHitTesting(shouldShowControls)
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

    private func forceInitialAutoHide(timeout: TimeInterval) {
      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        Task { @MainActor in
          withAnimation(animation) {
            showingControls = false
          }
        }
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
  }
#endif
