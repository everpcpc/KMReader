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
      VStack(alignment: .leading, spacing: 4) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.secondary.opacity(0.16))
          .aspectRatio(2.0 / 3.0, contentMode: .fit)
          .overlay {
            thumbnailImage
          }
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
          }
          .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
          .overlay(alignment: .bottom) {
            if showProgress, let page = entry.progressPage, entry.totalPages > 0 {
              ZStack {
                Capsule()
                  .fill(.black.opacity(0.42))
                  .frame(height: 6)
                ProgressView(value: Double(page), total: Double(entry.totalPages))
                  .tint(.white)
                  .progressViewStyle(.linear)
                  .scaleEffect(y: 0.9)
                  .padding(.horizontal, 1)
              }
              .padding(.horizontal, 6)
              .padding(.bottom, 5)
            }
          }

        Text(entry.title)
          .font(.caption2)
          .fontWeight(.semibold)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
