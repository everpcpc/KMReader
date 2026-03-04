//
// CoverPanGestureBridge.swift
//
//

#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  struct CoverPanGestureBridge: View {
    let isEnabled: Bool
    let mode: PageViewMode
    let onPanChanged: (CGSize) -> Void
    let onPanEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void
    let onPanCancelled: () -> Void

    var body: some View {
      PlatformBridge(
        configuration: configuration,
        onPanChanged: onPanChanged,
        onPanEnded: onPanEnded,
        onPanCancelled: onPanCancelled
      )
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }

    private var configuration: Configuration {
      Configuration(
        isEnabled: isEnabled,
        isVerticalMode: mode.isVertical
      )
    }

    private struct Configuration: Equatable {
      let isEnabled: Bool
      let isVerticalMode: Bool
    }

    private struct PlatformBridge: UIViewControllerRepresentable {
      let configuration: Configuration
      let onPanChanged: (CGSize) -> Void
      let onPanEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void
      let onPanCancelled: () -> Void

      func makeCoordinator() -> Coordinator {
        Coordinator(
          configuration: configuration,
          onPanChanged: onPanChanged,
          onPanEnded: onPanEnded,
          onPanCancelled: onPanCancelled
        )
      }

      func makeUIViewController(context: Context) -> BridgeViewController {
        let viewController = BridgeViewController()
        viewController.coordinator = context.coordinator
        return viewController
      }

      func updateUIViewController(_ uiViewController: BridgeViewController, context: Context) {
        context.coordinator.update(
          configuration: configuration,
          onPanChanged: onPanChanged,
          onPanEnded: onPanEnded,
          onPanCancelled: onPanCancelled
        )
        uiViewController.coordinator = context.coordinator
        context.coordinator.attachIfNeeded(anchorView: uiViewController.view)
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
          coordinator?.attachIfNeeded(anchorView: view)
        }

        override func viewDidLayoutSubviews() {
          super.viewDidLayoutSubviews()
          coordinator?.attachIfNeeded(anchorView: view)
        }

        override func viewWillDisappear(_ animated: Bool) {
          super.viewWillDisappear(animated)
          coordinator?.detach()
        }
      }

      @MainActor
      final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private struct DependencyCache {
          var viewChainSignature: [ObjectIdentifier] = []
          var navigationRecognizers: [UIGestureRecognizer] = []
          var boundRecognizerIDs: Set<ObjectIdentifier> = []
        }

        private var configuration: Configuration
        private var onPanChanged: (CGSize) -> Void
        private var onPanEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void
        private var onPanCancelled: () -> Void

        private weak var attachedView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?
        private var dependencyCache = DependencyCache()
        private var lastDependencyRefreshTime: TimeInterval = 0

        init(
          configuration: Configuration,
          onPanChanged: @escaping (CGSize) -> Void,
          onPanEnded: @escaping (_ translation: CGSize, _ velocity: CGSize) -> Void,
          onPanCancelled: @escaping () -> Void
        ) {
          self.configuration = configuration
          self.onPanChanged = onPanChanged
          self.onPanEnded = onPanEnded
          self.onPanCancelled = onPanCancelled
          super.init()
        }

        func update(
          configuration: Configuration,
          onPanChanged: @escaping (CGSize) -> Void,
          onPanEnded: @escaping (_ translation: CGSize, _ velocity: CGSize) -> Void,
          onPanCancelled: @escaping () -> Void
        ) {
          let wasEnabled = self.configuration.isEnabled
          self.configuration = configuration
          self.onPanChanged = onPanChanged
          self.onPanEnded = onPanEnded
          self.onPanCancelled = onPanCancelled
          applyRecognizerState(previouslyEnabled: wasEnabled)
          configureRecognizerDependenciesIfNeeded()
        }

        func attachIfNeeded(anchorView: UIView?) {
          guard let targetView = gestureContainer(from: anchorView) else { return }
          if attachedView === targetView {
            applyRecognizerState(previouslyEnabled: configuration.isEnabled)
            configureRecognizerDependenciesIfNeeded()
            return
          }

          detach()
          installRecognizer(on: targetView)
          configureRecognizerDependenciesIfNeeded(force: true)
          applyRecognizerState(previouslyEnabled: configuration.isEnabled)
        }

        func detach() {
          if let panRecognizer {
            panRecognizer.view?.removeGestureRecognizer(panRecognizer)
          }

          panRecognizer = nil
          attachedView = nil
          dependencyCache = DependencyCache()
          lastDependencyRefreshTime = 0
        }

        private func installRecognizer(on view: UIView) {
          let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
          #if !os(tvOS)
            pan.maximumNumberOfTouches = 1
          #endif
          pan.cancelsTouchesInView = false
          pan.delegate = self
          view.addGestureRecognizer(pan)
          panRecognizer = pan
          attachedView = view
        }

        private func applyRecognizerState(previouslyEnabled: Bool) {
          guard panRecognizer?.isEnabled != configuration.isEnabled else { return }
          let previousState = panRecognizer?.state
          panRecognizer?.isEnabled = configuration.isEnabled

          guard previouslyEnabled, !configuration.isEnabled else { return }
          guard previousState == .began || previousState == .changed else { return }
          DispatchQueue.main.async { [onPanCancelled] in
            onPanCancelled()
          }
        }

        private func configureRecognizerDependenciesIfNeeded(force: Bool = false) {
          guard let panRecognizer, let attachedView else { return }
          let viewChain = buildViewChain(from: attachedView)
          let signature = viewChain.map { ObjectIdentifier($0) }
          let now = Date().timeIntervalSinceReferenceDate
          let shouldPeriodicRefresh = now - lastDependencyRefreshTime > 1.0

          if force
            || dependencyCache.viewChainSignature != signature
            || dependencyCache.navigationRecognizers.isEmpty
            || shouldPeriodicRefresh
          {
            dependencyCache.viewChainSignature = signature
            dependencyCache.navigationRecognizers = navigationRecognizers(from: viewChain, excluding: panRecognizer)
            dependencyCache.boundRecognizerIDs.removeAll()
            lastDependencyRefreshTime = now
          }

          dependencyCache.navigationRecognizers.removeAll { $0.view == nil }

          for recognizer in dependencyCache.navigationRecognizers where recognizer !== panRecognizer {
            let id = ObjectIdentifier(recognizer)
            if dependencyCache.boundRecognizerIDs.contains(id) {
              continue
            }
            panRecognizer.require(toFail: recognizer)
            dependencyCache.boundRecognizerIDs.insert(id)
          }
        }

        private func buildViewChain(from view: UIView) -> [UIView] {
          var chain: [UIView] = []
          var current: UIView? = view
          while let candidate = current {
            chain.append(candidate)
            current = candidate.superview
          }
          return chain
        }

        private func navigationRecognizers(
          from viewChain: [UIView],
          excluding panRecognizer: UIPanGestureRecognizer
        ) -> [UIGestureRecognizer] {
          var collected: [UIGestureRecognizer] = []
          var seen: Set<ObjectIdentifier> = []

          for candidate in viewChain {
            if let gestures = candidate.gestureRecognizers {
              for recognizer in gestures {
                let typeName = String(describing: type(of: recognizer))
                let id = ObjectIdentifier(recognizer)
                if recognizer === panRecognizer {
                  continue
                }
                if isSystemNavigationGesture(typeName: typeName), !seen.contains(id) {
                  seen.insert(id)
                  collected.append(recognizer)
                }
              }
            }
          }

          return collected
        }

        private func isSystemNavigationGesture(typeName: String) -> Bool {
          typeName.contains("Parallax")
            || typeName.contains("ZoomTransition")
            || typeName.contains("ScreenEdgePan")
            || typeName.contains("FullPageSwipe")
            || typeName == "_UIContentSwipeDismissGestureRecognizer"
        }

        @objc
        private func handlePan(_ recognizer: UIPanGestureRecognizer) {
          guard configuration.isEnabled else { return }
          guard let view = recognizer.view else { return }
          let translationPoint = recognizer.translation(in: view)
          let translation = CGSize(width: translationPoint.x, height: translationPoint.y)

          switch recognizer.state {
          case .changed:
            onPanChanged(translation)
          case .ended:
            let velocityPoint = recognizer.velocity(in: view)
            let velocity = CGSize(width: velocityPoint.x, height: velocityPoint.y)
            onPanEnded(translation, velocity)
          case .cancelled, .failed:
            onPanCancelled()
          default:
            break
          }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
          guard configuration.isEnabled else { return false }
          guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

          let velocity = pan.velocity(in: pan.view)
          let primary = configuration.isVerticalMode ? abs(velocity.y) : abs(velocity.x)
          let secondary = configuration.isVerticalMode ? abs(velocity.x) : abs(velocity.y)
          return primary > secondary + 12
        }

        func gestureRecognizer(
          _ gestureRecognizer: UIGestureRecognizer,
          shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
          isSystemNavigationGesture(typeName: String(describing: type(of: otherGestureRecognizer)))
        }

        func gestureRecognizer(
          _ gestureRecognizer: UIGestureRecognizer,
          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
          let gestureType = String(describing: type(of: gestureRecognizer))
          let otherType = String(describing: type(of: otherGestureRecognizer))
          return isSystemNavigationGesture(typeName: gestureType)
            || isSystemNavigationGesture(typeName: otherType)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
          configuration.isEnabled && !isInteractiveElement(touch.view)
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
              || className.contains("Menu")
              || className.contains("ContextMenu")
              || className.contains("Popover")
            {
              return true
            }

            current = candidate.superview
          }

          return false
        }

        private func gestureContainer(from anchorView: UIView?) -> UIView? {
          var current = anchorView
          while let candidate = current {
            if candidate.bounds.width > 1, candidate.bounds.height > 1 {
              return candidate
            }
            current = candidate.superview
          }
          return nil
        }
      }
    }
  }
#endif
