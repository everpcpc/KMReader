//
//  PageJumpSheetView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImage
import SDWebImageSwiftUI
import SwiftUI

// Preview dimensions calculated based on available height
private struct PreviewDimensions {
  let scaleFactor: CGFloat
  let imageWidth: CGFloat
  let imageHeight: CGFloat
  let centerY: CGFloat
  let spacing: CGFloat
}

// Page transform properties for fan effect
private struct PageTransform {
  let x: CGFloat
  let rotation: Double
  let scale: CGFloat
  let opacity: Double
  let zIndex: Int

  // Calculate constrained x position within slider bounds
  func constrainedX(_ imageWidth: CGFloat, _ sliderWidth: CGFloat) -> CGFloat {
    max(imageWidth / 2, min(x, sliderWidth - imageWidth / 2))
  }
}

// Single page preview item view
private struct PagePreviewItem: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  let page: Int
  let pageValue: Int
  let imageURL: URL?
  let availableHeight: CGFloat
  let sliderWidth: CGFloat
  let maxPage: Int
  let readingDirection: ReadingDirection

  // Calculate preview dimensions based on available height
  private var dimensions: PreviewDimensions {
    // Base values for standard height (360)
    let baseHeight: CGFloat = 360
    let baseImageWidth: CGFloat = 180
    let baseImageHeight: CGFloat = 250
    let baseSpacing: CGFloat = 120

    // Calculate scale factor based on available height
    let scaleFactor = min(1.0, availableHeight / baseHeight)

    // Apply scale factor to all dimensions
    let imageWidth = baseImageWidth * scaleFactor
    let imageHeight = baseImageHeight * scaleFactor
    let centerY = (baseHeight * scaleFactor) / 2
    let spacing = baseSpacing * scaleFactor

    return PreviewDimensions(
      scaleFactor: scaleFactor,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      centerY: centerY,
      spacing: spacing
    )
  }

  private var xOffsetMultiplier: CGFloat {
    readingDirection == .rtl ? -1 : 1
  }

  private var rotationMultiplier: Double {
    readingDirection == .rtl ? -1 : 1
  }

  private func adjustedProgress(for progress: Double) -> Double {
    readingDirection == .rtl ? 1.0 - progress : progress
  }

  private var transform: PageTransform {
    let isCenter = page == pageValue
    let offset = page - pageValue
    let progress = (Double(pageValue) - 1) / Double(maxPage - 1)
    let adjustedProgress = adjustedProgress(for: progress)
    let baseX = adjustedProgress * sliderWidth

    // Calculate position with fan effect
    let xOffset = CGFloat(offset) * dimensions.spacing * xOffsetMultiplier
    let x = baseX + xOffset
    let rotation = Double(offset) * 8.0 * rotationMultiplier
    let scale = isCenter ? 1.0 : 0.75
    let opacity = isCenter ? 1.0 : 0.6
    let zIndex = isCenter ? 10 : abs(offset)

    return PageTransform(
      x: x,
      rotation: rotation,
      scale: scale,
      opacity: opacity,
      zIndex: zIndex
    )
  }

  var body: some View {
    if let imageURL = imageURL {
      let isCenter = page == pageValue

      VStack {
        WebImage(
          url: imageURL,
          options: [.retryFailed, .scaleDownLargeImages],
          context: [.customManager: SDImageCacheProvider.thumbnailManager]
        )
        .resizable()
        .placeholder {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .overlay {
              ProgressView()
            }
        }
        .indicator(.activity)
        .aspectRatio(contentMode: .fit)
        .frame(width: dimensions.imageWidth, height: dimensions.imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(
          color: Color.black.opacity(isCenter ? 0.4 : 0.2),
          radius: isCenter ? 8 : 4, x: 0, y: 2)

        if isCenter {
          Text("\(page)")
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
              RoundedRectangle(cornerRadius: 4)
                .fill(themeColor.color)
            }
        }
      }
      .scaleEffect(transform.scale)
      .opacity(transform.opacity)
      .rotationEffect(.degrees(transform.rotation))
      .position(
        x: transform.constrainedX(dimensions.imageWidth, sliderWidth),
        y: dimensions.centerY
      )
      .zIndex(Double(transform.zIndex))
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pageValue)
    }
  }
}

struct PageJumpSheetView: View {
  let bookId: String
  let totalPages: Int
  let currentPage: Int
  let readingDirection: ReadingDirection
  let onJump: (Int) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var pageValue: Int

  private var maxPage: Int {
    max(totalPages, 1)
  }

  private var canJump: Bool {
    totalPages > 0
  }

  private var rangeDescription: String {
    canJump ? "Range: 1 – \(totalPages)" : "No pages available"
  }

  private var sliderBinding: Binding<Double> {
    Binding(
      get: { Double(pageValue) },
      set: { newValue in
        pageValue = Int(newValue.rounded())
      }
    )
  }

  init(
    bookId: String, totalPages: Int, currentPage: Int,
    readingDirection: ReadingDirection = .ltr,
    onJump: @escaping (Int) -> Void
  ) {
    self.bookId = bookId
    self.totalPages = totalPages
    self.currentPage = currentPage
    self.readingDirection = readingDirection
    self.onJump = onJump

    let safeInitialPage = max(1, min(currentPage, max(totalPages, 1)))
    _pageValue = State(initialValue: safeInitialPage)
  }

  // Get preview pages range (current page ± offset)
  private var previewPages: [Int] {
    let offset = 2  // Show 2 pages before and after
    let startPage = max(1, pageValue - offset)
    let endPage = min(maxPage, pageValue + offset)
    return Array(startPage...endPage)
  }

  private func getPreviewImageURL(page: Int) -> URL? {
    BookService.shared.getBookPageThumbnailURL(bookId: bookId, page: page)
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

  private func jumpToPage() {
    guard canJump else { return }
    let clampedValue = min(max(pageValue, 1), totalPages)
    onJump(clampedValue)
    dismiss()
  }

  private func adjustPage(step: Int) {
    guard canJump else { return }
    let newValue = min(max(pageValue + step, 1), maxPage)
    pageValue = newValue
  }

  var body: some View {
    SheetView(title: "Go to Page", size: .large) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(spacing: 24) {
          VStack(spacing: 8) {
            Text(rangeDescription)
              .font(.headline)
              .foregroundStyle(.secondary)
            if canJump {
              Text("Current page: \(currentPage)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }

          if canJump {
            VStack(spacing: 16) {
              VStack(spacing: 0) {
                // Preview view above slider - scrolling fan effect
                GeometryReader { geometry in
                  let sliderWidth = geometry.size.width

                  ZStack {
                    ForEach(previewPages, id: \.self) { page in
                      PagePreviewItem(
                        page: page,
                        pageValue: pageValue,
                        imageURL: getPreviewImageURL(page: page),
                        availableHeight: geometry.size.height,
                        sliderWidth: sliderWidth,
                        maxPage: maxPage,
                        readingDirection: readingDirection
                      )
                    }
                  }
                }
                .frame(minHeight: 200, maxHeight: 360)

                #if os(tvOS)
                  HStack(spacing: 16) {
                    let leftStep = readingDirection == .rtl ? 1 : -1
                    let rightStep = readingDirection == .rtl ? -1 : 1
                    let leftIcon =
                      readingDirection == .rtl ? "plus.circle.fill" : "minus.circle.fill"
                    let rightIcon =
                      readingDirection == .rtl ? "minus.circle.fill" : "plus.circle.fill"

                    Button {
                      adjustPage(step: leftStep)
                    } label: {
                      Image(systemName: leftIcon)
                    }
                    .adaptiveButtonStyle(.plain)

                    Text("Page \(pageValue)")
                      .font(.body)

                    Button {
                      adjustPage(step: rightStep)
                    } label: {
                      Image(systemName: rightIcon)
                    }
                    .adaptiveButtonStyle(.plain)
                  }
                  .focusSection()
                #else
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
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                #endif
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          Spacer()
        }
      }
      .padding(.top, 8)
    }
    .presentationDragIndicator(.visible)
  }
}
