#if os(macOS)
  import PDFKit
  import SwiftUI

  struct PdfDocumentView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> PDFView {
      let pdfView = PDFView()
      pdfView.autoScales = true
      pdfView.displaysPageBreaks = false
      pdfView.backgroundColor = .clear

      applyPresentationConfiguration(to: pdfView, coordinator: context.coordinator)
      context.coordinator.bind(pdfView: pdfView)
      loadDocument(into: pdfView, coordinator: context.coordinator)
      return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
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

      switch (isWebtoon, resolvedLayout, transitionStyle) {
      case (true, _, _):
        displayMode = .singlePageContinuous
      case (false, .dual, _):
        displayMode = .twoUp
      case (false, .single, _):
        displayMode = .singlePage
      default:
        displayMode = .singlePage
      }

      pdfView.displayMode = displayMode
      pdfView.displayDirection = (direction == .vertical || direction == .webtoon) ? .vertical : .horizontal
      pdfView.displaysRTL = direction == .rtl
      pdfView.displaysAsBook = resolvedLayout == .dual && !isWebtoon
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

      guard size.width > 0, size.height > 0 else {
        return .single
      }

      return size.width > size.height ? .dual : .single
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

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
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
      private weak var singleClickRecognizer: NSClickGestureRecognizer?
      private weak var doubleClickRecognizer: NSClickGestureRecognizer?
      private weak var pressRecognizer: NSPressGestureRecognizer?
      private var singleClickWorkItem: DispatchWorkItem?
      private var isLongPressing = false
      private var lastLongPressEndTime: Date = .distantPast
      private var lastSingleClickActionTime: Date = .distantPast
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
        attachDoubleClickRecognizer(to: pdfView)
        attachSingleClickRecognizer(to: pdfView)
        attachPressRecognizer(to: pdfView)
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handlePageChanged),
          name: .PDFViewPageChanged,
          object: pdfView
        )
      }

      func refreshGestureRecognizers(on pdfView: PDFView) {
        attachDoubleClickRecognizer(to: pdfView)
        attachSingleClickRecognizer(to: pdfView)
        attachPressRecognizer(to: pdfView)
      }

      private func attachDoubleClickRecognizer(to pdfView: PDFView) {
        guard doubleTapZoomMode != .disabled else {
          if let doubleClickRecognizer {
            doubleClickRecognizer.view?.removeGestureRecognizer(doubleClickRecognizer)
          }
          self.doubleClickRecognizer = nil
          return
        }

        if let doubleClickRecognizer {
          if doubleClickRecognizer.view !== pdfView {
            doubleClickRecognizer.view?.removeGestureRecognizer(doubleClickRecognizer)
            pdfView.addGestureRecognizer(doubleClickRecognizer)
          }
          return
        }

        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        doubleClickRecognizer = recognizer
      }

      private func attachSingleClickRecognizer(to pdfView: PDFView) {
        if let singleClickRecognizer {
          if singleClickRecognizer.view !== pdfView {
            singleClickRecognizer.view?.removeGestureRecognizer(singleClickRecognizer)
            pdfView.addGestureRecognizer(singleClickRecognizer)
          }
          return
        }

        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleSingleClick(_:)))
        recognizer.numberOfClicksRequired = 1
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        singleClickRecognizer = recognizer
      }

      private func attachPressRecognizer(to pdfView: PDFView) {
        if let pressRecognizer {
          if pressRecognizer.view !== pdfView {
            pressRecognizer.view?.removeGestureRecognizer(pressRecognizer)
            pdfView.addGestureRecognizer(pressRecognizer)
          }
          return
        }

        let recognizer = NSPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        recognizer.minimumPressDuration = 0.5
        recognizer.delegate = self
        pdfView.addGestureRecognizer(recognizer)
        pressRecognizer = recognizer
      }

      @objc
      private func handlePageChanged() {
        guard let observedPDFView else { return }
        notifyCurrentPage(from: observedPDFView)
      }

      @objc
      private func handleSingleClick(_ recognizer: NSClickGestureRecognizer) {
        singleClickWorkItem?.cancel()

        guard let view = recognizer.view else { return }
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        guard !isLongPressing else { return }
        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }
        guard let pdfView = recognizer.view as? PDFView else { return }
        if isZoomed(in: pdfView) { return }
        if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

        let location = recognizer.location(in: view)
        let item = DispatchWorkItem { [weak self] in
          self?.performSingleClickAction(location: location, in: pdfView)
        }
        let delay = doubleTapZoomMode.tapDebounceDelay
        if delay > 0 {
          singleClickWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
          item.perform()
        }
      }

      @objc
      private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        singleClickWorkItem?.cancel()
        if Date().timeIntervalSince(lastSingleClickActionTime) < 0.3 { return }
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
      private func handlePress(_ gesture: NSPressGestureRecognizer) {
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

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        true
      }

      private func performSingleClickAction(location: CGPoint, in pdfView: PDFView) {
        let size = pdfView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        lastSingleClickActionTime = Date()
        let normalizedPoint = CGPoint(
          x: max(0, min(1, location.x / size.width)),
          y: max(0, min(1, 1.0 - (location.y / size.height)))
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
