#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  #if !os(tvOS)
    import VisionKit
  #endif

  struct PageScrollView: UIViewRepresentable {
    var viewModel: ReaderViewModel
    let screenSize: CGSize
    let resetID: AnyHashable
    let minScale: CGFloat
    let maxScale: CGFloat
    let doubleTapScale: CGFloat

    let tapZoneSize: TapZoneSize
    let tapZoneMode: TapZoneMode
    let showPageNumber: Bool
    let readerBackground: ReaderBackground
    let readingDirection: ReadingDirection
    let enableLiveText: Bool
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void

    let pages: [NativePageData]

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
      let scrollView = UIScrollView()
      scrollView.delegate = context.coordinator
      scrollView.minimumZoomScale = minScale
      scrollView.maximumZoomScale = maxScale
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.contentInsetAdjustmentBehavior = .never

      scrollView.backgroundColor = UIColor(readerBackground.color)

      let contentStack = UIStackView()
      contentStack.axis = .horizontal
      contentStack.distribution = .fillEqually
      contentStack.alignment = .fill
      contentStack.spacing = 0
      contentStack.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(contentStack)
      context.coordinator.contentStack = contentStack

      NSLayoutConstraint.activate([
        contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        contentStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
      ])

      context.coordinator.setupNativeInteractions(on: scrollView)
      return scrollView
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
      coordinator.prepareForDismantle()
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
      context.coordinator.isUpdatingFromSwiftUI = true
      defer {
        DispatchQueue.main.async { context.coordinator.isUpdatingFromSwiftUI = false }
      }

      context.coordinator.syncStates(
        viewModel: viewModel,
        pages: pages,
        screenSize: screenSize,
        minScale: minScale,
        tapZoneSize: tapZoneSize,
        tapZoneMode: tapZoneMode,
        showPageNumber: showPageNumber,
        readingDirection: readingDirection,
        enableLiveText: enableLiveText,
        onNextPage: onNextPage,
        onPreviousPage: onPreviousPage,
        onToggleControls: onToggleControls
      )

      uiView.backgroundColor = UIColor(readerBackground.color)

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
        uiView.setZoomScale(minScale, animated: false)
        uiView.contentOffset = .zero
      }
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
      var lastResetID: AnyHashable?
      var isUpdatingFromSwiftUI = false
      var isLongPressing = false
      var isMenuVisible = false
      var lastZoomOutTime: Date = .distantPast
      var lastLongPressEndTime: Date = .distantPast
      var lastTouchStartTime: Date = .distantPast

      private var mirrorPages: [NativePageData] = []
      private weak var viewModel: ReaderViewModel?
      private var mirrorScreenSize: CGSize = .zero
      private var mirrorMinScale: CGFloat = 1.0
      private var mirrorTapZoneSize: TapZoneSize = .large
      private var mirrorTapZoneMode: TapZoneMode = .auto
      private var mirrorShowPageNumber: Bool = true
      private var mirrorReadingDirection: ReadingDirection = .ltr
      private var mirrorEnableLiveText: Bool = false
      private var mirrorOnNextPage: () -> Void = {}
      private var mirrorOnPreviousPage: () -> Void = {}
      private var mirrorOnToggleControls: () -> Void = {}

      weak var contentStack: UIStackView?
      private var pageViews: [NativePageItemiOS] = []

      deinit {
        prepareForDismantle()
      }

      func prepareForDismantle() {
        pageViews.forEach { view in
          view.prepareForDismantle()
          view.removeFromSuperview()
        }
        pageViews.removeAll()
        mirrorPages.removeAll()
        viewModel = nil
      }

      func syncStates(
        viewModel: ReaderViewModel,
        pages: [NativePageData],
        screenSize: CGSize,
        minScale: CGFloat,
        tapZoneSize: TapZoneSize,
        tapZoneMode: TapZoneMode,
        showPageNumber: Bool,
        readingDirection: ReadingDirection,
        enableLiveText: Bool,
        onNextPage: @escaping () -> Void,
        onPreviousPage: @escaping () -> Void,
        onToggleControls: @escaping () -> Void
      ) {
        self.viewModel = viewModel
        self.mirrorPages = pages
        self.mirrorScreenSize = screenSize
        self.mirrorMinScale = minScale
        self.mirrorTapZoneSize = tapZoneSize
        self.mirrorTapZoneMode = tapZoneMode
        self.mirrorShowPageNumber = showPageNumber
        self.mirrorReadingDirection = readingDirection
        self.mirrorEnableLiveText = enableLiveText
        self.mirrorOnNextPage = onNextPage
        self.mirrorOnPreviousPage = onPreviousPage
        self.mirrorOnToggleControls = onToggleControls

        updatePages()
      }

      private func updatePages() {
        guard let stack = contentStack else { return }

        if pageViews.count != mirrorPages.count {
          pageViews.forEach { $0.removeFromSuperview() }
          pageViews = mirrorPages.map { _ in NativePageItemiOS() }
          pageViews.forEach {
            stack.addArrangedSubview($0)
          }
        }

        for (index, data) in mirrorPages.enumerated() {
          if let viewModel = viewModel {
            let image = viewModel.preloadedImages[data.pageNumber]
            pageViews[index].update(
              with: data, viewModel: viewModel, image: image, showPageNumber: mirrorShowPageNumber)
          }
        }
      }

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentStack
      }

      func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !isUpdatingFromSwiftUI else { return }

        let zoomed = scrollView.zoomScale > (mirrorMinScale + 0.01)
        if zoomed != viewModel?.isZoomed {
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.viewModel?.isZoomed != zoomed {
              self.viewModel?.isZoomed = zoomed
            }
          }
        }
      }

      func setupNativeInteractions(on scrollView: UIScrollView) {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.delegate = self
        singleTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delegate = self
        longPress.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(longPress)
      }

      @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > mirrorMinScale + 0.01 {
          scrollView.setZoomScale(mirrorMinScale, animated: true)
          lastZoomOutTime = Date()
        } else {
          let point = gesture.location(in: contentStack)
          let zoomRect = calculateZoomRect(scale: 2.0, center: point, scrollView: scrollView)
          scrollView.zoom(to: zoomRect, animated: true)
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

      @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && !isMenuVisible && holdDuration < 0.3 else { return }

        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > mirrorMinScale + 0.01 { return }
        if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

        let location = gesture.location(in: scrollView)
        let normalizedX = location.x / mirrorScreenSize.width
        let normalizedY = location.y / mirrorScreenSize.height

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: mirrorTapZoneMode,
          readingDirection: mirrorReadingDirection,
          zoneThreshold: mirrorTapZoneSize.value
        )

        switch action {
        case .previous:
          mirrorOnPreviousPage()
        case .next:
          mirrorOnNextPage()
        case .toggleControls:
          mirrorOnToggleControls()
        }
      }

      func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        lastTouchStartTime = Date()
        if let view = touch.view, view is UIControl {
          return false
        }
        return true
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        return true
      }

      private func calculateZoomRect(scale: CGFloat, center: CGPoint, scrollView: UIScrollView) -> CGRect {
        let width = scrollView.frame.size.width / scale
        let height = scrollView.frame.size.height / scale
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
      }
    }
  }

  private class NativePageItemiOS: UIView {
    private let imageView = UIImageView()
    private let pageNumberLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private var currentData: NativePageData?
    private weak var viewModel: ReaderViewModel?

    #if !os(tvOS)
      private let interaction = ImageAnalysisInteraction()
      private var analysisTask: Task<Void, Never>?
      private var analyzedImage: UIImage?
      private let logger = AppLogger(.reader)
    #endif

    private var aspectConstraint: NSLayoutConstraint?
    private var imageLeadingConstraint: NSLayoutConstraint?
    private var imageTrailingConstraint: NSLayoutConstraint?
    private var imageCenterXConstraint: NSLayoutConstraint?

    // Additional constraints for ensuring imageView doesn't exceed bounds
    private var imageLeadingBoundConstraint: NSLayoutConstraint?
    private var imageTrailingBoundConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
      #if !os(tvOS)
        analysisTask?.cancel()
      #endif
    }

    func prepareForDismantle() {
      #if !os(tvOS)
        clearAnalysis()
        analyzedImage = nil
      #endif
      imageView.image = nil
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window == nil {
        prepareForDismantle()
      } else {
        // Restore image when returning to window if it was cleared
        if imageView.image == nil, let data = currentData {
          imageView.image = viewModel?.preloadedImages[data.pageNumber]
        }
        #if !os(tvOS)
          if AppConfig.enableLiveText {
            analyzeImage()
          }
        #endif
      }
    }

    private func setup() {
      imageView.contentMode = .scaleAspectFit
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.isUserInteractionEnabled = true
      imageView.clipsToBounds = true
      addSubview(imageView)

      loadingIndicator.hidesWhenStopped = true
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      addSubview(loadingIndicator)

      pageNumberLabel.font = .systemFont(ofSize: PlatformHelper.pageNumberFontSize, weight: .semibold)
      pageNumberLabel.textColor = .white
      pageNumberLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      pageNumberLabel.layer.cornerRadius = 6
      pageNumberLabel.layer.masksToBounds = true
      pageNumberLabel.textAlignment = .center
      pageNumberLabel.translatesAutoresizingMaskIntoConstraints = false
      addSubview(pageNumberLabel)

      errorLabel.isHidden = true
      errorLabel.textColor = .systemRed
      errorLabel.numberOfLines = 0
      errorLabel.textAlignment = .center
      errorLabel.translatesAutoresizingMaskIntoConstraints = false
      addSubview(errorLabel)

      // Create equality constraints for dual-page mode (force alignment to edge/spine)
      imageLeadingConstraint = imageView.leadingAnchor.constraint(equalTo: leadingAnchor)
      imageTrailingConstraint = imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
      imageCenterXConstraint = imageView.centerXAnchor.constraint(equalTo: centerXAnchor)

      // Create inequality bounds for single-page mode (stay within bounds but centered)
      imageLeadingBoundConstraint = imageView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor)
      imageTrailingBoundConstraint = imageView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)

      NSLayoutConstraint.activate([
        // Center imageView vertically
        imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        imageView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
        imageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

        // Always enforce bounds constraints
        imageLeadingBoundConstraint!,
        imageTrailingBoundConstraint!,

        // Horizontal alignment will be set by updateImageAlignment
        // For single page: centerX will be activated
        // For dual page: leading or trailing equality will be activated

        loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        pageNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        pageNumberLabel.heightAnchor.constraint(equalToConstant: 24),
        errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
        errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
      ])
    }

    func update(with data: NativePageData, viewModel: ReaderViewModel, image: PlatformImage?, showPageNumber: Bool) {
      self.currentData = data
      self.viewModel = viewModel
      imageView.image = image

      updateImageAlignment()

      if image != nil, showPageNumber {
        pageNumberLabel.text = "\(data.pageNumber + 1)"
        pageNumberLabel.isHidden = false
      } else {
        pageNumberLabel.isHidden = true
      }

      // Show error or loading indicator
      if let error = data.error {
        loadingIndicator.stopAnimating()
        errorLabel.text = error
        errorLabel.isHidden = false
      } else if image == nil || data.isLoading {
        errorLabel.isHidden = true
        loadingIndicator.startAnimating()
      } else {
        errorLabel.isHidden = true
        loadingIndicator.stopAnimating()
      }

      #if !os(tvOS)
        // Only analyze if enableLiveText is on AND the view is likely visible
        if AppConfig.enableLiveText {
          if window != nil && !isHidden {
            if !imageView.interactions.contains(where: { $0 === interaction }) {
              imageView.addInteraction(interaction)
            }
            analyzeImage()
          }
        } else {
          if imageView.interactions.contains(where: { $0 === interaction }) {
            imageView.removeInteraction(interaction)
          }
          clearAnalysis()
        }
      #endif

      setNeedsLayout()
    }

    private func updateImageAlignment() {
      guard let data = currentData, let image = imageView.image else {
        aspectConstraint?.isActive = false
        return
      }

      aspectConstraint?.isActive = false
      let ratio = image.size.width / image.size.height
      aspectConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: ratio)
      aspectConstraint?.priority = .required
      aspectConstraint?.isActive = true

      imageLeadingConstraint?.isActive = false
      imageTrailingConstraint?.isActive = false
      imageCenterXConstraint?.isActive = false

      if data.alignment == .leading {
        // Dual page - left page: align to leading edge (spine in center)
        imageLeadingConstraint?.isActive = true
      } else if data.alignment == .trailing {
        // Dual page - right page: align to trailing edge (spine in center)
        imageTrailingConstraint?.isActive = true
      } else {
        // Single page: center horizontally
        imageCenterXConstraint?.isActive = true
      }
    }

    #if !os(tvOS)
      private func analyzeImage() {
        guard let image = imageView.image else { return }

        // Avoid redundant analysis if we are already analyzing or have finished analyzing this specific image
        if image === analyzedImage && (interaction.analysis != nil || analysisTask != nil) {
          return
        }

        let pageNum = currentData?.pageNumber ?? -1
        let bookId = currentData?.bookId ?? "unknown"
        let startTime = Date()

        analyzedImage = image
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
          let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
          do {
            let analysis = try await LiveTextManager.shared.analyzer.analyze(image, configuration: configuration)
            if !Task.isCancelled {
              guard let self = self else { return }
              self.interaction.analysis = analysis
              self.interaction.preferredInteractionTypes = .automatic
              let duration = Date().timeIntervalSince(startTime)
              self.logger.info(
                String(format: "[LiveText] [\(bookId)] ✅ Finished analysis for page %d in %.2fs", pageNum + 1, duration)
              )
            }
          } catch {
            if !Task.isCancelled {
              guard let self = self else { return }
              self.logger.error("[LiveText] [\(bookId)] ❌ Analysis failed for page \(pageNum + 1): \(error)")
            }
          }
        }
      }

      private func clearAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        analyzedImage = nil
        interaction.analysis = nil
      }
    #endif

    override func layoutSubviews() {
      super.layoutSubviews()
      updateOverlaysPosition()

      #if !os(tvOS)
        // When layout happens (e.g. during scroll),
        // check if we should start analysis if it hasn't been started yet
        if AppConfig.enableLiveText, imageView.image != nil,
          window != nil, !isHidden, interaction.analysis == nil, analysisTask == nil
        {
          if !imageView.interactions.contains(where: { $0 === interaction }) {
            imageView.addInteraction(interaction)
          }
          analyzeImage()
        }
      #endif
    }

    private func updateOverlaysPosition() {
      guard let image = imageView.image else { return }
      let imageSize = image.size
      let viewSize = bounds.size
      if viewSize.width == 0 || viewSize.height == 0 { return }

      let widthRatio = viewSize.width / imageSize.width
      let heightRatio = viewSize.height / imageSize.height
      let scale = min(widthRatio, heightRatio)

      let actualImageWidth = imageSize.width * scale
      let actualImageHeight = imageSize.height * scale
      let yOffset = (viewSize.height - actualImageHeight) / 2

      let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
      var xOffset: CGFloat = (viewSize.width - actualImageWidth) / 2

      // Calculate xOffset based on alignment
      if let alignment = currentData?.alignment {
        if alignment == .leading {
          xOffset = isRTL ? (viewSize.width - actualImageWidth) : 0
        } else if alignment == .trailing {
          xOffset = isRTL ? 0 : (viewSize.width - actualImageWidth)
        } else {
          xOffset = (viewSize.width - actualImageWidth) / 2
        }
      }

      let topY = yOffset + 12
      let labelWidth = pageNumberLabel.intrinsicContentSize.width + 16

      // Determine if this is dual-page mode (leading or trailing alignment)
      let isDualPage = currentData?.alignment == .leading || currentData?.alignment == .trailing

      if isDualPage {
        // Dual page mode: position based on left/right page
        let isLeftPage =
          (!isRTL && currentData?.alignment == .trailing) || (isRTL && currentData?.alignment == .leading)

        if isLeftPage {
          pageNumberLabel.frame = CGRect(x: xOffset + 12, y: topY, width: max(30, labelWidth), height: 24)
        } else {
          pageNumberLabel.frame = CGRect(
            x: xOffset + actualImageWidth - max(30, labelWidth) - 12, y: topY, width: max(30, labelWidth), height: 24)
        }
      } else {
        // Single page mode: center at top
        pageNumberLabel.frame = CGRect(
          x: xOffset + (actualImageWidth - max(30, labelWidth)) / 2, y: topY, width: max(30, labelWidth), height: 24)
      }
    }

    func getCombinedRectRelativeToImage() -> CGRect {
      let labelFrameInItem = pageNumberLabel.frame
      let labelFrameInImage = convert(labelFrameInItem, to: imageView)
      let imageRectInSelf = CGRect(origin: .zero, size: imageView.bounds.size)
      if !pageNumberLabel.isHidden {
        return imageRectInSelf.union(labelFrameInImage)
      }
      return imageRectInSelf
    }
  }
#endif
