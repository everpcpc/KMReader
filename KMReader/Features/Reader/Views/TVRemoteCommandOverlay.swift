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
          logger.debug("📺 TV remote capture \(parent.isEnabled ? "enabled" : "disabled")")
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
          }
        } else if isFirstResponder {
          resignFirstResponder()
        }
      }

      override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let coordinator else {
          super.pressesEnded(presses, with: event)
          return
        }

        var handledAny = false
        for press in presses {
          if coordinator.handlePress(press.type) {
            handledAny = true
          }
        }

        if !handledAny {
          super.pressesEnded(presses, with: event)
        }
      }
    }
  }
#endif
