#if os(macOS)
  import AppKit
  import QuartzCore
  import SwiftUI
  import VisionKit

  // Extension to find KeyboardHandlerView in view hierarchy
  extension NSView {
    func findViewOfType<T: NSView>(_ type: T.Type) -> T? {
      if let view = self as? T {
        return view
      }
      for subview in subviews {
        if let found = subview.findViewOfType(type) {
          return found
        }
      }
      return nil
    }
  }

  struct PageScrollView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NSScrollView {
      let scrollView = FocusScrollView()
      scrollView.hasVerticalScroller = false
      scrollView.hasHorizontalScroller = false
      scrollView.allowsMagnification = true
      scrollView.minMagnification = minScale
      scrollView.maxMagnification = maxScale

      scrollView.backgroundColor = NSColor(readerBackground.color)
      scrollView.drawsBackground = true

      let contentStack = NSStackView()
      contentStack.orientation = .horizontal
      contentStack.distribution = .fillEqually
      contentStack.spacing = 0
      contentStack.translatesAutoresizingMaskIntoConstraints = false
      scrollView.documentView = contentStack
      context.coordinator.contentStack = contentStack

      NSLayoutConstraint.activate([
        contentStack.widthAnchor.constraint(equalToConstant: screenSize.width)
      ])

      context.coordinator.parent = self
      context.coordinator.scrollView = scrollView
      context.coordinator.applyDisplayModeIfNeeded(in: scrollView)
      context.coordinator.setupNativeInteractions(on: scrollView)

      return scrollView
    }

    @MainActor
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
      coordinator.prepareForDismantle()
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
      context.coordinator.isUpdatingFromSwiftUI = true
      defer {
        DispatchQueue.main.async {
          context.coordinator.isUpdatingFromSwiftUI = false
          context.coordinator.applyInitialZoomIfNeeded(in: nsView)
        }
      }

      context.coordinator.parent = self
      context.coordinator.applyDisplayModeIfNeeded(in: nsView)
      context.coordinator.updatePages()

      // Force focus restoration on state changes to ensure keyboard responsiveness
      if let window = nsView.window {
        let keyboardHandler = window.contentView?.findViewOfType(KeyboardHandlerView.self)

        let isFirstResponderInvalid =
          window.firstResponder == nil
          || window.firstResponder is NSWindow
          || (keyboardHandler != nil && window.firstResponder !== keyboardHandler)

        if isFirstResponderInvalid, let target = keyboardHandler {
          DispatchQueue.main.async {
            if window.firstResponder !== target {
              window.makeFirstResponder(target)
            }
          }
        }
      }

      nsView.backgroundColor = NSColor(readerBackground.color)

      if let focusScroll = nsView as? FocusScrollView {
        focusScroll.readingDirection = readingDirection
        focusScroll.onNextPage = onNextPage
        focusScroll.onPreviousPage = onPreviousPage
      }

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
        context.coordinator.lastInitialZoomID = nil
        nsView.magnification = minScale
      }

      // Sync constraints
      if let stack = context.coordinator.contentStack {
        for constraint in stack.constraints {
          if constraint.firstAttribute == .width { constraint.constant = screenSize.width }
          if constraint.firstAttribute == .height { constraint.constant = screenSize.height }
        }
      }
    }

    @MainActor
    class Coordinator: NSObject, NSGestureRecognizerDelegate {
      var lastResetID: AnyHashable?
      var lastInitialZoomID: AnyHashable?
      var lastDisplayMode: PageDisplayMode?
      var isUpdatingFromSwiftUI = false
      var isLongPressing = false
      var isMenuVisible = false
      var lastZoomOutTime: Date = .distantPast
      var lastLongPressEndTime: Date = .distantPast
      private let logger = AppLogger(.reader)

      var parent: PageScrollView!
      weak var scrollView: NSScrollView?

      weak var contentStack: NSStackView?
      var contentHeightConstraint: NSLayoutConstraint?
      private var pageViews: [NativePageItemMacOS] = []

      func prepareForDismantle() {
        if let scrollView = scrollView {
          NotificationCenter.default.removeObserver(
            self, name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
          NotificationCenter.default.removeObserver(
            self, name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
        }
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
          pageViews = pages.map { _ in NativePageItemMacOS() }
          pageViews.forEach { stack.addArrangedSubview($0) }
        }
        for (index, data) in pages.enumerated() {
          let image = parent.viewModel.preloadedImages[data.pageNumber]
          let targetHeight = targetHeight(for: data, image: image)
          pageViews[index].update(
            with: data,
            viewModel: parent.viewModel,
            image: image,
            showPageNumber: parent.showPageNumber,
            background: parent.readerBackground,
            readingDirection: parent.readingDirection,
            displayMode: parent.displayMode,
            targetHeight: targetHeight
          )
        }

        // Match reading direction
        contentStack?.userInterfaceLayoutDirection = parent.readingDirection == .rtl ? .rightToLeft : .leftToRight
      }

      func setupNativeInteractions(on scrollView: NSScrollView) {
        guard let view = scrollView.documentView else { return }
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        click.numberOfClicksRequired = 1
        click.delegate = self
        view.addGestureRecognizer(click)

        let press = NSPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0.5
        press.delegate = self
        view.addGestureRecognizer(press)

        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handleScrollEnded(_:)),
          name: NSScrollView.didEndLiveScrollNotification,
          object: scrollView
        )
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handleScrollEnded(_:)),
          name: NSScrollView.didEndLiveMagnifyNotification,
          object: scrollView
        )
      }

      func applyDisplayModeIfNeeded(in scrollView: NSScrollView) {
        guard let stack = contentStack else { return }
        guard lastDisplayMode != parent.displayMode else { return }

        lastDisplayMode = parent.displayMode
        contentHeightConstraint?.isActive = false

        switch parent.displayMode {
        case .fit:
          stack.alignment = .centerY
          stack.distribution = .fillEqually
          contentHeightConstraint = stack.heightAnchor.constraint(equalToConstant: parent.screenSize.height)
        case .fillWidth:
          stack.alignment = .top
          stack.distribution = .fill
          contentHeightConstraint = stack.heightAnchor.constraint(
            greaterThanOrEqualToConstant: parent.screenSize.height
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

      @objc func handleScrollEnded(_ notification: Notification) {
        guard !isUpdatingFromSwiftUI, let scrollView = scrollView else { return }

        // Handle Zoom state binding
        let zoomed = scrollView.magnification > (parent.minScale + 0.01)
        if zoomed != parent.viewModel.isZoomed {
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.parent.viewModel.isZoomed != zoomed {
              self.parent.viewModel.isZoomed = zoomed
            }
          }
        }

        // Paging Snap Logic
        if !zoomed {
          let pageWidth = parent.screenSize.width
          guard pageWidth > 0 else { return }

          let currentX = scrollView.contentView.bounds.origin.x
          let targetPage = round(currentX / pageWidth)
          let targetX = targetPage * pageWidth

          if abs(currentX - targetX) > 1 {
            NSAnimationContext.runAnimationGroup { context in
              context.duration = 0.2
              context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
              scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
              scrollView.reflectScrolledClipView(scrollView.contentView)
            }
          }
        }
      }

      @objc func handlePress(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPressing = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          lastLongPressEndTime = Date()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLongPressing = false
          }
        }
      }

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        let now = Date()
        let longPressDiff = now.timeIntervalSince(lastLongPressEndTime)
        let zoomOutDiff = now.timeIntervalSince(lastZoomOutTime)

        guard !isLongPressing && !isMenuVisible else { return }
        if longPressDiff < 0.5 { return }

        guard let scrollView = scrollView else { return }
        if scrollView.magnification > parent.minScale + 0.01 { return }
        if zoomOutDiff < 0.4 { return }

        let location = gesture.location(in: gesture.view)
        let normalizedX = location.x / parent.screenSize.width
        // macOS uses flipped Y coordinate (0 at bottom)
        let normalizedY = 1.0 - (location.y / parent.screenSize.height)

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

        // Recover focus
        restoreKeyboardFocus()
      }

      private func restoreKeyboardFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          if let window = self?.scrollView?.window {
            let keyboardHandler = window.contentView?.findViewOfType(KeyboardHandlerView.self)
            if let target = keyboardHandler, window.firstResponder !== target {
              window.makeFirstResponder(target)
            }
          }
        }
      }

      func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent)
        -> Bool
      {
        guard let view = gestureRecognizer.view else { return true }
        let location = view.convert(event.locationInWindow, from: nil)

        if let hitView = view.hitTest(location) {
          let className = hitView.className

          // Rule 1: NSImageView should ALWAYS allow paging
          if hitView is NSImageView || className == "NSImageView" {
            return true
          }

          // Rule 2: Precision check for interactive buttons/controls in VisionKit
          var current: NSView? = hitView
          while let c = current {
            let cn = c.className
            if c is NSButton || c is NSControl || cn.contains("Button") || cn.contains("Control")
              || cn.contains("Action") || cn.contains("Toggle") || cn.contains("Popup")
            {
              // DO NOT block if it's just a general overlay or background layer
              if !cn.contains("Overlay") && !cn.contains("Background") && !cn.contains("View") {
                return false  // Block paging only for real buttons
              }
              if cn.contains("Button") {
                return false  // Specific block for anything named Button
              }
            }
            if c is NativePageItemMacOS { break }
            current = c.superview
          }

          // Rule 3: If Live Text is active, and we hit the overlay area (VKCActionInfoView etc.):
          // We only allow the paging gesture if the click is in the LEFT/RIGHT paging zones.
          // This allows the center to be used for Live Text interaction (like clicking to deselect).
          if AppConfig.enableLiveText && className.contains("VK") {
            let normalizedX = location.x / parent.screenSize.width
            let threshold = parent.tapZoneSize.value
            let isEdge = normalizedX < threshold || normalizedX > (1.0 - threshold)

            if !isEdge {
              // Clicked in the center of a Live Text overlay: block paging to allow interaction
              return false
            }
          }
        }
        return true
      }

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        return true
      }

      func applyInitialZoomIfNeeded(in scrollView: NSScrollView) {
        guard let initialZoomID = parent.initialZoomID else { return }
        guard initialZoomID != lastInitialZoomID else { return }
        guard scrollView.contentView.bounds.width > 0, scrollView.contentView.bounds.height > 0 else {
          return
        }
        guard let documentView = scrollView.documentView else { return }
        documentView.layoutSubtreeIfNeeded()
        let baseSize = documentView.bounds.size
        guard baseSize.width > 0, baseSize.height > 0 else { return }

        let scale = clampedScale(parent.initialZoomScale ?? parent.minScale)
        let baseAnchor = clampedAnchor(parent.initialZoomAnchor ?? CGPoint(x: 0.5, y: 0.5))
        let adjustedAnchor = clampedAnchor(adjustedAnchorForFillWidth(baseAnchor, contentSize: baseSize))
        let convertedAnchorY = 1.0 - adjustedAnchor.y
        let center = CGPoint(
          x: baseSize.width * adjustedAnchor.x,
          y: baseSize.height * convertedAnchorY
        )
        let scaledCenter = CGPoint(x: center.x * scale, y: center.y * scale)
        let contentSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
        let viewport = scrollView.contentView.bounds.size

        var origin = CGPoint(x: scaledCenter.x - viewport.width / 2, y: scaledCenter.y - viewport.height / 2)
        let maxX = max(contentSize.width - viewport.width, 0)
        let maxY = max(contentSize.height - viewport.height, 0)
        origin.x = min(max(origin.x, 0), maxX)
        origin.y = min(max(origin.y, 0), maxY)

        scrollView.magnification = scale
        scrollView.contentView.scroll(to: NSPoint(x: origin.x, y: origin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        let zoomed = scale > (parent.minScale + 0.01)
        if zoomed != parent.viewModel.isZoomed {
          parent.viewModel.isZoomed = zoomed
        }

        lastInitialZoomID = initialZoomID
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

  private class FocusScrollView: NSScrollView {
    var onNextPage: (() -> Void)?
    var onPreviousPage: (() -> Void)?
    var readingDirection: ReadingDirection = .ltr

    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 100.0
    private var hasPageTurnedInCurrentGesture = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
      super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
      self.nextResponder?.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
      guard magnification <= minMagnification + 0.01 else {
        super.scrollWheel(with: event)
        return
      }

      if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
        if event.phase == .began {
          scrollAccumulator = 0
          hasPageTurnedInCurrentGesture = false
        }

        if !hasPageTurnedInCurrentGesture {
          scrollAccumulator += event.scrollingDeltaX
          if abs(scrollAccumulator) >= scrollThreshold {
            if scrollAccumulator > 0 {
              readingDirection == .rtl ? onPreviousPage?() : onNextPage?()
            } else {
              readingDirection == .rtl ? onNextPage?() : onPreviousPage?()
            }
            hasPageTurnedInCurrentGesture = true
            scrollAccumulator = 0
          }
        }

        if event.phase == .ended || event.phase == .cancelled {
          scrollAccumulator = 0
          hasPageTurnedInCurrentGesture = false
        }
      } else {
        super.scrollWheel(with: event)
      }
    }
  }

  private class NativePageItemMacOS: NSView {
    private let imageView = NSImageView()
    private let pageNumberContainer = NSView()
    private let pageNumberLabel = NSTextField()
    private let progressIndicator = NSProgressIndicator()
    private let errorLabel = NSTextField()

    private let overlayView = ImageAnalysisOverlayView()
    private var analysisTask: Task<Void, Never>?
    private var analyzedImage: NSImage?
    private var currentData: NativePageData?
    private var readingDirection: ReadingDirection = .ltr
    private var displayMode: PageDisplayMode = .fit
    private weak var readerViewModel: ReaderViewModel?
    private let logger = AppLogger(.reader)
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
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window == nil {
        clearAnalysis()
        imageView.image = nil
        analyzedImage = nil
      } else {
        // Restore image when returning to window if it was cleared
        if imageView.image == nil, let data = currentData {
          imageView.image = readerViewModel?.preloadedImages[data.pageNumber]
        }
        if AppConfig.enableLiveText {
          if let image = imageView.image {
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

      // Add shadow for premium look
      imageView.layer?.shadowColor = NSColor.black.cgColor
      imageView.layer?.shadowOpacity = 0.25
      imageView.layer?.shadowOffset = CGSize(width: 0, height: -2)
      imageView.layer?.shadowRadius = 2

      addSubview(imageView)

      overlayView.isHidden = true
      overlayView.wantsLayer = true
      overlayView.translatesAutoresizingMaskIntoConstraints = true
      addSubview(overlayView)

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
      background: ReaderBackground,
      readingDirection: ReadingDirection,
      displayMode: PageDisplayMode,
      targetHeight: CGFloat
    ) {
      self.currentData = data
      self.readerViewModel = viewModel
      self.readingDirection = readingDirection

      // Handle split mode - crop the image if needed
      let displayImage: PlatformImage?
      if let image = image, data.splitMode != .none {
        displayImage = cropImageForSplitMode(image: image, splitMode: data.splitMode)
      } else {
        displayImage = image
      }

      imageView.image = displayImage
      imageView.layer?.shadowOpacity = displayImage == nil ? 0 : 0.25

      updateHeightConstraint(targetHeight)

      if displayImage != nil, showPageNumber {
        pageNumberLabel.stringValue = "\(data.pageNumber + 1)"
        pageNumberContainer.isHidden = false
      } else {
        pageNumberContainer.isHidden = true
      }

      // Show error or loading indicator
      if let error = data.error {
        progressIndicator.stopAnimation(nil)
        errorLabel.stringValue = error
        errorLabel.isHidden = false
      } else if displayImage == nil || data.isLoading {
        errorLabel.isHidden = true
        progressIndicator.startAnimation(nil)
      } else {
        errorLabel.isHidden = true
        progressIndicator.stopAnimation(nil)
      }

      if AppConfig.enableLiveText, let img = displayImage, !visibleRect.isEmpty {
        analyzeImage(img)
        overlayView.isHidden = false
      } else if !AppConfig.enableLiveText {
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

      // Calculate the crop rect for half the image
      let cropRect: CGRect
      if splitMode == .leftHalf {
        cropRect = CGRect(x: 0, y: 0, width: imageSize.width / 2, height: imageSize.height)
      } else {
        cropRect = CGRect(x: imageSize.width / 2, y: 0, width: imageSize.width / 2, height: imageSize.height)
      }

      // Create cropped image
      guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
        return image
      }

      return NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
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
        overlayView.isHidden = false
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
          let analysis = try await LiveTextManager.shared.analyzer.analyze(
            image, orientation: .up, configuration: configuration)
          if !Task.isCancelled {
            guard let self = self else { return }
            self.overlayView.analysis = analysis
            self.overlayView.preferredInteractionTypes = .automatic
            self.overlayView.isHidden = false
            let duration = Date().timeIntervalSince(startTime)
            self.logger.info(
              String(
                format: "[LiveText] [\(bookId)] ✅ Finished macOS analysis for page %d in %.2fs", pageNum + 1, duration))
          }
        } catch {
          if !Task.isCancelled {
            guard let self = self else { return }
            self.logger.error("[LiveText] [\(bookId)] ❌ macOS Analysis failed for page \(pageNum + 1): \(error)")
          }
        }
      }
    }

    private func clearAnalysis() {
      analysisTask?.cancel()
      analysisTask = nil
      analyzedImage = nil
      overlayView.analysis = nil
      overlayView.isHidden = true
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
          // outer edge
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

      // Update shadow path for performance and remove shadow at spine in dual-page mode
      let radius = imageView.layer?.shadowRadius ?? 0
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
      imageView.layer?.shadowPath = CGPath(rect: shadowRect, transform: nil)

      if AppConfig.enableLiveText, currentData != nil,
        let image = imageView.image,
        !visibleRect.isEmpty, overlayView.analysis == nil, analysisTask == nil
      {
        analyzeImage(image)
        overlayView.isHidden = false
      }
    }
  }
#endif
