//
// ReadListContinuationHintView.swift
//
//

import SwiftUI

/// Quiet pointer on an ordered read list's page to the opt-in setting that
/// lets the list continue across series.
struct ReadListContinuationHintView: View {
  var body: some View {
    NavigationLink(value: NavDestination.settingsReading) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "list.number")
        Text(String(localized: "readList.continuation.hint"))
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
