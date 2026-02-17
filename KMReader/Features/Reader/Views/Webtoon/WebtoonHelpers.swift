//
//  WebtoonHelpers.swift
//  Komga
//
//  Created by Komga iOS Client
//

import CoreGraphics
import Foundation

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
  var heights: [Int: CGFloat] = [:]
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
    for index: Int,
    page: BookPage,
    pageWidth: CGFloat
  ) -> CGFloat {
    guard pageWidth > 0 else { return 0 }
    if let cached = heights[index] {
      return cached
    }
    if let width = page.width, let height = page.height, width > 0 {
      let ratio = CGFloat(height) / CGFloat(width)
      if ratio.isFinite && ratio > 0 {
        let targetHeight = pageWidth * ratio
        heights[index] = targetHeight
        return targetHeight
      }
    }
    return pageWidth * 3
  }
}
