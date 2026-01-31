//
//  ReaderControlsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI
import UniformTypeIdentifiers

struct ReaderControlsView: View {
  @Binding var showingControls: Bool
  @Binding var readingDirection: ReadingDirection
  @Binding var pageLayout: PageLayout
  @Binding var isolateCoverPage: Bool
  @Binding var splitWidePages: Bool
  @Binding var swapSplitPageOrder: Bool

  @Binding var showingPageJumpSheet: Bool
  @Binding var showingTOCSheet: Bool
  @Binding var showingReaderSettingsSheet: Bool
  @Binding var showingDetailSheet: Bool

  @AppStorage("readerControlsGradientBackground") private var readerControlsGradientBackground: Bool = false

  let viewModel: ReaderViewModel
  let currentBook: Book?
  let currentSeries: Series?
  let dualPage: Bool
  let incognito: Bool
  let onDismiss: () -> Void
  let previousBook: Book?
  let nextBook: Book?
  let onPreviousBook: ((String) -> Void)?
  let onNextBook: ((String) -> Void)?

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?

  #if os(tvOS)
    private enum ControlFocus: Hashable {
      case close
      case title
      case settings
      case pageNumber
    }
    @FocusState private var focusedControl: ControlFocus?
  #endif

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  private var buttonStyle: AdaptiveButtonStyleType {
    return .bordered
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
      if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex] {
        return pair.display(readingDirection: readingDirection)
      } else {
        return String(viewModel.currentPageIndex + 1)
      }
    }
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
    VStack {

      // Top bar
      HStack(alignment: .top) {
        // Close button
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
        }
        .contentShape(Circle())
        .controlSize(.large)
        .buttonBorderShape(.circle)
        .adaptiveButtonStyle(buttonStyle)
        #if os(tvOS)
          .focused($focusedControl, equals: .close)
          .id("closeButton")
        #endif

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
        .contentShape(Circle())
        .controlSize(.large)
        .buttonBorderShape(.circle)
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
          LinearGradient(
            gradient: Gradient(colors: [
              Color.black.opacity(0.6),
              Color.black.opacity(0.3),
              Color.clear,
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea(edges: .top)
        }
      }

      Spacer()

      // Bottom section with page info and slider
      VStack(spacing: 12) {
        // Page info display with navigation buttons
        HStack {
          Spacer(minLength: 0)

          // Page info - tappable to open jump sheet
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
          .contentShape(Rectangle())
          .adaptiveButtonStyle(buttonStyle)
          #if os(tvOS)
            .focused($focusedControl, equals: .pageNumber)
          #endif

          Spacer(minLength: 0)
        }
        .optimizedControlSize()
        .allowsHitTesting(true)

        // Bottom slider
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
          LinearGradient(
            gradient: Gradient(colors: [
              Color.clear,
              Color.black.opacity(0.3),
              Color.black.opacity(0.6),
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea(edges: .bottom)
        }
      }
    }
    #if os(iOS)
      .tint(.primary)
    #endif
    .transition(.opacity)
    #if os(tvOS)
      .onAppear {
        if showingControls {
          focusedControl = .close
        }
      }
      .onChange(of: showingControls) { _, newValue in
        if newValue {
          focusedControl = .close
        } else {
          focusedControl = nil
        }
      }
      .onChange(of: focusedControl) { _, newValue in
        if showingControls && newValue == nil {
          focusedControl = .close
        }
      }
      .focusSection()
    #endif
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

      // Wide page splitting options (not for webtoon)
      if readingDirection != .webtoon {
        Button {
          splitWidePages.toggle()
        } label: {
          Label(
            String(localized: "Split Wide Pages"),
            systemImage: splitWidePages ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
          )
        }

        if splitWidePages {
          Button {
            swapSplitPageOrder.toggle()
          } label: {
            Label(
              String(localized: "Swap Split Page Order"),
              systemImage: swapSplitPageOrder ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle"
            )
          }
        }
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
          if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex] {
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
        // Current page is already isolated, show cancel button
        Button {
          viewModel.toggleIsolatePage(viewModel.currentPageIndex)
        } label: {
          Label(String(localized: "Cancel Isolation"), systemImage: "rectangle.portrait.slash")
        }
      } else if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex],
        let secondPage = pair.second,
        pair.first < viewModel.pages.count,
        secondPage < viewModel.pages.count
      {
        // Dual page mode with two pages, show separate buttons
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
