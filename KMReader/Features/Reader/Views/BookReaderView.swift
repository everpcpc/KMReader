//
//  BookReaderView.swift
//  KMReader
//
//

import SwiftUI

struct BookReaderView: View {
  let book: Book
  let incognito: Bool
  let readList: ReadList?
  let onClose: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("useNativePdfReader") private var useNativePdfReader: Bool = true

  private var mediaProfile: MediaProfile {
    book.media.mediaProfile ?? .unknown
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
            switch mediaProfile {
            case .divina, .unknown:
              DivinaReaderView(
                book: book,
                incognito: incognito,
                readList: readList,
                onClose: closeReader
              )
            case .epub:
              if book.media.epubDivinaCompatible ?? false {
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
            case .pdf:
              if useNativePdfReader {
                #if os(iOS) || os(macOS)
                  PdfReaderView(
                    book: book,
                    incognito: incognito,
                    onClose: closeReader
                  )
                #else
                  ReaderUnavailableView(
                    icon: "doc.richtext",
                    title: "PDF Reader Not Available",
                    message: String(
                      localized:
                        "PDF reading is only supported on iOS and macOS."
                    ),
                    onClose: closeReader
                  )
                #endif
              } else {
                DivinaReaderView(
                  book: book,
                  incognito: incognito,
                  readList: readList,
                  onClose: closeReader
                )
              }
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
