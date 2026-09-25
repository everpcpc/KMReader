//
// ReadListStopReadingButton.swift
//
//

import SwiftUI

/// Stop Reading for a read list the user is reading through; hidden otherwise.
/// Stopping changes reading state, not the read list, so it needs no reload of
/// the page that shows it.
struct ReadListStopReadingButton: View {
  let readListId: String
  let instanceId: String

  var body: some View {
    if ReadListReadingService.shared.isReading(readListId: readListId) {
      Button {
        ReadListReadingService.shared.stopReading(readListId: readListId, instanceId: instanceId)
      } label: {
        Label(String(localized: "readList.stopReading"), systemImage: "stop.circle")
      }
    }
  }
}
