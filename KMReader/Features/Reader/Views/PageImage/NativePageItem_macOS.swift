#if os(macOS)
  import AppKit
  import SwiftUI
  import VisionKit

  final class NativePageItem: NSView {
    private let imageView = NSImageView()
    private let sepiaOverlayView = NSView()
    private let animatedInlineContainer = NSView()
    private let animatedImageController = AnimatedImagePlayerController()
    private let pageNumberContainer = NSView()
    private let pageNumberLabel = NSTextField()
    private let progressIndicator = NSProgressIndicator()
    private let errorLabel = NSTextField()

    private let overlayView = ImageAnalysisOverlayView()
    private var analysisTask: Task<Void, Never>?
    private var analyzedImage: NSImage?
    private var analysisRequestID: UInt64 = 0
    private var currentData: NativePageData?
    private var readingDirection: ReadingDirection = .ltr
    private var displayMode: PageDisplayMode = .fit
    private var readerBackground: ReaderBackground = .system
    private var enableLiveText = false
    private weak var readerViewModel: ReaderViewModel?
    private let logger = AppLogger(.reader)
    private var analysisSourceImage: NSImage?
    private var heightConstraint: NSLayoutConstraint?

    init() {
      super.init(frame: .zero)
      setup()
    }

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      setup()
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
      setup()
    }

    deinit {
      analysisTask?.cancel()
    }

    func prepareForDismantle() {
      clearAnalysis()
      updateAnimatedPlayback(sourceFileURL: nil)
      imageView.isHidden = false
      imageView.image = nil
      animatedInlineContainer.layer?.contents = nil
      analyzedImage = nil
      analysisSourceImage = nil
      updateSepiaOverlay()
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window == nil {
        prepareForDismantle()
      } else {
        if imageView.image == nil, let data = currentData {
          let pageSourceImage: NSImage?
          if let image = readerViewModel?.preloadedImage(for: data.pageID), data.splitMode != .none {
            pageSourceImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
          } else {
            pageSourceImage = readerViewModel?.preloadedImage(for: data.pageID)
          }
          analysisSourceImage = pageSourceImage
          imageView.image = pageSourceImage
        }
        updateAnimatedPlayback(sourceFileURL: currentData?.animatedSourceFileURL)
        if enableLiveText {
          if let image = analysisSourceImage {
            analyzeImage(image)
          }
        }
      }
    }

    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
      super.mouseDown(with: event)
      restoreKeyboardFocus()
    }

    override func mouseUp(with event: NSEvent) {
      super.mouseUp(with: event)
      restoreKeyboardFocus()
    }

    private func restoreKeyboardFocus() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        if let window = self?.window {
          let keyboardHandler = window.contentView?.findViewOfType(KeyboardHandlerView.self)
          if let target = keyboardHandler, window.firstResponder !== target {
            window.makeFirstResponder(target)
          }
        }
      }
    }

    private func setup() {
      self.wantsLayer = true
      self.translatesAutoresizingMaskIntoConstraints = false

      imageView.imageScaling = .scaleProportionallyUpOrDown
      imageView.translatesAutoresizingMaskIntoConstraints = true
      imageView.wantsLayer = true

      imageView.layer?.shadowColor = NSColor.black.cgColor
      imageView.layer?.shadowOpacity = 0.25
      imageView.layer?.shadowOffset = CGSize(width: 0, height: -2)
      imageView.layer?.shadowRadius = 2

      addSubview(imageView)
      sepiaOverlayView.wantsLayer = true
      sepiaOverlayView.isHidden = true
      sepiaOverlayView.translatesAutoresizingMaskIntoConstraints = true
      addSubview(sepiaOverlayView)

      animatedInlineContainer.wantsLayer = true
      animatedInlineContainer.isHidden = true
      animatedInlineContainer.translatesAutoresizingMaskIntoConstraints = true
      animatedInlineContainer.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
      animatedInlineContainer.layer?.contentsGravity = .resizeAspect
      addSubview(animatedInlineContainer)

      overlayView.isHidden = true
      overlayView.wantsLayer = true
      overlayView.translatesAutoresizingMaskIntoConstraints = true
      addSubview(overlayView)
      overlayView.trackingImageView = imageView

      progressIndicator.style = .spinning
      progressIndicator.controlSize = .small
      progressIndicator.isDisplayedWhenStopped = false
      progressIndicator.translatesAutoresizingMaskIntoConstraints = false
      addSubview(progressIndicator)

      pageNumberContainer.wantsLayer = true
      pageNumberContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
      pageNumberContainer.layer?.cornerRadius = 6
      pageNumberContainer.translatesAutoresizingMaskIntoConstraints = false
      addSubview(pageNumberContainer)

      pageNumberLabel.isEditable = false
      pageNumberLabel.isSelectable = false
      pageNumberLabel.isBordered = false
      pageNumberLabel.drawsBackground = false
      pageNumberLabel.font = .systemFont(ofSize: PlatformHelper.pageNumberFontSize, weight: .semibold)
      pageNumberLabel.textColor = .white
      pageNumberLabel.alignment = .center
      pageNumberLabel.translatesAutoresizingMaskIntoConstraints = false
      pageNumberContainer.addSubview(pageNumberLabel)

      errorLabel.isEditable = false
      errorLabel.isSelectable = false
      errorLabel.isBordered = false
      errorLabel.drawsBackground = false
      errorLabel.font = .systemFont(ofSize: 14)
      errorLabel.textColor = .systemRed
      errorLabel.alignment = .center
      errorLabel.maximumNumberOfLines = 0
      errorLabel.lineBreakMode = .byWordWrapping
      errorLabel.isHidden = true
      errorLabel.translatesAutoresizingMaskIntoConstraints = false
      addSubview(errorLabel)

      NSLayoutConstraint.activate([
        progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        pageNumberContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        pageNumberContainer.heightAnchor.constraint(equalToConstant: 24),
        pageNumberLabel.centerXAnchor.constraint(equalTo: pageNumberContainer.centerXAnchor),
        pageNumberLabel.centerYAnchor.constraint(equalTo: pageNumberContainer.centerYAnchor),
        pageNumberLabel.leadingAnchor.constraint(equalTo: pageNumberContainer.leadingAnchor, constant: 4),
        pageNumberLabel.trailingAnchor.constraint(equalTo: pageNumberContainer.trailingAnchor, constant: -4),
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
      enableLiveText: Bool,
      background: ReaderBackground,
      readingDirection: ReadingDirection,
      displayMode: PageDisplayMode,
      targetHeight: CGFloat
    ) {
      self.currentData = data
      self.readerViewModel = viewModel
      self.readingDirection = readingDirection
      self.displayMode = displayMode
      self.readerBackground = background
      let shouldEnableLiveText = enableLiveText && !viewModel.isAnimatedPage(for: data.pageID)
      self.enableLiveText = shouldEnableLiveText

      let pageSourceImage: PlatformImage?
      if let image = image, data.splitMode != .none {
        pageSourceImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
      } else {
        pageSourceImage = image
      }

      analysisSourceImage = shouldEnableLiveText ? pageSourceImage : nil
      imageView.image = pageSourceImage

      updateHeightConstraint(targetHeight)
      updateAnimatedPlayback(sourceFileURL: data.animatedSourceFileURL)

      if pageSourceImage != nil, showPageNumber {
        if let displayedPageNumber = viewModel.displayPageNumber(for: data.pageID) {
          pageNumberLabel.stringValue = "\(displayedPageNumber)"
          pageNumberContainer.isHidden = false
        } else {
          pageNumberContainer.isHidden = true
        }
      } else {
        pageNumberContainer.isHidden = true
      }

      if let error = data.error {
        progressIndicator.stopAnimation(nil)
        errorLabel.stringValue = error
        errorLabel.isHidden = false
      } else if pageSourceImage == nil {
        errorLabel.isHidden = true
        progressIndicator.startAnimation(nil)
      } else {
        errorLabel.isHidden = true
        progressIndicator.stopAnimation(nil)
      }

      if shouldEnableLiveText, let img = pageSourceImage, !visibleRect.isEmpty {
        analyzeImage(img)
      } else if !shouldEnableLiveText {
        clearAnalysis()
      }

      updateOverlaysPosition()
    }

    private func cropImageForSplitMode(image: NSImage, splitMode: PageSplitMode) -> NSImage? {
      guard splitMode != .none else { return image }
      guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return image
      }

      let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

      let cropRect: CGRect
      if splitMode == .leftHalf {
        cropRect = CGRect(x: 0, y: 0, width: imageSize.width / 2, height: imageSize.height)
      } else {
        cropRect = CGRect(x: imageSize.width / 2, y: 0, width: imageSize.width / 2, height: imageSize.height)
      }

      guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
        return image
      }

      return NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
    }

    private func updateSepiaOverlay() {
      guard !isAnimatedPlaybackVisible, readerBackground.appliesImageMultiplyBlend, imageView.image != nil else {
        sepiaOverlayView.isHidden = true
        sepiaOverlayView.layer?.compositingFilter = nil
        sepiaOverlayView.layer?.backgroundColor = NSColor.clear.cgColor
        return
      }
      sepiaOverlayView.isHidden = false
      sepiaOverlayView.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      sepiaOverlayView.layer?.compositingFilter = "multiplyBlendMode"
    }

    func updateAnimatedPlayback(sourceFileURL: URL?) {
      layoutSubtreeIfNeeded()
      if let sourceFileURL {
        animatedInlineContainer.isHidden = false
        animatedInlineContainer.layer?.contents = nil
        updateAnimatedPresentationState()
        if let layer = animatedInlineContainer.layer {
          animatedImageController.start(
            sourceFileURL: sourceFileURL,
            targetLayer: layer
          )
        }
      } else {
        animatedImageController.stop()
        animatedInlineContainer.layer?.contents = nil
        animatedInlineContainer.isHidden = true
        updateAnimatedPresentationState()
      }
    }

    private var isAnimatedPlaybackVisible: Bool {
      currentData?.animatedSourceFileURL != nil && !animatedInlineContainer.isHidden
    }

    private func updateAnimatedPresentationState() {
      imageView.isHidden = false
      imageView.layer?.shadowOpacity = imageView.image == nil ? 0 : 0.25
      updateSepiaOverlay()
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

    private func analyzeImage(_ image: NSImage) {
      if image === analyzedImage && (overlayView.analysis != nil || analysisTask != nil) {
        let requestID = analysisRequestID
        DispatchQueue.main.async { [weak self] in
          guard let self = self, self.analysisRequestID == requestID else { return }
          self.overlayView.isHidden = false
        }
        return
      }

      let pageNum = currentData?.pageID.pageNumber ?? -1
      let bookId = currentData?.pageID.bookId ?? "unknown"
      let startTime = Date()
      let requestID = nextAnalysisRequestID()

      analyzedImage = image
      analysisTask?.cancel()
      analysisTask = Task { [weak self] in
        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        do {
          let analysis = try await LiveTextManager.shared.analyzer.analyze(
            image, orientation: .up, configuration: configuration)
          if Task.isCancelled { return }
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.analysisRequestID == requestID else { return }
            self.overlayView.analysis = analysis
            self.overlayView.preferredInteractionTypes = .automatic
            self.overlayView.isHidden = false
            self.analysisTask = nil
            let duration = Date().timeIntervalSince(startTime)
            self.logger.info(
              String(
                format: "[LiveText] [\(bookId)] ✅ Finished macOS analysis for page %d in %.2fs", pageNum + 1, duration))
          }
        } catch {
          if Task.isCancelled { return }
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.analysisRequestID == requestID else { return }
            self.analysisTask = nil
            self.logger.error("[LiveText] [\(bookId)] ❌ macOS Analysis failed for page \(pageNum + 1): \(error)")
          }
        }
      }
    }

    private func clearAnalysis() {
      let requestID = nextAnalysisRequestID()
      analysisTask?.cancel()
      analysisTask = nil
      analyzedImage = nil
      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.analysisRequestID == requestID else { return }
        self.overlayView.analysis = nil
        self.overlayView.isHidden = true
      }
    }

    private func nextAnalysisRequestID() -> UInt64 {
      analysisRequestID &+= 1
      return analysisRequestID
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

      if let alignment = currentData?.alignment {
        if alignment == .leading {
          xOffset = isRTL ? (viewSize.width - actualImageWidth) : 0
        } else if alignment == .trailing {
          xOffset = isRTL ? 0 : (viewSize.width - actualImageWidth)
        } else {
          xOffset = (viewSize.width - actualImageWidth) / 2
        }
      }

      let imgFrame = NSRect(x: xOffset, y: yOffset, width: actualImageWidth, height: actualImageHeight)
      imageView.frame = imgFrame
      sepiaOverlayView.frame = imgFrame
      animatedInlineContainer.frame = imgFrame
      overlayView.frame = imgFrame

      let topY = yOffset + actualImageHeight - 36

      if let alignment = currentData?.alignment {
        let isLeft: Bool
        if alignment == .center {
          isLeft = isRTL
        } else {
          if alignment == .trailing {
            isLeft = !isRTL
          } else {
            isLeft = isRTL
          }
        }

        if isLeft {
          pageNumberContainer.setFrameOrigin(NSPoint(x: xOffset + 12, y: topY))
        } else {
          pageNumberContainer.setFrameOrigin(
            NSPoint(x: xOffset + actualImageWidth - pageNumberContainer.bounds.width - 12, y: topY))
        }
      }
    }

    override func layout() {
      super.layout()
      updateOverlaysPosition()

      let radius = imageView.layer?.shadowRadius ?? 0
      var shadowRect = imageView.bounds
      if let alignment = currentData?.alignment {
        if alignment == .trailing {
          shadowRect.size.width -= radius
        } else if alignment == .leading {
          shadowRect.origin.x += radius
          shadowRect.size.width -= radius
        }
      }
      imageView.layer?.shadowPath = CGPath(rect: shadowRect, transform: nil)

      if enableLiveText, currentData != nil,
        let image = analysisSourceImage,
        !visibleRect.isEmpty, overlayView.analysis == nil, analysisTask == nil
      {
        analyzeImage(image)
      }
    }
  }
#endif
