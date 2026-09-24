//
// DetailChipFlowSection.swift
//
//

import Flow
import SwiftUI

/// Labeled flow of matte chips for detail pages (genres, tags, links).
struct DetailChipFlowSection<Item: Hashable, Content: View>: View {
  let title: LocalizedStringKey
  let items: [Item]
  let collapsedLimit: Int
  @ViewBuilder let content: (Item) -> Content

  @State private var isExpanded = false

  init(
    title: LocalizedStringKey,
    items: [Item],
    collapsedLimit: Int = 6,
    @ViewBuilder content: @escaping (Item) -> Content
  ) {
    self.title = title
    self.items = items
    self.collapsedLimit = collapsedLimit
    self.content = content
  }

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        HFlow {
          ForEach(displayedItems, id: \.self) { item in
            content(item)
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
