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
    let showingControls: Bool
    let bookTitle: String?
    let onCenterTap: () -> Void
    let onEndReached: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
      let spineLocation: UIPageViewController.SpineLocation = .min
      let options: [UIPageViewController.OptionsKey: Any] = [.spineLocation: NSNumber(value: spineLocation.rawValue)]

      let pageVC = UIPageViewController(
        transitionStyle: .pageCurl,
        navigationOrientation: .horizontal,
        options: options
      )
      pageVC.isDoubleSided = false
      pageVC.dataSource = context.coordinator
      pageVC.delegate = context.coordinator
      pageVC.view.backgroundColor = .clear
      context.coordinator.pageViewController = pageVC

      // Allow simultaneous gesture recognition for zoom transition return gesture
      pageVC.gestureRecognizers.forEach { recognizer in
        recognizer.delegate = context.coordinator
      }

      // Use UIPageViewController's native tap gesture for left/right edge page turning
      // Add custom tap gesture for center area to toggle controls
      let centerTapRecognizer = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleCenterTap(_:))
      )
      centerTapRecognizer.cancelsTouchesInView = false
      centerTapRecognizer.delegate = context.coordinator
      pageVC.view.addGestureRecognizer(centerTapRecognizer)

      let initialChapterIndex = viewModel.currentChapterIndex
      let initialPageCount = viewModel.chapterPageCount(at: initialChapterIndex) ?? 1
      let initialPageIndex = max(0, min(viewModel.currentPageIndex, initialPageCount - 1))
      if initialChapterIndex >= 0,
        initialChapterIndex < viewModel.chapterCount,
        let initialVC = context.coordinator.pageViewController(
          chapterIndex: initialChapterIndex,
          subPageIndex: initialPageIndex,
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

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
      context.coordinator.parent = self

      let initialChapterIndex = viewModel.currentChapterIndex
      let initialPageCount = viewModel.chapterPageCount(at: initialChapterIndex) ?? 1
      let initialPageIndex = max(0, min(viewModel.currentPageIndex, initialPageCount - 1))

      if uiViewController.viewControllers?.isEmpty ?? true,
        initialChapterIndex >= 0,
        initialChapterIndex < viewModel.chapterCount,
        let initialVC = context.coordinator.pageViewController(
          chapterIndex: initialChapterIndex,
          subPageIndex: initialPageIndex,
          in: uiViewController
        )
      {
        uiViewController.setViewControllers([initialVC], direction: .forward, animated: false)
        context.coordinator.currentChapterIndex = initialChapterIndex
        context.coordinator.currentPageIndex = initialPageIndex
        if let initialVC = initialVC as? EpubPageViewController {
          context.coordinator.preloadAdjacentPages(for: initialVC, in: uiViewController)
        }
      }

      if let targetChapterIndex = viewModel.targetChapterIndex,
        let targetPageIndex = viewModel.targetPageIndex,
        !context.coordinator.isAnimating,
        targetChapterIndex >= 0,
        targetChapterIndex < viewModel.chapterCount,
        targetChapterIndex != context.coordinator.currentChapterIndex
          || targetPageIndex != context.coordinator.currentPageIndex
      {
        let pageCount = viewModel.chapterPageCount(at: targetChapterIndex) ?? 1
        let isLastPageRequest = targetPageIndex < 0
        let normalizedPageIndex =
          isLastPageRequest
          ? max(0, pageCount - 1)
          : max(0, min(targetPageIndex, pageCount - 1))
        guard
          let targetVC = context.coordinator.pageViewController(
            chapterIndex: targetChapterIndex,
            subPageIndex: normalizedPageIndex,
            in: uiViewController,
            preferLastPageOnReady: isLastPageRequest
          )
        else { return }

        let isForward =
          targetChapterIndex > context.coordinator.currentChapterIndex
          || (targetChapterIndex == context.coordinator.currentChapterIndex
            && normalizedPageIndex > context.coordinator.currentPageIndex)
        let direction: UIPageViewController.NavigationDirection = isForward ? .forward : .reverse

        context.coordinator.isAnimating = true
        uiViewController.setViewControllers(
          [targetVC],
          direction: direction,
          animated: true
        ) { completed in
          context.coordinator.isAnimating = false
          if completed {
            context.coordinator.currentChapterIndex = targetChapterIndex
            context.coordinator.currentPageIndex = normalizedPageIndex
            if let currentVC = uiViewController.viewControllers?.first as? EpubPageViewController {
              context.coordinator.preloadAdjacentPages(for: currentVC, in: uiViewController)
            }
            Task { @MainActor in
              viewModel.currentChapterIndex = targetChapterIndex
              viewModel.currentPageIndex = normalizedPageIndex
              viewModel.targetChapterIndex = nil
              viewModel.targetPageIndex = nil
              viewModel.pageDidChange()
            }
          }
        }
      }

      if let currentVC = uiViewController.viewControllers?.first as? EpubPageViewController {
        let chapterIndex = currentVC.chapterIndex
        let pageInsets = viewModel.pageInsets(for: preferences)
        let theme = preferences.resolvedTheme(for: colorScheme)

        // Ensure the selected font is copied to the resource directory
        if let fontName = preferences.fontFamily.fontName {
          viewModel.ensureFontCopied(fontName: fontName)
        }

        let fontPath = preferences.fontFamily.fontName.flatMap { CustomFontStore.shared.getFontPath(for: $0) }
        let readiumPayload = preferences.makeReadiumPayload(
          theme: theme,
          fontPath: fontPath,
          rootURL: viewModel.resourceRootURL
        )

        guard
          let location = viewModel.pageLocation(
            chapterIndex: chapterIndex,
            pageIndex: currentVC.currentSubPageIndex
          )
        else { return }
        let chapterProgress = location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = viewModel.totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )

        currentVC.configure(
          chapterURL: viewModel.chapterURL(at: chapterIndex),
          rootURL: viewModel.resourceRootURL,
          pageInsets: pageInsets,
          theme: theme,
          contentCSS: readiumPayload.css,
          readiumProperties: readiumPayload.properties,
          publicationLanguage: viewModel.publicationLanguage,
          publicationReadingProgression: viewModel.publicationReadingProgression,
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
      var currentChapterIndex: Int
      var currentPageIndex: Int
      var isAnimating = false
      weak var pageViewController: UIPageViewController?
      private let maxCachedControllers = 5  // Increased from 3 to 5 to reduce eviction during transitions
      private var cachedControllers: [String: EpubPageViewController] = [:]
      private var controllerKeys: [ObjectIdentifier: String] = [:]
      private var pendingControllers: Set<ObjectIdentifier> = []  // Track controllers in transition

      init(_ parent: WebPubPageView) {
        self.parent = parent
        self.currentChapterIndex = parent.viewModel.currentChapterIndex
        self.currentPageIndex = parent.viewModel.currentPageIndex
      }

      private func cacheKey(chapterIndex: Int, pageIndex: Int) -> String {
        "\(chapterIndex)-\(pageIndex)"
      }

      private func configureController(
        _ controller: EpubPageViewController
      ) {
        controller.onPageIndexAdjusted = { [weak self, weak controller] pageIndex in
          guard let self, let controller else { return }
          guard self.pageViewController?.viewControllers?.first === controller else { return }
          let chapterIndex = controller.chapterIndex
          let storedCount = self.parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
          let effectiveCount = max(storedCount, controller.totalPagesInChapter)
          let normalizedPageIndex = max(0, min(pageIndex, effectiveCount - 1))
          if effectiveCount != storedCount {
            self.parent.viewModel.updateChapterPageCount(effectiveCount, for: chapterIndex)
          }
          self.parent.viewModel.currentChapterIndex = chapterIndex
          self.parent.viewModel.currentPageIndex = normalizedPageIndex
          self.currentChapterIndex = chapterIndex
          self.currentPageIndex = normalizedPageIndex
          self.parent.viewModel.pageDidChange()
        }
      }

      func pageViewController(
        chapterIndex: Int,
        subPageIndex: Int,
        in pageViewController: UIPageViewController?,
        preferLastPageOnReady: Bool = false
      ) -> UIViewController? {
        guard chapterIndex >= 0, chapterIndex < parent.viewModel.chapterCount else { return nil }
        let pageCount = parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1

        // Only validate bounds if we're not using preferLastPageOnReady
        // preferLastPageOnReady allows any subPageIndex and will adjust when content loads
        if !preferLastPageOnReady {
          guard subPageIndex >= 0, subPageIndex < pageCount else { return nil }
        } else {
          // For preferLastPageOnReady, ensure subPageIndex is at least 0
          guard subPageIndex >= 0 else { return nil }
        }

        let pageInsets = parent.viewModel.pageInsets(for: parent.preferences)
        let theme = parent.preferences.resolvedTheme(for: parent.colorScheme)

        // Ensure the selected font is copied to the resource directory
        if let fontName = parent.preferences.fontFamily.fontName {
          parent.viewModel.ensureFontCopied(fontName: fontName)
        }

        let fontPath = parent.preferences.fontFamily.fontName.flatMap { CustomFontStore.shared.getFontPath(for: $0) }
        let chapterURL = parent.viewModel.chapterURL(at: chapterIndex)
        let rootURL = parent.viewModel.resourceRootURL
        let readiumPayload = parent.preferences.makeReadiumPayload(
          theme: theme,
          fontPath: fontPath,
          rootURL: rootURL
        )
        let chapterIndexForCallback = chapterIndex
        let onPageCountReady: (Int) -> Void = { [weak viewModel = parent.viewModel] pageCount in
          Task { @MainActor in
            viewModel?.updateChapterPageCount(pageCount, for: chapterIndexForCallback)
          }
        }

        let locationPageIndex = min(max(subPageIndex, 0), max(0, pageCount - 1))
        guard
          let location = parent.viewModel.pageLocation(
            chapterIndex: chapterIndex,
            pageIndex: locationPageIndex
          )
        else { return nil }
        let chapterProgress = location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = parent.viewModel.totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )
        let initialProgression = parent.viewModel.initialProgression(for: chapterIndex)

        let key = cacheKey(chapterIndex: chapterIndex, pageIndex: subPageIndex)
        if let cached = cachedControllers[key] {
          cached.configure(
            chapterURL: chapterURL,
            rootURL: rootURL,
            pageInsets: pageInsets,
            theme: theme,
            contentCSS: readiumPayload.css,
            readiumProperties: readiumPayload.properties,
            publicationLanguage: parent.viewModel.publicationLanguage,
            publicationReadingProgression: parent.viewModel.publicationReadingProgression,
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
            contentCSS: readiumPayload.css,
            readiumProperties: readiumPayload.properties,
            publicationLanguage: parent.viewModel.publicationLanguage,
            publicationReadingProgression: parent.viewModel.publicationReadingProgression,
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
          storeController(reusable, for: key)
          return reusable
        }

        let controller = EpubPageViewController(
          chapterURL: chapterURL,
          rootURL: rootURL,
          pageInsets: pageInsets,
          theme: theme,
          contentCSS: readiumPayload.css,
          readiumProperties: readiumPayload.properties,
          publicationLanguage: parent.viewModel.publicationLanguage,
          publicationReadingProgression: parent.viewModel.publicationReadingProgression,
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
        storeController(controller, for: key)
        return controller
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
      ) -> UIViewController? {
        guard let current = viewController as? EpubPageViewController else { return nil }

        // If we're on the first chapter and first page, there's no previous page
        // Return nil to indicate no previous page exists
        if current.chapterIndex == 0 && current.currentSubPageIndex <= 0 {
          return nil
        }

        // If we're on the first chapter but not the first page
        if current.chapterIndex == 0 && current.currentSubPageIndex > 0 {
          let controller = self.pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: current.currentSubPageIndex - 1,
            in: pageViewController
          )
          // If we can't create the controller, return nil to prevent crash
          return controller
        }

        // If we're not on the first page of current chapter, go to previous page
        if current.currentSubPageIndex > 0 {
          let controller = self.pageViewController(
            chapterIndex: current.chapterIndex,
            subPageIndex: current.currentSubPageIndex - 1,
            in: pageViewController
          )
          return controller
        }

        // We're on the first page of a non-first chapter, go to previous chapter
        let previousChapter = current.chapterIndex - 1
        guard previousChapter >= 0 else { return nil }
        let previousCount = parent.viewModel.chapterPageCount(at: previousChapter) ?? 1

        // Go to last page of previous chapter
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

        let storedCount = parent.viewModel.chapterPageCount(at: current.chapterIndex) ?? 1
        let chapterPageCount = max(storedCount, current.totalPagesInChapter)
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
        // Guard against empty array which can cause crashes
        guard !pendingViewControllers.isEmpty else { return }

        // Track pending controllers to prevent them from being evicted during transition
        for controller in pendingViewControllers {
          pendingControllers.insert(ObjectIdentifier(controller))
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
        // Clear pending controllers tracking
        pendingControllers.removeAll()

        guard completed,
          let currentVC = pageViewController.viewControllers?.first as? EpubPageViewController
        else { return }

        let chapterIndex = currentVC.chapterIndex
        let storedCount = parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
        let effectiveCount = max(storedCount, currentVC.totalPagesInChapter)
        let normalizedPageIndex = max(0, min(currentVC.currentSubPageIndex, effectiveCount - 1))
        if effectiveCount != storedCount {
          parent.viewModel.updateChapterPageCount(effectiveCount, for: chapterIndex)
        }
        currentChapterIndex = chapterIndex
        currentPageIndex = normalizedPageIndex
        preloadAdjacentPages(for: currentVC, in: pageViewController)
        Task { @MainActor in
          parent.viewModel.currentChapterIndex = chapterIndex
          parent.viewModel.currentPageIndex = normalizedPageIndex
          parent.viewModel.pageDidChange()
        }
      }

      @objc func handleCenterTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        let size = recognizer.view?.bounds.size ?? .zero

        // Only handle taps in the center 40% of the screen
        let normalizedX = location.x / size.width
        if normalizedX > 0.3 && normalizedX < 0.7 {
          parent.onCenterTap()
        }
      }

      private func storeController(_ controller: EpubPageViewController, for key: String) {
        let identifier = ObjectIdentifier(controller)
        if let existingKey = controllerKeys[identifier] {
          cachedControllers.removeValue(forKey: existingKey)
        }
        controllerKeys[identifier] = key
        cachedControllers[key] = controller
        if cachedControllers.count > maxCachedControllers {
          evictUnusedControllers()
        }
      }

      private func evictUnusedControllers() {
        // Protect currently visible controllers
        let protectedIDs = Set((pageViewController?.viewControllers ?? []).map { ObjectIdentifier($0) })

        // Also protect pending controllers (those in transition)
        let allProtectedIDs = protectedIDs.union(pendingControllers)

        for (key, controller) in cachedControllers {
          if cachedControllers.count <= maxCachedControllers {
            break
          }
          let identifier = ObjectIdentifier(controller)
          if !allProtectedIDs.contains(identifier) {
            cachedControllers.removeValue(forKey: key)
            controllerKeys.removeValue(forKey: identifier)
          }
        }
      }

      func preloadAdjacentPages(for current: EpubPageViewController, in pageVC: UIPageViewController) {
        let storedCount = parent.viewModel.chapterPageCount(at: current.chapterIndex) ?? 1
        let chapterPageCount = max(storedCount, current.totalPagesInChapter)
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

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pageVC = pageViewController,
          let currentVC = pageVC.viewControllers?.first as? EpubPageViewController
        else {
          return true
        }

        // Check if this is UIPageViewController's internal gesture
        guard gestureRecognizer.view === pageVC.view || gestureRecognizer.view?.superview === pageVC.view else {
          return true
        }

        // Determine if we're at a boundary
        let isAtFirstPage = currentVC.chapterIndex == 0 && currentVC.currentSubPageIndex <= 0
        let lastChapterIndex = parent.viewModel.chapterCount - 1
        let isAtLastPage: Bool = {
          if currentVC.chapterIndex == lastChapterIndex {
            let storedCount = parent.viewModel.chapterPageCount(at: lastChapterIndex) ?? 1
            let pageCount = max(storedCount, currentVC.totalPagesInChapter)
            return currentVC.currentSubPageIndex >= pageCount - 1
          }
          return false
        }()

        // For tap gestures, check tap location
        if let tapGesture = gestureRecognizer as? UITapGestureRecognizer {
          let location = tapGesture.location(in: pageVC.view)
          let viewWidth = pageVC.view.bounds.width
          let tapZoneWidth = viewWidth * 0.3

          // Block left tap at first page
          if isAtFirstPage && location.x < tapZoneWidth {
            return false
          }

          // Block right tap at last page
          if isAtLastPage && location.x > viewWidth - tapZoneWidth {
            parent.onEndReached()
            return false
          }
        }
        // For pan gestures, check the translation direction
        else if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
          let translation = panGesture.translation(in: pageVC.view)

          // Block backward swipe (left to right, positive translation) at first page
          if isAtFirstPage && translation.x > 0 {
            return false
          }

          // Block forward swipe (right to left, negative translation) at last page
          if isAtLastPage && translation.x < 0 {
            parent.onEndReached()
            return false
          }
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

  @MainActor
  final class EpubPageViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    var chapterIndex: Int
    var currentSubPageIndex: Int
    var totalPagesInChapter: Int
    private var pageInsets: UIEdgeInsets
    private var theme: ReaderTheme
    private var contentCSS: String
    private var readiumProperties: [String: String?]
    private var publicationLanguage: String?
    private var publicationReadingProgression: WebPubReadingProgression?
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
      readiumProperties: [String: String?],
      publicationLanguage: String?,
      publicationReadingProgression: WebPubReadingProgression?,
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
      self.readiumProperties = readiumProperties
      self.publicationLanguage = publicationLanguage
      self.publicationReadingProgression = publicationReadingProgression
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

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      // Force layout and refresh if WebView size was 0 before
      // This handles cases where UIPageViewController hasn't laid out the WebView yet
      let webViewSize = webView?.bounds.size ?? .zero
      if webViewSize.width > 0 && webViewSize.height > 0 && webViewSize != lastLayoutSize {
        lastLayoutSize = webViewSize
        refreshDisplay()
      }
    }

    @objc private func handleAppDidBecomeActive() {
      refreshDisplay()
      updateOverlayLabels()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      let size = view.bounds.size
      let webViewSize = webView?.bounds.size ?? .zero
      guard size.width > 0, size.height > 0 else {
        return
      }

      // Always track WebView size changes, even if it's currently 0x0
      // This ensures we detect when WebView transitions from 0x0 to valid size
      if webViewSize != lastLayoutSize {
        lastLayoutSize = webViewSize

        // Only refresh if WebView has valid size
        if webViewSize.width > 0 && webViewSize.height > 0 {
          refreshDisplay()
          updateOverlayLabels()
        }
      }
    }

    func configure(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      readiumProperties: [String: String?],
      publicationLanguage: String?,
      publicationReadingProgression: WebPubReadingProgression?,
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
        || readiumProperties != self.readiumProperties
        || publicationLanguage != self.publicationLanguage
        || publicationReadingProgression != self.publicationReadingProgression
        || labelTopOffset != self.labelTopOffset
        || labelBottomOffset != self.labelBottomOffset
        || useSafeArea != self.useSafeArea

      // Reset layout size when chapter changes to ensure proper size detection
      if chapterIndex != self.chapterIndex {
        lastLayoutSize = .zero
      }

      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.pageInsets = pageInsets
      self.theme = theme
      self.contentCSS = contentCSS
      self.readiumProperties = readiumProperties
      self.publicationLanguage = publicationLanguage
      self.publicationReadingProgression = publicationReadingProgression
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
        if isContentLoaded {
          scrollToPage(currentSubPageIndex)
        } else {
          pendingPageIndex = currentSubPageIndex
        }
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
      bookTitleLabel.textColor = theme.uiColorText.withAlphaComponent(0.6)
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
      progressLabel.textColor = theme.uiColorText.withAlphaComponent(0.6)
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
      chapterLabel.textColor = theme.uiColorText.withAlphaComponent(0.6)
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
      pageCenterLabel.textColor = theme.uiColorText.withAlphaComponent(0.6)
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
      pageRightLabel.textColor = theme.uiColorText.withAlphaComponent(0.6)
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

      // Update overlay label colors
      let labelColor = theme.uiColorText.withAlphaComponent(0.6)
      topBookTitleLabel?.textColor = labelColor
      topProgressLabel?.textColor = labelColor
      bottomChapterLabel?.textColor = labelColor
      bottomPageCenterLabel?.textColor = labelColor
      bottomPageRightLabel?.textColor = labelColor
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

      // Only show loading indicator if WebView has valid size (is visible)
      // For pre-loaded pages with 0x0 size, don't show indicator
      let webViewSize = webView.bounds.size
      if webViewSize.width > 0 && webViewSize.height > 0 {
        loadingIndicator?.startAnimating()
      }

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
          /* Pagination Layout */
          :root {
            height: 100vh !important;
            width: 100vw !important;
            max-width: 100vw !important;
            max-height: 100vh !important;
            min-width: 100vw !important;
            min-height: 100vh !important;
            padding: 0 !important;
            margin: 0 !important;
            -webkit-columns: auto auto !important;
            -moz-columns: auto auto !important;
            columns: auto auto !important;
            -webkit-column-width: auto !important;
            -moz-column-width: auto !important;
            column-width: auto !important;
            -webkit-column-count: auto !important;
            -moz-column-count: auto !important;
            column-count: auto !important;
            -webkit-column-gap: 0 !important;
            -moz-column-gap: 0 !important;
            column-gap: 0 !important;
          }

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
          }
        """

      let css = contentCSS + "\n" + paginationCSS

      injectCSS(
        css,
        readiumProperties: readiumProperties,
        language: publicationLanguage,
        readingProgression: publicationReadingProgression
      ) { [weak self] in
        self?.injectPaginationJS(targetPageIndex: pageIndex, preferLastPage: self?.preferLastPageOnReady ?? false)
      }
    }

    private func injectCSS(
      _ css: String,
      readiumProperties: [String: String?],
      language: String?,
      readingProgression: WebPubReadingProgression?,
      completion: (() -> Void)? = nil
    ) {
      // Determine if the current theme is dark based on the background color brightness.
      // This allows the CSS to apply theme-specific rules (like image blending).
      let isDark = theme.uiColorBackground.brightness < 0.5
      let themeName = isDark ? "dark" : "light"

      let readiumAssets = ReadiumCSSLoader.cssAssets(
        language: language,
        readingProgression: readingProgression
      )
      let readiumVariant = ReadiumCSSLoader.resolveVariantSubdirectory(
        language: language,
        readingProgression: readingProgression
      )
      let shouldSetDir = readiumVariant == "rtl"

      let readiumBefore = Data(readiumAssets.before.utf8).base64EncodedString()
      let readiumDefault = Data(readiumAssets.defaultCSS.utf8).base64EncodedString()
      let readiumAfter = Data(readiumAssets.after.utf8).base64EncodedString()
      let customCSS = Data(css.utf8).base64EncodedString()

      var properties: [String: Any] = [:]
      for (key, value) in readiumProperties {
        properties[key] = value ?? NSNull()
      }
      let propertiesJSON: String = {
        guard
          let data = try? JSONSerialization.data(withJSONObject: properties, options: []),
          let json = String(data: data, encoding: .utf8)
        else {
          return "{}"
        }
        return json
      }()
      let languageJSON: String = {
        guard let language else { return "null" }
        var escaped = language
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
      }()

      let js = """
          (function() {
            var root = document.documentElement;
            root.setAttribute('data-kmreader-theme', '\(themeName)');
            var lang = \(languageJSON);
            if (lang) {
              if (!root.hasAttribute('lang')) {
                root.setAttribute('lang', lang);
              }
              if (!root.hasAttribute('xml:lang')) {
                root.setAttribute('xml:lang', lang);
              }
              if (document.body) {
                if (!document.body.hasAttribute('lang')) {
                  document.body.setAttribute('lang', lang);
                }
                if (!document.body.hasAttribute('xml:lang')) {
                  document.body.setAttribute('xml:lang', lang);
                }
              }
            }
            if (\(shouldSetDir ? "true" : "false")) {
              root.setAttribute('dir', 'rtl');
              if (document.body) {
                document.body.setAttribute('dir', 'rtl');
              }
            }

            var props = \(propertiesJSON);
            Object.keys(props).forEach(function(key) {
              var value = props[key];
              if (value === null || value === undefined) {
                root.style.removeProperty(key);
              } else {
                root.style.setProperty(key, value, 'important');
              }
            });

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
            var hasStyles = document.querySelector("link[rel~='stylesheet'], style:not(#kmreader-style)") !== null;
            var css = atob('\(readiumBefore)') + "\\n"
              + (hasStyles ? "" : atob('\(readiumDefault)') + "\\n")
              + atob('\(readiumAfter)') + "\\n"
              + atob('\(customCSS)');
            style.textContent = css;
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
            var lastReportedPageCount = 0;
            var resizeDebounceTimer = null;
            var hasFinalized = false;

            var finalize = function() {
              if (hasFinalized) return;
              hasFinalized = true;

              var pageWidth = window.innerWidth || document.documentElement.clientWidth;
              if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }

              var currentWidth = document.body.scrollWidth;
              var total = Math.max(1, Math.ceil(currentWidth / pageWidth));
              var maxScroll = Math.max(0, currentWidth - pageWidth);

              // Recalculate target to ensure we land on the actual last page if requested.
              var finalTarget = preferLast ? (total - 1) : target;
              var offset = Math.min(pageWidth * finalTarget, maxScroll);

              // Apply scroll position immediately.
              window.scrollTo(offset, 0);
              if (document.documentElement) { document.documentElement.scrollLeft = offset; }
              if (document.body) { document.body.scrollLeft = offset; }

              // Store initial page count for ResizeObserver comparison
              lastReportedPageCount = total;

              // Small delay to ensure WebKit commits the paint before signaling readiness.
              setTimeout(function() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.readerBridge) {
                  window.webkit.messageHandlers.readerBridge.postMessage({
                    type: 'ready',
                    totalPages: total,
                    currentPage: finalTarget
                  });
                }
              }, 60);
            };

            var startLayoutCheck = function() {
              var lastW = document.body.scrollWidth;
              var stableCount = 0;
              var attempt = 0;

              var check = function() {
                if (hasFinalized) return;

                attempt++;
                var currentW = document.body.scrollWidth;
                var pageWidth = window.innerWidth || document.documentElement.clientWidth;

                // Readium-style stability check:
                // Wait for the multi-column layout to expand beyond 1 page if we expect more.
                if (currentW === lastW && currentW > 0) {
                  stableCount++;
                } else {
                  stableCount = 0;
                  lastW = currentW;
                }

                // If jumping to a deep page (preferLast or target > 0),
                // we must wait for the width to actually represent multiple pages.
                var isProbablyReady = (stableCount >= 4);
                if ((preferLast || target > 0) && currentW <= pageWidth && attempt < 40) {
                  isProbablyReady = false;
                }

                if (isProbablyReady || attempt >= 60) {
                  finalize();
                } else {
                  window.requestAnimationFrame(check);
                }
              };
              window.requestAnimationFrame(check);
            };

            // Global timeout: force finalize after 10 seconds regardless of load state
            var globalTimeout = setTimeout(function() {
              finalize();
            }, 10000);

            // Use the 'load' event to ensure all resources are fetched before calculating layout.
            // But also start on DOMContentLoaded as a fallback if load takes too long
            var loadStarted = false;
            var startOnce = function() {
              if (loadStarted) return;
              loadStarted = true;
              clearTimeout(globalTimeout);
              startLayoutCheck();
            };

            if (document.readyState === 'complete') {
              startOnce();
            } else {
              // Start on DOMContentLoaded (DOM ready, images may still be loading)
              if (document.readyState === 'interactive' || document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                  // Give images a brief moment to start loading
                  setTimeout(startOnce, 500);
                });
              }
              // Also listen for full load (all resources including images)
              window.addEventListener('load', function() {
                startOnce();
              });
            }

            // Continuous monitoring for late-loading resources (like gaiji or large images).
            // Only enable during initial load phase, then lock the page count once stable.
            if (window.ResizeObserver) {
              var stableScrollWidth = 0;
              var stableCheckCount = 0;
              var isPageCountLocked = false;
              var resizeDebounceTimer = null;

              var ro = new ResizeObserver(function() {
                // Once locked, stop monitoring
                if (isPageCountLocked) {
                  return;
                }

                // Debounce: wait for 1000ms of stability before checking
                if (resizeDebounceTimer) {
                  clearTimeout(resizeDebounceTimer);
                }

                resizeDebounceTimer = setTimeout(function() {
                  var w = document.body.scrollWidth;
                  var pageWidth = window.innerWidth || document.documentElement.clientWidth;

                  if (pageWidth > 0 && w > 0) {
                    // Check if scrollWidth has stabilized
                    if (w === stableScrollWidth) {
                      stableCheckCount++;
                      // After 3 consecutive stable checks (3 seconds total), lock the page count
                      if (stableCheckCount >= 3) {
                        isPageCountLocked = true;
                        ro.disconnect();
                        return;
                      }
                    } else {
                      // ScrollWidth changed, reset stability counter
                      stableCheckCount = 0;
                      stableScrollWidth = w;

                      var t = Math.max(1, Math.ceil(w / pageWidth));
                      // Only report if page count changed significantly (more than 1 page difference)
                      if (Math.abs(t - lastReportedPageCount) > 1) {
                        lastReportedPageCount = t;
                        window.webkit.messageHandlers.readerBridge.postMessage({
                          type: 'pageCountUpdate',
                          totalPages: t
                        });
                      }
                    }
                  }
                }, 1000);
              });

              // Start observing after a delay to let initial layout settle
              setTimeout(function() {
                stableScrollWidth = document.body.scrollWidth;
                ro.observe(document.body);
              }, 1500);
            }
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
