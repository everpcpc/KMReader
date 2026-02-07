//
//  SeriesDetailContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct SeriesDetailContentView: View {
  let series: Series

  @State private var thumbnailRefreshKey = UUID()

  private let collapsedMetadataChipLimit = 10

  var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .bottom) {
        Text(series.metadata.title)
          .font(.title2)
        if let ageRating = series.metadata.ageRating, ageRating > 0 {
          AgeRatingBadge(ageRating: ageRating)
        }
        Spacer()
      }

      HStack(alignment: .top) {
        ThumbnailImage(
          id: series.id,
          type: .series,
          width: PlatformHelper.detailThumbnailWidth,
          isTransitionSource: false,
          onAction: {}
        ) {
        } menu: {
          Button {
            Task {
              do {
                _ = try await ThumbnailCache.shared.ensureThumbnail(
                  id: series.id,
                  type: .series,
                  force: true
                )
                await MainActor.run {
                  thumbnailRefreshKey = UUID()
                  ErrorManager.shared.notify(
                    message: String(localized: "notification.cover.refreshed"))
                }
              } catch {
                await MainActor.run {
                  ErrorManager.shared.notify(
                    message: String(localized: "notification.cover.refreshFailed"))
                }
              }
            }
          } label: {
            Label(String(localized: "Refresh Cover"), systemImage: "arrow.clockwise")
          }
        }
        .id(thumbnailRefreshKey)

        VStack(alignment: .leading) {

          VStack(alignment: .leading, spacing: 6) {
            if series.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else {
              HStack(spacing: 6) {
                if let totalBookCount = series.metadata.totalBookCount {
                  InfoChip(
                    labelKey: "\(series.booksCount) / \(totalBookCount) books",
                    systemImage: ContentIcon.book,
                    backgroundColor: Color.secondary.opacity(0.1),
                    foregroundColor: .secondary
                  )
                } else {
                  InfoChip(
                    labelKey: "\(series.booksCount) books",
                    systemImage: ContentIcon.book,
                    backgroundColor: Color.secondary.opacity(0.1),
                    foregroundColor: .secondary
                  )
                }

                if series.booksUnreadCount > 0 && series.booksUnreadCount < series.booksCount {
                  InfoChip(
                    labelKey: "\(series.booksUnreadCount) unread",
                    systemImage: "circle",
                    backgroundColor: Color.gray.opacity(0.2),
                    foregroundColor: .gray
                  )
                } else if series.booksInProgressCount > 0 {
                  InfoChip(
                    labelKey: "\(series.booksInProgressCount) in progress",
                    systemImage: "circle.righthalf.filled",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                } else if series.booksUnreadCount == 0 && series.booksCount > 0 {
                  InfoChip(
                    labelKey: "All read",
                    systemImage: "checkmark.circle.fill",
                    backgroundColor: Color.green.opacity(0.2),
                    foregroundColor: .green
                  )
                }
              }
            }

            if hasReleaseInfo {
              HStack(spacing: 6) {
                if let releaseDate = series.booksMetadata.releaseDate {
                  InfoChip(
                    label: releaseDate,
                    systemImage: "calendar",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                }
                if let status = series.metadata.status, !status.isEmpty {
                  InfoChip(
                    labelKey: series.statusDisplayName,
                    systemImage: series.statusIcon,
                    backgroundColor: series.statusColor.opacity(0.8),
                    foregroundColor: .white
                  )
                }
              }
            }

            if hasReadInfo {
              HStack(spacing: 6) {
                if let language = series.metadata.language, !language.isEmpty {
                  InfoChip(
                    label: LanguageCodeHelper.displayName(for: language),
                    systemImage: "globe",
                    backgroundColor: Color.purple.opacity(0.2),
                    foregroundColor: .purple
                  )
                }

                if let direction = series.metadata.readingDirection, !direction.isEmpty {
                  InfoChip(
                    label: ReadingDirection.fromString(direction).displayName,
                    systemImage: ReadingDirection.fromString(direction).icon,
                    backgroundColor: Color.cyan.opacity(0.2),
                    foregroundColor: .cyan
                  )
                }
              }
            }

            if let publisher = series.metadata.publisher, !publisher.isEmpty {
              TappableInfoChip(
                label: publisher,
                systemImage: "building.2",
                color: .secondary,
                destination: MetadataFilterHelper.seriesDestinationForPublisher(publisher)
              )
            }

            CollapsibleChipSection(items: sortedAuthors, collapsedLimit: collapsedMetadataChipLimit) {
              author in
              TappableInfoChip(
                label: author.name,
                systemImage: author.role.icon,
                color: .purple,
                destination: MetadataFilterHelper.seriesDestinationForAuthor(author.name)
              )
            }
          }
        }
      }

      CollapsibleChipSection(items: sortedGenres, collapsedLimit: collapsedMetadataChipLimit) { genre in
        TappableInfoChip(
          label: genre,
          systemImage: "theatermasks",
          color: .teal,
          destination: MetadataFilterHelper.seriesDestinationForGenre(genre)
        )
      }

      CollapsibleChipSection(items: sortedTags, collapsedLimit: collapsedMetadataChipLimit) { tag in
        TappableInfoChip(
          label: tag,
          systemImage: "tag",
          color: .secondary,
          destination: MetadataFilterHelper.seriesDestinationForTag(tag)
        )
      }

      HStack(spacing: 6) {
        InfoChip(
          labelKey: "Created: \(series.created.formattedMediumDate)",
          systemImage: "calendar.badge.plus",
          backgroundColor: Color.secondary.opacity(0.1),
          foregroundColor: .secondary
        )
        InfoChip(
          labelKey: "Modified: \(series.lastModified.formattedMediumDate)",
          systemImage: "clock",
          backgroundColor: Color.purple.opacity(0.2),
          foregroundColor: .purple
        )
      }

      if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Divider()
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
              }
            }
          }
        }.padding(.bottom, 8)
      }

      if let links = series.metadata.links, !links.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Divider()
          Text("Links")
            .font(.headline)
          HFlow {
            ForEach(Array(links.enumerated()), id: \.offset) { _, link in
              ExternalLinkChip(label: link.label, url: link.url)
            }
          }
        }.padding(.bottom, 8)
      }

      if let summary = series.metadata.summary, !summary.isEmpty {
        Divider()
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: nil,
          titleStyle: .headline
        )
      } else if let summary = series.booksMetadata.summary, !summary.isEmpty {
        let subtitle = series.booksMetadata.summaryNumber.map { "(from Book #\($0))" }
        Divider()
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: subtitle,
          titleStyle: .headline
        )
      }
    }
  }

  private var hasReleaseInfo: Bool {
    if let releaseDate = series.booksMetadata.releaseDate, !releaseDate.isEmpty {
      return true
    }
    if let status = series.metadata.status, !status.isEmpty {
      return true
    }
    return false
  }

  private var hasReadInfo: Bool {
    if let language = series.metadata.language, !language.isEmpty {
      return true
    }
    if let direction = series.metadata.readingDirection, !direction.isEmpty {
      return true
    }
    return false
  }

  private var sortedAuthors: [Author] {
    (series.booksMetadata.authors ?? []).sortedByRole()
  }

  private var sortedGenres: [String] {
    (series.metadata.genres ?? []).sorted()
  }

  private var sortedTags: [String] {
    (series.metadata.tags ?? []).sorted()
  }
}
