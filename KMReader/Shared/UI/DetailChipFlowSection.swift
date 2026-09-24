//
// DetailChipFlowSection.swift
//
//

import Flow
import SwiftUI

/// Flow of matte chips for detail pages (genres, tags, links), collapsed
/// behind an inline "+N" chip that expands in place. Chips carry their own
/// leading icon to distinguish the field, so the section needs no text title.
struct DetailChipFlowSection<Item: Hashable, Content: View>: View {
  let items: [Item]
  let collapsedLimit: Int
  @ViewBuilder let content: (Item) -> Content

  @State private var isExpanded = false

  init(
    items: [Item],
    collapsedLimit: Int = 6,
    @ViewBuilder content: @escaping (Item) -> Content
  ) {
    self.items = items
    self.collapsedLimit = collapsedLimit
    self.content = content
  }

  var body: some View {
    if !items.isEmpty {
      HFlow {
        ForEach(displayedItems, id: \.self) { item in
          content(item)
        }
        if !isExpanded && items.count > collapsedLimit {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              isExpanded = true
            }
          } label: {
            DetailChip("+\(items.count - collapsedLimit)")
          }
          .adaptiveButtonStyle(.plain)
        }
      }
    }
  }

  private var displayedItems: [Item] {
    if isExpanded || items.count <= collapsedLimit {
      return items
    }

    return Array(items.prefix(collapsedLimit))
  }
}
