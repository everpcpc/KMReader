//
//  ReaderTOCSheetView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReaderTOCSheetView: View {
  let entries: [ReaderTOCEntry]
  let currentPageIndex: Int
  let onSelect: (ReaderTOCEntry) -> Void

  var body: some View {
    SheetView(title: "Table of Contents", size: .large) {
      List {
        ForEach(entries) { entry in
          Button {
            onSelect(entry)
          } label: {
            HStack(alignment: .center, spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                  .font(.body)
                Text(
                  String(
                    format: NSLocalizedString("Page %d", comment: "TOC page label"),
                    entry.pageNumber)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              Spacer()
              if entry.pageIndex == currentPageIndex {
                Image(systemName: "bookmark.fill")
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .adaptiveButtonStyle(.plain)
          #if os(tvOS)
            .listRowInsets(EdgeInsets(top: 24, leading: 48, bottom: 24, trailing: 48))
          #endif
        }
      }
      .optimizedListStyle()
    }
    .presentationDragIndicator(.visible)
  }
}
