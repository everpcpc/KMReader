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
    var uiColorBackground: UIColor { UIColor(hex: backgroundColor) ?? .white }
    var uiColorText: UIColor { UIColor(hex: textColor) ?? .black }
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
  }

  struct WebPubPageView: UIViewControllerRepresentable {
    @Bindable var viewModel: EpubReaderViewModel
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme
    let onTap: (CGPoint, CGSize) -> Void
    let transitionStyle: UIPageViewController.TransitionStyle

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
        currentVC.configure(
          chapterURL: viewModel.chapterURL(at: chapterIndex),
          rootURL: viewModel.resourceRootURL,
          pageInsets: pageInsets,
          theme: theme,
          contentCSS: contentCSS,
          chapterIndex: chapterIndex,
          subPageIndex: currentVC.currentSubPageIndex,
          totalPages: currentVC.totalPagesInChapter,
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
      weak var pageViewController: UIPageViewController?
      private let maxCachedControllers = 3
      private var cachedControllers: [Int: EpubPageViewController] = [:]
      private var controllerKeys: [ObjectIdentifier: Int] = [:]

      init(_ parent: WebPubPageView) {
        self.parent = parent
        self.currentPageIndex = parent.viewModel.currentPageIndex
      }

      private func configureController(
        _ controller: EpubPageViewController,
        preferLastPageOnReady: Bool
      ) {
        controller.preferLastPageOnReady = preferLastPageOnReady
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
        guard let pageCount = parent.viewModel.chapterPageCount(at: chapterIndex) else { return nil }
        guard subPageIndex >= 0, subPageIndex < pageCount else { return nil }

        let globalIndex = parent.viewModel.globalIndexForChapter(chapterIndex, pageIndex: subPageIndex) ?? 0
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
            onPageCountReady: onPageCountReady
          )
          configureController(cached, preferLastPageOnReady: preferLastPageOnReady)
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
            onPageCountReady: onPageCountReady
          )
          configureController(reusable, preferLastPageOnReady: preferLastPageOnReady)
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
          onPageCountReady: onPageCountReady
        )
        configureController(controller, preferLastPageOnReady: preferLastPageOnReady)
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
        let preferLastPageOnReady = previousCount <= 1

        let controller = self.pageViewController(
          chapterIndex: previousChapter,
          subPageIndex: max(0, previousCount - 1),
          in: pageViewController,
          preferLastPageOnReady: preferLastPageOnReady
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

      @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
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

    init(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      chapterIndex: Int,
      subPageIndex: Int,
      totalPages: Int,
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
      self.onPageCountReady = onPageCountReady
      self.onLinkTap = nil
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      let webView = webView
      Task { @MainActor in
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "readerBridge")
      }
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupWebView()
      loadContentIfNeeded(force: true)
    }

    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      refreshDisplay()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      let size = view.bounds.size
      guard size.width > 0, size.height > 0 else { return }
      if size != lastLayoutSize {
        lastLayoutSize = size
        refreshDisplay()
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
      onPageCountReady: ((Int) -> Void)?
    ) {
      let shouldReload = chapterURL != self.chapterURL || rootURL != self.rootURL
      let appearanceChanged =
        theme != self.theme
        || pageInsets != self.pageInsets
        || contentCSS != self.contentCSS

      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.pageInsets = pageInsets
      self.theme = theme
      self.contentCSS = contentCSS
      self.chapterIndex = chapterIndex
      self.currentSubPageIndex = subPageIndex
      self.totalPagesInChapter = totalPages
      self.onPageCountReady = onPageCountReady

      guard isViewLoaded else { return }

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

    func forceEnsureContentLoaded() {
      loadContentIfNeeded(force: true)
    }

    private var containerView: UIView?
    private var containerConstraints: (top: NSLayoutConstraint, leading: NSLayoutConstraint,
      trailing: NSLayoutConstraint, bottom: NSLayoutConstraint)?

    private func setupWebView() {
      let config = WKWebViewConfiguration()
      let controller = WKUserContentController()
      controller.add(self, name: "readerBridge")
      config.userContentController = controller

      let container = UIView()
      container.backgroundColor = .clear
      view.addSubview(container)
      container.translatesAutoresizingMaskIntoConstraints = false
      let top = container.topAnchor.constraint(equalTo: view.topAnchor, constant: pageInsets.top)
      let leading = container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pageInsets.left)
      let trailing = view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: pageInsets.right)
      let bottom = view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: pageInsets.bottom)
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
    }

    private func applyTheme() {
      view.backgroundColor = theme.uiColorBackground
      containerView?.backgroundColor = .clear
      if webView != nil {
        webView.backgroundColor = theme.uiColorBackground
        webView.scrollView.backgroundColor = .clear
      }
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

      // If URL matches and content is loaded, just refresh pagination without reloading
      if urlMatches && isContentLoaded {
        applyPagination(scrollToPage: currentSubPageIndex)
        // Ensure webView is visible for already-loaded content
        webView.alpha = 1
        return
      }

      // Skip reload if URL matches and not forcing
      if !force && urlMatches {
        return
      }

      isContentLoaded = false
      pendingPageIndex = currentSubPageIndex
      readyToken += 1
      webView.alpha = 0
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

      // With outer insets, the webView bounds already represent the content area.
      let columnWidth = max(1, Int(size.width))
      let paginationCSS = """
          html, body {
            height: 100vh !important;
            width: 100vw !important;
            margin: 0 !important;
            padding: 0 !important;
            overflow: hidden !important;
            -webkit-text-size-adjust: 100% !important;
            text-size-adjust: 100% !important;
          }
          body {
            box-sizing: border-box !important;
            column-width: \(columnWidth)px !important;
            column-gap: 0 !important;
            column-fill: auto !important;
            background-color: \(theme.backgroundColor) !important;
            color: \(theme.textColor) !important;
            widows: 2;
            orphans: 2;
          }
          *, *::before, *::after { box-sizing: border-box; }

          /* Fragmentation: prevent awkward breaks */
          h1, h2, h3, h4, h5, h6, dt, figure, tr {
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
          }
          h2, h3, h4, h5, h6, dt, hr, caption {
            -webkit-column-break-after: avoid;
            break-after: avoid;
          }

          /* CJK language support */
          :lang(ja), :lang(zh), :lang(ko) {
            word-wrap: break-word;
            -webkit-line-break: strict;
            line-break: strict;
          }
          *:lang(ja), *:lang(zh), *:lang(ko),
          :lang(ja) cite, :lang(ja) dfn, :lang(ja) em, :lang(ja) i,
          :lang(zh) cite, :lang(zh) dfn, :lang(zh) em, :lang(zh) i,
          :lang(ko) cite, :lang(ko) dfn, :lang(ko) em, :lang(ko) i {
            font-style: normal;
          }

          /* Images and media */
          img, svg, video, canvas {
            max-width: 100% !important;
            height: auto !important;
            max-height: 95vh !important;
            object-fit: contain;
            background: transparent !important;
            mix-blend-mode: multiply;
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
          }

          /* Wrap long links and headings */
          a, h1, h2, h3, h4, h5, h6 {
            word-wrap: break-word;
          }

          /* Selection styling */
          ::selection {
            background-color: #b4d8fe;
          }
        """
      let css = contentCSS + "\n" + paginationCSS

      injectCSS(css) { [weak self] in
        self?.injectPaginationJS(targetPageIndex: pageIndex, preferLastPage: self?.preferLastPageOnReady ?? false)
      }
    }

    private func injectCSS(_ css: String, completion: (() -> Void)? = nil) {
      let sanitized = css.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
      let js = """
          (function() {
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
            style.innerHTML = `\(sanitized)`;
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
            document.fonts.ready.then(function() {
              requestAnimationFrame(function() {
                var pageWidth = window.innerWidth || document.documentElement.clientWidth;
                if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }
                var total = Math.max(1, Math.ceil(document.body.scrollWidth / pageWidth));
                if (preferLast) {
                  target = Math.max(0, total - 1);
                }
                var maxScroll = Math.max(0, document.body.scrollWidth - pageWidth);
                var desired = pageWidth * target;
                var offset = Math.min(desired, maxScroll);
                window.scrollTo(offset, 0);
                if (document.documentElement) { document.documentElement.scrollLeft = offset; }
                if (document.body) { document.body.scrollLeft = offset; }
                requestAnimationFrame(function() {
                  window.scrollTo(offset, 0);
                  if (document.documentElement) { document.documentElement.scrollLeft = offset; }
                  if (document.body) { document.body.scrollLeft = offset; }
                  // Send ready message AFTER scroll is complete
                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.readerBridge) {
                    window.webkit.messageHandlers.readerBridge.postMessage({
                      type: 'ready',
                      totalPages: total
                    });
                  }
                });
              });
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
      if type == "ready", let total = body["totalPages"] as? Int {
        let normalized = max(1, total)
        totalPagesInChapter = normalized
        onPageCountReady?(normalized)

        if preferLastPageOnReady, normalized > 1 {
          let lastIndex = normalized - 1
          if currentSubPageIndex != lastIndex {
            currentSubPageIndex = lastIndex
            scrollToPage(lastIndex)
            onPageIndexAdjusted?(lastIndex)
          }
          preferLastPageOnReady = false
        }

        // Show immediately without animation to prevent white flash
        webView.alpha = 1
      }
    }
  }
#endif
