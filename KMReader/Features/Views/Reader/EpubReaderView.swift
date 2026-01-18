//
//  EpubReaderView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import ReadiumNavigator
  import ReadiumShared
  import SwiftUI

  struct EpubReaderView: View {
    private let bookId: String
    private let incognito: Bool
    private let readList: ReadList?
    private let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    @AppStorage("epubReaderPreferences") private var readerPrefs: EpubReaderPreferences = .init()
    @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
    @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
    @AppStorage("autoHideControls") private var autoHideControls: Bool = false

    @State private var viewModel: EpubReaderViewModel
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var showTapZoneOverlay = false
    @State private var overlayTimer: Timer?
    @State private var currentSeries: Series?
    @State private var currentBook: Book?
    @State private var showingChapterSheet = false
    @State private var showingPreferencesSheet = false
    @State private var showingDetailSheet = false

    init(
      bookId: String,
      incognito: Bool = false,
      readList: ReadList? = nil,
      onClose: (() -> Void)? = nil
    ) {
      self.bookId = bookId
      self.incognito = incognito
      self.readList = readList
      self.onClose = onClose
      _viewModel = State(initialValue: EpubReaderViewModel(incognito: incognito))
    }

    private func closeReader() {
      if let onClose {
        onClose()
      } else {
        dismiss()
      }
    }

    var shouldShowControls: Bool {
      viewModel.isLoading || showingControls
    }

    private var buttonStyle: AdaptiveButtonStyleType {
      return .bordered
    }

    var body: some View {
      readerBody
        .task(id: bookId) {
          await loadBook()
          triggerTapZoneDisplay()
        }
        .task(id: readerPrefs) {
          viewModel.applyPreferences(readerPrefs, colorScheme: colorScheme)
        }
        .onDisappear {
          controlsTimer?.invalidate()
          overlayTimer?.invalidate()
          withAnimation {
            readerPresentation.hideStatusBar = false
          }
        }
        .onChange(of: shouldShowControls) { _, newValue in
          withAnimation {
            readerPresentation.hideStatusBar = !newValue
          }
        }
        .onChange(of: showTapZoneOverlay) { _, newValue in
          if newValue {
            resetOverlayTimer()
          } else {
            overlayTimer?.invalidate()
          }
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
          if !newValue {
            forceInitialAutoHide(timeout: 2)
          }
        }
        .onChange(of: colorScheme) { _, newScheme in
          guard readerPrefs.theme == .system else { return }
          viewModel.applyPreferences(readerPrefs, colorScheme: newScheme)
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
      // Load book info
      do {
        currentBook = try await SyncService.shared.syncBook(bookId: bookId)
      } catch {
        // Silently fail
      }

      if let activeBook = currentBook {
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
      }

      await viewModel.load(bookId: bookId)
    }

    private var readerBody: some View {
      GeometryReader { geometry in
        ZStack {
          Color.clear.readerIgnoresSafeArea()

          contentView(for: geometry.size)

          if viewModel.navigatorViewController != nil {
            TapZoneOverlay(isVisible: $showTapZoneOverlay, readingDirection: .ltr)
              .readerIgnoresSafeArea()
              .onChange(of: tapZoneMode) {
                triggerTapZoneDisplay()
              }
          }

          controlsOverlay

          chapterStatusOverlay
        }
      }
      .onAppear {
        if .ltr != readerPresentation.readingDirection {
          readerPresentation.readingDirection = .ltr
        }
      }
    }

    @ViewBuilder
    private func contentView(for size: CGSize) -> some View {
      if viewModel.isLoading {
        VStack(spacing: 16) {
          ProgressView()
          if viewModel.downloadProgress > 0 {
            Text("Downloading: \(Int(viewModel.downloadProgress * 100))%")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } else if let error = viewModel.errorMessage {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
          Text(error)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task {
              await viewModel.retry()
            }
          }
        }
        .padding()
      } else if let navigatorViewController = viewModel.navigatorViewController {
        NavigatorView(
          navigatorViewController: navigatorViewController,
          onTap: { location in
            handleTap(location: location, in: size)
          }
        )
        .readerIgnoresSafeArea()
      } else {
        Text("No content available.")
          .foregroundStyle(.secondary)
      }
    }

    private var controlsOverlay: some View {
      VStack {
        // Top bar
        HStack {
          Button {
            closeReader()
          } label: {
            Image(systemName: "xmark")
          }
          .contentShape(Circle())
          .controlSize(.large)
          .buttonBorderShape(.circle)
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

          Spacer()

          // Series and book title
          if let book = currentBook {
            Button {
              showingDetailSheet = true
            } label: {
              HStack(spacing: 4) {
                if incognito {
                  Image(systemName: "eye.slash.fill")
                    .font(.callout)
                }
                VStack(alignment: incognito ? .leading : .center, spacing: 4) {
                  if book.oneshot {
                    Text(book.metadata.title)
                      .lineLimit(2)
                  } else {
                    Text(book.seriesTitle)
                      .foregroundStyle(.secondary)
                      .font(.caption)
                      .lineLimit(1)
                    Text("#\(book.metadata.number) - \(book.metadata.title)")
                      .lineLimit(1)
                  }
                }
              }
              .padding(.vertical, 2)
              .padding(.horizontal, 4)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .optimizedControlSize()
            .adaptiveButtonStyle(buttonStyle)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }

          Spacer()

          Button {
            showingPreferencesSheet = true
          } label: {
            Image(systemName: "gearshape")
          }
          .contentShape(Circle())
          .controlSize(.large)
          .buttonBorderShape(.circle)
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .allowsHitTesting(true)

        if let currentLocator = viewModel.currentLocator {
          Button {
            showingChapterSheet = true
          } label: {
            HStack(spacing: 4) {
              // Total progress
              if let totalProgression = currentLocator.locations.totalProgression {
                HStack(spacing: 6) {
                  Image(systemName: "bookmark")
                  Text("\(totalProgression * 100, specifier: "%.1f")%")
                    .monospacedDigit()
                }
              }
            }
          }
          .adaptiveButtonStyle(buttonStyle)
          .optimizedControlSize()
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          .disabled(viewModel.tableOfContents.isEmpty)
        }

        Spacer()
      }
      .tint(.primary)
      .padding()
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
        EpubPreferencesSheet(readerPrefs) { newPreferences in
          readerPrefs = newPreferences
          viewModel.applyPreferences(newPreferences, colorScheme: colorScheme)
        }
      }
      .readerDetailSheet(
        isPresented: $showingDetailSheet,
        book: currentBook,
        series: currentSeries
      )
    }

    private func toggleControls(autoHide: Bool = true) {
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        // Only auto-hide if autoHide is true
        if autoHide {
          resetControlsTimer(timeout: 3)
        } else {
          // Cancel any existing timer when manually opened
          controlsTimer?.invalidate()
        }
      }
    }

    private func forceInitialAutoHide(timeout: TimeInterval) {
      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        withAnimation {
          showingControls = false
        }
      }
    }

    private func resetControlsTimer(timeout: TimeInterval) {
      // Don't start timer if auto-hide is disabled
      if !autoHideControls {
        return
      }

      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        withAnimation {
          showingControls = false
        }
      }
    }

    private var chapterStatusOverlay: some View {
      let chapterProgression = viewModel.currentLocator?.locations.progression
      let totalProgression = viewModel.currentLocator?.locations.totalProgression

      return VStack {
        Spacer()
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            if let chapterTitle = viewModel.currentLocator?.title, !chapterTitle.isEmpty {
              HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                  .font(.caption2)
                  .foregroundStyle(.gray)
                Text(chapterTitle)
                  .font(.caption)
                  .foregroundStyle(.gray)
                  .lineLimit(1)
              }
            }
            Spacer()
            if let chapterProgression {
              HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                  .font(.caption2)
                  .foregroundStyle(.gray)
                Text("\(Int(chapterProgression * 100))%")
                  .font(.caption)
                  .foregroundStyle(.gray)
                  .monospacedDigit()
              }
            }
          }

          if let totalProgression {
            ReadingProgressBar(progress: totalProgression, type: .reader)
              .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
              .opacity(shouldShowControls ? 1.0 : 0.0)
              .allowsHitTesting(false)
          }
        }.padding(.horizontal, 16)
      }
      .allowsHitTesting(false)
    }

    private var currentChapterLink: ReadiumShared.Link? {
      guard let currentLocator = viewModel.currentLocator else {
        return nil
      }
      return viewModel.tableOfContents.first { link in
        link.url().isEquivalentTo(currentLocator.href)
      }
    }

    private func handleTap(location: CGPoint, in size: CGSize) {
      if showingControls {
        toggleControls()
        return
      }

      let normalizedX = location.x / size.width
      let normalizedY = location.y / size.height

      let action = TapZoneHelper.action(
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        tapZoneMode: tapZoneMode,
        readingDirection: .ltr,
        zoneThreshold: tapZoneSize.value
      )

      switch action {
      case .previous:
        viewModel.goToPreviousPage()
      case .next:
        viewModel.goToNextPage()
      case .toggleControls:
        toggleControls()
      }
    }

    private func triggerTapZoneDisplay() {
      guard viewModel.navigatorViewController != nil else { return }
      showTapZoneOverlay = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation {
          showTapZoneOverlay = true
        }
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
  }

  import UIKit

  struct NavigatorView: UIViewControllerRepresentable {
    let navigatorViewController: EPUBNavigatorViewController
    let onTap: (CGPoint) -> Void

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
      return navigatorViewController
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
      context.coordinator.onTap = onTap
      context.coordinator.setupGestures(for: uiViewController.view)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var onTap: ((CGPoint) -> Void)?
      var isLongPressing = false
      private weak var installedView: UIView?

      func setupGestures(for view: UIView) {
        guard installedView != view else { return }

        cleanup()
        installedView = view

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        // Allow touches to pass through to Readium for scrolling and link clicking.
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        view.addGestureRecognizer(longPress)
      }

      private func cleanup() {
        if let view = installedView {
          view.gestureRecognizers?.filter {
            $0 is UITapGestureRecognizer || $0 is UILongPressGestureRecognizer
          }.forEach {
            if $0.delegate === self { view.removeGestureRecognizer($0) }
          }
        }
      }

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          // Delay resetting to ensure handleTap can see the flag.
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        // Skip navigation if it was a long press.
        guard !isLongPressing, let view = gesture.view else { return }
        let location = gesture.location(in: view)
        onTap?(location)
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        // Allow simultaneous recognition with Readium's internal gestures.
        return true
      }
    }
  }
#endif
