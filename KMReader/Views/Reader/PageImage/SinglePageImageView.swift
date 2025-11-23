//
//  SinglePageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Single page image view with zoom and pan support
struct SinglePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  private let minScale: CGFloat = 1.0
  private let maxScale: CGFloat = 4.0

  var body: some View {
    PageImageView(viewModel: viewModel, pageIndex: pageIndex)
      .scaleEffect(scale, anchor: .center)
      .offset(offset)
      .gesture(
        MagnificationGesture()
          .onChanged { value in
            let delta = value / lastScale
            lastScale = value
            applyScale(delta: delta)
          }
          .onEnded { _ in
            lastScale = 1.0
            if scale <= minScale {
              withAnimation {
                resetTransform()
              }
            }
          }
      )
      .onTapGesture(count: 2) {
        // Double tap to zoom in/out
        if scale > minScale {
          withAnimation {
            resetTransform()
          }
        } else {
          withAnimation {
            scale = 2.0
          }
        }
      }
      .simultaneousGesture(
        DragGesture(
          minimumDistance: scale > minScale ? 0 : CGFloat.greatestFiniteMagnitude
        )
        .onChanged { value in
          guard scale > minScale else { return }
          offset = CGSize(
            width: lastOffset.width + value.translation.width,
            height: lastOffset.height + value.translation.height
          )
        }
        .onEnded { _ in
          if scale > minScale {
            lastOffset = offset
          } else {
            resetPanState()
          }
        }
      )
      .task(id: pageIndex) {
        // Reset zoom state when switching pages
        resetTransform()
      }
      .onDisappear {
        resetTransform()
      }
  }

  private func applyScale(delta: CGFloat) {
    let previousScale = scale
    let newScale = min(max(previousScale * delta, minScale), maxScale)
    scale = newScale

    if newScale == minScale {
      withAnimation {
        resetPanState()
      }
      return
    }

    let factor = previousScale == 0 ? 1 : newScale / previousScale
    guard factor.isFinite else { return }

    offset = CGSize(
      width: offset.width * factor,
      height: offset.height * factor
    )
    lastOffset = CGSize(
      width: lastOffset.width * factor,
      height: lastOffset.height * factor
    )
  }

  private func resetTransform() {
    scale = minScale
    lastScale = minScale
    resetPanState()
  }

  private func resetPanState() {
    offset = .zero
    lastOffset = .zero
  }
}
