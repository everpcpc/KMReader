import Foundation

struct ReaderTOCSelection: Equatable {
  let entryIDs: Set<UUID>
  let scrollTargetID: UUID?

  static let empty = ReaderTOCSelection(entryIDs: [], scrollTargetID: nil)

  static func resolve(in entries: [ReaderTOCEntry], currentPageIndex: Int) -> ReaderTOCSelection {
    var selectedEntryIDs: Set<UUID> = []
    var currentEntries = entries
    var scrollTargetID: UUID?

    while true {
      var found = false
      for (index, entry) in currentEntries.enumerated() {
        let nextPageIndex = index + 1 < currentEntries.count ? currentEntries[index + 1].pageIndex : Int.max
        if currentPageIndex >= entry.pageIndex && currentPageIndex < nextPageIndex {
          selectedEntryIDs.insert(entry.id)
          scrollTargetID = scrollTargetID ?? entry.id
          if let children = entry.children, !children.isEmpty {
            currentEntries = children
            found = true
            break
          }
          return ReaderTOCSelection(entryIDs: selectedEntryIDs, scrollTargetID: scrollTargetID)
        }
      }
      if !found {
        break
      }
    }

    return ReaderTOCSelection(entryIDs: selectedEntryIDs, scrollTargetID: scrollTargetID)
  }
}
