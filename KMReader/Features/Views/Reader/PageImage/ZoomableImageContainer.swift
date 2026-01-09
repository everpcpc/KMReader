//
//  ZoomableImageContainer.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Shared zoom/pan container powered by UIScrollView for smooth gestures on iOS
// Uses NSScrollView on macOS
struct ZoomableImageContainer<Content: View>: View {
  let screenSize: CGSize
  let resetID: AnyHashable
  let minScale: CGFloat
  let maxScale: CGFloat
  let doubleTapScale: CGFloat
  @Binding var isZoomed: Bool
  @ViewBuilder private let content: () -> Content

  init(
    screenSize: CGSize,
    resetID: AnyHashable,
    minScale: CGFloat = 1.0,
    maxScale: CGFloat = 8.0,
    doubleTapScale: CGFloat = 2.0,
    isZoomed: Binding<Bool> = .constant(false),
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.screenSize = screenSize
    self.resetID = resetID
    self.minScale = minScale
    self.maxScale = maxScale
    self.doubleTapScale = doubleTapScale
    self._isZoomed = isZoomed
    self.content = content
  }

  var body: some View {
#if os(iOS)
    ZoomableScrollViewRepresentable(
      resetID: resetID,
      minScale: minScale,
      maxScale: maxScale,
      doubleTapScale: doubleTapScale,
      isZoomed: $isZoomed,
      content: content
    )
    .frame(width: screenSize.width, height: screenSize.height)
#else
    // tvOS and macOS do not support zooming, so we just show the content
    content()
      .frame(width: screenSize.width, height: screenSize.height)
#endif
  }
}

#if os(iOS)
  import UIKit

  private struct ZoomableScrollViewRepresentable<Content: View>: UIViewRepresentable {
    typealias UIViewType = UIScrollView

    let resetID: AnyHashable
    let minScale: CGFloat
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    var isZoomed: Binding<Bool>
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
      let scrollView = UIScrollView()
      scrollView.delegate = context.coordinator
      context.coordinator.scrollView = scrollView
      scrollView.minimumZoomScale = minScale
      scrollView.maximumZoomScale = max(maxScale * 1.5, maxScale)
      scrollView.bouncesZoom = true
      scrollView.bounces = true
      scrollView.clipsToBounds = true
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.backgroundColor = .clear

      let hostedView = context.coordinator.hostingController.view!
      hostedView.translatesAutoresizingMaskIntoConstraints = false
      hostedView.backgroundColor = .clear
      scrollView.addSubview(hostedView)

      NSLayoutConstraint.activate([
        hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        hostedView.widthAnchor.constraint(
          greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
        hostedView.heightAnchor.constraint(
          greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
      ])

      context.coordinator.attachDoubleTapRecognizer(to: scrollView)
      context.coordinator.centerContentIfNeeded(scrollView)
      return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.scrollView = scrollView
      context.coordinator.updateContent(with: content())
      scrollView.minimumZoomScale = minScale
      scrollView.maximumZoomScale = max(maxScale * 1.5, maxScale)

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
        context.coordinator.resetZoom(in: scrollView, animated: false)
      }

      context.coordinator.updateZoomState(for: scrollView)
      if scrollView.zoomScale <= minScale + 0.01 {
        context.coordinator.resetOffsetIfNeeded(for: scrollView)
      }
      context.coordinator.updateScrollEnabled(for: scrollView)
      context.coordinator.centerContentIfNeeded(scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
      var parent: ZoomableScrollViewRepresentable
      let hostingController: UIHostingController<AnyView>
      var lastResetID: AnyHashable?
      weak var scrollView: UIScrollView?

      init(parent: ZoomableScrollViewRepresentable) {
        self.parent = parent
        self.hostingController = UIHostingController(rootView: AnyView(parent.content()))
        self.hostingController.view.backgroundColor = .clear
      }

      func updateContent(with view: Content) {
        hostingController.rootView = AnyView(view)
        hostingController.view.setNeedsLayout()
      }

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        hostingController.view
      }

      func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContentIfNeeded(scrollView)
        updateZoomState(for: scrollView)
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
        centerContentIfNeeded(scrollView)
      }

      func scrollViewDidEndZooming(
        _ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat
      ) {
        clampScaleIfNeeded(for: scrollView, currentScale: scale)
      }

      func resetZoom(in scrollView: UIScrollView, animated: Bool) {
        scrollView.setZoomScale(parent.minScale, animated: animated)
        scrollView.setContentOffset(.zero, animated: animated)
        centerContentIfNeeded(scrollView)
        updateZoomState(for: scrollView)
      }

      func updateZoomState(for scrollView: UIScrollView) {
        let zoomed = scrollView.zoomScale > (parent.minScale + 0.01)
        guard parent.isZoomed.wrappedValue != zoomed else { return }
        DispatchQueue.main.async { [weak self] in
          self?.parent.isZoomed.wrappedValue = zoomed
        }
        if !zoomed {
          resetOffsetIfNeeded(for: scrollView)
        }
        updateScrollEnabled(for: scrollView)
      }

      func centerContentIfNeeded(_ scrollView: UIScrollView) {
        let horizontalInset = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let verticalInset = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(
          top: verticalInset,
          left: horizontalInset,
          bottom: verticalInset,
          right: horizontalInset
        )
      }

      func resetOffsetIfNeeded(for scrollView: UIScrollView) {
        guard scrollView.contentOffset != .zero else { return }
        scrollView.setContentOffset(.zero, animated: false)
      }

      func updateScrollEnabled(for scrollView: UIScrollView) {
        let zoomed = scrollView.zoomScale > (parent.minScale + 0.01)
        if zoomed {
          scrollView.isScrollEnabled = true
          return
        }

        let canScrollHorizontally = scrollView.contentSize.width > scrollView.bounds.width + 1
        let canScrollVertically = scrollView.contentSize.height > scrollView.bounds.height + 1
        scrollView.isScrollEnabled = canScrollHorizontally || canScrollVertically
      }

      func clampScaleIfNeeded(for scrollView: UIScrollView, currentScale: CGFloat) {
        var target = currentScale
        if currentScale < parent.minScale {
          target = parent.minScale
        } else if currentScale > parent.maxScale {
          target = parent.maxScale
        }
        guard abs(target - currentScale) > .ulpOfOne else { return }
        scrollView.setZoomScale(target, animated: true)
      }

      func attachDoubleTapRecognizer(to scrollView: UIScrollView) {
        let recognizer = UITapGestureRecognizer(
          target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(recognizer)
      }

      @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let scrollView = recognizer.view as? UIScrollView else { return }
        if scrollView.zoomScale > parent.minScale + 0.01 {
          scrollView.setZoomScale(parent.minScale, animated: true)
        } else {
          let targetScale = min(parent.maxScale, parent.doubleTapScale)
          let point = recognizer.location(in: hostingController.view)
          zoom(to: point, scale: targetScale, in: scrollView)
        }
      }

      private func zoom(to point: CGPoint, scale: CGFloat, in scrollView: UIScrollView) {
        let zoomRect = CGRect(
          x: point.x - scrollView.bounds.size.width / (scale * 2),
          y: point.y - scrollView.bounds.size.height / (scale * 2),
          width: scrollView.bounds.size.width / scale,
          height: scrollView.bounds.size.height / scale
        )
        scrollView.zoom(to: zoomRect, animated: true)
      }
    }
  }

#endif
