//
//  BookActionsSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookActionsSection: View {
  let book: Book
  var seriesLink: Bool

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  var body: some View {
    HStack {
      Button {
        readerPresentation.present(book: book, incognito: false)
      } label: {
        Label("Read", systemImage: "book.pages")
      }
      .adaptiveButtonStyle(.borderedProminent)

      Button {
        readerPresentation.present(book: book, incognito: true)
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
