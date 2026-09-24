//
// DetailMetadataRow.swift
//
//

import SwiftUI

/// Icon + caption metadata row for detail pages, in the same visual
/// language as the Media Information section. `color` is for state
/// semantics only; plain metadata stays secondary.
struct DetailMetadataRow: View {
  let systemImage: String
  let text: Text
  var color: Color = .secondary

  var body: some View {
    HStack {
      Image(systemName: systemImage)
        .font(.caption)
        .frame(minWidth: 16)
      text
        .font(.caption)
        .textSelectionIfAvailable()
      Spacer()
    }
    .foregroundStyle(color)
  }
}
