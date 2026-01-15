//
//  OneShotDetailContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct OneShotDetailContentView: View {
  let book: Book
  let series: Series
  let downloadStatus: DownloadStatus?
  let inSheet: Bool

  @State private var thumbnailRefreshKey = UUID()

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
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

  var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .bottom) {
        Text(book.metadata.title)
          .font(.title2)
          .fixedSize(horizontal: false, vertical: true)
        if let ageRating = series.metadata.ageRating, ageRating > 0 {
          AgeRatingBadge(ageRating: ageRating)
        }
        Spacer()
      }

      HStack(alignment: .top) {
        ThumbnailImage(
          id: book.id,
          type: .book,
          width: PlatformHelper.detailThumbnailWidth,
          isTransitionSource: false,
          onAction: {}
        ) {
        } menu: {
          Button {
            Task {
              do {
                _ = try await ThumbnailCache.shared.ensureThumbnail(
                  id: book.id,
                  type: .book,
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
          HStack(spacing: 6) {
            if book.media.status != .ready {
              InfoChip(
                label: book.media.status.label,
                systemImage: book.media.status.icon,
                backgroundColor: book.media.status.color.opacity(0.2),
                foregroundColor: book.media.status.color
              )
            } else {
              InfoChip(
                labelKey: "\(book.media.pagesCount) pages",
                systemImage: "book.pages",
                backgroundColor: Color.blue.opacity(0.2),
                foregroundColor: .blue
              )
            }
          }

          if book.deleted {
            InfoChip(
              labelKey: "Unavailable",
              backgroundColor: Color.red.opacity(0.2),
              foregroundColor: .red
            )
          }

          if let readProgress = book.readProgress {
            if isCompleted {
              InfoChip(
                labelKey: "Completed",
                systemImage: "checkmark.circle.fill",
                backgroundColor: Color.green.opacity(0.2),
                foregroundColor: .green
              )
            } else {
              InfoChip(
                labelKey: "Page \(readProgress.page) / \(book.media.pagesCount)",
                systemImage: "circle.righthalf.filled",
                backgroundColor: Color.orange.opacity(0.2),
                foregroundColor: .orange
              )
            }

            InfoChip(
              labelKey: "Last Read: \(readProgress.readDate.formattedMediumDate)",
              systemImage: "book.closed",
              backgroundColor: Color.teal.opacity(0.2),
              foregroundColor: .teal
            )
          } else {
            InfoChip(
              labelKey: "Unread",
              systemImage: "circle",
              backgroundColor: Color.gray.opacity(0.2),
              foregroundColor: .gray
            )
          }

          if let releaseDate = book.metadata.releaseDate {
            InfoChip(
              labelKey: "Release Date: \(releaseDate)",
              systemImage: "calendar",
              backgroundColor: Color.orange.opacity(0.2),
              foregroundColor: .orange
            )
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

          if let isbn = book.metadata.isbn, !isbn.isEmpty {
            InfoChip(
              label: isbn,
              systemImage: "barcode",
              backgroundColor: Color.cyan.opacity(0.2),
              foregroundColor: .cyan
            )
          }

          if let publisher = series.metadata.publisher, !publisher.isEmpty {
            InfoChip(
              label: publisher,
              systemImage: "building.2",
              backgroundColor: Color.teal.opacity(0.2),
              foregroundColor: .teal
            )
          }

          if let authors = book.metadata.authors, !authors.isEmpty {
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

      // Series genres
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

      // Book tags
      if let tags = book.metadata.tags, !tags.isEmpty {
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

      // Created and last modified dates
      HStack(spacing: 6) {
        InfoChip(
          labelKey: "Created: \(book.created.formattedMediumDate)",
          systemImage: "calendar.badge.plus",
          backgroundColor: Color.blue.opacity(0.2),
          foregroundColor: .blue
        )
        InfoChip(
          labelKey: "Modified: \(book.lastModified.formattedMediumDate)",
          systemImage: "clock",
          backgroundColor: Color.purple.opacity(0.2),
          foregroundColor: .purple
        )
      }

      Divider()
      if let downloadStatus = downloadStatus {
        BookDownloadActionsSection(book: book, status: downloadStatus)
      }

      if !inSheet {
        Divider()
        BookActionsSection(
          book: book,
          seriesLink: false
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

      if let links = book.metadata.links, !links.isEmpty {
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
        }
      }

      // Book media info
      VStack(alignment: .leading, spacing: 8) {
        Divider()
        Text("Media Information")
          .font(.headline)

        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Image(systemName: "doc.text.magnifyingglass")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(minWidth: 16)
            Text(book.media.mediaType.uppercased())
              .font(.caption)
            Spacer()
          }

          HStack {
            Image(systemName: "internaldrive")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(minWidth: 16)
            Text(book.size)
              .font(.caption)
            Spacer()
          }

          HStack(alignment: .top) {
            Image(systemName: "folder")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(minWidth: 16)
            Text(book.url)
              .font(.caption)
            Spacer()
          }

          if let comment = book.media.comment, !comment.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
              Image("exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
              Text(comment)
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        }
      }

      if let summary = book.metadata.summary, !summary.isEmpty {
        Divider()
        ExpandableSummaryView(summary: summary)
      }
    }
  }
}
