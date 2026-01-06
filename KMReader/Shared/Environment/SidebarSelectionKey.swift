//
//  BrowseSelectionKey.swift
//  KMReader
//

import SwiftUI

private struct SidebarSelectionKey: EnvironmentKey {
  static let defaultValue: Binding<NavDestination?>? = nil
}

extension EnvironmentValues {
  var sidebarSelection: Binding<NavDestination?>? {
    get { self[SidebarSelectionKey.self] }
    set { self[SidebarSelectionKey.self] = newValue }
  }
}
