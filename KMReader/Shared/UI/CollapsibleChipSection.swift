//
//  CollapsibleChipSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct CollapsibleChipSection<Item: Hashable, Chip: View>: View {
  let items: [Item]
  let collapsedLimit: Int
  let chip: (Item) -> Chip

  @State private var isExpanded = false

  init(
    items: [Item],
    collapsedLimit: Int = 10,
    @ViewBuilder chip: @escaping (Item) -> Chip
  ) {
    self.items = items
    self.collapsedLimit = collapsedLimit
    self.chip = chip
  }

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HFlow {
          ForEach(displayedItems, id: \.self) { item in
            chip(item)
          }
        }

        if shouldShowToggle {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              isExpanded.toggle()
            }
          } label: {
            Label(
              isExpanded
                ? String(localized: "Show Less")
                : String(localized: "Show More"),
              systemImage: isExpanded ? "chevron.up" : "chevron.down"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .adaptiveButtonStyle(.plain)
        }
      }
    }
  }

  private var shouldShowToggle: Bool {
    items.count > collapsedLimit
  }

  private var displayedItems: [Item] {
    if isExpanded || !shouldShowToggle {
      return items
    }

    return Array(items.prefix(collapsedLimit))
  }
}
