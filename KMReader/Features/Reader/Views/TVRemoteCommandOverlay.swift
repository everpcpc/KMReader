#if os(tvOS)
  import SwiftUI
  import UIKit

  struct TVRemoteCommandOverlay: UIViewRepresentable {
    let isEnabled: Bool
    let onMoveCommand: (MoveCommandDirection) -> Void
    let onSelectCommand: () -> Void

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
          parent.onMoveCommand(.left)
          return true
        case .rightArrow:
          parent.onMoveCommand(.right)
          return true
        case .upArrow:
          parent.onMoveCommand(.up)
          return true
        case .downArrow:
          parent.onMoveCommand(.down)
          return true
        case .select:
          parent.onSelectCommand()
          return true
        default:
          return false
        }
      }
    }

    final class RemoteCaptureView: UIView {
      weak var coordinator: Coordinator?
      var isCaptureEnabled = false
      private var activeHandledPressTypes: Set<UIPress.PressType> = []

      override var canBecomeFirstResponder: Bool {
        true
      }

      override func didMoveToWindow() {
        super.didMoveToWindow()
        ensureResponderState()
      }

      func ensureResponderState() {
        guard window != nil else { return }

        if isCaptureEnabled {
          if !isFirstResponder {
            becomeFirstResponder()
            DispatchQueue.main.async { [weak self] in
              guard let self else { return }
              if self.isCaptureEnabled, !self.isFirstResponder {
                self.becomeFirstResponder()
              }
            }
          }
        } else {
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
