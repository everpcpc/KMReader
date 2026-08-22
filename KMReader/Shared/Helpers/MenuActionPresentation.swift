//
// MenuActionPresentation.swift
//
//

import Foundation

/// Defers a presentation-state mutation out of a menu item action.
/// Presenting a sheet or alert synchronously from an NSMenu action can leave
/// macOS stuck mid-presentation (menu bar disabled, beachball) while the menu
/// tracking loop is still active. Running the mutation on the next runloop lets
/// the menu finish dismissing first. Safe no-op timing-wise on other platforms.
func deferMenuActionPresentation(_ action: @escaping () -> Void) {
  DispatchQueue.main.async(execute: action)
}
