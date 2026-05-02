//
// WebPubPagedCoverView.swift
//
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct WebPubPagedCoverView: UIViewControllerRepresentable {
    @Bindable var viewModel: EpubReaderViewModel
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme
    let animateTapTurns: Bool
    let showingControls: Bool
    let bookTitle: String?
    let onCenterTap: () -> Void
    let onEndReached: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CoverEpubContainerViewController {
      let container = CoverEpubContainerViewController()
      container.coordinator = context.coordinator
      context.coordinator.containerViewController = container

      let initialChapterIndex = viewModel.currentChapterIndex
      let initialPageCount = viewModel.chapterPageCount(at: initialChapterIndex) ?? 1
      let initialPageIndex = max(0, min(viewModel.currentPageIndex, initialPageCount - 1))

      if let initialVC = context.coordinator.makePageViewController(
        chapterIndex: initialChapterIndex,
        subPageIndex: initialPageIndex
      ) {
        context.coordinator.rebuildDeck(
          around: initialVC,
          chapterIndex: initialChapterIndex,
          subPageIndex: initialPageIndex
        )
        context.coordinator.currentChapterIndex = initialChapterIndex
        context.coordinator.currentPageIndex = initialPageIndex
        Task { @MainActor in
          viewModel.currentChapterIndex = initialChapterIndex
          viewModel.currentPageIndex = initialPageIndex
        }
      }

      return container
    }

    func updateUIViewController(_ container: CoverEpubContainerViewController, context: Context) {
      context.coordinator.parent = self
      context.coordinator.containerViewController = container
      defer { context.coordinator.hasCompletedInitialUpdate = true }

      let initialChapterIndex = viewModel.currentChapterIndex
      let initialPageCount = viewModel.chapterPageCount(at: initialChapterIndex) ?? 1
      let initialPageIndex = max(0, min(viewModel.currentPageIndex, initialPageCount - 1))

      if context.coordinator.frontController == nil,
        initialChapterIndex >= 0,
        initialChapterIndex < viewModel.chapterCount,
        let initialVC = context.coordinator.makePageViewController(
          chapterIndex: initialChapterIndex,
          subPageIndex: initialPageIndex
        )
      {
        context.coordinator.rebuildDeck(
          around: initialVC,
          chapterIndex: initialChapterIndex,
          subPageIndex: initialPageIndex
        )
        context.coordinator.currentChapterIndex = initialChapterIndex
        context.coordinator.currentPageIndex = initialPageIndex
      }

      if let targetChapterIndex = viewModel.targetChapterIndex,
        let targetPageIndex = viewModel.targetPageIndex,
        !context.coordinator.isAnimating,
        targetChapterIndex >= 0,
        targetChapterIndex < viewModel.chapterCount,
        targetChapterIndex != context.coordinator.currentChapterIndex
          || targetPageIndex != context.coordinator.currentPageIndex
      {
        let pageCount = viewModel.chapterPageCount(at: targetChapterIndex) ?? 1
        let isLastPageRequest = targetPageIndex < 0
        let normalizedPageIndex =
          isLastPageRequest
          ? max(0, pageCount - 1)
          : max(0, min(targetPageIndex, pageCount - 1))

        guard
          let targetVC = context.coordinator.makePageViewController(
            chapterIndex: targetChapterIndex,
            subPageIndex: normalizedPageIndex,
            preferLastPageOnReady: isLastPageRequest
          )
        else { return }

        let isForward =
          targetChapterIndex > context.coordinator.currentChapterIndex
          || (targetChapterIndex == context.coordinator.currentChapterIndex
            && normalizedPageIndex > context.coordinator.currentPageIndex)

        let shouldAnimate = context.coordinator.hasCompletedInitialUpdate && animateTapTurns

        if shouldAnimate {
          context.coordinator.animateTransition(
            to: targetVC,
            chapterIndex: targetChapterIndex,
            subPageIndex: normalizedPageIndex,
            forward: isForward
          )
        } else {
          context.coordinator.rebuildDeck(
            around: targetVC,
            chapterIndex: targetChapterIndex,
            subPageIndex: normalizedPageIndex
          )
          context.coordinator.currentChapterIndex = targetChapterIndex
          context.coordinator.currentPageIndex = normalizedPageIndex
          Task { @MainActor in
            viewModel.currentChapterIndex = targetChapterIndex
            viewModel.currentPageIndex = normalizedPageIndex
            viewModel.targetChapterIndex = nil
            viewModel.targetPageIndex = nil
            viewModel.pageDidChange()
          }
        }
      }

      if let frontVC = context.coordinator.frontController {
        context.coordinator.configureVisibleController(frontVC)
      }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var parent: WebPubPagedCoverView
      var currentChapterIndex: Int
      var currentPageIndex: Int
      var isAnimating = false
      var hasCompletedInitialUpdate = false
      weak var containerViewController: CoverEpubContainerViewController?

      private(set) var frontController: EpubPageViewController?
      private var nextController: EpubPageViewController?
      private var previousController: EpubPageViewController?

      private var panRecognizer: UIPanGestureRecognizer?
      private var tapRecognizer: UITapGestureRecognizer?
      private var longPressRecognizer: UILongPressGestureRecognizer?
      private var isLongPressing = false
      private var lastLongPressEndTime: Date = .distantPast
      private var lastTouchStartTime: Date = .distantPast

      private var transitionDirection: Int?
      private var dragOffset: CGFloat = 0

      private let maxCachedControllers = 5
      private var cachedControllers: [String: EpubPageViewController] = [:]
      private var controllerKeys: [ObjectIdentifier: String] = [:]

      private enum Metrics {
        static let minimumDragDistance: CGFloat = 1
        static let directionalDragBias: CGFloat = 4
        static let overscrollResistance: CGFloat = 0.2
        static let cancelThreshold: CGFloat = 0.5
        static let commitDistanceRatio: CGFloat = 0.18
        static let commitVelocityThreshold: CGFloat = 700
        static let movingShadowOpacity: Float = 0.12
        static let idleShadowOpacity: Float = 0.05
        static let movingShadowRadius: CGFloat = 5
        static let idleShadowRadius: CGFloat = 2
        static let movingShadowOffset: CGFloat = 3
        static let idleShadowOffset: CGFloat = 1
        static let animationDuration: TimeInterval = 0.3
      }

      init(_ parent: WebPubPagedCoverView) {
        self.parent = parent
        self.currentChapterIndex = parent.viewModel.currentChapterIndex
        self.currentPageIndex = parent.viewModel.currentPageIndex
        super.init()
      }

      func setupGestures(on view: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = self
        view.addGestureRecognizer(pan)
        panRecognizer = pan

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapRecognizer = tap

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        view.addGestureRecognizer(longPress)
        longPressRecognizer = longPress
      }

      private func cacheKey(chapterIndex: Int, pageIndex: Int) -> String {
        "\(chapterIndex)-\(pageIndex)"
      }

      func makePageViewController(
        chapterIndex: Int,
        subPageIndex: Int,
        preferLastPageOnReady: Bool = false
      ) -> EpubPageViewController? {
        guard chapterIndex >= 0, chapterIndex < parent.viewModel.chapterCount else { return nil }
        let pageCount = parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
        if !preferLastPageOnReady {
          guard subPageIndex >= 0, subPageIndex < pageCount else { return nil }
        } else {
          guard subPageIndex >= 0 else { return nil }
        }

        let containerInsets = parent.viewModel.containerInsetsForLabels().uiEdgeInsets
        let theme = parent.preferences.resolvedTheme(for: parent.colorScheme)
        if let fontName = parent.preferences.fontFamily.fontName {
          parent.viewModel.ensureFontCopied(fontName: fontName)
        }
        let fontPath = parent.preferences.fontFamily.fontName.flatMap {
          CustomFontStore.shared.getFontPath(for: $0)
        }
        let chapterURL = parent.viewModel.chapterURL(at: chapterIndex)
        let rootURL = parent.viewModel.resourceRootURL
        let readiumPayload = parent.preferences.makeReadiumPayload(
          theme: theme,
          fontPath: fontPath,
          rootURL: rootURL,
          viewportSize: parent.viewModel.resolvedViewportSize
        )
        let chapterIndexForCallback = chapterIndex
        let onPageCountReady: (Int) -> Void = { [weak viewModel = parent.viewModel] pageCount in
          Task { @MainActor in
            viewModel?.updateChapterPageCount(pageCount, for: chapterIndexForCallback)
          }
        }

        let locationPageIndex = min(max(subPageIndex, 0), max(0, pageCount - 1))
        guard
          let location = parent.viewModel.pageLocation(
            chapterIndex: chapterIndex,
            pageIndex: locationPageIndex
          )
        else { return nil }
        let chapterProgress =
          location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = parent.viewModel.totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )
        let initialProgression = parent.viewModel.initialProgression(for: chapterIndex)

        let key = cacheKey(chapterIndex: chapterIndex, pageIndex: subPageIndex)
        if let cached = cachedControllers[key] {
          cached.configure(
            chapterURL: chapterURL,
            rootURL: rootURL,
            containerInsets: containerInsets,
            theme: theme,
            contentCSS: readiumPayload.css,
            readiumProperties: readiumPayload.properties,
            publicationLanguage: parent.viewModel.publicationLanguage,
            publicationReadingProgression: parent.viewModel.publicationReadingProgression,
            chapterIndex: chapterIndex,
            subPageIndex: subPageIndex,
            totalPages: pageCount,
            bookTitle: parent.bookTitle,
            chapterTitle: location.title,
            totalProgression: totalProgression,
            showingControls: parent.showingControls,
            labelTopOffset: parent.viewModel.labelTopOffset,
            labelBottomOffset: parent.viewModel.labelBottomOffset,
            useSafeArea: parent.viewModel.useSafeArea,
            preferLastPageOnReady: preferLastPageOnReady,
            targetProgressionOnReady: initialProgression,
            onPageCountReady: onPageCountReady
          )
          configurePageController(cached)
          cached.loadViewIfNeeded()
          return cached
        }

        let protectedIDs = Set(
          [frontController, nextController, previousController].compactMap {
            $0.map { ObjectIdentifier($0) }
          })
        if let reusable = cachedControllers.values.first(where: {
          !protectedIDs.contains(ObjectIdentifier($0))
        }) {
          reusable.configure(
            chapterURL: chapterURL,
            rootURL: rootURL,
            containerInsets: containerInsets,
            theme: theme,
            contentCSS: readiumPayload.css,
            readiumProperties: readiumPayload.properties,
            publicationLanguage: parent.viewModel.publicationLanguage,
            publicationReadingProgression: parent.viewModel.publicationReadingProgression,
            chapterIndex: chapterIndex,
            subPageIndex: subPageIndex,
            totalPages: pageCount,
            bookTitle: parent.bookTitle,
            chapterTitle: location.title,
            totalProgression: totalProgression,
            showingControls: parent.showingControls,
            labelTopOffset: parent.viewModel.labelTopOffset,
            labelBottomOffset: parent.viewModel.labelBottomOffset,
            useSafeArea: parent.viewModel.useSafeArea,
            preferLastPageOnReady: preferLastPageOnReady,
            targetProgressionOnReady: initialProgression,
            onPageCountReady: onPageCountReady
          )
          configurePageController(reusable)
          reusable.onLinkTap = { [weak self] url in
            self?.parent.viewModel.navigateToURL(url)
          }
          reusable.loadViewIfNeeded()
          storeController(reusable, for: key)
          return reusable
        }

        let controller = EpubPageViewController(
          chapterURL: chapterURL,
          rootURL: rootURL,
          containerInsets: containerInsets,
          theme: theme,
          contentCSS: readiumPayload.css,
          readiumProperties: readiumPayload.properties,
          publicationLanguage: parent.viewModel.publicationLanguage,
          publicationReadingProgression: parent.viewModel.publicationReadingProgression,
          chapterIndex: chapterIndex,
          subPageIndex: subPageIndex,
          totalPages: pageCount,
          bookTitle: parent.bookTitle,
          chapterTitle: location.title,
          totalProgression: totalProgression,
          showingControls: parent.showingControls,
          labelTopOffset: parent.viewModel.labelTopOffset,
          labelBottomOffset: parent.viewModel.labelBottomOffset,
          useSafeArea: parent.viewModel.useSafeArea,
          onPageCountReady: onPageCountReady
        )
        controller.preferLastPageOnReady = preferLastPageOnReady
        controller.targetProgressionOnReady = initialProgression
        configurePageController(controller)
        controller.onLinkTap = { [weak self] url in
          self?.parent.viewModel.navigateToURL(url)
        }
        controller.loadViewIfNeeded()
        storeController(controller, for: key)
        return controller
      }

      private func configurePageController(_ controller: EpubPageViewController) {
        controller.onPageIndexAdjusted = { [weak self, weak controller] pageIndex in
          guard let self, let controller else { return }
          guard self.frontController === controller else { return }
          let chapterIndex = controller.chapterIndex
          let storedCount = self.parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
          let effectiveCount = max(storedCount, controller.totalPagesInChapter)
          let normalizedPageIndex = max(0, min(pageIndex, effectiveCount - 1))
          if effectiveCount != storedCount {
            self.parent.viewModel.updateChapterPageCount(effectiveCount, for: chapterIndex)
          }
          self.parent.viewModel.currentChapterIndex = chapterIndex
          self.parent.viewModel.currentPageIndex = normalizedPageIndex
          self.currentChapterIndex = chapterIndex
          self.currentPageIndex = normalizedPageIndex
          self.parent.viewModel.pageDidChange()
        }
      }

      func configureVisibleController(_ controller: EpubPageViewController) {
        let chapterIndex = controller.chapterIndex
        let containerInsets = parent.viewModel.containerInsetsForLabels().uiEdgeInsets
        let theme = parent.preferences.resolvedTheme(for: parent.colorScheme)
        if let fontName = parent.preferences.fontFamily.fontName {
          parent.viewModel.ensureFontCopied(fontName: fontName)
        }
        let fontPath = parent.preferences.fontFamily.fontName.flatMap {
          CustomFontStore.shared.getFontPath(for: $0)
        }
        let readiumPayload = parent.preferences.makeReadiumPayload(
          theme: theme,
          fontPath: fontPath,
          rootURL: parent.viewModel.resourceRootURL,
          viewportSize: parent.viewModel.resolvedViewportSize
        )

        guard
          let location = parent.viewModel.pageLocation(
            chapterIndex: chapterIndex,
            pageIndex: controller.currentSubPageIndex
          )
        else { return }
        let chapterProgress =
          location.pageCount > 0 ? Double(location.pageIndex + 1) / Double(location.pageCount) : nil
        let totalProgression = parent.viewModel.totalProgression(
          location: location,
          chapterProgress: chapterProgress
        )

        controller.configure(
          chapterURL: parent.viewModel.chapterURL(at: chapterIndex),
          rootURL: parent.viewModel.resourceRootURL,
          containerInsets: containerInsets,
          theme: theme,
          contentCSS: readiumPayload.css,
          readiumProperties: readiumPayload.properties,
          publicationLanguage: parent.viewModel.publicationLanguage,
          publicationReadingProgression: parent.viewModel.publicationReadingProgression,
          chapterIndex: chapterIndex,
          subPageIndex: controller.currentSubPageIndex,
          totalPages: controller.totalPagesInChapter,
          bookTitle: parent.bookTitle,
          chapterTitle: location.title,
          totalProgression: totalProgression,
          showingControls: parent.showingControls,
          labelTopOffset: parent.viewModel.labelTopOffset,
          labelBottomOffset: parent.viewModel.labelBottomOffset,
          useSafeArea: parent.viewModel.useSafeArea,
          onPageCountReady: { [weak viewModel = parent.viewModel] pageCount in
            Task { @MainActor in
              viewModel?.updateChapterPageCount(pageCount, for: chapterIndex)
            }
          }
        )
      }

      private func storeController(_ controller: EpubPageViewController, for key: String) {
        let identifier = ObjectIdentifier(controller)
        if let existingKey = controllerKeys[identifier] {
          cachedControllers.removeValue(forKey: existingKey)
        }
        controllerKeys[identifier] = key
        cachedControllers[key] = controller
        if cachedControllers.count > maxCachedControllers {
          evictUnusedControllers()
        }
      }

      private func evictUnusedControllers() {
        let protectedIDs = Set(
          [frontController, nextController, previousController].compactMap {
            $0.map { ObjectIdentifier($0) }
          })
        for (key, controller) in cachedControllers {
          if cachedControllers.count <= maxCachedControllers { break }
          let identifier = ObjectIdentifier(controller)
          if !protectedIDs.contains(identifier) {
            cachedControllers.removeValue(forKey: key)
            controllerKeys.removeValue(forKey: identifier)
          }
        }
      }

      // MARK: - Deck Management

      func rebuildDeck(
        around controller: EpubPageViewController,
        chapterIndex: Int,
        subPageIndex: Int
      ) {
        guard let container = containerViewController else { return }

        removeChildController(frontController, from: container)
        removeChildController(nextController, from: container)
        removeChildController(previousController, from: container)

        frontController = controller
        addChildController(controller, to: container)
        controller.view.frame = container.view.bounds
        controller.view.layer.zPosition = 1
        updateShadow(for: controller.view, isElevated: true, offset: 0)

        let nextTarget = nextPageTarget(chapterIndex: chapterIndex, subPageIndex: subPageIndex)
        if let nextTarget,
          let nextVC = makePageViewController(
            chapterIndex: nextTarget.chapterIndex,
            subPageIndex: nextTarget.subPageIndex
          )
        {
          nextController = nextVC
          addChildController(nextVC, to: container)
          nextVC.view.frame = container.view.bounds
          nextVC.view.layer.zPosition = 0
          nextVC.view.isHidden = true
          warmAdjacentController(nextVC)
        } else {
          nextController = nil
        }

        let prevTarget = previousPageTarget(chapterIndex: chapterIndex, subPageIndex: subPageIndex)
        if let prevTarget,
          let prevVC = makePageViewController(
            chapterIndex: prevTarget.chapterIndex,
            subPageIndex: prevTarget.subPageIndex,
            preferLastPageOnReady: prevTarget.preferLastPage
          )
        {
          previousController = prevVC
          addChildController(prevVC, to: container)
          prevVC.view.frame = container.view.bounds
          prevVC.view.layer.zPosition = 0
          prevVC.view.isHidden = true
          warmAdjacentController(prevVC)
        } else {
          previousController = nil
        }

        transitionDirection = nil
        dragOffset = 0
      }

      private func addChildController(_ child: EpubPageViewController, to parent: UIViewController) {
        guard child.parent !== parent else { return }
        if child.parent != nil {
          child.willMove(toParent: nil)
          child.view.removeFromSuperview()
          child.removeFromParent()
        }
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        child.didMove(toParent: parent)
      }

      private func warmAdjacentController(_ controller: EpubPageViewController) {
        controller.loadViewIfNeeded()
        controller.forceEnsureContentLoaded()
      }

      private func removeChildController(_ child: EpubPageViewController?, from parent: UIViewController) {
        guard let child, child.parent === parent else { return }
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
      }

      private func nextPageTarget(
        chapterIndex: Int,
        subPageIndex: Int
      ) -> (chapterIndex: Int, subPageIndex: Int, preferLastPage: Bool)? {
        let storedCount = parent.viewModel.chapterPageCount(at: chapterIndex) ?? 1
        if subPageIndex < storedCount - 1 {
          return (chapterIndex, subPageIndex + 1, false)
        }
        let nextChapter = chapterIndex + 1
        if nextChapter < parent.viewModel.chapterCount {
          return (nextChapter, 0, false)
        }
        return nil
      }

      private func previousPageTarget(
        chapterIndex: Int,
        subPageIndex: Int
      ) -> (chapterIndex: Int, subPageIndex: Int, preferLastPage: Bool)? {
        if subPageIndex > 0 {
          return (chapterIndex, subPageIndex - 1, false)
        }
        let previousChapter = chapterIndex - 1
        guard previousChapter >= 0 else { return nil }
        let previousCount = parent.viewModel.chapterPageCount(at: previousChapter) ?? 1
        return (previousChapter, max(0, previousCount - 1), previousCount <= 1)
      }

      // MARK: - Gestures

      @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard !isAnimating else { return }
        guard let view = recognizer.view else { return }

        switch recognizer.state {
        case .changed:
          let translation = recognizer.translation(in: view)
          handlePanChanged(translation: translation, viewWidth: view.bounds.width)
        case .ended:
          let translation = recognizer.translation(in: view)
          let velocity = recognizer.velocity(in: view)
          handlePanEnded(translation: translation, velocity: velocity, viewWidth: view.bounds.width)
        case .cancelled, .failed:
          resetDragState()
        default:
          break
        }
      }

      private func handlePanChanged(translation: CGPoint, viewWidth: CGFloat) {
        guard frontController != nil else { return }
        guard abs(translation.x) > abs(translation.y) + Metrics.directionalDragBias else { return }
        guard abs(translation.x) > Metrics.minimumDragDistance else { return }

        let directionOffset = translation.x < 0 ? 1 : -1

        if directionOffset == 1 {
          guard nextController != nil else {
            dragOffset = translation.x * Metrics.overscrollResistance
            transitionDirection = nil
            updateDragLayout(viewWidth: viewWidth)
            return
          }
          transitionDirection = 1
          dragOffset = translation.x
        } else {
          guard previousController != nil else {
            dragOffset = translation.x * Metrics.overscrollResistance
            transitionDirection = nil
            updateDragLayout(viewWidth: viewWidth)
            return
          }
          transitionDirection = -1
          // translation.x is positive when dragging right; map 0→viewWidth to 0→viewWidth for dragOffset
          dragOffset = min(translation.x, viewWidth)
        }

        updateDragLayout(viewWidth: viewWidth)
      }

      private func handlePanEnded(translation: CGPoint, velocity: CGPoint, viewWidth: CGFloat) {
        guard abs(translation.x) > abs(translation.y) + Metrics.directionalDragBias else {
          resetDragState()
          return
        }

        guard transitionDirection != nil else {
          if abs(dragOffset) > Metrics.cancelThreshold {
            cancelDragWithAnimation(viewWidth: viewWidth)
          } else {
            resetDragState()
          }
          return
        }

        let shouldCommit =
          abs(translation.x) > viewWidth * Metrics.commitDistanceRatio
          || abs(velocity.x) > Metrics.commitVelocityThreshold

        if shouldCommit {
          commitCurrentDrag(viewWidth: viewWidth)
        } else {
          cancelDragWithAnimation(viewWidth: viewWidth)
        }
      }

      private func updateDragLayout(viewWidth: CGFloat) {
        guard let container = containerViewController else { return }

        if let direction = transitionDirection {
          if direction == 1 {
            // Forward: front page slides left, revealing next page behind
            frontController?.view.isHidden = false
            frontController?.view.layer.zPosition = 1
            frontController?.view.frame = container.view.bounds.offsetBy(dx: dragOffset, dy: 0)
            updateShadow(for: frontController?.view, isElevated: true, offset: dragOffset)

            nextController?.view.isHidden = false
            nextController?.view.layer.zPosition = 0
            nextController?.view.frame = container.view.bounds

            previousController?.view.isHidden = true
          } else {
            // Backward: previous page slides in from left
            previousController?.view.isHidden = false
            previousController?.view.layer.zPosition = 1
            let offset = dragOffset - viewWidth
            previousController?.view.frame = container.view.bounds.offsetBy(dx: offset, dy: 0)
            updateShadow(for: previousController?.view, isElevated: true, offset: offset)

            frontController?.view.isHidden = false
            frontController?.view.layer.zPosition = 0
            frontController?.view.frame = container.view.bounds

            nextController?.view.isHidden = true
          }
        } else {
          // Overscroll
          frontController?.view.isHidden = false
          frontController?.view.layer.zPosition = 1
          frontController?.view.frame = container.view.bounds.offsetBy(dx: dragOffset, dy: 0)
          updateShadow(for: frontController?.view, isElevated: true, offset: dragOffset)

          nextController?.view.isHidden = true
          previousController?.view.isHidden = true
        }
      }

      private func updateShadow(for view: UIView?, isElevated: Bool, offset: CGFloat) {
        guard let view else { return }
        guard isElevated else {
          view.layer.shadowOpacity = 0
          return
        }

        let isMoving = abs(offset) > Metrics.cancelThreshold
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = isMoving ? Metrics.movingShadowOpacity : Metrics.idleShadowOpacity
        view.layer.shadowRadius = isMoving ? Metrics.movingShadowRadius : Metrics.idleShadowRadius
        view.layer.shadowOffset = CGSize(
          width: isMoving ? (offset < 0 ? Metrics.movingShadowOffset : -Metrics.movingShadowOffset) : 0,
          height: Metrics.idleShadowOffset
        )
      }

      private func commitCurrentDrag(viewWidth: CGFloat) {
        guard let direction = transitionDirection else {
          cancelDragWithAnimation(viewWidth: viewWidth)
          return
        }

        isAnimating = true

        if direction == 1 {
          UIView.animate(
            withDuration: Metrics.animationDuration,
            delay: 0,
            options: [.curveEaseOut]
          ) {
            self.dragOffset = -viewWidth
            self.frontController?.view.frame =
              self.containerViewController?.view.bounds.offsetBy(dx: -viewWidth, dy: 0) ?? .zero
            self.updateShadow(for: self.frontController?.view, isElevated: true, offset: -viewWidth)
          } completion: { _ in
            self.completeForwardTransition()
          }
        } else {
          UIView.animate(
            withDuration: Metrics.animationDuration,
            delay: 0,
            options: [.curveEaseOut]
          ) {
            self.dragOffset = viewWidth
            self.previousController?.view.frame = self.containerViewController?.view.bounds ?? .zero
            self.updateShadow(for: self.previousController?.view, isElevated: true, offset: 0)
          } completion: { _ in
            self.completeBackwardTransition()
          }
        }
      }

      private func completeForwardTransition() {
        guard let container = containerViewController else { return }
        guard let nextVC = nextController else {
          resetDragState()
          return
        }

        let oldFront = frontController
        let oldPrev = previousController

        // Rotate deck
        frontController = nextVC
        previousController = oldFront
        nextController = nil

        // Layout front
        nextVC.view.frame = container.view.bounds
        nextVC.view.layer.zPosition = 1
        nextVC.view.isHidden = false
        updateShadow(for: nextVC.view, isElevated: true, offset: 0)

        // Hide others
        oldFront?.view.isHidden = true
        oldFront?.view.layer.zPosition = 0
        oldPrev?.view.isHidden = true

        // Remove old previous from hierarchy
        if let oldPrev, oldPrev !== nextVC, oldPrev !== oldFront {
          removeChildController(oldPrev, from: container)
        }

        let chapterIndex = nextVC.chapterIndex
        let subPageIndex = nextVC.currentSubPageIndex
        currentChapterIndex = chapterIndex
        currentPageIndex = subPageIndex

        // Preload next
        let nextTarget = nextPageTarget(chapterIndex: chapterIndex, subPageIndex: subPageIndex)
        if let nextTarget,
          let newNextVC = makePageViewController(
            chapterIndex: nextTarget.chapterIndex,
            subPageIndex: nextTarget.subPageIndex
          )
        {
          nextController = newNextVC
          addChildController(newNextVC, to: container)
          newNextVC.view.frame = container.view.bounds
          newNextVC.view.layer.zPosition = 0
          newNextVC.view.isHidden = true
          warmAdjacentController(newNextVC)
        }

        transitionDirection = nil
        dragOffset = 0
        isAnimating = false

        Task { @MainActor in
          parent.viewModel.currentChapterIndex = chapterIndex
          parent.viewModel.currentPageIndex = subPageIndex
          parent.viewModel.targetChapterIndex = nil
          parent.viewModel.targetPageIndex = nil
          parent.viewModel.pageDidChange()
        }
      }

      private func completeBackwardTransition() {
        guard let container = containerViewController else { return }
        guard let prevVC = previousController else {
          resetDragState()
          return
        }

        let oldFront = frontController
        let oldNext = nextController

        // Rotate deck
        frontController = prevVC
        nextController = oldFront
        previousController = nil

        // Layout front
        prevVC.view.frame = container.view.bounds
        prevVC.view.layer.zPosition = 1
        prevVC.view.isHidden = false
        updateShadow(for: prevVC.view, isElevated: true, offset: 0)

        // Hide others
        oldFront?.view.isHidden = true
        oldFront?.view.layer.zPosition = 0
        oldNext?.view.isHidden = true

        // Remove old next from hierarchy
        if let oldNext, oldNext !== prevVC, oldNext !== oldFront {
          removeChildController(oldNext, from: container)
        }

        let chapterIndex = prevVC.chapterIndex
        let subPageIndex = prevVC.currentSubPageIndex
        currentChapterIndex = chapterIndex
        currentPageIndex = subPageIndex

        // Preload previous
        let prevTarget = previousPageTarget(chapterIndex: chapterIndex, subPageIndex: subPageIndex)
        if let prevTarget,
          let newPrevVC = makePageViewController(
            chapterIndex: prevTarget.chapterIndex,
            subPageIndex: prevTarget.subPageIndex,
            preferLastPageOnReady: prevTarget.preferLastPage
          )
        {
          previousController = newPrevVC
          addChildController(newPrevVC, to: container)
          newPrevVC.view.frame = container.view.bounds
          newPrevVC.view.layer.zPosition = 0
          newPrevVC.view.isHidden = true
          warmAdjacentController(newPrevVC)
        }

        transitionDirection = nil
        dragOffset = 0
        isAnimating = false

        Task { @MainActor in
          parent.viewModel.currentChapterIndex = chapterIndex
          parent.viewModel.currentPageIndex = subPageIndex
          parent.viewModel.targetChapterIndex = nil
          parent.viewModel.targetPageIndex = nil
          parent.viewModel.pageDidChange()
        }
      }

      func animateTransition(
        to targetVC: EpubPageViewController,
        chapterIndex: Int,
        subPageIndex: Int,
        forward: Bool
      ) {
        guard let container = containerViewController else { return }

        isAnimating = true
        let viewWidth = container.view.bounds.width

        addChildController(targetVC, to: container)
        targetVC.view.frame = container.view.bounds
        targetVC.loadViewIfNeeded()
        targetVC.forceEnsureContentLoaded()

        if forward {
          // Target goes behind, front slides away
          targetVC.view.layer.zPosition = 0
          targetVC.view.isHidden = false
          frontController?.view.layer.zPosition = 1

          UIView.animate(
            withDuration: Metrics.animationDuration,
            delay: 0,
            options: [.curveEaseOut]
          ) {
            self.frontController?.view.frame =
              container.view.bounds.offsetBy(dx: -viewWidth, dy: 0)
            self.updateShadow(for: self.frontController?.view, isElevated: true, offset: -viewWidth)
          } completion: { _ in
            self.finalizeJump(
              to: targetVC,
              chapterIndex: chapterIndex,
              subPageIndex: subPageIndex
            )
          }
        } else {
          // Target slides in from left
          targetVC.view.layer.zPosition = 1
          targetVC.view.frame = container.view.bounds.offsetBy(dx: -viewWidth, dy: 0)
          targetVC.view.isHidden = false
          frontController?.view.layer.zPosition = 0

          UIView.animate(
            withDuration: Metrics.animationDuration,
            delay: 0,
            options: [.curveEaseOut]
          ) {
            targetVC.view.frame = container.view.bounds
            self.updateShadow(for: targetVC.view, isElevated: true, offset: 0)
          } completion: { _ in
            self.finalizeJump(
              to: targetVC,
              chapterIndex: chapterIndex,
              subPageIndex: subPageIndex
            )
          }
        }
      }

      private func finalizeJump(
        to targetVC: EpubPageViewController,
        chapterIndex: Int,
        subPageIndex: Int
      ) {
        rebuildDeck(around: targetVC, chapterIndex: chapterIndex, subPageIndex: subPageIndex)
        currentChapterIndex = chapterIndex
        currentPageIndex = subPageIndex
        isAnimating = false

        Task { @MainActor in
          parent.viewModel.currentChapterIndex = chapterIndex
          parent.viewModel.currentPageIndex = subPageIndex
          parent.viewModel.targetChapterIndex = nil
          parent.viewModel.targetPageIndex = nil
          parent.viewModel.pageDidChange()
        }
      }

      private func cancelDragWithAnimation(viewWidth: CGFloat) {
        isAnimating = true

        if let direction = transitionDirection {
          if direction == 1 {
            UIView.animate(
              withDuration: Metrics.animationDuration,
              delay: 0,
              options: [.curveEaseOut]
            ) {
              self.frontController?.view.frame = self.containerViewController?.view.bounds ?? .zero
              self.updateShadow(for: self.frontController?.view, isElevated: true, offset: 0)
            } completion: { _ in
              self.resetDragState()
            }
          } else {
            UIView.animate(
              withDuration: Metrics.animationDuration,
              delay: 0,
              options: [.curveEaseOut]
            ) {
              self.previousController?.view.frame =
                self.containerViewController?.view.bounds.offsetBy(dx: -viewWidth, dy: 0) ?? .zero
              self.updateShadow(
                for: self.previousController?.view, isElevated: true, offset: -viewWidth)
            } completion: { _ in
              self.resetDragState()
            }
          }
        } else {
          UIView.animate(
            withDuration: Metrics.animationDuration,
            delay: 0,
            options: [.curveEaseOut]
          ) {
            self.frontController?.view.frame = self.containerViewController?.view.bounds ?? .zero
            self.updateShadow(for: self.frontController?.view, isElevated: true, offset: 0)
          } completion: { _ in
            self.resetDragState()
          }
        }
      }

      private func resetDragState() {
        guard let container = containerViewController else { return }

        frontController?.view.frame = container.view.bounds
        frontController?.view.layer.zPosition = 1
        frontController?.view.isHidden = false
        updateShadow(for: frontController?.view, isElevated: true, offset: 0)

        nextController?.view.isHidden = true
        nextController?.view.layer.zPosition = 0
        previousController?.view.isHidden = true
        previousController?.view.layer.zPosition = 0

        transitionDirection = nil
        dragOffset = 0
        isAnimating = false
      }

      // MARK: - Tap Handling

      @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard !isAnimating else { return }
        let holdDuration = Date().timeIntervalSince(lastTouchStartTime)
        guard !isLongPressing && holdDuration < 0.3 else { return }
        if Date().timeIntervalSince(lastLongPressEndTime) < 0.5 { return }

        let location = recognizer.location(in: recognizer.view)
        let size = recognizer.view?.bounds.size ?? .zero
        guard size.width > 0, size.height > 0 else { return }

        let normalizedX = location.x / size.width
        let normalizedY = location.y / size.height

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: AppConfig.tapZoneMode,
          readingDirection: tapReadingDirection(),
          zoneThreshold: AppConfig.tapZoneSize.value
        )

        switch action {
        case .previous:
          parent.viewModel.goToPreviousPage()
        case .next:
          if isAtLastPage() {
            parent.onEndReached()
          } else {
            parent.viewModel.goToNextPage()
          }
        case .toggleControls:
          parent.onCenterTap()
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

      private func tapReadingDirection() -> ReadingDirection {
        switch parent.viewModel.publicationReadingProgression {
        case .rtl:
          return .rtl
        case .ttb, .btt:
          return .vertical
        case .ltr, .auto, .none:
          return .ltr
        }
      }

      private func isAtLastPage() -> Bool {
        guard let frontVC = frontController else { return false }
        let lastChapterIndex = parent.viewModel.chapterCount - 1
        guard frontVC.chapterIndex == lastChapterIndex else { return false }
        let storedCount = parent.viewModel.chapterPageCount(at: lastChapterIndex) ?? 1
        let pageCount = max(storedCount, frontVC.totalPagesInChapter)
        return frontVC.currentSubPageIndex >= pageCount - 1
      }

      // MARK: - UIGestureRecognizerDelegate

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapRecognizer || gestureRecognizer === longPressRecognizer {
          return true
        }

        guard gestureRecognizer === panRecognizer else { return true }
        guard !isAnimating else { return false }

        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: pan.view)
        return abs(velocity.x) > abs(velocity.y) + 12
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        true
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
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        let typeName = String(describing: type(of: otherGestureRecognizer))
        return typeName.contains("Parallax")
          || typeName.contains("ZoomTransition")
          || typeName.contains("ScreenEdgePan")
          || typeName.contains("FullPageSwipe")
          || typeName == "_UIContentSwipeDismissGestureRecognizer"
      }
    }
  }

  @MainActor
  final class CoverEpubContainerViewController: UIViewController {
    weak var coordinator: WebPubPagedCoverView.Coordinator?

    override func viewDidLoad() {
      super.viewDidLoad()
      view.clipsToBounds = true
      coordinator?.setupGestures(on: view)
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      guard let coordinator, !coordinator.isAnimating else { return }
      guard let frontVC = coordinator.frontController else { return }
      coordinator.rebuildDeck(
        around: frontVC,
        chapterIndex: coordinator.currentChapterIndex,
        subPageIndex: coordinator.currentPageIndex
      )
    }
  }
#endif
