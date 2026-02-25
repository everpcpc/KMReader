#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  #if !os(tvOS)
    import VisionKit
  #endif

  final class NativePageItem: UIView {
    private let imageView = UIImageView()
    private let pageNumberLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private var currentData: NativePageData?
    private weak var viewModel: ReaderViewModel?
    private var readingDirection: ReadingDirection = .ltr
    private var displayMode: PageDisplayMode = .fit
    private var readerBackground: ReaderBackground = .system
    private var enableLiveText = false
    private let logger = AppLogger(.reader)
    private var renderedSourceImage: UIImage?
    private var renderedBackground: ReaderBackground = .system
    private var renderedImage: UIImage?

    #if !os(tvOS)
      private let interaction = ImageAnalysisInteraction()
      private var analysisTask: Task<Void, Never>?
      private var analyzedImage: UIImage?
      private var analysisSourceImage: UIImage?
      private var analysisRequestID: UInt64 = 0
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
        if imageView.interactions.contains(where: { $0 === interaction }) {
          imageView.removeInteraction(interaction)
        }
        clearAnalysis()
        analyzedImage = nil
        analysisSourceImage = nil
      #endif
      clearRenderedImageCache()
      imageView.image = nil
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window == nil {
        prepareForDismantle()
      } else {
        if imageView.image == nil, let data = currentData {
          let sourceImage: UIImage?
          if let image = viewModel?.preloadedImage(forPageIndex: data.pageNumber), data.splitMode != .none {
            sourceImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
          } else {
            sourceImage = viewModel?.preloadedImage(forPageIndex: data.pageNumber)
          }
          #if !os(tvOS)
            analysisSourceImage = sourceImage
          #endif
          imageView.image = renderDisplayImage(from: sourceImage, background: readerBackground)
        }
        #if !os(tvOS)
          if enableLiveText {
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
      enableLiveText: Bool,
      background: ReaderBackground,
      readingDirection: ReadingDirection,
      displayMode: PageDisplayMode,
      targetHeight: CGFloat
    ) {
      self.currentData = data
      self.viewModel = viewModel
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

      #if !os(tvOS)
        analysisSourceImage = sourceImage
      #endif

      let displayImage = renderDisplayImage(from: sourceImage, background: background)
      imageView.image = displayImage
      imageView.layer.shadowOpacity = sourceImage == nil ? 0 : 0.25

      updateHeightConstraint(targetHeight)

      if sourceImage != nil, showPageNumber {
        if let displayedPageNumber = viewModel.displayPageNumber(forPageIndex: data.pageNumber) {
          pageNumberLabel.text = "\(displayedPageNumber)"
          pageNumberLabel.isHidden = false
        } else {
          pageNumberLabel.isHidden = true
        }
      } else {
        pageNumberLabel.isHidden = true
      }

      if let error = data.error {
        loadingIndicator.stopAnimating()
        errorLabel.text = error
        errorLabel.isHidden = false
      } else if sourceImage == nil || data.isLoading {
        errorLabel.isHidden = true
        loadingIndicator.startAnimating()
      } else {
        errorLabel.isHidden = true
        loadingIndicator.stopAnimating()
      }

      #if !os(tvOS)
        if enableLiveText {
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

      let cropRect: CGRect
      if splitMode == .leftHalf {
        cropRect = CGRect(x: 0, y: 0, width: imageSize.width / 2, height: imageSize.height)
      } else {
        cropRect = CGRect(x: imageSize.width / 2, y: 0, width: imageSize.width / 2, height: imageSize.height)
      }

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

    private func renderDisplayImage(from image: UIImage?, background: ReaderBackground) -> UIImage? {
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

      guard let blended = multiplyBlend(image: image, tintColor: UIColor(background.color)) else {
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

    private func multiplyBlend(image: UIImage, tintColor: UIColor) -> UIImage? {
      let size = image.size
      guard size.width > 0, size.height > 0 else { return image }

      let format = UIGraphicsImageRendererFormat.preferred()
      format.scale = image.scale
      format.opaque = false
      let renderer = UIGraphicsImageRenderer(size: size, format: format)

      return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        image.draw(in: rect)
        context.cgContext.setBlendMode(.multiply)
        context.cgContext.setFillColor(tintColor.cgColor)
        context.cgContext.fill(rect)
      }
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

    #if !os(tvOS)
      private func analyzeImage() {
        guard let image = analysisSourceImage ?? imageView.image else { return }

        if image === analyzedImage && (interaction.analysis != nil || analysisTask != nil) {
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
            let analysis = try await LiveTextManager.shared.analyzer.analyze(image, configuration: configuration)
            if Task.isCancelled { return }
            await MainActor.run {
              guard let self = self, self.analysisRequestID == requestID else { return }
              self.interaction.analysis = analysis
              self.interaction.preferredInteractionTypes = .automatic
              self.analysisTask = nil
              let duration = Date().timeIntervalSince(startTime)
              self.logger.info(
                String(format: "[LiveText] [\(bookId)] ✅ Finished analysis for page %d in %.2fs", pageNum + 1, duration)
              )
            }
          } catch {
            if Task.isCancelled { return }
            await MainActor.run {
              guard let self = self, self.analysisRequestID == requestID else { return }
              self.analysisTask = nil
              self.logger.error("[LiveText] [\(bookId)] ❌ Analysis failed for page \(pageNum + 1): \(error)")
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
          self.interaction.analysis = nil
        }
      }

      private func nextAnalysisRequestID() -> UInt64 {
        analysisRequestID &+= 1
        return analysisRequestID
      }
    #endif

    override func layoutSubviews() {
      super.layoutSubviews()
      updateOverlaysPosition()

      let radius = imageView.layer.shadowRadius
      var shadowRect = imageView.bounds
      if let alignment = currentData?.alignment {
        if alignment == .trailing {
          shadowRect.size.width -= radius
        } else if alignment == .leading {
          shadowRect.origin.x += radius
          shadowRect.size.width -= radius
        }
      }
      imageView.layer.shadowPath = UIBezierPath(rect: shadowRect).cgPath

      #if !os(tvOS)
        if enableLiveText, imageView.image != nil,
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

      if let alignment = currentData?.alignment {
        if alignment == .leading {
          xOffset = isRTL ? (viewSize.width - actualImageWidth) : 0
        } else if alignment == .trailing {
          xOffset = isRTL ? 0 : (viewSize.width - actualImageWidth)
        } else {
          xOffset = (viewSize.width - actualImageWidth) / 2
        }
      }

      imageView.frame = CGRect(x: xOffset, y: yOffset, width: actualImageWidth, height: actualImageHeight)

      let topY = yOffset
      let pageLabelWidth = max(30, pageNumberLabel.intrinsicContentSize.width + 16)
      let pageLabelHeight: CGFloat = 24

      let alignment = currentData?.alignment ?? .center
      let isLeft: Bool
      if alignment == .center {
        isLeft = isRTL
      } else if alignment == .trailing {
        isLeft = !isRTL
      } else {
        isLeft = isRTL
      }

      let topInset: CGFloat = 12
      if isLeft {
        pageNumberLabel.frame = CGRect(
          x: xOffset + 12, y: topY + topInset, width: pageLabelWidth, height: pageLabelHeight)
      } else {
        pageNumberLabel.frame = CGRect(
          x: xOffset + actualImageWidth - pageLabelWidth - 12,
          y: topY + topInset,
          width: pageLabelWidth,
          height: pageLabelHeight
        )
      }
    }

    func getCombinedRectRelativeToImage() -> CGRect {
      let imageRectInSelf = CGRect(origin: .zero, size: imageView.bounds.size)
      var combinedRect = imageRectInSelf

      if !pageNumberLabel.isHidden {
        let labelFrameInImage = convert(pageNumberLabel.frame, to: imageView)
        combinedRect = combinedRect.union(labelFrameInImage)
      }

      return combinedRect
    }
  }
#endif
