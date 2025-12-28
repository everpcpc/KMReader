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
      view.backgroundColor = .black
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
    private var pendingDirection: CurlNavigationDirection?
    private var isNavigating = false
    private var isPrefetching = false
    private var isRTL = false
    private var refreshToken: UUID?
    private var tapHandler: (() -> Void)?

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
        currentSnapshot = captureSnapshot()
        if currentSnapshot == nil {
          try? await Task.sleep(nanoseconds: 60_000_000)
          currentSnapshot = captureSnapshot()
        }
        currentController = SnapshotPageViewController(kind: .current, image: currentSnapshot)
        if let controller = currentController {
          pageViewController?.setViewControllers([controller], direction: .forward, animated: false)
        }
        await prefetchForwardSnapshot()
        await prefetchBackwardSnapshot()
      }
    }

    private func refreshSnapshots() {
      Task { @MainActor in
        currentSnapshot = captureSnapshot()
        forwardSnapshot = nil
        backwardSnapshot = nil
        currentController?.updateImage(currentSnapshot)
        if currentController == nil {
          currentController = SnapshotPageViewController(kind: .current, image: currentSnapshot)
          if let controller = currentController {
            pageViewController?.setViewControllers(
              [controller], direction: .forward, animated: false)
          }
        }
        await prefetchForwardSnapshot()
        await prefetchBackwardSnapshot()
      }
    }

    private func captureSnapshot() -> UIImage? {
      guard let view = navigatorViewController?.view else { return nil }
      return view.snapshotImage()
    }

    private func prefetchForwardSnapshot() async {
      guard !isPrefetching else { return }
      isPrefetching = true
      forwardSnapshot = await prefetchSnapshot(direction: .forward)
      isPrefetching = false
    }

    private func prefetchBackwardSnapshot() async {
      guard !isPrefetching else { return }
      isPrefetching = true
      backwardSnapshot = await prefetchSnapshot(direction: .backward)
      isPrefetching = false
    }

    private func prefetchSnapshot(direction: CurlNavigationDirection) async -> UIImage? {
      guard let viewModel, let navigatorViewController else { return nil }
      return await viewModel.withoutProgressUpdates {
        let didNavigate: Bool
        switch direction {
        case .forward:
          didNavigate = await viewModel.goToNextPage(animated: false)
        case .backward:
          didNavigate = await viewModel.goToPreviousPage(animated: false)
        }
        guard didNavigate else { return nil }

        try? await Task.sleep(nanoseconds: 60_000_000)
        let image = navigatorViewController.view.snapshotImage()

        switch direction {
        case .forward:
          _ = await viewModel.goToPreviousPage(animated: false)
        case .backward:
          _ = await viewModel.goToNextPage(animated: false)
        }

        return image
      }
    }

    private func directionForBefore() -> CurlNavigationDirection? {
      isRTL ? .forward : .backward
    }

    private func directionForAfter() -> CurlNavigationDirection? {
      isRTL ? .backward : .forward
    }

    private func controller(for direction: CurlNavigationDirection) -> SnapshotPageViewController? {
      switch direction {
      case .forward:
        guard let forwardSnapshot else { return nil }
        return SnapshotPageViewController(kind: .forward, image: forwardSnapshot)
      case .backward:
        guard let backwardSnapshot else { return nil }
        return SnapshotPageViewController(kind: .backward, image: backwardSnapshot)
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

      let didNavigate: Bool
      switch direction {
      case .forward:
        didNavigate = await viewModel.goToNextPage(animated: false)
      case .backward:
        didNavigate = await viewModel.goToPreviousPage(animated: false)
      }

      guard didNavigate else {
        isNavigating = false
        return
      }

      let previousSnapshot = currentSnapshot
      try? await Task.sleep(nanoseconds: 60_000_000)
      currentSnapshot = captureSnapshot()

      switch direction {
      case .forward:
        backwardSnapshot = previousSnapshot
        forwardSnapshot = nil
        await prefetchForwardSnapshot()
      case .backward:
        forwardSnapshot = previousSnapshot
        backwardSnapshot = nil
        await prefetchBackwardSnapshot()
      }

      let controller = SnapshotPageViewController(kind: .current, image: currentSnapshot)
      currentController = controller
      pageViewController?.setViewControllers([controller], direction: .forward, animated: false)
      isNavigating = false
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
