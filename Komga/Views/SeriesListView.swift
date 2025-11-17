//
//  SeriesListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesListView: View {
  @Binding var browseOpts: BrowseOptions
  let width: CGFloat
  let height: CGFloat
  let spacing: CGFloat = 16
  @State private var viewModel = SeriesViewModel()
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

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
              await viewModel.loadSeries(browseOpts: browseOpts, refresh: true)
            }
          }
        }
        .padding()
      } else {
        LazyVGrid(columns: columns, spacing: spacing) {
          ForEach(Array(viewModel.series.enumerated()), id: \.element.id) { index, series in
            NavigationLink(destination: SeriesDetailView(seriesId: series.id)) {
              SeriesCardView(
                series: series, viewModel: viewModel, cardWidth: cardWidth)
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
              // Load next page when the last few items appear
              if index >= viewModel.series.count - 3 {
                Task {
                  await viewModel.loadSeries(browseOpts: browseOpts, refresh: false)
                }
              }
            }
          }
        }
        .padding(.horizontal, spacing)

        if viewModel.isLoading {
          ProgressView()
            .padding()
        }
      }
    }
    .animation(.default, value: viewModel.series)
    .task {
      if viewModel.series.isEmpty {
        await viewModel.loadSeries(browseOpts: browseOpts, refresh: true)
      }
    }
    .onChange(of: browseOpts) {
      Task {
        await viewModel.loadSeries(browseOpts: browseOpts, refresh: true)
      }
    }
  }
}
