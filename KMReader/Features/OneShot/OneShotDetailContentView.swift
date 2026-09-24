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

          DetailAuthorChips(
            authors: (book.metadata.authors ?? []).sortedByRole(),
            destination: { MetadataFilterHelper.seriesDestinationForAuthor($0.name) }
          )

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
            seriesLink: false
          )
        }

        if let downloadStatus = downloadStatus {
          BookDownloadActionsSection(
            book: book,
            status: downloadStatus,
            protectionSources: protectionSources
          )
        }
      }

      if let summary = book.metadata.summary, !summary.isEmpty {
        ExpandableSummaryView(
          summary: summary,
          titleIcon: nil,
          subtitle: nil,
          titleStyle: .headline
        )
      }

      if let genres = series.metadata.genres, !genres.isEmpty {
        DetailChipFlowSection(
          title: "Genres", items: genres.localizedSorted(), collapsedLimit: collapsedLinkLimit
        ) { genre in
          NavigationLink(value: MetadataFilterHelper.seriesDestinationForGenre(genre)) {
            DetailChip(genre)
          }
          .adaptiveButtonStyle(.plain)
        }
      }

      if let tags = book.metadata.tags, !tags.isEmpty {
        DetailChipFlowSection(
          title: "Tags", items: tags.localizedSorted(), collapsedLimit: collapsedLinkLimit
        ) { tag in
          NavigationLink(value: MetadataFilterHelper.seriesDestinationForTag(tag)) {
            DetailChip(tag)
          }
          .adaptiveButtonStyle(.plain)
        }
      }

      if let publisher = series.metadata.publisher, !publisher.isEmpty {
        DetailChipFlowSection(
          title: "Publisher", items: [publisher], collapsedLimit: collapsedLinkLimit
        ) { name in
          NavigationLink(value: MetadataFilterHelper.seriesDestinationForPublisher(name)) {
            DetailChip(name)
          }
          .adaptiveButtonStyle(.plain)
        }
      }

      if let links = book.metadata.links, !links.isEmpty {
        DetailChipFlowSection(
          title: "Links", items: links, collapsedLimit: collapsedLinkLimit
        ) { link in
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

      DetailTimestampsView(created: book.created, lastModified: book.lastModified)
    }
    .environment(\.detailHeroCentered, isCompactHero)
  }
}
