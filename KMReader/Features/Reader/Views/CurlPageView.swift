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
    let nextBook: Book?
    let readList: ReadList?
    let onDismiss: () -> Void
    let onNextBook: (String) -> Void
    let goToNextPage: () -> Void
    let goToPreviousPage: () -> Void
    let toggleControls: () -> Void
    let onEndPageFocusChange: ((Bool) -> Void)?

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
      pageVC.dataSource = context.coordinator
      pageVC.delegate = context.coordinator

      // Allow simultaneous gesture recognition for zoom transition return gesture
      for recognizer in pageVC.gestureRecognizers {
        recognizer.delegate = context.coordinator
        if recognizer is UITapGestureRecognizer {
          recognizer.isEnabled = false
        }
      }
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

      let direction: UIPageViewController.NavigationDirection
      if mode.isRTL {
        direction = targetViewItemIndex > context.coordinator.currentPageIndex ? .reverse : .forward
      } else {
        direction = targetViewItemIndex > context.coordinator.currentPageIndex ? .forward : .reverse
      }

      pageVC.setViewControllers(
        [targetVC],
        direction: direction,
        animated: true
      ) { completed in
        Task { @MainActor in
          if completed {
            context.coordinator.currentPageIndex = targetViewItemIndex
            viewModel.updateCurrentPosition(viewItemIndex: targetViewItemIndex)
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
            onPreviousPage: parent.goToPreviousPage,
            onFocusChange: parent.onEndPageFocusChange,
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
            onToggleControls: parent.toggleControls
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
            onToggleControls: parent.toggleControls
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
            onToggleControls: parent.toggleControls
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
        return self.pageViewController(for: targetIndex)
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
      ) -> UIViewController? {
        let index = viewController.view.tag
        // "after" = page on the right side
        let targetIndex = parent.mode.isRTL ? index - 1 : index + 1
        return self.pageViewController(for: targetIndex)
      }

      // MARK: - UIPageViewControllerDelegate

      func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
      ) {
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

      private func nextIndex(from index: Int) -> Int {
        parent.mode.isRTL ? index - 1 : index + 1
      }

      private func previousIndex(from index: Int) -> Int {
        parent.mode.isRTL ? index + 1 : index - 1
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !parent.viewModel.isZoomed else { return false }
        guard parent.viewModel.liveTextActivePageIndex == nil else { return false }

        let nextExists = isValidIndex(nextIndex(from: currentPageIndex))
        let previousExists = isValidIndex(previousIndex(from: currentPageIndex))

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
          let velocity = pan.velocity(in: pan.view)
          let forward: Bool?

          switch parent.readingDirection {
          case .ltr:
            if velocity.x < 0 { forward = true } else if velocity.x > 0 { forward = false } else { forward = nil }
          case .rtl:
            if velocity.x > 0 { forward = true } else if velocity.x < 0 { forward = false } else { forward = nil }
          case .vertical, .webtoon:
            if velocity.y < 0 { forward = true } else if velocity.y > 0 { forward = false } else { forward = nil }
          }

          if let forward {
            return forward ? nextExists : previousExists
          }
        }

        return true
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
              onToggleControls: onToggleControls
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
              onToggleControls: onToggleControls
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
