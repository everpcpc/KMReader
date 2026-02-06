//
//  DivinaControlsOverlayView.swift
//  Komga
//
//  Created by Komga iOS Client
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

  private var progress: Double {
    guard viewModel.pages.count > 0 else { return 0 }
    return Double(min(viewModel.currentPageIndex + 1, viewModel.pages.count))
      / Double(viewModel.pages.count)
  }

  private var displayedCurrentPage: String {
    guard viewModel.pages.count > 0 else { return "0" }
    if viewModel.currentPageIndex >= viewModel.pages.count {
      return String(localized: "reader.page.end")
    } else {
      if dualPage, let pair = viewModel.currentPagePair() {
        return displayPagePair(first: pair.first, second: pair.second)
      } else {
        return String(viewModel.currentPageIndex + 1)
      }
    }
  }

  private func displayPagePair(first: Int, second: Int?) -> String {
    guard let second else { return "\(first + 1)" }
    if readingDirection == .rtl {
      return "\(second + 1),\(first + 1)"
    }
    return "\(first + 1),\(second + 1)"
  }

  private var enableDualPageOptions: Bool {
    return readingDirection != .webtoon && readingDirection != .vertical && pageLayout.supportsDualPageOptions
  }

  private var isCurrentPageValid: Bool {
    return viewModel.currentPageIndex >= 0 && viewModel.currentPageIndex < viewModel.pages.count
  }

  #if os(iOS) || os(macOS)
    private func sharePages(indices: [Int]) {
      var images: [PlatformImage] = []
      var names: [String] = []

      for index in indices {
        if index >= 0 && index < viewModel.pages.count {
          let page = viewModel.pages[index]
          if let image = viewModel.preloadedImages[index] {
            images.append(image)
            names.append(page.fileName)
          }
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
          .padding(.horizontal, 4)
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
          guard !viewModel.pages.isEmpty else { return }
          showingPageJumpSheet = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "bookmark")
            Text("\(displayedCurrentPage) / \(viewModel.pages.count)")
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
      if viewModel.currentPageIndex < viewModel.pages.count {
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
        pair.first < viewModel.pages.count,
        secondPage < viewModel.pages.count
      {
        let leftPage = readingDirection == .rtl ? secondPage : pair.first
        let rightPage = readingDirection == .rtl ? pair.first : secondPage
        Button {
          viewModel.toggleIsolatePage(leftPage)
        } label: {
          Label(
            String.localizedStringWithFormat(String(localized: "Isolate Page %d"), leftPage + 1),
            systemImage: "rectangle.lefthalf.inset.filled"
          )
        }
        Button {
          viewModel.toggleIsolatePage(rightPage)
        } label: {
          Label(
            String.localizedStringWithFormat(String(localized: "Isolate Page %d"), rightPage + 1),
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
      guard !viewModel.pages.isEmpty else { return }
      showingPageJumpSheet = true
    } label: {
      Label(String(localized: "Jump to Page"), systemImage: "bookmark")
    }
    .disabled(viewModel.pages.isEmpty)
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
        Label(
          String.localizedStringWithFormat(sharePageFormat, firstPage + 1),
          systemImage: "square.and.arrow.up"
        )
      }
      if let secondPage {
        Button {
          sharePage(index: secondPage)
        } label: {
          Label(
            String.localizedStringWithFormat(sharePageFormat, secondPage + 1),
            systemImage: "square.and.arrow.up.on.square"
          )
        }
      }
    }
  #endif
}
