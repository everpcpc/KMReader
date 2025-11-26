//
//  EpubReaderView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import ReadiumNavigator
import ReadiumShared
import SwiftUI

struct EpubReaderView: View {
  private let bookId: String
  private let incognito: Bool

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("epubReaderPreferences") private var readerPrefs: EpubReaderPreferences = .init()
  @Environment(\.dismiss) private var dismiss

  @State private var viewModel: EpubReaderViewModel
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var showTapZoneOverlay = false
  @State private var overlayTimer: Timer?
  @State private var currentBook: Book?
  @State private var showingChapterSheet = false
  @State private var showingPreferencesSheet = false

  init(bookId: String, incognito: Bool = false) {
    self.bookId = bookId
    self.incognito = incognito
    _viewModel = State(initialValue: EpubReaderViewModel(incognito: incognito))
  }

  var shouldShowControls: Bool {
    viewModel.isLoading || showingControls
  }

  var body: some View {
    readerBody
      .task(id: bookId) {
        await loadBook()
        resetControlsTimer()
        triggerTapZoneDisplay()
      }
      .task(id: readerPrefs) {
        viewModel.applyPreferences(readerPrefs)
      }
      .onDisappear {
        controlsTimer?.invalidate()
        overlayTimer?.invalidate()
      }
      .onChange(of: showTapZoneOverlay) { _, newValue in
        if newValue {
          resetOverlayTimer()
        } else {
          overlayTimer?.invalidate()
        }
      }
  }

  private func loadBook() async {
    // Load book info
    do {
      currentBook = try await BookService.shared.getBook(id: bookId)
    } catch {
      // Silently fail
    }

    await viewModel.load(bookId: bookId)
  }

  private var readerBody: some View {
    GeometryReader { geometry in
      ZStack {
        readerBackground.color.ignoresSafeArea()

        contentView(for: geometry.size)

        if viewModel.navigatorViewController != nil {
          ComicTapZoneOverlay(isVisible: $showTapZoneOverlay)
            .ignoresSafeArea()
        }

        controlsOverlay

        chapterStatusOverlay
      }
    }
    .ignoresSafeArea()
    #if canImport(UIKit)
      .statusBar(hidden: !shouldShowControls)
    #endif
  }

  @ViewBuilder
  private func contentView(for size: CGSize) -> some View {
    if viewModel.isLoading {
      VStack(spacing: 16) {
        ProgressView()
          .tint(.white)
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
        .ignoresSafeArea()
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
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColor.color.opacity(0.9))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())

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
                      .font(.footnote)
                    Text("\(totalProgression * 100, specifier: "%.1f")%")
                      .monospacedDigit()
                  }
                }
              }
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(themeColor.color.opacity(0.9))
              .cornerRadius(20)
              .overlay(
                RoundedRectangle(cornerRadius: 20)
                  .stroke(Color.white.opacity(0.3), lineWidth: 1)
              )
              .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
          }

          Spacer()

          Button {
            showingPreferencesSheet = true
          } label: {
            Image(systemName: "gearshape")
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColor.color.opacity(0.9))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())
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
          Text("#\(Int(book.number)) - \(book.metadata.title)")
            .font(.subheadline)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeColor.color.opacity(0.9))
        .cornerRadius(12)
      }

      Spacer()
    }
    .padding(.vertical, 24)
    .padding(.horizontal, 8)
    .ignoresSafeArea()
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
        viewModel.applyPreferences(newPreferences)
      }
    }
  }

  private func toggleControls() {
    withAnimation {
      showingControls.toggle()
    }
    if showingControls {
      resetControlsTimer()
    }
  }

  private func resetControlsTimer() {
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
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
                Image(systemName: "hourglass")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text("\(Int((1 - chapterProgression) * 100))%")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .monospacedDigit()
              }
            }
          }

          if let totalProgression {
            ProgressView(value: totalProgression, total: 1.0)
              .tint(themeColor.color)
              .opacity(shouldShowControls ? 1.0 : 0.0)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
      }
    }
    .ignoresSafeArea()
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

#if canImport(UIKit)
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
#elseif canImport(AppKit)
  import AppKit

  struct NavigatorView: NSViewControllerRepresentable {
    let navigatorViewController: EPUBNavigatorViewController

    func makeNSViewController(context: Context) -> NSViewController {
      // On macOS, EPUBNavigatorViewController is a UIViewController
      // We need to wrap it in an NSViewController
      let container = NSViewController()
      let viewController = navigatorViewController
      container.addChild(viewController)
      container.view.addSubview(viewController.view)
      viewController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        viewController.view.topAnchor.constraint(equalTo: container.view.topAnchor),
        viewController.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
        viewController.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
        viewController.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
      ])
      return container
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
      // Update if needed
    }
  }
#endif
