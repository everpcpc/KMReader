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
  let containingCollections: [SeriesCollection]
  @Binding var thumbnailRefreshTrigger: Int

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
          refreshTrigger: thumbnailRefreshTrigger
        )
        .thumbnailFocus()

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
                    systemImage: "book",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                } else {
                  InfoChip(
                    labelKey: "\(series.booksCount) books",
                    systemImage: "book",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
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
              InfoChip(
                label: publisher,
                systemImage: "building.2",
                backgroundColor: Color.teal.opacity(0.2),
                foregroundColor: .teal
              )
            }

            if let authors = series.booksMetadata.authors, !authors.isEmpty {
              HFlow {
                ForEach(authors.sortedByRole(), id: \.self) { author in
                  InfoChip(
                    label: author.name,
                    systemImage: author.role.icon,
                    backgroundColor: Color.indigo.opacity(0.2),
                    foregroundColor: .indigo
                  )
                }
              }
            }
          }
        }
      }

      if let genres = series.metadata.genres, !genres.isEmpty {
        HFlow {
          ForEach(genres.sorted(), id: \.self) { genre in
            InfoChip(
              label: genre,
              systemImage: "bookmark",
              backgroundColor: Color.blue.opacity(0.1),
              foregroundColor: .blue,
              cornerRadius: 8
            )
          }
        }
      }

      if let tags = series.metadata.tags, !tags.isEmpty {
        HFlow {
          ForEach(tags.sorted(), id: \.self) { tag in
            InfoChip(
              label: tag,
              systemImage: "tag",
              backgroundColor: Color.secondary.opacity(0.1),
              foregroundColor: .secondary,
              cornerRadius: 8
            )
          }
        }
      }

      HStack(spacing: 6) {
        InfoChip(
          labelKey: "Created: \(series.created.formattedMediumDate)",
          systemImage: "calendar.badge.plus",
          backgroundColor: Color.blue.opacity(0.2),
          foregroundColor: .blue
        )
        InfoChip(
          labelKey: "Modified: \(series.lastModified.formattedMediumDate)",
          systemImage: "clock",
          backgroundColor: Color.purple.opacity(0.2),
          foregroundColor: .purple
        )
      }

      if !containingCollections.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Text("Collections")
              .font(.headline)
          }
          .foregroundColor(.secondary)

          VStack(alignment: .leading, spacing: 8) {
            ForEach(containingCollections) { collection in
              NavigationLink(
                value: NavDestination.collectionDetail(collectionId: collection.id)
              ) {
                HStack {
                  Label(collection.name, systemImage: "square.grid.2x2")
                    .foregroundColor(.primary)
                  Spacer()
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(16)
              }
            }
          }
        }
        .padding(.vertical)
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
              if let url = URL(string: link.url) {
                Link(destination: url) {
                  InfoChip(
                    label: link.label,
                    systemImage: "link",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                }
              } else {
                InfoChip(
                  label: link.label,
                  systemImage: "link",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )
              }
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
}
