import Foundation

enum ReaderPagePresentationInvalidation: Equatable {
  case all
  case pages(Set<ReaderPageID>)

  func merged(with other: ReaderPagePresentationInvalidation) -> ReaderPagePresentationInvalidation {
    switch (self, other) {
    case (.all, _), (_, .all):
      return .all
    case (.pages(let lhs), .pages(let rhs)):
      return .pages(lhs.union(rhs))
    }
  }
}
