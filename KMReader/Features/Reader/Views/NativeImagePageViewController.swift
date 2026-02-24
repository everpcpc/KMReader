//
// NativeImagePageViewController.swift
//

#if os(iOS)
  import SwiftUI
  import UIKit
  import WebKit

  @MainActor
  final class NativeImagePageViewController: UIViewController, UIScrollViewDelegate,
    UIGestureRecognizerDelegate, WKNavigationDelegate
  {
    private weak var viewModel: ReaderViewModel?

    private var pageIndex: Int = 0
    private var splitMode: PageSplitMode = .none
    private var readingDirection: ReadingDirection = .ltr
    private var renderConfig = ReaderRenderConfig(
      tapZoneSize: .large,
      tapZoneMode: .auto,
      showPageNumber: true,
      autoPlayAnimatedImages: false,
      readerBackground: .system,
      enableLiveText: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )

    private var onNextPage: (() -> Void)?
    private var onPreviousPage: (() -> Void)?
    private var onToggleControls: (() -> Void)?
    private var onPlayAnimatedPage: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let pageItem = NativePageItem()
    private let animatedInlineContainer = UIView()
    private let playButton = UIButton(type: .system)

    private var singleTapWorkItem: DispatchWorkItem?
    private var loadTask: Task<Void, Never>?

    private var lastConfiguredPageIndex: Int?
    private var loadError: String?
    private var isMenuVisible = false
    private var isLongPressing = false
    private var lastZoomOutTime: Date = .distantPast
    private var lastLongPressEndTime: Date = .distantPast
    private var lastTouchStartTime: Date = .distantPast
    private var lastSingleTapActionTime: Date = .distantPast

    func configure(
      viewModel: ReaderViewModel,
      pageIndex: Int,
      splitMode: PageSplitMode,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      onNextPage: @escaping () -> Void,
      onPreviousPage: @escaping () -> Void,
      onToggleControls: @escaping () -> Void,
      onPlayAnimatedPage: ((Int) -> Void)?
    ) {
      let isPageChanged = lastConfiguredPageIndex != pageIndex

      self.viewModel = viewModel
      self.pageIndex = pageIndex
      self.splitMode = splitMode
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig
      self.onNextPage = onNextPage
      self.onPreviousPage = onPreviousPage
      self.onToggleControls = onToggleControls
      self.onPlayAnimatedPage = onPlayAnimatedPage

      if isPageChanged {
        loadTask?.cancel()
        loadTask = nil
        loadError = nil
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        viewModel.isZoomed = false
        hideAnimatedInlinePlayback()
      }
      lastConfiguredPageIndex = pageIndex

      if isViewLoaded {
        applyConfiguration()
      }
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupUI()
      setupGestures()
      applyConfiguration()
    }

    deinit {
      loadTask?.cancel()
    }

    private func setupUI() {
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)

      scrollView.translatesAutoresizingMaskIntoConstraints = false
      scrollView.delegate = self
      scrollView.minimumZoomScale = 1.0
      scrollView.maximumZoomScale = 8.0
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      view.addSubview(scrollView)

      NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: view.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])

      pageItem.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(pageItem)

      NSLayoutConstraint.activate([
        pageItem.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        pageItem.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        pageItem.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        pageItem.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        pageItem.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        pageItem.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
      ])

      playButton.translatesAutoresizingMaskIntoConstraints = false
      playButton.tintColor = .white
      playButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
      playButton.layer.cornerRadius = 28
      playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
      playButton.addTarget(self, action: #selector(handlePlayButtonTap), for: .touchUpInside)
      playButton.isHidden = true
      view.addSubview(playButton)

      animatedInlineContainer.translatesAutoresizingMaskIntoConstraints = false
      animatedInlineContainer.backgroundColor = .black
      animatedInlineContainer.isHidden = true
      animatedInlineContainer.isUserInteractionEnabled = false
      view.addSubview(animatedInlineContainer)

      NSLayoutConstraint.activate([
        animatedInlineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        animatedInlineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        animatedInlineContainer.topAnchor.constraint(equalTo: view.topAnchor),
        animatedInlineContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        playButton.widthAnchor.constraint(equalToConstant: 56),
        playButton.heightAnchor.constraint(equalToConstant: 56),
      ])
    }

    private func setupGestures() {
      let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
      doubleTap.numberOfTapsRequired = 2
      doubleTap.delegate = self
      scrollView.addGestureRecognizer(doubleTap)

      let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
      singleTap.numberOfTapsRequired = 1
      singleTap.cancelsTouchesInView = false
      singleTap.delegate = self
      scrollView.addGestureRecognizer(singleTap)

      let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      longPress.minimumPressDuration = 0.5
      longPress.cancelsTouchesInView = false
      longPress.delegate = self
      scrollView.addGestureRecognizer(longPress)
    }

    private func applyConfiguration() {
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)
      scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      refreshPageItem()
    }

    private func refreshPageItem() {
      guard let viewModel else { return }

      let readerPage = viewModel.readerPage(at: pageIndex)
      let image = viewModel.preloadedImage(forPageIndex: pageIndex)

      if image != nil {
        loadError = nil
      }

      let isLoading = loadTask != nil || (image == nil && readerPage != nil && loadError == nil)
      let data = NativePageData(
        bookId: viewModel.resolvedBookId(forPageIndex: pageIndex),
        pageNumber: pageIndex,
        isLoading: isLoading,
        error: loadError,
        alignment: .center,
        splitMode: splitMode
      )

      pageItem.update(
        with: data,
        viewModel: viewModel,
        image: image,
        showPageNumber: renderConfig.showPageNumber,
        enableLiveText: renderConfig.enableLiveText,
        readingDirection: readingDirection,
        displayMode: .fit,
        targetHeight: view.bounds.height
      )

      updateAnimatedInlinePlayback()
      updatePlayButtonVisibility()

      if image == nil, readerPage != nil, loadError == nil {
        startLoadingImageIfNeeded()
      }
    }

    private func startLoadingImageIfNeeded() {
      guard loadTask == nil else { return }
      guard let viewModel else { return }

      let requestedPageIndex = pageIndex

      loadTask = Task { [weak self] in
        guard let self else { return }
        let image = await viewModel.preloadImageForPage(at: requestedPageIndex)
        guard !Task.isCancelled else { return }
        guard self.pageIndex == requestedPageIndex else { return }

        self.loadTask = nil
        if image == nil && viewModel.preloadedImage(forPageIndex: requestedPageIndex) == nil {
          self.loadError = "Failed to load page"
        } else {
          self.loadError = nil
        }
        self.refreshPageItem()
      }
    }

    private func updatePlayButtonVisibility() {
      guard let viewModel else {
        playButton.isHidden = true
        return
      }

      let shouldShow =
        !renderConfig.autoPlayAnimatedImages
        && onPlayAnimatedPage != nil
        && viewModel.shouldShowAnimatedPlayButton(for: pageIndex)
      playButton.isHidden = !shouldShow
    }

    private func updateAnimatedInlinePlayback() {
      guard renderConfig.autoPlayAnimatedImages else {
        hideAnimatedInlinePlayback()
        return
      }
      guard let viewModel else {
        hideAnimatedInlinePlayback()
        return
      }
      guard let fileURL = viewModel.animatedPlaybackFileURL(for: pageIndex) else {
        hideAnimatedInlinePlayback()
        return
      }

      let slot = max(pageIndex, 0) % 4
      let webView = AnimatedImageWebViewPool.shared.webView(for: slot)
      webView.navigationDelegate = self
      if webView.superview !== animatedInlineContainer {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        animatedInlineContainer.addSubview(webView)
        NSLayoutConstraint.activate([
          webView.leadingAnchor.constraint(equalTo: animatedInlineContainer.leadingAnchor),
          webView.trailingAnchor.constraint(equalTo: animatedInlineContainer.trailingAnchor),
          webView.topAnchor.constraint(equalTo: animatedInlineContainer.topAnchor),
          webView.bottomAnchor.constraint(equalTo: animatedInlineContainer.bottomAnchor),
        ])
      }

      let didStartLoad = AnimatedImageWebViewPool.shared.loadFileIfNeeded(fileURL, slot: slot)
      animatedInlineContainer.isHidden = didStartLoad
      if !didStartLoad {
        animatedInlineContainer.isHidden = false
      }
    }

    private func hideAnimatedInlinePlayback() {
      animatedInlineContainer.isHidden = true
      for subview in animatedInlineContainer.subviews {
        subview.removeFromSuperview()
      }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard webView.superview === animatedInlineContainer else { return }
      animatedInlineContainer.isHidden = false
    }

    func webView(
      _ webView: WKWebView,
      didFail navigation: WKNavigation!,
      withError error: Error
    ) {
      guard webView.superview === animatedInlineContainer else { return }
      animatedInlineContainer.isHidden = false
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      guard webView.superview === animatedInlineContainer else { return }
      animatedInlineContainer.isHidden = false
    }

    @objc private func handlePlayButtonTap() {
      onPlayAnimatedPage?(pageIndex)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
      guard renderConfig.doubleTapZoomMode != .disabled else { return }

      singleTapWorkItem?.cancel()
      if Date().timeIntervalSince(lastSingleTapActionTime) < 0.3 { return }

      if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        lastZoomOutTime = Date()
      } else {
        let point = gesture.location(in: pageItem)
        let zoomRect = calculateZoomRect(
          scale: CGFloat(renderConfig.doubleTapZoomScale),
          center: point
        )
        scrollView.zoom(to: zoomRect, animated: true)
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

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
      singleTapWorkItem?.cancel()

      let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
      guard !isLongPressing && !isMenuVisible && holdDuration < 0.3 else { return }
      if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }
      if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 { return }
      if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

      let location = gesture.location(in: view)
      let actionItem = DispatchWorkItem { [weak self] in
        self?.performSingleTapAction(location: location)
      }

      let delay = renderConfig.doubleTapZoomMode.tapDebounceDelay
      if delay > 0 {
        singleTapWorkItem = actionItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: actionItem)
      } else {
        actionItem.perform()
      }
    }

    private func performSingleTapAction(location: CGPoint) {
      guard view.bounds.width > 0, view.bounds.height > 0 else { return }

      lastSingleTapActionTime = Date()
      let normalizedX = location.x / view.bounds.width
      let normalizedY = location.y / view.bounds.height

      let action = TapZoneHelper.action(
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        tapZoneMode: renderConfig.tapZoneMode,
        readingDirection: readingDirection,
        zoneThreshold: renderConfig.tapZoneSize.value
      )

      switch action {
      case .previous:
        onPreviousPage?()
      case .next:
        onNextPage?()
      case .toggleControls:
        onToggleControls?()
      }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      pageItem
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      guard let viewModel else { return }
      let zoomed = scrollView.zoomScale > (scrollView.minimumZoomScale + 0.01)
      if viewModel.isZoomed != zoomed {
        viewModel.isZoomed = zoomed
      }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      lastTouchStartTime = Date()
      if let touchedView = touch.view, touchedView is UIControl {
        return false
      }
      return true
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      true
    }

    private func calculateZoomRect(scale: CGFloat, center: CGPoint) -> CGRect {
      let width = scrollView.frame.size.width / scale
      let height = scrollView.frame.size.height / scale
      return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
  }
#endif
