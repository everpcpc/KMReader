//
// BookActionsSection.swift
//
//

import SwiftUI

/// The book detail page's single action row: Read, Peek, and the download
/// toggle when the book has a download state. Series navigation lives on the
/// hero's series title instead of a button here.
struct BookActionsSection: View {
  let book: Book
  let downloadStatus: DownloadStatus?

  @Environment(\.readerActions) private var readerActions
  @AppStorage("currentAccount") private var current: Current = .init()

  var body: some View {
    HStack {
      Button {
        readerActions.open(book: book, incognito: false)
      } label: {
        Label("Read", systemImage: "book")
      }
      .adaptiveButtonStyle(.borderedProminent)

      Button {
        readerActions.open(book: book, incognito: true)
      } label: {
        Label("Peek", systemImage: "eye.slash")
      }
      .adaptiveButtonStyle(.bordered)

      if let downloadStatus {
        Button {
          Task {
            await OfflineManager.shared.toggleDownload(
              instanceId: current.instanceId, info: book.downloadInfo)
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: downloadStatus.menuIcon)
              .font(.caption2)
            Text(downloadStatus.menuLabel)
              .font(.caption)
              .fontWeight(.medium)
              .lineLimit(1)
          }
        }
        .adaptiveButtonStyle(.bordered)
        .optimizedControlSize()
        .tint(downloadStatus.menuColor)
      }
    }
    .font(.caption)
    .animation(.default, value: downloadStatus)
  }
}
