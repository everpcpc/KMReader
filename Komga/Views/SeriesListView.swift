//
//  SeriesListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesListView: View {
  let libraryId: String
  let libraryName: String

  @State private var viewModel = SeriesViewModel()

  // Calculate number of columns and card width based on screen width
  private func calculateLayout(for width: CGFloat) -> (columns: Int, cardWidth: CGFloat) {
    let horizontalPadding: CGFloat = 32  // 16pt padding on each side
    let spacing: CGFloat = 16
    let minCardWidth: CGFloat = 120

    let availableWidth = width - horizontalPadding

    // Calculate how many columns can fit
    let maxColumns = Int((availableWidth + spacing) / (minCardWidth + spacing))
    let columns = max(2, min(maxColumns, 6))  // Minimum 2 columns, maximum 6 columns

    // Calculate actual card width
    let totalSpacing = CGFloat(columns - 1) * spacing
    let cardWidth = (availableWidth - totalSpacing) / CGFloat(columns)

    return (columns, cardWidth)
  }

  var body: some View {
    GeometryReader { geometry in
      let layout = calculateLayout(for: geometry.size.width)
      let columns = Array(
        repeating: GridItem(.fixed(layout.cardWidth), spacing: 16), count: layout.columns)

      Group {
        if viewModel.isLoading && viewModel.series.isEmpty {
          ProgressView()
        } else if let errorMessage = viewModel.errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.orange)
            Text(errorMessage)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await viewModel.loadSeries(libraryId: libraryId, refresh: true)
              }
            }
          }
          .padding()
        } else {
          ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
              ForEach(viewModel.series) { series in
                NavigationLink(destination: SeriesDetailView(seriesId: series.id)) {
                  SeriesCardView(series: series, viewModel: viewModel, cardWidth: layout.cardWidth)
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
            .padding()

            if viewModel.isLoading {
              ProgressView()
                .padding()
            }
          }
        }
      }
    }
    .navigationTitle(libraryName)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if viewModel.series.isEmpty {
        await viewModel.loadSeries(libraryId: libraryId)
      }
    }
  }
}

struct SeriesCardView: View {
  let series: Series
  var viewModel: SeriesViewModel
  let cardWidth: CGFloat
  @State private var thumbnail: UIImage?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Thumbnail
      ZStack {
        if let thumbnail = thumbnail {
          Image(uiImage: thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
        } else {
          Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
              ProgressView()
            }
        }
      }
      .frame(width: cardWidth, height: cardWidth * 1.5)
      .clipped()
      .cornerRadius(8)
      .overlay(alignment: .topTrailing) {
        if series.booksUnreadCount > 0 {
          Text("\(series.booksUnreadCount)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange)
            .clipShape(Capsule())
            .padding(4)
        }
      }

      // Series info
      VStack(alignment: .leading, spacing: 2) {
        Text(series.metadata.title)
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)

        Text("\(series.booksCount) books")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .frame(width: cardWidth, alignment: .leading)
    }
    .task {
      thumbnail = await viewModel.loadThumbnail(for: series.id)
    }
  }
}

#Preview {
  NavigationView {
    SeriesListView(libraryId: "1", libraryName: "Comics")
  }
}
