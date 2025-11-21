//
//  ReadListCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListCardView: View {
  let readList: ReadList
  let width: CGFloat

  private var bookCountText: String {
    let count = readList.bookIds.count
    return count == 1 ? "1 book" : "\(count) books"
  }

  private var thumbnailURL: URL? {
    ReadListService.shared.getReadListThumbnailURL(id: readList.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      VStack(alignment: .leading, spacing: 8) {
        ThumbnailImage(url: thumbnailURL, width: width, cornerRadius: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(readList.name)
            .font(.headline)
            .lineLimit(1)

          Text(bookCountText)
            .font(.caption)
            .foregroundColor(.secondary)

          if !readList.summary.isEmpty {
            Text(readList.summary)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
        }
        .frame(width: width, alignment: .leading)
      }
    }
    .buttonStyle(.plain)
  }
}
