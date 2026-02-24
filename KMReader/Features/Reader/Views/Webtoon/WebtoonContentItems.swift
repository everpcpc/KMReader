//
// WebtoonContentItems.swift
//

import CoreGraphics
import Foundation

struct WebtoonContentItems {
  enum Item: Equatable {
    case page(Int)
    case end(String)
  }

  let items: [Item]
  let itemIndexByPageIndex: [Int: Int]

  static var empty: WebtoonContentItems {
    WebtoonContentItems(items: [], itemIndexByPageIndex: [:])
  }

  static func build(from viewModel: ReaderViewModel?) -> WebtoonContentItems {
    guard let viewModel else {
      return .empty
    }

    var items: [Item] = []
    var itemIndexByPageIndex: [Int: Int] = [:]
    var globalPageIndex = 0

    for segment in viewModel.segments {
      if !segment.pages.isEmpty {
        for _ in segment.pages {
          itemIndexByPageIndex[globalPageIndex] = items.count
          items.append(.page(globalPageIndex))
          globalPageIndex += 1
        }
      }
      items.append(.end(segment.currentBook.id))
    }

    return WebtoonContentItems(items: items, itemIndexByPageIndex: itemIndexByPageIndex)
  }

  static func resolvedPageIndex(
    for itemIndex: Int,
    in items: [Item],
    viewModel: ReaderViewModel?
  ) -> Int? {
    guard itemIndex >= 0, itemIndex < items.count else { return nil }
    switch items[itemIndex] {
    case .page(let pageIndex):
      return pageIndex
    case .end(let segmentBookId):
      guard let range = viewModel?.pageRange(forSegmentBookId: segmentBookId), !range.isEmpty else {
        return nil
      }
      return range.upperBound - 1
    }
  }

  static func lastVisibleItemIndex(
    itemCount: Int,
    viewportBottom: CGFloat,
    threshold: CGFloat,
    visibleItemIndices: [Int],
    frameForItemAtIndex: (Int) -> CGRect?
  ) -> Int {
    let sortedVisibleIndices =
      visibleItemIndices
      .filter { $0 >= 0 && $0 < itemCount }
      .sorted()

    guard let firstVisibleIndex = sortedVisibleIndices.first else {
      return lastVisibleItemIndex(
        itemCount: itemCount,
        viewportBottom: viewportBottom,
        threshold: threshold,
        frameForItemAtIndex: frameForItemAtIndex
      )
    }

    var candidateIndex = firstVisibleIndex
    for itemIndex in sortedVisibleIndices {
      guard let frame = frameForItemAtIndex(itemIndex) else {
        continue
      }
      if frame.maxY <= viewportBottom + threshold {
        candidateIndex = itemIndex
      } else {
        break
      }
    }

    return candidateIndex
  }

  static func lastVisibleItemIndex(
    itemCount: Int,
    viewportBottom: CGFloat,
    threshold: CGFloat,
    frameForItemAtIndex: (Int) -> CGRect?
  ) -> Int {
    var visibleIndex = 0
    for itemIndex in 0..<itemCount {
      guard let frame = frameForItemAtIndex(itemIndex) else {
        continue
      }
      if frame.maxY <= viewportBottom + threshold {
        visibleIndex = itemIndex
      } else {
        break
      }
    }
    return visibleIndex
  }

  static func preheatPageIndices(around pageIndex: Int, radius: Int = WebtoonConstants.preheatRadius)
    -> [Int]
  {
    let safeRadius = max(radius, 0)
    return Array((pageIndex - safeRadius)...(pageIndex + safeRadius))
  }
}
