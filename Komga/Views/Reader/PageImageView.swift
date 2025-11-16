//
//  PageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int

  @State private var image: Image?
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let image = image {
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
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
        } else {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .task(id: pageIndex) {
      // Reset zoom state when switching pages
      scale = 1.0
      lastScale = 1.0
      offset = .zero
      lastOffset = .zero

      // Load image (will check cache first: memory -> disk -> network)
      let loadedImage = await viewModel.loadPageImage(pageIndex: pageIndex)
      image = loadedImage
    }
  }
}
