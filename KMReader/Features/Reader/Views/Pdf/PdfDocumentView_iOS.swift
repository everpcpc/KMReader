#if os(iOS)
  import PDFKit
  import SwiftUI

  struct PdfDocumentView: UIViewRepresentable {
    let documentURL: URL
    let pageLayout: PageLayout
    let pageTransitionStyle: PageTransitionStyle
    let readingDirection: ReadingDirection
    let doubleTapZoomScale: CGFloat
    let doubleTapZoomMode: DoubleTapZoomMode
    let initialPageNumber: Int
    let targetPageNumber: Int?
    let navigationToken: UUID
    let onPageChange: (Int, Int) -> Void
    let onSingleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(
        onPageChange: onPageChange,
        onSingleTap: onSingleTap,
        doubleTapZoomScale: doubleTapZoomScale,
        doubleTapZoomMode: doubleTapZoomMode
      )
    }

    func makeUIView(context: Context) -> PDFView {
      let pdfView = PDFView()
      pdfView.autoScales = true
      pdfView.displaysPageBreaks = false
      pdfView.backgroundColor = .clear

      applyPresentationConfiguration(to: pdfView, coordinator: context.coordinator)
      context.coordinator.bind(pdfView: pdfView)
      loadDocument(into: pdfView, coordinator: context.coordinator)
      return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
      context.coordinator.onPageChange = onPageChange
      context.coordinator.onSingleTap = onSingleTap
      context.coordinator.doubleTapZoomScale = doubleTapZoomScale
      context.coordinator.doubleTapZoomMode = doubleTapZoomMode
      context.coordinator.refreshGestureRecognizers(on: pdfView)

      applyPresentationConfiguration(to: pdfView, coordinator: context.coordinator)

      if context.coordinator.loadedDocumentURL != documentURL {
        loadDocument(into: pdfView, coordinator: context.coordinator)
      } else if context.coordinator.lastNavigationToken != navigationToken {
        context.coordinator.lastNavigationToken = navigationToken
        if let targetPageNumber {
          goToPage(targetPageNumber, in: pdfView)
        }
      }
    }

    private func loadDocument(into pdfView: PDFView, coordinator: Coordinator) {
      guard let document = PDFDocument(url: documentURL) else { return }

      pdfView.document = document
      coordinator.loadedDocumentURL = documentURL
      let minScale = minimumScale(for: pdfView)
      pdfView.minScaleFactor = minScale
      pdfView.maxScaleFactor = max(minScale * 8.0, minScale)

      if let page = document.page(at: max(0, min(initialPageNumber - 1, document.pageCount - 1))) {
        pdfView.go(to: page)
      }

      coordinator.lastNavigationToken = navigationToken
      coordinator.notifyCurrentPage(from: pdfView)
    }

    private func applyPresentationConfiguration(to pdfView: PDFView, coordinator: Coordinator) {
      let resolvedLayout = resolvedPageLayout(for: pdfView.bounds.size)
      let transitionStyle = resolvedTransitionStyle
      let direction = resolvedReadingDirection
      let isWebtoon = direction == .webtoon

      if coordinator.lastResolvedPageLayout == resolvedLayout,
        coordinator.lastResolvedTransitionStyle == transitionStyle,
        coordinator.lastResolvedReadingDirection == direction
      {
        return
      }

      let currentPage = pdfView.currentPage
      let displayMode: PDFDisplayMode
      let usesPageController: Bool
      switch (isWebtoon, resolvedLayout, transitionStyle) {
      case (true, _, _):
        displayMode = .singlePageContinuous
        usesPageController = false
      case (false, .dual, .scroll):
        displayMode = .twoUp
        usesPageController = false
      case (false, .single, .scroll):
        displayMode = .singlePage
        usesPageController = false
      case (false, .dual, .pageCurl):
        displayMode = .twoUp
        usesPageController = true
      case (false, .single, .pageCurl):
        displayMode = .singlePage
        usesPageController = true
      default:
        displayMode = .singlePage
        usesPageController = false
      }

      pdfView.displayMode = displayMode
      pdfView.displayDirection = (direction == .vertical || direction == .webtoon) ? .vertical : .horizontal
      pdfView.displaysRTL = direction == .rtl
      pdfView.displaysAsBook = resolvedLayout == .dual && !isWebtoon
      pdfView.usePageViewController(usesPageController, withViewOptions: nil)
      let minScale = minimumScale(for: pdfView)
      pdfView.minScaleFactor = minScale
      pdfView.maxScaleFactor = max(minScale * 8.0, minScale)

      coordinator.lastResolvedPageLayout = resolvedLayout
      coordinator.lastResolvedTransitionStyle = transitionStyle
      coordinator.lastResolvedReadingDirection = direction

      if let currentPage {
        pdfView.go(to: currentPage)
      }
    }

    private var resolvedTransitionStyle: PageTransitionStyle {
      PageTransitionStyle.availableCases.contains(pageTransitionStyle) ? pageTransitionStyle : .scroll
    }

    private var resolvedReadingDirection: ReadingDirection {
      readingDirection
    }

    private func resolvedPageLayout(for size: CGSize) -> PageLayout {
      guard pageLayout == .auto else {
        return pageLayout
      }

      let effectiveSize: CGSize = {
        guard size.width > 0, size.height > 0 else {
          return UIScreen.main.bounds.size
        }
        return size
      }()

      return effectiveSize.width > effectiveSize.height ? .dual : .single
    }

    private func goToPage(_ pageNumber: Int, in pdfView: PDFView) {
      guard let document = pdfView.document else { return }
      let index = max(0, min(pageNumber - 1, document.pageCount - 1))
      guard let page = document.page(at: index) else { return }
      pdfView.go(to: page)
    }

    private func minimumScale(for pdfView: PDFView) -> CGFloat {
      let fitScale = pdfView.scaleFactorForSizeToFit
      if fitScale > 0 {
        return fitScale
      }
      if pdfView.minScaleFactor > 0 {
        return pdfView.minScaleFactor
      }
      return 1.0
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var onPageChange: (Int, Int) -> Void
      var onSingleTap: (CGPoint) -> Void
      var doubleTapZoomScale: CGFloat
      var doubleTapZoomMode: DoubleTapZoomMode
      var loadedDocumentURL: URL?
      var lastNavigationToken: UUID?
      var lastResolvedPageLayout: PageLayout?
      var lastResolvedTransitionStyle: PageTransitionStyle?
      var lastResolvedReadingDirection: ReadingDirection?
      private weak var observedPDFView: PDFView?
      private weak var singleTapRecognizer: UITapGestureRecognizer?
      private weak var doubleTapRecognizer: UITapGestureRecognizer?
      private weak var longPressRecognizer: UILongPressGestureRecognizer?
      private var singleTapWorkItem: DispatchWorkItem?
      private var isLongPressing = false
      private var lastLongPressEndTime: Date = .distantPast
      private var lastTouchStartTime: Date = .distantPast
      private var lastSingleTapActionTime: Date = .distantPast
      private var lastZoomOutTime: Date = .distantPast

      init(
        onPageChange: @escaping (Int, Int) -> Void,
        onSingleTap: @escaping (CGPoint) -> Void,
        doubleTapZoomScale: CGFloat,
        doubleTapZoomMode: DoubleTapZoomMode
      ) {
        self.onPageChange = onPageChange
        self.onSingleTap = onSingleTap
        self.doubleTapZoomScale = doubleTapZoomScale
        self.doubleTapZoomMode = doubleTapZoomMode
        super.init()
      }

      deinit {
        NotificationCenter.default.removeObserver(self)
      }

      func bind(pdfView: PDFView) {
        if let observedPDFView {
          NotificationCenter.default.removeObserver(
            self,
            name: .PDFViewPageChanged,
            object: observedPDFView
          )
        }

        observedPDFView = pdfView
        attachDoubleTapRecognizer(to: pdfView)
        attachSingleTapRecognizer(to: pdfView)
        attachLongPressRecognizer(to: pdfView)
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handlePageChanged),
          name: .PDFViewPageChanged,
          object: pdfView
        )
      }

      func refreshGestureRecognizers(on pdfView: PDFView) {
        attachDoubleTapRecognizer(to: pdfView)
        attachSingleTapRecognizer(to: pdfView)
        attachLongPressRecognizer(to: pdfView)
      }

      private func attachDoubleTapRecognizer(to pdfView: PDFView) {
        guard doubleTapZoomMode != .disabled else {
          if let doubleTapRecognizer {
            doubleTapRecognizer.view?.removeGestureRecognizer(doubleTapRecognizer)
          }
          self.doubleTapRecognizer = nil
          return
        }

        if let doubleTapRecognizer {
          if doubleTapRecognizer.view !== pdfView {
            doubleTapRecognizer.view?.removeGestureRecognizer(doubleTapRecognizer)
            pdfView.addGestureRecognizer(doubleTapRecognizer)
          }
          return
        }

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        doubleTapRecognizer = recognizer
      }

      private func attachSingleTapRecognizer(to pdfView: PDFView) {
        if let singleTapRecognizer {
          if singleTapRecognizer.view !== pdfView {
            singleTapRecognizer.view?.removeGestureRecognizer(singleTapRecognizer)
            pdfView.addGestureRecognizer(singleTapRecognizer)
          }
          return
        }

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        recognizer.numberOfTapsRequired = 1
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        singleTapRecognizer = recognizer
      }

      private func attachLongPressRecognizer(to pdfView: PDFView) {
        if let longPressRecognizer {
          if longPressRecognizer.view !== pdfView {
            longPressRecognizer.view?.removeGestureRecognizer(longPressRecognizer)
            pdfView.addGestureRecognizer(longPressRecognizer)
          }
          return
        }

        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.5
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        longPressRecognizer = recognizer
      }

      @objc
      private func handlePageChanged() {
        guard let observedPDFView else { return }
        notifyCurrentPage(from: observedPDFView)
      }

      @objc
      private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()

        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && holdDuration < 0.3 else { return }
        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        guard let pdfView = recognizer.view as? PDFView else { return }
        if isZoomed(in: pdfView) { return }
        if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

        let location = recognizer.location(in: pdfView)
        let item = DispatchWorkItem { [weak self] in
          self?.performSingleTapAction(location: location, in: pdfView)
        }
        let delay = doubleTapZoomMode.tapDebounceDelay
        if delay > 0 {
          singleTapWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
          item.perform()
        }
      }

      @objc
      private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()
        if Date().timeIntervalSince(lastSingleTapActionTime) < 0.3 { return }

        guard let pdfView = recognizer.view as? PDFView else { return }
        let minimumScale = minimumScale(for: pdfView)

        if pdfView.scaleFactor > minimumScale + 0.01 {
          pdfView.autoScales = false
          pdfView.scaleFactor = minimumScale
          lastZoomOutTime = Date()
          return
        }

        let location = recognizer.location(in: pdfView)
        zoom(to: clampedZoomScale(for: pdfView), centeredAt: location, in: pdfView)
      }

      @objc
      private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      func notifyCurrentPage(from pdfView: PDFView) {
        guard let document = pdfView.document else {
          onPageChange(1, 0)
          return
        }

        let totalPages = document.pageCount
        guard totalPages > 0 else {
          onPageChange(1, 0)
          return
        }

        guard let currentPage = pdfView.currentPage else {
          onPageChange(1, totalPages)
          return
        }

        let pageNumber = document.index(for: currentPage) + 1
        onPageChange(max(1, pageNumber), totalPages)
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
        true
      }

      private func performSingleTapAction(location: CGPoint, in pdfView: PDFView) {
        let size = pdfView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        lastSingleTapActionTime = Date()
        let normalizedPoint = CGPoint(
          x: max(0, min(1, location.x / size.width)),
          y: max(0, min(1, location.y / size.height))
        )
        onSingleTap(normalizedPoint)
      }

      private func isZoomed(in pdfView: PDFView) -> Bool {
        pdfView.scaleFactor > minimumScale(for: pdfView) + 0.01
      }

      private func minimumScale(for pdfView: PDFView) -> CGFloat {
        let fitScale = pdfView.scaleFactorForSizeToFit
        if fitScale > 0 {
          return fitScale
        }
        if pdfView.minScaleFactor > 0 {
          return pdfView.minScaleFactor
        }
        return 1.0
      }

      private func clampedZoomScale(for pdfView: PDFView) -> CGFloat {
        let minimumScale = minimumScale(for: pdfView)
        let maximumScale = max(pdfView.maxScaleFactor, minimumScale)
        return min(max(doubleTapZoomScale, minimumScale), maximumScale)
      }

      private func zoom(to targetScale: CGFloat, centeredAt location: CGPoint, in pdfView: PDFView) {
        guard let page = pdfView.page(for: location, nearest: true) else {
          pdfView.autoScales = false
          pdfView.scaleFactor = targetScale
          return
        }

        let pagePoint = pdfView.convert(location, to: page)
        let visibleRect = pdfView.convert(pdfView.bounds, to: page)
        let currentScale = max(pdfView.scaleFactor, 0.01)
        let rawWidth = visibleRect.width * (currentScale / targetScale)
        let rawHeight = visibleRect.height * (currentScale / targetScale)
        let pageBounds = page.bounds(for: pdfView.displayBox)

        let targetSize = CGSize(
          width: min(max(rawWidth, 1.0), pageBounds.width),
          height: min(max(rawHeight, 1.0), pageBounds.height)
        )

        var originX = pagePoint.x - targetSize.width / 2
        var originY = pagePoint.y - targetSize.height / 2
        originX = min(max(originX, pageBounds.minX), pageBounds.maxX - targetSize.width)
        originY = min(max(originY, pageBounds.minY), pageBounds.maxY - targetSize.height)

        let targetRect = CGRect(origin: CGPoint(x: originX, y: originY), size: targetSize)
        pdfView.autoScales = false
        pdfView.scaleFactor = targetScale
        pdfView.go(to: targetRect, on: page)
      }
    }
  }
#endif
