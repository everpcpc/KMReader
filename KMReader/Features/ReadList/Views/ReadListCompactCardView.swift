//
//  ReadListCompactCardView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadListCompactCardView: View {
  @Bindable var komgaReadList: KomgaReadList

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: komgaReadList.readListId)) {
      HStack {
        ThumbnailImage(id: komgaReadList.readListId, type: .readlist, width: 60)

        VStack(alignment: .leading, spacing: 4) {
          Text(komgaReadList.name)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(komgaReadList.bookIds.count) books")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(komgaReadList.lastModifiedDate.formattedMediumDate)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: 320, alignment: .leading)
      }
      .padding(6)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      }
    }
    .adaptiveButtonStyle(.plain)
  }
}
