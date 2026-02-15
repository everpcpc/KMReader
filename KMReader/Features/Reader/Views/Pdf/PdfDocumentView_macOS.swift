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

      let clampedInitialPage = max(1, min(initialPageNumber, max(1, document.pageCount)))
      goToPage(clampedInitialPage, in: pdfView)
      coordinator.lastKnownPageNumber = clampedInitialPage

      coordinator.lastNavigationToken = navigationToken
      coordinator.notifyCurrentPage(from: pdfView)

      scheduleInitialPageCorrection(
        targetPage: clampedInitialPage,
        in: pdfView,
        coordinator: coordinator
      )
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
      let currentPageNumberBeforeConfiguration = currentPageNumber(in: pdfView)
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

      coordinator.lastResolvedPageLayout = resolvedLayout
      coordinator.lastResolvedReadingDirection = direction
      coordinator.lastResolvedIsolateCoverPage = isolateCoverPage

      if let currentPage {
        if currentPageNumber(in: pdfView) != currentPageNumberBeforeConfiguration {
          pdfView.go(to: currentPage)
        }
      } else if pdfView.document != nil {
        let fallbackPage = coordinator.lastKnownPageNumber > 0 ? coordinator.lastKnownPageNumber : initialPageNumber
        goToPage(fallbackPage, in: pdfView)
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

    private func scheduleInitialPageCorrection(
      targetPage: Int,
      in pdfView: PDFView,
      coordinator: Coordinator
    ) {
      // In continuous mode, PDFKit may reset current page multiple times
      // during initial layout; retry briefly until the target page sticks.
      let retryDelays: [TimeInterval] = [0.0, 0.05, 0.2, 0.5]
      for delay in retryDelays {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak pdfView, weak coordinator] in
          guard let pdfView, let coordinator else { return }
          guard coordinator.loadedDocumentURL == documentURL else { return }
          if currentPageNumber(in: pdfView) != targetPage {
            goToPage(targetPage, in: pdfView)
          }
          coordinator.notifyCurrentPage(from: pdfView)
        }
      }
    }

    private func currentPageNumber(in pdfView: PDFView) -> Int? {
      guard let document = pdfView.document else { return nil }
      guard let page = pdfView.currentPage else { return nil }
      return document.index(for: page) + 1
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
      var onPageChange: (Int, Int) -> Void
      var onSingleTap: (CGPoint) -> Void
      var loadedDocumentURL: URL?
      var lastNavigationToken: UUID?
      var lastResolvedPageLayout: PageLayout?
      var lastResolvedReadingDirection: ReadingDirection?
      var lastResolvedIsolateCoverPage: Bool?
      var lastKnownPageNumber: Int = 1
      private weak var observedPDFView: PDFView?
      private weak var singleClickRecognizer: NSClickGestureRecognizer?
      private weak var doubleClickRecognizer: NSClickGestureRecognizer?
      private weak var longPressRecognizer: NSPressGestureRecognizer?
      private var singleClickWorkItem: DispatchWorkItem?
      private var lastLongPressEndTime: Date = .distantPast
      private var lastDoubleClickTime: Date = .distantPast
      private var isLongPressing = false
      private var hadSelectionAtClickStart = false

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
        attachRecognizers(to: pdfView)
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handlePageChanged),
          name: .PDFViewPageChanged,
          object: pdfView
        )
      }

      func refreshGestureRecognizers(on pdfView: PDFView) {
        attachRecognizers(to: pdfView)
      }

      private func attachRecognizers(to pdfView: PDFView) {
        if let existingDoubleClickRecognizer = doubleClickRecognizer {
          if existingDoubleClickRecognizer.view !== pdfView {
            existingDoubleClickRecognizer.view?.removeGestureRecognizer(existingDoubleClickRecognizer)
            pdfView.addGestureRecognizer(existingDoubleClickRecognizer)
          }
        } else {
          let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
          recognizer.numberOfClicksRequired = 2
          recognizer.delegate = self
          pdfView.addGestureRecognizer(recognizer)
          doubleClickRecognizer = recognizer
        }

        if let existingLongPressRecognizer = longPressRecognizer {
          if existingLongPressRecognizer.view !== pdfView {
            existingLongPressRecognizer.view?.removeGestureRecognizer(existingLongPressRecognizer)
            pdfView.addGestureRecognizer(existingLongPressRecognizer)
          }
        } else {
          let recognizer = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
          recognizer.minimumPressDuration = 0.5
          recognizer.delegate = self
          pdfView.addGestureRecognizer(recognizer)
          longPressRecognizer = recognizer
        }

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
      private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        singleClickWorkItem?.cancel()
        lastDoubleClickTime = Date()
      }

      @objc
      private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc
      private func handleSingleClick(_ recognizer: NSClickGestureRecognizer) {
        singleClickWorkItem?.cancel()
        guard !isLongPressing else { return }
        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }
        if Date().timeIntervalSince(lastDoubleClickTime) < 0.35 { return }

        guard let pdfView = recognizer.view as? PDFView else { return }
        if hadSelectionAtClickStart || pdfView.currentSelection != nil {
          hadSelectionAtClickStart = false
          return
        }

        let size = pdfView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let location = recognizer.location(in: pdfView)
        let normalizedPoint = CGPoint(
          x: max(0, min(1, location.x / size.width)),
          y: max(0, min(1, 1.0 - (location.y / size.height)))
        )

        let item = DispatchWorkItem { [weak self] in
          self?.onSingleTap(normalizedPoint)
        }
        singleClickWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
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
        lastKnownPageNumber = max(1, pageNumber)
        onPageChange(max(1, pageNumber), totalPages)
      }

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        true
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer === singleClickRecognizer || gestureRecognizer === doubleClickRecognizer {
          hadSelectionAtClickStart = (observedPDFView?.currentSelection != nil)
        }
        return true
      }
    }
  }
#endif
