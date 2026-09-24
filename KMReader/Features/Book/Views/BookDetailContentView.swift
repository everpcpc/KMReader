//
// BookDetailContentView.swift
//
//

import Flow
import SwiftUI

struct BookDetailContentView: View {
  let book: Book
  let downloadStatus: DownloadStatus?
  let protectionSources: [OfflineProtectionSource]
  let inSheet: Bool

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

  @State private var thumbnailRefreshKey = UUID()

  private let collapsedLinkLimit = 6

  init(
    book: Book,
    downloadStatus: DownloadStatus?,
    protectionSources: [OfflineProtectionSource] = [],
    inSheet: Bool
  ) {
    self.book = book
    self.downloadStatus = downloadStatus
    self.protectionSources = protectionSources
    self.inSheet = inSheet
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && book.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        ThumbnailImage(
          id: book.id,
          type: .book,
          contentBlurRadius: coverBlurRadius,
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
                thumbnailRefreshKey = UUID()
                ErrorManager.shared.notify(
                  message: String(localized: "notification.cover.refreshed"))
              } catch {
                ErrorManager.shared.notify(
                  message: String(localized: "notification.cover.refreshFailed"))
              }
            }
          } label: {
            Label(String(localized: "Refresh Cover"), systemImage: "arrow.clockwise")
          }
        }
        .id(thumbnailRefreshKey)

        VStack(alignment: .leading, spacing: 6) {
          Text(book.seriesTitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelectionIfAvailable()

          DetailTitleView(title: book.metadata.title)

          DetailAuthorChips(
            authors: (book.metadata.authors ?? []).sortedByRole(),
            destination: { MetadataFilterHelper.booksDestinationForAuthor($0.name) }
          )

          if let releaseDate = book.metadata.releaseDate {
            DetailMetadataRow(
              systemImage: "calendar",
              text: Text("Release Date: \(releaseDate)")
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

      DetailActionCard {
        VStack(alignment: .leading, spacing: 2) {
          let mediaStatus = book.media.statusValue
          let number = book.metadata.number
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if mediaStatus != .ready {
              Label(mediaStatus.label, systemImage: mediaStatus.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mediaStatus.detailColor)
            } else {
              if !number.isEmpty {
                Text(verbatim: "#\(number)")
                  .font(.subheadline.weight(.semibold))
              }
              Text("\(book.media.pagesCount) pages")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            seriesLink: true
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

      if let tags = book.metadata.tags, !tags.isEmpty {
        DetailChipFlowSection(
          title: "Tags", items: tags.localizedSorted(), collapsedLimit: collapsedLinkLimit
        ) { tag in
          NavigationLink(value: MetadataFilterHelper.booksDestinationForTag(tag)) {
            DetailChip(tag)
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

      // book media info
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
  }
}
