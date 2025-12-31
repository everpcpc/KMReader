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

    @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
    @AppStorage("epubReaderPreferences") private var readerPrefs: EpubReaderPreferences = .init()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    @State private var viewModel: EpubReaderViewModel
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var showTapZoneOverlay = false
    @State private var overlayTimer: Timer?
    @State private var currentBook: Book?
    @State private var showingChapterSheet = false
    @State private var showingPreferencesSheet = false

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

    var body: some View {
      readerBody
        .task(id: bookId) {
          await loadBook()
          resetControlsTimer(timeout: 1)
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
        .onChange(of: colorScheme) { _, newScheme in
          guard readerPrefs.theme == .system else { return }
          viewModel.applyPreferences(readerPrefs, colorScheme: newScheme)
        }
    }

    private func loadBook() async {
      // Load book info
      do {
        currentBook = try await SyncService.shared.syncBook(bookId: bookId)
      } catch {
        // Silently fail
      }

      await viewModel.load(bookId: bookId)
    }

    private var readerBody: some View {
      GeometryReader { geometry in
        ZStack {
          readerBackground.color.readerIgnoresSafeArea()

          contentView(for: geometry.size)

          if viewModel.navigatorViewController != nil {
            ComicTapZoneOverlay(isVisible: $showTapZoneOverlay)
              .readerIgnoresSafeArea()
          }

          controlsOverlay

          chapterStatusOverlay
        }
      }
      .readerIgnoresSafeArea()
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
        NavigatorView(navigatorViewController: navigatorViewController)
          .readerIgnoresSafeArea()
          .contentShape(Rectangle())
          .simultaneousGesture(
            SpatialTapGesture()
              .onEnded { value in
                handleTap(location: value.location, in: size)
              }
          )
      } else {
        Text("No content available.")
          .foregroundStyle(.secondary)
      }
    }

    private var controlsOverlay: some View {
      VStack {
        // Top bar
        VStack(spacing: 12) {
          HStack {
            Button {
              closeReader()
            } label: {
              Image(systemName: "xmark")
            }
            .controlSize(.large)
            .adaptiveButtonStyle(.borderedProminent)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Spacer()

            // Progress indicator
            if let currentLocator = viewModel.currentLocator, !viewModel.tableOfContents.isEmpty {
              Button {
                showingChapterSheet = true
              } label: {
                HStack(spacing: 4) {
                  // Total progress
                  if let totalProgression = currentLocator.locations.totalProgression {
                    HStack(spacing: 6) {
                      Image(systemName: "book.fill")
                      Text("\(totalProgression * 100, specifier: "%.1f")%")
                        .monospacedDigit()
                    }
                  }
                }
              }
              .controlSize(.regular)
              .adaptiveButtonStyle(.borderedProminent)
              .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Button {
              showingPreferencesSheet = true
            } label: {
              Image(systemName: "gearshape")
            }
            .controlSize(.large)
            .adaptiveButtonStyle(.borderedProminent)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
        }
        .padding()
        .allowsHitTesting(true)

        // Series and book title
        if let book = currentBook {
          VStack(spacing: 4) {
            Text(book.seriesTitle)
              .font(.headline)
              .foregroundColor(.white)
            Text("#\(book.metadata.number) - \(book.metadata.title)")
              .font(.subheadline)
              .foregroundColor(.white)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.accentColor.opacity(0.9))
          .cornerRadius(12)
        }

        Spacer()
      }
      .padding(.vertical, 24)
      .padding(.horizontal, 8)
      .readerIgnoresSafeArea()
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
    }

    private func toggleControls() {
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        resetControlsTimer(timeout: 3)
      }
    }

    private func resetControlsTimer(timeout: TimeInterval) {
      controlsTimer?.invalidate()
      controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
        withAnimation {
          showingControls = false
        }
      }
    }

    private var chapterStatusOverlay: some View {
      let hasTitle = (viewModel.currentLocator?.title?.isEmpty == false)
      let chapterProgression = viewModel.currentLocator?.locations.progression
      let totalProgression = viewModel.currentLocator?.locations.totalProgression

      return VStack {
        Spacer()
        if hasTitle || chapterProgression != nil || totalProgression != nil {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              if let chapterTitle = viewModel.currentLocator?.title, !chapterTitle.isEmpty {
                HStack(spacing: 6) {
                  Image(systemName: "list.bullet.rectangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                  Text(chapterTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              Spacer()
              if let chapterProgression {
                HStack(spacing: 4) {
                  Image(systemName: "doc.text.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                  Text("\(Int(chapterProgression * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
              }
            }

            if let totalProgression {
              ReadingProgressBar(progress: totalProgression)
                .opacity(shouldShowControls ? 1.0 : 0.0)
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 24)
        }
      }
      .readerIgnoresSafeArea()
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
      let width = size.width
      let leftZone = width * 0.3
      let rightZone = width * 0.7

      if showingControls {
        toggleControls()
        return
      }

      switch location.x {
      case ..<leftZone:
        viewModel.goToPreviousPage()
      case rightZone...:
        viewModel.goToNextPage()
      default:
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

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
      return navigatorViewController
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
      // Update if needed
    }
  }
#endif
