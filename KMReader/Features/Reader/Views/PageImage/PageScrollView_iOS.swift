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
    let displayMode: PageDisplayMode
    let readingDirection: ReadingDirection
    let doubleTapScale: CGFloat
    let doubleTapZoomMode: DoubleTapZoomMode
    let tapZoneSize: TapZoneSize
    let tapZoneMode: TapZoneMode
    let showPageNumber: Bool
    let readerBackground: ReaderBackground
    let enableLiveText: Bool
    let initialZoomScale: CGFloat?
    let initialZoomAnchor: CGPoint?
    let initialZoomID: AnyHashable?

    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void

    let pages: [NativePageData]

    init(
      viewModel: ReaderViewModel,
      screenSize: CGSize,
      resetID: AnyHashable,
      minScale: CGFloat,
      maxScale: CGFloat,
      displayMode: PageDisplayMode = .fit,
      readingDirection: ReadingDirection,
      doubleTapScale: CGFloat,
      doubleTapZoomMode: DoubleTapZoomMode,
      tapZoneSize: TapZoneSize,
      tapZoneMode: TapZoneMode,
      showPageNumber: Bool,
      readerBackground: ReaderBackground,
      enableLiveText: Bool,
      initialZoomScale: CGFloat? = nil,
      initialZoomAnchor: CGPoint? = nil,
      initialZoomID: AnyHashable? = nil,
      onNextPage: @escaping () -> Void,
      onPreviousPage: @escaping () -> Void,
      onToggleControls: @escaping () -> Void,
      pages: [NativePageData]
    ) {
      self.viewModel = viewModel
      self.screenSize = screenSize
      self.resetID = resetID
      self.minScale = minScale
      self.maxScale = maxScale
      self.displayMode = displayMode
      self.readingDirection = readingDirection
      self.doubleTapScale = doubleTapScale
      self.doubleTapZoomMode = doubleTapZoomMode
      self.tapZoneSize = tapZoneSize
      self.tapZoneMode = tapZoneMode
      self.showPageNumber = showPageNumber
      self.readerBackground = readerBackground
      self.enableLiveText = enableLiveText
      self.initialZoomScale = initialZoomScale
      self.initialZoomAnchor = initialZoomAnchor
      self.initialZoomID = initialZoomID
      self.onNextPage = onNextPage
      self.onPreviousPage = onPreviousPage
      self.onToggleControls = onToggleControls
      self.pages = pages
    }

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

      #if os(tvOS)
        scrollView.isScrollEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false
      #endif

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
      ])

      context.coordinator.parent = self
      context.coordinator.applyDisplayModeIfNeeded(in: scrollView)
      context.coordinator.setupNativeInteractions(on: scrollView)
      return scrollView
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
      coordinator.prepareForDismantle()
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
      context.coordinator.isUpdatingFromSwiftUI = true
      defer {
        DispatchQueue.main.async {
          context.coordinator.isUpdatingFromSwiftUI = false
          context.coordinator.applyInitialZoomIfNeeded(in: uiView)
        }
      }

      context.coordinator.parent = self
      context.coordinator.applyDisplayModeIfNeeded(in: uiView)
      context.coordinator.updatePages()

      uiView.backgroundColor = UIColor(readerBackground.color)

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
        context.coordinator.lastInitialZoomID = nil
        uiView.setZoomScale(minScale, animated: false)
        uiView.contentOffset = .zero
      }
    }

    @MainActor
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
      var lastResetID: AnyHashable?
      var lastInitialZoomID: AnyHashable?
      var lastDisplayMode: PageDisplayMode?
      var isUpdatingFromSwiftUI = false
      var isMenuVisible = false
      var isLongPressing = false
      var lastZoomOutTime: Date = .distantPast
      var lastLongPressEndTime: Date = .distantPast
      var lastTouchStartTime: Date = .distantPast
      var lastSingleTapActionTime: Date = .distantPast

      private var singleTapWorkItem: DispatchWorkItem?

      var parent: PageScrollView!

      weak var contentStack: UIStackView?
      var contentHeightConstraint: NSLayoutConstraint?
      private var pageViews: [NativePageItemiOS] = []

      func prepareForDismantle() {
        pageViews.forEach { view in
          view.prepareForDismantle()
          view.removeFromSuperview()
        }
        pageViews.removeAll()
      }

      func updatePages() {
        guard let stack = contentStack else { return }
        let pages = parent.pages

        if pageViews.count != pages.count {
          pageViews.forEach { $0.removeFromSuperview() }
          pageViews = pages.map { _ in NativePageItemiOS() }
          pageViews.forEach {
            stack.addArrangedSubview($0)
          }
        }

        for (index, data) in pages.enumerated() {
          let image = parent.viewModel.preloadedImages[data.pageNumber]
          let targetHeight = targetHeight(for: data, image: image)
          pageViews[index].update(
            with: data,
            viewModel: parent.viewModel,
            image: image,
            showPageNumber: parent.showPageNumber,
            readingDirection: parent.readingDirection,
            displayMode: parent.displayMode,
            targetHeight: targetHeight
          )
        }

        contentStack?.semanticContentAttribute = parent.readingDirection == .rtl ? .forceRightToLeft : .forceLeftToRight
      }

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentStack
      }

      func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !isUpdatingFromSwiftUI else { return }

        let zoomed = scrollView.zoomScale > (parent.minScale + 0.01)
        if zoomed != parent.viewModel.isZoomed {
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.parent.viewModel.isZoomed != zoomed {
              self.parent.viewModel.isZoomed = zoomed
            }
          }
        }
      }

      func applyInitialZoomIfNeeded(in scrollView: UIScrollView) {
        guard let initialZoomID = parent.initialZoomID else { return }
        guard initialZoomID != lastInitialZoomID else { return }
        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }

        scrollView.layoutIfNeeded()
        let contentSize = scrollView.contentSize
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let scale = clampedScale(parent.initialZoomScale ?? parent.minScale)
        let baseAnchor = clampedAnchor(parent.initialZoomAnchor ?? CGPoint(x: 0.5, y: 0.5))
        let adjustedAnchor = clampedAnchor(adjustedAnchorForFillWidth(baseAnchor, contentSize: contentSize))
        let center = CGPoint(
          x: contentSize.width * adjustedAnchor.x,
          y: contentSize.height * adjustedAnchor.y
        )
        let zoomRect = calculateZoomRect(scale: scale, center: center, scrollView: scrollView)
        scrollView.zoom(to: zoomRect, animated: false)
        lastInitialZoomID = initialZoomID
      }

      func setupNativeInteractions(on scrollView: UIScrollView) {
        if parent.doubleTapZoomMode != .disabled {
          let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
          doubleTap.numberOfTapsRequired = 2
          doubleTap.delegate = self
          scrollView.addGestureRecognizer(doubleTap)
        }

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

      func applyDisplayModeIfNeeded(in scrollView: UIScrollView) {
        guard let stack = contentStack else { return }
        guard lastDisplayMode != parent.displayMode else { return }

        lastDisplayMode = parent.displayMode
        contentHeightConstraint?.isActive = false
        contentHeightConstraint = nil

        switch parent.displayMode {
        case .fit:
          stack.alignment = .fill
          stack.distribution = .fillEqually
          contentHeightConstraint = stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        case .fillWidth:
          stack.alignment = .top
          stack.distribution = .fill
          contentHeightConstraint = stack.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
          )
        }

        contentHeightConstraint?.isActive = true
      }

      private func targetHeight(for data: NativePageData, image: PlatformImage?) -> CGFloat {
        guard parent.displayMode == .fillWidth else { return parent.screenSize.height }
        let width = parent.screenSize.width
        guard width > 0 else { return parent.screenSize.height }

        if let image = image {
          let imageSize = image.size
          if imageSize.width > 0, imageSize.height > 0 {
            let height = width * imageSize.height / imageSize.width
            if height.isFinite && height > 0 {
              return height
            }
          }
        }

        if let page = parent.viewModel.pages.first(where: { $0.number == data.pageNumber }),
          let pageWidth = page.width,
          let pageHeight = page.height,
          pageWidth > 0,
          pageHeight > 0
        {
          let height = width * CGFloat(pageHeight) / CGFloat(pageWidth)
          if height.isFinite && height > 0 {
            return height
          }
        }

        return parent.screenSize.height
      }

      @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()
        if Date().timeIntervalSince(lastSingleTapActionTime) < 0.3 { return }
        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > parent.minScale + 0.01 {
          scrollView.setZoomScale(parent.minScale, animated: true)
          lastZoomOutTime = Date()
        } else {
          let point = gesture.location(in: contentStack)
          let zoomRect = calculateZoomRect(scale: parent.doubleTapScale, center: point, scrollView: scrollView)
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
        singleTapWorkItem?.cancel()

        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && !isMenuVisible && holdDuration < 0.3 else { return }

        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > parent.minScale + 0.01 { return }
        if Date().timeIntervalSince(lastZoomOutTime) < 0.4 { return }

        let location = gesture.location(in: scrollView)

        let item = DispatchWorkItem { [weak self] in
          self?.performSingleTapAction(location: location)
        }
        let delay = parent.doubleTapZoomMode.tapDebounceDelay

        if delay > 0 {
          singleTapWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
          // Execute immediately if disabled
          item.perform()
        }
      }

      private func performSingleTapAction(location: CGPoint) {
        lastSingleTapActionTime = Date()
        let normalizedX = location.x / parent.screenSize.width
        let normalizedY = location.y / parent.screenSize.height

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: parent.tapZoneMode,
          readingDirection: parent.readingDirection,
          zoneThreshold: parent.tapZoneSize.value
        )

        switch action {
        case .previous:
          parent.onPreviousPage()
        case .next:
          parent.onNextPage()
        case .toggleControls:
          parent.onToggleControls()
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

      private func clampedScale(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite else { return parent.minScale }
        return min(max(scale, parent.minScale), parent.maxScale)
      }

      private func clampedAnchor(_ anchor: CGPoint) -> CGPoint {
        let x = min(max(anchor.x, 0), 1)
        let y = min(max(anchor.y, 0), 1)
        return CGPoint(x: x, y: y)
      }

      private func adjustedAnchorForFillWidth(_ anchor: CGPoint, contentSize: CGSize) -> CGPoint {
        guard parent.displayMode == .fillWidth else { return anchor }
        guard let data = parent.pages.first else { return anchor }
        let image = parent.viewModel.preloadedImages[data.pageNumber]
        let imageHeight = targetHeight(for: data, image: image)
        guard imageHeight > 0, contentSize.height > 0, imageHeight < contentSize.height else { return anchor }
        let adjustedY = anchor.y * (imageHeight / contentSize.height)
        return CGPoint(x: anchor.x, y: adjustedY)
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
    private var readingDirection: ReadingDirection = .ltr
    private var displayMode: PageDisplayMode = .fit

    #if !os(tvOS)
      private let interaction = ImageAnalysisInteraction()
      private var analysisTask: Task<Void, Never>?
      private var analyzedImage: UIImage?
      private let logger = AppLogger(.reader)
    #endif

    private var heightConstraint: NSLayoutConstraint?

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
      imageView.translatesAutoresizingMaskIntoConstraints = true
      imageView.isUserInteractionEnabled = true
      imageView.clipsToBounds = false

      // Add shadow for premium look
      imageView.layer.shadowColor = UIColor.black.cgColor
      imageView.layer.shadowOpacity = 0.25
      imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
      imageView.layer.shadowRadius = 2
      imageView.layer.masksToBounds = false

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

      NSLayoutConstraint.activate([
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

    func update(
      with data: NativePageData,
      viewModel: ReaderViewModel,
      image: PlatformImage?,
      showPageNumber: Bool,
      readingDirection: ReadingDirection,
      displayMode: PageDisplayMode,
      targetHeight: CGFloat
    ) {
      self.currentData = data
      self.viewModel = viewModel
      self.readingDirection = readingDirection
      self.displayMode = displayMode

      // Handle split mode - crop the image if needed
      let displayImage: PlatformImage?
      if let image = image, data.splitMode != .none {
        displayImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
      } else {
        displayImage = image
      }

      imageView.image = displayImage
      imageView.layer.shadowOpacity = displayImage == nil ? 0 : 0.25

      updateHeightConstraint(targetHeight)

      if displayImage != nil, showPageNumber {
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
      } else if displayImage == nil || data.isLoading {
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

    private func cropImageForSplitMode(image: UIImage, splitMode: PageSplitMode) -> UIImage? {
      guard splitMode != .none else { return image }

      let imageSize = image.size
      let scale = image.scale

      // Calculate the crop rect for half the image
      let cropRect: CGRect
      if splitMode == .leftHalf {
        cropRect = CGRect(x: 0, y: 0, width: imageSize.width / 2, height: imageSize.height)
      } else {
        cropRect = CGRect(x: imageSize.width / 2, y: 0, width: imageSize.width / 2, height: imageSize.height)
      }

      // Create cropped image
      guard
        let cgImage = image.cgImage?.cropping(
          to: CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.size.width * scale,
            height: cropRect.size.height * scale
          ))
      else {
        return image
      }

      return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }

    private func updateHeightConstraint(_ targetHeight: CGFloat) {
      if displayMode == .fillWidth {
        if heightConstraint == nil {
          heightConstraint = heightAnchor.constraint(equalToConstant: targetHeight)
          heightConstraint?.priority = .required
          heightConstraint?.isActive = true
        } else {
          heightConstraint?.constant = targetHeight
        }
      } else {
        heightConstraint?.isActive = false
        heightConstraint = nil
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

      // Update shadow path for performance and remove shadow at spine in dual-page mode
      let radius = imageView.layer.shadowRadius
      var shadowRect = imageView.bounds
      if let alignment = currentData?.alignment {
        if alignment == .trailing {
          // Spine is on the trailing side (right in LTR)
          shadowRect.size.width -= radius
        } else if alignment == .leading {
          // Spine is on the leading side (left in LTR)
          shadowRect.origin.x += radius
          shadowRect.size.width -= radius
        }
      }
      imageView.layer.shadowPath = UIBezierPath(rect: shadowRect).cgPath

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
      guard imageSize.width > 0, imageSize.height > 0 else { return }
      let viewSize = bounds.size
      if viewSize.width == 0 || viewSize.height == 0 { return }

      let widthRatio = viewSize.width / imageSize.width
      let heightRatio = viewSize.height / imageSize.height
      let scale: CGFloat
      if displayMode == .fillWidth {
        scale = widthRatio
      } else {
        scale = min(widthRatio, heightRatio)
      }

      let actualImageWidth = imageSize.width * scale
      let actualImageHeight = imageSize.height * scale
      let yOffset = (viewSize.height - actualImageHeight) / 2

      let isRTL = readingDirection == .rtl
      var xOffset: CGFloat = (viewSize.width - actualImageWidth) / 2

      // Calculate xOffset based on alignment
      if let alignment = currentData?.alignment {
        if alignment == .leading {
          xOffset = isRTL ? (viewSize.width - actualImageWidth) : 0
        } else if alignment == .trailing {
          xOffset = isRTL ? 0 : (viewSize.width - actualImageWidth)
        } else {
          // Center alignment
          xOffset = (viewSize.width - actualImageWidth) / 2
        }
      }

      imageView.frame = CGRect(x: xOffset, y: yOffset, width: actualImageWidth, height: actualImageHeight)

      let topY = yOffset
      let labelWidth = pageNumberLabel.intrinsicContentSize.width + 16

      if let alignment = currentData?.alignment {
        let isLeft: Bool
        if alignment == .center {
          isLeft = isRTL
        } else {
          // outer edge
          if alignment == .trailing {
            isLeft = !isRTL
          } else {
            isLeft = isRTL
          }
        }

        if isLeft {
          pageNumberLabel.frame = CGRect(x: xOffset + 12, y: topY + 12, width: max(30, labelWidth), height: 24)
        } else {
          pageNumberLabel.frame = CGRect(
            x: xOffset + actualImageWidth - max(30, labelWidth) - 12, y: topY + 12, width: max(30, labelWidth),
            height: 24)
        }
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
