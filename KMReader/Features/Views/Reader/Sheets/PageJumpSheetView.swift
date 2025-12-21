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

// Page transform properties for cover flow effect
private struct PageTransform {
  let x: CGFloat
  let yRotation: Double
  let scale: CGFloat
  let opacity: Double
  let zIndex: Int

  // Calculate constrained x position within slider bounds
  func constrainedX(
    _ imageWidth: CGFloat,
    containerWidth: CGFloat,
    centerX: CGFloat
  ) -> CGFloat {
    let halfContainer = containerWidth / 2
    let minX = centerX - halfContainer + imageWidth / 2
    let maxX = centerX + halfContainer - imageWidth / 2
    return max(minX, min(x, maxX))
  }
}

// Single page preview item view
private struct PagePreviewItem: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  let bookId: String
  let page: Int
  let pageValue: Int
  let availableHeight: CGFloat
  let containerWidth: CGFloat
  let containerCenterX: CGFloat
  let maxPage: Int
  let readingDirection: ReadingDirection

  @State private var localURL: URL?

  // Calculate preview dimensions based on available height
  private var dimensions: PreviewDimensions {
    // Base values for standard height (360)
    let baseHeight: CGFloat = 360
    let baseImageWidth: CGFloat = 180
    let baseImageHeight: CGFloat = 250
    let baseSpacing: CGFloat = 200

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
    let clampedOffset = max(-2, min(2, offset))
    let baseX = containerCenterX

    // Cover flow style transform
    let spacing = dimensions.spacing
    let xOffset = CGFloat(offset) * spacing * xOffsetMultiplier
    let x = baseX + xOffset
    let yRotation = Double(clampedOffset) * 20.0 * rotationMultiplier
    let centerScale = 1.1
    let scaleDrop = 0.12 * Double(abs(clampedOffset))
    let scale = isCenter ? centerScale : max(0.7, centerScale - scaleDrop)
    let opacity = isCenter ? 1.0 : max(0.45, 0.75 - 0.1 * Double(abs(clampedOffset)))
    let zIndex = isCenter ? 20 : 20 - abs(offset)

    return PageTransform(
      x: x,
      yRotation: yRotation,
      scale: scale,
      opacity: opacity,
      zIndex: zIndex
    )
  }

  var body: some View {
    let isCenter = page == pageValue

    VStack {
      if let localURL = localURL {
        WebImage(
          url: localURL,
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
        .overlay(alignment: .bottom) {
          if isCenter {
            Text("\(page)")
              .foregroundColor(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .background {
                RoundedRectangle(cornerRadius: 4)
                  .fill(themeColor.color)
              }
              .offset(y: 30)
          }
        }
      } else {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(contentMode: .fit)
          .frame(width: dimensions.imageWidth, height: dimensions.imageHeight)
          .overlay {
            ProgressView()
          }
      }
    }
    .shadow(
      color: Color.black.opacity(isCenter ? 0.4 : 0.2),
      radius: isCenter ? 8 : 4, x: 0, y: 2
    )
    .scaleEffect(transform.scale)
    .opacity(transform.opacity)
    .rotation3DEffect(
      .degrees(transform.yRotation),
      axis: (x: 0, y: 1, z: 0),
      perspective: 0.6
    )
    .position(
      x: transform.constrainedX(
        dimensions.imageWidth,
        containerWidth: containerWidth,
        centerX: containerCenterX
      ),
      y: dimensions.centerY
    )
    .zIndex(Double(transform.zIndex))
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pageValue)
    .task(id: page) {
      localURL = try? await ThumbnailCache.shared.ensureThumbnail(
        id: bookId, type: .page, page: page)
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
  @State private var dragStartPage: Int?

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
    SheetView(title: String(localized: "Go to Page"), size: .medium) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(spacing: 24) {
          VStack(spacing: 8) {
            if canJump {
              Text("Current page: \(currentPage)")
                .foregroundStyle(.secondary)
            }
          }

          if canJump {
            VStack(spacing: 16) {
              // Preview view above slider - scrolling fan effect
              GeometryReader { geometry in
                let fullWidth = geometry.size.width
                let centerX = fullWidth / 2

                ZStack {
                  ForEach(previewPages, id: \.self) { page in
                    PagePreviewItem(
                      bookId: bookId,
                      page: page,
                      pageValue: pageValue,
                      availableHeight: geometry.size.height,
                      containerWidth: fullWidth,
                      containerCenterX: centerX,
                      maxPage: maxPage,
                      readingDirection: readingDirection
                    )
                  }
                }
                #if os(iOS)
                  .contentShape(Rectangle())
                  .gesture(
                    DragGesture(minimumDistance: 5)
                      .onChanged { value in
                        if dragStartPage == nil {
                          dragStartPage = pageValue
                        }
                        let base = Double(dragStartPage ?? pageValue)
                        let projected =
                          value.translation.width
                          + (value.predictedEndTranslation.width - value.translation.width) * 0.2
                        let normalized = Double(projected / (fullWidth * 8.0))
                        let directionMultiplier = readingDirection == .rtl ? -1.0 : 1.0
                        let deltaPages = normalized * directionMultiplier * Double(maxPage - 1)
                        let target = base - deltaPages
                        let clamped = Int(target.rounded())
                        pageValue = min(max(clamped, 1), maxPage)
                      }
                      .onEnded { _ in
                        dragStartPage = nil
                      }
                  )
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                #endif
              }
              .frame(minHeight: 200, maxHeight: 360)

              #if os(tvOS)
                VStack(spacing: 40) {
                  HStack(spacing: 32) {
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
                    // must be a full width button, otherwise it will not be focused
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
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          Spacer()
        }
      }
      .padding()
    }
    .presentationDragIndicator(.visible)
  }
}
