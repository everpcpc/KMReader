import Foundation

struct ReaderPreloadWindow: Equatable, Sendable {
  let preloadBefore: Int
  let preloadAfter: Int
  let keepRangeBefore: Int
  let keepRangeAfter: Int

  static let lowMemory = ReaderPreloadWindow(
    preloadBefore: 1,
    preloadAfter: 2,
    keepRangeBefore: 1,
    keepRangeAfter: 2
  )

  static let balanced = ReaderPreloadWindow(
    preloadBefore: 2,
    preloadAfter: 4,
    keepRangeBefore: 3,
    keepRangeAfter: 6
  )

  static let fastPageTurns = ReaderPreloadWindow(
    preloadBefore: 3,
    preloadAfter: 6,
    keepRangeBefore: 4,
    keepRangeAfter: 8
  )
}
