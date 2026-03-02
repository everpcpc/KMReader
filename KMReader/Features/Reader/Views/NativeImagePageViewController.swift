//
// NativeImagePageViewController.swift
//

#if os(iOS)
  import AVFoundation
  import SwiftUI
  import UIKit

  @MainActor
  final class NativeImagePageViewController: UIViewController, UIScrollViewDelegate,
    UIGestureRecognizerDelegate
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
      readerBackground: .system,
      enableLiveText: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )

    private let scrollView = UIScrollView()
    private let pageItem = NativePageItem()
    private let animatedInlineContainer = UIView()
    private let animatedInlinePlayerView = AnimatedInlinePlayerView()

    private var loadTask: Task<Void, Never>?
    private var animatedInlinePreparationTask: Task<Void, Never>?

    private var lastConfiguredPageID: ReaderPageID?
    private var loadError: String?
    private var isVisibleForAnimatedInlinePlayback = false
    private var animatedInlineCurrentURL: URL?
    private var animatedInlinePlayer: AVQueuePlayer?
    private var animatedInlineLooper: AVPlayerLooper?
    private var animatedInlineStatusObserver: NSKeyValueObservation?

    func configure(
      viewModel: ReaderViewModel,
      pageID: ReaderPageID,
      splitMode: PageSplitMode,
      alignment: HorizontalAlignment = .center,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig
    ) {
      let isPageChanged = lastConfiguredPageID != pageID

      self.viewModel = viewModel
      self.pageID = pageID
      self.splitMode = splitMode
      self.alignment = alignment
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig

      if isPageChanged {
        loadTask?.cancel()
        loadTask = nil
        cancelAnimatedInlinePreparation()
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
      refreshPageItem()
      prepareAnimatedInlinePlaybackIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      guard isVisibleForAnimatedInlinePlayback else { return }
      isVisibleForAnimatedInlinePlayback = false
      cancelAnimatedInlinePreparation()
      hideAnimatedInlinePlayback()
    }

    deinit {
      loadTask?.cancel()
      animatedInlinePreparationTask?.cancel()
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

      animatedInlineContainer.translatesAutoresizingMaskIntoConstraints = false
      animatedInlineContainer.backgroundColor = .clear
      animatedInlineContainer.isHidden = true
      animatedInlineContainer.isUserInteractionEnabled = false
      view.addSubview(animatedInlineContainer)

      animatedInlinePlayerView.translatesAutoresizingMaskIntoConstraints = false
      animatedInlinePlayerView.playerLayer.videoGravity = .resizeAspect
      animatedInlineContainer.addSubview(animatedInlinePlayerView)

      NSLayoutConstraint.activate([
        animatedInlineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        animatedInlineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        animatedInlineContainer.topAnchor.constraint(equalTo: view.topAnchor),
        animatedInlineContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        animatedInlinePlayerView.leadingAnchor.constraint(equalTo: animatedInlineContainer.leadingAnchor),
        animatedInlinePlayerView.trailingAnchor.constraint(equalTo: animatedInlineContainer.trailingAnchor),
        animatedInlinePlayerView.topAnchor.constraint(equalTo: animatedInlineContainer.topAnchor),
        animatedInlinePlayerView.bottomAnchor.constraint(equalTo: animatedInlineContainer.bottomAnchor),
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
      animatedInlineContainer.backgroundColor = .clear
      refreshPageItem()
      prepareAnimatedInlinePlaybackIfNeeded()
    }

    private func refreshPageItem() {
      guard let viewModel else { return }

      let readerPage = viewModel.readerPage(for: pageID)
      let image = viewModel.preloadedImage(for: pageID)

      if image != nil {
        loadError = nil
      }

      let isAnimatedLoading = shouldShowAnimatedLoading(viewModel: viewModel, readerPage: readerPage)
      let isLoading =
        loadTask != nil
        || (image == nil && readerPage != nil && loadError == nil)
        || isAnimatedLoading
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
        self.prepareAnimatedInlinePlaybackIfNeeded()
      }
    }

    private func updateAnimatedInlinePlayback() {
      guard isVisibleForAnimatedInlinePlayback else {
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

      startAnimatedInlinePlayback(fileURL: fileURL)
    }

    private func prepareAnimatedInlinePlaybackIfNeeded() {
      guard isVisibleForAnimatedInlinePlayback else { return }
      guard let viewModel else { return }
      guard let readerPage = viewModel.readerPage(for: pageID) else { return }
      guard readerPage.page.isAnimatedImageCandidate else { return }
      guard viewModel.animatedPlaybackFileURL(for: pageID) == nil else { return }
      guard animatedInlinePreparationTask == nil else { return }

      let requestedPageID = pageID
      animatedInlinePreparationTask = Task { [weak self] in
        guard let self else { return }
        _ = await viewModel.prepareAnimatedPagePlaybackURL(pageID: requestedPageID)
        guard !Task.isCancelled else { return }
        guard self.pageID == requestedPageID else { return }
        self.animatedInlinePreparationTask = nil
        self.refreshPageItem()
      }
    }

    private func shouldShowAnimatedLoading(
      viewModel: ReaderViewModel,
      readerPage: ReaderPage?
    ) -> Bool {
      guard isVisibleForAnimatedInlinePlayback else { return false }
      guard viewModel.animatedPlaybackFileURL(for: pageID) == nil else { return false }

      if viewModel.isAnimatedPlaybackLoading(for: pageID) {
        return true
      }
      if readerPage?.page.isAnimatedImageCandidate == true {
        return animatedInlinePreparationTask != nil
      }
      return false
    }

    private func cancelAnimatedInlinePreparation() {
      animatedInlinePreparationTask?.cancel()
      animatedInlinePreparationTask = nil
    }

    private func hideAnimatedInlinePlayback() {
      animatedInlineContainer.isHidden = true
      stopAnimatedInlinePlayback()
    }

    private func startAnimatedInlinePlayback(fileURL: URL) {
      if animatedInlineCurrentURL == fileURL, let player = animatedInlinePlayer {
        if animatedInlinePlayerView.playerLayer.player !== player {
          animatedInlinePlayerView.playerLayer.player = player
        }
        animatedInlinePlayerView.alpha = 1
        player.play()
        animatedInlineContainer.isHidden = false
        return
      }

      stopAnimatedInlinePlayback()
      animatedInlineContainer.isHidden = false
      animatedInlinePlayerView.alpha = 0

      let item = AVPlayerItem(url: fileURL)
      let player = AVQueuePlayer()
      player.isMuted = true
      player.actionAtItemEnd = .none
      player.automaticallyWaitsToMinimizeStalling = false

      animatedInlineLooper = AVPlayerLooper(player: player, templateItem: item)
      animatedInlineStatusObserver = item.observe(\.status, options: [.initial, .new]) {
        [weak self] observedItem, _ in
        guard let self else { return }
        Task { @MainActor in
          guard self.animatedInlineCurrentURL == fileURL else { return }
          switch observedItem.status {
          case .readyToPlay, .failed:
            self.animatedInlinePlayerView.alpha = 1
            self.animatedInlineContainer.isHidden = false
          default:
            break
          }
        }
      }

      animatedInlineCurrentURL = fileURL
      animatedInlinePlayer = player
      animatedInlinePlayerView.playerLayer.player = player
      player.play()
    }

    private func stopAnimatedInlinePlayback() {
      animatedInlinePlayerView.alpha = 0
      animatedInlineStatusObserver?.invalidate()
      animatedInlineStatusObserver = nil
      animatedInlineLooper = nil
      animatedInlinePlayer?.pause()
      animatedInlinePlayer?.removeAllItems()
      animatedInlinePlayer = nil
      animatedInlineCurrentURL = nil
      animatedInlinePlayerView.playerLayer.player = nil
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

    private final class AnimatedInlinePlayerView: UIView {
      override class var layerClass: AnyClass {
        AVPlayerLayer.self
      }

      var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
      }
    }
  }
#endif
