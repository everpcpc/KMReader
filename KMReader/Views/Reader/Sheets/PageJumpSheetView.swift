//
//  PageJumpSheetView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImage
import SDWebImageSwiftUI
import SwiftUI

struct PageJumpSheetView: View {
  let bookId: String
  let totalPages: Int
  let currentPage: Int
  let readingDirection: ReadingDirection
  let onJump: (Int) -> Void

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

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

  private func adjustedProgress(for progress: Double) -> Double {
    readingDirection == .rtl ? 1.0 - progress : progress
  }

  private var xOffsetMultiplier: CGFloat {
    readingDirection == .rtl ? -1 : 1
  }

  private var rotationMultiplier: Double {
    readingDirection == .rtl ? -1 : 1
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

  var body: some View {
    NavigationStack {
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
          VStack(spacing: 8) {
            VStack(spacing: 0) {
              // Preview view above slider - scrolling fan effect
              GeometryReader { geometry in
                let sliderWidth = geometry.size.width
                let previewHeight: CGFloat = 360
                let imageWidth: CGFloat = 180
                let imageHeight: CGFloat = 250
                let centerY = previewHeight / 2

                ZStack {
                  ForEach(Array(previewPages.enumerated()), id: \.element) { index, page in
                    let isCenter = page == pageValue
                    let offset = page - pageValue
                    let progress = (Double(pageValue) - 1) / Double(maxPage - 1)
                    let adjustedProgress = adjustedProgress(for: progress)
                    let baseX = adjustedProgress * sliderWidth

                    // Calculate position with fan effect
                    let spacing: CGFloat = 150
                    let xOffset = CGFloat(offset) * spacing * xOffsetMultiplier
                    let x = baseX + xOffset
                    let rotation = Double(offset) * 8.0 * rotationMultiplier  // Rotation angle in degrees
                    let scale = isCenter ? 1.0 : 0.75
                    let opacity = isCenter ? 1.0 : 0.6
                    let zIndex = isCenter ? 10 : abs(offset)

                    if let imageURL = getPreviewImageURL(page: page) {
                      VStack(spacing: 4) {
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
                        .frame(width: imageWidth, height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(
                          color: Color.black.opacity(isCenter ? 0.4 : 0.2),
                          radius: isCenter ? 8 : 4, x: 0, y: 2)

                        if isCenter {
                          Text("\(page)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background {
                              RoundedRectangle(cornerRadius: 4)
                                .fill(themeColor.color)
                            }
                        }
                      }
                      .scaleEffect(scale)
                      .opacity(opacity)
                      .rotationEffect(.degrees(rotation))
                      .position(
                        x: max(imageWidth / 2, min(x, sliderWidth - imageWidth / 2)),
                        y: centerY
                      )
                      .zIndex(Double(zIndex))
                      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pageValue)
                    }
                  }
                }
              }
              .frame(height: 360)

              Slider(
                value: sliderBinding,
                in: 1...Double(maxPage),
                step: 1
              )
              .tint(themeColor.color)
              .scaleEffect(x: sliderScaleX, y: 1)

              HStack {
                Text(pageLabels.left)
                Spacer()
                Text(pageLabels.right)
              }
              .font(.footnote)
              .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Go to Page")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            dismiss()
          } label: {
            Label("Close", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            jumpToPage()
          } label: {
            Label("Jump", systemImage: "arrow.right.to.line")
          }
          .disabled(!canJump || pageValue == currentPage)
        }
      }
    }
  }

  private func jumpToPage() {
    guard canJump else { return }
    let clampedValue = min(max(pageValue, 1), totalPages)
    onJump(clampedValue)
    dismiss()
  }
}
