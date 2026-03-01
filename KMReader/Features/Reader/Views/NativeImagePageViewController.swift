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

    private var pageID = ReaderPageID(bookId: "", pageNumber: 0)
    private var splitMode: PageSplitMode = .none
    private var alignment: HorizontalAlignment = .center
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

    private var onPlayAnimatedPage: ((ReaderPageID) -> Void)?

    private let scrollView = UIScrollView()
    private let pageItem = NativePageItem()
    private let animatedInlineContainer = UIView()
    private let playButton = UIButton(type: .system)

    private var loadTask: Task<Void, Never>?

    private var lastConfiguredPageID: ReaderPageID?
    private var loadError: String?
    private var isVisibleForAnimatedInlinePlayback = false
    private var inlineReadyProbeToken: UInt64 = 0

    func configure(
      viewModel: ReaderViewModel,
      pageID: ReaderPageID,
      splitMode: PageSplitMode,
      alignment: HorizontalAlignment = .center,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      onPlayAnimatedPage: ((ReaderPageID) -> Void)?
    ) {
      let isPageChanged = lastConfiguredPageID != pageID

      self.viewModel = viewModel
      self.pageID = pageID
      self.splitMode = splitMode
      self.alignment = alignment
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig
      self.onPlayAnimatedPage = onPlayAnimatedPage

      if isPageChanged {
        loadTask?.cancel()
        loadTask = nil
        loadError = nil
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        viewModel.isZoomed = false
        hideAnimatedInlinePlayback()
      }
      lastConfiguredPageID = pageID

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

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      guard !isVisibleForAnimatedInlinePlayback else { return }
      isVisibleForAnimatedInlinePlayback = true
      updateAnimatedInlinePlayback()
    }

    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      guard isVisibleForAnimatedInlinePlayback else { return }
      isVisibleForAnimatedInlinePlayback = false
      hideAnimatedInlinePlayback()
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
      animatedInlineContainer.backgroundColor = .clear
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
    }

    private func applyConfiguration() {
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)
      scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      refreshPageItem()
    }

    private func refreshPageItem() {
      guard let viewModel else { return }

      let readerPage = viewModel.readerPage(for: pageID)
      let image = viewModel.preloadedImage(for: pageID)

      if image != nil {
        loadError = nil
      }

      let isLoading = loadTask != nil || (image == nil && readerPage != nil && loadError == nil)
      let data = NativePageData(
        pageID: pageID,
        isLoading: isLoading,
        error: loadError,
        alignment: alignment,
        splitMode: splitMode
      )

      pageItem.update(
        with: data,
        viewModel: viewModel,
        image: image,
        showPageNumber: renderConfig.showPageNumber,
        enableLiveText: renderConfig.enableLiveText,
        background: renderConfig.readerBackground,
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
      guard let requestedPageIndex = viewModel.pageIndex(for: pageID) else { return }

      let requestedPageID = pageID

      loadTask = Task { [weak self] in
        guard let self else { return }
        let image = await viewModel.preloadImageForPage(at: requestedPageIndex)
        guard !Task.isCancelled else { return }
        guard self.pageID == requestedPageID else { return }

        self.loadTask = nil
        if image == nil && viewModel.preloadedImage(for: requestedPageID) == nil {
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
        && viewModel.shouldShowAnimatedPlayButton(for: pageID)
      playButton.isHidden = !shouldShow
    }

    private func updateAnimatedInlinePlayback() {
      guard isVisibleForAnimatedInlinePlayback else {
        hideAnimatedInlinePlayback()
        return
      }
      guard renderConfig.autoPlayAnimatedImages else {
        hideAnimatedInlinePlayback()
        return
      }
      guard let viewModel else {
        hideAnimatedInlinePlayback()
        return
      }
      guard let fileURL = viewModel.animatedPlaybackFileURL(for: pageID) else {
        hideAnimatedInlinePlayback()
        return
      }

      let slot = max(viewModel.pageIndex(for: pageID) ?? pageID.pageNumber, 0) % 4
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
      if didStartLoad {
        inlineReadyProbeToken &+= 1
        webView.alpha = 0
        animatedInlineContainer.isHidden = true
      } else {
        webView.alpha = 1
        animatedInlineContainer.isHidden = false
      }
    }

    private func hideAnimatedInlinePlayback() {
      inlineReadyProbeToken &+= 1
      animatedInlineContainer.isHidden = true
      for subview in animatedInlineContainer.subviews {
        subview.removeFromSuperview()
      }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard webView.superview === animatedInlineContainer else { return }
      let token = inlineReadyProbeToken
      AnimatedImageReadiness.waitUntilReady(
        in: webView,
        token: token,
        currentToken: { [weak self] in self?.inlineReadyProbeToken ?? 0 }
      ) { [weak self, weak webView] in
        guard let self, let webView else { return }
        webView.alpha = 1
        self.animatedInlineContainer.isHidden = false
      }
    }

    func webView(
      _ webView: WKWebView,
      didFail navigation: WKNavigation!,
      withError error: Error
    ) {
      guard webView.superview === animatedInlineContainer else { return }
      webView.alpha = 1
      animatedInlineContainer.isHidden = false
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      guard webView.superview === animatedInlineContainer else { return }
      webView.alpha = 1
      animatedInlineContainer.isHidden = false
    }

    @objc private func handlePlayButtonTap() {
      onPlayAnimatedPage?(pageID)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
      guard renderConfig.doubleTapZoomMode != .disabled else { return }

      if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
      } else {
        let point = gesture.location(in: pageItem)
        let zoomRect = calculateZoomRect(
          scale: CGFloat(renderConfig.doubleTapZoomScale),
          center: point
        )
        scrollView.zoom(to: zoomRect, animated: true)
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
