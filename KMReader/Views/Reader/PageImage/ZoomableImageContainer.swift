//
//  ZoomableImageContainer.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Shared zoom/pan container used by single and dual page views
struct ZoomableImageContainer<Content: View>: View {
  let screenSize: CGSize
  let resetID: AnyHashable
  let minScale: CGFloat
  let maxScale: CGFloat
  let doubleTapScale: CGFloat
  @ViewBuilder private let content: () -> Content

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var scaleAnchor: UnitPoint = .center
  @State private var contentSize: CGSize = .zero

  private let resetAnimation = Animation.easeOut(duration: 0.2)

  private var effectiveContentSize: CGSize {
    let width = contentSize.width > 0 ? contentSize.width : screenSize.width
    let height = contentSize.height > 0 ? contentSize.height : screenSize.height
    return CGSize(width: width, height: height)
  }

  private var metrics: ZoomMetrics {
    ZoomMetrics(contentSize: effectiveContentSize, screenSize: screenSize, scale: scale)
  }

  init(
    screenSize: CGSize,
    resetID: AnyHashable,
    minScale: CGFloat = 1.0,
    maxScale: CGFloat = 4.0,
    doubleTapScale: CGFloat = 2.0,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.screenSize = screenSize
    self.resetID = resetID
    self.minScale = minScale
    self.maxScale = maxScale
    self.doubleTapScale = doubleTapScale
    self.content = content
  }

  var body: some View {
    content()
      .environment(\.zoomableContentSizeReporter) { size in
        if size.width > 0 && size.height > 0 {
          contentSize = size
        }
      }
      .scaleEffect(scale, anchor: scaleAnchor)
      .offset(offset)
      .gesture(magnificationGesture)
      .simultaneousGesture(panGesture)
      .simultaneousGesture(doubleTapGesture)
      .task(id: resetID) {
        resetTransform(animated: false)
      }
      .onDisappear {
        resetTransform(animated: false)
      }
  }

  private var magnificationGesture: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        scaleAnchor = anchor(from: value.startLocation)
        let delta = value.magnification / lastScale
        lastScale = value.magnification
        applyScale(delta: delta)
      }
      .onEnded { _ in
        finalizeMagnification()
      }
  }

  private var panGesture: some Gesture {
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
        clampOffset(animated: true)
      } else {
        resetPanState(animated: false)
      }
    }
  }

  private var doubleTapGesture: some Gesture {
    SpatialTapGesture(count: 2)
      .onEnded { value in
        let tapAnchor = anchor(from: value.location)
        if scale > minScale {
          resetTransform(animated: true)
        } else {
          withAnimation {
            scaleAnchor = tapAnchor
            scale = min(max(doubleTapScale, minScale), maxScale)
            normalizeAnchor()
          }
          clampOffset(animated: true)
        }
      }
  }

  private func applyScale(delta: CGFloat) {
    let previousScale = scale
    let newScale = min(max(previousScale * delta, minScale), maxScale)
    scale = newScale

    if newScale == minScale {
      resetPanState(animated: true)
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

  private func finalizeMagnification() {
    lastScale = 1.0
    normalizeAnchor()
    if scale <= minScale {
      resetTransform(animated: true)
    } else {
      clampOffset(animated: true)
    }
  }

  private func resetTransform(animated: Bool) {
    let update = {
      scale = minScale
      lastScale = minScale
      scaleAnchor = .center
      resetPanState(animated: false)
    }

    guard animated else {
      update()
      return
    }

    withAnimation(resetAnimation) {
      update()
    }
  }

  private func resetPanState(animated: Bool) {
    let update = {
      offset = .zero
      lastOffset = .zero
    }

    guard animated else {
      update()
      return
    }

    withAnimation(resetAnimation) {
      update()
    }
  }

  private func anchor(from location: CGPoint) -> UnitPoint {
    guard screenSize.width > 0 && screenSize.height > 0 else {
      return .center
    }
    let normalizedX = min(max(location.x / screenSize.width, 0), 1)
    let normalizedY = min(max(location.y / screenSize.height, 0), 1)
    return UnitPoint(x: normalizedX, y: normalizedY)
  }

  private func clampOffset(animated: Bool) {
    if scale <= minScale {
      resetPanState(animated: animated)
      return
    }
    let bounded = metrics.clamp(offset)
    let update = {
      offset = bounded
      lastOffset = bounded
    }
    guard animated else {
      update()
      return
    }
    withAnimation(resetAnimation) {
      update()
    }
  }

  private func normalizeAnchor() {
    guard scaleAnchor != .center else { return }
    let shift = metrics.shift(for: scaleAnchor)
    scaleAnchor = .center
    offset = CGSize(
      width: offset.width + shift.width,
      height: offset.height + shift.height
    )
    lastOffset = CGSize(
      width: lastOffset.width + shift.width,
      height: lastOffset.height + shift.height
    )
  }

}

struct SizeReportingOverlay: View {
  let onChange: (CGSize) -> Void

  var body: some View {
    GeometryReader { proxy in
      Color.clear
        .onAppear {
          report(proxy.size)
        }
        .onChange(of: proxy.size) { _, newSize in
          report(newSize)
        }
    }
    .allowsHitTesting(false)
  }

  private func report(_ size: CGSize) {
    guard size.width > 0 && size.height > 0 else { return }
    onChange(size)
  }
}

struct ZoomableContentSizeOverlay: View {
  @Environment(\.zoomableContentSizeReporter) private var reportContentSize

  var body: some View {
    SizeReportingOverlay { size in
      reportContentSize(size)
    }
  }
}

private struct ZoomableContentSizeReporterKey: EnvironmentKey {
  static var defaultValue: (CGSize) -> Void = { _ in }
}

extension EnvironmentValues {
  var zoomableContentSizeReporter: (CGSize) -> Void {
    get { self[ZoomableContentSizeReporterKey.self] }
    set { self[ZoomableContentSizeReporterKey.self] = newValue }
  }
}

extension View {
  func reportSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
    background(SizeReportingOverlay(onChange: onChange))
  }

  func reportZoomableContentSize() -> some View {
    background(ZoomableContentSizeOverlay())
  }
}

private struct ZoomMetrics {
  private let contentSize: CGSize
  private let screenSize: CGSize
  private let scale: CGFloat
  private let overscrollFraction: CGFloat = 0.2

  init(contentSize: CGSize, screenSize: CGSize, scale: CGFloat) {
    self.contentSize = contentSize
    self.screenSize = screenSize
    self.scale = scale
  }

  private var horizontalAllowance: CGFloat {
    screenSize.width * overscrollFraction
  }

  private var verticalAllowance: CGFloat {
    screenSize.height * overscrollFraction
  }

  private var maxX: CGFloat {
    max((contentSize.width * scale - screenSize.width) / 2 + horizontalAllowance, 0)
  }

  private var maxY: CGFloat {
    max((contentSize.height * scale - screenSize.height) / 2 + verticalAllowance, 0)
  }

  func clamp(_ value: CGSize) -> CGSize {
    guard screenSize.width > 0 && screenSize.height > 0 else { return value }
    let clampedWidth = min(max(value.width, -maxX), maxX)
    let clampedHeight = min(max(value.height, -maxY), maxY)
    return CGSize(width: clampedWidth, height: clampedHeight)
  }

  func shift(for anchor: UnitPoint) -> CGSize {
    guard anchor != .center else { return .zero }
    let dx = (0.5 - anchor.x) * contentSize.width * (scale - 1)
    let dy = (0.5 - anchor.y) * contentSize.height * (scale - 1)
    return CGSize(width: dx, height: dy)
  }
}
