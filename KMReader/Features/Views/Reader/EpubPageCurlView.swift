#if os(iOS)
  import ReadiumNavigator
  import SwiftUI
  import UIKit

  struct EpubPageCurlView: UIViewControllerRepresentable {
    let navigatorViewController: EPUBNavigatorViewController
    let viewModel: EpubReaderViewModel
    let readingDirection: ReadingDirection
    let refreshToken: UUID
    let onTap: () -> Void
    let onReady: () -> Void

    func makeUIViewController(context: Context) -> UIPageViewController {
      let controller = UIPageViewController(
        transitionStyle: .pageCurl,
        navigationOrientation: .horizontal
      )
      controller.dataSource = context.coordinator
      controller.delegate = context.coordinator
      controller.isDoubleSided = false
      context.coordinator.attach(pageViewController: controller)
      context.coordinator.attach(
        navigatorViewController: navigatorViewController,
        viewModel: viewModel
      )
      context.coordinator.updateReadingDirection(readingDirection)
      context.coordinator.applyInitialSnapshotIfNeeded()
      context.coordinator.setTapHandler(onTap)
      context.coordinator.setReadyHandler(onReady)
      return controller
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
      context.coordinator.updateReadingDirection(readingDirection)
      context.coordinator.handleRefreshIfNeeded(refreshToken: refreshToken)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }
  }

  private enum CurlNavigationDirection {
    case forward
    case backward
  }

  private enum SnapshotKind {
    case current
    case forward
    case backward
  }

  private final class SnapshotPageViewController: UIViewController {
    let kind: SnapshotKind
    private let imageView = UIImageView()

    init(kind: SnapshotKind, image: UIImage?) {
      self.kind = kind
      super.init(nibName: nil, bundle: nil)
      imageView.image = image
      imageView.contentMode = .scaleToFill
      imageView.translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      view.addSubview(imageView)
      NSLayoutConstraint.activate([
        imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        imageView.topAnchor.constraint(equalTo: view.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }

    func updateImage(_ image: UIImage?) {
      imageView.image = image
    }
  }

  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private weak var pageViewController: UIPageViewController?
    private weak var navigatorViewController: EPUBNavigatorViewController?
    private var viewModel: EpubReaderViewModel?

    private var currentSnapshot: UIImage?
    private var forwardSnapshot: UIImage?
    private var backwardSnapshot: UIImage?
    private var currentController: SnapshotPageViewController?
    private var forwardController: SnapshotPageViewController?
    private var backwardController: SnapshotPageViewController?
    private var pendingDirection: CurlNavigationDirection?
    private var isNavigating = false
    private var isRTL = false
    private var refreshToken: UUID?
    private var tapHandler: (() -> Void)?
    private var readyHandler: (() -> Void)?
    private var forwardPrefetchTask: Task<Void, Never>?
    private var backwardPrefetchTask: Task<Void, Never>?
    private var canGoForward = true
    private var canGoBackward = true

    func attach(pageViewController: UIPageViewController) {
      self.pageViewController = pageViewController
    }

    func attach(
      navigatorViewController: EPUBNavigatorViewController, viewModel: EpubReaderViewModel
    ) {
      self.navigatorViewController = navigatorViewController
      self.viewModel = viewModel
    }

    func setTapHandler(_ handler: @escaping () -> Void) {
      tapHandler = handler
      guard let pageViewController else { return }
      let recognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(handleTap)
      )
      recognizer.cancelsTouchesInView = false
      pageViewController.view.addGestureRecognizer(recognizer)
    }

    func setReadyHandler(_ handler: @escaping () -> Void) {
      readyHandler = handler
    }

    func updateReadingDirection(_ direction: ReadingDirection) {
      isRTL = direction == .rtl
    }

    func handleRefreshIfNeeded(refreshToken: UUID) {
      if self.refreshToken != refreshToken {
        self.refreshToken = refreshToken
        refreshSnapshots()
      }
    }

    func applyInitialSnapshotIfNeeded() {
      guard currentSnapshot == nil else { return }
      Task { @MainActor in
        currentSnapshot = await ensureInitialSnapshot()
        currentController = SnapshotPageViewController(kind: .current, image: currentSnapshot)
        if let controller = currentController {
          pageViewController?.setViewControllers([controller], direction: .forward, animated: false)
        }
        if currentSnapshot != nil {
          readyHandler?()
        }
        await prefetchSnapshots()
      }
    }

    private func refreshSnapshots() {
      Task { @MainActor in
        currentSnapshot = await ensureInitialSnapshot()
        forwardSnapshot = nil
        backwardSnapshot = nil
        forwardController = nil
        backwardController = nil
        canGoForward = true
        canGoBackward = true
        cancelPrefetchTasks()
        currentController?.updateImage(currentSnapshot)
        if currentController == nil {
          currentController = SnapshotPageViewController(kind: .current, image: currentSnapshot)
          if let controller = currentController {
            pageViewController?.setViewControllers(
              [controller], direction: .forward, animated: false)
          }
        }
        if currentSnapshot != nil {
          readyHandler?()
        }
        await prefetchSnapshots()
      }
    }

    private func ensureInitialSnapshot() async -> UIImage? {
      let maxAttempts = 4
      for attempt in 0..<maxAttempts {
        if Task.isCancelled { return nil }
        if let image = await captureSnapshotWithRetries() {
          return image
        }
        if attempt < maxAttempts - 1 {
          try? await Task.sleep(nanoseconds: 120_000_000)
        }
      }
      return nil
    }

    private func captureSnapshot() -> UIImage? {
      guard let view = navigatorViewController?.view else { return nil }
      view.setNeedsLayout()
      view.layoutIfNeeded()
      return view.snapshotImage()
    }

    private func captureSnapshotWithRetries(
      maxRetries: Int = 2,
      delayNanoseconds: UInt64 = 70_000_000
    ) async -> UIImage? {
      for attempt in 0...maxRetries {
        if Task.isCancelled { return nil }
        if let view = navigatorViewController?.view, view.window != nil {
          let image = captureSnapshot()
          if image != nil {
            return image
          }
        }
        if attempt < maxRetries {
          try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
      }
      return nil
    }

    private func schedulePrefetchForward() {
      guard forwardSnapshot == nil, forwardPrefetchTask == nil, !isNavigating else { return }
      forwardPrefetchTask = Task { @MainActor [weak self] in
        guard let self else { return }
        let result = await self.prefetchSnapshot(direction: .forward)
        self.forwardSnapshot = result.image
        self.canGoForward = result.didNavigate
        if let controller = self.forwardController, let image = result.image {
          controller.updateImage(image)
        }
        self.forwardPrefetchTask = nil
      }
    }

    private func schedulePrefetchBackward() {
      guard backwardSnapshot == nil, backwardPrefetchTask == nil, !isNavigating else { return }
      backwardPrefetchTask = Task { @MainActor [weak self] in
        guard let self else { return }
        let result = await self.prefetchSnapshot(direction: .backward)
        self.backwardSnapshot = result.image
        self.canGoBackward = result.didNavigate
        if let controller = self.backwardController, let image = result.image {
          controller.updateImage(image)
        }
        self.backwardPrefetchTask = nil
      }
    }

    private func prefetchSnapshots() async {
      cancelPrefetchTasks()
      let forwardResult = await prefetchSnapshot(direction: .forward)
      forwardSnapshot = forwardResult.image
      canGoForward = forwardResult.didNavigate
      if forwardSnapshot == nil, forwardResult.didNavigate {
        try? await Task.sleep(nanoseconds: 120_000_000)
        let retry = await prefetchSnapshot(direction: .forward)
        forwardSnapshot = retry.image
        canGoForward = retry.didNavigate
      }
      if let forwardController, let image = forwardSnapshot {
        forwardController.updateImage(image)
      }

      let backwardResult = await prefetchSnapshot(direction: .backward)
      backwardSnapshot = backwardResult.image
      canGoBackward = backwardResult.didNavigate
      if backwardSnapshot == nil, backwardResult.didNavigate {
        try? await Task.sleep(nanoseconds: 120_000_000)
        let retry = await prefetchSnapshot(direction: .backward)
        backwardSnapshot = retry.image
        canGoBackward = retry.didNavigate
      }
      if let backwardController, let image = backwardSnapshot {
        backwardController.updateImage(image)
      }
    }

    private func cancelPrefetchTasks() {
      forwardPrefetchTask?.cancel()
      backwardPrefetchTask?.cancel()
      forwardPrefetchTask = nil
      backwardPrefetchTask = nil
    }

    private func prefetchSnapshot(
      direction: CurlNavigationDirection
    ) async -> (image: UIImage?, didNavigate: Bool) {
      guard let viewModel, let navigatorViewController else {
        return (nil, false)
      }
      return await viewModel.withoutProgressUpdates {
        if Task.isCancelled { return (nil, false) }
        let didNavigate: Bool
        switch direction {
        case .forward:
          didNavigate = await viewModel.goToNextPage(animated: false)
        case .backward:
          didNavigate = await viewModel.goToPreviousPage(animated: false)
        }
        guard didNavigate else { return (nil, false) }

        if Task.isCancelled {
          switch direction {
          case .forward:
            _ = await viewModel.goToPreviousPage(animated: false)
          case .backward:
            _ = await viewModel.goToNextPage(animated: false)
          }
          return (nil, true)
        }
        try? await Task.sleep(nanoseconds: 70_000_000)
        let image = await captureSnapshotWithRetries(maxRetries: 1, delayNanoseconds: 50_000_000)

        switch direction {
        case .forward:
          _ = await viewModel.goToPreviousPage(animated: false)
        case .backward:
          _ = await viewModel.goToNextPage(animated: false)
        }

        return (image ?? navigatorViewController.view.snapshotImage(), true)
      }
    }

    private func directionForBefore() -> CurlNavigationDirection? {
      isRTL ? .forward : .backward
    }

    private func directionForAfter() -> CurlNavigationDirection? {
      isRTL ? .backward : .forward
    }

    private func controller(for direction: CurlNavigationDirection) -> SnapshotPageViewController? {
      if direction == .forward, !canGoForward { return nil }
      if direction == .backward, !canGoBackward { return nil }

      switch direction {
      case .forward:
        if let forwardController { return forwardController }
        guard let forwardSnapshot else {
          schedulePrefetchForward()
          return nil
        }
        let controller = SnapshotPageViewController(kind: .forward, image: forwardSnapshot)
        forwardController = controller
        return controller
      case .backward:
        if let backwardController { return backwardController }
        guard let backwardSnapshot else {
          schedulePrefetchBackward()
          return nil
        }
        let controller = SnapshotPageViewController(kind: .backward, image: backwardSnapshot)
        backwardController = controller
        return controller
      }
    }

    private func navigationDirection(for kind: SnapshotKind) -> CurlNavigationDirection? {
      switch kind {
      case .forward:
        return .forward
      case .backward:
        return .backward
      case .current:
        return nil
      }
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
      guard let direction = directionForBefore() else { return nil }
      return controller(for: direction)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
      guard let direction = directionForAfter() else { return nil }
      return controller(for: direction)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      willTransitionTo pendingViewControllers: [UIViewController]
    ) {
      guard let pending = pendingViewControllers.first as? SnapshotPageViewController else {
        pendingDirection = nil
        return
      }
      pendingDirection = navigationDirection(for: pending.kind)
    }

    func pageViewController(
      _ pageViewController: UIPageViewController,
      didFinishAnimating finished: Bool,
      previousViewControllers: [UIViewController],
      transitionCompleted completed: Bool
    ) {
      guard completed, let direction = pendingDirection else {
        pendingDirection = nil
        return
      }
      pendingDirection = nil
      Task { @MainActor in
        await handleCompletedNavigation(direction: direction)
      }
    }

    private func handleCompletedNavigation(direction: CurlNavigationDirection) async {
      guard !isNavigating, let viewModel else { return }
      isNavigating = true
      cancelPrefetchTasks()

      let didNavigate: Bool
      switch direction {
      case .forward:
        didNavigate = await viewModel.goToNextPage(animated: false)
      case .backward:
        didNavigate = await viewModel.goToPreviousPage(animated: false)
      }

      guard didNavigate else {
        if let controller = currentController {
          pageViewController?.setViewControllers([controller], direction: .forward, animated: false)
        }
        if direction == .forward {
          canGoForward = false
        } else {
          canGoBackward = false
        }
        isNavigating = false
        return
      }

      await viewModel.waitForLocationChange(timeoutNanoseconds: 500_000_000)
      let previousSnapshot = currentSnapshot
      let prefetchedSnapshot = (direction == .forward) ? forwardSnapshot : backwardSnapshot
      if let prefetchedSnapshot {
        currentSnapshot = prefetchedSnapshot
      } else {
        currentSnapshot = await captureSnapshotWithRetries()
      }

      switch direction {
      case .forward:
        backwardSnapshot = previousSnapshot
        forwardSnapshot = nil
        backwardController = nil
        forwardController = nil
        canGoBackward = true
        schedulePrefetchForward()
      case .backward:
        forwardSnapshot = previousSnapshot
        backwardSnapshot = nil
        forwardController = nil
        backwardController = nil
        canGoForward = true
        schedulePrefetchBackward()
      }

      let controller = SnapshotPageViewController(kind: .current, image: currentSnapshot)
      currentController = controller
      pageViewController?.setViewControllers([controller], direction: .forward, animated: false)
      isNavigating = false

      await prefetchSnapshots()
      scheduleLateSnapshotRefresh()
    }

    private func scheduleLateSnapshotRefresh() {
      Task { @MainActor [weak self] in
        guard let self else { return }
        try? await Task.sleep(nanoseconds: 160_000_000)
        guard !self.isNavigating else { return }
        guard let refreshed = await self.captureSnapshotWithRetries(maxRetries: 1, delayNanoseconds: 60_000_000)
        else { return }
        self.currentSnapshot = refreshed
        self.currentController?.updateImage(refreshed)
      }
    }

    @objc private func handleTap() {
      tapHandler?()
    }
  }

  extension UIView {
    fileprivate func snapshotImage() -> UIImage? {
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      let renderer = UIGraphicsImageRenderer(bounds: bounds)
      return renderer.image { _ in
        if !drawHierarchy(in: bounds, afterScreenUpdates: true),
          let context = UIGraphicsGetCurrentContext()
        {
          layer.render(in: context)
        }
      }
    }
  }
#endif
