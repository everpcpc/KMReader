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

  @Environment(\.dismiss) private var dismiss

  private var shouldUseDivinaReader: Bool {
    guard let profile = book.media.mediaProfile else { return true }
    switch profile {
    case .epub:
      return book.media.epubDivinaCompatible ?? false
    case .divina, .pdf, .unknown:
      return true
    }
  }

  var body: some View {
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
            dismiss()
          } label: {
            Label("Close", systemImage: "xmark.circle.fill")
              .font(.headline)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else {
        switch book.media.status {
        case .ready:
          if shouldUseDivinaReader {
            DivinaReaderView(bookId: book.id, incognito: incognito)
          } else {
            EpubReaderView(bookId: book.id, incognito: incognito)
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
              dismiss()
            } label: {
              Label("Close", systemImage: "xmark.circle.fill")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
        }
      }
    }
  }
}
