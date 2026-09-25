//
// ReadListBookCountView.swift
//
//

import SwiftUI

/// Book count and ordering line shown inside the read list detail action
/// card. Centered in centered layouts (via `detailHeroCentered`), leading
/// otherwise.
struct ReadListBookCountView: View {
  let readList: ReadList

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("\(readList.bookIds.count) books")
        .font(.subheadline.weight(.semibold))

      if readList.ordered {
        Label("Ordered", systemImage: "arrow.up.arrow.down")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: heroCentered ? .center : .leading)
  }
}
