//
// DivinaTapZoneGestureBridge.swift
//

#if os(iOS) || os(macOS)
  import SwiftUI

  #if os(iOS)
    import UIKit
  #elseif os(macOS)
    import AppKit
  #endif

  struct DivinaTapZoneGestureBridge: View {
    let isEnabled: Bool
    let readingDirection: ReadingDirection
    let tapZoneMode: TapZoneMode
    let tapZoneSize: TapZoneSize
    let doubleTapZoomMode: DoubleTapZoomMode
    let enableLiveText: Bool
    let onAction: (TapZoneAction) -> Void

    var body: some View {
      PlatformBridge(
        configuration: configuration,
        onAction: onAction
      )
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }

    private var configuration: Configuration {
      Configuration(
        isEnabled: isEnabled,
        readingDirection: readingDirection,
        tapZoneMode: tapZoneMode,
        zoneThreshold: tapZoneSize.value,
        tapDebounceDelay: doubleTapZoomMode.tapDebounceDelay,
        enableLiveText: enableLiveText
      )
    }

    private struct Configuration: Equatable {
      let isEnabled: Bool
      let readingDirection: ReadingDirection
      let tapZoneMode: TapZoneMode
      let zoneThreshold: Double
      let tapDebounceDelay: TimeInterval
      let enableLiveText: Bool
    }

    #if os(iOS)
      private struct PlatformBridge: UIViewControllerRepresentable {
        let configuration: Configuration
        let onAction: (TapZoneAction) -> Void

        func makeCoordinator() -> Coordinator {
          Coordinator(configuration: configuration, onAction: onAction)
        }

        func makeUIViewController(context: Context) -> BridgeViewController {
          let viewController = BridgeViewController()
          viewController.coordinator = context.coordinator
          return viewController
        }

        func updateUIViewController(_ uiViewController: BridgeViewController, context: Context) {
          context.coordinator.update(configuration: configuration, onAction: onAction)
          uiViewController.coordinator = context.coordinator
          context.coordinator.attachIfNeeded(window: uiViewController.view.window)
        }

        static func dismantleUIViewController(
          _ uiViewController: BridgeViewController,
          coordinator: Coordinator
        ) {
          coordinator.detach()
        }

        @MainActor
        final class BridgeViewController: UIViewController {
          weak var coordinator: Coordinator?

          override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            coordinator?.attachIfNeeded(window: view.window)
          }

          override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            coordinator?.attachIfNeeded(window: view.window)
          }

          override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            coordinator?.detach()
          }
        }

        @MainActor
        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
          private var configuration: Configuration
          private var onAction: (TapZoneAction) -> Void

          private weak var attachedView: UIView?
          private var singleTapRecognizer: UITapGestureRecognizer?
          private var doubleTapRecognizer: UITapGestureRecognizer?
          private var longPressRecognizer: UILongPressGestureRecognizer?

          private var singleTapWorkItem: DispatchWorkItem?
          private var lastLongPressEndTime: Date = .distantPast
          private var lastDoubleTapTime: Date = .distantPast
          private var lastSingleTapActionTime: Date = .distantPast

          init(configuration: Configuration, onAction: @escaping (TapZoneAction) -> Void) {
            self.configuration = configuration
            self.onAction = onAction
            super.init()
          }

          func update(configuration: Configuration, onAction: @escaping (TapZoneAction) -> Void) {
            self.configuration = configuration
            self.onAction = onAction
            applyRecognizerState()
          }

          func attachIfNeeded(window: UIWindow?) {
            guard let window else { return }
            if attachedView === window {
              applyRecognizerState()
              return
            }

            detach()
            installRecognizers(on: window)
            applyRecognizerState()
          }

          func detach() {
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil

            if let singleTapRecognizer {
              singleTapRecognizer.view?.removeGestureRecognizer(singleTapRecognizer)
            }
            if let doubleTapRecognizer {
              doubleTapRecognizer.view?.removeGestureRecognizer(doubleTapRecognizer)
            }
            if let longPressRecognizer {
              longPressRecognizer.view?.removeGestureRecognizer(longPressRecognizer)
            }

            singleTapRecognizer = nil
            doubleTapRecognizer = nil
            longPressRecognizer = nil
            attachedView = nil
          }

          private func installRecognizers(on view: UIView) {
            let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
            singleTap.numberOfTapsRequired = 1
            singleTap.cancelsTouchesInView = false
            singleTap.delegate = self

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            doubleTap.cancelsTouchesInView = false
            doubleTap.delegate = self

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.cancelsTouchesInView = false
            longPress.delegate = self

            view.addGestureRecognizer(singleTap)
            view.addGestureRecognizer(doubleTap)
            view.addGestureRecognizer(longPress)

            attachedView = view
            singleTapRecognizer = singleTap
            doubleTapRecognizer = doubleTap
            longPressRecognizer = longPress
          }

          private func applyRecognizerState() {
            singleTapRecognizer?.isEnabled = configuration.isEnabled
            doubleTapRecognizer?.isEnabled = configuration.isEnabled
            longPressRecognizer?.isEnabled = configuration.isEnabled
            if !configuration.isEnabled {
              singleTapWorkItem?.cancel()
              singleTapWorkItem = nil
            }
          }

          @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard configuration.isEnabled else { return }
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil
            lastDoubleTapTime = Date()
          }

          @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard configuration.isEnabled else { return }
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
              lastLongPressEndTime = Date()
            }
          }

          @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            singleTapWorkItem?.cancel()
            guard configuration.isEnabled else { return }
            guard let view = attachedView ?? gesture.view else { return }

            let now = Date()
            let fromLongPress = now.timeIntervalSince(lastLongPressEndTime)
            if fromLongPress < 0.5 { return }
            let fromDoubleTap = now.timeIntervalSince(lastDoubleTapTime)
            if fromDoubleTap < 0.35 { return }
            let fromLastAction = now.timeIntervalSince(lastSingleTapActionTime)
            if fromLastAction < 0.3 { return }

            let location = gesture.location(in: view)
            let workItem = DispatchWorkItem { [weak self, weak view] in
              guard let self, let view else { return }
              self.dispatchSingleTapAction(location: location, in: view.bounds.size)
            }

            let delay = max(configuration.tapDebounceDelay, 0)
            if delay > 0 {
              singleTapWorkItem = workItem
              DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            } else {
              workItem.perform()
            }
          }

          private func dispatchSingleTapAction(location: CGPoint, in size: CGSize) {
            guard configuration.isEnabled else { return }
            guard size.width > 0, size.height > 0 else { return }

            lastSingleTapActionTime = Date()

            let normalizedX = max(0, min(1, location.x / size.width))
            let normalizedY = max(0, min(1, location.y / size.height))
            let action = TapZoneHelper.action(
              normalizedX: normalizedX,
              normalizedY: normalizedY,
              tapZoneMode: configuration.tapZoneMode,
              readingDirection: configuration.readingDirection,
              zoneThreshold: configuration.zoneThreshold
            )
            onAction(action)
          }

          func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            configuration.isEnabled && !isInteractiveElement(touch.view)
          }

          func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
          ) -> Bool {
            true
          }

          private func isInteractiveElement(_ view: UIView?) -> Bool {
            var current = view
            while let candidate = current {
              if candidate is UIControl {
                return true
              }

              let className = NSStringFromClass(type(of: candidate))
              if className.contains("Button")
                || className.contains("Slider")
                || className.contains("Switch")
                || className.contains("TextField")
                || className.contains("TextView")
                || className.contains("Segmented")
                || className.contains("NavigationBar")
                || className.contains("Toolbar")
              {
                return true
              }

              current = candidate.superview
            }

            return false
          }
        }
      }
    #elseif os(macOS)
      private struct PlatformBridge: NSViewRepresentable {
        let configuration: Configuration
        let onAction: (TapZoneAction) -> Void

        func makeCoordinator() -> Coordinator {
          Coordinator(configuration: configuration, onAction: onAction)
        }

        func makeNSView(context: Context) -> BridgeNSView {
          let view = BridgeNSView()
          view.coordinator = context.coordinator
          return view
        }

        func updateNSView(_ nsView: BridgeNSView, context: Context) {
          context.coordinator.update(configuration: configuration, onAction: onAction)
          nsView.coordinator = context.coordinator
          context.coordinator.attachIfNeeded(window: nsView.window)
        }

        @MainActor
        static func dismantleNSView(_ nsView: BridgeNSView, coordinator: Coordinator) {
          coordinator.detach()
        }

        @MainActor
        final class BridgeNSView: NSView {
          weak var coordinator: Coordinator?

          override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attachIfNeeded(window: window)
          }

          override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
              coordinator?.detach()
            }
            super.viewWillMove(toWindow: newWindow)
          }
        }

        @MainActor
        final class Coordinator: NSObject, NSGestureRecognizerDelegate {
          private var configuration: Configuration
          private var onAction: (TapZoneAction) -> Void

          private weak var attachedView: NSView?
          private var singleClickRecognizer: NSClickGestureRecognizer?
          private var doubleClickRecognizer: NSClickGestureRecognizer?
          private var longPressRecognizer: NSPressGestureRecognizer?

          private var singleTapWorkItem: DispatchWorkItem?
          private var lastLongPressEndTime: Date = .distantPast
          private var lastDoubleTapTime: Date = .distantPast
          private var lastSingleTapActionTime: Date = .distantPast

          init(configuration: Configuration, onAction: @escaping (TapZoneAction) -> Void) {
            self.configuration = configuration
            self.onAction = onAction
            super.init()
          }

          func update(configuration: Configuration, onAction: @escaping (TapZoneAction) -> Void) {
            self.configuration = configuration
            self.onAction = onAction
            applyRecognizerState()
          }

          func attachIfNeeded(window: NSWindow?) {
            guard let contentView = window?.contentView else { return }
            if attachedView === contentView {
              applyRecognizerState()
              return
            }

            detach()
            installRecognizers(on: contentView)
            applyRecognizerState()
          }

          func detach() {
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil

            if let singleClickRecognizer {
              singleClickRecognizer.view?.removeGestureRecognizer(singleClickRecognizer)
            }
            if let doubleClickRecognizer {
              doubleClickRecognizer.view?.removeGestureRecognizer(doubleClickRecognizer)
            }
            if let longPressRecognizer {
              longPressRecognizer.view?.removeGestureRecognizer(longPressRecognizer)
            }

            singleClickRecognizer = nil
            doubleClickRecognizer = nil
            longPressRecognizer = nil
            attachedView = nil
          }

          private func installRecognizers(on view: NSView) {
            let singleClick = NSClickGestureRecognizer(target: self, action: #selector(handleSingleClick(_:)))
            singleClick.numberOfClicksRequired = 1
            singleClick.delegate = self

            let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
            doubleClick.numberOfClicksRequired = 2
            doubleClick.delegate = self

            let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.delegate = self

            view.addGestureRecognizer(singleClick)
            view.addGestureRecognizer(doubleClick)
            view.addGestureRecognizer(longPress)

            attachedView = view
            singleClickRecognizer = singleClick
            doubleClickRecognizer = doubleClick
            longPressRecognizer = longPress
          }

          private func applyRecognizerState() {
            singleClickRecognizer?.isEnabled = configuration.isEnabled
            doubleClickRecognizer?.isEnabled = configuration.isEnabled
            longPressRecognizer?.isEnabled = configuration.isEnabled
            if !configuration.isEnabled {
              singleTapWorkItem?.cancel()
              singleTapWorkItem = nil
            }
          }

          @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            guard configuration.isEnabled else { return }
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil
            lastDoubleTapTime = Date()
          }

          @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
            guard configuration.isEnabled else { return }
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
              lastLongPressEndTime = Date()
            }
          }

          @objc private func handleSingleClick(_ gesture: NSClickGestureRecognizer) {
            singleTapWorkItem?.cancel()
            guard configuration.isEnabled else { return }
            guard let view = attachedView ?? gesture.view else { return }

            let now = Date()
            let fromLongPress = now.timeIntervalSince(lastLongPressEndTime)
            if fromLongPress < 0.5 { return }
            let fromDoubleTap = now.timeIntervalSince(lastDoubleTapTime)
            if fromDoubleTap < 0.35 { return }
            let fromLastAction = now.timeIntervalSince(lastSingleTapActionTime)
            if fromLastAction < 0.3 { return }

            let location = gesture.location(in: view)
            let workItem = DispatchWorkItem { [weak self, weak view] in
              guard let self, let view else { return }
              self.dispatchSingleTapAction(location: location, in: view.bounds.size)
            }

            let delay = max(configuration.tapDebounceDelay, 0.25)
            if delay > 0 {
              singleTapWorkItem = workItem
              DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            } else {
              workItem.perform()
            }
          }

          private func dispatchSingleTapAction(location: CGPoint, in size: CGSize) {
            guard configuration.isEnabled else { return }
            guard size.width > 0, size.height > 0 else { return }

            lastSingleTapActionTime = Date()

            let normalizedX = max(0, min(1, location.x / size.width))
            let normalizedY = max(0, min(1, 1 - (location.y / size.height)))
            let action = TapZoneHelper.action(
              normalizedX: normalizedX,
              normalizedY: normalizedY,
              tapZoneMode: configuration.tapZoneMode,
              readingDirection: configuration.readingDirection,
              zoneThreshold: configuration.zoneThreshold
            )
            onAction(action)
          }

          func gestureRecognizer(
            _ gestureRecognizer: NSGestureRecognizer,
            shouldAttemptToRecognizeWith event: NSEvent
          ) -> Bool {
            guard configuration.isEnabled else { return false }
            guard let attachedView else { return false }

            let location = attachedView.convert(event.locationInWindow, from: nil)
            guard let hitView = attachedView.hitTest(location) else { return true }

            let className = hitView.className
            if isInteractiveElement(hitView) { return false }

            if configuration.enableLiveText && className.contains("VK") {
              let normalizedX = location.x / max(attachedView.bounds.width, 1)
              let threshold = configuration.zoneThreshold
              let isEdge = normalizedX < threshold || normalizedX > (1 - threshold)
              return isEdge
            }

            return true
          }

          func gestureRecognizer(
            _ gestureRecognizer: NSGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
          ) -> Bool {
            true
          }

          private func isInteractiveElement(_ view: NSView) -> Bool {
            var current: NSView? = view
            while let candidate = current {
              if candidate is NSControl || candidate is NSButton {
                return true
              }

              let className = candidate.className
              if className.contains("Button")
                || className.contains("Toggle")
                || className.contains("TextField")
                || className.contains("TextView")
                || className.contains("Slider")
                || className.contains("Popup")
                || className.contains("Menu")
              {
                return true
              }

              current = candidate.superview
            }

            return false
          }
        }
      }
    #endif
  }
#endif
