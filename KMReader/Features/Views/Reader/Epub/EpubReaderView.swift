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

    @AppStorage("epubPreferences") private var readerPrefs: EpubReaderPreferences = .init()
    @AppStorage("autoHideControls") private var autoHideControls: Bool = false

    @State private var viewModel: EpubReaderViewModel
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var currentSeries: Series?
    @State private var currentBook: Book?
    @State private var showingChapterSheet = false
    @State private var showingPreferencesSheet = false
    @State private var showingDetailSheet = false
    @State private var showingQuickActions = false

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

    private var buttonStyle: AdaptiveButtonStyleType {
      return .bordered
    }

    private var titleText: String {
      if showingControls {
        if let totalProgression = viewModel.currentLocation?.totalProgression {
          return String(localized: "\(totalProgression * 100, specifier: "%.1f")%")
        }
      } else {
        if let title = currentBook?.metadata.title {
          return title
        }
      }
      return String(localized: "")
    }

    var body: some View {
      readerBody
        .iPadIgnoresSafeArea()
        .task(id: book.id) {
          await loadBook()
        }
        .onAppear {
          viewModel.applyPreferences(readerPrefs, colorScheme: colorScheme)
        }
        .onChange(of: readerPrefs) { _, newPrefs in
          viewModel.applyPreferences(newPrefs, colorScheme: colorScheme)
        }
        .onChange(of: colorScheme) { _, newScheme in
          viewModel.applyPreferences(readerPrefs, colorScheme: newScheme)
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
            forceInitialAutoHide(timeout: 2)
          }
        }
        .onChange(of: autoHideControls) { _, newValue in
          if newValue {
            resetControlsTimer(timeout: 3)
          } else {
            controlsTimer?.invalidate()
          }
        }
    }

    private func loadBook() async {
      viewModel.beginLoading()

      currentBook = book
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
      if viewModel.isLoading {
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
      } else if !viewModel.pageLocations.isEmpty {
        WebPubPageView(
          viewModel: viewModel,
          preferences: readerPrefs,
          colorScheme: colorScheme,
          transitionStyle: .pageCurl,
          showingControls: shouldShowControls,
          bookTitle: currentBook?.metadata.title,
          onCenterTap: {
            toggleControls()
          }
        ).readerIgnoresSafeArea()
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
      VStack {
        HStack {
          Spacer()
          Button {
            closeReader()
          } label: {
            Image(systemName: "xmark")
          }
          .contentShape(Circle())
          .controlSize(.large)
          .buttonBorderShape(.circle)
          .adaptiveButtonStyle(buttonStyle)
        }

        Spacer()

        if showingQuickActions {
          quickActionsPanel
        }

        HStack {
          Spacer()
          Button {
            withAnimation {
              showingQuickActions.toggle()
            }
          } label: {
            Image(systemName: showingQuickActions ? "xmark" : "line.3.horizontal")
              .padding(2)
              .contentTransition(.symbolEffect(.replace, options: .nonRepeating))
          }
          .contentShape(Circle())
          .controlSize(.large)
          .buttonBorderShape(.circle)
          .adaptiveButtonStyle(buttonStyle)
        }
      }
      .tint(.primary)
      .padding(.vertical, 24)
      .padding(.horizontal, 12)
      .iPadIgnoresSafeArea(paddingTop: 24)
      .opacity(shouldShowControls ? 1.0 : 0.0)
      .allowsHitTesting(shouldShowControls)
      .transition(.opacity)
      .sheet(isPresented: $showingChapterSheet) {
        ChapterListSheetView(
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
          EpubPreferencesView(inSheet: true)
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
      HStack {
        Spacer()
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
      }
      .transition(
        .asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .trailing).combined(with: .opacity)
        )
      )
    }

    private func toggleControls(autoHide: Bool = true) {
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        if autoHide {
          resetControlsTimer(timeout: 3)
        } else {
          controlsTimer?.invalidate()
        }
      } else {
        showingQuickActions = false
      }
    }

    private func forceInitialAutoHide(timeout: TimeInterval) {
      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        Task { @MainActor in
          withAnimation {
            showingControls = false
          }
        }
      }
    }

    private func resetControlsTimer(timeout: TimeInterval) {
      if !autoHideControls {
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
