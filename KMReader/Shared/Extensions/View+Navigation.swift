//
// View+Navigation.swift
//
//

import SwiftUI

extension View {
  /// Apply inline navigation bar title style on supported platforms.
  /// - On iOS: sets navigation title and uses `.navigationBarTitleDisplayMode(.inline)`
  /// - On macOS: sets navigation title only
  /// - On other platforms (tvOS, etc.): no-op (does not set title)
  func inlineNavigationBarTitle(_ title: String) -> some View {
    #if os(iOS)
      return self.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      return self.navigationTitle(title)
    #else
      return self
    #endif
  }

  func inlineNavigationBarTitle(_ title: String, systemImage: String) -> some View {
    #if os(iOS)
      return self.navigationTitle(Text("\(Image(systemName: systemImage)) ") + Text(title))
        .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      return self.navigationTitle(Text("\(Image(systemName: systemImage)) ") + Text(title))
    #else
      return self
    #endif
  }

  func handleNavigation() -> some View {
    self.modifier(NavigationHandlingModifier())
  }
}

private struct NavigationHandlingModifier: ViewModifier {
  @Environment(\.zoomNamespace) private var zoomNamespace
  @Environment(\.browseLibrarySelection) private var browseLibrarySelection

  func body(content: Content) -> some View {
    content
      .navigationDestination(for: NavDestination.self) { destination in
        destination.content
          .environment(\.browseLibrarySelection, browseLibrarySelection)
          .navigationTransitionZoomIfAvailable(sourceID: destination.zoomSourceID, in: zoomNamespace)
      }
  }
}
