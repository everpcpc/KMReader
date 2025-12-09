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
          VStack(spacing: 24) {
            Image(systemName: "trash.circle")
              .font(.system(size: 60))
              .foregroundColor(.secondary)

            VStack(spacing: 8) {
              Text("Book has been deleted")
                .font(.headline)
            }

            Button {
              closeReader()
            } label: {
              Label("Close", systemImage: "xmark.circle.fill")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .adaptiveButtonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
        } else {
          switch book.media.status {
          case .ready:
            if shouldUseDivinaReader {
              DivinaReaderView(
                bookId: book.id,
                incognito: incognito,
                readList: readList,
                onClose: closeReader
              )
            } else {
              #if os(iOS)
                EpubReaderView(
                  bookId: book.id,
                  incognito: incognito,
                  readList: readList,
                  onClose: closeReader
                )
              #else
                VStack(spacing: 24) {
                  Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                  VStack(spacing: 8) {
                    Text("EPUB Reader Not Available")
                      .font(.headline)
                    Text(
                      "EPUB reading is only supported on iOS. Please use Divina reader for this book."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                  }

                  Button {
                    closeReader()
                  } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                      .font(.headline)
                      .padding(.horizontal, 16)
                      .padding(.vertical, 8)
                  }
                  .adaptiveButtonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
              #endif
            }
          default:
            VStack(spacing: 24) {
              Image(systemName: book.media.status.icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

              VStack(spacing: 8) {
                Text(book.media.status.message)
                  .font(.headline)
                if let comment = book.media.comment, !comment.isEmpty {
                  Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
              }

              Button {
                closeReader()
              } label: {
                Label("Close", systemImage: "xmark.circle.fill")
                  .font(.headline)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
              }
              .adaptiveButtonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
          }
        }
      }
    }
    .readerIgnoresSafeArea()
  }
}
