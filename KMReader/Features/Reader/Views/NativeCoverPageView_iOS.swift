#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  struct NativeCoverPageView: UIViewRepresentable {
    private struct SlotRenderState {
      let isVisible: Bool
      let isMoving: Bool
      let isElevated: Bool
      let isActive: Bool
      let zIndex: Double

      static let hidden = SlotRenderState(
        isVisible: false,
        isMoving: false,
        isElevated: false,
        isActive: false,
        zIndex: -1
      )
    }

    private enum TransitionMetrics {
      static let minimumDragDistance: CGFloat = 1
      static let directionalDragBias: CGFloat = 4
      static let overscrollResistance: CGFloat = 0.2
      static let cancelThreshold: CGFloat = 0.5
      static let commitDistanceRatio: CGFloat = 0.18
      static let commitVelocityThreshold: CGFloat = 700
      static let movingShadowOpacity: Double = 0.12
      static let idleShadowOpacity: Double = 0.05
      static let movingShadowRadius: CGFloat = 5
      static let idleShadowRadius: CGFloat = 2
      static let movingShadowOffset: CGFloat = 3
      static let idleShadowOffset: CGFloat = 1
    }

    let mode: PageViewMode
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    @Bindable var viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void

    @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.3

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIView(context: Context) -> NativeCoverContainerView {
      let containerView = NativeCoverContainerView()
      containerView.onDidLayout = { [weak coordinator = context.coordinator] in
        coordinator?.handleContainerLayout()
      }
      context.coordinator.attach(to: containerView)
      context.coordinator.update(from: self)
      return containerView
    }

    func updateUIView(_ uiView: NativeCoverContainerView, context: Context) {
      context.coordinator.attach(to: uiView)
      context.coordinator.update(from: self)
    }

    static func dismantleUIView(_ uiView: NativeCoverContainerView, coordinator: Coordinator) {
      coordinator.teardown()
      uiView.prepareForDismantle()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate, NativePagedPagePresentationHost {
      private var parent: NativeCoverPageView
      private weak var containerView: NativeCoverContainerView?
      private let pagePresentationCoordinator = NativePagedPagePresentationCoordinator()

      private var deckState = NativeCoverDeckState()
      private var transitionDirection: Int?
      private var dragOffset: CGFloat = 0
      private var isAnimatingTransition = false
      private var transitionToken = 0
      private var lastViewportSize: CGSize = .zero
      private var postTransitionTask: Task<Void, Never>?
      private var panRecognizer: UIPanGestureRecognizer?

      init(_ parent: NativeCoverPageView) {
        self.parent = parent
        super.init()
        pagePresentationCoordinator.host = self
      }

      func attach(to containerView: NativeCoverContainerView) {
        self.containerView = containerView
        containerView.backgroundColor = UIColor(parent.renderConfig.readerBackground.color)
        attachPanRecognizerIfNeeded(to: containerView)
      }

      func update(from parent: NativeCoverPageView) {
        self.parent = parent
        pagePresentationCoordinator.update(viewModel: parent.viewModel)
        containerView?.backgroundColor = UIColor(parent.renderConfig.readerBackground.color)
        applyPanRecognizerState()

        if deckState.currentItem == nil {
          syncCurrentItemFromViewModel(force: true)
        } else if !isAnimatingTransition {
          syncCurrentItemFromViewModel()
          if let navigationTarget = parent.viewModel.navigationTarget {
            handleNavigationTarget(navigationTarget)
          } else {
            syncSlotContent()
            updateSlotLayout()
          }
        }

        pagePresentationCoordinator.flushIfPossible()
      }

      func teardown() {
        postTransitionTask?.cancel()
        postTransitionTask = nil
        if let panRecognizer {
          panRecognizer.view?.removeGestureRecognizer(panRecognizer)
        }
        panRecognizer = nil
        pagePresentationCoordinator.teardown()
        containerView = nil
      }

      func handleContainerLayout() {
        guard let containerView else { return }
        let newSize = containerView.bounds.size
        guard newSize != .zero else { return }
        let sizeChanged = newSize != lastViewportSize
        lastViewportSize = newSize
        if sizeChanged && !isAnimatingTransition {
          syncSlotContent()
        }
        updateSlotLayout()
        pagePresentationCoordinator.flushIfPossible()
      }

      func hasVisiblePagePresentationContent() -> Bool {
        guard let containerView else { return false }
        return containerView.slotViews.contains(where: { !$0.isHidden && $0.item != nil })
      }

      func applyPagePresentationInvalidation(_ invalidation: ReaderPagePresentationInvalidation) {
        guard let containerView else { return }

        switch invalidation {
        case .all:
          containerView.slotViews.forEach { slotView in
            guard !slotView.isHidden else { return }
            slotView.refreshContent()
          }
        case .pages(let pageIDs):
          containerView.slotViews.forEach { slotView in
            guard !slotView.isHidden else { return }
            guard slotView.containsAny(pageIDs: pageIDs) else { return }
            slotView.refreshContent()
          }
        }
      }

      @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let containerView else { return }
        switch recognizer.state {
        case .changed:
          handlePanChanged(translation: recognizer.translation(in: containerView))
        case .ended:
          handlePanEnded(
            translation: recognizer.translation(in: containerView),
            velocity: recognizer.velocity(in: containerView)
          )
        case .cancelled, .failed:
          resetDragStateImmediately()
        default:
          break
        }
      }

      private func attachPanRecognizerIfNeeded(to containerView: NativeCoverContainerView) {
        #if os(iOS) || os(macOS)
          if panRecognizer?.view === containerView {
            return
          }

          if let panRecognizer {
            panRecognizer.view?.removeGestureRecognizer(panRecognizer)
          }

          let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
          panRecognizer.maximumNumberOfTouches = 1
          panRecognizer.cancelsTouchesInView = false
          panRecognizer.delegate = self
          containerView.addGestureRecognizer(panRecognizer)
          self.panRecognizer = panRecognizer
          applyPanRecognizerState()
        #endif
      }

      private func applyPanRecognizerState() {
        #if os(iOS) || os(macOS)
          guard let panRecognizer else { return }
          let wasEnabled = panRecognizer.isEnabled
          let shouldEnable = !parent.viewModel.isZoomed && !isAnimatingTransition
          guard wasEnabled != shouldEnable else { return }
          let previousState = panRecognizer.state
          panRecognizer.isEnabled = shouldEnable
          if wasEnabled && !shouldEnable && (previousState == .began || previousState == .changed) {
            resetDragStateImmediately()
          }
        #endif
      }

      private var currentItem: ReaderViewItem? {
        deckState.currentItem
      }

      private var pendingTargetItem: ReaderViewItem? {
        guard let transitionDirection else { return nil }
        return transitionDirection == 1 ? deckState.nextItem : deckState.previousItem
      }

      private var transitionDuration: Double {
        max(parent.tapPageTransitionDuration, 0)
      }

      private var primaryExtent: CGFloat {
        guard let containerView else { return 1 }
        let size = containerView.bounds.size
        return max(parent.mode.isVertical ? size.height : size.width, 1)
      }

      private var isCurrentItemValid: Bool {
        guard let currentItem else { return false }
        return parent.viewModel.viewItemIndex(for: currentItem) != nil
      }

      private func syncCurrentItemFromViewModel(force: Bool = false) {
        let resolved = parent.viewModel.currentViewItem() ?? parent.viewModel.viewItems.first
        if !force,
          let resolved,
          let currentItem,
          resolved == currentItem,
          isCurrentItemValid,
          transitionDirection == nil
        {
          deckState.updateAdjacentSlots(around: resolved, viewModel: parent.viewModel)
          syncSlotContent()
          updateSlotLayout()
          return
        }

        if let resolved, let currentItem, resolved == currentItem {
          deckState.updateAdjacentSlots(around: resolved, viewModel: parent.viewModel)
          transitionDirection = nil
          dragOffset = 0
          syncSlotContent()
          updateSlotLayout()
          if force {
            applyCurrentItem(resolved)
          }
          return
        }

        guard let resolved else {
          deckState.reset()
          transitionDirection = nil
          dragOffset = 0
          syncSlotContent()
          updateSlotLayout()
          postTransitionTask?.cancel()
          postTransitionTask = nil
          return
        }

        deckState.rebuild(around: resolved, viewModel: parent.viewModel)
        transitionDirection = nil
        dragOffset = 0
        syncSlotContent()
        updateSlotLayout()
        applyCurrentItem(resolved)
      }

      private func resolveNavigationTarget(_ target: ReaderViewItem) -> ReaderViewItem? {
        if let exactIndex = parent.viewModel.viewItemIndex(for: target) {
          return parent.viewModel.viewItem(at: exactIndex)
        }
        return parent.viewModel.viewItem(for: target.pageID)
      }

      private func handleNavigationTarget(_ target: ReaderViewItem) {
        guard let targetItem = resolveNavigationTarget(target) else {
          parent.viewModel.clearNavigationTarget()
          return
        }

        guard let currentItem else {
          deckState.rebuild(around: targetItem, viewModel: parent.viewModel)
          syncSlotContent()
          updateSlotLayout()
          applyCurrentItem(targetItem)
          parent.viewModel.clearNavigationTarget()
          return
        }

        guard let currentIndex = parent.viewModel.viewItemIndex(for: currentItem),
          let targetIndex = parent.viewModel.viewItemIndex(for: targetItem)
        else {
          parent.viewModel.clearNavigationTarget()
          return
        }

        guard targetIndex != currentIndex else {
          parent.viewModel.clearNavigationTarget()
          return
        }

        if abs(targetIndex - currentIndex) == 1 {
          dragOffset = 0
          commitTransition(to: targetItem)
        } else {
          deckState.rebuild(around: targetItem, viewModel: parent.viewModel)
          transitionDirection = nil
          dragOffset = 0
          syncSlotContent()
          updateSlotLayout()
          applyCurrentItem(targetItem)
        }

        parent.viewModel.clearNavigationTarget()
      }

      private func handlePanChanged(translation: CGPoint) {
        guard !parent.viewModel.isZoomed else { return }
        guard !isAnimatingTransition else { return }
        guard let currentItem else { return }
        guard isPrimaryDirectionalDrag(translation) else { return }

        let primary = primaryTranslation(from: translation)
        guard abs(primary) > TransitionMetrics.minimumDragDistance else { return }

        let directionOffset = adjacentOffset(for: primary)
        guard let targetItem = parent.viewModel.adjacentViewItem(from: currentItem, offset: directionOffset) else {
          dragOffset = primary * TransitionMetrics.overscrollResistance
          transitionDirection = nil
          updateSlotLayout()
          return
        }

        transitionDirection = directionOffset
        deckState.prepareTransitionTarget(targetItem, direction: directionOffset)
        syncSlotContent()
        if directionOffset == 1 {
          dragOffset = primary
        } else {
          dragOffset = backwardInteractiveOffset(for: primary)
        }
        updateSlotLayout()
      }

      private func handlePanEnded(translation: CGPoint, velocity: CGPoint) {
        guard !parent.viewModel.isZoomed else {
          resetDragStateImmediately()
          return
        }
        guard !isAnimatingTransition else { return }
        guard isPrimaryDirectionalDrag(translation) else {
          resetDragStateImmediately()
          return
        }

        guard pendingTargetItem != nil else {
          if abs(dragOffset) > TransitionMetrics.cancelThreshold {
            cancelDragWithAnimation()
          } else {
            resetDragStateImmediately()
          }
          return
        }

        let primary = primaryTranslation(from: translation)
        let primaryVelocity = primaryVelocity(from: velocity)
        let shouldCommit =
          abs(primary) > primaryExtent * TransitionMetrics.commitDistanceRatio
          || abs(primaryVelocity) > TransitionMetrics.commitVelocityThreshold

        if shouldCommit {
          commitCurrentDrag()
        } else {
          cancelDragWithAnimation()
        }
      }

      private func commitCurrentDrag() {
        guard let targetItem = pendingTargetItem else {
          cancelDragWithAnimation()
          return
        }
        commitTransition(to: targetItem)
      }

      private func commitTransition(to targetItem: ReaderViewItem) {
        guard let currentItem,
          let currentIndex = parent.viewModel.viewItemIndex(for: currentItem),
          let targetIndex = parent.viewModel.viewItemIndex(for: targetItem)
        else {
          completeTransition(to: targetItem)
          return
        }

        let direction = targetIndex > currentIndex ? 1 : -1
        transitionDirection = direction
        deckState.prepareTransitionTarget(targetItem, direction: direction)
        syncSlotContent()

        let directionSign = transitionDirectionSign(from: currentIndex, to: targetIndex)
        let endOffset = directionSign * primaryExtent

        isAnimatingTransition = true
        transitionToken += 1
        let token = transitionToken

        if targetIndex > currentIndex {
          animateDragOffset(to: endOffset, token: token) {
            self.completeTransition(to: targetItem)
          }
        } else {
          if abs(dragOffset) < TransitionMetrics.cancelThreshold {
            dragOffset = backwardStartOffset(for: directionSign)
            updateSlotLayout()
          }
          animateDragOffset(to: 0, token: token) {
            self.completeTransition(to: targetItem)
          }
        }
      }

      private func completeTransition(to targetItem: ReaderViewItem) {
        let direction = transitionDirection ?? 1
        deckState.rotateAfterCommit(
          to: targetItem,
          direction: direction,
          viewModel: parent.viewModel
        )
        transitionDirection = nil
        dragOffset = 0
        isAnimatingTransition = false
        syncSlotContent()
        updateSlotLayout()
        applyCurrentItem(targetItem)
        applyPanRecognizerState()
      }

      private func cancelDragWithAnimation() {
        transitionToken += 1
        let token = transitionToken
        let cancelTargetOffset: CGFloat = {
          guard transitionDirection == -1,
            let currentItem,
            let pendingTargetItem,
            let currentIndex = parent.viewModel.viewItemIndex(for: currentItem),
            let targetIndex = parent.viewModel.viewItemIndex(for: pendingTargetItem)
          else {
            return 0
          }
          let directionSign = transitionDirectionSign(from: currentIndex, to: targetIndex)
          return backwardStartOffset(for: directionSign)
        }()

        isAnimatingTransition = true
        animateDragOffset(to: cancelTargetOffset, token: token) {
          self.resetDragStateImmediately()
        }
      }

      private func resetDragStateImmediately() {
        transitionDirection = nil
        dragOffset = 0
        isAnimatingTransition = false
        syncSlotContent()
        updateSlotLayout()
        applyPanRecognizerState()
      }

      private func animateDragOffset(
        to targetOffset: CGFloat,
        token: Int,
        completion: @escaping () -> Void
      ) {
        guard let containerView else {
          dragOffset = targetOffset
          completion()
          return
        }

        if transitionDuration <= 0 {
          dragOffset = targetOffset
          updateSlotLayout()
          guard token == transitionToken else { return }
          completion()
          return
        }

        UIView.animate(
          withDuration: transitionDuration,
          delay: 0,
          options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
          self.dragOffset = targetOffset
          self.updateSlotLayout()
          containerView.layoutIfNeeded()
        } completion: { _ in
          guard token == self.transitionToken else { return }
          completion()
        }
      }

      private func applyCurrentItem(_ item: ReaderViewItem) {
        postTransitionTask?.cancel()
        let token = transitionToken

        postTransitionTask = Task(priority: .utility) {
          guard !Task.isCancelled else { return }

          let shouldContinue = await MainActor.run { () -> Bool in
            guard token == self.transitionToken else { return false }
            guard self.currentItem == item else { return false }
            self.parent.viewModel.updateCurrentPosition(viewItem: item)
            return true
          }
          guard shouldContinue else { return }

          await preloadPresentationWindow(around: item)
          await parent.viewModel.preloadPages()
        }
      }

      private func preloadPresentationWindow(around item: ReaderViewItem) async {
        let candidateItems = [
          item,
          parent.viewModel.adjacentViewItem(from: item, offset: 1),
          parent.viewModel.adjacentViewItem(from: item, offset: -1),
        ].compactMap { $0 }

        var pageIDs: [ReaderPageID] = []
        var seenPageIDs: Set<ReaderPageID> = []
        for candidateItem in candidateItems {
          for pageID in candidateItem.pageIDs where seenPageIDs.insert(pageID).inserted {
            pageIDs.append(pageID)
          }
        }

        guard !pageIDs.isEmpty else { return }

        parent.viewModel.prioritizeVisiblePageLoads(for: item.pageIDs)

        for pageID in pageIDs {
          guard !Task.isCancelled else { return }
          _ = await parent.viewModel.preloadImage(for: pageID)
        }
      }

      private func syncSlotContent() {
        guard let containerView else { return }
        let viewportSize = containerView.bounds.size
        for (slotIndex, slotView) in containerView.slotViews.enumerated() {
          let renderState = slotRenderState(for: slotIndex)
          slotView.configure(
            item: deckState.item(at: slotIndex),
            viewModel: parent.viewModel,
            screenSize: viewportSize,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode,
            renderConfig: parent.renderConfig,
            readListContext: parent.readListContext,
            isVisible: renderState.isVisible,
            isPlaybackActive: renderState.isActive,
            tracksGlobalZoomState: renderState.isActive,
            onDismiss: parent.onDismiss
          )
          slotView.isUserInteractionEnabled = renderState.isVisible && renderState.isActive
        }
      }

      private func updateSlotLayout() {
        guard let containerView else { return }

        for (slotIndex, slotView) in containerView.slotViews.enumerated() {
          let renderState = slotRenderState(for: slotIndex)
          let offset = renderState.isMoving ? dragOffset : 0
          let shadow = pageShadow(for: offset, isElevated: renderState.isElevated)

          slotView.frame = shiftedFrame(for: containerView.bounds, offset: offset)
          slotView.isHidden = !renderState.isVisible || slotView.item == nil
          slotView.alpha = renderState.isVisible ? 1 : 0
          slotView.layer.zPosition = CGFloat(renderState.zIndex)
          slotView.layer.masksToBounds = false
          slotView.layer.shadowColor = UIColor.black.cgColor
          slotView.layer.shadowOpacity = Float(shadow.opacity)
          slotView.layer.shadowRadius = shadow.radius
          slotView.layer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
          slotView.layer.shadowPath = UIBezierPath(rect: slotView.bounds).cgPath
          slotView.isUserInteractionEnabled = renderState.isVisible && renderState.isActive
        }
      }

      private func shiftedFrame(for bounds: CGRect, offset: CGFloat) -> CGRect {
        var frame = bounds
        if parent.mode.isVertical {
          frame.origin.y += offset
        } else {
          frame.origin.x += offset
        }
        return frame
      }

      private func slotRenderState(for slotIndex: Int) -> SlotRenderState {
        if let transitionDirection {
          if transitionDirection == 1 {
            if slotIndex == deckState.frontSlotIndex {
              return SlotRenderState(isVisible: true, isMoving: true, isElevated: true, isActive: true, zIndex: 1)
            }
            if slotIndex == deckState.middleSlotIndex {
              return SlotRenderState(
                isVisible: true,
                isMoving: false,
                isElevated: false,
                isActive: false,
                zIndex: 0
              )
            }
            return .hidden
          }

          if slotIndex == deckState.backSlotIndex {
            return SlotRenderState(isVisible: true, isMoving: true, isElevated: true, isActive: false, zIndex: 1)
          }
          if slotIndex == deckState.frontSlotIndex {
            return SlotRenderState(
              isVisible: true,
              isMoving: false,
              isElevated: false,
              isActive: true,
              zIndex: 0
            )
          }
          return .hidden
        }

        if slotIndex == deckState.frontSlotIndex {
          return SlotRenderState(isVisible: true, isMoving: false, isElevated: true, isActive: true, zIndex: 1)
        }
        return .hidden
      }

      private func pageShadow(for offset: CGFloat, isElevated: Bool) -> (
        opacity: Double, radius: CGFloat, x: CGFloat, y: CGFloat
      ) {
        guard isElevated else {
          return (0, 0, 0, 0)
        }

        let isMoving = abs(offset) > TransitionMetrics.cancelThreshold
        let opacity: Double = isMoving ? TransitionMetrics.movingShadowOpacity : TransitionMetrics.idleShadowOpacity
        let radius: CGFloat = isMoving ? TransitionMetrics.movingShadowRadius : TransitionMetrics.idleShadowRadius

        if parent.mode.isVertical {
          let y: CGFloat =
            isMoving
            ? (offset < 0 ? TransitionMetrics.movingShadowOffset : -TransitionMetrics.movingShadowOffset)
            : TransitionMetrics.idleShadowOffset
          return (opacity, radius, 0, y)
        }

        let x: CGFloat =
          isMoving
          ? (offset < 0 ? TransitionMetrics.movingShadowOffset : -TransitionMetrics.movingShadowOffset)
          : 0
        return (opacity, radius, x, TransitionMetrics.idleShadowOffset)
      }

      private func primaryTranslation(from point: CGPoint) -> CGFloat {
        parent.mode.isVertical ? point.y : point.x
      }

      private func secondaryTranslation(from point: CGPoint) -> CGFloat {
        parent.mode.isVertical ? point.x : point.y
      }

      private func primaryVelocity(from point: CGPoint) -> CGFloat {
        parent.mode.isVertical ? point.y : point.x
      }

      private func isPrimaryDirectionalDrag(_ point: CGPoint) -> Bool {
        abs(primaryTranslation(from: point))
          > abs(secondaryTranslation(from: point)) + TransitionMetrics.directionalDragBias
      }

      private func adjacentOffset(for translation: CGFloat) -> Int {
        if parent.mode.isVertical {
          return translation < 0 ? 1 : -1
        }
        if parent.mode.isRTL {
          return translation > 0 ? 1 : -1
        }
        return translation < 0 ? 1 : -1
      }

      private func transitionDirectionSign(from currentIndex: Int, to targetIndex: Int) -> CGFloat {
        let isForward = targetIndex > currentIndex
        if parent.mode.isVertical {
          return isForward ? -1 : 1
        }
        if parent.mode.isRTL {
          return isForward ? 1 : -1
        }
        return isForward ? -1 : 1
      }

      private func backwardStartOffset(for directionSign: CGFloat) -> CGFloat {
        -directionSign * primaryExtent
      }

      private func backwardInteractiveOffset(for translation: CGFloat) -> CGFloat {
        let translationSign: CGFloat = translation >= 0 ? 1 : -1
        let start = backwardStartOffset(for: translationSign)
        let raw = start + translation
        if start < 0 {
          return min(max(raw, start), 0)
        }
        return max(min(raw, start), 0)
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
        false
      }
    }
  }
#endif
