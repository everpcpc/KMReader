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
  @Binding var pageLayout: PageLayout
  @Binding var dualPageNoCover: Bool
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let bookId: String
  let dualPage: Bool
  let incognito: Bool
  let onDismiss: () -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let previousBook: Book?
  let nextBook: Book?
  let onPreviousBook: ((String) -> Void)?
  let onNextBook: ((String) -> Void)?

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @State private var showingPageJumpSheet = false
  @State private var showingTOCSheet = false
  @State private var showingReaderSettingsSheet = false
  @State private var showingBookDetailSheet = false
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

  private var buttonStyle: AdaptiveButtonStyleType {
    return .borderedProminent
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

  private var leftButtonLabel: String {
    readingDirection == .rtl
      ? String(localized: "reader.nextBook") : String(localized: "reader.previousBook")
  }

  private var rightButtonLabel: String {
    readingDirection == .rtl
      ? String(localized: "reader.previousBook") : String(localized: "reader.nextBook")
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
        }
        .controlSize(.large)
        .adaptiveButtonStyle(buttonStyle)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        #if os(tvOS)
          .focused($focusedControl, equals: .close)
          .id("closeButton")
        #endif

        Spacer()

        // Series and book title
        if let book = currentBook {
          Button {
            showingBookDetailSheet = true
          } label: {
            HStack {
              if incognito {
                Image(systemName: "eye.slash.fill")
                  .font(.title3)
              }
              VStack(alignment: incognito ? .leading : .center, spacing: 4) {
                if book.oneshot {
                  Text(book.metadata.title)
                    .lineLimit(2)
                } else {
                  Text(book.seriesTitle)
                    .font(.caption)
                    .lineLimit(1)
                  Text("#\(book.metadata.number) - \(book.metadata.title)")
                    .lineLimit(1)
                }
              }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
          }
          .optimizedControlSize()
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }

        Spacer()

        // Action buttons
        HStack(spacing: PlatformHelper.buttonSpacing) {
          // Reader settings button
          Button {
            showingReaderSettingsSheet = true
          } label: {
            Image(systemName: "gearshape")
          }
          .controlSize(.large)
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          #if os(tvOS)
            .focused($focusedControl, equals: .settings)
          #endif
        }

      }.allowsHitTesting(true)

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
              Text(leftButtonLabel)
            }
          }
          .contentShape(Rectangle())
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
          }
          .contentShape(Rectangle())
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          #if os(tvOS)
            .focused($focusedControl, equals: .pageNumber)
          #endif

          // TOC button (only show if TOC exists)
          if !viewModel.tableOfContents.isEmpty {
            Button {
              showingTOCSheet = true
            } label: {
              Image(systemName: "list.bullet")
                .padding(2)
            }
            .contentShape(Rectangle())
            .adaptiveButtonStyle(buttonStyle)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
              Text(rightButtonLabel)
              Image(systemName: "chevron.right")
            }
          }
          .contentShape(Rectangle())
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          .opacity((readingDirection == .rtl ? previousBook : nextBook) != nil ? 1.0 : 0.0)
          .disabled((readingDirection == .rtl ? previousBook : nextBook) == nil)
          #if os(tvOS)
            .focused(
              $focusedControl, equals: readingDirection == .rtl ? .previousBook : .nextBook)
          #endif
        }
        .optimizedControlSize()
        .allowsHitTesting(true)

        // Bottom slider
        ReadingProgressBar(progress: progress)
          .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
    }
    .padding()
    .iPadIgnoresSafeArea(paddingTop: 24)
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
        pageLayout: $pageLayout,
        dualPageNoCover: $dualPageNoCover
      )
    }
    .sheet(isPresented: $showingBookDetailSheet) {
      if let book = currentBook {
        SheetView(title: book.metadata.title, size: .large) {
          ScrollView {
            BookDetailContentView(
              book: book,
              downloadStatus: nil,
              inSheet: true,
            ).padding(.horizontal)
          }
        }
      }
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
