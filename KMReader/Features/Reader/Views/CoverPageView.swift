//
// CoverPageView.swift
//
//

#if os(iOS)
  import SwiftUI

  struct CoverPageView: View {
    let mode: PageViewMode
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    @Bindable var viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void

    @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.3

    @State private var currentItem: ReaderViewItem?
    @State private var pendingTargetItem: ReaderViewItem?
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

    private var nextItem: ReaderViewItem? {
      viewModel.adjacentViewItem(from: currentItem, offset: 1)
    }

    private var transitionOffset: Int? {
      guard let currentItem,
        let pendingTargetItem,
        let currentIndex = viewModel.viewItemIndex(for: currentItem),
        let targetIndex = viewModel.viewItemIndex(for: pendingTargetItem)
      else {
        return nil
      }
      let delta = targetIndex - currentIndex
      guard abs(delta) == 1 else { return nil }
      return delta > 0 ? 1 : -1
    }

    var body: some View {
      GeometryReader { geometry in
        ZStack {
          if let currentItem {
            if transitionOffset == 1, let nextItem {
              pageView(for: nextItem, isActive: true)
                .zIndex(0)
              pageView(for: currentItem, isActive: true)
                .offset(
                  x: mode.isVertical ? 0 : dragOffset,
                  y: mode.isVertical ? dragOffset : 0
                )
                .zIndex(1)
            } else if transitionOffset == -1, let pendingTargetItem {
              pageView(for: currentItem)
                .zIndex(0)
              pageView(for: pendingTargetItem, isActive: true)
                .offset(
                  x: mode.isVertical ? 0 : dragOffset,
                  y: mode.isVertical ? dragOffset : 0
                )
                .zIndex(1)
            } else {
              pageView(for: currentItem, isActive: true)
                .offset(
                  x: mode.isVertical ? 0 : dragOffset,
                  y: mode.isVertical ? dragOffset : 0
                )
                .zIndex(1)
            }
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .contentShape(Rectangle())
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
          guard pendingTargetItem == nil else { return }
          guard !isCurrentItemValid || currentItem == nil else { return }
          if let resolved = viewModel.resolvedViewItem(for: newItem) ?? newItem ?? viewModel.viewItems.first {
            currentItem = resolved
            pendingTargetItem = nil
            dragOffset = 0
          }
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
          EndPageView(
            previousBook: viewModel.currentBook(forSegmentBookId: id.bookId),
            nextBook: viewModel.nextBook(forSegmentBookId: id.bookId),
            readListContext: readListContext,
            onDismiss: onDismiss,
            readingDirection: readingDirection
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
    }

    private func handlePanChanged(translation: CGSize) {
      guard !shouldDisableScrollInteraction else { return }
      guard !isAnimatingTransition else { return }
      guard let currentItem else { return }
      guard isPrimaryDirectionalDrag(translation) else { return }

      let primary = primaryTranslation(from: translation)
      guard abs(primary) > 1 else { return }

      let directionOffset = adjacentOffset(for: primary)
      guard let targetItem = viewModel.adjacentViewItem(from: currentItem, offset: directionOffset) else {
        dragOffset = primary * 0.2
        pendingTargetItem = nil
        return
      }

      pendingTargetItem = targetItem
      if directionOffset == 1 {
        dragOffset = primary
      } else {
        dragOffset = backwardInteractiveOffset(for: primary)
      }
    }

    private func handlePanEnded(translation: CGSize, velocity: CGSize) {
      guard !isAnimatingTransition else { return }
      guard isPrimaryDirectionalDrag(translation) else {
        resetDragStateImmediately()
        return
      }

      guard pendingTargetItem != nil else {
        if abs(dragOffset) > 0.5 {
          cancelDragWithAnimation()
        } else {
          resetDragStateImmediately()
        }
        return
      }

      let primary = primaryTranslation(from: translation)
      let primaryVelocity = primaryVelocity(from: velocity)
      let shouldCommit =
        abs(primary) > primaryExtent * 0.18
        || abs(primaryVelocity) > 700

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
      abs(primaryTranslation(from: size)) > abs(secondaryTranslation(from: size)) + 4
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
      currentItem = viewModel.currentViewItem() ?? viewModel.viewItems.first
      pendingTargetItem = nil
      dragOffset = 0
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
        self.currentItem = targetItem
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
        pendingTargetItem = targetItem
        dragOffset = 0
        commitTransition(to: targetItem)
      } else {
        self.currentItem = targetItem
        pendingTargetItem = nil
        dragOffset = 0
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
        if abs(dragOffset) < 0.5 {
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
        currentItem = targetItem
        pendingTargetItem = nil
        dragOffset = 0
        isAnimatingTransition = false
      }
      applyCurrentItem(targetItem)
    }

    private func cancelDragWithAnimation() {
      transitionToken += 1
      let token = transitionToken
      let cancelTargetOffset: CGFloat = {
        guard transitionOffset == -1,
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
        pendingTargetItem = nil
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

    private func applyCurrentItem(_ item: ReaderViewItem) {
      postTransitionTask?.cancel()
      let token = transitionToken

      postTransitionTask = Task(priority: .utility) {
        guard !Task.isCancelled else { return }

        let shouldSyncPosition = await MainActor.run { () -> Bool in
          guard token == transitionToken else { return false }
          guard currentItem == item else { return false }
          viewModel.updateCurrentPosition(viewItem: item)
          return true
        }
        guard shouldSyncPosition else { return }

        let shouldPreload = await MainActor.run { () -> Bool in
          guard token == transitionToken else { return false }
          guard currentItem == item else { return false }
          preloadVisiblePages(for: item)
          return true
        }
        guard shouldPreload else { return }

        await viewModel.preloadPages()
      }
    }

    private func preloadVisiblePages(for item: ReaderViewItem) {
      let visiblePageIndices: [Int]
      switch item {
      case .page(let id):
        visiblePageIndices = [viewModel.pageIndex(for: id)].compactMap { $0 }
      case .split(let id, _):
        visiblePageIndices = [viewModel.pageIndex(for: id)].compactMap { $0 }
      case .dual(let first, let second):
        visiblePageIndices = [viewModel.pageIndex(for: first), viewModel.pageIndex(for: second)].compactMap {
          $0
        }
      case .end:
        visiblePageIndices = []
      }

      guard !visiblePageIndices.isEmpty else { return }

      Task(priority: .utility) {
        for pageIndex in visiblePageIndices {
          _ = await viewModel.preloadImageForPage(at: pageIndex)
        }
      }
    }
  }
#endif
