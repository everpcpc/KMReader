//
// CurlDualPageView.swift
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct CurlDualPageView: UIViewControllerRepresentable {
    @Bindable var viewModel: ReaderViewModel
    let mode: PageViewMode
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void
    let onPlayAnimatedPage: ((ReaderPageID) -> Void)?

    private enum SpreadSlot: Int {
      case first = 0
      case second = 1
    }

    private enum SlotContent {
      case page(pageID: ReaderPageID, splitMode: PageSplitMode)
      case end(segmentBookId: String)
      case placeholder
    }

    private let slotViewIdentifier = "curlDualSlot"

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
      let options: [UIPageViewController.OptionsKey: Any] = [
        .spineLocation: NSNumber(value: UIPageViewController.SpineLocation.mid.rawValue)
      ]
      let pageVC = UIPageViewController(
        transitionStyle: .pageCurl,
        navigationOrientation: .horizontal,
        options: options
      )
      context.coordinator.pageViewController = pageVC
      pageVC.dataSource = context.coordinator
      pageVC.delegate = context.coordinator

      for recognizer in pageVC.gestureRecognizers {
        recognizer.delegate = context.coordinator
        if recognizer is UITapGestureRecognizer {
          recognizer.isEnabled = false
        }
      }

      PageCurlControllerPlanner.configure(
        pageViewController: pageVC,
        semanticContentAttribute: mode.isRTL ? .forceRightToLeft : .forceLeftToRight
      )

      let initialSpreadIndex = viewModel.currentViewItem().flatMap { viewModel.viewItemIndex(for: $0) } ?? 0
      context.coordinator.currentItem = viewModel.viewItem(at: initialSpreadIndex)
      context.coordinator.updateViewItemsSnapshot(viewModel.viewItems)
      Task { @MainActor in
        viewModel.updateCurrentPosition(viewItem: viewModel.viewItem(at: initialSpreadIndex))
      }

      if let initialPair = context.coordinator.pageControllerPair(for: initialSpreadIndex) {
        PageCurlControllerPlanner.safeSetViewControllers(
          initialPair,
          on: pageVC,
          direction: .forward,
          animated: false
        )
      }

      return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
      context.coordinator.parent = self
      context.coordinator.pageViewController = pageVC
      defer { context.coordinator.hasCompletedInitialUpdate = true }

      PageCurlControllerPlanner.configure(
        pageViewController: pageVC,
        semanticContentAttribute: mode.isRTL ? .forceRightToLeft : .forceLeftToRight
      )

      context.coordinator.syncCurrentItemWithVisibleController()
      let didViewItemsChange = context.coordinator.updateViewItemsSnapshot(viewModel.viewItems)
      context.coordinator.refreshVisibleControllerConfiguration()

      let targetSpreadIndex: Int? = {
        if let explicitTarget = viewModel.navigationTarget.flatMap({ viewModel.resolvedViewItem(for: $0) }) {
          return viewModel.viewItemIndex(for: explicitTarget)
        }
        if didViewItemsChange, let currentItem = viewModel.currentViewItem() {
          return viewModel.viewItemIndex(for: currentItem)
        }
        return nil
      }()

      guard let targetSpreadIndex else { return }
      let currentSpreadIndex = context.coordinator.currentResolvedSpreadIndex() ?? targetSpreadIndex

      let clearTargets: () -> Void = {
        _ = Task { @MainActor in
          viewModel.clearNavigationTarget()
        }
      }

      guard targetSpreadIndex != currentSpreadIndex else {
        clearTargets()
        return
      }

      guard let targetPair = context.coordinator.pageControllerPair(for: targetSpreadIndex) else {
        clearTargets()
        return
      }

      guard !context.coordinator.isTransitioning else { return }

      let direction: UIPageViewController.NavigationDirection
      if mode.isRTL {
        direction = targetSpreadIndex > currentSpreadIndex ? .reverse : .forward
      } else {
        direction = targetSpreadIndex > currentSpreadIndex ? .forward : .reverse
      }

      context.coordinator.isTransitioning = true
      let shouldAnimateTransition = context.coordinator.hasCompletedInitialUpdate
      PageCurlControllerPlanner.safeSetViewControllers(
        targetPair,
        on: pageVC,
        direction: direction,
        animated: shouldAnimateTransition
      ) { completed in
        Task { @MainActor in
          context.coordinator.isTransitioning = false
          if completed || !shouldAnimateTransition {
            if let committedPair = context.coordinator.pageControllerPair(for: targetSpreadIndex) {
              PageCurlControllerPlanner.safeSetViewControllers(
                committedPair,
                on: pageVC,
                direction: direction,
                animated: false
              )
            }
            context.coordinator.currentItem = viewModel.viewItem(at: targetSpreadIndex)
            viewModel.updateCurrentPosition(viewItem: context.coordinator.currentItem)
          }
          viewModel.clearNavigationTarget()
        }
      }
    }

    private func encodedTag(for spreadIndex: Int, slot: SpreadSlot) -> Int {
      spreadIndex * 2 + slot.rawValue + 1
    }

    private func decodedMetadata(
      for controller: UIViewController
    ) -> (spreadIndex: Int, slot: SpreadSlot)? {
      guard controller.view.accessibilityIdentifier == slotViewIdentifier else { return nil }
      let rawTag = controller.view.tag - 1
      guard rawTag >= 0 else { return nil }
      let slotRaw = rawTag % 2
      guard let slot = SpreadSlot(rawValue: slotRaw) else { return nil }
      let spreadIndex = rawTag / 2
      return (spreadIndex: spreadIndex, slot: slot)
    }

    private func applyMetadata(
      to controller: UIViewController,
      spreadIndex: Int,
      slot: SpreadSlot
    ) {
      controller.view.tag = encodedTag(for: spreadIndex, slot: slot)
      controller.view.accessibilityIdentifier = slotViewIdentifier
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
      UIGestureRecognizerDelegate
    {
      var parent: CurlDualPageView
      var currentItem: ReaderViewItem?
      weak var pageViewController: UIPageViewController?
      var isTransitioning = false
      var hasCompletedInitialUpdate = false
      private var transitionTargetItem: ReaderViewItem?
      private var lastViewItemsCount: Int = 0
      private var lastFirstViewItem: ReaderViewItem?
      private var lastLastViewItem: ReaderViewItem?

      init(_ parent: CurlDualPageView) {
        self.parent = parent
        self.currentItem = parent.viewModel.currentViewItem()
      }

      private var totalSpreads: Int {
        parent.viewModel.viewItems.count
      }

      @discardableResult
      func updateViewItemsSnapshot(_ items: [ReaderViewItem]) -> Bool {
        let firstItem = items.first
        let lastItem = items.last
        let didChange =
          items.count != lastViewItemsCount
          || firstItem != lastFirstViewItem
          || lastItem != lastLastViewItem

        lastViewItemsCount = items.count
        lastFirstViewItem = firstItem
        lastLastViewItem = lastItem
        return didChange
      }

      private func beforeSpreadIndex(from spreadIndex: Int) -> Int {
        parent.mode.isRTL ? spreadIndex + 1 : spreadIndex - 1
      }

      private func afterSpreadIndex(from spreadIndex: Int) -> Int {
        parent.mode.isRTL ? spreadIndex - 1 : spreadIndex + 1
      }

      private func isValidSpreadIndex(_ spreadIndex: Int) -> Bool {
        spreadIndex >= 0 && spreadIndex < totalSpreads
      }

      private func isFirstSpreadInSegment(_ spreadIndex: Int) -> Bool {
        guard spreadIndex >= 0 else { return false }
        if spreadIndex == 0 { return true }
        guard let previousItem = parent.viewModel.viewItem(at: spreadIndex - 1) else { return false }
        if case .end = previousItem {
          return true
        }
        return false
      }

      private func isLastSpreadInSegment(_ spreadIndex: Int) -> Bool {
        guard spreadIndex >= 0 else { return false }
        if spreadIndex >= totalSpreads - 1 { return true }
        guard let nextItem = parent.viewModel.viewItem(at: spreadIndex + 1) else { return false }
        if case .end = nextItem {
          return true
        }
        return false
      }

      private func coverSlot() -> SpreadSlot {
        parent.mode.isRTL ? .first : .second
      }

      private func oppositeSlot(of slot: SpreadSlot) -> SpreadSlot {
        slot == .first ? .second : .first
      }

      private func preferredSlotForSingleSpread(at spreadIndex: Int) -> SpreadSlot {
        let cover = coverSlot()
        if isFirstSpreadInSegment(spreadIndex) {
          return cover
        }
        if isLastSpreadInSegment(spreadIndex) {
          return oppositeSlot(of: cover)
        }
        return cover
      }

      private func spineAlignment(for slot: SpreadSlot) -> HorizontalAlignment {
        if parent.mode.isRTL {
          return slot == .first ? .leading : .trailing
        }
        return slot == .first ? .trailing : .leading
      }

      private func slotContent(for spreadIndex: Int, slot: SpreadSlot) -> SlotContent? {
        guard isValidSpreadIndex(spreadIndex) else { return nil }
        guard let item = parent.viewModel.viewItem(at: spreadIndex) else { return nil }

        switch item {
        case .dual(let firstID, let secondID):
          let targetPageID: ReaderPageID
          if parent.mode.isRTL {
            targetPageID = slot == .first ? secondID : firstID
          } else {
            targetPageID = slot == .first ? firstID : secondID
          }
          return .page(pageID: targetPageID, splitMode: .none)
        case .page(let id):
          guard preferredSlotForSingleSpread(at: spreadIndex) == slot else {
            return .placeholder
          }
          return .page(pageID: id, splitMode: .none)
        case .split(let id, let part):
          if part == .both {
            let firstIsLeftHalf = parent.viewModel.isLeftSplitHalf(
              part: .first,
              readingDirection: parent.readingDirection,
              splitWidePageMode: parent.splitWidePageMode
            )
            let secondIsLeftHalf = parent.viewModel.isLeftSplitHalf(
              part: .second,
              readingDirection: parent.readingDirection,
              splitWidePageMode: parent.splitWidePageMode
            )

            let slotUsesFirstLogicalPart: Bool
            if parent.mode.isRTL {
              slotUsesFirstLogicalPart = slot == .second
            } else {
              slotUsesFirstLogicalPart = slot == .first
            }

            let isLeftHalf = slotUsesFirstLogicalPart ? firstIsLeftHalf : secondIsLeftHalf
            let splitMode: PageSplitMode = isLeftHalf ? .leftHalf : .rightHalf
            return .page(pageID: id, splitMode: splitMode)
          }

          guard preferredSlotForSingleSpread(at: spreadIndex) == slot else {
            return .placeholder
          }
          let isLeftHalf = parent.viewModel.isLeftSplitHalf(
            part: part,
            readingDirection: parent.readingDirection,
            splitWidePageMode: parent.splitWidePageMode
          )
          let splitMode: PageSplitMode = isLeftHalf ? .leftHalf : .rightHalf
          return .page(pageID: id, splitMode: splitMode)
        case .end(let id):
          return .end(segmentBookId: id.bookId)
        }
      }

      private func makePlaceholderController() -> UIViewController {
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = UIColor(parent.renderConfig.readerBackground.color)
        return placeholder
      }

      private func configureImageController(
        _ controller: NativeImagePageViewController,
        pageID: ReaderPageID,
        splitMode: PageSplitMode,
        alignment: HorizontalAlignment
      ) {
        controller.configure(
          viewModel: parent.viewModel,
          pageID: pageID,
          splitMode: splitMode,
          alignment: alignment,
          readingDirection: parent.readingDirection,
          renderConfig: parent.renderConfig,
          onPlayAnimatedPage: parent.onPlayAnimatedPage
        )
      }

      private func configureEndController(
        _ controller: NativeEndPageViewController,
        segmentBookId: String,
        slot: SpreadSlot
      ) {
        let sectionDisplayMode: NativeEndPageViewController.SectionDisplayMode
        if parent.mode.isRTL {
          sectionDisplayMode = slot == .first ? .nextOnly : .previousOnly
        } else {
          sectionDisplayMode = slot == .first ? .previousOnly : .nextOnly
        }
        controller.configure(
          previousBook: parent.viewModel.currentBook(forSegmentBookId: segmentBookId),
          nextBook: parent.viewModel.nextBook(forSegmentBookId: segmentBookId),
          readListContext: parent.readListContext,
          readingDirection: parent.readingDirection,
          sectionDisplayMode: sectionDisplayMode,
          renderConfig: parent.renderConfig,
          onDismiss: parent.onDismiss
        )
      }

      private func configureController(
        _ controller: UIViewController,
        spreadIndex: Int,
        slot: SpreadSlot
      ) -> Bool {
        guard let content = slotContent(for: spreadIndex, slot: slot) else { return false }

        switch content {
        case .page(let pageID, let splitMode):
          guard let imageController = controller as? NativeImagePageViewController else { return false }
          configureImageController(
            imageController,
            pageID: pageID,
            splitMode: splitMode,
            alignment: spineAlignment(for: slot)
          )
          return true
        case .end(let segmentBookId):
          guard let endController = controller as? NativeEndPageViewController else { return false }
          configureEndController(endController, segmentBookId: segmentBookId, slot: slot)
          return true
        case .placeholder:
          controller.view.backgroundColor = UIColor(parent.renderConfig.readerBackground.color)
          return true
        }
      }

      private func pageController(for spreadIndex: Int, slot: SpreadSlot) -> UIViewController? {
        guard parent.viewModel.hasPages else { return nil }
        guard let content = slotContent(for: spreadIndex, slot: slot) else { return nil }

        let controller: UIViewController
        switch content {
        case .page(let pageID, let splitMode):
          let imageController = NativeImagePageViewController()
          configureImageController(
            imageController,
            pageID: pageID,
            splitMode: splitMode,
            alignment: spineAlignment(for: slot)
          )
          controller = imageController
        case .end(let segmentBookId):
          let endController = NativeEndPageViewController()
          configureEndController(endController, segmentBookId: segmentBookId, slot: slot)
          controller = endController
        case .placeholder:
          controller = makePlaceholderController()
        }

        parent.applyMetadata(to: controller, spreadIndex: spreadIndex, slot: slot)
        return controller
      }

      func pageControllerPair(for spreadIndex: Int) -> [UIViewController]? {
        guard let first = pageController(for: spreadIndex, slot: .first),
          let second = pageController(for: spreadIndex, slot: .second)
        else {
          return nil
        }
        return [first, second]
      }

      private func spreadIndices(
        from controllers: [UIViewController]
      ) -> [Int] {
        controllers.compactMap { parent.decodedMetadata(for: $0)?.spreadIndex }
      }

      private func resolvedSpreadIndex(for item: ReaderViewItem?) -> Int? {
        guard let item = parent.viewModel.resolvedViewItem(for: item) else { return nil }
        return parent.viewModel.viewItemIndex(for: item)
      }

      func currentResolvedSpreadIndex() -> Int? {
        resolvedSpreadIndex(for: currentItem)
      }

      private func resolvedVisibleSpreadIndex() -> Int? {
        guard let visibleControllers = pageViewController?.viewControllers else { return nil }
        let uniqueIndices = Array(Set(spreadIndices(from: visibleControllers))).sorted()
        guard !uniqueIndices.isEmpty else { return nil }
        if uniqueIndices.count == 1 {
          return uniqueIndices[0]
        }
        if let transitionTargetSpreadIndex = resolvedSpreadIndex(for: transitionTargetItem),
          uniqueIndices.contains(transitionTargetSpreadIndex)
        {
          return transitionTargetSpreadIndex
        }
        if let currentSpreadIndex = currentResolvedSpreadIndex(),
          uniqueIndices.contains(currentSpreadIndex)
        {
          return currentSpreadIndex
        }
        return uniqueIndices[0]
      }

      func syncCurrentItemWithVisibleController() {
        if let visibleSpreadIndex = resolvedVisibleSpreadIndex() {
          currentItem = parent.viewModel.viewItem(at: visibleSpreadIndex)
        }
      }

      func refreshVisibleControllerConfiguration() {
        guard let pageViewController else { return }
        guard let visibleControllers = pageViewController.viewControllers else { return }
        guard let spreadIndex = resolvedVisibleSpreadIndex() else { return }

        var needsReplacement = false
        for controller in visibleControllers {
          guard let metadata = parent.decodedMetadata(for: controller) else {
            needsReplacement = true
            break
          }
          if metadata.spreadIndex != spreadIndex {
            needsReplacement = true
            break
          }
          if !configureController(controller, spreadIndex: spreadIndex, slot: metadata.slot) {
            needsReplacement = true
            break
          }
        }

        if needsReplacement, let replacementPair = pageControllerPair(for: spreadIndex) {
          PageCurlControllerPlanner.safeSetViewControllers(
            replacementPair,
            on: pageViewController,
            direction: .forward,
            animated: false
          )
        }
      }

      // MARK: - UIPageViewControllerDataSource

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
      ) -> UIViewController? {
        guard let metadata = parent.decodedMetadata(for: viewController) else { return nil }

        switch metadata.slot {
        case .first:
          let targetSpreadIndex = beforeSpreadIndex(from: metadata.spreadIndex)
          guard isValidSpreadIndex(targetSpreadIndex) else { return nil }
          return pageController(for: targetSpreadIndex, slot: .second)
        case .second:
          guard isValidSpreadIndex(metadata.spreadIndex) else { return nil }
          return pageController(for: metadata.spreadIndex, slot: .first)
        }
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
      ) -> UIViewController? {
        guard let metadata = parent.decodedMetadata(for: viewController) else { return nil }

        switch metadata.slot {
        case .first:
          guard isValidSpreadIndex(metadata.spreadIndex) else { return nil }
          return pageController(for: metadata.spreadIndex, slot: .second)
        case .second:
          let targetSpreadIndex = afterSpreadIndex(from: metadata.spreadIndex)
          guard isValidSpreadIndex(targetSpreadIndex) else { return nil }
          return pageController(for: targetSpreadIndex, slot: .first)
        }
      }

      // MARK: - UIPageViewControllerDelegate

      func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]
      ) {
        isTransitioning = true
        let pendingIndices = Array(Set(spreadIndices(from: pendingViewControllers))).sorted()
        let currentSpreadIndex = currentResolvedSpreadIndex()
        if let explicitTarget = pendingIndices.first(where: { $0 != currentSpreadIndex }) {
          transitionTargetItem = parent.viewModel.viewItem(at: explicitTarget)
        } else {
          transitionTargetItem = pendingIndices.first.flatMap { parent.viewModel.viewItem(at: $0) }
        }
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
      ) {
        isTransitioning = false
        syncCurrentItemWithVisibleController()

        guard completed else {
          transitionTargetItem = nil
          return
        }

        guard
          let committedSpreadIndex =
            resolvedSpreadIndex(for: transitionTargetItem)
            ?? resolvedVisibleSpreadIndex()
            ?? currentResolvedSpreadIndex()
        else {
          transitionTargetItem = nil
          return
        }
        transitionTargetItem = nil
        guard isValidSpreadIndex(committedSpreadIndex) else { return }

        if let committedPair = pageControllerPair(for: committedSpreadIndex) {
          PageCurlControllerPlanner.safeSetViewControllers(
            committedPair,
            on: pageViewController,
            direction: .forward,
            animated: false
          )
        }

        currentItem = parent.viewModel.viewItem(at: committedSpreadIndex)
        let viewModel = parent.viewModel
        Task { @MainActor in
          viewModel.updateCurrentPosition(viewItem: currentItem)
        }
        Task(priority: .utility) { @MainActor in
          await viewModel.preloadPages()
        }
      }

      func pageViewController(
        _ pageViewController: UIPageViewController,
        spineLocationFor orientation: UIInterfaceOrientation
      ) -> UIPageViewController.SpineLocation {
        PageCurlControllerPlanner.configure(
          pageViewController: pageViewController,
          semanticContentAttribute: parent.mode.isRTL ? .forceRightToLeft : .forceLeftToRight
        )
        return .mid
      }

      // MARK: - UIGestureRecognizerDelegate

      private func primaryTranslation(for pan: UIPanGestureRecognizer) -> CGFloat {
        pan.translation(in: pan.view).x
      }

      private func primaryVelocity(for pan: UIPanGestureRecognizer) -> CGFloat {
        pan.velocity(in: pan.view).x
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isTransitioning else { return false }
        guard !parent.viewModel.isZoomed else { return false }
        guard parent.viewModel.liveTextActivePageIndex == nil else { return false }

        syncCurrentItemWithVisibleController()
        guard let currentSpreadIndex = currentResolvedSpreadIndex(),
          isValidSpreadIndex(currentSpreadIndex)
        else { return false }

        let beforeExists = isValidSpreadIndex(beforeSpreadIndex(from: currentSpreadIndex))
        let afterExists = isValidSpreadIndex(afterSpreadIndex(from: currentSpreadIndex))

        if let tap = gestureRecognizer as? UITapGestureRecognizer,
          let view = tap.view,
          view.bounds.width > 0,
          view.bounds.height > 0
        {
          let location = tap.location(in: view)
          let normalizedX = location.x / view.bounds.width
          let normalizedY = location.y / view.bounds.height

          let action = TapZoneHelper.action(
            normalizedX: normalizedX,
            normalizedY: normalizedY,
            tapZoneMode: parent.renderConfig.tapZoneMode,
            readingDirection: parent.readingDirection,
            zoneThreshold: parent.renderConfig.tapZoneSize.value
          )

          switch action {
          case .next, .previous, .toggleControls:
            return false
          }
        }

        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
          let primaryTranslation = primaryTranslation(for: pan)
          let primaryVelocity = primaryVelocity(for: pan)

          let directionTranslationThreshold: CGFloat = 1
          let directionVelocityThreshold: CGFloat = 60

          let directionSignal: CGFloat
          if abs(primaryTranslation) >= directionTranslationThreshold {
            directionSignal = primaryTranslation
          } else if abs(primaryVelocity) >= directionVelocityThreshold {
            directionSignal = primaryVelocity
          } else {
            directionSignal = 0
          }

          if directionSignal > 0 {
            return beforeExists
          }

          if directionSignal < 0 {
            return afterExists
          }

          return beforeExists && afterExists
        }

        return true
      }
    }
  }
#endif
