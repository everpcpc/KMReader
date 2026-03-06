//
// ReaderActions.swift
//
//

import SwiftUI

struct ReaderActions {
  let openBook: @MainActor (Book, Bool, ReaderReadListContext?) -> Void

  func open(
    book: Book,
    incognito: Bool,
    readListContext: ReaderReadListContext? = nil
  ) {
    openBook(book, incognito, readListContext)
  }

  static func live(readerPresentation: ReaderPresentationManager) -> Self {
    Self { book, incognito, readListContext in
      readerPresentation.present(
        book: book,
        incognito: incognito,
        readListContext: readListContext
      )
    }
  }

  static let unavailable = Self { _, _, _ in
    AppLogger(.reader).error("Reader action invoked without configured reader presentation")
  }
}

private struct ReaderActionsKey: EnvironmentKey {
  static let defaultValue = ReaderActions.unavailable
}

extension EnvironmentValues {
  var readerActions: ReaderActions {
    get { self[ReaderActionsKey.self] }
    set { self[ReaderActionsKey.self] = newValue }
  }
}
