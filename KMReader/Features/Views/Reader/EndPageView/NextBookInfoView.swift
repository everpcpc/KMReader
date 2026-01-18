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
  let showImage: Bool

  @Environment(\.readerBackgroundPreference) private var readerBackground

  private var bookNumber: String {
    guard let book = nextBook else { return "" }
    return "#\(book.metadata.number)"
  }

  private var upNextLabel: String {
    if readList != nil {
      return String.localizedStringWithFormat(
        String(localized: "UP NEXT IN READ LIST: %@"),
        bookNumber
      ).uppercased()
    } else {
      return String.localizedStringWithFormat(
        String(localized: "UP NEXT IN SERIES: %@"),
        bookNumber
      ).uppercased()
    }
  }

  private var textColor: Color {
    switch readerBackground {
    case .black:
      return .white
    case .white:
      return .black
    case .gray:
      return .white
    case .system:
      return .primary
    }
  }

  var body: some View {
    VStack(spacing: 24) {
      if let nextBook = nextBook {
        VStack(spacing: 16) {
          Text(upNextLabel)
            .font(.title3)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .foregroundColor(textColor.opacity(0.9))

          if showImage {
            ThumbnailImage(
              id: nextBook.id,
              type: .book,
              shadowStyle: .basic,
              width: 120,
              cornerRadius: 12
            )
            .frame(maxHeight: 160)
          }

          VStack(spacing: 4) {
            Text(nextBook.metadata.title)
              .font(.title3)
              .fontDesign(.serif)
              .fontWeight(.bold)
              .multilineTextAlignment(.center)
              .foregroundColor(textColor)

            if let readList = readList {
              HStack(spacing: 4) {
                Image(systemName: ContentIcon.readList)
                  .font(.caption)
                Text(readList.name)
              }
              .font(.subheadline)
              .fontDesign(.serif)
              .foregroundColor(textColor.opacity(0.7))
            } else {
              Text(nextBook.seriesTitle)
                .font(.subheadline)
                .fontDesign(.serif)
                .foregroundColor(textColor.opacity(0.7))
            }

            HStack(spacing: 4) {
              Text("\(nextBook.media.pagesCount) pages")
              Text("•")
              Text(nextBook.size)
            }
            .font(.caption)
            .foregroundColor(textColor.opacity(0.5))
          }
        }
      } else {
        VStack(spacing: 12) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.accentColor)
          Text(String(localized: "You're all caught up!"))
            .font(.headline)
            .foregroundColor(textColor)
        }
        .padding(.vertical, 40)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 32)
  }
}
