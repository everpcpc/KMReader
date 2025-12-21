//
//  NextBookInfoView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct NextBookInfoView: View {
  let nextBook: Book?
  let readList: ReadList?

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  private var bookNumber: String {
    guard let book = nextBook else { return "" }
    return "#\(book.metadata.number)"
  }

  private var upNextLabel: String {
    if readList != nil {
      return String.localizedStringWithFormat(
        String(localized: "UP NEXT IN READ LIST: %@"),
        bookNumber
      )
    } else {
      return String.localizedStringWithFormat(
        String(localized: "UP NEXT IN SERIES: %@"),
        bookNumber
      )
    }
  }

  var body: some View {
    if let nextBook = nextBook {
      VStack(spacing: 4) {
        HStack(spacing: 6) {
          Image(systemName: "arrow.right.circle")
          Text(upNextLabel)
        }
        if let readList = readList {
          HStack(spacing: 4) {
            Image(systemName: "list.bullet.rectangle")
              .font(.caption2)
            Text("From: \(readList.name)")
              .font(.caption)
          }
          .foregroundColor(.white.opacity(0.8))
        }
        Text(nextBook.metadata.title)
        HStack(spacing: 4) {
          Text("\(nextBook.media.pagesCount) pages")
          Text("•")
          Text(nextBook.size)
        }
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
        Text(String(localized: "You're all caught up!"))
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
