//
// ReaderControlsVisibilityPreference.swift
//
//

import SwiftUI

private struct ReaderControlsVisibilityPreferenceKey: PreferenceKey {
  static var defaultValue = true

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = nextValue()
  }
}

extension View {
  func readerControlsVisibility(_ visible: Bool) -> some View {
    preference(key: ReaderControlsVisibilityPreferenceKey.self, value: visible)
  }

  func onReaderControlsVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
    onPreferenceChange(ReaderControlsVisibilityPreferenceKey.self, perform: action)
  }
}
