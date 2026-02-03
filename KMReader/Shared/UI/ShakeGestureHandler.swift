#if os(iOS)
  import UIKit

  extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
  }

  extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
      if motion == .motionShake {
        NotificationCenter.default.post(name: .deviceDidShake, object: nil)
      }
      super.motionEnded(motion, with: event)
    }
  }
#endif
