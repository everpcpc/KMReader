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
  @Binding var dualPageNoCover: Bool

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
      case pageNumber
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
          .contentShape(RoundedRectangle(cornerRadius: 12))
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

        Menu {
          menuContent()
        } label: {
          Image(systemName: "ellipsis")
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
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          #if os(tvOS)
            .focused($focusedControl, equals: .pageNumber)
          #endif

          Spacer(minLength: 0)
        }
        .optimizedControlSize()
        .allowsHitTesting(true)

        // Bottom slider
        ReadingProgressBar(progress: progress)
          .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
    }
    #if os(iOS)
      .tint(.primary)
    #endif
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

  @ViewBuilder
  private func menuContent() -> some View {
    Section {
      Picker(String(localized: "Reading Direction"), selection: $readingDirection) {
        ForEach(ReadingDirection.availableCases, id: \.self) { direction in
          Label(direction.displayName, systemImage: direction.icon)
            .tag(direction)
        }
      }
      .pickerStyle(.menu)

      if readingDirection != .webtoon && readingDirection != .vertical {
        Picker(String(localized: "Page Layout"), selection: $pageLayout) {
          ForEach(PageLayout.allCases, id: \.self) { layout in
            Label(layout.displayName, systemImage: layout.icon)
              .tag(layout)
          }
        }
        .pickerStyle(.menu)

        if pageLayout.supportsDualPageOptions {
          Toggle(String(localized: "Show Cover in Dual Spread"), isOn: $dualPageNoCover)
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
    } header: {
      Text(String(localized: "Page Navigation"))
    }

    Section {
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
    } header: {
      Text(String(localized: "Book Navigation"))
    }

    #if os(iOS) || os(macOS)
      Section {
        if dualPage, let pair = viewModel.dualPageIndices[viewModel.currentPageIndex],
          let secondIndex = pair.second
        {
          Button {
            sharePage(index: pair.first)
          } label: {
            Label(
              String.localizedStringWithFormat(sharePageFormat, pair.first + 1),
              systemImage: "square.and.arrow.up"
            )
          }
          Button {
            sharePage(index: secondIndex)
          } label: {
            Label(
              String.localizedStringWithFormat(sharePageFormat, secondIndex + 1),
              systemImage: "square.and.arrow.up.on.square"
            )
          }
        } else {
          Button {
            sharePage(index: viewModel.currentPageIndex)
          } label: {
            Label(
              String.localizedStringWithFormat(
                sharePageFormat, viewModel.currentPageIndex + 1),
              systemImage: "square.and.arrow.up"
            )
          }
        }
      } header: {
        Text(String(localized: "Share"))
      }
    #endif
  }
}
