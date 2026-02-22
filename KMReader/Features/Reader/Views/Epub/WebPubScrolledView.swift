//
// WebPubScrolledView.swift
//
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

  /// A SwiftUI view that displays EPUB content in continuous vertical scroll mode.
  struct WebPubScrolledView: UIViewControllerRepresentable {
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

    func makeUIViewController(context: Context) -> ScrolledEpubViewController {
      let chapterIndex = viewModel.currentChapterIndex
      let pageIndex = viewModel.currentPageIndex
      let currentLocation = viewModel.pageLocation(chapterIndex: chapterIndex, pageIndex: pageIndex)
      let initialProgression = viewModel.initialProgression(for: chapterIndex)

      let theme = preferences.resolvedTheme(for: colorScheme)
      let fontPath = preferences.fontFamily.fontName.flatMap { CustomFontStore.shared.getFontPath(for: $0) }
      let readiumPayload = preferences.makeReadiumPayload(
        theme: theme,
        fontPath: fontPath,
        rootURL: viewModel.resourceRootURL
      )

      let vc = ScrolledEpubViewController(
        chapterURL: viewModel.chapterURL(at: chapterIndex),
        rootURL: viewModel.resourceRootURL,
        containerInsets: viewModel.containerInsetsForLabels(),
        tapScrollPercentage: preferences.tapScrollPercentage,
        theme: theme,
        contentCSS: readiumPayload.css,
        readiumProperties: readiumPayload.properties,
        publicationLanguage: viewModel.publicationLanguage,
        publicationReadingProgression: viewModel.publicationReadingProgression,
        chapterIndex: chapterIndex,
        initialSubPageIndex: pageIndex,
        targetProgressionOnReady: initialProgression,
        totalChapters: viewModel.chapterCount,
        bookTitle: bookTitle,
        chapterTitle: currentLocation?.title,
        totalProgression: currentLocation.flatMap { location in
          viewModel.totalProgression(
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
      vc.onEndReached = onEndReached
      vc.onChapterNavigationNeeded = { [weak viewModel] targetChapterIndex in
        guard let viewModel = viewModel else { return }

        // Determine if we're going forward or backward
        let currentChapterIndex = viewModel.currentChapterIndex
        let isGoingBackward = targetChapterIndex < currentChapterIndex

        if isGoingBackward {
          // Going to previous chapter - jump to last page
          viewModel.targetChapterIndex = targetChapterIndex
          viewModel.targetPageIndex = -1
        } else {
          // Going to next chapter - jump to first page
          viewModel.targetChapterIndex = targetChapterIndex
          viewModel.targetPageIndex = 0
        }
        Task { @MainActor in
          viewModel.pageDidChange()
        }
      }
      vc.onPageDidChange = { [weak viewModel] chapterIndex, pageIndex in
        guard let viewModel = viewModel else { return }
        let normalizedPageIndex = max(0, pageIndex)
        viewModel.currentChapterIndex = chapterIndex
        viewModel.currentPageIndex = normalizedPageIndex
        let pageCount = viewModel.chapterPageCount(at: chapterIndex) ?? 1
        if normalizedPageIndex >= pageCount {
          viewModel.updateChapterPageCount(normalizedPageIndex + 1, for: chapterIndex)
        }
        viewModel.pageDidChange()
      }
      vc.onPageCountReady = { [weak viewModel] chapterIndex, pageCount in
        Task { @MainActor in
          viewModel?.updateChapterPageCount(pageCount, for: chapterIndex)
        }
      }
      context.coordinator.viewController = vc

      return vc
    }

    func updateUIViewController(_ uiViewController: ScrolledEpubViewController, context: Context) {
      context.coordinator.parent = self
      uiViewController.onEndReached = onEndReached

      // Handle TOC navigation via targetPageIndex
      if let targetChapterIndex = viewModel.targetChapterIndex,
        let targetPageIndex = viewModel.targetPageIndex,
        targetChapterIndex >= 0,
        targetChapterIndex < viewModel.chapterCount
      {
        let uiChapterIndex = uiViewController.currentChapterIndex
        let uiPageIndex = uiViewController.currentPageIndex
        let pageCount = viewModel.chapterPageCount(at: targetChapterIndex) ?? 1
        let isLastPageRequest = targetPageIndex < 0
        let normalizedPageIndex =
          isLastPageRequest
          ? max(0, pageCount - 1)
          : max(0, min(targetPageIndex, pageCount - 1))
        let shouldNavigate =
          targetChapterIndex != uiChapterIndex
          || normalizedPageIndex != uiPageIndex

        if shouldNavigate {
          // Check if this is a jump to the last page of a chapter (backward navigation)
          let isGoingBackward = targetChapterIndex < uiChapterIndex
          let isLastPageOfChapter = isLastPageRequest || normalizedPageIndex == max(0, pageCount - 1)

          // Navigate to target chapter and page
          uiViewController.navigateToPage(
            chapterIndex: targetChapterIndex,
            subPageIndex: normalizedPageIndex,
            jumpToLastPage: isGoingBackward && isLastPageOfChapter
          )

          // Clear targetPageIndex and update current page
          Task { @MainActor in
            viewModel.currentChapterIndex = targetChapterIndex
            viewModel.currentPageIndex = normalizedPageIndex
            viewModel.targetChapterIndex = nil
            viewModel.targetPageIndex = nil
            viewModel.pageDidChange()
          }
          return
        }

        Task { @MainActor in
          if viewModel.currentChapterIndex != targetChapterIndex
            || viewModel.currentPageIndex != normalizedPageIndex
          {
            viewModel.currentChapterIndex = targetChapterIndex
            viewModel.currentPageIndex = normalizedPageIndex
            viewModel.pageDidChange()
          }
          viewModel.targetChapterIndex = nil
          viewModel.targetPageIndex = nil
        }
      }

      let chapterIndex = viewModel.currentChapterIndex
      let pageIndex = viewModel.currentPageIndex
      let currentLocation = viewModel.pageLocation(chapterIndex: chapterIndex, pageIndex: pageIndex)

      let containerInsets = viewModel.containerInsetsForLabels()
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

      let chapterProgress =
        currentLocation?.pageCount ?? 0 > 0
        ? Double((currentLocation?.pageIndex ?? 0) + 1) / Double(currentLocation?.pageCount ?? 1)
        : nil
      let totalProgression = currentLocation.flatMap { location in
        viewModel.totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )
      }

      uiViewController.configure(
        chapterURL: viewModel.chapterURL(at: chapterIndex),
        rootURL: viewModel.resourceRootURL,
        containerInsets: containerInsets,
        tapScrollPercentage: preferences.tapScrollPercentage,
        theme: theme,
        contentCSS: readiumPayload.css,
        readiumProperties: readiumPayload.properties,
        publicationLanguage: viewModel.publicationLanguage,
        publicationReadingProgression: viewModel.publicationReadingProgression,
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
      var parent: WebPubScrolledView
      weak var viewController: ScrolledEpubViewController?

      init(_ parent: WebPubScrolledView) {
        self.parent = parent
      }
    }
  }

  // MARK: - ScrolledEpubViewController

  /// A view controller that displays a single EPUB chapter with continuous vertical scrolling.
  @MainActor
  final class ScrolledEpubViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler,
    UIScrollViewDelegate, UIGestureRecognizerDelegate
  {
    private enum BoundaryDirection {
      case previousChapter
      case nextChapter
    }

    private var webView: WKWebView!
    private var chapterIndex: Int
    private var currentSubPageIndex: Int = 0
    private var totalPagesInChapter: Int = 1
    private var containerInsets: UIEdgeInsets
    private var tapScrollPercentage: Double
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
    private var pendingJumpToLastPage: Bool = false
    private var targetProgressionOnReady: Double?
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
    var onPageDidChange: ((Int, Int) -> Void)?
    var onPageCountReady: ((Int, Int) -> Void)?

    var currentChapterIndex: Int { chapterIndex }
    var currentPageIndex: Int { currentSubPageIndex }

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
    private var topBoundaryIndicatorView: UIVisualEffectView?
    private var bottomBoundaryIndicatorView: UIVisualEffectView?
    private var topBoundaryIconView: UIImageView?
    private var bottomBoundaryIconView: UIImageView?
    private var boundaryHintHideWorkItem: DispatchWorkItem?

    private var loadingIndicator: UIActivityIndicatorView?

    // Tap gesture handling
    var onCenterTap: (() -> Void)?
    var onEndReached: (() -> Void)?
    private var tapGestureRecognizer: UITapGestureRecognizer?
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    private var isLongPressing = false
    private var lastLongPressEndTime: Date = .distantPast
    private var lastTouchStartTime: Date = .distantPast
    private var isBoundaryTransitionInFlight = false
    private var boundaryReadyDirection: BoundaryDirection?
    private let boundaryOverscrollThreshold: CGFloat = 48
    private let boundaryHintDuration: TimeInterval = 0.6
    private let boundaryTransitionDelay: TimeInterval = 0.14

    init(
      chapterURL: URL?,
      rootURL: URL?,
      containerInsets: UIEdgeInsets,
      tapScrollPercentage: Double,
      theme: ReaderTheme,
      contentCSS: String,
      readiumProperties: [String: String?],
      publicationLanguage: String?,
      publicationReadingProgression: WebPubReadingProgression?,
      chapterIndex: Int,
      initialSubPageIndex: Int,
      targetProgressionOnReady: Double?,
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
      self.containerInsets = containerInsets
      self.tapScrollPercentage = Self.normalizedTapScrollPercentage(tapScrollPercentage)
      self.theme = theme
      self.contentCSS = contentCSS
      self.readiumProperties = readiumProperties
      self.publicationLanguage = publicationLanguage
      self.publicationReadingProgression = publicationReadingProgression
      self.chapterIndex = chapterIndex
      self.currentSubPageIndex = max(0, initialSubPageIndex)
      self.targetProgressionOnReady = targetProgressionOnReady
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
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAppDidBecomeActive),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
      loadContentIfNeeded(force: true)
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
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

      // Container respects safe area (or view edges based on policy), with additional label spacing
      let top = container.topAnchor.constraint(equalTo: topAnchor, constant: containerInsets.top)
      let leading = container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: containerInsets.left)
      let trailing = trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: containerInsets.right)
      let bottom = bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: containerInsets.bottom)
      containerConstraints = (top, leading, trailing, bottom)
      NSLayoutConstraint.activate([top, leading, trailing, bottom])
      containerView = container

      applyContainerInsets()

      webView = WKWebView(frame: .zero, configuration: config)
      webView.navigationDelegate = self
      webView.scrollView.delegate = self
      webView.scrollView.isScrollEnabled = true
      webView.scrollView.bounces = true
      webView.scrollView.alwaysBounceVertical = true
      webView.scrollView.alwaysBounceHorizontal = false
      webView.scrollView.showsHorizontalScrollIndicator = false
      webView.scrollView.showsVerticalScrollIndicator = false
      webView.scrollView.contentInsetAdjustmentBehavior = .never
      webView.scrollView.isPagingEnabled = false
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
      tapRecognizer.cancelsTouchesInView = false
      view.addGestureRecognizer(tapRecognizer)
      self.tapGestureRecognizer = tapRecognizer

      let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      longPressRecognizer.minimumPressDuration = 0.5
      longPressRecognizer.delegate = self
      longPressRecognizer.cancelsTouchesInView = false
      view.addGestureRecognizer(longPressRecognizer)
      self.longPressGestureRecognizer = longPressRecognizer
    }

    private func setupOverlayLabels() {
      let topOffset = labelTopOffset
      let bottomOffset = -labelBottomOffset

      // Top book title label
      let bookTitleLabel = UILabel()
      bookTitleLabel.font = .systemFont(ofSize: 14)
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
      progressLabel.font = .systemFont(ofSize: 14)
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

      let topIndicator = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
      topIndicator.translatesAutoresizingMaskIntoConstraints = false
      topIndicator.layer.cornerRadius = 18
      topIndicator.clipsToBounds = true
      topIndicator.alpha = 0
      topIndicator.isUserInteractionEnabled = false
      let topIcon = UIImageView(image: UIImage(systemName: "chevron.up"))
      topIcon.translatesAutoresizingMaskIntoConstraints = false
      topIcon.contentMode = .scaleAspectFit
      topIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
      topIndicator.contentView.addSubview(topIcon)
      NSLayoutConstraint.activate([
        topIcon.centerXAnchor.constraint(equalTo: topIndicator.contentView.centerXAnchor),
        topIcon.centerYAnchor.constraint(equalTo: topIndicator.contentView.centerYAnchor),
        topIcon.widthAnchor.constraint(equalToConstant: 20),
        topIcon.heightAnchor.constraint(equalToConstant: 20),
      ])
      view.addSubview(topIndicator)
      NSLayoutConstraint.activate([
        topIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        topIndicator.topAnchor.constraint(equalTo: topAnchor, constant: topOffset + 14),
        topIndicator.widthAnchor.constraint(equalToConstant: 40),
        topIndicator.heightAnchor.constraint(equalToConstant: 40),
      ])
      self.topBoundaryIndicatorView = topIndicator
      self.topBoundaryIconView = topIcon

      let bottomIndicator = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
      bottomIndicator.translatesAutoresizingMaskIntoConstraints = false
      bottomIndicator.layer.cornerRadius = 18
      bottomIndicator.clipsToBounds = true
      bottomIndicator.alpha = 0
      bottomIndicator.isUserInteractionEnabled = false
      let bottomIcon = UIImageView(image: UIImage(systemName: "chevron.down"))
      bottomIcon.translatesAutoresizingMaskIntoConstraints = false
      bottomIcon.contentMode = .scaleAspectFit
      bottomIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
      bottomIndicator.contentView.addSubview(bottomIcon)
      NSLayoutConstraint.activate([
        bottomIcon.centerXAnchor.constraint(equalTo: bottomIndicator.contentView.centerXAnchor),
        bottomIcon.centerYAnchor.constraint(equalTo: bottomIndicator.contentView.centerYAnchor),
        bottomIcon.widthAnchor.constraint(equalToConstant: 20),
        bottomIcon.heightAnchor.constraint(equalToConstant: 20),
      ])
      view.addSubview(bottomIndicator)
      NSLayoutConstraint.activate([
        bottomIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        bottomIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomOffset - 14),
        bottomIndicator.widthAnchor.constraint(equalToConstant: 40),
        bottomIndicator.heightAnchor.constraint(equalToConstant: 40),
      ])
      self.bottomBoundaryIndicatorView = bottomIndicator
      self.bottomBoundaryIconView = bottomIcon
    }

    func updateOverlayLabels() {
      UIView.animate {
        // Top labels
        if self.showingControls {
          self.topBookTitleLabel?.alpha = 0.0
          if let totalProgression = self.totalProgression {
            let percentage = String(format: "%.2f%%", totalProgression * 100)
            self.topProgressLabel?.text = String(localized: "Book Progress \(percentage)")
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
          let chapterProgress = min(
            1.0,
            max(
              0.0,
              Double(self.currentSubPageIndex + 1) / Double(self.totalPagesInChapter)
            )
          )
          let chapterProgressText = String(format: "%.1f%%", chapterProgress * 100)
          let chapterRemainingText = String(format: "%.1f%%", (1.0 - chapterProgress) * 100)

          if self.showingControls {
            self.bottomChapterLabel?.alpha = 0.0
            self.bottomPageCenterLabel?.text = String(localized: "Chapter Progress \(chapterProgressText)")
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
            self.bottomPageRightLabel?.text = String(localized: "\(chapterRemainingText) left")
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
      let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
      guard !isLongPressing && holdDuration < 0.3 else { return }
      if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

      let location = recognizer.location(in: view)
      let size = view.bounds.size
      guard size.width > 0, size.height > 0 else { return }

      let normalizedX = location.x / size.width
      let normalizedY = location.y / size.height

      let action = TapZoneHelper.action(
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        tapZoneMode: AppConfig.tapZoneMode,
        readingDirection: tapReadingDirection(),
        zoneThreshold: AppConfig.tapZoneSize.value
      )

      switch action {
      case .previous:
        scrollToPreviousPage()
      case .next:
        scrollToNextPage()
      case .toggleControls:
        onCenterTap?()
      }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
      if gesture.state == .began {
        isLongPressing = true
      } else if gesture.state == .ended || gesture.state == .cancelled {
        lastLongPressEndTime = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          self?.isLongPressing = false
        }
      }
    }

    private func tapReadingDirection() -> ReadingDirection {
      .vertical
    }

    private var tapScrollStepRatio: CGFloat {
      CGFloat(tapScrollPercentage / 100.0)
    }

    private func scrollToPreviousPage() {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }
      let currentOffset = webView.scrollView.contentOffset.y
      if currentOffset <= 1 {
        if chapterIndex > 0 {
          onChapterNavigationNeeded?(chapterIndex - 1)
        }
        return
      }
      let step = pageHeight * tapScrollStepRatio
      let targetOffset = max(0, currentOffset - step)
      scrollToOffset(targetOffset)
    }

    private func scrollToNextPage() {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }
      let contentHeight = webView.scrollView.contentSize.height
      let maxOffset = max(0, contentHeight - pageHeight)
      let currentOffset = webView.scrollView.contentOffset.y
      if currentOffset >= maxOffset - 1 {
        if chapterIndex < totalChapters - 1 {
          onChapterNavigationNeeded?(chapterIndex + 1)
        } else {
          onEndReached?()
        }
        return
      }
      let step = pageHeight * tapScrollStepRatio
      let targetOffset = min(maxOffset, currentOffset + step)
      scrollToOffset(targetOffset)
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

      // Update overlay label colors
      let labelColor = theme.uiColorText.withAlphaComponent(0.6)
      topBookTitleLabel?.textColor = labelColor
      topProgressLabel?.textColor = labelColor
      bottomChapterLabel?.textColor = labelColor
      bottomPageCenterLabel?.textColor = labelColor
      bottomPageRightLabel?.textColor = labelColor
      topBoundaryIconView?.tintColor = theme.uiColorText.withAlphaComponent(0.9)
      bottomBoundaryIconView?.tintColor = theme.uiColorText.withAlphaComponent(0.9)
    }

    private func applyContainerInsets() {
      guard let containerConstraints else { return }
      containerConstraints.top.constant = containerInsets.top
      containerConstraints.leading.constant = containerInsets.left
      containerConstraints.trailing.constant = containerInsets.right
      containerConstraints.bottom.constant = containerInsets.bottom
      view.layoutIfNeeded()
    }

    func configure(
      chapterURL: URL?,
      rootURL: URL?,
      containerInsets: UIEdgeInsets,
      tapScrollPercentage: Double,
      theme: ReaderTheme,
      contentCSS: String,
      readiumProperties: [String: String?],
      publicationLanguage: String?,
      publicationReadingProgression: WebPubReadingProgression?,
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
      let normalizedTapScrollPercentage = Self.normalizedTapScrollPercentage(tapScrollPercentage)
      let appearanceChanged =
        theme != self.theme
        || containerInsets != self.containerInsets
        || normalizedTapScrollPercentage != self.tapScrollPercentage
        || contentCSS != self.contentCSS
        || readiumProperties != self.readiumProperties
        || publicationLanguage != self.publicationLanguage
        || publicationReadingProgression != self.publicationReadingProgression
        || labelTopOffset != self.labelTopOffset
        || labelBottomOffset != self.labelBottomOffset
        || useSafeArea != self.useSafeArea

      self.chapterURL = chapterURL
      self.rootURL = rootURL
      self.containerInsets = containerInsets
      self.tapScrollPercentage = normalizedTapScrollPercentage
      self.theme = theme
      self.contentCSS = contentCSS
      self.readiumProperties = readiumProperties
      self.publicationLanguage = publicationLanguage
      self.publicationReadingProgression = publicationReadingProgression
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

    private static func normalizedTapScrollPercentage(_ value: Double) -> Double {
      min(100.0, max(25.0, value))
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

    @objc private func handleAppDidBecomeActive() {
      refreshDisplay()
      updateOverlayLabels()
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

      injectCSS(
        contentCSS,
        readiumProperties: readiumProperties,
        readiumPropertyKeys: EpubReaderPreferences.readiumPropertyKeys,
        language: publicationLanguage,
        readingProgression: publicationReadingProgression
      ) { [weak self] in
        self?.injectPaginationJS(targetPageIndex: pageIndex)
      }
    }

    private func scrollToPage(_ pageIndex: Int, animated: Bool = true) {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }

      let contentHeight = webView.scrollView.contentSize.height
      let maxOffset = max(0, contentHeight - webView.bounds.height)
      let targetOffset = min(pageHeight * CGFloat(pageIndex), maxOffset)

      webView.scrollView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: animated)
    }

    private func scrollToOffset(_ targetOffset: CGFloat, animated: Bool = true) {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }
      let contentHeight = webView.scrollView.contentSize.height
      let maxOffset = max(0, contentHeight - pageHeight)
      let clampedOffset = min(max(0, targetOffset), maxOffset)

      webView.scrollView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: animated)

      let newPageIndex = Int(round(clampedOffset / pageHeight))
      let clampedIndex = max(0, min(totalPagesInChapter - 1, newPageIndex))
      if clampedIndex != currentSubPageIndex {
        currentSubPageIndex = clampedIndex
        updateOverlayLabels()
        onPageDidChange?(chapterIndex, currentSubPageIndex)
      }
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

              var root = document.documentElement;
              var pageHeight = root.clientHeight || window.innerHeight;
              if (!pageHeight || pageHeight <= 0) { pageHeight = 1; }

              var currentHeight = root.scrollHeight || document.body.scrollHeight;
              var total = Math.max(1, Math.ceil(currentHeight / pageHeight));
              var maxScroll = Math.max(0, currentHeight - pageHeight);

              var finalTarget = target;
              var offset = Math.min(pageHeight * finalTarget, maxScroll);

              window.scrollTo(0, offset);
              if (document.documentElement) { document.documentElement.scrollTop = offset; }
              if (document.body) { document.body.scrollTop = offset; }

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
              var root = document.documentElement;
              var lastH = root.scrollHeight || document.body.scrollHeight;
              var stableCount = 0;
              var attempt = 0;

              var check = function() {
                if (hasFinalized) return;

                attempt++;
                var currentH = root.scrollHeight || document.body.scrollHeight;
                var pageHeight = root.clientHeight || window.innerHeight;
                if (!pageHeight || pageHeight <= 0) { pageHeight = 1; }

                if (currentH === lastH && currentH > 0) {
                  stableCount++;
                } else {
                  stableCount = 0;
                  lastH = currentH;
                }

                var isProbablyReady = (stableCount >= 4);
                if (target > 0 && currentH <= pageHeight && attempt < 40) {
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
          onPageCountReady?(chapterIndex, normalizedTotal)

          // If we need to jump to last page after loading, do it now
          let shouldJumpToLastPage = pendingJumpToLastPage
          if shouldJumpToLastPage {
            actualPage = max(0, normalizedTotal - 1)
            scrollToPage(actualPage, animated: false)
            pendingJumpToLastPage = false
          }

          if !shouldJumpToLastPage,
            let progression = targetProgressionOnReady
          {
            let targetIndex = max(0, min(normalizedTotal - 1, Int(floor(Double(normalizedTotal) * progression))))
            if targetIndex != actualPage {
              actualPage = targetIndex
              scrollToPage(targetIndex, animated: false)
            }
            targetProgressionOnReady = nil
          }

          if currentSubPageIndex != actualPage {
            currentSubPageIndex = actualPage
          }
        }

        updateOverlayLabels()
        loadingIndicator?.stopAnimating()
        webView.alpha = 1
        onPageDidChange?(chapterIndex, currentSubPageIndex)
      }
    }

    private func injectCSS(
      _ css: String,
      readiumProperties: [String: String?],
      readiumPropertyKeys: [String],
      language: String?,
      readingProgression: WebPubReadingProgression?,
      completion: (() -> Void)? = nil
    ) {
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
      let propertyKeysJSON: String = {
        guard
          let data = try? JSONSerialization.data(withJSONObject: readiumPropertyKeys, options: []),
          let json = String(data: data, encoding: .utf8)
        else {
          return "[]"
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
            var knownKeys = \(propertyKeysJSON);
            knownKeys.forEach(function(key) {
              if (!(key in props)) {
                root.style.removeProperty(key);
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

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      updateCurrentPageFromScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
      if !decelerate {
        updateCurrentPageFromScroll()
      }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      guard isContentLoaded else { return }
      guard !isBoundaryTransitionInFlight else { return }

      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }

      let maxOffset = max(0, scrollView.contentSize.height - pageHeight)
      let topOverscroll = max(0, -scrollView.contentOffset.y)
      let bottomOverscroll = max(0, scrollView.contentOffset.y - maxOffset)

      var candidateDirection: BoundaryDirection?
      var overscrollDistance: CGFloat = 0

      if topOverscroll > 0, chapterIndex > 0, topOverscroll >= bottomOverscroll {
        candidateDirection = .previousChapter
        overscrollDistance = topOverscroll
      } else if bottomOverscroll > 0, chapterIndex <= totalChapters - 1 {
        candidateDirection = .nextChapter
        overscrollDistance = bottomOverscroll
      }

      guard let candidateDirection, overscrollDistance >= boundaryOverscrollThreshold else {
        if boundaryReadyDirection != nil {
          boundaryReadyDirection = nil
          hideBoundaryHint()
        }
        return
      }

      if boundaryReadyDirection != candidateDirection {
        boundaryReadyDirection = candidateDirection
        showBoundaryHint(for: candidateDirection, autoHideAfter: nil)
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
      }
    }

    func scrollViewWillEndDragging(
      _ scrollView: UIScrollView,
      withVelocity velocity: CGPoint,
      targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }
      let maxOffset = max(0, scrollView.contentSize.height - pageHeight)
      guard let direction = boundaryReadyDirection else {
        hideBoundaryHint()
        return
      }

      switch direction {
      case .previousChapter:
        targetContentOffset.pointee = CGPoint(x: 0, y: 0)
      case .nextChapter:
        targetContentOffset.pointee = CGPoint(x: 0, y: maxOffset)
      }
      triggerBoundaryNavigation(direction)
    }

    private func triggerBoundaryNavigation(_ direction: BoundaryDirection) {
      guard !isBoundaryTransitionInFlight else { return }
      isBoundaryTransitionInFlight = true
      boundaryReadyDirection = nil
      showBoundaryHint(for: direction, autoHideAfter: boundaryHintDuration)

      DispatchQueue.main.asyncAfter(deadline: .now() + boundaryTransitionDelay) { [weak self] in
        guard let self else { return }
        switch direction {
        case .previousChapter:
          if self.chapterIndex > 0 {
            self.onChapterNavigationNeeded?(self.chapterIndex - 1)
          }
        case .nextChapter:
          if self.chapterIndex < self.totalChapters - 1 {
            self.onChapterNavigationNeeded?(self.chapterIndex + 1)
          } else {
            self.onEndReached?()
          }
        }
        self.isBoundaryTransitionInFlight = false
      }
    }

    private func showBoundaryHint(for direction: BoundaryDirection, autoHideAfter delay: TimeInterval? = nil) {
      boundaryHintHideWorkItem?.cancel()

      let showView: UIVisualEffectView?
      let hideView: UIVisualEffectView?
      let initialTransform: CGAffineTransform
      switch direction {
      case .previousChapter:
        showView = topBoundaryIndicatorView
        hideView = bottomBoundaryIndicatorView
        initialTransform = CGAffineTransform(translationX: 0, y: -10)
      case .nextChapter:
        showView = bottomBoundaryIndicatorView
        hideView = topBoundaryIndicatorView
        initialTransform = CGAffineTransform(translationX: 0, y: 10)
      }

      if let hideView {
        hideView.alpha = 0
      }
      guard let showView else { return }
      showView.transform = initialTransform
      UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
        showView.alpha = 1
        showView.transform = .identity
      }

      guard let delay else { return }
      let workItem = DispatchWorkItem { [weak self] in
        self?.hideBoundaryHint()
      }
      boundaryHintHideWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func hideBoundaryHint() {
      boundaryHintHideWorkItem?.cancel()
      boundaryHintHideWorkItem = nil
      UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
        self.topBoundaryIndicatorView?.alpha = 0
        self.bottomBoundaryIndicatorView?.alpha = 0
      }
    }

    private func updateCurrentPageFromScroll() {
      guard isContentLoaded else { return }
      let pageHeight = webView.bounds.height
      guard pageHeight > 0 else { return }

      let scrollOffset = webView.scrollView.contentOffset.y
      let newPageIndex = Int(round(scrollOffset / pageHeight))
      let clampedIndex = max(0, min(totalPagesInChapter - 1, newPageIndex))

      if clampedIndex != currentSubPageIndex {
        currentSubPageIndex = clampedIndex
        updateOverlayLabels()
        onPageDidChange?(chapterIndex, currentSubPageIndex)
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      lastTouchStartTime = Date()
      if let view = touch.view, view is UIControl {
        return false
      }
      return true
    }
  }
#endif
