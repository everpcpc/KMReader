//
// CurlPageView.swift
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct CurlPageView: UIViewControllerRepresentable {
    @Bindable var viewModel: ReaderViewModel
    let mode: PageViewMode
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void
    let goToNextPage: () -> Void
    let goToPreviousPage: () -> Void
    let toggleControls: () -> Void
    let onPlayAnimatedPage: ((Int) -> Void)?

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

      for recognizer in pageVC.gestureRecognizers {
        recognizer.delegate = context.coordinator
        if recognizer is UITapGestureRecognizer {
          recognizer.isEnabled = false
        }
      }

      pageVC.isDoubleSided = false
      pageVC.view.semanticContentAttribute = mode.isRTL ? .forceRightToLeft : .forceLeftToRight

      let initialIndex = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      context.coordinator.currentPageIndex = initialIndex
      context.coordinator.updateViewItemsSnapshot(viewModel.viewItems)
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
      let didViewItemsChange = context.coordinator.updateViewItemsSnapshot(viewModel.viewItems)
      context.coordinator.refreshVisibleControllerConfiguration()

      let targetViewItemIndex: Int? = {
        if let explicitTarget = viewModel.targetViewItemIndex {
          return explicitTarget
        }
        if let targetPageIndex = viewModel.targetPageIndex {
          return viewModel.viewItemIndex(forPageIndex: targetPageIndex)
        }
        if didViewItemsChange {
          return viewModel.currentViewItemIndex
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
      var isTransitioning = false
      private var lastViewItemsCount: Int = 0
      private var lastFirstViewItem: ReaderViewItem?
      private var lastLastViewItem: ReaderViewItem?

      init(_ parent: CurlPageView) {
        self.parent = parent
        self.currentPageIndex = parent.viewModel.currentViewItemIndex
      }

      var totalPages: Int {
        parent.viewModel.viewItems.count
      }

      @discardableResult
      func updateViewItemsSnapshot(_ items: [ReaderViewItem]) -> Bool {
        let firstItem = items.first
        let lastItem = items.last
        let didChange =
          items.count != lastViewItemsCount
          || firstItem != lastFirstViewItem
          || lastItem != lastLastViewItem

        lastViewItemsCount = items.count
        lastFirstViewItem = firstItem
        lastLastViewItem = lastItem
        return didChange
      }

      private func configureImageController(
        _ controller: NativeImagePageViewController,
        with item: ReaderViewItem
      ) {
        let pageIndex: Int
        let splitMode: PageSplitMode

        switch item {
        case .page(let id):
          guard let resolvedIndex = parent.viewModel.pageIndex(for: id) else { return }
          pageIndex = resolvedIndex
          splitMode = .none
        case .dual(let first, _):
          guard let resolvedIndex = parent.viewModel.pageIndex(for: first) else { return }
          pageIndex = resolvedIndex
          splitMode = .none
        case .split(let id, let isFirstHalf):
          guard let resolvedIndex = parent.viewModel.pageIndex(for: id) else { return }
          pageIndex = resolvedIndex
          let isLeftHalf = parent.viewModel.isLeftSplitHalf(
            isFirstHalf: isFirstHalf,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode
          )
          splitMode = isLeftHalf ? .leftHalf : .rightHalf
        case .end:
          return
        }

        controller.configure(
          viewModel: parent.viewModel,
          pageIndex: pageIndex,
          splitMode: splitMode,
          readingDirection: parent.readingDirection,
          renderConfig: parent.renderConfig,
          onNextPage: parent.goToNextPage,
          onPreviousPage: parent.goToPreviousPage,
          onToggleControls: parent.toggleControls,
          onPlayAnimatedPage: parent.onPlayAnimatedPage
        )
      }

      private func configureEndController(
        _ controller: NativeEndPageViewController,
        segmentBookId: String
      ) {
        controller.configure(
          previousBook: parent.viewModel.currentBook(forSegmentBookId: segmentBookId),
          nextBook: parent.viewModel.nextBook(forSegmentBookId: segmentBookId),
          readListContext: parent.readListContext,
          readingDirection: parent.readingDirection,
          renderConfig: parent.renderConfig,
          onNextPage: parent.goToNextPage,
          onPreviousPage: parent.goToPreviousPage,
          onToggleControls: parent.toggleControls,
          onDismiss: parent.onDismiss
        )
      }

      func refreshVisibleControllerConfiguration() {
        guard let pageViewController else { return }
        guard let visibleController = pageViewController.viewControllers?.first else { return }
        let index = visibleController.view.tag
        guard let item = parent.viewModel.viewItem(at: index) else { return }

        switch item {
        case .end(let segmentBookId):
          if let endController = visibleController as? NativeEndPageViewController {
            configureEndController(endController, segmentBookId: segmentBookId)
          } else if let replacement = self.pageViewController(for: index) {
            pageViewController.setViewControllers([replacement], direction: .forward, animated: false)
          }
        case .page, .dual, .split:
          if let imageController = visibleController as? NativeImagePageViewController {
            configureImageController(imageController, with: item)
          } else if let replacement = self.pageViewController(for: index) {
            pageViewController.setViewControllers([replacement], direction: .forward, animated: false)
          }
        }
      }

      func pageViewController(for index: Int) -> UIViewController? {
        guard index >= 0 && index < totalPages else { return nil }
        guard parent.viewModel.hasPages else { return nil }
        guard let item = parent.viewModel.viewItem(at: index) else { return nil }

        let controller: UIViewController

        switch item {
        case .end(let segmentBookId):
          let endController = NativeEndPageViewController()
          configureEndController(endController, segmentBookId: segmentBookId)
          controller = endController
        case .page, .dual, .split:
          let imageController = NativeImagePageViewController()
          configureImageController(imageController, with: item)
          controller = imageController
        }

        controller.view.tag = index
        return controller
      }

      // MARK: - UIPageViewControllerDataSource

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
      ) -> UIViewController? {
        let index = viewController.view.tag
        let targetIndex = parent.mode.isRTL ? index + 1 : index - 1
        if !isValidIndex(targetIndex) { return nil }
        return self.pageViewController(for: targetIndex)
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
      ) -> UIViewController? {
        let index = viewController.view.tag
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

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isTransitioning else { return false }
        guard !parent.viewModel.isZoomed else { return false }
        guard parent.viewModel.liveTextActivePageIndex == nil else { return false }

        syncCurrentPageIndexWithVisibleController()
        guard isValidIndex(currentPageIndex) else { return false }

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
            tapZoneMode: parent.renderConfig.tapZoneMode,
            readingDirection: parent.readingDirection,
            zoneThreshold: parent.renderConfig.tapZoneSize.value
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

          return beforeExists && afterExists
        }

        return true
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        true
      }
    }
  }
#endif
