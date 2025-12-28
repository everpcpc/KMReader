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

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var isVerticalReading: Bool
      var configuredRecognizers:
        [(recognizer: UIGestureRecognizer, originalDelegate: UIGestureRecognizerDelegate?)] = []

      init(isVerticalReading: Bool) {
        self.isVerticalReading = isVerticalReading
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let recognizerType = String(describing: type(of: gestureRecognizer))

        switch recognizerType {
        case "_UIParallaxTransitionPanGestureRecognizer":
          // Edge swipe - allow only for vertical reading
          return isVerticalReading

        case "_UIContentSwipeDismissGestureRecognizer":
          // Swipe down - allow only for horizontal reading
          return !isVerticalReading

        default:
          return true
        }
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

            guard
              recognizerType == "_UIParallaxTransitionPanGestureRecognizer"
                || recognizerType == "_UIContentSwipeDismissGestureRecognizer"
            else { continue }

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
