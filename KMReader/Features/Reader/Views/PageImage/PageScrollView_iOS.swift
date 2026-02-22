#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  struct PageScrollView: UIViewRepresentable {
    var viewModel: ReaderViewModel
    let screenSize: CGSize
    let resetID: AnyHashable
    let minScale: CGFloat
    let maxScale: CGFloat
    let displayMode: PageDisplayMode
    let readingDirection: ReadingDirection
    let renderConfig: ReaderRenderConfig
    let initialZoomScale: CGFloat?
    let initialZoomAnchor: CGPoint?
    let initialZoomID: AnyHashable?

    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void

    let pages: [NativePageData]

    init(
      viewModel: ReaderViewModel,
      screenSize: CGSize,
      resetID: AnyHashable,
      minScale: CGFloat,
      maxScale: CGFloat,
      displayMode: PageDisplayMode = .fit,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      initialZoomScale: CGFloat? = nil,
      initialZoomAnchor: CGPoint? = nil,
      initialZoomID: AnyHashable? = nil,
      onNextPage: @escaping () -> Void,
      onPreviousPage: @escaping () -> Void,
      onToggleControls: @escaping () -> Void,
      pages: [NativePageData]
    ) {
      self.viewModel = viewModel
      self.screenSize = screenSize
      self.resetID = resetID
      self.minScale = minScale
      self.maxScale = maxScale
      self.displayMode = displayMode
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig
      self.initialZoomScale = initialZoomScale
      self.initialZoomAnchor = initialZoomAnchor
      self.initialZoomID = initialZoomID
      self.onNextPage = onNextPage
      self.onPreviousPage = onPreviousPage
      self.onToggleControls = onToggleControls
      self.pages = pages
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
      let scrollView = UIScrollView()
      scrollView.delegate = context.coordinator
      scrollView.minimumZoomScale = minScale
      scrollView.maximumZoomScale = maxScale
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.contentInsetAdjustmentBehavior = .never

      #if os(tvOS)
        scrollView.isScrollEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false
      #endif

      scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)

      let contentStack = UIStackView()
      contentStack.axis = .horizontal
      contentStack.distribution = .fillEqually
      contentStack.alignment = .fill
      contentStack.spacing = 0
      contentStack.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(contentStack)
      context.coordinator.contentStack = contentStack

      NSLayoutConstraint.activate([
        contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
      ])

      context.coordinator.parent = self
      context.coordinator.applyDisplayModeIfNeeded(in: scrollView)
      context.coordinator.setupNativeInteractions(on: scrollView)
      return scrollView
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
      coordinator.prepareForDismantle()
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
      context.coordinator.isUpdatingFromSwiftUI = true
      defer {
        DispatchQueue.main.async {
          context.coordinator.isUpdatingFromSwiftUI = false
          context.coordinator.applyInitialZoomIfNeeded(in: uiView)
        }
      }

      context.coordinator.parent = self
      context.coordinator.applyDisplayModeIfNeeded(in: uiView)
      context.coordinator.updatePages()

      uiView.backgroundColor = UIColor(renderConfig.readerBackground.color)

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
        context.coordinator.lastInitialZoomID = nil
        uiView.setZoomScale(minScale, animated: false)
        uiView.contentOffset = .zero
      }
    }

    @MainActor
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
      var lastResetID: AnyHashable?
      var lastInitialZoomID: AnyHashable?
      var lastDisplayMode: PageDisplayMode?
      var isUpdatingFromSwiftUI = false
      var isMenuVisible = false
      var isLongPressing = false
      var lastZoomOutTime: Date = .distantPast
      var lastLongPressEndTime: Date = .distantPast
      var lastTouchStartTime: Date = .distantPast
      var lastSingleTapActionTime: Date = .distantPast

      private var singleTapWorkItem: DispatchWorkItem?

      var parent: PageScrollView!

      weak var contentStack: UIStackView?
      var contentHeightConstraint: NSLayoutConstraint?
      private var pageViews: [NativePageItem] = []

      func prepareForDismantle() {
        pageViews.forEach { view in
          view.prepareForDismantle()
          view.removeFromSuperview()
        }
        pageViews.removeAll()
      }

      func updatePages() {
        guard let stack = contentStack else { return }
        let pages = parent.pages

        if pageViews.count != pages.count {
          pageViews.forEach { $0.removeFromSuperview() }
          pageViews = pages.map { _ in NativePageItem() }
          pageViews.forEach {
            stack.addArrangedSubview($0)
          }
        }

        for (index, data) in pages.enumerated() {
          let image = parent.viewModel.preloadedImages[data.pageNumber]
          let targetHeight = targetHeight(for: data, image: image)
          pageViews[index].update(
            with: data,
            viewModel: parent.viewModel,
            image: image,
            showPageNumber: parent.renderConfig.showPageNumber,
            enableLiveText: parent.renderConfig.enableLiveText,
            readingDirection: parent.readingDirection,
            displayMode: parent.displayMode,
            targetHeight: targetHeight
          )
        }

        contentStack?.semanticContentAttribute = parent.readingDirection == .rtl ? .forceRightToLeft : .forceLeftToRight
      }

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentStack
      }

      func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !isUpdatingFromSwiftUI else { return }

        let zoomed = scrollView.zoomScale > (parent.minScale + 0.01)
        if zoomed != parent.viewModel.isZoomed {
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.parent.viewModel.isZoomed != zoomed {
              self.parent.viewModel.isZoomed = zoomed
            }
          }
        }
      }

      func applyInitialZoomIfNeeded(in scrollView: UIScrollView) {
        guard let initialZoomID = parent.initialZoomID else { return }
        guard initialZoomID != lastInitialZoomID else { return }
        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }

        scrollView.layoutIfNeeded()
        let contentSize = scrollView.contentSize
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let scale = clampedScale(parent.initialZoomScale ?? parent.minScale)
        let baseAnchor = clampedAnchor(parent.initialZoomAnchor ?? CGPoint(x: 0.5, y: 0.5))
        let adjustedAnchor = clampedAnchor(adjustedAnchorForFillWidth(baseAnchor, contentSize: contentSize))
        let center = CGPoint(
          x: contentSize.width * adjustedAnchor.x,
          y: contentSize.height * adjustedAnchor.y
        )
        let zoomRect = calculateZoomRect(scale: scale, center: center, scrollView: scrollView)
        scrollView.zoom(to: zoomRect, animated: false)
        lastInitialZoomID = initialZoomID
      }

      func setupNativeInteractions(on scrollView: UIScrollView) {
        if parent.renderConfig.doubleTapZoomMode != .disabled {
          let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
          doubleTap.numberOfTapsRequired = 2
          doubleTap.delegate = self
          scrollView.addGestureRecognizer(doubleTap)
        }

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.delegate = self
        singleTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delegate = self
        longPress.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(longPress)
      }

      func applyDisplayModeIfNeeded(in scrollView: UIScrollView) {
        guard let stack = contentStack else { return }
        guard lastDisplayMode != parent.displayMode else { return }

        lastDisplayMode = parent.displayMode
        contentHeightConstraint?.isActive = false
        contentHeightConstraint = nil

        switch parent.displayMode {
        case .fit:
          stack.alignment = .fill
          stack.distribution = .fillEqually
          contentHeightConstraint = stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        case .fillWidth:
          stack.alignment = .top
          stack.distribution = .fill
          contentHeightConstraint = stack.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
          )
        }

        contentHeightConstraint?.isActive = true
      }

      private func targetHeight(for data: NativePageData, image: PlatformImage?) -> CGFloat {
        guard parent.displayMode == .fillWidth else { return parent.screenSize.height }
        let width = parent.screenSize.width
        guard width > 0 else { return parent.screenSize.height }

        if let image = image {
          let imageSize = image.size
          if imageSize.width > 0, imageSize.height > 0 {
            let height = width * imageSize.height / imageSize.width
            if height.isFinite && height > 0 {
              return height
            }
          }
        }

        if let page = parent.viewModel.pages.first(where: { $0.number == data.pageNumber }),
          let pageWidth = page.width,
          let pageHeight = page.height,
          pageWidth > 0,
          pageHeight > 0
        {
          let height = width * CGFloat(pageHeight) / CGFloat(pageWidth)
          if height.isFinite && height > 0 {
            return height
          }
        }

        return parent.screenSize.height
      }

      @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()
        if Date().timeIntervalSince(lastSingleTapActionTime) < 0.3 { return }
        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > parent.minScale + 0.01 {
          scrollView.setZoomScale(parent.minScale, animated: true)
          lastZoomOutTime = Date()
        } else {
          let point = gesture.location(in: contentStack)
          let zoomRect = calculateZoomRect(
            scale: CGFloat(parent.renderConfig.doubleTapZoomScale),
            center: point,
            scrollView: scrollView
          )
          scrollView.zoom(to: zoomRect, animated: true)
        }
      }

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()

        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && !isMenuVisible && holdDuration < 0.3 else { return }

        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > parent.minScale + 0.01 { return }
        if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

        let location = gesture.location(in: scrollView)

        let item = DispatchWorkItem { [weak self] in
          self?.performSingleTapAction(location: location)
        }
        let delay = parent.renderConfig.doubleTapZoomMode.tapDebounceDelay

        if delay > 0 {
          singleTapWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
          // Execute immediately if disabled
          item.perform()
        }
      }

      private func performSingleTapAction(location: CGPoint) {
        lastSingleTapActionTime = Date()
        let normalizedX = location.x / parent.screenSize.width
        let normalizedY = location.y / parent.screenSize.height

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: parent.renderConfig.tapZoneMode,
          readingDirection: parent.readingDirection,
          zoneThreshold: parent.renderConfig.tapZoneSize.value
        )

        switch action {
        case .previous:
          parent.onPreviousPage()
        case .next:
          parent.onNextPage()
        case .toggleControls:
          parent.onToggleControls()
        }
      }

      func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        lastTouchStartTime = Date()
        if let view = touch.view, view is UIControl {
          return false
        }
        return true
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        return true
      }

      private func calculateZoomRect(scale: CGFloat, center: CGPoint, scrollView: UIScrollView) -> CGRect {
        let width = scrollView.frame.size.width / scale
        let height = scrollView.frame.size.height / scale
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
      }

      private func clampedScale(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite else { return parent.minScale }
        return min(max(scale, parent.minScale), parent.maxScale)
      }

      private func clampedAnchor(_ anchor: CGPoint) -> CGPoint {
        let x = min(max(anchor.x, 0), 1)
        let y = min(max(anchor.y, 0), 1)
        return CGPoint(x: x, y: y)
      }

      private func adjustedAnchorForFillWidth(_ anchor: CGPoint, contentSize: CGSize) -> CGPoint {
        guard parent.displayMode == .fillWidth else { return anchor }
        guard let data = parent.pages.first else { return anchor }
        let image = parent.viewModel.preloadedImages[data.pageNumber]
        let imageHeight = targetHeight(for: data, image: image)
        guard imageHeight > 0, contentSize.height > 0, imageHeight < contentSize.height else { return anchor }
        let adjustedY = anchor.y * (imageHeight / contentSize.height)
        return CGPoint(x: anchor.x, y: adjustedY)
      }
    }
  }

#endif
