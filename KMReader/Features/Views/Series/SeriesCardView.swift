//
//  SeriesCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesCardView: View {
  @Bindable var komgaSeries: KomgaSeries
  let cardWidth: CGFloat
  var onActionCompleted: (() -> Void)? = nil

  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false

  @State private var showCollectionPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  var body: some View {
    VStack(alignment: .leading) {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)) {
        ThumbnailImage(
          id: komgaSeries.seriesId, type: .series, width: cardWidth, alignment: .bottom
        ) {
          ZStack {
            if komgaSeries.booksUnreadCount > 0 {
              VStack(alignment: .trailing) {
                UnreadCountBadge(count: komgaSeries.booksUnreadCount)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
              }
            }
          }
        }
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)

      if !coverOnlyCards {
        VStack(alignment: .leading) {
          Text(komgaSeries.metaTitle)
            .lineLimit(1)

          HStack(spacing: 4) {
            if komgaSeries.deleted {
              Text("Unavailable")
                .foregroundColor(.red)
            } else if komgaSeries.oneshot {
              Text("Oneshot")
                .foregroundColor(.blue)
            } else {
              Text("\(komgaSeries.booksCount) books")
            }
            if komgaSeries.downloadStatus != .notDownloaded {
              Image(systemName: komgaSeries.downloadStatus.icon)
                .foregroundColor(komgaSeries.downloadStatus.color)
            }
            Spacer()
            Menu {
              SeriesContextMenu(
                komgaSeries: komgaSeries,
                onActionCompleted: onActionCompleted,
                onShowCollectionPicker: {
                  showCollectionPicker = true
                },
                onDeleteRequested: {
                  showDeleteConfirmation = true
                },
                onEditRequested: {
                  showEditSheet = true
                }
              )
            } label: {
              HStack {
                Image(systemName: "ellipsis")
                  .padding(.horizontal, 4)
              }
              .foregroundColor(.secondary)
              .contentShape(Rectangle())
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }.font(.footnote)
      }
    }
    .frame(width: cardWidth, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .top)
    .alert("Delete Series", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
    } message: {
      Text("Are you sure you want to delete this series? This action cannot be undone.")
    }
    .sheet(isPresented: $showCollectionPicker) {
      CollectionPickerSheet(
        seriesIds: [komgaSeries.seriesId],
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        },
        onComplete: {
          // Create already adds series, just refresh
          onActionCompleted?()
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      SeriesEditSheet(series: komgaSeries.toSeries())
        .onDisappear {
          onActionCompleted?()
        }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [komgaSeries.seriesId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.addedToCollection"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: komgaSeries.seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
