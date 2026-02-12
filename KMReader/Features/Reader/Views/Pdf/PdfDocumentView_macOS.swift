#if os(macOS)
  import PDFKit
  import SwiftUI

  struct PdfDocumentView: NSViewRepresentable {
    let documentURL: URL
    let pageLayout: PageLayout
    let isolateCoverPage: Bool
    let readingDirection: ReadingDirection
    let initialPageNumber: Int
    let targetPageNumber: Int?
    let navigationToken: UUID
    let onPageChange: (Int, Int) -> Void
    let onSingleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(
        onPageChange: onPageChange,
        onSingleTap: onSingleTap
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
      let direction = readingDirection
      let isContinuous = direction == .webtoon

      if coordinator.lastResolvedPageLayout == resolvedLayout,
        coordinator.lastResolvedReadingDirection == direction,
        coordinator.lastResolvedIsolateCoverPage == isolateCoverPage
      {
        return
      }

      let currentPage = pdfView.currentPage
      let displayMode: PDFDisplayMode

      switch (isContinuous, resolvedLayout) {
      case (true, .dual):
        displayMode = .twoUpContinuous
      case (true, .single):
        displayMode = .singlePageContinuous
      case (false, .dual):
        displayMode = .twoUp
      case (false, .single):
        displayMode = .singlePage
      default:
        displayMode = .singlePage
      }

      pdfView.displayMode = displayMode
      pdfView.displayDirection = (direction == .vertical || direction == .webtoon) ? .vertical : .horizontal
      pdfView.displaysRTL = direction == .rtl
      pdfView.displaysAsBook = resolvedLayout == .dual && !isContinuous && isolateCoverPage
      let minScale = minimumScale(for: pdfView)
      pdfView.minScaleFactor = minScale
      pdfView.maxScaleFactor = max(minScale * 8.0, minScale)

      coordinator.lastResolvedPageLayout = resolvedLayout
      coordinator.lastResolvedReadingDirection = direction
      coordinator.lastResolvedIsolateCoverPage = isolateCoverPage

      if let currentPage {
        pdfView.go(to: currentPage)
      }
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
      var loadedDocumentURL: URL?
      var lastNavigationToken: UUID?
      var lastResolvedPageLayout: PageLayout?
      var lastResolvedReadingDirection: ReadingDirection?
      var lastResolvedIsolateCoverPage: Bool?
      private weak var observedPDFView: PDFView?
      private weak var singleClickRecognizer: NSClickGestureRecognizer?

      init(
        onPageChange: @escaping (Int, Int) -> Void,
        onSingleTap: @escaping (CGPoint) -> Void
      ) {
        self.onPageChange = onPageChange
        self.onSingleTap = onSingleTap
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
        attachSingleClickRecognizer(to: pdfView)
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handlePageChanged),
          name: .PDFViewPageChanged,
          object: pdfView
        )
      }

      func refreshGestureRecognizers(on pdfView: PDFView) {
        attachSingleClickRecognizer(to: pdfView)
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

      @objc
      private func handlePageChanged() {
        guard let observedPDFView else { return }
        notifyCurrentPage(from: observedPDFView)
      }

      @objc
      private func handleSingleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let pdfView = recognizer.view as? PDFView else { return }
        let size = pdfView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let location = recognizer.location(in: pdfView)
        let normalizedPoint = CGPoint(
          x: max(0, min(1, location.x / size.width)),
          y: max(0, min(1, 1.0 - (location.y / size.height)))
        )
        onSingleTap(normalizedPoint)
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
    }
  }
#endif
