//
// DetailAuthorChips.swift
//
//

import Flow
import SwiftUI

/// Creator chip row for a detail page hero: the publisher chip (when the
/// series has one) followed by author chips capped at `collapsedLimit`
/// with a "+N" chip that expands in place — long author lists
/// (anthologies) would otherwise flood the hero.
struct DetailAuthorChips: View {
  let publisher: String?
  let authors: [Author]
  let collapsedLimit: Int
  let destination: (Author) -> NavDestination

  @State private var isExpanded = false

  @Environment(\.detailHeroCentered) private var heroCentered

  init(
    publisher: String? = nil,
    authors: [Author],
    collapsedLimit: Int = 4,
    destination: @escaping (Author) -> NavDestination
  ) {
    self.publisher = publisher
    self.authors = authors
    self.collapsedLimit = collapsedLimit
    self.destination = destination
  }

  private var normalizedPublisher: String? {
    guard let publisher, !publisher.isEmpty else { return nil }
    return publisher
  }

  var body: some View {
    if !authors.isEmpty || normalizedPublisher != nil {
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
    if let publisher = normalizedPublisher {
      NavigationLink(value: MetadataFilterHelper.seriesDestinationForPublisher(publisher)) {
        DetailChip(publisher, systemImage: "building.2")
      }
      .adaptiveButtonStyle(.plain)
    }
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
