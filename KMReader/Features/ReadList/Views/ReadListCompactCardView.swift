//
// ReadListCompactCardView.swift
//
//

import SwiftUI

struct ReadListCompactCardView: View {
  let readList: ReadList

  var body: some View {
    NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
      HStack {
        ThumbnailImage(id: readList.id, type: .readlist, width: 60)

        VStack(alignment: .leading, spacing: 4) {
          Text(readList.name)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("\(readList.bookIds.count) books")
            .font(.footnote)
            .foregroundColor(.secondary)

          Text(readList.lastModifiedDate.formattedMediumDate)
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
