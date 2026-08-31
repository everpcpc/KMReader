//
// ReadingActionBarContext.swift
//
//

import Foundation

/// Shared presentation state for the series continue-reading accessory.
/// Written by `SeriesDetailView`, rendered by `PhoneTabView` through the
/// iOS 26 `tabViewBottomAccessory`. On every other platform and OS version
/// the accessory does not exist and this context is simply unused.
@MainActor
@Observable
final class ReadingActionBarContext {
  static let shared = ReadingActionBarContext()

  struct Presentation {
    let seriesId: String
    let instanceId: String
    /// The resolved continue-reading target book; nil means the accessory
    /// presents the series itself (cover and title fall back to the series).
    let bookId: String?
    let caption: String
    let title: String
    let isResolving: Bool
  }

  private(set) var presentation: Presentation?
  private var action: (() -> Void)?

  private init() {}

  func present(_ presentation: Presentation, action: @escaping () -> Void) {
    self.presentation = presentation
    self.action = action
  }

  /// Clears the presentation. When `seriesId` is provided, only clears if the
  /// current presentation belongs to that series, so a disappearing detail
  /// view never wipes a newer presentation from another series.
  func clear(seriesId: String? = nil) {
    if let seriesId, presentation?.seriesId != seriesId { return }
    presentation = nil
    action = nil
  }

  func performAction() {
    action?()
  }
}
