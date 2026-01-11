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
    let doubleTapScale: CGFloat
    @Binding var isZoomed: Bool

    let tapZoneSize: TapZoneSize
    let disableTapToTurnPage: Bool
    let showPageNumber: Bool
    let readerBackground: ReaderBackground
    let readingDirection: ReadingDirection
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleControls: () -> Void

    let pages: [NativePageData]

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
      let scrollView = FocusScrollView()
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = true
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
        contentStack.widthAnchor.constraint(equalToConstant: screenSize.width),
        contentStack.heightAnchor.constraint(equalToConstant: screenSize.height),
      ])

      context.coordinator.setupNativeInteractions(on: scrollView)

      return scrollView
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
      coordinator.prepareForDismantle()
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
      context.coordinator.isUpdatingFromSwiftUI = true
      defer {
        DispatchQueue.main.async {
          context.coordinator.isUpdatingFromSwiftUI = false
        }
      }

      context.coordinator.syncStates(
        viewModel: viewModel,
        pages: pages,
        screenSize: screenSize,
        isZoomed: $isZoomed,
        minScale: minScale,
        tapZoneSize: tapZoneSize,
        disableTapToTurnPage: disableTapToTurnPage,
        showPageNumber: showPageNumber,
        readingDirection: readingDirection,
        onNextPage: onNextPage,
        onPreviousPage: onPreviousPage,
        onToggleControls: onToggleControls,
        scrollView: nsView,
        readerBackground: readerBackground
      )

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

      if context.coordinator.lastResetID != resetID {
        context.coordinator.lastResetID = resetID
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

    class Coordinator: NSObject, NSGestureRecognizerDelegate {
      var lastResetID: AnyHashable?
      var isUpdatingFromSwiftUI = false
      var isLongPressing = false
      var isMenuVisible = false
      var lastZoomOutTime: Date = .distantPast
      var lastLongPressEndTime: Date = .distantPast
      private let logger = AppLogger(.reader)

      private var mirrorPages: [NativePageData] = []
      private weak var readerViewModel: ReaderViewModel?
      private var mirrorScreenSize: CGSize = .zero
      private var mirrorMinScale: CGFloat = 1.0
      private var mirrorTapZoneSize: TapZoneSize = .large
      private var mirrorDisableTapToTurnPage: Bool = false
      private var mirrorShowPageNumber: Bool = true
      private var mirrorReadingDirection: ReadingDirection = .ltr
      private var mirrorOnNextPage: () -> Void = {}
      private var mirrorOnPreviousPage: () -> Void = {}
      private var mirrorOnToggleControls: () -> Void = {}
      private var isZoomedBinding: Binding<Bool>?
      weak var scrollView: NSScrollView?
      private var mirrorReaderBackground: ReaderBackground = .system

      weak var contentStack: NSStackView?
      private var pageViews: [NativePageItemMacOS] = []

      deinit {
        prepareForDismantle()
      }

      func prepareForDismantle() {
        if let scrollView = scrollView {
          NotificationCenter.default.removeObserver(
            self, name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
        }
        pageViews.forEach { view in
          view.prepareForDismantle()
          view.removeFromSuperview()
        }
        pageViews.removeAll()
        mirrorPages.removeAll()
      }

      func syncStates(
        viewModel: ReaderViewModel,
        pages: [NativePageData],
        screenSize: CGSize,
        isZoomed: Binding<Bool>,
        minScale: CGFloat,
        tapZoneSize: TapZoneSize,
        disableTapToTurnPage: Bool,
        showPageNumber: Bool,
        readingDirection: ReadingDirection,
        onNextPage: @escaping () -> Void,
        onPreviousPage: @escaping () -> Void,
        onToggleControls: @escaping () -> Void,
        scrollView: NSScrollView,
        readerBackground: ReaderBackground
      ) {
        self.readerViewModel = viewModel
        self.mirrorPages = pages
        self.mirrorScreenSize = screenSize
        self.isZoomedBinding = isZoomed
        self.mirrorMinScale = minScale
        self.mirrorTapZoneSize = tapZoneSize
        self.mirrorDisableTapToTurnPage = disableTapToTurnPage
        self.mirrorShowPageNumber = showPageNumber
        self.mirrorReadingDirection = readingDirection
        self.mirrorOnNextPage = onNextPage
        self.mirrorOnPreviousPage = onPreviousPage
        self.mirrorOnToggleControls = onToggleControls
        self.scrollView = scrollView
        self.mirrorReaderBackground = readerBackground

        if let focusScroll = scrollView as? FocusScrollView {
          focusScroll.readingDirection = readingDirection
          focusScroll.onNextPage = onNextPage
          focusScroll.onPreviousPage = onPreviousPage
        }

        updatePages()
      }

      private func updatePages() {
        guard let stack = contentStack else { return }

        if pageViews.count != mirrorPages.count {
          pageViews.forEach { $0.removeFromSuperview() }
          pageViews = mirrorPages.map { _ in NativePageItemMacOS() }
          pageViews.forEach { stack.addArrangedSubview($0) }
        }
        for (index, data) in mirrorPages.enumerated() {
          if let viewModel = self.readerViewModel {
            let image = viewModel.preloadedImages[data.pageNumber]
            pageViews[index].update(
              with: data, viewModel: viewModel, image: image, showPageNumber: mirrorShowPageNumber,
              background: mirrorReaderBackground)
          }
        }
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
      }

      @objc func handleScrollEnded(_ notification: Notification) {
        guard !isUpdatingFromSwiftUI, let scrollView = scrollView else { return }

        // Handle Zoom state binding
        let zoomed = scrollView.magnification > mirrorMinScale + 0.01
        if isZoomedBinding?.wrappedValue != zoomed {
          DispatchQueue.main.async { [weak self] in
            guard let self = self, let binding = self.isZoomedBinding else { return }
            if binding.wrappedValue != zoomed {
              binding.wrappedValue = zoomed
            }
          }
        }

        // Paging Snap Logic
        if !zoomed {
          let pageWidth = mirrorScreenSize.width
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
        if scrollView.magnification > mirrorMinScale + 0.01 { return }
        if zoomOutDiff < 0.4 { return }

        if mirrorDisableTapToTurnPage {
          mirrorOnToggleControls()
          return
        }

        let location = gesture.location(in: gesture.view)
        let normalizedX = location.x / mirrorScreenSize.width
        let threshold = mirrorTapZoneSize.value

        if mirrorReadingDirection == .vertical || mirrorReadingDirection == .webtoon {
          let normalizedY = 1.0 - (location.y / mirrorScreenSize.height)
          if normalizedY < threshold {
            mirrorOnPreviousPage()
          } else if normalizedY > (1.0 - threshold) {
            mirrorOnNextPage()
          } else {
            mirrorOnToggleControls()
          }
        } else {
          if normalizedX < threshold {
            mirrorReadingDirection == .rtl ? mirrorOnNextPage() : mirrorOnPreviousPage()
          } else if normalizedX > (1.0 - threshold) {
            mirrorReadingDirection == .rtl ? mirrorOnPreviousPage() : mirrorOnNextPage()
          } else {
            mirrorOnToggleControls()
          }
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
            let normalizedX = location.x / mirrorScreenSize.width
            let threshold = mirrorTapZoneSize.value
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
    private let pageNumberLabel = NSTextField()
    private let progressIndicator = NSProgressIndicator()

    private let overlayView = ImageAnalysisOverlayView()
    private var analysisTask: Task<Void, Never>?
    private var analyzedImage: NSImage?
    private var currentData: NativePageData?
    private weak var readerViewModel: ReaderViewModel?
    private let logger = AppLogger(.reader)

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

      pageNumberLabel.isEditable = false
      pageNumberLabel.isSelectable = false
      pageNumberLabel.isBordered = false
      pageNumberLabel.drawsBackground = true
      pageNumberLabel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
      pageNumberLabel.font = .systemFont(ofSize: 14, weight: .semibold)
      pageNumberLabel.textColor = .white
      pageNumberLabel.alignment = .center
      pageNumberLabel.wantsLayer = true
      pageNumberLabel.layer?.cornerRadius = 6
      pageNumberLabel.layer?.masksToBounds = true
      pageNumberLabel.translatesAutoresizingMaskIntoConstraints = false
      addSubview(pageNumberLabel)

      NSLayoutConstraint.activate([
        progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        pageNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        pageNumberLabel.heightAnchor.constraint(equalToConstant: 24),
      ])
    }

    func update(
      with data: NativePageData, viewModel: ReaderViewModel, image: PlatformImage?, showPageNumber: Bool,
      background: ReaderBackground
    ) {
      self.currentData = data
      self.readerViewModel = viewModel
      imageView.image = image

      if image != nil, showPageNumber {
        pageNumberLabel.stringValue = "\(data.pageNumber + 1)"
        pageNumberLabel.isHidden = false
      } else {
        pageNumberLabel.isHidden = true
      }

      if data.isLoading { progressIndicator.startAnimation(nil) } else { progressIndicator.stopAnimation(nil) }

      if AppConfig.enableLiveText, let img = image, !visibleRect.isEmpty {
        analyzeImage(img)
        overlayView.isHidden = false
      } else if !AppConfig.enableLiveText {
        clearAnalysis()
      }

      updateOverlaysPosition()
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
      let viewSize = bounds.size
      if viewSize.width == 0 || viewSize.height == 0 { return }

      let widthRatio = viewSize.width / imageSize.width
      let heightRatio = viewSize.height / imageSize.height
      let scale = min(widthRatio, heightRatio)

      let actualImageWidth = imageSize.width * scale
      let actualImageHeight = imageSize.height * scale
      let yOffset = (viewSize.height - actualImageHeight) / 2

      let isRTL = userInterfaceLayoutDirection == .rightToLeft
      var xOffset: CGFloat = (viewSize.width - actualImageWidth) / 2

      if let alignment = currentData?.alignment {
        if alignment == .leading {
          xOffset = isRTL ? (viewSize.width - actualImageWidth) : 0
        } else if alignment == .trailing {
          xOffset = isRTL ? 0 : (viewSize.width - actualImageWidth)
        }
      }

      let imgFrame = NSRect(x: xOffset, y: yOffset, width: actualImageWidth, height: actualImageHeight)
      imageView.frame = imgFrame
      overlayView.frame = imgFrame

      let topY = yOffset + actualImageHeight - 38

      if let alignment = currentData?.alignment {
        let isLeftPage = (!isRTL && alignment == .trailing) || (isRTL && alignment == .leading)
        if isLeftPage {
          pageNumberLabel.setFrameOrigin(NSPoint(x: xOffset + 12, y: topY))
        } else {
          pageNumberLabel.setFrameOrigin(
            NSPoint(x: xOffset + actualImageWidth - pageNumberLabel.bounds.width - 12, y: topY))
        }
      } else {
        pageNumberLabel.setFrameOrigin(NSPoint(x: (viewSize.width - pageNumberLabel.bounds.width) / 2, y: topY))
      }
    }

    override func layout() {
      super.layout()
      updateOverlaysPosition()

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
