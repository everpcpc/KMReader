//
//  SeriesBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesBrowseView: View {
  @Binding var browseOpts: SeriesBrowseOptions
  let width: CGFloat
  let height: CGFloat
  let searchText: String
  let spacing: CGFloat = 16

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid

  @State private var viewModel = SeriesViewModel()

  var availableWidth: CGFloat {
    width - spacing * 2
  }

  var isLandscape: Bool {
    width > height
  }

  var columnsCount: Int {
    return isLandscape ? browseColumns.landscape : browseColumns.portrait
  }

  var cardWidth: CGFloat {
    let totalSpacing = CGFloat(columnsCount - 1) * spacing
    return (availableWidth - totalSpacing) / CGFloat(columnsCount)
  }

  var columns: [GridItem] {
    Array(
      repeating: GridItem(.fixed(cardWidth), spacing: 16),
      count: columnsCount)
  }

  @State private var showOptions = false

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.series.isEmpty {
        VStack(spacing: 16) {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        }
      } else if let errorMessage = viewModel.errorMessage {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(themeColorOption.color)
          Text(errorMessage)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task {
              await viewModel.loadSeries(
                browseOpts: browseOpts, searchText: searchText, refresh: true)
            }
          }
        }
        .padding()
      } else if viewModel.series.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "books.vertical")
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text("No series found")
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
            ForEach(Array(viewModel.series.enumerated()), id: \.element.id) { index, series in
              NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                SeriesCardView(
                  series: series,
                  cardWidth: cardWidth,
                  onActionCompleted: {
                    Task {
                      await viewModel.loadSeries(
                        browseOpts: browseOpts, searchText: searchText, refresh: true)
                    }
                  }
                )
              }
              .buttonStyle(.plain)
              .onAppear {
                if index >= viewModel.series.count - 3 {
                  Task {
                    await viewModel.loadSeries(
                      browseOpts: browseOpts, searchText: searchText, refresh: false)
                  }
                }
              }
            }
          }
          .padding(.horizontal, spacing)
        case .list:
          LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.series.enumerated()), id: \.element.id) { index, series in
              NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                SeriesRowView(
                  series: series,
                  onActionCompleted: {
                    Task {
                      await viewModel.loadSeries(
                        browseOpts: browseOpts, searchText: searchText, refresh: true)
                    }
                  }
                )
                .padding()
              }
              .buttonStyle(.plain)
              .onAppear {
                if index >= viewModel.series.count - 3 {
                  Task {
                    await viewModel.loadSeries(
                      browseOpts: browseOpts, searchText: searchText, refresh: false)
                  }
                }
              }

              if index < viewModel.series.count - 1 {
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
      if viewModel.series.isEmpty {
        await viewModel.loadSeries(browseOpts: browseOpts, searchText: searchText, refresh: true)
      }
    }
    .onChange(of: browseOpts) { _, newValue in
      Task {
        await viewModel.loadSeries(browseOpts: newValue, searchText: searchText, refresh: true)
      }
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await viewModel.loadSeries(browseOpts: browseOpts, searchText: newValue, refresh: true)
      }
    }
    .sheet(isPresented: $showOptions) {
      SeriesBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}
