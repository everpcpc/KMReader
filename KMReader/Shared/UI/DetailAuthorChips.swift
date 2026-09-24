//
// DetailAuthorChips.swift
//
//

import Flow
import SwiftUI

/// Author chips for a detail page hero, capped at `collapsedLimit` with a
/// "+N" chip that expands in place — long author lists (anthologies)
/// would otherwise flood the hero.
struct DetailAuthorChips: View {
  let authors: [Author]
  let collapsedLimit: Int
  let destination: (Author) -> NavDestination

  @State private var isExpanded = false

  @Environment(\.detailHeroCentered) private var heroCentered

  init(
    authors: [Author],
    collapsedLimit: Int = 4,
    destination: @escaping (Author) -> NavDestination
  ) {
    self.authors = authors
    self.collapsedLimit = collapsedLimit
    self.destination = destination
  }

  var body: some View {
    if !authors.isEmpty {
      if heroCentered {
        HFlow(
          horizontalAlignment: .center,
          verticalAlignment: .center,
          horizontalSpacing: 8,
          verticalSpacing: 8
        ) {
          chips
        }
      } else {
        HFlow(itemSpacing: 8) {
          chips
        }
      }
    }
  }

  @ViewBuilder
  private var chips: some View {
    ForEach(displayedAuthors, id: \.self) { author in
      NavigationLink(value: destination(author)) {
        DetailChip(author.name, systemImage: author.role.icon)
      }
      .adaptiveButtonStyle(.plain)
    }
    if !isExpanded && authors.count > collapsedLimit {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded = true
        }
      } label: {
        DetailChip("+\(authors.count - collapsedLimit)")
      }
      .adaptiveButtonStyle(.plain)
    }
  }

  private var displayedAuthors: [Author] {
    if isExpanded || authors.count <= collapsedLimit {
      return authors
    }
    return Array(authors.prefix(collapsedLimit))
  }
}
