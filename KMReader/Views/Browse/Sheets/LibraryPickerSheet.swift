//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryPickerSheet: View {
  var body: some View {
    SheetView(title: "Select Library", size: .large) {
      LibraryListContent(
        showMetrics: true,
        showDeleteAction: false,
        loadMetrics: false
      )
    } controls: {
      HStack(spacing: 12) {
        Button {
          Task {
            await LibraryManager.shared.refreshLibraries()
          }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
      }
    }
  }
}
