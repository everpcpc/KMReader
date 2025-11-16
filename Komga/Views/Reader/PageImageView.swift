//
//  PageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImageSwiftUI
import SwiftUI

struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int

  @State private var imageURL: URL?
  @State private var loadError: String?
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let imageURL = imageURL {
          // Use SDWebImage to load and display (handles both static and animated images)
          AnimatedImage(
            url: imageURL,
            options: [.retryFailed, .scaleDownLargeImages],
            context: [
              // Limit single image memory to 50MB (will scale down if larger)
              .imageScaleDownLimitBytes: 50 * 1024 * 1024
            ]
          )
          .resizable()
          .aspectRatio(contentMode: .fit)
          .transition(.fade)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .scaleEffect(scale)
          .offset(offset)
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale *= delta
              }
              .onEnded { _ in
                lastScale = 1.0
                if scale < 1.0 {
                  withAnimation {
                    scale = 1.0
                    offset = .zero
                  }
                } else if scale > 4.0 {
                  withAnimation {
                    scale = 4.0
                  }
                }
              }
          )
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                // Only handle drag when zoomed in
                if scale > 1.0 {
                  offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                  )
                }
              }
              .onEnded { _ in
                if scale > 1.0 {
                  lastOffset = offset
                }
              }
          )
          .onTapGesture(count: 2) {
            // Double tap to zoom in/out
            if scale > 1.0 {
              withAnimation {
                scale = 1.0
                offset = .zero
                lastOffset = .zero
              }
            } else {
              withAnimation {
                scale = 2.0
              }
            }
          }
        } else if let error = loadError {
          // Show error message
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 48))
              .foregroundColor(.white.opacity(0.7))
            Text("Failed to load image")
              .font(.headline)
              .foregroundColor(.white)
            Text(error)
              .font(.caption)
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .padding(.horizontal)
            Button("Retry") {
              Task {
                loadError = nil
                imageURL = await viewModel.getPageImageFileURL(pageIndex: pageIndex)
                if imageURL == nil {
                  loadError = "Please check your network connection"
                }
              }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
        } else {
          // Show loading indicator
          ZStack(alignment: .center) {
            ProgressView()
              .frame(width: geometry.size.width, height: geometry.size.height)
              .tint(.white)
              .padding()
          }
        }
      }
    }
    .task(id: pageIndex) {
      // Reset zoom state when switching pages
      scale = 1.0
      lastScale = 1.0
      offset = .zero
      lastOffset = .zero

      // Clear previous URL and error
      imageURL = nil
      loadError = nil

      // Download to cache if needed, then get file URL
      // SDWebImage will handle decoding and display
      imageURL = await viewModel.getPageImageFileURL(pageIndex: pageIndex)

      // If download failed, show error
      if imageURL == nil {
        loadError = "Failed to load page image. Please check your network connection."
      }
    }
    .onDisappear {
      // Clear URL when view disappears
      imageURL = nil
    }
  }
}
