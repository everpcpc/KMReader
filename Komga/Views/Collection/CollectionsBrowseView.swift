//
//  CollectionsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionsBrowseView: View {
  @Binding var browseOpts: SeriesBrowseOptions
  let width: CGFloat
  let height: CGFloat
  let searchText: String

  private let spacing: CGFloat = 16

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = CollectionViewModel()
  @State private var showOptions = false

  private var availableWidth: CGFloat {
    width - spacing * 2
  }

  private var isLandscape: Bool {
    width > height
  }

  private var columnsCount: Int {
    isLandscape ? browseColumns.landscape : browseColumns.portrait
  }

  private var cardWidth: CGFloat {
    guard columnsCount > 0 else { return availableWidth }
    let totalSpacing = CGFloat(columnsCount - 1) * spacing
    return (availableWidth - totalSpacing) / CGFloat(columnsCount)
  }

  private var columns: [GridItem] {
    Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: max(columnsCount, 1))
  }

  var body: some View {
    VStack(spacing: 0) {
      if BrowseContentType.collections.supportsSorting
        || BrowseContentType.collections.supportsReadStatusFilter
      {
        header
      }
      if viewModel.isLoading && viewModel.collections.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else if let errorMessage = viewModel.errorMessage {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(themeColorOption.color)
          Text(errorMessage)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task {
              await loadCollections(refresh: true)
            }
          }
        }
        .padding()
      } else if viewModel.collections.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "square.grid.2x2")
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text("No collections found")
            .font(.headline)
          Text("Try selecting a different library.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(viewModel.collections.enumerated()), id: \.element.id) {
              index, collection in
              CollectionCardView(collection: collection, width: cardWidth)
                .onAppear {
                  if index >= viewModel.collections.count - 3 {
                    Task {
                      await loadCollections(refresh: false)
                    }
                  }
                }
            }
          }
          .padding(.horizontal, spacing)
        case .list:
          LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.collections.enumerated()), id: \.element.id) {
              index, collection in
              CollectionRowView(collection: collection)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .onAppear {
                  if index >= viewModel.collections.count - 3 {
                    Task {
                      await loadCollections(refresh: false)
                    }
                  }
                }

              if index < viewModel.collections.count - 1 {
                Divider()
                  .padding(.leading)
              }
            }
          }
        }

        if viewModel.isLoading {
          ProgressView()
            .padding()
        }
      }
    }
    .task {
      if viewModel.collections.isEmpty {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: browseOpts) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .sheet(isPresented: $showOptions) {
      SeriesBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }

  private func loadCollections(refresh: Bool) async {
    // Collections use a simple sort string based on series sort field
    let sort: String?
    switch browseOpts.sortField {
    case .name:
      sort = "name,\(browseOpts.sortDirection.rawValue)"
    case .dateAdded:
      sort = "createdDate,\(browseOpts.sortDirection.rawValue)"
    case .dateUpdated:
      sort = "lastModifiedDate,\(browseOpts.sortDirection.rawValue)"
    default:
      sort = nil
    }
    await viewModel.loadCollections(
      libraryId: browseOpts.libraryId,
      sort: sort,
      searchText: searchText,
      refresh: refresh
    )
  }
}

extension CollectionsBrowseView {
  private var header: some View {
    HStack {
      Button {
        showOptions = true
      } label: {
        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding([.horizontal, .top])
  }
}
