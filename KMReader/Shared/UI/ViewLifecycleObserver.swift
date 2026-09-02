//
// ViewLifecycleObserver.swift
//
//

#if os(iOS)
  import SwiftUI
  import UIKit

  /// Bridges the enclosing view controller's UIKit appearance callbacks into
  /// SwiftUI. SwiftUI's `onDisappear` only fires after a navigation pop
  /// transition finishes and the view is torn down; `viewWillDisappear` fires
  /// at the start of the transition, which is what time-sensitive chrome such
  /// as the series reading accessory needs.
  struct ViewLifecycleObserver: UIViewControllerRepresentable {
    let onWillDisappear: () -> Void
    let onDidAppear: () -> Void

    func makeUIViewController(context: Context) -> ViewLifecycleObserverViewController {
      let viewController = ViewLifecycleObserverViewController()
      viewController.onWillDisappear = onWillDisappear
      viewController.onDidAppear = onDidAppear
      return viewController
    }

    func updateUIViewController(
      _ uiViewController: ViewLifecycleObserverViewController, context: Context
    ) {
      uiViewController.onWillDisappear = onWillDisappear
      uiViewController.onDidAppear = onDidAppear
    }
  }
#endif
