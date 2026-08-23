//
// View+KeepScreenAwake.swift
//
//

import SwiftUI

#if os(iOS) || os(tvOS)
  import UIKit
#endif

extension View {
  /// Disables the idle timer while a reader is open when the global
  /// "keepScreenAwakeWhileReading" setting is enabled. No-op on macOS.
  func keepScreenAwakeWhileReading() -> some View {
    #if os(iOS) || os(tvOS)
      self.modifier(KeepScreenAwakeModifier())
    #else
      self
    #endif
  }
}

#if os(iOS) || os(tvOS)
  private struct KeepScreenAwakeModifier: ViewModifier {
    @AppStorage("keepScreenAwakeWhileReading") private var enabled: Bool = false

    func body(content: Content) -> some View {
      content
        .onAppear {
          apply()
        }
        .onChange(of: enabled) { _, _ in
          apply()
        }
        .onDisappear {
          UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func apply() {
      UIApplication.shared.isIdleTimerDisabled = enabled
    }
  }
#endif
