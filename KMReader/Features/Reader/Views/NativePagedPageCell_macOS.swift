#if os(macOS)
  import AppKit
  import SwiftUI

  final class NativePagedPageCell: NSCollectionViewItem {
    private let pagedContentView = PagedContentView()

    override func loadView() {
      view = NSView()
      view.wantsLayer = true
      view.addSubview(pagedContentView)
      pagedContentView.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        pagedContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        pagedContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        pagedContentView.topAnchor.constraint(equalTo: view.topAnchor),
        pagedContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
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

    func resetContent(backgroundColor: NSColor) {
      view.wantsLayer = true
      view.layer?.backgroundColor = backgroundColor.cgColor
      pagedContentView.resetContent()
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      pagedContentView.resetContent()
    }

    private final class PagedContentView: NSView {
      private let scrollView = NSScrollView()
      private let contentStack = NSStackView()
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
        showPageShadow: true,
        readerBackground: .system,
        enableLiveText: false,
        doubleTapZoomScale: 3.0,
        doubleTapZoomMode: .fast
      )
      private var readingDirection: ReadingDirection = .ltr
      private var isPlaybackActive = false
      private var isUpdatingMagnification = false

      override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
      }

      required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      override func layout() {
        super.layout()
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
          resetMagnification()
        }

        wantsLayer = true
        layer?.backgroundColor = NSColor(renderConfig.readerBackground.color).cgColor
        scrollView.backgroundColor = NSColor(renderConfig.readerBackground.color)
        contentStack.userInterfaceLayoutDirection =
          readingDirection == .rtl ? .rightToLeft : .leftToRight

        updatePages()
      }

      func resetContent() {
        currentItem = nil
        currentPageData = []
        isPlaybackActive = false
        pageViews.forEach { $0.prepareForDismantle() }
        resetMagnification()
      }

      private func setupUI() {
        wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 8.0
        scrollView.backgroundColor = NSColor(renderConfig.readerBackground.color)
        scrollView.drawsBackground = true
        addSubview(scrollView)

        contentStack.orientation = .horizontal
        contentStack.distribution = .fillEqually
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentStack

        NSLayoutConstraint.activate([
          scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
          scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
          scrollView.topAnchor.constraint(equalTo: topAnchor),
          scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
          contentStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
          contentStack.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor),
        ])

        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handleMagnificationEnded),
          name: NSScrollView.didEndLiveMagnifyNotification,
          object: scrollView
        )
      }

      deinit {
        NotificationCenter.default.removeObserver(self)
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
            showPageShadow: renderConfig.showPageShadow,
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
        currentPageData = playbackData
        updatePages()
      }

      private func resetMagnification() {
        isUpdatingMagnification = true
        scrollView.magnification = scrollView.minMagnification
        scrollView.contentView.bounds.origin = .zero
        scrollView.reflectScrolledClipView(scrollView.contentView)
        isUpdatingMagnification = false

        guard let viewModel, viewModel.isZoomed else { return }
        viewModel.isZoomed = false
      }

      @objc private func handleMagnificationEnded() {
        guard !isUpdatingMagnification else { return }
        guard let viewModel else { return }

        let zoomed = scrollView.magnification > (scrollView.minMagnification + 0.01)
        if viewModel.isZoomed != zoomed {
          viewModel.isZoomed = zoomed
        }
      }
    }
  }
#endif
