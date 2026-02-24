//
// DivinaControlsOverlayView.swift
//
//

import SwiftUI

struct DivinaControlsOverlayView: View {
  @Binding var readingDirection: ReadingDirection
  @Binding var pageLayout: PageLayout
  @Binding var isolateCoverPage: Bool
  @Binding var splitWidePageMode: SplitWidePageMode

  @Binding var showingPageJumpSheet: Bool
  @Binding var showingTOCSheet: Bool
  @Binding var showingReaderSettingsSheet: Bool
  @Binding var showingDetailSheet: Bool

  @AppStorage("readerControlsGradientBackground") private var readerControlsGradientBackground: Bool = false

  let viewModel: ReaderViewModel
  let currentBook: Book?
  let dualPage: Bool
  let incognito: Bool
  let onDismiss: () -> Void
  let previousBook: Book?
  let nextBook: Book?
  let onPreviousBook: ((String) -> Void)?
  let onNextBook: ((String) -> Void)?
  let controlsVisible: Bool
  let showingControls: Bool

  #if os(tvOS)
    private enum ControlFocus: Hashable {
      case close
      case title
      case settings
      case pageNumber
    }
    @FocusState private var focusedControl: ControlFocus?
  #endif

  private var buttonStyle: AdaptiveButtonStyleType {
    return .bordered
  }

  private var animation: Animation {
    .bouncy(duration: 0.25)
  }

  private var currentSegmentBookId: String? {
    currentBook?.id
  }

  private var currentSegmentPageCount: Int {
    guard let currentSegmentBookId else {
      return viewModel.pageCount
    }
    return viewModel.pageCount(forSegmentBookId: currentSegmentBookId)
  }

  private var currentSegmentProgressPage: Int {
    guard currentSegmentPageCount > 0 else { return 0 }
    if viewModel.currentViewItem()?.isEnd == true {
      return currentSegmentPageCount
    }
    return min(max(viewModel.currentPageNumberInCurrentSegment(), 1), currentSegmentPageCount)
  }

  private var progress: Double {
    guard currentSegmentPageCount > 0 else { return 0 }
    return Double(currentSegmentProgressPage) / Double(currentSegmentPageCount)
  }

  private var displayedCurrentPage: String {
    guard currentSegmentPageCount > 0 else { return "0" }
    if viewModel.currentViewItem()?.isEnd == true || viewModel.currentPageIndex >= viewModel.pageCount {
      return String(localized: "reader.page.end")
    } else {
      if dualPage, let pair = viewModel.currentPagePair() {
        return displayPagePair(first: pair.first, second: pair.second)
      } else {
        return String(displayPageNumber(forPageIndex: viewModel.currentPageIndex))
      }
    }
  }

  private func displayPagePair(first: Int, second: Int?) -> String {
    let firstPageNumber = displayPageNumber(forPageIndex: first)
    guard let second else { return "\(firstPageNumber)" }
    let secondPageNumber = displayPageNumber(forPageIndex: second)
    if readingDirection == .rtl {
      return "\(secondPageNumber),\(firstPageNumber)"
    }
    return "\(firstPageNumber),\(secondPageNumber)"
  }

  private func displayPageNumber(forPageIndex pageIndex: Int) -> Int {
    viewModel.displayPageNumber(forPageIndex: pageIndex) ?? pageIndex + 1
  }

  private var enableDualPageOptions: Bool {
    return readingDirection != .webtoon && readingDirection != .vertical && pageLayout.supportsDualPageOptions
  }

  private var isCurrentPageValid: Bool {
    return viewModel.currentPageIndex >= 0 && viewModel.currentPageIndex < viewModel.pageCount
  }

  #if os(iOS) || os(macOS)
    private func sharePages(indices: [Int]) {
      var images: [PlatformImage] = []
      var names: [String] = []

      for index in indices {
        guard index >= 0 && index < viewModel.pageCount else { continue }
        guard let page = viewModel.page(at: index) else { continue }
        if let image = viewModel.preloadedImage(forPageIndex: index) {
          images.append(image)
          names.append(page.fileName)
        }
      }

      guard !images.isEmpty else { return }
      ImageShareHelper.shareMultiple(images: images, fileNames: names)
    }

    private func sharePage(index: Int) {
      sharePages(indices: [index])
    }

    private var sharePageFormat: String {
      String(localized: "Share Page %d")
    }
  #endif

  var body: some View {
    VStack(spacing: 0) {
      if controlsVisible {
        topBar
          .transition(
            .move(edge: .top)
              .combined(with: .opacity)
              .combined(with: .scale(scale: 0.8, anchor: .top))
          )
      }

      Spacer(minLength: 0)

      if controlsVisible {
        bottomBar
          .transition(
            .move(edge: .bottom)
              .combined(with: .opacity)
              .combined(with: .scale(scale: 0.8, anchor: .bottom))
          )
      }
    }
    .animation(animation, value: controlsVisible)
    .allowsHitTesting(controlsVisible)
    #if os(iOS)
      .tint(.primary)
    #endif
    #if os(tvOS)
      .onAppear {
        if showingControls {
          focusedControl = .close
        }
      }
      .onChange(of: showingControls) { _, newValue in
        focusedControl = newValue ? .close : nil
      }
      .onChange(of: focusedControl) { _, newValue in
        if showingControls && newValue == nil {
          focusedControl = .close
        }
      }
      .focusSection()
    #endif
  }

  private var topBar: some View {
    HStack(alignment: .top) {
      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonBorderShape(.circle)
      .controlSize(.large)
      .contentShape(Circle())
      .adaptiveButtonStyle(buttonStyle)
      #if os(tvOS)
        .focused($focusedControl, equals: .close)
        .id("closeButton")
      #endif

      Spacer()

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
                Text("#\(book.metadata.number) - \(book.metadata.title)")
                  .lineLimit(1)
                Text(book.seriesTitle)
                  .foregroundStyle(.secondary)
                  .font(.caption)
                  .lineLimit(1)
              }
            }
          }
          .padding(.vertical, 2)
          .padding(.horizontal)
        }
        .optimizedControlSize()
        .contentShape(Capsule())
        .adaptiveButtonStyle(buttonStyle)
        #if os(tvOS)
          .focused($focusedControl, equals: .title)
          .id("titleLabel")
        #endif
      }

      Spacer()

      Menu {
        menuContent()
      } label: {
        Image(systemName: "ellipsis")
          .padding(4)
      }
      .appMenuStyle()
      .buttonBorderShape(.circle)
      .controlSize(.large)
      .contentShape(Circle())
      .adaptiveButtonStyle(buttonStyle)
      #if os(tvOS)
        .focused($focusedControl, equals: .settings)
      #endif
    }
    .allowsHitTesting(true)
    .padding()
    .iPadIgnoresSafeArea(paddingTop: 24)
    .background {
      if readerControlsGradientBackground {
        gradientBackground(startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea(edges: .top)
      }
    }
  }

  private var bottomBar: some View {
    VStack(spacing: 12) {
      HStack {
        Spacer(minLength: 0)

        Button {
          guard viewModel.hasPages else { return }
          showingPageJumpSheet = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "bookmark")
            Text("\(displayedCurrentPage) / \(currentSegmentPageCount)")
              .monospacedDigit()
          }
        }
        .contentShape(Capsule())
        .adaptiveButtonStyle(buttonStyle)
        #if os(tvOS)
          .focused($focusedControl, equals: .pageNumber)
        #endif

        Spacer(minLength: 0)
      }
      .optimizedControlSize()
      .allowsHitTesting(true)

      ReadingProgressBar(progress: progress, type: .reader)
        .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
        .shadow(
          color: readerControlsGradientBackground ? .clear : .black.opacity(0.4),
          radius: readerControlsGradientBackground ? 0 : 4,
          x: 0,
          y: readerControlsGradientBackground ? 0 : 2
        )
    }
    .padding()
    .iPadIgnoresSafeArea(paddingTop: 24)
    .background {
      if readerControlsGradientBackground {
        gradientBackground(startPoint: .bottom, endPoint: .top)
          .ignoresSafeArea(edges: .bottom)
      }
    }
  }

  @ViewBuilder
  private func menuContent() -> some View {
    Section {
      Picker(selection: $readingDirection) {
        ForEach(ReadingDirection.availableCases, id: \.self) { direction in
          Label(direction.displayName, systemImage: direction.icon)
            .tag(direction)
        }
      } label: {
        Label(String(localized: "Reading Direction"), systemImage: readingDirection.icon)
      }
      .pickerStyle(.menu)

      if readingDirection != .webtoon && readingDirection != .vertical {
        Picker(selection: $pageLayout) {
          ForEach(PageLayout.allCases, id: \.self) { layout in
            Label(layout.displayName, systemImage: layout.icon)
              .tag(layout)
          }
        } label: {
          Label(String(localized: "Page Layout"), systemImage: pageLayout.icon)
        }
        .pickerStyle(.menu)

        if enableDualPageOptions {
          pageIsolation()
        }
      }

      if readingDirection != .webtoon && (pageLayout == .single || pageLayout == .auto) {
        Picker(selection: $splitWidePageMode) {
          ForEach(SplitWidePageMode.allCases, id: \.self) { mode in
            Label(mode.displayName, systemImage: mode.icon).tag(mode)
          }
        } label: {
          Label(String(localized: "Split Wide Pages"), systemImage: splitWidePageMode.icon)
        }
        .pickerStyle(.menu)
      }
    } header: {
      Text(String(localized: "Current Reading Options"))
    }

    Button {
      showingReaderSettingsSheet = true
    } label: {
      Label(String(localized: "Reader Settings"), systemImage: "gearshape")
    }

    Section {
      pageNavigation()
    } header: {
      Text(String(localized: "Page Navigation"))
    }

    Section {
      bookNavigation()
    } header: {
      Text(String(localized: "Book Navigation"))
    }

    #if os(iOS) || os(macOS)
      if viewModel.currentPageIndex < viewModel.pageCount {
        Section {
          if dualPage, let pair = viewModel.currentPagePair() {
            share(firstPage: pair.first, secondPage: pair.second)
          } else {
            share(firstPage: viewModel.currentPageIndex, secondPage: nil)
          }
        } header: {
          Text(String(localized: "Share"))
        }
      }
    #endif
  }

  @ViewBuilder
  private func gradientBackground(
    startPoint: UnitPoint,
    endPoint: UnitPoint
  ) -> some View {
    LinearGradient(
      gradient: Gradient(colors: [
        Color.black.opacity(0.6),
        Color.black.opacity(0.3),
        Color.clear,
      ]),
      startPoint: startPoint,
      endPoint: endPoint
    )
  }

  @ViewBuilder
  private func pageIsolation() -> some View {
    Button {
      isolateCoverPage.toggle()
    } label: {
      Label(
        String(localized: "Isolate Cover Page"),
        systemImage: isolateCoverPage ? "checkmark.rectangle.portrait" : "rectangle.portrait"
      )
    }

    if isCurrentPageValid {
      if viewModel.isCurrentPageIsolated {
        Button {
          viewModel.toggleIsolatePage(viewModel.currentPageIndex)
        } label: {
          Label(String(localized: "Cancel Isolation"), systemImage: "rectangle.portrait.slash")
        }
      } else if dualPage, let pair = viewModel.currentPagePair(),
        let secondPage = pair.second,
        pair.first < viewModel.pageCount,
        secondPage < viewModel.pageCount
      {
        let leftPage = readingDirection == .rtl ? secondPage : pair.first
        let rightPage = readingDirection == .rtl ? pair.first : secondPage
        Button {
          viewModel.toggleIsolatePage(leftPage)
        } label: {
          let displayedPageNumber = displayPageNumber(forPageIndex: leftPage)
          Label(
            String.localizedStringWithFormat(String(localized: "Isolate Page %d"), displayedPageNumber),
            systemImage: "rectangle.lefthalf.inset.filled"
          )
        }
        Button {
          viewModel.toggleIsolatePage(rightPage)
        } label: {
          let displayedPageNumber = displayPageNumber(forPageIndex: rightPage)
          Label(
            String.localizedStringWithFormat(String(localized: "Isolate Page %d"), displayedPageNumber),
            systemImage: "rectangle.righthalf.inset.filled"
          )
        }
      }
    }
  }

  @ViewBuilder
  private func pageNavigation() -> some View {
    if !viewModel.tableOfContents.isEmpty {
      Button {
        showingTOCSheet = true
      } label: {
        Label(String(localized: "Table of Contents"), systemImage: "list.bullet")
      }
    }
    Button {
      guard viewModel.hasPages else { return }
      showingPageJumpSheet = true
    } label: {
      Label(String(localized: "Jump to Page"), systemImage: "bookmark")
    }
    .disabled(!viewModel.hasPages)
  }

  @ViewBuilder
  private func bookNavigation() -> some View {
    if let previousBook, let onPreviousBook {
      let previousNumber =
        previousBook.metadata.number.isEmpty
        ? nil
        : previousBook.metadata.number
      Button {
        onPreviousBook(previousBook.id)
      } label: {
        Label(
          "\(String(localized: "reader.previousBook")) #\(previousNumber ?? "-")",
          systemImage: "chevron.left"
        )
      }
    }

    if let nextBook, let onNextBook {
      let nextNumber =
        nextBook.metadata.number.isEmpty
        ? nil
        : nextBook.metadata.number
      Button {
        onNextBook(nextBook.id)
      } label: {
        Label(
          "\(String(localized: "reader.nextBook")) #\(nextNumber ?? "-")",
          systemImage: "chevron.right"
        )
      }
    }
  }

  #if os(iOS) || os(macOS)
    @ViewBuilder
    private func share(firstPage: Int, secondPage: Int?) -> some View {
      Button {
        sharePage(index: firstPage)
      } label: {
        let displayedPageNumber = displayPageNumber(forPageIndex: firstPage)
        Label(
          String.localizedStringWithFormat(sharePageFormat, displayedPageNumber),
          systemImage: "square.and.arrow.up"
        )
      }
      if let secondPage {
        Button {
          sharePage(index: secondPage)
        } label: {
          let displayedPageNumber = displayPageNumber(forPageIndex: secondPage)
          Label(
            String.localizedStringWithFormat(sharePageFormat, displayedPageNumber),
            systemImage: "square.and.arrow.up.on.square"
          )
        }
      }
    }
  #endif
}
