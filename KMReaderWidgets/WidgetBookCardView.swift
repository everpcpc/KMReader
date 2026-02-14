//
//  WidgetBookCardView.swift
//  KMReaderWidgets
//

import SwiftUI
import WidgetKit

struct WidgetBookCardView: View {
  let entry: WidgetBookEntry
  let showProgress: Bool

  var body: some View {
    Link(destination: WidgetDataStore.bookDeepLinkURL(bookId: entry.id)) {
      VStack(spacing: 3) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.secondary.opacity(0.2))
          .aspectRatio(2.0 / 3.0, contentMode: .fit)
          .overlay {
            thumbnailImage
          }
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .overlay(alignment: .bottom) {
            if showProgress, let page = entry.progressPage, entry.totalPages > 0 {
              ProgressView(value: Double(page), total: Double(entry.totalPages))
                .tint(.accentColor)
                .padding(.horizontal, 3)
                .padding(.bottom, 3)
            }
          }

        Text(entry.title)
          .font(.caption2)
          .fontWeight(.medium)
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private var thumbnailImage: some View {
    if let url = WidgetDataStore.thumbnailURL(for: entry),
      let imageData = try? Data(contentsOf: url),
      let uiImage = PlatformImage(data: imageData)
    {
      Image(platformImage: uiImage)
        .resizable()
        .scaledToFill()
    }
  }
}

#if os(iOS)
  typealias PlatformImage = UIImage
#elseif os(macOS)
  typealias PlatformImage = NSImage
#endif

#if os(macOS)
  extension Image {
    init(platformImage: NSImage) {
      self.init(nsImage: platformImage)
    }
  }
#else
  extension Image {
    init(platformImage: UIImage) {
      self.init(uiImage: platformImage)
    }
  }
#endif
