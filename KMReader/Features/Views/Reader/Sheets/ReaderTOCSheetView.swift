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
    SheetView(title: String(localized: "Table of Contents"), size: .large, applyFormStyle: true) {
      ScrollViewReader { proxy in
        List {
          ForEach(entries) { entry in
            TOCEntryRow(
              entry: entry,
              currentPageIndex: currentPageIndex,
              onSelect: onSelect
            )
          }
        }
        .optimizedListStyle()
        .onAppear {
          DispatchQueue.main.async {
            proxy.scrollTo(currentPageIndex, anchor: .center)
          }
        }
      }
    }
    .presentationDragIndicator(.visible)
  }
}

private struct TOCEntryRow: View {
  let entry: ReaderTOCEntry
  let currentPageIndex: Int
  let onSelect: (ReaderTOCEntry) -> Void
  let level: Int

  @State private var isExpanded: Bool = false

  init(entry: ReaderTOCEntry, currentPageIndex: Int, onSelect: @escaping (ReaderTOCEntry) -> Void, level: Int = 0) {
    self.entry = entry
    self.currentPageIndex = currentPageIndex
    self.onSelect = onSelect
    self.level = level
  }

  var body: some View {
    #if os(tvOS)
      Group {
        Button {
          onSelect(entry)
        } label: {
          TOCEntryLabel(entry: entry, currentPageIndex: currentPageIndex, level: level)
        }
        .adaptiveButtonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 24, leading: 48 + CGFloat(level * 20), bottom: 24, trailing: 48))
        .id(entry.pageIndex)

        if let children = entry.children, !children.isEmpty {
          ForEach(children) { child in
            TOCEntryRow(
              entry: child,
              currentPageIndex: currentPageIndex,
              onSelect: onSelect,
              level: level + 1
            )
          }
        }
      }
    #else
      if let children = entry.children, !children.isEmpty {
        DisclosureGroup(isExpanded: $isExpanded) {
          ForEach(children) { child in
            TOCEntryRow(
              entry: child,
              currentPageIndex: currentPageIndex,
              onSelect: onSelect,
              level: level + 1
            )
          }
        } label: {
          Button(action: {
            onSelect(entry)
          }) {
            TOCEntryLabel(entry: entry, currentPageIndex: currentPageIndex, level: level)
          }
          .adaptiveButtonStyle(.plain)
        }
        .id(entry.pageIndex)
        .onAppear {
          if shouldExpand(entry: entry, children: children) {
            isExpanded = true
          }
        }
      } else {
        Button {
          onSelect(entry)
        } label: {
          TOCEntryLabel(entry: entry, currentPageIndex: currentPageIndex, level: level)
        }
        .adaptiveButtonStyle(.plain)
        .contentShape(Rectangle())
        .id(entry.pageIndex)
      }
    #endif
  }

  private func shouldExpand(entry: ReaderTOCEntry, children: [ReaderTOCEntry]) -> Bool {
    return containsPageIndex(currentPageIndex, in: children)
  }

  private func containsPageIndex(_ pageIndex: Int, in entries: [ReaderTOCEntry]) -> Bool {
    for entry in entries {
      if entry.pageIndex == pageIndex {
        return true
      }
      if let children = entry.children, containsPageIndex(pageIndex, in: children) {
        return true
      }
    }
    return false
  }
}

private struct TOCEntryLabel: View {
  let entry: ReaderTOCEntry
  let currentPageIndex: Int
  let level: Int

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title)
        Text(
          "Page \(entry.pageNumber)",
          tableName: nil,
          bundle: .main,
          comment: "TOC page label"
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
}
