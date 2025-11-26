//
//  NextBookInfoView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct NextBookInfoView: View {
  let nextBook: Book?

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    if let nextBook = nextBook {
      VStack(spacing: 4) {
        Label("UP NEXT: #\(Int(nextBook.number))", systemImage: "arrow.right.circle")
        Text(nextBook.metadata.title)
        Text("\(nextBook.media.pagesCount) pages • \(nextBook.size)")
          .font(.footnote)
      }
      .foregroundColor(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(themeColor.color.opacity(0.6))
      )
    } else {
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle")
        Text("You're all caught up!")
      }
      .foregroundColor(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(themeColor.color.opacity(0.6))
      )
    }
  }
}
