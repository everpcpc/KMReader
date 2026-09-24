//
// SeriesHeroInfoView.swift
//
//

import SwiftUI

/// Title, age rating, creator chips, and metadata rows of the series detail
/// hero. Centered under the compact stacked hero (via `detailHeroCentered`),
/// leading elsewhere.
struct SeriesHeroInfoView: View {
  let series: Series

  @Environment(\.detailHeroCentered) private var heroCentered

  var body: some View {
    VStack(alignment: heroCentered ? .center : .leading, spacing: 12) {
      HStack(alignment: .bottom, spacing: 8) {
        if heroCentered {
          Spacer(minLength: 0)
        }
        DetailTitleView(title: series.metadata.title)
        if let ageRating = series.metadata.ageRating, ageRating > 0 {
          AgeRatingBadge(ageRating: ageRating)
        }
        Spacer(minLength: 0)
      }

      DetailChipFlow(items: creatorItems, collapsedLimit: 4)

      DetailHeroMetadataGroup {
        if let releaseDate = series.booksMetadata.releaseDate {
          DetailMetadataRow(
            systemImage: "calendar",
            text: Text(releaseDate)
          )
        }
        if let status = series.metadata.status, !status.isEmpty {
          DetailMetadataRow(
            systemImage: series.statusIcon,
            text: Text(series.statusDisplayName),
            color: series.statusColor
          )
        }
        if let language = series.metadata.language, !language.isEmpty {
          DetailMetadataRow(
            systemImage: "globe",
            text: Text(LanguageCodeHelper.displayName(for: language))
          )
        }
        if let direction = series.metadata.readingDirection, !direction.isEmpty {
          DetailMetadataRow(
            systemImage: ReadingDirection.fromString(direction).icon,
            text: Text(ReadingDirection.fromString(direction).displayName)
          )
        }
      }
    }
  }

  private var sortedAuthors: [Author] {
    (series.booksMetadata.authors ?? []).sortedByRole()
  }

  private var creatorItems: [DetailChipFlow.Item] {
    var items: [DetailChipFlow.Item] = []
    if let publisher = series.metadata.publisher, !publisher.isEmpty {
      items.append(
        .init(
          title: publisher,
          systemImage: "building.2",
          destination: .navigate(MetadataFilterHelper.seriesDestinationForPublisher(publisher))
        )
      )
    }
    items += sortedAuthors.map {
      .init(
        title: $0.name,
        systemImage: $0.role.icon,
        destination: .navigate(MetadataFilterHelper.seriesDestinationForAuthor($0.name))
      )
    }
    return items
  }
}
