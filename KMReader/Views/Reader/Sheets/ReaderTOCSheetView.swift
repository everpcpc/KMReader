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
    NavigationStack {
      List(entries) { entry in
        Button {
          onSelect(entry)
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(entry.title)
                .font(.body)
              Text(
                String(
                  format: NSLocalizedString("Page %d", comment: "TOC page label"), entry.pageNumber)
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.pageIndex == currentPageIndex {
              Image(systemName: "bookmark.fill")
                .foregroundStyle(.tint)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .inlineNavigationBarTitle("Table of Contents")
      .padding(PlatformHelper.sheetPadding)
    }
    .presentationDragIndicator(.visible)
    #if canImport(UIKit)
      .presentationDetents([.medium, .large])
    #else
      .frame(minWidth: 400, minHeight: 500)
    #endif
  }
}
