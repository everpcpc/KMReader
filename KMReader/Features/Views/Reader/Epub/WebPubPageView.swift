//
//  WebPubPageView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI
  import UIKit
  import WebKit

  extension ReaderTheme {
    var uiColorBackground: UIColor { UIColor(hex: backgroundColorHex) ?? .white }
    var uiColorText: UIColor { UIColor(hex: textColorHex) ?? .black }
  }

  extension UIColor {
    convenience init?(hex: String) {
      var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("#") {
        trimmed.removeFirst()
      }
      guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
      let red = CGFloat((value >> 16) & 0xFF) / 255.0
      let green = CGFloat((value >> 8) & 0xFF) / 255.0
      let blue = CGFloat(value & 0xFF) / 255.0
      self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    var brightness: CGFloat {
      var r: CGFloat = 0
      var g: CGFloat = 0
      var b: CGFloat = 0
      var a: CGFloat = 0
      guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
      return (r * 299 + g * 587 + b * 114) / 1000
    }
  }

  /// A weak wrapper for WKScriptMessageHandler to avoid retain cycles.
  /// WKUserContentController retains its message handlers strongly, so we use this
  /// wrapper to prevent the view controller from being retained by the web view.
  private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
      self.delegate = delegate
      super.init()
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      delegate?.userContentController(userContentController, didReceive: message)
    }
  }

  struct WebPubPageView: UIViewControllerRepresentable {
    @Bindable var viewModel: EpubReaderViewModel
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme
    let onTap: (CGPoint, CGSize) -> Void
    let transitionStyle: UIPageViewController.TransitionStyle
    let showingControls: Bool
    let bookTitle: String?

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
      let spineLocation: UIPageViewController.SpineLocation = .min
      let options: [UIPageViewController.OptionsKey: Any]? =
        transitionStyle == .pageCurl ? [.spineLocation: NSNumber(value: spineLocation.rawValue)] : nil

      let pageVC = UIPageViewController(
        transitionStyle: transitionStyle,
        navigationOrientation: .horizontal,
        options: options
      )
      pageVC.isDoubleSided = false
      pageVC.dataSource = context.coordinator
      pageVC.delegate = context.coordinator
      context.coordinator.pageViewController = pageVC

      if transitionStyle == .pageCurl {
        pageVC.view.gestureRecognizers?.forEach { recognizer in
          if recognizer is UITapGestureRecognizer {
            recognizer.isEnabled = false
          }
        }
      }

      let tapRecognizer = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleTap(_:))
      )
      tapRecognizer.cancelsTouchesInView = false
      tapRecognizer.delegate = context.coordinator
      pageVC.view.addGestureRecognizer(tapRecognizer)

      let longPress = UILongPressGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleLongPress(_:))
      )
      longPress.minimumPressDuration = 0.5
      longPress.delegate = context.coordinator
      longPress.cancelsTouchesInView = false
      pageVC.view.addGestureRecognizer(longPress)

      if let initialLocation = viewModel.pageLocation(at: viewModel.currentPageIndex),
        let initialVC = context.coordinator.pageViewController(
          chapterIndex: initialLocation.chapterIndex,
          subPageIndex: initialLocation.pageIndex,
          in: pageVC
        )
      {
        pageVC.setViewControllers(
          [initialVC],
          direction: .forward,
          animated: false
        )
        if let initialVC = initialVC as? EpubPageViewController {
          context.coordinator.preloadAdjacentPages(for: initialVC, in: pageVC)
        }
      }

      return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
      context.coordinator.parent = self

      if pageVC.viewControllers?.isEmpty ?? true,
        let initialLocation = viewModel.pageLocation(at: viewModel.currentPageIndex),
        let initialVC = context.coordinator.pageViewController(
          chapterIndex: initialLocation.chapterIndex,
          subPageIndex: initialLocation.pageIndex,
          in: pageVC
        )
      {
        pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        context.coordinator.currentPageIndex = viewModel.currentPageIndex
        if let initialVC = initialVC as? EpubPageViewController {
          context.coordinator.preloadAdjacentPages(for: initialVC, in: pageVC)
        }
      }

      if let targetIndex = viewModel.targetPageIndex,
        targetIndex != context.coordinator.currentPageIndex,
        !context.coordinator.isAnimating,
        let targetLocation = viewModel.pageLocation(at: targetIndex),
        let targetVC = context.coordinator.pageViewController(
          chapterIndex: targetLocation.chapterIndex,
          subPageIndex: targetLocation.pageIndex,
          in: pageVC
        )
      {
        let direction: UIPageViewController.NavigationDirection =
          targetIndex > context.coordinator.currentPageIndex ? .forward : .reverse

        context.coordinator.isAnimating = true
        pageVC.setViewControllers(
          [targetVC],
          direction: direction,
          animated: true
        ) { completed in
          context.coordinator.isAnimating = false
          if completed {
            context.coordinator.currentPageIndex = targetIndex
            if let currentVC = pageVC.viewControllers?.first as? EpubPageViewController {
              context.coordinator.preloadAdjacentPages(for: currentVC, in: pageVC)
            }
            Task { @MainActor in
              viewModel.targetPageIndex = nil
              viewModel.pageDidChange(to: targetIndex)
            }
          }
        }
      }

      if let currentVC = pageVC.viewControllers?.first as? EpubPageViewController {
        let chapterIndex = currentVC.chapterIndex
        let pageInsets = viewModel.pageInsets(for: preferences)
        let theme = preferences.resolvedTheme(for: colorScheme)
        let contentCSS = preferences.makeCSS(theme: theme)

        guard let globalIndex = viewModel.globalIndexForChapter(chapterIndex, pageIndex: currentVC.currentSubPageIndex),
          globalIndex < viewModel.pageLocations.count
        else { return }
        let location = viewModel.pageLocations[globalIndex]
        let chapterProgress = location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = viewModel.totalProgression(
          for: globalIndex, location: location, chapterProgress: chapterProgress)

        currentVC.configure(
          chapterURL: viewModel.chapterURL(at: chapterIndex),
          rootURL: viewModel.resourceRootURL,
          pageInsets: pageInsets,
          theme: theme,
          contentCSS: contentCSS,
          chapterIndex: chapterIndex,
          subPageIndex: currentVC.currentSubPageIndex,
          totalPages: currentVC.totalPagesInChapter,
          bookTitle: bookTitle,
          chapterTitle: location.title,
          totalProgression: totalProgression,
          showingControls: showingControls,
          labelTopOffset: viewModel.labelTopOffset,
          labelBottomOffset: viewModel.labelBottomOffset,
          useSafeArea: viewModel.useSafeArea,
          onPageCountReady: { [weak viewModel] pageCount in
            Task { @MainActor in
              viewModel?.updateChapterPageCount(pageCount, for: chapterIndex)
            }
          }
        )
      }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
      UIGestureRecognizerDelegate
    {
      var parent: WebPubPageView
      var currentPageIndex: Int
      var isAnimating = false
      var isLongPressing = false
      var lastLongPressEndTime: Date = .distantPast
      var lastTouchStartTime: Date = .distantPast
      weak var pageViewController: UIPageViewController?
      private let maxCachedControllers = 3
      private var cachedControllers: [Int: EpubPageViewController] = [:]
      private var controllerKeys: [ObjectIdentifier: Int] = [:]

      init(_ parent: WebPubPageView) {
        self.parent = parent
        self.currentPageIndex = parent.viewModel.currentPageIndex
      }

      private func configureController(
        _ controller: EpubPageViewController
      ) {
        controller.onPageIndexAdjusted = { [weak self, weak controller] pageIndex in
          guard let self, let controller else { return }
          guard self.pageViewController?.viewControllers?.first === controller else { return }
          if let globalIndex = self.parent.viewModel.globalIndexForChapter(
            controller.chapterIndex,
            pageIndex: pageIndex
          ) {
            self.currentPageIndex = globalIndex
            self.parent.viewModel.pageDidChange(to: globalIndex)
          }
        }
      }

      func pageViewController(
        chapterIndex: Int,
        subPageIndex: Int,
        in pageViewController: UIPageViewController?,
        preferLastPageOnReady: Bool = false
      ) -> UIViewController? {
        let pageCount = parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
        guard subPageIndex >= 0, subPageIndex < pageCount || preferLastPageOnReady else { return nil }

        let pageInsets = parent.viewModel.pageInsets(for: parent.preferences)
        let theme = parent.preferences.resolvedTheme(for: parent.colorScheme)
        let contentCSS = parent.preferences.makeCSS(theme: theme)
        let chapterURL = parent.viewModel.chapterURL(at: chapterIndex)
        let rootURL = parent.viewModel.resourceRootURL
        let chapterIndexForCallback = chapterIndex
        let onPageCountReady: (Int) -> Void = { [weak viewModel = parent.viewModel] pageCount in
          Task { @MainActor in
            viewModel?.updateChapterPageCount(pageCount, for: chapterIndexForCallback)
          }
        }

        guard let globalIndex = parent.viewModel.globalIndexForChapter(chapterIndex, pageIndex: subPageIndex),
          globalIndex < parent.viewModel.pageLocations.count
        else { return nil }
        let location = parent.viewModel.pageLocations[globalIndex]
        let chapterProgress = location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = parent.viewModel.totalProgression(
          for: globalIndex, location: location, chapterProgress: chapterProgress)
        let initialProgression = parent.viewModel.initialProgression(for: chapterIndex)

        if let cached = cachedControllers[globalIndex] {
          cached.configure(
            chapterURL: chapterURL,
            rootURL: rootURL,
            pageInsets: pageInsets,
            theme: theme,
            contentCSS: contentCSS,
            chapterIndex: chapterIndex,
            subPageIndex: subPageIndex,
            totalPages: pageCount,
            bookTitle: parent.bookTitle,
            chapterTitle: location.title,
            totalProgression: totalProgression,
            showingControls: parent.showingControls,
            labelTopOffset: parent.viewModel.labelTopOffset,
            labelBottomOffset: parent.viewModel.labelBottomOffset,
            useSafeArea: parent.viewModel.useSafeArea,
            preferLastPageOnReady: preferLastPageOnReady,
            targetProgressionOnReady: initialProgression,
            onPageCountReady: onPageCountReady
          )
          configureController(cached)
          cached.loadViewIfNeeded()
          cached.view.tag = globalIndex
          return cached
        }

        let protectedIDs = Set((pageViewController?.viewControllers ?? []).map { ObjectIdentifier($0) })
        if let reusable = cachedControllers.values.first(where: {
          !protectedIDs.contains(ObjectIdentifier($0))
        }) {
          reusable.configure(
            chapterURL: chapterURL,
            rootURL: rootURL,
            pageInsets: pageInsets,
            theme: theme,
            contentCSS: contentCSS,
            chapterIndex: chapterIndex,
            subPageIndex: subPageIndex,
            totalPages: pageCount,
            bookTitle: parent.bookTitle,
            chapterTitle: location.title,
            totalProgression: totalProgression,
            showingControls: parent.showingControls,
            labelTopOffset: parent.viewModel.labelTopOffset,
            labelBottomOffset: parent.viewModel.labelBottomOffset,
            useSafeArea: parent.viewModel.useSafeArea,
            preferLastPageOnReady: preferLastPageOnReady,
            targetProgressionOnReady: initialProgression,
            onPageCountReady: onPageCountReady
          )
          configureController(reusable)
          reusable.onLinkTap = { [weak self] url in
            self?.parent.viewModel.navigateToURL(url)
          }
          reusable.loadViewIfNeeded()
          reusable.view.tag = globalIndex
          storeController(reusable, for: globalIndex)
          return reusable
        }

        let controller = EpubPageViewController(
          chapterURL: chapterURL,
          rootURL: rootURL,
          pageInsets: pageInsets,
          theme: theme,
          contentCSS: contentCSS,
          chapterIndex: chapterIndex,
          subPageIndex: subPageIndex,
          totalPages: pageCount,
          bookTitle: parent.bookTitle,
          chapterTitle: location.title,
          totalProgression: totalProgression,
          showingControls: parent.showingControls,
          labelTopOffset: parent.viewModel.labelTopOffset,
          labelBottomOffset: parent.viewModel.labelBottomOffset,
          useSafeArea: parent.viewModel.useSafeArea,
          onPageCountReady: onPageCountReady
        )
        controller.preferLastPageOnReady = preferLastPageOnReady
        controller.targetProgressionOnReady = initialProgression
        configureController(controller)
        controller.onLinkTap = { [weak self] url in
          self?.parent.viewModel.navigateToURL(url)
        }
        controller.loadViewIfNeeded()
        controller.view.tag = globalIndex
        storeController(controller, for: globalIndex)
        return controller
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
      ) -> UIViewController? {
        guard let current = viewController as? EpubPageViewController else { return nil }

        if current.currentSubPageIndex > 0 {
          let controller = self.pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: current.currentSubPageIndex - 1,
            in: pageViewController
          )
          return controller
        }

        let previousChapter = current.chapterIndex - 1
        guard previousChapter >= 0 else { return nil }
        let previousCount = parent.viewModel.chapterPageCount(at: previousChapter) ?? 1

        let controller = self.pageViewController(
          chapterIndex: previousChapter,
          subPageIndex: max(0, previousCount - 1),
          in: pageViewController,
          preferLastPageOnReady: true
        )
        return controller
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
      ) -> UIViewController? {
        guard let current = viewController as? EpubPageViewController else { return nil }

        let chapterPageCount =
          parent.viewModel.chapterPageCount(at: current.chapterIndex) ?? current.totalPagesInChapter
        if current.currentSubPageIndex < chapterPageCount - 1 {
          let controller = self.pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: current.currentSubPageIndex + 1,
            in: pageViewController
          )
          return controller
        }

        let nextChapter = current.chapterIndex + 1
        guard nextChapter < parent.viewModel.chapterCount else { return nil }

        let controller = self.pageViewController(
          chapterIndex: nextChapter,
          subPageIndex: 0,
          in: pageViewController
        )
        return controller
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]
      ) {
        for controller in pendingViewControllers {
          if let pending = controller as? EpubPageViewController {
            pending.loadViewIfNeeded()
            pending.forceEnsureContentLoaded()
          }
        }
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
      ) {
        guard completed,
          let currentVC = pageViewController.viewControllers?.first as? EpubPageViewController
        else { return }

        if let newIndex = parent.viewModel.globalIndexForChapter(
          currentVC.chapterIndex,
          pageIndex: currentVC.currentSubPageIndex
        ) {
          currentPageIndex = newIndex
          preloadAdjacentPages(for: currentVC, in: pageViewController)
          Task { @MainActor in
            parent.viewModel.pageDidChange(to: newIndex)
          }
        }
      }

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && holdDuration < 0.3 else { return }
        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        let location = recognizer.location(in: recognizer.view)
        let size = recognizer.view?.bounds.size ?? .zero
        parent.onTap(location, size)
      }

      private func storeController(_ controller: EpubPageViewController, for globalIndex: Int) {
        let identifier = ObjectIdentifier(controller)
        if let existingKey = controllerKeys[identifier] {
          cachedControllers.removeValue(forKey: existingKey)
        }
        controllerKeys[identifier] = globalIndex
        cachedControllers[globalIndex] = controller
        if cachedControllers.count > maxCachedControllers {
          evictUnusedControllers()
        }
      }

      private func evictUnusedControllers() {
        let protectedIDs = Set((pageViewController?.viewControllers ?? []).map { ObjectIdentifier($0) })
        for (key, controller) in cachedControllers {
          if cachedControllers.count <= maxCachedControllers {
            break
          }
          let identifier = ObjectIdentifier(controller)
          if !protectedIDs.contains(identifier) {
            cachedControllers.removeValue(forKey: key)
            controllerKeys.removeValue(forKey: identifier)
          }
        }
      }

      func preloadAdjacentPages(for current: EpubPageViewController, in pageVC: UIPageViewController) {
        let chapterPageCount =
          parent.viewModel.chapterPageCount(at: current.chapterIndex) ?? current.totalPagesInChapter
        let nextSubPage = current.currentSubPageIndex + 1
        let prevSubPage = current.currentSubPageIndex - 1

        if nextSubPage < chapterPageCount {
          if let controller = pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: nextSubPage,
            in: pageVC
          ) as? EpubPageViewController {
            controller.loadViewIfNeeded()
            controller.forceEnsureContentLoaded()
          }
        } else {
          let nextChapter = current.chapterIndex + 1
          if nextChapter < parent.viewModel.chapterCount {
            if let controller = pageViewController(
              chapterIndex: nextChapter,
              subPageIndex: 0,
              in: pageVC
            ) as? EpubPageViewController {
              controller.loadViewIfNeeded()
              controller.forceEnsureContentLoaded()
            }
          }
        }

        if prevSubPage >= 0 {
          if let controller = pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: prevSubPage,
            in: pageVC
          ) as? EpubPageViewController {
            controller.loadViewIfNeeded()
            controller.forceEnsureContentLoaded()
          }
        } else {
          let previousChapter = current.chapterIndex - 1
          if previousChapter >= 0 {
            let previousCount = parent.viewModel.chapterPageCount(at: previousChapter) ?? 1
            let preferLastPageOnReady = previousCount <= 1
            if let controller = pageViewController(
              chapterIndex: previousChapter,
              subPageIndex: max(0, previousCount - 1),
              in: pageVC,
              preferLastPageOnReady: preferLastPageOnReady
            ) as? EpubPageViewController {
              controller.loadViewIfNeeded()
              controller.forceEnsureContentLoaded()
            }
          }
        }
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        true
      }

      func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        lastTouchStartTime = Date()
        return true
      }
    }
  }

  @MainActor
  final class EpubPageViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    var chapterIndex: Int
    var currentSubPageIndex: Int
    var totalPagesInChapter: Int
    private var pageInsets: UIEdgeInsets
    private var theme: ReaderTheme
    private var contentCSS: String
    private var chapterURL: URL?
    private var rootURL: URL?
    private var lastLayoutSize: CGSize = .zero
    private var isContentLoaded = false
    private var pendingPageIndex: Int?
    private var readyToken: Int = 0
    private var onPageCountReady: ((Int) -> Void)?
    var onLinkTap: ((URL) -> Void)?
    var onPageIndexAdjusted: ((Int) -> Void)?
    var preferLastPageOnReady = false
    var targetProgressionOnReady: Double?

    private var bookTitle: String?
    private var chapterTitle: String?
    private var totalProgression: Double?
    private var showingControls: Bool = false
    private var labelTopOffset: CGFloat
    private var labelBottomOffset: CGFloat
    private var useSafeArea: Bool

    // Overlay labels
    private var topBookTitleLabel: UILabel?
    private var topProgressLabel: UILabel?
    private var bottomChapterLabel: UILabel?
    private var bottomPageCenterLabel: UILabel?
    private var bottomPageRightLabel: UILabel?

    private var loadingIndicator: UIActivityIndicatorView?

    init(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      chapterIndex: Int,
      subPageIndex: Int,
      totalPages: Int,
      bookTitle: String?,
      chapterTitle: String?,
      totalProgression: Double?,
      showingControls: Bool,
      labelTopOffset: CGFloat,
      labelBottomOffset: CGFloat,
      useSafeArea: Bool,
      onPageCountReady: ((Int) -> Void)?
    ) {
      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.pageInsets = pageInsets
      self.theme = theme
      self.contentCSS = contentCSS
      self.chapterIndex = chapterIndex
      self.currentSubPageIndex = subPageIndex
      self.totalPagesInChapter = totalPages
      self.bookTitle = bookTitle
      self.chapterTitle = chapterTitle
      self.totalProgression = totalProgression
      self.showingControls = showingControls
      self.labelTopOffset = labelTopOffset
      self.labelBottomOffset = labelBottomOffset
      self.useSafeArea = useSafeArea
      self.onPageCountReady = onPageCountReady
      self.onLinkTap = nil
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupWebView()
      setupOverlayLabels()
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAppDidBecomeActive),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
      loadContentIfNeeded(force: true)
    }

    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      refreshDisplay()
      updateOverlayLabels()
    }

    @objc private func handleAppDidBecomeActive() {
      refreshDisplay()
      updateOverlayLabels()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      let size = view.bounds.size
      guard size.width > 0, size.height > 0 else { return }
      if size != lastLayoutSize {
        lastLayoutSize = size
        refreshDisplay()
        updateOverlayLabels()
      }
    }

    func configure(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      chapterIndex: Int,
      subPageIndex: Int,
      totalPages: Int,
      bookTitle: String?,
      chapterTitle: String?,
      totalProgression: Double?,
      showingControls: Bool,
      labelTopOffset: CGFloat,
      labelBottomOffset: CGFloat,
      useSafeArea: Bool,
      preferLastPageOnReady: Bool = false,
      targetProgressionOnReady: Double? = nil,
      onPageCountReady: ((Int) -> Void)?
    ) {
      let shouldReload = chapterURL != self.chapterURL || rootURL != self.rootURL
      let appearanceChanged =
        theme != self.theme
        || pageInsets != self.pageInsets
        || contentCSS != self.contentCSS
        || labelTopOffset != self.labelTopOffset
        || labelBottomOffset != self.labelBottomOffset
        || useSafeArea != self.useSafeArea

      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.pageInsets = pageInsets
      self.theme = theme
      self.contentCSS = contentCSS
      self.chapterIndex = chapterIndex
      self.currentSubPageIndex = subPageIndex
      self.totalPagesInChapter = totalPages
      self.bookTitle = bookTitle
      self.chapterTitle = chapterTitle
      self.totalProgression = totalProgression
      self.showingControls = showingControls
      self.labelTopOffset = labelTopOffset
      self.labelBottomOffset = labelBottomOffset
      self.useSafeArea = useSafeArea
      self.preferLastPageOnReady = preferLastPageOnReady
      self.targetProgressionOnReady = targetProgressionOnReady
      self.onPageCountReady = onPageCountReady

      guard isViewLoaded else { return }

      updateOverlayLabels()

      if appearanceChanged {
        applyContainerInsets()
      }

      applyTheme()
      if shouldReload {
        loadContentIfNeeded(force: true)
      } else if appearanceChanged || preferLastPageOnReady {
        applyPagination(scrollToPage: currentSubPageIndex)
      } else {
        scrollToPage(currentSubPageIndex)
      }
    }

    func refreshDisplay() {
      applyPagination(scrollToPage: currentSubPageIndex)
    }

    private var topAnchor: NSLayoutYAxisAnchor {
      useSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
    }
    private var bottomAnchor: NSLayoutYAxisAnchor {
      useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
    }
    private var leadingAnchor: NSLayoutXAxisAnchor {
      useSafeArea ? view.safeAreaLayoutGuide.leadingAnchor : view.leadingAnchor
    }
    private var trailingAnchor: NSLayoutXAxisAnchor {
      useSafeArea ? view.safeAreaLayoutGuide.trailingAnchor : view.trailingAnchor
    }

    func setupOverlayLabels() {
      let topOffset = labelTopOffset
      let bottomOffset = -labelBottomOffset

      // Top book title label
      let bookTitleLabel = UILabel()
      bookTitleLabel.font = .systemFont(ofSize: 13)
      bookTitleLabel.textColor = .systemGray
      bookTitleLabel.textAlignment = .center
      bookTitleLabel.translatesAutoresizingMaskIntoConstraints = false
      bookTitleLabel.isUserInteractionEnabled = false
      bookTitleLabel.alpha = 0
      view.addSubview(bookTitleLabel)
      NSLayoutConstraint.activate([
        bookTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
        bookTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        bookTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      ])
      self.topBookTitleLabel = bookTitleLabel

      // Top progress label
      let progressLabel = UILabel()
      progressLabel.font = .systemFont(ofSize: 13)
      progressLabel.textColor = .systemGray
      progressLabel.textAlignment = .center
      progressLabel.translatesAutoresizingMaskIntoConstraints = false
      progressLabel.isUserInteractionEnabled = false
      progressLabel.alpha = 0
      view.addSubview(progressLabel)
      NSLayoutConstraint.activate([
        progressLabel.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
        progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      ])
      self.topProgressLabel = progressLabel

      // Bottom chapter label
      let chapterLabel = UILabel()
      chapterLabel.font = .systemFont(ofSize: 12)
      chapterLabel.textColor = .systemGray
      chapterLabel.textAlignment = .left
      chapterLabel.translatesAutoresizingMaskIntoConstraints = false
      chapterLabel.isUserInteractionEnabled = false
      chapterLabel.alpha = 0
      view.addSubview(chapterLabel)
      NSLayoutConstraint.activate([
        chapterLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomOffset),
        chapterLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      ])
      self.bottomChapterLabel = chapterLabel

      // Bottom page label (centered)
      let pageCenterLabel = UILabel()
      pageCenterLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
      pageCenterLabel.textColor = .systemGray
      pageCenterLabel.textAlignment = .center
      pageCenterLabel.translatesAutoresizingMaskIntoConstraints = false
      pageCenterLabel.isUserInteractionEnabled = false
      pageCenterLabel.alpha = 0
      view.addSubview(pageCenterLabel)
      NSLayoutConstraint.activate([
        pageCenterLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomOffset),
        pageCenterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      ])
      self.bottomPageCenterLabel = pageCenterLabel

      // Bottom page label (right side)
      let pageRightLabel = UILabel()
      pageRightLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
      pageRightLabel.textColor = .systemGray
      pageRightLabel.textAlignment = .right
      pageRightLabel.translatesAutoresizingMaskIntoConstraints = false
      pageRightLabel.isUserInteractionEnabled = false
      pageRightLabel.alpha = 0
      view.addSubview(pageRightLabel)
      NSLayoutConstraint.activate([
        pageRightLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomOffset),
        pageRightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        pageRightLabel.leadingAnchor.constraint(greaterThanOrEqualTo: chapterLabel.trailingAnchor, constant: 8),
      ])
      self.bottomPageRightLabel = pageRightLabel
    }

    func updateOverlayLabels() {
      UIView.animate {
        // Top labels
        if self.showingControls {
          self.topBookTitleLabel?.alpha = 0.0
          if let totalProgression = self.totalProgression {
            self.topProgressLabel?.text = String(format: "%.2f%%", totalProgression * 100)
            self.topProgressLabel?.alpha = 1.0
          } else {
            self.topProgressLabel?.alpha = 0.0
          }
        } else {
          self.topProgressLabel?.alpha = 0.0
          if let bookTitle = self.bookTitle, !bookTitle.isEmpty {
            self.topBookTitleLabel?.text = bookTitle
            self.topBookTitleLabel?.alpha = 1.0
          } else {
            self.topBookTitleLabel?.alpha = 0.0
          }
        }

        // Bottom labels
        if self.totalPagesInChapter > 0 {
          if self.showingControls {
            self.bottomChapterLabel?.alpha = 0.0
            self.bottomPageCenterLabel?.text = "\(self.currentSubPageIndex + 1) / \(self.totalPagesInChapter)"
            self.bottomPageCenterLabel?.alpha = 1.0
            self.bottomPageRightLabel?.alpha = 0.0
          } else {
            if let chapterTitle = self.chapterTitle, !chapterTitle.isEmpty {
              self.bottomChapterLabel?.text = chapterTitle
              self.bottomChapterLabel?.alpha = 1.0
            } else {
              self.bottomChapterLabel?.alpha = 0.0
            }
            self.bottomPageCenterLabel?.alpha = 0.0
            self.bottomPageRightLabel?.text = "\(self.currentSubPageIndex + 1)"
            self.bottomPageRightLabel?.alpha = 1.0
          }
        } else {
          self.bottomChapterLabel?.alpha = 0.0
          self.bottomPageCenterLabel?.alpha = 0.0
          self.bottomPageRightLabel?.alpha = 0.0
        }
      }
    }

    func forceEnsureContentLoaded() {
      loadContentIfNeeded(force: true)
    }

    private var containerView: UIView?
    private var containerConstraints:
      (
        top: NSLayoutConstraint, leading: NSLayoutConstraint,
        trailing: NSLayoutConstraint, bottom: NSLayoutConstraint
      )?

    private func setupWebView() {
      let config = WKWebViewConfiguration()
      let controller = WKUserContentController()
      // Use weak wrapper to avoid retain cycle (WKUserContentController retains handlers strongly)
      controller.add(WeakScriptMessageHandler(delegate: self), name: "readerBridge")
      config.userContentController = controller

      // Set background to fill entire view (including safe area)
      view.backgroundColor = theme.uiColorBackground

      let container = UIView()
      container.backgroundColor = .clear
      view.addSubview(container)
      container.translatesAutoresizingMaskIntoConstraints = false

      // Container respects safe area (or view edges based on policy), with additional pageInsets
      let top = container.topAnchor.constraint(equalTo: topAnchor, constant: pageInsets.top)
      let leading = container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pageInsets.left)
      let trailing = trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: pageInsets.right)
      let bottom = bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: pageInsets.bottom)
      containerConstraints = (top, leading, trailing, bottom)
      NSLayoutConstraint.activate([top, leading, trailing, bottom])
      containerView = container

      applyContainerInsets()

      webView = WKWebView(frame: .zero, configuration: config)
      webView.navigationDelegate = self
      webView.scrollView.isScrollEnabled = false
      webView.scrollView.bounces = false
      webView.scrollView.showsHorizontalScrollIndicator = false
      webView.scrollView.showsVerticalScrollIndicator = false
      webView.scrollView.contentInsetAdjustmentBehavior = .never
      webView.isOpaque = false
      webView.alpha = 0

      applyTheme()

      container.addSubview(webView)
      webView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        webView.topAnchor.constraint(equalTo: container.topAnchor),
        webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])

      let indicator = UIActivityIndicatorView(style: .medium)
      indicator.hidesWhenStopped = true
      indicator.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      ])
      self.loadingIndicator = indicator
    }

    private func applyTheme() {
      // Background fills entire view (including safe area)
      view.backgroundColor = theme.uiColorBackground
      containerView?.backgroundColor = .clear
      if webView != nil {
        webView.backgroundColor = theme.uiColorBackground
        webView.scrollView.backgroundColor = .clear
      }
      loadingIndicator?.color = theme.uiColorText
    }

    private func applyContainerInsets() {
      guard let containerConstraints else { return }
      containerConstraints.top.constant = pageInsets.top
      containerConstraints.leading.constant = pageInsets.left
      containerConstraints.trailing.constant = pageInsets.right
      containerConstraints.bottom.constant = pageInsets.bottom
      view.layoutIfNeeded()
    }

    private func loadContentIfNeeded(force: Bool) {
      guard let chapterURL, let rootURL else { return }
      let currentURL = webView.url?.standardizedFileURL
      let urlMatches = currentURL == chapterURL.standardizedFileURL

      // If URL matches and content is loaded, just update pagination.
      // We don't hide the webview or show the loader here to avoid flickering
      // when just transitioning within the same chapter.
      if urlMatches && isContentLoaded {
        applyPagination(scrollToPage: currentSubPageIndex)
        return
      }

      // Skip reload if URL matches and not forcing
      if !force && urlMatches {
        return
      }

      // New content loading - show indicator and keep webview active but hidden
      isContentLoaded = false
      pendingPageIndex = currentSubPageIndex
      readyToken += 1

      // Use a near-zero alpha instead of exactly 0.
      // WebKit sometimes throttles layout/JS execution for elements with alpha=0.
      webView.alpha = 0.01
      loadingIndicator?.startAnimating()
      webView.loadFileURL(chapterURL, allowingReadAccessTo: rootURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      isContentLoaded = true
      applyPagination(scrollToPage: pendingPageIndex ?? currentSubPageIndex)
      pendingPageIndex = nil
      // Visibility is handled in userContentController when pagination is ready
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      preferences: WKWebpagePreferences,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
      // Allow initial page load
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow, preferences)
        return
      }

      // Allow file:// URLs for the same domain (CSS, images, etc.)
      if navigationAction.navigationType == .other {
        decisionHandler(.allow, preferences)
        return
      }

      // Handle link clicks
      if navigationAction.navigationType == .linkActivated {
        // Check if this is an internal link (same book navigation)
        if url.scheme == "file" {
          onLinkTap?(url)
          decisionHandler(.cancel, preferences)
          return
        }
        // For external links, could open in Safari later
        decisionHandler(.cancel, preferences)
        return
      }

      decisionHandler(.allow, preferences)
    }

    private func applyPagination(scrollToPage pageIndex: Int) {
      guard isViewLoaded else { return }
      guard isContentLoaded else { return }
      let size = webView.bounds.size
      guard size.width > 0, size.height > 0 else { return }

      // Use a near-zero alpha to indicate transition if not already showing.
      // This prevents WebKit from throttling layout while keeping the view hidden from users.
      if webView.alpha < 0.1 {
        webView.alpha = 0.01
        loadingIndicator?.startAnimating()
      }

      let columnWidth = max(1, Int(size.width))

      // Standardized Readium-based structural CSS
      let paginationCSS = """
          /* Base Viewport & Root */
          html {
            height: 100vh !important;
            width: 100vw !important;
            margin: 0 !important;
            padding: 0 !important;
            overflow: hidden !important;
            -webkit-text-size-adjust: 100% !important;
          }

          body {
            display: block !important;
            margin: 0 !important;
            padding: 0 !important;
            height: 100vh !important;
            width: 100vw !important;
            column-width: \(columnWidth)px !important;
            column-gap: 0 !important;
            column-fill: auto !important;
            background-color: \(theme.backgroundColorHex) !important;
            color: \(theme.textColorHex) !important;
            word-wrap: break-word;
            overflow-wrap: break-word;
            /* Widows/Orphans from Readium standard */
            widows: 2;
            orphans: 2;
          }

          /* Reset all potential document margins that break columns */
          body > *, html > * {
            max-width: 100%;
          }

          /* High-Fidelity Image Handling (Based on Readium Standard) */
          img, svg, video, canvas {
            display: inline-block;
            max-width: 100% !important;
            max-height: 95vh !important;
            height: auto !important;
            object-fit: contain;
            background: transparent !important;
            /* Prevent image splitting between columns */
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
          }

          /* Light/Sepia themes: Use multiply to remove white backgrounds from illustrations.
             This is the standard Readium approach for non-dark themes. */
          :root[data-kmreader-theme="light"] img,
          :root[data-kmreader-theme="light"] svg {
            mix-blend-mode: multiply;
          }

          /* Dark themes: Disable multiply to prevent content from disappearing on black.
             Apply a subtle brightness filter to reduce eye strain from bright images in the dark. */
          :root[data-kmreader-theme="dark"] img,
          :root[data-kmreader-theme="dark"] svg {
            mix-blend-mode: normal;
            filter: brightness(80%);
          }

          /* Fragmentation Control for Headings and Structure */
          h1, h2, h3, h4, h5, h6, dt, figure, tr {
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
          }
          h1, h2, h3, h4, h5, h6 {
            -webkit-column-break-after: avoid;
            break-after: avoid;
          }

          /* CJK Support (from Readium horizontal patches) */
          :lang(ja), :lang(zh), :lang(ko) {
            word-wrap: break-word;
            -webkit-line-break: strict;
            line-break: strict;
            text-align: justify;
            /* Better ruby character alignment */
            ruby-align: center;
          }
          /* Reset unwanted italics for CJK emphasis */
          *:lang(ja), *:lang(zh), *:lang(ko),
          :lang(ja) i, :lang(zh) i, :lang(ko) i,
          :lang(ja) em, :lang(zh) em, :lang(ko) em {
            font-style: normal;
          }
          /* Standard vertical-in-horizontal for numbers/short text */
          span.tcy, span.tate-chu-yoko {
            -webkit-text-combine: horizontal;
            text-combine-upright: all;
          }

          /* Selection & UI Elements */
          ::selection {
            background-color: #b4d8fe;
          }
          a {
            color: inherit;
            text-decoration: underline;
            overflow-wrap: break-word;
          }
        """

      let css = contentCSS + "\n" + paginationCSS

      injectCSS(css) { [weak self] in
        self?.injectPaginationJS(targetPageIndex: pageIndex, preferLastPage: self?.preferLastPageOnReady ?? false)
      }
    }

    private func injectCSS(_ css: String, completion: (() -> Void)? = nil) {
      // Determine if the current theme is dark based on the background color brightness.
      // This allows the CSS to apply theme-specific rules (like image blending).
      let isDark = theme.uiColorBackground.brightness < 0.5
      let themeName = isDark ? "dark" : "light"

      // Use Base64 encoding for the CSS content to avoid any JS string escaping/parsing issues.
      let base64 = Data(css.utf8).base64EncodedString()
      let js = """
          (function() {
            var root = document.documentElement;
            root.setAttribute('data-kmreader-theme', '\(themeName)');

            var meta = document.querySelector('meta[name=viewport]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');

            var style = document.getElementById('kmreader-style');
            if (!style) {
              style = document.createElement('style');
              style.id = 'kmreader-style';
              document.head.appendChild(style);
            }
            style.textContent = atob('\(base64)');
            return true;
          })();
        """

      webView.evaluateJavaScript(js) { _, _ in
        completion?()
      }
    }

    private func injectPaginationJS(targetPageIndex: Int, preferLastPage: Bool) {
      let js = """
          (function() {
            var target = \(targetPageIndex);
            var preferLast = \(preferLastPage ? "true" : "false");

            var waitForImages = function() {
              var images = Array.prototype.slice.call(document.images || []);
              if (!images.length) { return Promise.resolve(); }
              return Promise.all(images.map(function(img) {
                if (img.complete) { return Promise.resolve(); }
                return new Promise(function(resolve) {
                  img.addEventListener('load', resolve, { once: true });
                  img.addEventListener('error', resolve, { once: true });
                });
              }));
            };

            var fontReady = (document.fonts && document.fonts.ready) ? document.fonts.ready : Promise.resolve();
            var readiness = Promise.all([fontReady, waitForImages()]);
            var timeout = new Promise(function(resolve) { setTimeout(resolve, 800); });

            Promise.race([readiness, timeout]).then(function() {
              var lastWidth = 0;
              var stableCount = 0;
              var maxAttempts = 60; // Increased to ~1 second of polling at 60fps
              var attempt = 0;

              var checkLayout = function() {
                attempt++;
                var pageWidth = window.innerWidth || document.documentElement.clientWidth;
                if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }

                var currentWidth = document.body.scrollWidth;

                // Layout is stable if scrollWidth remains constant.
                // Multi-column layout is incremental, so we wait for growth to stop.
                if (currentWidth === lastWidth && currentWidth > 0) {
                  stableCount++;
                } else {
                  stableCount = 0;
                  lastWidth = currentWidth;
                }

                // If we are looking for the last page, we must wait for at least 15 frames 
                // to give the multi-column engine time to expand from the initial 1-page width.
                var isReady = (stableCount >= 5);
                if (preferLast && currentWidth <= pageWidth && attempt < 30) {
                  isReady = false;
                }

                if (isReady || attempt >= maxAttempts) {
                  var total = Math.max(1, Math.ceil(currentWidth / pageWidth));
                  var maxScroll = Math.max(0, currentWidth - pageWidth);
                  var finalTarget = preferLast ? (total - 1) : target;
                  var offset = Math.min(pageWidth * finalTarget, maxScroll);

                  window.scrollTo(offset, 0);
                  if (document.documentElement) { document.documentElement.scrollLeft = offset; }
                  if (document.body) { document.body.scrollLeft = offset; }

                  setTimeout(function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.readerBridge) {
                      window.webkit.messageHandlers.readerBridge.postMessage({
                        type: 'ready',
                        totalPages: total,
                        currentPage: finalTarget
                      });
                    }
                  }, 50);

                  // Restore ResizeObserver to handle late layout shifts (e.g. lazy-loaded images)
                  if (window.ResizeObserver) {
                    var lastW = currentWidth;
                    var ro = new ResizeObserver(function() {
                      var newW = document.body.scrollWidth;
                      if (Math.abs(newW - lastW) > 5) {
                        lastW = newW;
                        var newTotal = Math.max(1, Math.ceil(newW / pageWidth));
                        window.webkit.messageHandlers.readerBridge.postMessage({
                          type: 'pageCountUpdate',
                          totalPages: newTotal
                        });
                      }
                    });
                    ro.observe(document.body);
                  }
                } else {
                  requestAnimationFrame(checkLayout);
                }
              };

              // Start the layout heartbeat
              requestAnimationFrame(checkLayout);
            });
          })();
        """

      webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func scrollToPage(_ pageIndex: Int) {
      guard isContentLoaded else { return }
      let js = """
          (function() {
            var pageWidth = window.innerWidth || document.documentElement.clientWidth;
            if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }
            var maxScroll = Math.max(0, document.body.scrollWidth - pageWidth);
            var offset = Math.min(pageWidth * \(pageIndex), maxScroll);
            window.scrollTo(offset, 0);
            if (document.documentElement) { document.documentElement.scrollLeft = offset; }
            if (document.body) { document.body.scrollLeft = offset; }
          })();
        """
      webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      guard let body = message.body as? [String: Any] else { return }
      guard let type = body["type"] as? String else { return }

      if type == "ready" {
        if let total = body["totalPages"] as? Int {
          let normalizedTotal = max(1, total)
          var actualPage = body["currentPage"] as? Int ?? currentSubPageIndex

          totalPagesInChapter = normalizedTotal
          onPageCountReady?(normalizedTotal)

          // Handle target progression jump if requested (e.g. on initial book open).
          // We ignore this if preferLastPageOnReady is true, as that takes precedence.
          if let progression = targetProgressionOnReady, !preferLastPageOnReady {
            let targetIndex = max(0, min(normalizedTotal - 1, Int(floor(Double(normalizedTotal) * progression))))
            if targetIndex != actualPage {
              actualPage = targetIndex
              scrollToPage(targetIndex)
            }
            targetProgressionOnReady = nil
          }

          // Sync the current sub-page index with the actual page landed on by JS or progression calculation.
          if currentSubPageIndex != actualPage {
            currentSubPageIndex = actualPage
            onPageIndexAdjusted?(actualPage)
          }

          preferLastPageOnReady = false
          updateOverlayLabels()
        }

        // Stop the loading indicator and finally show the WebView content.
        loadingIndicator?.stopAnimating()
        webView.alpha = 1
      } else if type == "pageCountUpdate", let total = body["totalPages"] as? Int {
        // Handle incremental layout updates from ResizeObserver
        let normalizedTotal = max(1, total)
        if totalPagesInChapter != normalizedTotal {
          totalPagesInChapter = normalizedTotal
          onPageCountReady?(normalizedTotal)
          updateOverlayLabels()
        }
      }
    }
  }
#endif
