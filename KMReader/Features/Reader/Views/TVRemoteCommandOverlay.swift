#if os(tvOS)
  import SwiftUI
  import UIKit

  struct TVRemoteCommandOverlay: UIViewRepresentable {
    let isEnabled: Bool
    let onMoveCommand: (MoveCommandDirection) -> Bool
    let onSelectCommand: () -> Bool

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> RemoteCaptureView {
      let view = RemoteCaptureView()
      view.backgroundColor = .clear
      view.coordinator = context.coordinator
      context.coordinator.applyState(to: view)
      return view
    }

    func updateUIView(_ uiView: RemoteCaptureView, context: Context) {
      context.coordinator.parent = self
      context.coordinator.applyState(to: uiView)
    }

    final class Coordinator {
      var parent: TVRemoteCommandOverlay

      private let logger = AppLogger(.reader)
      private var lastEnabledState: Bool?

      init(parent: TVRemoteCommandOverlay) {
        self.parent = parent
      }

      func applyState(to view: RemoteCaptureView) {
        view.isCaptureEnabled = parent.isEnabled
        view.ensureResponderState()

        if lastEnabledState != parent.isEnabled {
          logger.debug("📺 UIKit remote capture \(parent.isEnabled ? "enabled" : "disabled")")
          lastEnabledState = parent.isEnabled
        }
      }

      @discardableResult
      func handlePress(_ pressType: UIPress.PressType) -> Bool {
        guard parent.isEnabled else { return false }

        switch pressType {
        case .leftArrow:
          return parent.onMoveCommand(.left)
        case .rightArrow:
          return parent.onMoveCommand(.right)
        case .upArrow:
          return parent.onMoveCommand(.up)
        case .downArrow:
          return parent.onMoveCommand(.down)
        case .select:
          return parent.onSelectCommand()
        default:
          return false
        }
      }
    }

    final class RemoteCaptureView: UIView {
      weak var coordinator: Coordinator?
      var isCaptureEnabled = false
      private var activeHandledPressTypes: Set<UIPress.PressType> = []
      private var responderRetryWorkItem: DispatchWorkItem?

      override var canBecomeFirstResponder: Bool {
        true
      }

      override func didMoveToWindow() {
        super.didMoveToWindow()
        ensureResponderState()
      }

      override func didMoveToSuperview() {
        super.didMoveToSuperview()
        ensureResponderState()
      }

      override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        DispatchQueue.main.async { [weak self] in
          self?.ensureResponderState()
        }
      }

      private func cancelResponderRetry() {
        responderRetryWorkItem?.cancel()
        responderRetryWorkItem = nil
      }

      private func attemptBecomeFirstResponder(attemptsLeft: Int = 8) {
        guard window != nil, isCaptureEnabled else { return }

        if !isFirstResponder {
          becomeFirstResponder()
        }

        guard !isFirstResponder, attemptsLeft > 0 else { return }

        cancelResponderRetry()
        let workItem = DispatchWorkItem { [weak self] in
          self?.attemptBecomeFirstResponder(attemptsLeft: attemptsLeft - 1)
        }
        responderRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: workItem)
      }

      func ensureResponderState() {
        guard window != nil else { return }

        if isCaptureEnabled {
          attemptBecomeFirstResponder()
        } else {
          cancelResponderRetry()
          activeHandledPressTypes.removeAll()
          if isFirstResponder {
            resignFirstResponder()
          }
        }
      }

      private func handlePressesBegan(_ presses: Set<UIPress>) -> Bool {
        guard let coordinator else { return false }

        var handledAny = false
        for press in presses {
          if coordinator.handlePress(press.type) {
            activeHandledPressTypes.insert(press.type)
            handledAny = true
          }
        }
        return handledAny
      }

      private func handlePressesEnded(_ presses: Set<UIPress>) -> Bool {
        guard let coordinator else { return false }

        var handledAny = false
        for press in presses {
          if activeHandledPressTypes.remove(press.type) != nil {
            handledAny = true
          } else if coordinator.handlePress(press.type) {
            handledAny = true
          }
        }
        return handledAny
      }

      override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handlePressesBegan(presses) {
          super.pressesBegan(presses, with: event)
        }
      }

      override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handlePressesEnded(presses) {
          super.pressesEnded(presses, with: event)
        }
      }

      override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
          activeHandledPressTypes.remove(press.type)
        }
        super.pressesCancelled(presses, with: event)
      }

    }
  }
#endif
