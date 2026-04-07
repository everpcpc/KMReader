//
// ReaderPageIsolationActions.swift
//
//

import Foundation

enum ReaderPageIsolationActions {
  struct Action: Identifiable, Equatable {
    let id: String
    let pageID: ReaderPageID
    let title: String
    let systemImage: String
  }

  static func resolve(
    supportsDualPageOptions: Bool,
    dualPage: Bool,
    readingDirection: ReadingDirection,
    currentPageID: ReaderPageID?,
    currentPairIDs: (first: ReaderPageID, second: ReaderPageID?)?,
    isCurrentPageWide: Bool,
    isCurrentPageIsolated: Bool,
    displayPageNumber: (ReaderPageID) -> Int
  ) -> [Action] {
    guard supportsDualPageOptions else { return [] }
    guard let currentPageID else { return [] }
    guard !isCurrentPageWide else { return [] }

    if isCurrentPageIsolated {
      return [
        Action(
          id: "cancel-\(currentPageID.description)",
          pageID: currentPageID,
          title: String(localized: "Cancel Isolation"),
          systemImage: "rectangle.portrait.slash"
        )
      ]
    }

    guard dualPage, let currentPairIDs, let secondPageID = currentPairIDs.second else { return [] }

    let leftPageID = readingDirection == .rtl ? secondPageID : currentPairIDs.first
    let rightPageID = readingDirection == .rtl ? currentPairIDs.first : secondPageID

    return [
      Action(
        id: "isolate-\(leftPageID.description)",
        pageID: leftPageID,
        title: String.localizedStringWithFormat(
          String(localized: "Isolate Page %d"),
          displayPageNumber(leftPageID)
        ),
        systemImage: "rectangle.lefthalf.inset.filled"
      ),
      Action(
        id: "isolate-\(rightPageID.description)",
        pageID: rightPageID,
        title: String.localizedStringWithFormat(
          String(localized: "Isolate Page %d"),
          displayPageNumber(rightPageID)
        ),
        systemImage: "rectangle.righthalf.inset.filled"
      ),
    ]
  }
}
