//
// ViewLifecycleObserverViewController.swift
//
//

#if os(iOS)
  import UIKit

  /// Invisible view controller used by `ViewLifecycleObserver`. Appearance
  /// callbacks propagate from the hosting controller, so this reports the
  /// enclosing SwiftUI page's UIKit lifecycle.
  final class ViewLifecycleObserverViewController: UIViewController {
    var onWillDisappear: (() -> Void)?
    var onDidAppear: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      onWillDisappear?()
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      onDidAppear?()
    }
  }
#endif
