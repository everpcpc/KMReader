//
//  BookActionsSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookActionsSection: View {
  let book: Book
  var onRead: (Bool) -> Void

  var body: some View {
    HStack {
      Button {
        onRead(false)
      } label: {
        Label("Read", systemImage: "book.pages")
      }
      .adaptiveButtonStyle(.borderedProminent)

      Button {
        onRead(true)
      } label: {
        Label("Read Incognito", systemImage: "eye.slash")
      }
      .adaptiveButtonStyle(.bordered)

      Spacer()

      NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
        Label("View Series", systemImage: "book.fill")
      }
      .adaptiveButtonStyle(.bordered)
    }.font(.caption)
  }
}
