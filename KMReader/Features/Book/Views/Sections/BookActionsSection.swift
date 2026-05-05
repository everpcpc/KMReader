//
// BookActionsSection.swift
//
//

import SwiftUI

struct BookActionsSection: View {
  let book: Book
  var seriesLink: Bool

  @Environment(\.readerActions) private var readerActions

  var body: some View {
    HStack {
      Button {
        readerActions.open(book: book, incognito: false)
      } label: {
        Label("Read", systemImage: "play")
      }
      .adaptiveButtonStyle(.borderedProminent)

      Button {
        readerActions.open(book: book, incognito: true)
      } label: {
        Label("Read Incognito", systemImage: "eye.slash")
      }
      .adaptiveButtonStyle(.bordered)

      Spacer()

      if seriesLink {
        NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
          Label("View Series", systemImage: "book.fill")
        }
        .adaptiveButtonStyle(.bordered)
      }
    }.font(.caption)
  }
}
