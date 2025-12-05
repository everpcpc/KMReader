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

  private var displayNumber: Int {
    guard let readList = readList, let nextBook = nextBook else {
      return Int(nextBook?.number ?? 0)
    }

    guard let index = readList.bookIds.firstIndex(of: nextBook.id) else {
      return Int(nextBook.number)
    }

    // Index is 0-based, so add 1 for display (1-based)
    return index + 1
  }

  private var upNextLabel: String {
    if readList != nil {
      return "UP NEXT IN READ LIST: #\(displayNumber)"
    } else {
      return "UP NEXT IN SERIES: #\(displayNumber)"
    }
  }

  var body: some View {
    if let nextBook = nextBook {
      VStack(spacing: 4) {
        HStack(spacing: 6) {
          Label(upNextLabel, systemImage: "arrow.right.circle")
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
