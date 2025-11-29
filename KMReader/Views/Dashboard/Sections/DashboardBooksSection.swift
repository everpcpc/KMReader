//
//  DashboardBooksSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DashboardBooksSection: View {
  let title: String
  let books: [Book]
  var bookViewModel: BookViewModel
  var onBookUpdated: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(books) { book in
            BookCardView(
              book: book,
              viewModel: bookViewModel,
              cardWidth: PlatformHelper.dashboardCardWidth,
              onBookUpdated: onBookUpdated,
              showSeriesTitle: true,
            )
          }
        }.padding()
      }
    }
  }
}
