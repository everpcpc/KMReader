//
//  ZoomNamespaceKey.swift
//  KMReader
//

import SwiftUI

// Environment key for sharing zoom transition namespace
struct ZoomNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
  var zoomNamespace: Namespace.ID? {
    get { self[ZoomNamespaceKey.self] }
    set { self[ZoomNamespaceKey.self] = newValue }
  }
}
