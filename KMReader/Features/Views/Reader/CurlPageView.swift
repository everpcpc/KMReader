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
    let nextBook: Book?
    let readList: ReadList?
    let onDismiss: () -> Void
    let onNextBook: (String) -> Void
    let goToNextPage: () -> Void
    let goToPreviousPage: () -> Void
    let toggleControls: () -> Void
    let onEndPageFocusChange: ((Bool) -> Void)?

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
      }
      // isDoubleSided requires 2 VCs for animated transitions which complicates the logic
      // For single-page curl effect, keep it false
      pageVC.isDoubleSided = false

      // Match page curl direction to reading order
      pageVC.view.semanticContentAttribute = mode.isRTL ? .forceRightToLeft : .forceLeftToRight

      // Set initial page (non-animated, so single VC is fine)
      if let initialVC = context.coordinator.pageViewController(for: viewModel.currentPageIndex) {
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

      // Handle programmatic page changes via targetPageIndex
      if let targetIndex = viewModel.targetPageIndex,
        targetIndex != context.coordinator.currentPageIndex
      {
        if let targetVC = context.coordinator.pageViewController(for: targetIndex) {
          let direction: UIPageViewController.NavigationDirection
          if mode.isRTL {
            direction = targetIndex > context.coordinator.currentPageIndex ? .reverse : .forward
          } else {
            direction = targetIndex > context.coordinator.currentPageIndex ? .forward : .reverse
          }

          pageVC.setViewControllers(
            [targetVC],
            direction: direction,
            animated: true
          ) { completed in
            if completed {
              context.coordinator.currentPageIndex = targetIndex
              Task { @MainActor in
                viewModel.currentPageIndex = targetIndex
                viewModel.targetPageIndex = nil
              }
            }
          }
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
        self.currentPageIndex = parent.viewModel.currentPageIndex
      }

      // Total page count including end page
      var totalPages: Int {
        parent.viewModel.pages.count + 1
      }

      func pageViewController(for index: Int) -> UIViewController? {
        guard index >= 0 && index < totalPages else { return nil }

        let hostingController: UIHostingController<AnyView>

        if index == parent.viewModel.pages.count {
          // End page
          let endPageView = EndPageView(
            viewModel: parent.viewModel,
            nextBook: parent.nextBook,
            readList: parent.readList,
            onDismiss: parent.onDismiss,
            onNextBook: parent.onNextBook,
            readingDirection: parent.readingDirection,
            onPreviousPage: parent.goToPreviousPage,
            onFocusChange: parent.onEndPageFocusChange
          )
          hostingController = UIHostingController(rootView: AnyView(endPageView))
        } else {
          let pageView = CurlSinglePageView(
            viewModel: parent.viewModel,
            pageIndex: index,
            readingDirection: parent.readingDirection,
            onNextPage: parent.goToNextPage,
            onPreviousPage: parent.goToPreviousPage,
            onToggleControls: parent.toggleControls
          )
          hostingController = UIHostingController(rootView: AnyView(pageView))
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
          parent.viewModel.currentPageIndex = newIndex
          await parent.viewModel.updateProgress()
          await parent.viewModel.preloadPages()
        }
      }

      // MARK: - UIGestureRecognizerDelegate

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
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void

    @Environment(\.readerBackgroundPreference) private var readerBackground

    var body: some View {
      GeometryReader { proxy in
        ZStack {
          readerBackground.color.readerIgnoresSafeArea()

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
        .frame(width: proxy.size.width, height: proxy.size.height)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .readerIgnoresSafeArea()
    }
  }
#endif
