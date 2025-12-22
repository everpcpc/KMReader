//
//  View+ZoomTransition.swift
//  KMReader
//

import SwiftUI

extension View {
  /// Applies matchedTransitionSource on iOS 18+, returns self on earlier versions
  @ViewBuilder
  func matchedTransitionSourceIfAvailable(id: some Hashable, in namespace: Namespace.ID) -> some View
  {
    #if os(iOS) || os(tvOS)
      if #available(iOS 18.0, tvOS 18.0, *) {
        self.matchedTransitionSource(id: id, in: namespace)
      } else {
        self
      }
    #else
      self
    #endif
  }

  /// Applies navigationTransition zoom on iOS 18+, returns self on earlier versions
  @ViewBuilder
  func navigationTransitionZoomIfAvailable(sourceID: some Hashable, in namespace: Namespace.ID)
    -> some View
  {
    #if os(iOS) || os(tvOS)
      if #available(iOS 18.0, tvOS 18.0, *) {
        self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
      } else {
        self
      }
    #else
      self
    #endif
  }

  /// Conditionally applies a transform if the optional value is non-nil
  @ViewBuilder
  func ifLet<T, Content: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> Content)
    -> some View
  {
    if let value = value {
      transform(self, value)
    } else {
      self
    }
  }
}
