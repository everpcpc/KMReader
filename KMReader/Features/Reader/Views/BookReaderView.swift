//
//  BookReaderView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookReaderView: View {
  let book: Book
  let incognito: Bool
  let readList: ReadList?
  let onClose: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  private var shouldUseDivinaReader: Bool {
    guard let profile = book.media.mediaProfile else { return true }
    switch profile {
    case .epub:
      return book.media.epubDivinaCompatible ?? false
    case .divina, .pdf, .unknown:
      return true
    }
  }

  private var closeReader: () -> Void {
    onClose ?? { dismiss() }
  }

  var body: some View {
    ZStack {
      readerBackground.color.readerIgnoresSafeArea()

      Group {
        if book.deleted {
          ReaderUnavailableView(
            icon: "trash.circle",
            title: "Book has been deleted",
            onClose: closeReader
          )
        } else {
          switch book.media.status {
          case .ready:
            if shouldUseDivinaReader {
              DivinaReaderView(
                book: book,
                incognito: incognito,
                readList: readList,
                onClose: closeReader
              )
            } else {
              #if os(iOS)
                EpubReaderView(
                  book: book,
                  incognito: incognito,
                  readList: readList,
                  onClose: closeReader
                )
              #else
                ReaderUnavailableView(
                  icon: "exclamationmark.triangle",
                  title: "EPUB Reader Not Available",
                  message: String(
                    localized:
                      "EPUB reading is only supported on iOS."
                  ),
                  onClose: closeReader
                )
              #endif
            }
          default:
            ReaderUnavailableView(
              icon: book.media.status.icon,
              title: LocalizedStringKey(book.media.status.message),
              message: book.media.comment,
              onClose: closeReader
            )
          }
        }
      }
    }
  }
}
