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
  @Binding var showingKeyboardHelp: Bool
  @Binding var readingDirection: ReadingDirection
  @Binding var readerBackground: ReaderBackground
  @Binding var pageLayout: PageLayout
  @Binding var dualPageNoCover: Bool
  @Binding var webtoonPageWidthPercentage: Double
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let bookId: String
  let dualPage: Bool
  let onDismiss: () -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let previousBook: Book?
  let nextBook: Book?
  let onPreviousBook: ((String) -> Void)?
  let onNextBook: ((String) -> Void)?

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @State private var showingPageJumpSheet = false
  @State private var showingTOCSheet = false
  @State private var showingReaderSettingsSheet = false
  #if os(tvOS)
    private enum ControlFocus: Hashable {
      case close
      case previousBook
      case pageNumber
      case toc
      case nextBook
      case settings
    }
    @FocusState private var focusedControl: ControlFocus?
  #endif

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  private var buttonPadding: CGFloat {
    #if os(tvOS)
      return 12
    #else
      return 6
    #endif
  }

  private var buttonMargin: CGFloat {
    #if os(tvOS)
      return 36
    #else
      return 12
    #endif
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

  var body: some View {
    VStack {

      // Top bar
      HStack(alignment: .top) {
        // Close button
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundColor(.white)
            .frame(minWidth: 40, minHeight: 40)
            .padding(buttonPadding)
            .background(themeColor.color.opacity(0.9))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        #if os(tvOS)
          .focused($focusedControl, equals: .close)
          .id("closeButton")
        #endif

        Spacer()

        // Series and book title
        if let book = currentBook {
          VStack(spacing: 4) {
            Text(book.seriesTitle)
              .font(.footnote)
              .foregroundColor(.white)
            Text("#\(book.metadata.number) - \(book.metadata.title)")
              .font(.callout)
              .foregroundColor(.white)
          }
          .padding(.vertical, buttonPadding)
          .padding(.horizontal, buttonMargin)
          .background(themeColor.color.opacity(0.9))
          .cornerRadius(12)
        }

        Spacer()

        // Action buttons
        HStack(spacing: PlatformHelper.buttonSpacing) {

          // Reader settings button
          Button {
            showingReaderSettingsSheet = true
          } label: {
            Image(systemName: "gearshape")
              .foregroundColor(.white)
              .frame(width: 40, height: 40)
              .padding(buttonPadding)
              .background(themeColor.color.opacity(0.9))
              .clipShape(Circle())
              .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          #if os(tvOS)
            .focused($focusedControl, equals: .settings)
          #endif
        }

      }
      .adaptiveButtonStyle(.plain)
      .padding(.horizontal, buttonMargin)
      .padding(.vertical, buttonPadding)
      .allowsHitTesting(true)

      Spacer()

      // Bottom section with page info and slider
      VStack(spacing: 12) {
        // Page info display with navigation buttons
        HStack(spacing: PlatformHelper.buttonSpacing) {
          // Left button (previous for LTR, next for RTL)
          Button {
            if readingDirection == .rtl {
              if let nextBook = nextBook, let onNextBook = onNextBook {
                onNextBook(nextBook.id)
              }
            } else {
              if let previousBook = previousBook, let onPreviousBook = onPreviousBook {
                onPreviousBook(previousBook.id)
              }
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "chevron.left")
                .font(.footnote.weight(.semibold))
              Text(
                String(
                  localized: readingDirection == .rtl ? "reader.nextBook" : "reader.previousBook")
              )
              .font(.footnote.weight(.medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, buttonMargin)
            .padding(.vertical, buttonPadding)
            .background(themeColor.color.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .adaptiveButtonStyle(.plain)
          .opacity((readingDirection == .rtl ? nextBook : previousBook) != nil ? 1.0 : 0.0)
          .disabled((readingDirection == .rtl ? nextBook : previousBook) == nil)
          #if os(tvOS)
            .focused(
              $focusedControl, equals: readingDirection == .rtl ? .nextBook : .previousBook)
          #endif

          Spacer()

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
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, buttonMargin)
            .padding(.vertical, buttonPadding)
            .background(themeColor.color.opacity(0.9))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .adaptiveButtonStyle(.plain)
          #if os(tvOS)
            .focused($focusedControl, equals: .pageNumber)
          #endif

          // TOC button (only show if TOC exists)
          if !viewModel.tableOfContents.isEmpty {
            Button {
              showingTOCSheet = true
            } label: {
              Image(systemName: "list.bullet")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
                .padding(buttonPadding)
                .background(themeColor.color.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .adaptiveButtonStyle(.plain)
            #if os(tvOS)
              .focused($focusedControl, equals: .toc)
            #endif
          }

          Spacer()

          // Right button (next for LTR, previous for RTL)
          Button {
            if readingDirection == .rtl {
              if let previousBook = previousBook, let onPreviousBook = onPreviousBook {
                onPreviousBook(previousBook.id)
              }
            } else {
              if let nextBook = nextBook, let onNextBook = onNextBook {
                onNextBook(nextBook.id)
              }
            }
          } label: {
            HStack(spacing: 4) {
              Text(
                String(
                  localized: readingDirection == .rtl ? "reader.previousBook" : "reader.nextBook")
              )
              .font(.footnote.weight(.medium))
              Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, buttonMargin)
            .padding(.vertical, buttonPadding)
            .background(themeColor.color.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .adaptiveButtonStyle(.plain)
          .opacity((readingDirection == .rtl ? previousBook : nextBook) != nil ? 1.0 : 0.0)
          .disabled((readingDirection == .rtl ? previousBook : nextBook) == nil)
          #if os(tvOS)
            .focused(
              $focusedControl, equals: readingDirection == .rtl ? .previousBook : .nextBook)
          #endif
        }

        // Bottom slider
        ReadingProgressBar(progress: progress, backgroundColor: .gray)
          .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
      }
      .padding()
    }
    .padding(.vertical)
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
    .sheet(isPresented: $showingPageJumpSheet) {
      PageJumpSheetView(
        bookId: bookId,
        totalPages: viewModel.pages.count,
        currentPage: min(viewModel.currentPageIndex + 1, viewModel.pages.count),
        readingDirection: readingDirection,
        onJump: jumpToPage
      )
    }
    .sheet(isPresented: $showingTOCSheet) {
      ReaderTOCSheetView(
        entries: viewModel.tableOfContents,
        currentPageIndex: viewModel.currentPageIndex,
        onSelect: { entry in
          showingTOCSheet = false
          jumpToTOCEntry(entry)
        }
      )
    }
    .sheet(isPresented: $showingReaderSettingsSheet) {
      ReaderSettingsSheet(
        readingDirection: $readingDirection,
        readerBackground: $readerBackground,
        pageLayout: $pageLayout,
        dualPageNoCover: $dualPageNoCover,
        webtoonPageWidthPercentage: $webtoonPageWidthPercentage
      )
    }
    .onChange(of: dualPageNoCover) { _, newValue in
      viewModel.updateDualPageSettings(noCover: newValue)
    }
  }

  #if os(macOS)
    func handleKeyCode(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) {
      // Handle ESC key to close window
      if keyCode == 53 {  // ESC key
        onDismiss()
        return
      }

      // Handle ? key and H key for keyboard help
      if keyCode == 44 {  // ? key (Shift + /)
        showingKeyboardHelp.toggle()
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
        showingControls.toggle()
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
        showingKeyboardHelp.toggle()
        return
      }

      // Handle C key for toggle controls
      if keyCode == 8 {  // C key
        showingControls.toggle()
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
        if let nextBook = nextBook, let onNextBook = onNextBook {
          onNextBook(nextBook.id)
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
}
