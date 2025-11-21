//
//  CollectionDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionDetailView: View {
  let collectionId: String

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  @Environment(\.dismiss) private var dismiss

  @State private var seriesViewModel = SeriesViewModel()
  @State private var collection: Collection?
  @State private var actionErrorMessage: String?

  private var thumbnailURL: URL? {
    guard let collection = collection else { return nil }
    return CollectionService.shared.getCollectionThumbnailURL(id: collection.id)
  }

  private var isActionErrorPresented: Binding<Bool> {
    Binding(
      get: { actionErrorMessage != nil },
      set: { if !$0 { actionErrorMessage = nil } }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let collection = collection {
          // Header with thumbnail and info
          HStack(alignment: .top, spacing: 16) {
            ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

            VStack(alignment: .leading) {
              Text(collection.name)
                .font(.title2)

              // Series count
              Text("\(collection.seriesIds.count) series")
                .font(.caption)
                .foregroundColor(.secondary)

              // Created date
              HStack(spacing: 4) {
                Image(systemName: "calendar.badge.plus")
                  .font(.caption2)
                Text(collection.createdDate.formatted(date: .abbreviated, time: .omitted))
              }
              .font(.caption)
              .foregroundColor(.secondary)

              // Last modified date
              HStack(spacing: 4) {
                Image(systemName: "clock")
                  .font(.caption2)
                Text(collection.lastModifiedDate.formatted(date: .abbreviated, time: .omitted))
              }
              .font(.caption)
              .foregroundColor(.secondary)

              // Ordered indicator
              if collection.ordered {
                HStack(spacing: 4) {
                  Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                  Text("Ordered")
                }
                .font(.caption)
                .foregroundColor(.secondary)
              }
            }

            Spacer()
          }

          // Series list
          SeriesListView(
            collectionId: collectionId,
            seriesViewModel: seriesViewModel
          )
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal)
    }
    .navigationTitle("Collection")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Action Failed", isPresented: isActionErrorPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      if let actionErrorMessage {
        Text(actionErrorMessage)
      }
    }
    .task {
      await loadCollectionDetails()
    }
  }
}

// Helper functions for CollectionDetailView
extension CollectionDetailView {
  @MainActor
  private func loadCollectionDetails() async {
    do {
      let fetchedCollection = try await CollectionService.shared.getCollection(id: collectionId)
      collection = fetchedCollection
      await seriesViewModel.loadCollectionSeries(collectionId: collectionId, refresh: true)
    } catch {
      actionErrorMessage = error.localizedDescription
    }
  }
}

// Series list view for collection
struct SeriesListView: View {
  let collectionId: String
  @Bindable var seriesViewModel: SeriesViewModel

  @AppStorage("bookListSortDirection") private var sortDirection: SortDirection = .ascending

  private var sortString: String {
    "metadata.titleSort,\(sortDirection.rawValue)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Series")
          .font(.headline)

        Spacer()

        Button {
          sortDirection = sortDirection.toggle()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: sortDirection.icon)
            Text(sortDirection.displayName)
          }
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.1))
          .foregroundColor(.primary)
          .cornerRadius(4)
        }
      }

      if seriesViewModel.isLoading && seriesViewModel.series.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        LazyVStack(spacing: 8) {
          ForEach(seriesViewModel.series) { series in
            NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
              SeriesRowView(
                series: series,
                onActionCompleted: {
                  Task {
                    await seriesViewModel.loadCollectionSeries(
                      collectionId: collectionId, sort: sortString, refresh: true)
                  }
                }
              )
            }
            .buttonStyle(.plain)
            .onAppear {
              if series.id == seriesViewModel.series.last?.id {
                Task {
                  await seriesViewModel.loadCollectionSeries(
                    collectionId: collectionId, sort: sortString, refresh: false)
                }
              }
            }
          }

          if seriesViewModel.isLoading && !seriesViewModel.series.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
          }
        }
      }
    }
    .task(id: collectionId) {
      await seriesViewModel.loadCollectionSeries(
        collectionId: collectionId, sort: sortString, refresh: true)
    }
    .onChange(of: sortDirection) {
      Task {
        await seriesViewModel.loadCollectionSeries(
          collectionId: collectionId, sort: sortString, refresh: true)
      }
    }
  }
}
