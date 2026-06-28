//
// BrowseSearchFocusModifier.swift
//
//

import SwiftUI

extension View {
  @ViewBuilder
  func browseSearchFocus(_ binding: FocusState<Bool>.Binding, when shouldFocus: Bool) -> some View {
    #if os(iOS) || os(macOS)
      if #available(iOS 18.0, macOS 15.0, *) {
        modifier(
          BrowseSearchFocusModifier(
            isSearchFocused: binding,
            focusesSearchOnAppear: shouldFocus
          )
        )
      } else {
        self
      }
    #else
      self
    #endif
  }
}

#if os(iOS) || os(macOS)
  @available(iOS 18.0, macOS 15.0, *)
  private struct BrowseSearchFocusModifier: ViewModifier {
    let isSearchFocused: FocusState<Bool>.Binding
    let focusesSearchOnAppear: Bool

    func body(content: Content) -> some View {
      content
        .searchFocused(isSearchFocused)
        .task {
          if focusesSearchOnAppear {
            await Task.yield()
            isSearchFocused.wrappedValue = true
          }
        }
    }
  }
#endif
