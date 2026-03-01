//
// WebtoonHelpers.swift
//
//

import CoreGraphics
import Foundation

@MainActor
func scheduleOnMain(after delay: TimeInterval, action: @escaping () -> Void) {
  Task { @MainActor in
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    action()
  }
}

struct InitialScrollRetrier {
  typealias DelayScheduler = @MainActor (TimeInterval, @escaping () -> Void) -> Void

  private(set) var attempts: Int = 0
  let maxRetries: Int

  mutating func reset() {
    attempts = 0
  }

  @MainActor
  mutating func schedule(
    after delay: TimeInterval,
    using scheduler: DelayScheduler,
    action: @escaping () -> Void
  ) {
    guard attempts < maxRetries else { return }
    attempts += 1
    scheduler(delay, action)
  }
}

struct WebtoonPageHeightCache {
  var heights: [ReaderPageID: CGFloat] = [:]
  var lastPageWidth: CGFloat = 0

  mutating func reset() {
    heights.removeAll()
  }

  mutating func rescaleIfNeeded(newWidth: CGFloat) {
    if lastPageWidth > 0, abs(lastPageWidth - newWidth) > 0.1 {
      let scaleFactor = newWidth / lastPageWidth
      if scaleFactor.isFinite && scaleFactor > 0 {
        for (index, height) in heights {
          heights[index] = height * scaleFactor
        }
      }
    }
    lastPageWidth = newWidth
  }

  mutating func height(
    for pageID: ReaderPageID,
    page: BookPage,
    pageWidth: CGFloat
  ) -> CGFloat {
    guard pageWidth > 0 else { return 0 }
    if let cached = heights[pageID] {
      return cached
    }
    if let width = page.width, let height = page.height, width > 0 {
      let ratio = CGFloat(height) / CGFloat(width)
      if ratio.isFinite && ratio > 0 {
        let targetHeight = pageWidth * ratio
        heights[pageID] = targetHeight
        return targetHeight
      }
    }
    return pageWidth * 3
  }
}
