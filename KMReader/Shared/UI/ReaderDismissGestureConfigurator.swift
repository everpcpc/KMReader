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
  struct ReaderDismissGestureConfigurator: UIViewRepresentable {
    let isVerticalReading: Bool

    func makeCoordinator() -> Coordinator {
      Coordinator(isVerticalReading: isVerticalReading)
    }

    func makeUIView(context: Context) -> GestureConfiguratorView {
      let view = GestureConfiguratorView()
      view.coordinator = context.coordinator
      return view
    }

    func updateUIView(_ uiView: GestureConfiguratorView, context: Context) {
      context.coordinator.isVerticalReading = isVerticalReading
      uiView.configureGestures()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var isVerticalReading: Bool

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
    }
  }

  class GestureConfiguratorView: UIView {
    weak var coordinator: ReaderDismissGestureConfigurator.Coordinator?
    private var configuredRecognizers: Set<ObjectIdentifier> = []

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil {
        // Delay configuration to ensure gestures are available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.configureGestures()
        }
      }
    }

    func configureGestures() {
      guard let window = self.window, let coordinator = coordinator else { return }
      searchAndConfigureGestures(in: window, coordinator: coordinator)
    }

    private func searchAndConfigureGestures(
      in view: UIView, coordinator: ReaderDismissGestureConfigurator.Coordinator
    ) {
      if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
          let recognizerType = String(describing: type(of: recognizer))
          let recognizerId = ObjectIdentifier(recognizer)

          // Only configure recognize types we care about
          guard
            recognizerType == "_UIParallaxTransitionPanGestureRecognizer"
              || recognizerType == "_UIContentSwipeDismissGestureRecognizer"
          else { continue }

          // Set delegate if not already configured
          if !configuredRecognizers.contains(recognizerId) {
            recognizer.delegate = coordinator
            configuredRecognizers.insert(recognizerId)
          }
        }
      }

      for subview in view.subviews {
        searchAndConfigureGestures(in: subview, coordinator: coordinator)
      }
    }
  }

  extension View {
    /// Configures dismiss gestures for the reader based on reading direction.
    func readerDismissGesture(isVerticalReading: Bool) -> some View {
      self.background(ReaderDismissGestureConfigurator(isVerticalReading: isVerticalReading))
    }
  }
#endif
