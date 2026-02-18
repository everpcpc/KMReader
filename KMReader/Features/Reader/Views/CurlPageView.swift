//
//  CurlPageView.swift
//  KMReader
//
//  UIPageViewController wrapper for pageCurl transition effect (iOS only)
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct CurlPageView: UIViewControllerRepresentable {
    @Bindable var viewModel: ReaderViewModel
    let mode: PageViewMode
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let previousBook: Book?
    let nextBook: Book?
    let readList: ReadList?
    let onDismiss: () -> Void
    let onPreviousBook: (String) -> Void
    let onNextBook: (String) -> Void
    let goToNextPage: () -> Void
    let goToPreviousPage: () -> Void
    let toggleControls: () -> Void
    let onPlayAnimatedPage: ((Int) -> Void)?
    let onBoundaryPanUpdate: ((CGFloat) -> Void)?

    @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
    @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
      let spineLocation: UIPageViewController.SpineLocation = mode.isRTL ? .max : .min
      let pageVC = UIPageViewController(
        transitionStyle: .pageCurl,
        navigationOrientation: mode.isVertical ? .vertical : .horizontal,
        options: [.spineLocation: NSNumber(value: spineLocation.rawValue)]
      )
      context.coordinator.pageViewController = pageVC
      pageVC.dataSource = context.coordinator
      pageVC.delegate = context.coordinator

      // Allow simultaneous gesture recognition for zoom transition return gesture
      for recognizer in pageVC.gestureRecognizers {
        recognizer.delegate = context.coordinator
        if recognizer is UITapGestureRecognizer {
          recognizer.isEnabled = false
        }
      }

      let boundaryPanRecognizer = UIPanGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleBoundaryPan(_:))
      )
      boundaryPanRecognizer.cancelsTouchesInView = false
      boundaryPanRecognizer.delegate = context.coordinator
      pageVC.view.addGestureRecognizer(boundaryPanRecognizer)
      context.coordinator.boundaryPanRecognizer = boundaryPanRecognizer
      // isDoubleSided requires 2 VCs for animated transitions which complicates the logic
      // For single-page curl effect, keep it false
      pageVC.isDoubleSided = false

      // Match page curl direction to reading order
      pageVC.view.semanticContentAttribute = mode.isRTL ? .forceRightToLeft : .forceLeftToRight

      // Set initial page (non-animated, so single VC is fine)
      let initialIndex = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      context.coordinator.currentPageIndex = initialIndex
      Task { @MainActor in
        viewModel.updateCurrentPosition(viewItemIndex: initialIndex)
      }

      if let initialVC = context.coordinator.pageViewController(for: initialIndex) {
        pageVC.setViewControllers(
          [initialVC],
          direction: .forward,
          animated: false
        )
      }

      return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
      context.coordinator.parent = self
      context.coordinator.pageViewController = pageVC
      context.coordinator.syncCurrentPageIndexWithVisibleController()

      let targetViewItemIndex: Int? = {
        if let explicitTarget = viewModel.targetViewItemIndex {
          return explicitTarget
        }
        if let targetPageIndex = viewModel.targetPageIndex {
          return viewModel.viewItemIndex(forPageIndex: targetPageIndex)
        }
        return nil
      }()

      guard let targetViewItemIndex else { return }

      let clearTargets: () -> Void = {
        _ = Task { @MainActor in
          viewModel.targetViewItemIndex = nil
          viewModel.targetPageIndex = nil
        }
      }

      guard targetViewItemIndex != context.coordinator.currentPageIndex else {
        clearTargets()
        return
      }

      guard let targetVC = context.coordinator.pageViewController(for: targetViewItemIndex) else {
        clearTargets()
        return
      }

      guard !context.coordinator.isTransitioning else { return }

      let direction: UIPageViewController.NavigationDirection
      if mode.isRTL {
        direction = targetViewItemIndex > context.coordinator.currentPageIndex ? .reverse : .forward
      } else {
        direction = targetViewItemIndex > context.coordinator.currentPageIndex ? .forward : .reverse
      }

      context.coordinator.isTransitioning = true
      pageVC.setViewControllers(
        [targetVC],
        direction: direction,
        animated: true
      ) { completed in
        Task { @MainActor in
          context.coordinator.isTransitioning = false
          context.coordinator.syncCurrentPageIndexWithVisibleController()
          if completed {
            viewModel.updateCurrentPosition(viewItemIndex: context.coordinator.currentPageIndex)
          }
          viewModel.targetViewItemIndex = nil
          viewModel.targetPageIndex = nil
        }
      }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
      UIGestureRecognizerDelegate
    {
      var parent: CurlPageView
      var currentPageIndex: Int
      weak var pageViewController: UIPageViewController?
      weak var boundaryPanRecognizer: UIPanGestureRecognizer?
      var isTransitioning = false
      private let boundarySwipeThreshold: CGFloat = 120
      private var hasTriggeredBoundaryHaptic = false

      init(_ parent: CurlPageView) {
        self.parent = parent
        self.currentPageIndex = parent.viewModel.currentViewItemIndex
      }

      // Total page count including end page
      var totalPages: Int {
        parent.viewModel.viewItems.count
      }

      func pageViewController(for index: Int) -> UIViewController? {
        guard index >= 0 && index < totalPages else { return nil }

        // Safety check: ensure we have pages loaded
        guard !parent.viewModel.pages.isEmpty else { return nil }

        let hostingController: UIHostingController<AnyView>

        let item = parent.viewModel.viewItems[index]

        switch item {
        case .end:
          let endPageView = EndPageView(
            viewModel: parent.viewModel,
            nextBook: parent.nextBook,
            readList: parent.readList,
            onDismiss: parent.onDismiss,
            onNextBook: parent.onNextBook,
            readingDirection: parent.readingDirection,
            showImage: true
          )
          hostingController = UIHostingController(rootView: AnyView(endPageView))
        case .dual(let first, _):
          let pageView = CurlSinglePageView(
            viewModel: parent.viewModel,
            pageIndex: first,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode,
            onNextPage: parent.goToNextPage,
            onPreviousPage: parent.goToPreviousPage,
            onToggleControls: parent.toggleControls,
            onPlayAnimatedPage: parent.onPlayAnimatedPage
          )
          hostingController = UIHostingController(rootView: AnyView(pageView))
        case .page(let index):
          let pageView = CurlSinglePageView(
            viewModel: parent.viewModel,
            pageIndex: index,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode,
            onNextPage: parent.goToNextPage,
            onPreviousPage: parent.goToPreviousPage,
            onToggleControls: parent.toggleControls,
            onPlayAnimatedPage: parent.onPlayAnimatedPage
          )
          hostingController = UIHostingController(rootView: AnyView(pageView))
        case .split(let index, let isFirstHalf):
          let isLeftHalf = parent.viewModel.isLeftSplitHalf(
            isFirstHalf: isFirstHalf,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode
          )
          let splitPageView = CurlSinglePageView(
            viewModel: parent.viewModel,
            pageIndex: index,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode,
            isLeftHalf: isLeftHalf,
            onNextPage: parent.goToNextPage,
            onPreviousPage: parent.goToPreviousPage,
            onToggleControls: parent.toggleControls,
            onPlayAnimatedPage: parent.onPlayAnimatedPage
          )
          hostingController = UIHostingController(rootView: AnyView(splitPageView))
        }

        hostingController.view.tag = index
        return hostingController
      }

      // MARK: - UIPageViewControllerDataSource

      // For pageCurl, "before" = page spatially on the left, "after" = page on the right
      // In LTR: left = previous page (index - 1), right = next page (index + 1)
      // In RTL: left = next page (index + 1), right = previous page (index - 1)

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
      ) -> UIViewController? {
        let index = viewController.view.tag
        // "before" = page on the left side
        let targetIndex = parent.mode.isRTL ? index + 1 : index - 1
        if !isValidIndex(targetIndex) { return nil }
        return self.pageViewController(for: targetIndex)
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
      ) -> UIViewController? {
        let index = viewController.view.tag
        // "after" = page on the right side
        let targetIndex = parent.mode.isRTL ? index - 1 : index + 1
        if !isValidIndex(targetIndex) { return nil }
        return self.pageViewController(for: targetIndex)
      }

      // MARK: - UIPageViewControllerDelegate

      func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]
      ) {
        isTransitioning = true
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
      ) {
        isTransitioning = false
        syncCurrentPageIndexWithVisibleController()
        guard completed,
          let currentVC = pageViewController.viewControllers?.first
        else { return }

        let newIndex = currentVC.view.tag
        currentPageIndex = newIndex

        Task { @MainActor in
          parent.viewModel.updateCurrentPosition(viewItemIndex: newIndex)
          await parent.viewModel.updateProgress()
          await parent.viewModel.preloadPages()
        }
      }

      // MARK: - UIGestureRecognizerDelegate

      private func isValidIndex(_ index: Int) -> Bool {
        index >= 0 && index < totalPages
      }

      private func visiblePageIndex() -> Int? {
        guard let index = pageViewController?.viewControllers?.first?.view.tag else { return nil }
        guard isValidIndex(index) else { return nil }
        return index
      }

      func syncCurrentPageIndexWithVisibleController() {
        if let visibleIndex = visiblePageIndex() {
          currentPageIndex = visibleIndex
        }
      }

      private func beforeIndex(from index: Int) -> Int {
        parent.mode.isRTL ? index + 1 : index - 1
      }

      private func afterIndex(from index: Int) -> Int {
        parent.mode.isRTL ? index - 1 : index + 1
      }

      private func primaryTranslation(for pan: UIPanGestureRecognizer) -> CGFloat {
        let translation = pan.translation(in: pan.view)
        return parent.mode.isVertical ? translation.y : translation.x
      }

      private func primaryVelocity(for pan: UIPanGestureRecognizer) -> CGFloat {
        let velocity = pan.velocity(in: pan.view)
        return parent.mode.isVertical ? velocity.y : velocity.x
      }

      private func isBackwardSignal(_ signal: CGFloat) -> Bool {
        parent.readingDirection.isBackwardSwipe(signal)
      }

      private func isForwardSignal(_ signal: CGFloat) -> Bool {
        parent.readingDirection.isForwardSwipe(signal)
      }

      private enum BoundaryNavigationAction {
        case openPrevious(String)
        case openNext(String)
      }

      private var isAtFirstBoundary: Bool {
        currentPageIndex == 0
      }

      private var isAtEndBoundary: Bool {
        guard totalPages > 0 else { return false }
        return currentPageIndex == totalPages - 1
      }

      private var hasBoundarySwipeContext: Bool {
        (isAtFirstBoundary && parent.previousBook != nil) || (isAtEndBoundary && parent.nextBook != nil)
      }

      private func boundaryAction(for signal: CGFloat) -> BoundaryNavigationAction? {
        guard signal != 0 else { return nil }
        if isAtFirstBoundary, let previousBook = parent.previousBook, isBackwardSignal(signal) {
          return .openPrevious(previousBook.id)
        }
        if isAtEndBoundary, let nextBook = parent.nextBook, isForwardSignal(signal) {
          return .openNext(nextBook.id)
        }
        return nil
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isTransitioning else { return false }
        guard !parent.viewModel.isZoomed else { return false }
        guard parent.viewModel.liveTextActivePageIndex == nil else { return false }

        syncCurrentPageIndexWithVisibleController()
        guard isValidIndex(currentPageIndex) else { return false }

        if let pan = gestureRecognizer as? UIPanGestureRecognizer,
          gestureRecognizer === boundaryPanRecognizer
        {
          guard hasBoundarySwipeContext else { return false }
          let velocitySignal = primaryVelocity(for: pan)
          if velocitySignal == 0 { return true }
          return boundaryAction(for: velocitySignal) != nil
        }

        let beforeExists = isValidIndex(beforeIndex(from: currentPageIndex))
        let afterExists = isValidIndex(afterIndex(from: currentPageIndex))

        if let tap = gestureRecognizer as? UITapGestureRecognizer,
          let view = tap.view,
          view.bounds.width > 0,
          view.bounds.height > 0
        {
          let location = tap.location(in: view)
          let normalizedX = location.x / view.bounds.width
          let normalizedY = location.y / view.bounds.height

          let action = TapZoneHelper.action(
            normalizedX: normalizedX,
            normalizedY: normalizedY,
            tapZoneMode: parent.tapZoneMode,
            readingDirection: parent.readingDirection,
            zoneThreshold: parent.tapZoneSize.value
          )

          switch action {
          case .next, .previous, .toggleControls:
            return false
          }
        }

        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
          let primaryTranslation = primaryTranslation(for: pan)
          let primaryVelocity = primaryVelocity(for: pan)

          let directionTranslationThreshold: CGFloat = 1
          let directionVelocityThreshold: CGFloat = 60

          let directionSignal: CGFloat
          if abs(primaryTranslation) >= directionTranslationThreshold {
            directionSignal = primaryTranslation
          } else if abs(primaryVelocity) >= directionVelocityThreshold {
            directionSignal = primaryVelocity
          } else {
            directionSignal = 0
          }

          if directionSignal > 0 {
            return beforeExists
          }

          if directionSignal < 0 {
            return afterExists
          }

          // Ambiguous initial pan direction: allow only when both sides exist.
          // This avoids boundary curls (e.g. first page -> previous) that can crash.
          return beforeExists && afterExists
        }

        return true
      }

      @objc func handleBoundaryPan(_ gesture: UIPanGestureRecognizer) {
        syncCurrentPageIndexWithVisibleController()
        guard isValidIndex(currentPageIndex) else {
          parent.onBoundaryPanUpdate?(0)
          hasTriggeredBoundaryHaptic = false
          return
        }

        guard hasBoundarySwipeContext else {
          parent.onBoundaryPanUpdate?(0)
          hasTriggeredBoundaryHaptic = false
          return
        }

        let translation = primaryTranslation(for: gesture)
        let currentAction = boundaryAction(for: translation)

        switch gesture.state {
        case .began:
          hasTriggeredBoundaryHaptic = false
          parent.onBoundaryPanUpdate?(0)
        case .changed:
          guard currentAction != nil else {
            parent.onBoundaryPanUpdate?(0)
            hasTriggeredBoundaryHaptic = false
            return
          }
          parent.onBoundaryPanUpdate?(translation)
          if abs(translation) >= boundarySwipeThreshold && !hasTriggeredBoundaryHaptic {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            hasTriggeredBoundaryHaptic = true
          }
        case .ended, .cancelled:
          parent.onBoundaryPanUpdate?(0)
          defer { hasTriggeredBoundaryHaptic = false }
          guard let finalAction = currentAction else { return }
          guard abs(translation) >= boundarySwipeThreshold else { return }
          switch finalAction {
          case .openPrevious(let previousBookId):
            parent.onPreviousBook(previousBookId)
          case .openNext(let nextBookId):
            parent.onNextBook(nextBookId)
          }
        default:
          break
        }
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        // Allow UIPageViewController's gestures to work with other gestures (like zoom transition)
        return true
      }
    }
  }

  // MARK: - CurlSinglePageView

  /// Simplified page view for use within UIPageViewController
  private struct CurlSinglePageView: View {
    let viewModel: ReaderViewModel
    let pageIndex: Int
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    var isLeftHalf: Bool? = nil  // nil for non-split pages, true/false for split pages
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void
    let onPlayAnimatedPage: ((Int) -> Void)?

    @Environment(\.readerBackgroundPreference) private var readerBackground

    var body: some View {
      GeometryReader { proxy in
        ZStack {
          readerBackground.color.readerIgnoresSafeArea()

          // Check if current page is a split wide page
          if let isLeftHalf = isLeftHalf {
            // This is a split page
            SplitWidePageImageView(
              viewModel: viewModel,
              pageIndex: pageIndex,
              isLeftHalf: isLeftHalf,
              screenSize: proxy.size,
              readingDirection: readingDirection,
              onNextPage: onNextPage,
              onPreviousPage: onPreviousPage,
              onToggleControls: onToggleControls,
              onPlayAnimatedPage: onPlayAnimatedPage
            )
          } else {
            // Regular single page
            SinglePageImageView(
              viewModel: viewModel,
              pageIndex: pageIndex,
              screenSize: proxy.size,
              readingDirection: readingDirection,
              onNextPage: onNextPage,
              onPreviousPage: onPreviousPage,
              onToggleControls: onToggleControls,
              onPlayAnimatedPage: onPlayAnimatedPage
            )
          }
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .readerIgnoresSafeArea()
    }
  }
#endif
