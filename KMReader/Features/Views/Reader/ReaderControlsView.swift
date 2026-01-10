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

  @Binding var showingPageJumpSheet: Bool
  @Binding var showingTOCSheet: Bool
  @Binding var showingReaderSettingsSheet: Bool
  @Binding var showingSeriesDetailSheet: Bool
  @Binding var showingBookDetailSheet: Bool

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

  #if os(iOS) || os(macOS)
    private func shareCurrentPage() {
      let indices: [Int]
      if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex] {
        indices = [pair.first, pair.second].compactMap { $0 }
      } else {
        indices = [viewModel.currentPageIndex]
      }

      var images: [PlatformImage] = []
      var names: [String] = []

      for index in indices {
        if index >= 0 && index < viewModel.pages.count {
          let page = viewModel.pages[index]
          if let image = viewModel.preloadedImages[page.number] {
            images.append(image)
            names.append(page.fileName)
          }
        }
      }

      guard !images.isEmpty else { return }
      ImageShareHelper.shareMultiple(images: images, fileNames: names)
    }
  #endif

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
        .buttonBorderShape(.circle)
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
          .optimizedControlSize()
          .adaptiveButtonStyle(buttonStyle)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          .simultaneousGesture(
            LongPressGesture()
              .onEnded { _ in
                if currentSeries != nil {
                  showingSeriesDetailSheet = true
                }
              }
          )
        }

        Spacer()

        // Settings buttons
        Button {
          showingReaderSettingsSheet = true
        } label: {
          Image(systemName: "gearshape")
        }
        .controlSize(.large)
        .buttonBorderShape(.circle)
        .adaptiveButtonStyle(buttonStyle)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        #if os(tvOS)
          .focused($focusedControl, equals: .settings)
        #endif

      }
      .allowsHitTesting(true)

      Spacer()

      // Bottom section with page info and slider
      VStack(spacing: 12) {
        // Page info display with navigation buttons
        HStack {
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

          Spacer(minLength: 0)

          #if os(iOS) || os(macOS)
            // Share button
            Button {
              shareCurrentPage()
            } label: {
              Image(systemName: "square.and.arrow.up")
            }
            .contentShape(Circle())
            .buttonBorderShape(.circle)
            .adaptiveButtonStyle(buttonStyle)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          #endif

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
            .contentShape(Circle())
            .buttonBorderShape(.circle)
            .adaptiveButtonStyle(buttonStyle)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            #if os(tvOS)
              .focused($focusedControl, equals: .toc)
            #endif
          }

          Spacer(minLength: 0)

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
    .tint(.primary)
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
  }
}
