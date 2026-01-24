//
//  WebPubScrollView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI
  import UIKit
  import WebKit

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

  /// A SwiftUI view that displays EPUB content in scroll mode
  /// Uses a single WKWebView with horizontal scrolling, reusing the same CSS system as WebPubPageView
  struct WebPubScrollView: UIViewControllerRepresentable {
    @Bindable var viewModel: EpubReaderViewModel
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme
    let showingControls: Bool
    let bookTitle: String?
    let onCenterTap: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> ScrollEpubViewController {
      let currentLocation = viewModel.pageLocation(at: viewModel.currentPageIndex)
      let chapterIndex = currentLocation?.chapterIndex ?? 0

      let vc = ScrollEpubViewController(
        chapterURL: viewModel.chapterURL(at: chapterIndex),
        rootURL: viewModel.resourceRootURL,
        pageInsets: viewModel.pageInsets(for: preferences),
        theme: preferences.resolvedTheme(for: colorScheme),
        contentCSS: preferences.makeCSS(theme: preferences.resolvedTheme(for: colorScheme)),
        chapterIndex: chapterIndex,
        totalChapters: viewModel.chapterCount,
        bookTitle: bookTitle,
        chapterTitle: currentLocation?.title,
        totalProgression: currentLocation.flatMap { location in
          viewModel.totalProgression(
            for: viewModel.currentPageIndex,
            location: location,
            chapterProgress: nil
          )
        },
        showingControls: showingControls,
        labelTopOffset: viewModel.labelTopOffset,
        labelBottomOffset: viewModel.labelBottomOffset,
        useSafeArea: viewModel.useSafeArea
      )

      vc.onCenterTap = onCenterTap
      vc.onChapterNavigationNeeded = { [weak viewModel] targetChapterIndex in
        guard let viewModel = viewModel else { return }

        // Determine if we're going forward or backward
        let currentChapterIndex = viewModel.pageLocation(at: viewModel.currentPageIndex)?.chapterIndex ?? 0
        let isGoingBackward = targetChapterIndex < currentChapterIndex

        if isGoingBackward {
          // Going to previous chapter - jump to last page
          let pageCount = viewModel.chapterPageCount(at: targetChapterIndex) ?? 1
          let lastPageIndex = max(0, pageCount - 1)
          if let targetGlobalIndex = viewModel.globalIndexForChapter(targetChapterIndex, pageIndex: lastPageIndex) {
            viewModel.targetPageIndex = targetGlobalIndex
          }
        } else {
          // Going to next chapter - jump to first page
          if let targetGlobalIndex = viewModel.globalIndexForChapter(targetChapterIndex, pageIndex: 0) {
            viewModel.targetPageIndex = targetGlobalIndex
          }
        }
      }
      context.coordinator.viewController = vc

      return vc
    }

    func updateUIViewController(_ uiViewController: ScrollEpubViewController, context: Context) {
      context.coordinator.parent = self

      // Handle TOC navigation via targetPageIndex
      if let targetIndex = viewModel.targetPageIndex,
        targetIndex != viewModel.currentPageIndex,
        let targetLocation = viewModel.pageLocation(at: targetIndex)
      {
        let targetChapterIndex = targetLocation.chapterIndex
        let targetSubPageIndex = targetLocation.pageIndex

        // Check if this is a jump to the last page of a chapter (backward navigation)
        let currentChapterIndex = viewModel.pageLocation(at: viewModel.currentPageIndex)?.chapterIndex ?? 0
        let isGoingBackward = targetChapterIndex < currentChapterIndex
        let isLastPageOfChapter = targetLocation.pageCount > 0 && targetSubPageIndex == targetLocation.pageCount - 1

        // Navigate to target chapter and page
        uiViewController.navigateToPage(
          chapterIndex: targetChapterIndex,
          subPageIndex: targetSubPageIndex,
          jumpToLastPage: isGoingBackward && isLastPageOfChapter
        )

        // Clear targetPageIndex and update current page
        Task { @MainActor in
          viewModel.currentPageIndex = targetIndex
          viewModel.targetPageIndex = nil
          viewModel.pageDidChange(to: targetIndex)
        }
        return
      }

      let currentLocation = viewModel.pageLocation(at: viewModel.currentPageIndex)
      let chapterIndex = currentLocation?.chapterIndex ?? 0

      let pageInsets = viewModel.pageInsets(for: preferences)
      let theme = preferences.resolvedTheme(for: colorScheme)
      let contentCSS = preferences.makeCSS(theme: theme)

      let chapterProgress =
        currentLocation?.pageCount ?? 0 > 0
        ? Double((currentLocation?.pageIndex ?? 0) + 1) / Double(currentLocation?.pageCount ?? 1)
        : nil
      let totalProgression = currentLocation.flatMap { location in
        viewModel.totalProgression(
          for: viewModel.currentPageIndex,
          location: location,
          chapterProgress: chapterProgress
        )
      }

      uiViewController.configure(
        chapterURL: viewModel.chapterURL(at: chapterIndex),
        rootURL: viewModel.resourceRootURL,
        pageInsets: pageInsets,
        theme: theme,
        contentCSS: contentCSS,
        chapterIndex: chapterIndex,
        totalChapters: viewModel.chapterCount,
        bookTitle: bookTitle,
        chapterTitle: currentLocation?.title,
        totalProgression: totalProgression,
        showingControls: showingControls,
        labelTopOffset: viewModel.labelTopOffset,
        labelBottomOffset: viewModel.labelBottomOffset,
        useSafeArea: viewModel.useSafeArea
      )
    }

    class Coordinator: NSObject {
      var parent: WebPubScrollView
      weak var viewController: ScrollEpubViewController?

      init(_ parent: WebPubScrollView) {
        self.parent = parent
      }
    }
  }

  // MARK: - ScrollEpubViewController

  /// A view controller that displays a single EPUB chapter with horizontal scrolling
  /// Reuses the exact same CSS system as EpubPageViewController, just enables horizontal scrolling
  @MainActor
  final class ScrollEpubViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler,
    UIScrollViewDelegate, UIGestureRecognizerDelegate
  {
    private var webView: WKWebView!
    private var chapterIndex: Int
    private var currentSubPageIndex: Int = 0
    private var totalPagesInChapter: Int = 1
    private var pageInsets: UIEdgeInsets
    private var theme: ReaderTheme
    private var contentCSS: String
    private var chapterURL: URL?
    private var rootURL: URL?
    private var lastLayoutSize: CGSize = .zero
    private var isContentLoaded = false
    private var pendingPageIndex: Int?
    private var pendingJumpToLastPage: Bool = false
    private var readyToken: Int = 0

    private var bookTitle: String?
    private var chapterTitle: String?
    private var totalProgression: Double?
    private var showingControls: Bool = false
    private var labelTopOffset: CGFloat
    private var labelBottomOffset: CGFloat
    private var useSafeArea: Bool

    // Chapter navigation
    private var totalChapters: Int = 1
    var onChapterNavigationNeeded: ((Int) -> Void)?

    private var containerView: UIView?
    private var containerConstraints:
      (
        top: NSLayoutConstraint, leading: NSLayoutConstraint,
        trailing: NSLayoutConstraint, bottom: NSLayoutConstraint
      )?

    // Overlay labels
    private var topBookTitleLabel: UILabel?
    private var topProgressLabel: UILabel?
    private var bottomChapterLabel: UILabel?
    private var bottomPageCenterLabel: UILabel?
    private var bottomPageRightLabel: UILabel?

    private var loadingIndicator: UIActivityIndicatorView?

    // Tap gesture handling
    var onCenterTap: (() -> Void)?
    private var tapGestureRecognizer: UITapGestureRecognizer?

    init(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      chapterIndex: Int,
      totalChapters: Int,
      bookTitle: String?,
      chapterTitle: String?,
      totalProgression: Double?,
      showingControls: Bool,
      labelTopOffset: CGFloat,
      labelBottomOffset: CGFloat,
      useSafeArea: Bool
    ) {
      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.pageInsets = pageInsets
      self.theme = theme
      self.contentCSS = contentCSS
      self.chapterIndex = chapterIndex
      self.totalChapters = totalChapters
      self.bookTitle = bookTitle
      self.chapterTitle = chapterTitle
      self.totalProgression = totalProgression
      self.showingControls = showingControls
      self.labelTopOffset = labelTopOffset
      self.labelBottomOffset = labelBottomOffset
      self.useSafeArea = useSafeArea
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupWebView()
      setupOverlayLabels()
      setupTapGesture()
      loadContentIfNeeded(force: true)
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

    private func setupWebView() {
      let config = WKWebViewConfiguration()
      let controller = WKUserContentController()
      // Use weak wrapper to avoid retain cycle
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
      webView.scrollView.delegate = self
      webView.scrollView.isScrollEnabled = true
      webView.scrollView.bounces = true
      webView.scrollView.alwaysBounceVertical = false
      webView.scrollView.showsHorizontalScrollIndicator = false
      webView.scrollView.showsVerticalScrollIndicator = false
      webView.scrollView.contentInsetAdjustmentBehavior = .never
      webView.scrollView.isPagingEnabled = true
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

    private func setupTapGesture() {
      let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      tapRecognizer.delegate = self
      view.addGestureRecognizer(tapRecognizer)
      self.tapGestureRecognizer = tapRecognizer
    }

    private func setupOverlayLabels() {
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

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
      let location = recognizer.location(in: view)
      let viewWidth = view.bounds.width

      // Define tap zones: left 30%, center 40%, right 30%
      let leftZoneEnd = viewWidth * 0.3
      let rightZoneStart = viewWidth * 0.7

      if location.x < leftZoneEnd {
        // Left tap - go to previous page
        scrollToPreviousPage()
      } else if location.x > rightZoneStart {
        // Right tap - go to next page
        scrollToNextPage()
      } else {
        // Center tap - toggle controls
        onCenterTap?()
      }
    }

    private func scrollToPreviousPage() {
      guard isContentLoaded else { return }

      // If at first page of chapter, try to go to previous chapter
      if currentSubPageIndex <= 0 {
        if chapterIndex > 0 {
          onChapterNavigationNeeded?(chapterIndex - 1)
        }
        return
      }

      let newIndex = currentSubPageIndex - 1
      scrollToPage(newIndex)
      currentSubPageIndex = newIndex
      updateOverlayLabels()
    }

    private func scrollToNextPage() {
      guard isContentLoaded else { return }

      // If at last page of chapter, try to go to next chapter
      if currentSubPageIndex >= totalPagesInChapter - 1 {
        if chapterIndex < totalChapters - 1 {
          onChapterNavigationNeeded?(chapterIndex + 1)
        }
        return
      }

      let newIndex = currentSubPageIndex + 1
      scrollToPage(newIndex)
      currentSubPageIndex = newIndex
      updateOverlayLabels()
    }

    func navigateToPage(chapterIndex: Int, subPageIndex: Int, jumpToLastPage: Bool = false) {
      // If navigating to a different chapter, reload the content
      if chapterIndex != self.chapterIndex {
        self.chapterIndex = chapterIndex
        self.pendingPageIndex = subPageIndex
        self.pendingJumpToLastPage = jumpToLastPage
        loadContentIfNeeded(force: true)
      } else {
        // Same chapter - always wait for ready message to ensure correct page count
        self.pendingPageIndex = subPageIndex
        self.pendingJumpToLastPage = jumpToLastPage
        if isContentLoaded {
          applyPagination(scrollToPage: subPageIndex)
        }
      }
    }

    private func applyTheme() {
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

    func configure(
      chapterURL: URL?,
      rootURL: URL?,
      pageInsets: UIEdgeInsets,
      theme: ReaderTheme,
      contentCSS: String,
      chapterIndex: Int,
      totalChapters: Int,
      bookTitle: String?,
      chapterTitle: String?,
      totalProgression: Double?,
      showingControls: Bool,
      labelTopOffset: CGFloat,
      labelBottomOffset: CGFloat,
      useSafeArea: Bool
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
      self.totalChapters = totalChapters
      self.bookTitle = bookTitle
      self.chapterTitle = chapterTitle
      self.totalProgression = totalProgression
      self.showingControls = showingControls
      self.labelTopOffset = labelTopOffset
      self.labelBottomOffset = labelBottomOffset
      self.useSafeArea = useSafeArea

      guard isViewLoaded else { return }

      updateOverlayLabels()

      if appearanceChanged {
        applyContainerInsets()
      }

      applyTheme()
      if shouldReload {
        loadContentIfNeeded(force: true)
      } else if appearanceChanged {
        applyPagination(scrollToPage: currentSubPageIndex)
      }
    }

    private func loadContentIfNeeded(force: Bool) {
      guard let chapterURL, let rootURL else { return }
      let currentURL = webView.url?.standardizedFileURL
      let urlMatches = currentURL == chapterURL.standardizedFileURL

      if urlMatches && isContentLoaded {
        applyPagination(scrollToPage: currentSubPageIndex)
        return
      }

      if !force && urlMatches {
        return
      }

      isContentLoaded = false
      webView.alpha = 0.01
      loadingIndicator?.startAnimating()

      webView.loadFileURL(chapterURL, allowingReadAccessTo: rootURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      isContentLoaded = true
      applyPagination(scrollToPage: pendingPageIndex ?? currentSubPageIndex)
      pendingPageIndex = nil
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      let size = view.bounds.size
      let webViewSize = webView?.bounds.size ?? .zero
      guard size.width > 0, size.height > 0 else {
        return
      }

      if webViewSize != lastLayoutSize {
        lastLayoutSize = webViewSize

        if webViewSize.width > 0 && webViewSize.height > 0 {
          refreshDisplay()
        }
      }
    }

    func refreshDisplay() {
      applyPagination(scrollToPage: currentSubPageIndex)
    }

    private func applyPagination(scrollToPage pageIndex: Int) {
      guard isViewLoaded else { return }
      guard isContentLoaded else { return }
      let size = webView.bounds.size
      guard size.width > 0, size.height > 0 else { return }

      if webView.alpha < 0.1 {
        webView.alpha = 0.01
        loadingIndicator?.startAnimating()
      }

      let columnWidth = max(1, Int(size.width))

      // Use the exact same CSS as WebPubPageView, but allow horizontal scrolling
      let paginationCSS = """
          /* Base Viewport & Root */
          html {
            height: 100vh !important;
            width: 100vw !important;
            margin: 0 !important;
            padding: 0 !important;
            overflow-x: auto !important;
            overflow-y: hidden !important;
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
            widows: 2;
            orphans: 2;
          }

          /* Reset all potential document margins that break columns */
          body > *, html > * {
            max-width: 100%;
          }

          /* CSS Variables for media sizing (Readium standard) */
          :root {
            --RS__maxMediaWidth: 100%;
            --RS__maxMediaHeight: 95vh;
            --RS__boxSizingMedia: border-box;
            --RS__boxSizingTable: border-box;
          }

          /* High-Fidelity Image Handling (Based on Readium Standard) */
          img, svg, video, canvas, audio {
            object-fit: contain;
            width: auto;
            height: auto;
            max-width: var(--RS__maxMediaWidth);
            max-height: var(--RS__maxMediaHeight) !important;
            box-sizing: var(--RS__boxSizingMedia);
            -webkit-column-break-inside: avoid;
            page-break-inside: avoid;
            break-inside: avoid;
          }

          audio[controls] {
            width: revert;
            height: revert;
          }

          table {
            max-width: var(--RS__maxMediaWidth);
            box-sizing: var(--RS__boxSizingTable);
          }

          :root[data-kmreader-theme="light"] img,
          :root[data-kmreader-theme="light"] svg {
            mix-blend-mode: multiply;
          }

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

          /* CJK Support */
          :lang(ja), :lang(zh), :lang(ko) {
            word-wrap: break-word;
            -webkit-line-break: strict;
            line-break: strict;
            text-align: justify;
            ruby-align: center;
          }
          *:lang(ja), *:lang(zh), *:lang(ko),
          :lang(ja) i, :lang(zh) i, :lang(ko) i,
          :lang(ja) em, :lang(zh) em, :lang(ko) em {
            font-style: normal;
          }
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
        self?.injectPaginationJS(targetPageIndex: pageIndex)
      }
    }

    private func scrollToPage(_ pageIndex: Int, animated: Bool = true) {
      guard isContentLoaded else { return }
      let pageWidth = webView.bounds.width
      guard pageWidth > 0 else { return }

      let contentWidth = webView.scrollView.contentSize.width
      let maxOffset = max(0, contentWidth - pageWidth)
      let targetOffset = min(pageWidth * CGFloat(pageIndex), maxOffset)

      webView.scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: animated)
    }

    private func injectPaginationJS(targetPageIndex: Int) {
      let js = """
          (function() {
            var target = \(targetPageIndex);
            var lastReportedPageCount = 0;
            var hasFinalized = false;

            var finalize = function() {
              if (hasFinalized) return;
              hasFinalized = true;

              var pageWidth = window.innerWidth || document.documentElement.clientWidth;
              if (!pageWidth || pageWidth <= 0) { pageWidth = 1; }

              var currentWidth = document.body.scrollWidth;
              var total = Math.max(1, Math.ceil(currentWidth / pageWidth));
              var maxScroll = Math.max(0, currentWidth - pageWidth);

              var finalTarget = target;
              var offset = Math.min(pageWidth * finalTarget, maxScroll);

              window.scrollTo(offset, 0);
              if (document.documentElement) { document.documentElement.scrollLeft = offset; }
              if (document.body) { document.body.scrollLeft = offset; }

              lastReportedPageCount = total;

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

                if (currentW === lastW && currentW > 0) {
                  stableCount++;
                } else {
                  stableCount = 0;
                  lastW = currentW;
                }

                var isProbablyReady = (stableCount >= 4);
                if (target > 0 && currentW <= pageWidth && attempt < 40) {
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

            var globalTimeout = setTimeout(function() {
              finalize();
            }, 10000);

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
              if (document.readyState === 'interactive' || document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                  setTimeout(startOnce, 500);
                });
              }
              window.addEventListener('load', function() {
                startOnce();
              });
            }
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

          // If we need to jump to last page after loading, do it now
          if pendingJumpToLastPage {
            actualPage = max(0, normalizedTotal - 1)
            scrollToPage(actualPage, animated: false)
            pendingJumpToLastPage = false
          }

          if currentSubPageIndex != actualPage {
            currentSubPageIndex = actualPage
          }
        }

        updateOverlayLabels()
        loadingIndicator?.stopAnimating()
        webView.alpha = 1
      }
    }

    private func injectCSS(_ css: String, completion: (() -> Void)? = nil) {
      let isDark = theme.uiColorBackground.brightness < 0.5
      let themeName = isDark ? "dark" : "light"

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

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      updateCurrentPageFromScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
      if !decelerate {
        updateCurrentPageFromScroll()
      }
    }

    func scrollViewWillEndDragging(
      _ scrollView: UIScrollView,
      withVelocity velocity: CGPoint,
      targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
      guard isContentLoaded else { return }
      let pageWidth = webView.bounds.width
      guard pageWidth > 0 else { return }

      let targetOffset = targetContentOffset.pointee.x

      // Check if user is trying to scroll left from the first page
      if currentSubPageIndex == 0 {
        // Detect leftward scroll attempt (negative velocity or trying to scroll before start)
        if velocity.x < -0.1 || targetOffset < -pageWidth * 0.3 {
          if chapterIndex > 0 {
            // Cancel the scroll animation
            targetContentOffset.pointee = CGPoint(x: 0, y: 0)
            // Navigate to previous chapter
            onChapterNavigationNeeded?(chapterIndex - 1)
          }
          return
        }
      }

      // Check if user is trying to scroll right from the last page
      if currentSubPageIndex == totalPagesInChapter - 1 {
        let contentWidth = scrollView.contentSize.width
        let maxOffset = contentWidth - pageWidth
        // Detect rightward scroll attempt (positive velocity or trying to scroll past end)
        if velocity.x > 0.1 || targetOffset > maxOffset + pageWidth * 0.3 {
          if chapterIndex < totalChapters - 1 {
            // Cancel the scroll animation
            targetContentOffset.pointee = CGPoint(x: maxOffset, y: 0)
            // Navigate to next chapter
            onChapterNavigationNeeded?(chapterIndex + 1)
          }
          return
        }
      }
    }

    private func updateCurrentPageFromScroll() {
      guard isContentLoaded else { return }
      let pageWidth = webView.bounds.width
      guard pageWidth > 0 else { return }

      let scrollOffset = webView.scrollView.contentOffset.x
      let newPageIndex = Int(round(scrollOffset / pageWidth))
      let clampedIndex = max(0, min(totalPagesInChapter - 1, newPageIndex))

      if clampedIndex != currentSubPageIndex {
        currentSubPageIndex = clampedIndex
        updateOverlayLabels()
      }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      // Allow tap gesture to work alongside scroll view gestures
      return true
    }
  }
#endif
