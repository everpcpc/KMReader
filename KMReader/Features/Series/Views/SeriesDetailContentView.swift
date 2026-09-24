//
// SeriesDetailContentView.swift
//
//

import SwiftUI

struct SeriesDetailContentView<Actions: View>: View {
  let series: Series
  @ViewBuilder let actions: Actions

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private let collapsedLinkLimit = 6

  init(series: Series, @ViewBuilder actions: () -> Actions) {
    self.series = series
    self.actions = actions()
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && series.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var isCompactHero: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      DetailHeroView(
        id: series.id,
        type: .series,
        contentBlurRadius: coverBlurRadius
      ) {
        VStack(alignment: isCompactHero ? .center : .leading, spacing: 6) {
          HStack(alignment: .bottom, spacing: 8) {
            if isCompactHero {
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

      DetailActionCard {
        if series.deleted {
          Label("Unavailable", systemImage: "exclamationmark.circle")
            .font(.subheadline)
            .foregroundStyle(.red)
        } else {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let totalBookCount = series.metadata.totalBookCount {
              Text("\(series.booksCount) / \(totalBookCount) books")
                .font(.subheadline.weight(.semibold))
            } else {
              Text("\(series.booksCount) books")
                .font(.subheadline.weight(.semibold))
            }

            if series.booksUnreadCount > 0 && series.booksUnreadCount < series.booksCount {
              Label("\(series.booksUnreadCount) unread", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if series.booksInProgressCount > 0 {
              Label("\(series.booksInProgressCount) in progress", systemImage: "circle.righthalf.filled")
                .font(.caption)
                .foregroundStyle(.orange)
            } else if series.booksUnreadCount == 0 && series.booksCount > 0 {
              Label("All read", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            } else if series.booksCount > 0 {
              Label("Unread", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        actions
      }

      if let summary = series.metadata.summary, !summary.isEmpty {
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: nil,
          titleStyle: .headline
        )
      } else if let summary = series.booksMetadata.summary, !summary.isEmpty {
        let subtitle = series.booksMetadata.summaryNumber.map { "(from Book #\($0))" }
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: subtitle,
          titleStyle: .headline
        )
      }

      DetailChipFlow(items: genreItems, collapsedLimit: collapsedLinkLimit)

      DetailChipFlow(items: tagItems, collapsedLimit: collapsedLinkLimit)

      DetailChipFlow(items: linkItems, collapsedLimit: collapsedLinkLimit)

      if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Alternate Titles")
            .font(.headline)
          VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(alternateTitles.enumerated()), id: \.offset) { index, altTitle in
              HStack(alignment: .top, spacing: 4) {
                Text("\(altTitle.label):")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(width: 60, alignment: .leading)
                Text(altTitle.title)
                  .font(.caption)
                  .foregroundColor(.primary)
                  .textSelectionIfAvailable()
              }
            }
          }
        }
      }

      DetailTimestampsView(created: series.created, lastModified: series.lastModified)
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

  private var genreItems: [DetailChipFlow.Item] {
    sortedGenres.map {
      .init(
        title: $0,
        systemImage: "theatermasks",
        destination: .navigate(MetadataFilterHelper.seriesDestinationForGenre($0))
      )
    }
  }

  private var tagItems: [DetailChipFlow.Item] {
    combinedTagItems.map {
      .init(
        title: $0,
        systemImage: "tag",
        destination: .navigate(MetadataFilterHelper.seriesDestinationForTag($0))
      )
    }
  }

  private var linkItems: [DetailChipFlow.Item] {
    (series.metadata.links ?? []).compactMap { link in
      URL(string: link.url).map {
        .init(title: link.label, systemImage: "link", destination: .external($0))
      }
    }
  }

  private var sortedGenres: [String] {
    (series.metadata.genres ?? []).localizedSorted()
  }

  /// Series tags first (sorted), then book-only tags (sorted) — preserves web UI behavior
  private var combinedTagItems: [String] {
    let seriesTags = (series.metadata.tags ?? []).filter { !$0.isEmpty }.localizedSorted()
    let bookTags = (series.booksMetadata.tags ?? []).filter { !$0.isEmpty }

    let seriesSet = Set(seriesTags)
    let bookOnly = Set(bookTags).subtracting(seriesSet).localizedSorted()

    return seriesTags + bookOnly
  }
}
