//
// SidebarSelectionKey.swift
//
//

import SwiftUI

private struct SidebarSelectionKey: EnvironmentKey {
  static let defaultValue: Binding<NavDestination?>? = nil
}

private struct BrowseLibrarySelectionKey: EnvironmentKey {
  static let defaultValue: LibrarySelection? = nil
}

extension EnvironmentValues {
  var sidebarSelection: Binding<NavDestination?>? {
    get { self[SidebarSelectionKey.self] }
    set { self[SidebarSelectionKey.self] = newValue }
  }

  var browseLibrarySelection: LibrarySelection? {
    get { self[BrowseLibrarySelectionKey.self] }
    set { self[BrowseLibrarySelectionKey.self] = newValue }
  }
}
