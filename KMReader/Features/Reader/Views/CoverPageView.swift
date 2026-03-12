//
// CoverPageView.swift
//
//

import SwiftUI

struct CoverPageView: View {
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
    static let slotCount = 3
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

  @State private var slotItems: [ReaderViewItem?] = Array(repeating: nil, count: TransitionMetrics.slotCount)
  @State private var frontSlotIndex: Int = 0
  @State private var middleSlotIndex: Int = 1
  @State private var backSlotIndex: Int = 2
  @State private var transitionDirection: Int?
  @State private var dragOffset: CGFloat = 0
  @State private var viewportSize: CGSize = .zero
  @State private var isAnimatingTransition = false
  @State private var transitionToken: Int = 0
  @State private var postTransitionTask: Task<Void, Never>?

  private var shouldDisableScrollInteraction: Bool {
    viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil
  }

  private var isCurrentItemValid: Bool {
    guard let currentItem else { return false }
    return viewModel.viewItemIndex(for: currentItem) != nil
  }

  private var primaryExtent: CGFloat {
    max(mode.isVertical ? viewportSize.height : viewportSize.width, 1)
  }

  private var transitionDuration: Double {
    max(tapPageTransitionDuration, 0)
  }

  private var currentItem: ReaderViewItem? {
    slotItems[frontSlotIndex]
  }

  private var nextItem: ReaderViewItem? {
    slotItems[middleSlotIndex]
  }

  private var previousItem: ReaderViewItem? {
    slotItems[backSlotIndex]
  }

  private var pendingTargetItem: ReaderViewItem? {
    guard let transitionDirection else { return nil }
    return transitionDirection == 1 ? nextItem : previousItem
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        renderConfig.readerBackground.color

        ForEach(0..<slotItems.count, id: \.self) { slotIndex in
          slotLayer(for: slotIndex)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
      .contentShape(Rectangle())
      #if os(iOS) || os(tvOS)
        .background(
          CoverPanGestureBridge(
            isEnabled: !shouldDisableScrollInteraction && !isAnimatingTransition,
            mode: mode,
            onPanChanged: { translation in
              handlePanChanged(translation: translation)
            },
            onPanEnded: { translation, velocity in
              handlePanEnded(translation: translation, velocity: velocity)
            },
            onPanCancelled: {
              resetDragStateImmediately()
            }
          )
        )
      #else
        .gesture(coverDragGesture)
      #endif
      .onAppear {
        viewportSize = geometry.size
        syncCurrentItemFromViewModel(force: true)
      }
      .onDisappear {
        postTransitionTask?.cancel()
        postTransitionTask = nil
      }
      .onChange(of: geometry.size) { _, newSize in
        viewportSize = newSize
      }
      .onChange(of: viewModel.viewItems) { _, _ in
        guard !isAnimatingTransition else { return }
        syncCurrentItemFromViewModel(force: true)
      }
      .onChange(of: viewModel.currentViewItem()) { _, newItem in
        guard !isAnimatingTransition else { return }
        guard transitionDirection == nil else { return }
        let resolved = viewModel.resolvedViewItem(for: newItem) ?? newItem ?? viewModel.viewItems.first
        guard currentItem != resolved || !isCurrentItemValid else { return }
        guard let resolved else {
          resetDeck()
          return
        }
        rebuildDeck(around: resolved)
        applyCurrentItem(resolved)
      }
      .onChange(of: viewModel.navigationTarget) { _, newTarget in
        guard let newTarget else { return }
        handleNavigationTarget(newTarget)
      }
    }
  }

  @ViewBuilder
  private func pageView(for item: ReaderViewItem, isActive: Bool = false) -> some View {
    Group {
      if case .end(let id) = item {
        NativeEndPageHostView(
          previousBook: viewModel.currentBook(forSegmentBookId: id.bookId),
          nextBook: viewModel.nextBook(forSegmentBookId: id.bookId),
          readListContext: readListContext,
          readingDirection: readingDirection,
          renderConfig: renderConfig,
          onDismiss: onDismiss,
        )
      } else {
        ReaderViewItemImageView(
          viewModel: viewModel,
          item: item,
          isPlaybackActive: isActive,
          screenSize: viewportSize,
          renderConfig: renderConfig,
          readingDirection: readingDirection,
          splitWidePageMode: splitWidePageMode
        )
      }
    }
    .frame(width: viewportSize.width, height: viewportSize.height)
    .background(renderConfig.readerBackground.color)
  }

  @ViewBuilder
  private func slotLayer(for slotIndex: Int) -> some View {
    if let item = slotItems[slotIndex] {
      let renderState = slotRenderState(for: slotIndex)
      let offset = renderState.isMoving ? dragOffset : 0
      let shadow = pageShadow(for: offset, isElevated: renderState.isElevated)

      pageView(for: item, isActive: renderState.isActive)
        .shadow(
          color: .black.opacity(shadow.opacity),
          radius: shadow.radius,
          x: shadow.x,
          y: shadow.y
        )
        .offset(
          x: mode.isVertical ? 0 : offset,
          y: mode.isVertical ? offset : 0
        )
        .opacity(renderState.isVisible ? 1 : 0)
        .allowsHitTesting(renderState.isVisible)
        .zIndex(renderState.zIndex)
    } else {
      EmptyView()
    }
  }

  private func slotRenderState(for slotIndex: Int) -> SlotRenderState {
    if let transitionDirection {
      if transitionDirection == 1 {
        if slotIndex == frontSlotIndex {
          return SlotRenderState(isVisible: true, isMoving: true, isElevated: true, isActive: true, zIndex: 1)
        }
        if slotIndex == middleSlotIndex {
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

      if slotIndex == backSlotIndex {
        return SlotRenderState(isVisible: true, isMoving: true, isElevated: true, isActive: false, zIndex: 1)
      }
      if slotIndex == frontSlotIndex {
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

    if slotIndex == frontSlotIndex {
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

    if mode.isVertical {
      let y: CGFloat =
        isMoving
        ? (offset < 0 ? TransitionMetrics.movingShadowOffset : -TransitionMetrics.movingShadowOffset)
        : TransitionMetrics.idleShadowOffset
      return (opacity, radius, 0, y)
    }

    let x: CGFloat =
      isMoving ? (offset < 0 ? TransitionMetrics.movingShadowOffset : -TransitionMetrics.movingShadowOffset) : 0
    return (opacity, radius, x, TransitionMetrics.idleShadowOffset)
  }

  #if !os(iOS) && !os(tvOS)
    private var coverDragGesture: some Gesture {
      DragGesture(minimumDistance: TransitionMetrics.minimumDragDistance)
        .onChanged { value in
          handlePanChanged(translation: value.translation)
        }
        .onEnded { value in
          handlePanEnded(
            translation: value.translation,
            velocity: estimatedVelocity(from: value)
          )
        }
    }

    private func estimatedVelocity(from value: DragGesture.Value) -> CGSize {
      let timeStep: CGFloat = 0.1
      return CGSize(
        width: (value.predictedEndTranslation.width - value.translation.width) / timeStep,
        height: (value.predictedEndTranslation.height - value.translation.height) / timeStep
      )
    }
  #endif

  private func handlePanChanged(translation: CGSize) {
    guard !shouldDisableScrollInteraction else { return }
    guard !isAnimatingTransition else { return }
    guard let currentItem else { return }
    guard isPrimaryDirectionalDrag(translation) else { return }

    let primary = primaryTranslation(from: translation)
    guard abs(primary) > TransitionMetrics.minimumDragDistance else { return }

    let directionOffset = adjacentOffset(for: primary)
    guard let targetItem = viewModel.adjacentViewItem(from: currentItem, offset: directionOffset) else {
      dragOffset = primary * TransitionMetrics.overscrollResistance
      transitionDirection = nil
      return
    }

    transitionDirection = directionOffset
    prepareTransitionTarget(targetItem, direction: directionOffset)
    if directionOffset == 1 {
      dragOffset = primary
    } else {
      dragOffset = backwardInteractiveOffset(for: primary)
    }
  }

  private func handlePanEnded(translation: CGSize, velocity: CGSize) {
    guard !shouldDisableScrollInteraction else {
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

  private func primaryTranslation(from size: CGSize) -> CGFloat {
    mode.isVertical ? size.height : size.width
  }

  private func secondaryTranslation(from size: CGSize) -> CGFloat {
    mode.isVertical ? size.width : size.height
  }

  private func isPrimaryDirectionalDrag(_ size: CGSize) -> Bool {
    abs(primaryTranslation(from: size))
      > abs(secondaryTranslation(from: size)) + TransitionMetrics.directionalDragBias
  }

  private func primaryVelocity(from size: CGSize) -> CGFloat {
    mode.isVertical ? size.height : size.width
  }

  private func adjacentOffset(for translation: CGFloat) -> Int {
    if mode.isVertical {
      return translation < 0 ? 1 : -1
    }
    if mode.isRTL {
      return translation > 0 ? 1 : -1
    }
    return translation < 0 ? 1 : -1
  }

  private func transitionDirectionSign(from currentIndex: Int, to targetIndex: Int) -> CGFloat {
    let isForward = targetIndex > currentIndex
    if mode.isVertical {
      return isForward ? -1 : 1
    }
    if mode.isRTL {
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

  private func syncCurrentItemFromViewModel(force: Bool = false) {
    if !force && isCurrentItemValid {
      return
    }
    let resolved = viewModel.currentViewItem() ?? viewModel.viewItems.first
    if let resolved, let currentItem, resolved == currentItem {
      updateAdjacentSlots(around: resolved)
      transitionDirection = nil
      dragOffset = 0
      if force {
        applyCurrentItem(resolved)
      }
      return
    }
    guard let resolved else {
      resetDeck()
      postTransitionTask?.cancel()
      postTransitionTask = nil
      return
    }
    rebuildDeck(around: resolved)
    applyCurrentItem(resolved)
  }

  private func resolveNavigationTarget(_ target: ReaderViewItem) -> ReaderViewItem? {
    if let exactIndex = viewModel.viewItemIndex(for: target) {
      return viewModel.viewItem(at: exactIndex)
    }
    return viewModel.viewItem(for: target.pageID)
  }

  private func handleNavigationTarget(_ target: ReaderViewItem) {
    guard let targetItem = resolveNavigationTarget(target) else {
      viewModel.clearNavigationTarget()
      return
    }

    guard let currentItem else {
      rebuildDeck(around: targetItem)
      applyCurrentItem(targetItem)
      viewModel.clearNavigationTarget()
      return
    }

    guard let currentIndex = viewModel.viewItemIndex(for: currentItem),
      let targetIndex = viewModel.viewItemIndex(for: targetItem)
    else {
      viewModel.clearNavigationTarget()
      return
    }

    guard targetIndex != currentIndex else {
      viewModel.clearNavigationTarget()
      return
    }

    if abs(targetIndex - currentIndex) == 1 {
      dragOffset = 0
      commitTransition(to: targetItem)
    } else {
      rebuildDeck(around: targetItem)
      applyCurrentItem(targetItem)
    }

    viewModel.clearNavigationTarget()
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
      let currentIndex = viewModel.viewItemIndex(for: currentItem),
      let targetIndex = viewModel.viewItemIndex(for: targetItem)
    else {
      completeTransition(to: targetItem)
      return
    }

    let direction = targetIndex > currentIndex ? 1 : -1
    transitionDirection = direction
    prepareTransitionTarget(targetItem, direction: direction)

    let directionSign = transitionDirectionSign(from: currentIndex, to: targetIndex)
    let endOffset = directionSign * primaryExtent

    isAnimatingTransition = true
    transitionToken += 1
    let token = transitionToken

    if targetIndex > currentIndex {
      animateDragOffset(to: endOffset, token: token) {
        completeTransition(to: targetItem)
      }
    } else {
      if abs(dragOffset) < TransitionMetrics.cancelThreshold {
        dragOffset = backwardStartOffset(for: directionSign)
      }
      animateDragOffset(to: 0, token: token) {
        completeTransition(to: targetItem)
      }
    }
  }

  private func completeTransition(to targetItem: ReaderViewItem) {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      rotateDeckAfterCommit(to: targetItem)
      transitionDirection = nil
      dragOffset = 0
      isAnimatingTransition = false
    }
    applyCurrentItem(targetItem)
  }

  private func cancelDragWithAnimation() {
    transitionToken += 1
    let token = transitionToken
    let cancelTargetOffset: CGFloat = {
      guard transitionDirection == -1,
        let currentItem,
        let pendingTargetItem,
        let currentIndex = viewModel.viewItemIndex(for: currentItem),
        let targetIndex = viewModel.viewItemIndex(for: pendingTargetItem)
      else {
        return 0
      }
      let directionSign = transitionDirectionSign(from: currentIndex, to: targetIndex)
      return backwardStartOffset(for: directionSign)
    }()

    isAnimatingTransition = true
    animateDragOffset(to: cancelTargetOffset, token: token) {
      resetDragStateImmediately()
    }
  }

  private func resetDragStateImmediately() {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      transitionDirection = nil
      dragOffset = 0
      isAnimatingTransition = false
    }
  }

  private func animateDragOffset(
    to targetOffset: CGFloat,
    token: Int,
    completion: @escaping () -> Void
  ) {
    if transitionDuration <= 0 {
      dragOffset = targetOffset
      guard token == transitionToken else { return }
      completion()
      return
    }

    withAnimation(.easeOut(duration: transitionDuration), completionCriteria: .removed) {
      dragOffset = targetOffset
    } completion: {
      guard token == transitionToken else { return }
      completion()
    }
  }

  private func resetDeck() {
    slotItems = Array(repeating: nil, count: TransitionMetrics.slotCount)
    frontSlotIndex = 0
    middleSlotIndex = 1
    backSlotIndex = 2
    transitionDirection = nil
    dragOffset = 0
  }

  private func rebuildDeck(around item: ReaderViewItem) {
    slotItems[frontSlotIndex] = item
    updateAdjacentSlots(around: item)
    transitionDirection = nil
    dragOffset = 0
  }

  private func updateAdjacentSlots(around item: ReaderViewItem) {
    slotItems[middleSlotIndex] = viewModel.adjacentViewItem(from: item, offset: 1)
    slotItems[backSlotIndex] = viewModel.adjacentViewItem(from: item, offset: -1)
  }

  private func prepareTransitionTarget(_ targetItem: ReaderViewItem, direction: Int) {
    if direction == 1 {
      if slotItems[middleSlotIndex] != targetItem {
        if slotItems[backSlotIndex] == targetItem {
          swap(&middleSlotIndex, &backSlotIndex)
        } else {
          slotItems[middleSlotIndex] = targetItem
        }
      }
    } else {
      if slotItems[backSlotIndex] != targetItem {
        if slotItems[middleSlotIndex] == targetItem {
          swap(&middleSlotIndex, &backSlotIndex)
        } else {
          slotItems[backSlotIndex] = targetItem
        }
      }
    }
  }

  private func rotateDeckAfterCommit(to targetItem: ReaderViewItem) {
    guard let direction = transitionDirection else {
      rebuildDeck(around: targetItem)
      return
    }

    let oldFront = frontSlotIndex
    let oldMiddle = middleSlotIndex
    let oldBack = backSlotIndex

    if direction == 1 {
      frontSlotIndex = oldMiddle
      middleSlotIndex = oldBack
      backSlotIndex = oldFront
    } else {
      frontSlotIndex = oldBack
      middleSlotIndex = oldFront
      backSlotIndex = oldMiddle
    }

    slotItems[frontSlotIndex] = targetItem
    updateAdjacentSlots(around: targetItem)
  }

  private func applyCurrentItem(_ item: ReaderViewItem) {
    postTransitionTask?.cancel()
    let token = transitionToken

    postTransitionTask = Task(priority: .utility) {
      guard !Task.isCancelled else { return }

      let shouldContinue = await MainActor.run { () -> Bool in
        guard token == transitionToken else { return false }
        guard currentItem == item else { return false }
        viewModel.updateCurrentPosition(viewItem: item)
        return true
      }
      guard shouldContinue else { return }

      await preloadPresentationWindow(around: item)
      await viewModel.preloadPages()
    }
  }

  private func preloadPresentationWindow(around item: ReaderViewItem) async {
    let candidateItems = [
      item,
      viewModel.adjacentViewItem(from: item, offset: 1),
      viewModel.adjacentViewItem(from: item, offset: -1),
    ].compactMap { $0 }

    var pageIDs: [ReaderPageID] = []
    var seenPageIDs: Set<ReaderPageID> = []
    for candidateItem in candidateItems {
      for pageID in candidateItem.pageIDs where seenPageIDs.insert(pageID).inserted {
        pageIDs.append(pageID)
      }
    }

    guard !pageIDs.isEmpty else { return }

    viewModel.prioritizeVisiblePageLoads(for: item.pageIDs)

    for pageID in pageIDs {
      guard !Task.isCancelled else { return }
      _ = await viewModel.preloadImage(for: pageID)
    }
  }

}
