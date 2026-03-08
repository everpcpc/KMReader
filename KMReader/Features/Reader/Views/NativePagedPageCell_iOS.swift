#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  final class NativePagedPageCell: UICollectionViewCell {
    private let pagedContentView = PagedContentView()

    override init(frame: CGRect) {
      super.init(frame: frame)
      contentView.addSubview(pagedContentView)
      pagedContentView.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        pagedContentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        pagedContentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        pagedContentView.topAnchor.constraint(equalTo: contentView.topAnchor),
        pagedContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func configure(
      viewModel: ReaderViewModel,
      item: ReaderViewItem,
      screenSize: CGSize,
      renderConfig: ReaderRenderConfig,
      readingDirection: ReadingDirection,
      splitWidePageMode: SplitWidePageMode,
      isPlaybackActive: Bool
    ) {
      pagedContentView.configure(
        viewModel: viewModel,
        item: item,
        screenSize: screenSize,
        renderConfig: renderConfig,
        readingDirection: readingDirection,
        splitWidePageMode: splitWidePageMode,
        isPlaybackActive: isPlaybackActive
      )
    }

    func updatePlaybackActive(_ isPlaybackActive: Bool) {
      pagedContentView.updatePlaybackActive(isPlaybackActive)
    }

    func resetContent(backgroundColor: UIColor) {
      self.backgroundColor = backgroundColor
      contentView.backgroundColor = backgroundColor
      pagedContentView.resetContent(backgroundColor: backgroundColor)
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      pagedContentView.prepareForReuse()
    }

    private final class PagedContentView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
      private let scrollView = UIScrollView()
      private let contentStack = UIStackView()
      private var pageViews: [NativePageItem] = []

      private weak var viewModel: ReaderViewModel?
      private var currentItem: ReaderViewItem?
      private var currentPageData: [NativePageData] = []
      private var currentScreenSize: CGSize = .zero
      private var currentSplitWidePageMode: SplitWidePageMode = .auto
      private var renderConfig = ReaderRenderConfig(
        tapZoneSize: .large,
        tapZoneMode: .auto,
        showPageNumber: true,
        readerBackground: .system,
        enableLiveText: false,
        doubleTapZoomScale: 3.0,
        doubleTapZoomMode: .fast
      )
      private var readingDirection: ReadingDirection = .ltr
      private var isPlaybackActive = false
      private var isUpdatingZoomState = false

      override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
      }

      required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      override func layoutSubviews() {
        super.layoutSubviews()
        updatePages()
      }

      func configure(
        viewModel: ReaderViewModel,
        item: ReaderViewItem,
        screenSize: CGSize,
        renderConfig: ReaderRenderConfig,
        readingDirection: ReadingDirection,
        splitWidePageMode: SplitWidePageMode,
        isPlaybackActive: Bool
      ) {
        let itemChanged = currentItem != item

        self.viewModel = viewModel
        self.currentItem = item
        self.currentScreenSize = screenSize
        self.currentSplitWidePageMode = splitWidePageMode
        self.renderConfig = renderConfig
        self.readingDirection = readingDirection
        self.isPlaybackActive = isPlaybackActive
        self.currentPageData = viewModel.nativePageData(
          for: item,
          readingDirection: readingDirection,
          splitWidePageMode: splitWidePageMode,
          isPlaybackActive: isPlaybackActive
        )

        if itemChanged {
          resetZoomState()
        }

        scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)
        backgroundColor = UIColor(renderConfig.readerBackground.color)
        contentStack.semanticContentAttribute =
          readingDirection == .rtl ? .forceRightToLeft : .forceLeftToRight

        updatePages()
      }

      func prepareForReuse() {
        currentItem = nil
        currentPageData = []
        isPlaybackActive = false
        pageViews.forEach { $0.prepareForDismantle() }
        resetZoomState()
      }

      func resetContent(backgroundColor: UIColor) {
        viewModel = nil
        currentItem = nil
        currentPageData = []
        currentScreenSize = .zero
        isPlaybackActive = false
        self.backgroundColor = backgroundColor
        scrollView.backgroundColor = backgroundColor
        pageViews.forEach { $0.prepareForDismantle() }
        resetZoomState()
      }

      private func setupUI() {
        backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = UIColor(renderConfig.readerBackground.color)
        addSubview(scrollView)

        contentStack.axis = .horizontal
        contentStack.distribution = .fillEqually
        contentStack.alignment = .fill
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
          scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
          scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
          scrollView.topAnchor.constraint(equalTo: topAnchor),
          scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
          contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
          contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
          contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
          contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
          contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
          contentStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        #if os(tvOS)
          scrollView.isScrollEnabled = false
          scrollView.panGestureRecognizer.isEnabled = false
        #else
          let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
          doubleTap.numberOfTapsRequired = 2
          doubleTap.delegate = self
          scrollView.addGestureRecognizer(doubleTap)
        #endif
      }

      private func updatePages() {
        guard let viewModel else { return }
        let pages = currentPageData

        if pageViews.count != pages.count {
          pageViews.forEach { view in
            view.prepareForDismantle()
            view.removeFromSuperview()
          }
          pageViews = pages.map { _ in NativePageItem() }
          pageViews.forEach { contentStack.addArrangedSubview($0) }
        }

        let targetHeight = bounds.height > 0 ? bounds.height : currentScreenSize.height

        for (index, data) in pages.enumerated() {
          let image = viewModel.preloadedImage(for: data.pageID)
          pageViews[index].update(
            with: data,
            viewModel: viewModel,
            image: image,
            showPageNumber: renderConfig.showPageNumber,
            enableLiveText: renderConfig.enableLiveText,
            background: renderConfig.readerBackground,
            readingDirection: readingDirection,
            displayMode: .fit,
            targetHeight: targetHeight
          )
        }
      }

      func updatePlaybackActive(_ isPlaybackActive: Bool) {
        guard self.isPlaybackActive != isPlaybackActive else { return }
        self.isPlaybackActive = isPlaybackActive
        guard let viewModel, let currentItem else { return }

        let playbackData = viewModel.nativePageData(
          for: currentItem,
          readingDirection: readingDirection,
          splitWidePageMode: currentSplitWidePageMode,
          isPlaybackActive: isPlaybackActive
        )
        guard playbackData.count == pageViews.count else {
          currentPageData = playbackData
          updatePages()
          return
        }

        currentPageData = playbackData
        for (index, data) in playbackData.enumerated() {
          pageViews[index].updateAnimatedPlayback(sourceFileURL: data.animatedSourceFileURL)
        }
      }

      private func resetZoomState() {
        isUpdatingZoomState = true
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        scrollView.contentOffset = .zero
        isUpdatingZoomState = false

        guard let viewModel, viewModel.isZoomed else { return }
        viewModel.isZoomed = false
      }

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        contentStack
      }

      func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !isUpdatingZoomState else { return }
        guard let viewModel else { return }

        let zoomed = scrollView.zoomScale > (scrollView.minimumZoomScale + 0.01)
        if viewModel.isZoomed != zoomed {
          viewModel.isZoomed = zoomed
        }
      }

      #if !os(tvOS)
        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
          guard renderConfig.doubleTapZoomMode != .disabled else { return }

          if scrollView.zoomScale > (scrollView.minimumZoomScale + 0.01) {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
          }

          let targetScale = min(
            CGFloat(renderConfig.doubleTapZoomScale),
            scrollView.maximumZoomScale
          )
          let center = gesture.location(in: contentStack)
          let width = scrollView.frame.size.width / targetScale
          let height = scrollView.frame.size.height / targetScale
          let rect = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
          )
          scrollView.zoom(to: rect, animated: true)
        }

        func gestureRecognizer(
          _ gestureRecognizer: UIGestureRecognizer,
          shouldReceive touch: UITouch
        ) -> Bool {
          if let view = touch.view, view is UIControl {
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
      #endif
    }
  }
#endif
