//
//  ReaderDismissGestureConfigurator.swift
//  KMReader
//

#if os(iOS)
  import SwiftUI
  import UIKit

  /// Configures fullScreenCover dismiss gestures based on reading direction.
  /// - For horizontal reading (ltr/rtl): only swipe down to dismiss
  /// - For vertical reading (vertical/webtoon): only edge swipe to dismiss
  struct ReaderDismissGestureConfigurator: UIViewControllerRepresentable {
    let readingDirection: ReadingDirection

    private var isVerticalReading: Bool {
      readingDirection == .vertical || readingDirection == .webtoon
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(isVerticalReading: isVerticalReading)
    }

    func makeUIViewController(context: Context) -> GestureConfiguratorViewController {
      let vc = GestureConfiguratorViewController()
      vc.coordinator = context.coordinator
      return vc
    }

    func updateUIViewController(
      _ uiViewController: GestureConfiguratorViewController, context: Context
    ) {
      context.coordinator.isVerticalReading = isVerticalReading
    }

    static func dismantleUIViewController(
      _ uiViewController: GestureConfiguratorViewController,
      coordinator: Coordinator
    ) {
      coordinator.restoreOriginalDelegates()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var isVerticalReading: Bool
      var configuredRecognizers: [(recognizer: UIGestureRecognizer, originalDelegate: UIGestureRecognizerDelegate?)] =
        []

      init(isVerticalReading: Bool) {
        self.isVerticalReading = isVerticalReading
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let recognizerType = String(describing: type(of: gestureRecognizer))

        switch recognizerType {
        case let type
        where type.contains("Parallax") || type.contains("ZoomTransition")
          || type.contains("FullPageSwipe") || type.contains("ScreenEdgePan"):
          // Navigation/Edge/Zoom swipe - allow only for vertical reading
          return isVerticalReading

        case "_UIContentSwipeDismissGestureRecognizer":
          // Swipe down - allow only for horizontal reading
          if isVerticalReading {
            return false
          }

          // For horizontal reading (LTR/RTL), only allow if it's primarily a vertical swipe down.
          // This prevents horizontal swipes (page turns) from triggering dismissal.
          if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: pan.view)
            // velocity.y > 0 means swiping down.
            // abs(velocity.y) > abs(velocity.x) means more vertical than horizontal.
            return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
          }
          return true

        default:
          return true
        }
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        // Don't allow dismiss gestures to work alongside other gestures (like scrolling or curling)
        // to avoid conflicting animations/actions.
        return false
      }

      func restoreOriginalDelegates() {
        for (recognizer, originalDelegate) in configuredRecognizers {
          recognizer.delegate = originalDelegate
        }
        configuredRecognizers.removeAll()
      }
    }
  }

  class GestureConfiguratorViewController: UIViewController {
    weak var coordinator: ReaderDismissGestureConfigurator.Coordinator?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      // Delay to ensure gesture recognizers are set up
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.configureGestures()
      }
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      // Restore original delegates when fullScreenCover is dismissed
      coordinator?.restoreOriginalDelegates()
    }

    private func configureGestures() {
      guard let window = view.window, let coordinator = coordinator else { return }

      func searchAndConfigure(in view: UIView) {
        if let gestureRecognizers = view.gestureRecognizers {
          for recognizer in gestureRecognizers {
            let recognizerType = String(describing: type(of: recognizer))

            let isNavigationGesture =
              recognizerType.contains("Parallax") || recognizerType.contains("ZoomTransition")
              || recognizerType.contains("FullPageSwipe")
              || recognizerType.contains("ScreenEdgePan")
              || recognizerType == "_UIContentSwipeDismissGestureRecognizer"

            guard isNavigationGesture else { continue }

            // Check if already configured
            let alreadyConfigured = coordinator.configuredRecognizers.contains {
              $0.recognizer === recognizer
            }
            if !alreadyConfigured {
              let originalDelegate = recognizer.delegate
              coordinator.configuredRecognizers.append(
                (recognizer: recognizer, originalDelegate: originalDelegate))
              recognizer.delegate = coordinator
            }
          }
        }

        for subview in view.subviews {
          searchAndConfigure(in: subview)
        }
      }

      searchAndConfigure(in: window)
    }
  }

  extension View {
    /// Configures dismiss gestures for the reader based on reading direction.
    func readerDismissGesture(readingDirection: ReadingDirection) -> some View {
      self.background(ReaderDismissGestureConfigurator(readingDirection: readingDirection))
    }
  }
#endif
