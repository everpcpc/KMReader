//
// ReaderContainerInsets.swift
//
//

import CoreGraphics

#if os(iOS)
  import UIKit
#endif

struct ReaderContainerInsets: Equatable {
  var top: CGFloat
  var left: CGFloat
  var bottom: CGFloat
  var right: CGFloat

  static let zero = ReaderContainerInsets(top: 0, left: 0, bottom: 0, right: 0)
}

#if os(iOS)
  extension ReaderContainerInsets {
    var uiEdgeInsets: UIEdgeInsets {
      UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
  }
#endif
