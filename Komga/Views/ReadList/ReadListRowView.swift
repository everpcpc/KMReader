//
//  ReadListRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListRowView: View {
  let readList: ReadList

  private var thumbnailURL: URL? {
    ReadListService.shared.getReadListThumbnailURL(id: readList.id)
  }

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      HStack(spacing: 12) {
        ThumbnailImage(url: thumbnailURL, width: 70, cornerRadius: 10)

        VStack(alignment: .leading, spacing: 6) {
          Text(readList.name)
            .font(.callout)

          Label {
            Text("\(readList.bookIds.count) book")
          } icon: {
            Image(systemName: "book")
          }
          .font(.footnote)
          .foregroundColor(.secondary)

          Label {
            Text(readList.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
          } icon: {
            Image(systemName: "clock")
          }
          .font(.caption)
          .foregroundColor(.secondary)

          if !readList.summary.isEmpty {
            Text(readList.summary)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }

        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}
