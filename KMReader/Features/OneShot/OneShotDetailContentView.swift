//
// OneShotDetailContentView.swift
//
//

import SwiftUI

struct OneShotDetailContentView: View {
  let book: Book
  let series: Series
  let downloadStatus: DownloadStatus?
  let protectionSources: [OfflineProtectionSource]
  let inSheet: Bool

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private let collapsedLinkLimit = 6

  init(
    book: Book,
    series: Series,
    downloadStatus: DownloadStatus?,
    protectionSources: [OfflineProtectionSource] = [],
    inSheet: Bool
  ) {
    self.book = book
    self.series = series
    self.downloadStatus = downloadStatus
    self.protectionSources = protectionSources
    self.inSheet = inSheet
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && book.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var isCompactHero: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      DetailHeroView(
        id: book.id,
        type: .book,
        contentBlurRadius: coverBlurRadius
      ) {
        VStack(alignment: isCompactHero ? .center : .leading, spacing: 6) {
          HStack(alignment: .bottom, spacing: 8) {
            if isCompactHero {
              Spacer(minLength: 0)
            }
            DetailTitleView(title: book.metadata.title)
            if let ageRating = series.metadata.ageRating, ageRating > 0 {
              AgeRatingBadge(ageRating: ageRating)
            }
            Spacer(minLength: 0)
          }

          DetailChipFlow(items: creatorItems, collapsedLimit: 4)

          DetailHeroMetadataGroup {
            if let releaseDate = book.metadata.releaseDate {
              DetailMetadataRow(
                systemImage: "calendar",
                text: Text("Release Date: \(releaseDate)")
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
            if let isbn = book.metadata.isbn, !isbn.isEmpty {
              DetailMetadataRow(
                systemImage: "barcode",
                text: Text(isbn)
              )
            }
          }
        }
      }

      DetailActionCard {
        VStack(alignment: .leading, spacing: 2) {
          let mediaStatus = book.media.statusValue
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if mediaStatus != .ready {
              Label(mediaStatus.label, systemImage: mediaStatus.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mediaStatus.detailColor)
            } else {
              Text("\(book.media.pagesCount) pages")
                .font(.subheadline.weight(.semibold))
            }

            if book.deleted {
              Label("Unavailable", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
            } else if let readProgress = book.readProgress {
              if book.isCompleted {
                Label("Completed", systemImage: "checkmark.circle.fill")
                  .font(.caption)
                  .foregroundStyle(.green)
              } else {
                Label(
                  "Page \(readProgress.page) / \(book.media.pagesCount)",
                  systemImage: "circle.righthalf.filled"
                )
                .font(.caption)
                .foregroundStyle(.orange)
              }
            } else {
              Label("Unread", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let downloadStatus, let icon = downloadStatus.displayIcon {
              Spacer()
              OfflineProtectionStatusChip(
                label: downloadStatus.displayLabel,
                systemImage: icon,
                spinning: downloadStatus.isPending,
                sources: protectionSources
              )
            }
          }

          if let readProgress = book.readProgress, !book.deleted {
            Label(
              "Last Read: \(readProgress.readDate.formattedMediumDate)",
              systemImage: "book.closed"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }

        if !inSheet {
          BookActionsSection(
            book: book,
            downloadStatus: downloadStatus
          )
        }
      }
      .frame(maxWidth: isCompactHero ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: isCompactHero ? .center : .leading)

      DetailTimestampsView(created: book.created, lastModified: book.lastModified)

      if let summary = book.metadata.summary, !summary.isEmpty {
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: nil,
          titleStyle: .headline
        )
      }

      DetailChipFlow(items: genreItems, collapsedLimit: collapsedLinkLimit)

      DetailChipFlow(items: tagItems, collapsedLimit: collapsedLinkLimit)

      DetailChipFlow(items: linkItems, collapsedLimit: collapsedLinkLimit)

      SeriesAlternateTitlesView(series: series)

      // Book media info
      VStack(alignment: .leading, spacing: 8) {
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
              .textSelectionIfAvailable()
            Spacer()
          }

          HStack {
            Image(systemName: "internaldrive")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(minWidth: 16)
            Text(book.size)
              .font(.caption)
              .textSelectionIfAvailable()
            Spacer()
          }

          HStack(alignment: .top) {
            Image(systemName: "folder")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(minWidth: 16)
            Text(book.url)
              .font(.caption)
              .textSelectionIfAvailable()
            Spacer()
          }

          if let comment = book.media.localizedComment {
            VStack(alignment: .leading, spacing: 2) {
              Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
              Text(comment)
                .font(.caption)
                .foregroundColor(.red)
                .textSelectionIfAvailable()
            }
          }
        }
      }
    }
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
    items += (book.metadata.authors ?? []).sortedByRole().map {
      .init(
        title: $0.name,
        systemImage: $0.role.icon,
        destination: .navigate(MetadataFilterHelper.seriesDestinationForAuthor($0.name))
      )
    }
    return items
  }

  private var genreItems: [DetailChipFlow.Item] {
    (series.metadata.genres ?? []).localizedSorted().map {
      .init(
        title: $0,
        systemImage: "theatermasks",
        destination: .navigate(MetadataFilterHelper.seriesDestinationForGenre($0))
      )
    }
  }

  private var tagItems: [DetailChipFlow.Item] {
    (book.metadata.tags ?? []).localizedSorted().map {
      .init(
        title: $0,
        systemImage: "tag",
        destination: .navigate(MetadataFilterHelper.seriesDestinationForTag($0))
      )
    }
  }

  private var linkItems: [DetailChipFlow.Item] {
    (book.metadata.links ?? []).compactMap { link in
      URL(string: link.url).map {
        .init(title: link.label, systemImage: "link", destination: .external($0))
      }
    }
  }
}
