#if os(macOS)
  import AppKit
  import SwiftUI
  import VisionKit

  final class NativePageItem: NSView {
    private let imageView = NSImageView()
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
    private var renderedSourceImage: NSImage?
    private var renderedBackground: ReaderBackground = .system
    private var renderedImage: NSImage?
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
      imageView.image = nil
      analyzedImage = nil
      analysisSourceImage = nil
      clearRenderedImageCache()
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window == nil {
        clearAnalysis()
        imageView.image = nil
        analyzedImage = nil
        analysisSourceImage = nil
        clearRenderedImageCache()
      } else {
        if imageView.image == nil, let data = currentData {
          let sourceImage: NSImage?
          if let image = readerViewModel?.preloadedImage(forPageIndex: data.pageNumber), data.splitMode != .none {
            sourceImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
          } else {
            sourceImage = readerViewModel?.preloadedImage(forPageIndex: data.pageNumber)
          }
          analysisSourceImage = sourceImage
          imageView.image = renderDisplayImage(from: sourceImage, background: readerBackground)
        }
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
      self.enableLiveText = enableLiveText

      let sourceImage: PlatformImage?
      if let image = image, data.splitMode != .none {
        sourceImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
      } else {
        sourceImage = image
      }

      analysisSourceImage = sourceImage
      let displayImage = renderDisplayImage(from: sourceImage, background: background)
      imageView.image = displayImage
      imageView.layer?.shadowOpacity = sourceImage == nil ? 0 : 0.25

      updateHeightConstraint(targetHeight)

      if sourceImage != nil, showPageNumber {
        if let displayedPageNumber = viewModel.displayPageNumber(forPageIndex: data.pageNumber) {
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
      } else if sourceImage == nil || data.isLoading {
        errorLabel.isHidden = true
        progressIndicator.startAnimation(nil)
      } else {
        errorLabel.isHidden = true
        progressIndicator.stopAnimation(nil)
      }

      if enableLiveText, let img = sourceImage, !visibleRect.isEmpty {
        analyzeImage(img)
      } else if !enableLiveText {
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

    private func renderDisplayImage(from image: NSImage?, background: ReaderBackground) -> NSImage? {
      guard let image else {
        clearRenderedImageCache()
        return nil
      }

      guard background.appliesImageMultiplyBlend else {
        renderedSourceImage = image
        renderedBackground = background
        renderedImage = image
        return image
      }

      if let cachedSource = renderedSourceImage, cachedSource === image, renderedBackground == background {
        return renderedImage
      }

      guard let blended = multiplyBlend(image: image, tintColor: NSColor(background.color)) else {
        renderedSourceImage = image
        renderedBackground = background
        renderedImage = image
        return image
      }

      renderedSourceImage = image
      renderedBackground = background
      renderedImage = blended
      return blended
    }

    private func multiplyBlend(image: NSImage, tintColor: NSColor) -> NSImage? {
      guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
      else {
        return image
      }

      let width = cgImage.width
      let height = cgImage.height
      guard width > 0, height > 0 else { return image }

      let colorSpace = CGColorSpaceCreateDeviceRGB()
      guard
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else {
        return image
      }

      let rect = CGRect(x: 0, y: 0, width: width, height: height)
      context.draw(cgImage, in: rect)
      context.setBlendMode(.multiply)
      context.setFillColor(tintColor.cgColor)
      context.fill(rect)

      guard let blendedCGImage = context.makeImage() else {
        return image
      }

      return NSImage(cgImage: blendedCGImage, size: image.size)
    }

    private func clearRenderedImageCache() {
      renderedSourceImage = nil
      renderedImage = nil
      renderedBackground = .system
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

      let pageNum = currentData?.pageNumber ?? -1
      let bookId = currentData?.bookId ?? "unknown"
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
