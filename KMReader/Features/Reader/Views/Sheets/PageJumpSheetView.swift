//
// PageJumpSheetView.swift
//
//

import SwiftUI

// Simple page preview card for native scroll
private struct PagePreviewCard: View {

  let readerPage: ReaderPage
  let displayPage: Int
  let isSelected: Bool
  let imageHeight: CGFloat

  @State private var loadedImage: PlatformImage?

  private var imageWidth: CGFloat {
    imageHeight * 0.72
  }

  var body: some View {
    VStack(spacing: 8) {
      Group {
        if let platformImage = loadedImage {
          Image(platformImage: platformImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        } else {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .overlay {
              ProgressView()
            }
        }
      }
      .frame(width: imageWidth, height: imageHeight)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
      )
      .shadow(
        color: Color.black.opacity(isSelected ? 0.3 : 0.15),
        radius: isSelected ? 8 : 4, x: 0, y: 2
      )
      .scaleEffect(isSelected ? 1.0 : 0.9)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

      Text("\(displayPage)")
        .font(.caption)
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
    }
    .task(id: "\(readerPage.id.description)-\(Int(imageHeight))") {
      loadedImage = nil
      if let url = try? await ThumbnailCache.shared.ensureThumbnail(
        id: readerPage.bookId,
        type: .page,
        page: readerPage.pageNumber
      ) {
        loadedImage = PlatformImage(contentsOfFile: url.path)
      }
    }
  }
}

struct PageJumpSheetView: View {
  let currentPage: Int
  let readingDirection: ReadingDirection
  let viewModel: ReaderViewModel
  let onJump: (Int) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var pageValue: Int
  @State private var scrollPosition: Int?

  private var currentBookId: String? {
    viewModel.activeBookId
  }

  private var currentSegmentRange: Range<Int> {
    guard let currentBookId,
      let range = viewModel.pageRange(forSegmentBookId: currentBookId)
    else {
      return 0..<0
    }
    return range
  }

  private var totalPages: Int {
    pagePreviews.count
  }

  private var pagePreviews: [PagePreview] {
    currentSegmentRange.enumerated().compactMap { localIndex, globalIndex in
      guard let readerPage = viewModel.readerPage(at: globalIndex) else { return nil }
      return PagePreview(
        id: localIndex + 1,
        globalPageIndex: globalIndex,
        readerPage: readerPage
      )
    }
  }

  private var maxPage: Int {
    max(totalPages, 1)
  }

  private var canJump: Bool {
    totalPages > 0
  }

  private var sliderBinding: Binding<Double> {
    Binding(
      get: { Double(pageValue) },
      set: { newValue in
        let newPage = Int(newValue.rounded())
        if newPage != pageValue {
          pageValue = newPage
        }
      }
    )
  }

  init(
    currentPage: Int,
    readingDirection: ReadingDirection = .ltr,
    viewModel: ReaderViewModel,
    onJump: @escaping (Int) -> Void
  ) {
    self.currentPage = currentPage
    self.readingDirection = readingDirection
    self.viewModel = viewModel
    self.onJump = onJump

    let totalReaderPages = viewModel.pageCount
    let safeInitialPage = max(1, min(currentPage, max(totalReaderPages, 1)))
    _pageValue = State(initialValue: safeInitialPage)
    _scrollPosition = State(initialValue: safeInitialPage)
  }

  private var sliderScaleX: CGFloat {
    readingDirection == .rtl ? -1 : 1
  }

  private var pageLabels: (left: String, right: String) {
    if readingDirection == .rtl {
      return (left: "\(totalPages)", right: "1")
    } else {
      return (left: "1", right: "\(totalPages)")
    }
  }

  private func pagePreview(localPage: Int) -> PagePreview? {
    pagePreviews.first(where: { $0.id == localPage })
  }

  private func jumpToPage() {
    guard canJump else { return }
    let clampedValue = min(max(pageValue, 1), totalPages)
    guard let preview = pagePreview(localPage: clampedValue) else { return }
    onJump(preview.globalPageIndex + 1)
    dismiss()
  }

  private func adjustPage(step: Int) {
    guard canJump else { return }
    let newValue = min(max(pageValue + step, 1), maxPage)
    pageValue = newValue
    scrollPosition = newValue
  }

  #if os(iOS) || os(macOS)
    private func sharePage() async {
      let pageNumber = pageValue
      guard pageNumber > 0 && pageNumber <= totalPages else { return }
      guard let preview = pagePreview(localPage: pageNumber) else { return }
      let pageIndex = preview.globalPageIndex
      let readerPage = preview.readerPage

      // Use viewModel's method to get page image (checks cache, offline, downloads if needed)
      guard let fileURL = await viewModel.getPageImageFileURL(pageIndex: pageIndex) else { return }
      guard let image = PlatformImage(contentsOfFile: fileURL.path) else { return }

      ImageShareHelper.shareMultiple(images: [image], fileNames: [readerPage.page.fileName])
    }
  #endif

  var body: some View {
    SheetView(title: String(localized: "Go to Page"), size: .medium) {
      VStack(spacing: 16) {
        if canJump {
          Text("Current page: \(currentPage)")
            .foregroundStyle(.secondary)
        }

        if canJump {
          VStack(spacing: 16) {
            // Native paging scroll view
            GeometryReader { geometry in
              let imageHeight = min(geometry.size.height - 40, 250)

              ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                  LazyHStack(spacing: 8) {
                    ForEach(pagePreviews) { preview in
                      PagePreviewCard(
                        readerPage: preview.readerPage,
                        displayPage: preview.id,
                        isSelected: preview.id == pageValue,
                        imageHeight: imageHeight
                      )
                      .id(preview.id)
                    }
                  }
                  .scrollTargetLayout()
                }
                .contentMargins(
                  .horizontal, (geometry.size.width - imageHeight * 0.72) / 2, for: .scrollContent
                )
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .environment(
                  \.layoutDirection, readingDirection == .rtl ? .rightToLeft : .leftToRight
                )
                .onAppear {
                  // Initial scroll to current page
                  proxy.scrollTo(pageValue, anchor: .center)
                }
                .onChange(of: scrollPosition) { _, newValue in
                  // User scrolled - update pageValue
                  if let page = newValue {
                    pageValue = page
                  }
                }
                .onChange(of: pageValue) { oldValue, newValue in
                  // Slider changed - scroll to new page (only if different from scroll position)
                  if scrollPosition != newValue {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                      proxy.scrollTo(newValue, anchor: .center)
                    }
                  }
                }
              }
            }
            .frame(minHeight: 200, maxHeight: 320)

            #if os(tvOS)
              VStack(spacing: 40) {
                HStack(spacing: 20) {
                  Text(pageLabels.left)
                    .foregroundStyle(.secondary)
                  Button {
                    adjustPage(step: readingDirection == .rtl ? 1 : -1)
                  } label: {
                    Image(
                      systemName: readingDirection == .rtl
                        ? "plus.circle.fill" : "minus.circle.fill")
                  }

                  Text("Page \(pageValue)")
                    .monospacedDigit()

                  Button {
                    adjustPage(step: readingDirection == .rtl ? -1 : 1)
                  } label: {
                    Image(
                      systemName: readingDirection == .rtl
                        ? "minus.circle.fill" : "plus.circle.fill")
                  }
                  Text(pageLabels.right)
                    .foregroundStyle(.secondary)
                }

                Button {
                  jumpToPage()
                } label: {
                  HStack(spacing: 4) {
                    Spacer()
                    Text("Jump")
                    Image(systemName: "arrow.right.to.line")
                    Spacer()
                  }
                }
                .adaptiveButtonStyle(.borderedProminent)
                .disabled(!canJump || pageValue == currentPage)
              }
              .focusSection()
            #else
              VStack(spacing: 0) {
                Slider(
                  value: sliderBinding,
                  in: 1...Double(maxPage),
                  step: 1
                )
                .scaleEffect(x: sliderScaleX, y: 1)
                HStack {
                  Text(pageLabels.left)
                  Spacer()
                  Text(pageLabels.right)
                }
                .foregroundStyle(.secondary)
              }

              HStack {
                Button {
                  jumpToPage()
                } label: {
                  HStack(spacing: 4) {
                    Text("Jump")
                    Image(systemName: "arrow.right.to.line")
                  }
                }
                .adaptiveButtonStyle(.borderedProminent)
                .disabled(!canJump || pageValue == currentPage)
              }
            #endif
          }
        }
        Spacer()
      }
      .padding()
    } controls: {
      #if os(iOS) || os(macOS)
        Button {
          Task {
            await sharePage()
          }
        } label: {
          Image(systemName: "square.and.arrow.up")
        }
        .disabled(!canJump)
      #endif
    }
    .presentationDragIndicator(.visible)
  }
}

private struct PagePreview: Identifiable {
  let id: Int
  let globalPageIndex: Int
  let readerPage: ReaderPage
}
