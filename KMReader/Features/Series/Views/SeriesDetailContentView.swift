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

          DetailAuthorChips(
            authors: sortedAuthors,
            destination: { MetadataFilterHelper.seriesDestinationForAuthor($0.name) }
          )

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

      DetailChipFlowSection(items: sortedGenres, collapsedLimit: collapsedLinkLimit) { genre in
        NavigationLink(value: MetadataFilterHelper.seriesDestinationForGenre(genre)) {
          DetailChip(genre, systemImage: "theatermasks")
        }
        .adaptiveButtonStyle(.plain)
      }

      DetailChipFlowSection(items: combinedTagItems, collapsedLimit: collapsedLinkLimit) { tag in
        NavigationLink(value: MetadataFilterHelper.seriesDestinationForTag(tag)) {
          DetailChip(tag, systemImage: "tag")
        }
        .adaptiveButtonStyle(.plain)
      }

      if let publisher = series.metadata.publisher, !publisher.isEmpty {
        DetailChipFlowSection(items: [publisher], collapsedLimit: collapsedLinkLimit) { name in
          NavigationLink(value: MetadataFilterHelper.seriesDestinationForPublisher(name)) {
            DetailChip(name, systemImage: "building.2")
          }
          .adaptiveButtonStyle(.plain)
        }
      }

      if let links = series.metadata.links, !links.isEmpty {
        DetailChipFlowSection(items: links, collapsedLimit: collapsedLinkLimit) { link in
          if let url = URL(string: link.url) {
            Link(destination: url) {
              DetailChip(link.label, systemImage: "link")
            }
            .adaptiveButtonStyle(.plain)
          }
        }
      }

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
    .environment(\.detailHeroCentered, isCompactHero)
  }

  private var sortedAuthors: [Author] {
    (series.booksMetadata.authors ?? []).sortedByRole()
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
