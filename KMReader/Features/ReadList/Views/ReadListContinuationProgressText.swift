//
// ReadListContinuationProgressText.swift
//
//

import SwiftUI

/// A continuation card's progress line: the book's progress while it is in
/// progress, then how much of the list is read ("38% • 2 of 3 read"). Font and
/// color come from the card.
struct ReadListContinuationProgressText: View {
  let continuation: ReadListContinuation

  private var listProgressText: String {
    String(
      format: String(localized: "readList.continuation.progress"),
      Int64(continuation.booksRead),
      Int64(continuation.bookCount)
    )
  }

  var body: some View {
    HStack(spacing: 4) {
      if let bookProgress = continuation.bookProgress {
        Text(bookProgress, format: .percent.precision(.fractionLength(0)))
        Text("•")
      }
      Text(listProgressText)
    }
  }
}
