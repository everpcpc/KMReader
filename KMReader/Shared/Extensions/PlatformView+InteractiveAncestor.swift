#if os(iOS) || os(tvOS)
  import UIKit

  extension UIView {
    var hasInteractiveAncestor: Bool {
      var currentView: UIView? = self
      while let view = currentView {
        if view is UIControl {
          return true
        }
        currentView = view.superview
      }
      return false
    }
  }
#elseif os(macOS)
  import AppKit

  extension NSView {
    var hasInteractiveAncestor: Bool {
      var currentView: NSView? = self
      while let view = currentView {
        if view is NSControl {
          return true
        }
        currentView = view.superview
      }
      return false
    }
  }
#endif
